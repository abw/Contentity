package Contentity::Configure::Script;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    utils     => 'find_program',
    constants => 'HASH BLANK',
    constant  => {
        INTRO   => 'intro',
        SECTION => 'section',
    },
    accessors => 'script option';

our $HELPERS = {
    program => \&program_helper,
};


sub init {
    my ($self, $config) = @_;
    my $script = $config->{ script }
        || return $self->error_msg( missing => 'script' );

    $self->{ script } = $script;
    $self->{ option } = { };
    $self->{ data   } = $config->{ data };
    $self->{ quiet  } = $self->{ data }->{ quiet };
    $self->debug("init data: ", $self->dump_data($self->{ data })) if DEBUG;

    $self->{ title } = $script->{ title };
    $self->{ about } = $script->{ about };
    $self->{ items } = $script->{ items };

    $self->init_script($script);

    return $self;
}

sub init_script {
    my ($self, $script) = @_;
    my $items = $script->{ items };
    local $self->{ sections } = [ ];
    local $self->{ sectpath } = [ ];
    $self->init_items($items);
    $self->debug_data("items: ", $items) if DEBUG;
}

sub init_items {
    my ($self, $items) = @_;

    foreach my $item (@$items) {
        $self->init_item($item);
    }
}

sub init_item {
    my ($self, $item) = @_;
    my $type  = $item->{ type } || BLANK;
    my $urn   = $item->{ urn  } || $item->{ name };

    if ($type eq SECTION) {
        return $self->init_section($item);
    }

    $item->{ path } = [
        @{ $self->{ sectpath } },
        $urn
    ];

    my $short   = $item->{ short   };
    my $option  = $item->{ option  };
    my $default = $item->{ default };

    $self->{ option }->{ $option } = $item if $option;
    $self->{ option }->{ $short  } = $item if $short;

    if ($default) {
        if ($default =~ /^(\w+):(\w.*)/) {
            my $type = $1;
            my $name = $2;
            my $help = $HELPERS->{ $type }
                || return $self->error_msg( invalid => "default for $name" => $default );
            $item->{ default } = $help->($self, $name, $item);
            $self->debug("found $type:$name via $type helper: $item->{ default }") if DEBUG;
        }
    #   $self->default($option->{ path }, $option->{ default });
    }
}


sub init_section {
    my ($self, $section) = @_;
    my $urn   = $section->{ urn } || $section->{ name };
    my $arg   = $section->{ cmdarg } || $urn;
    my $items = $section->{ items };
    my $stack = $self->{ sections };
    my $frame = {
        section => $section,
        urn     => $urn,
    };

    local $self->{ sections } = [@$stack, $frame];
    local $self->{ sectpath } = [
        grep { defined && $_ } 
        map  { $_->{ urn }   }
        @{ $self->{ sections } },
    ];

    # force 'section' to be set to something useful
    $section->{ section } = $self->{ sectpath };
    #print "SECTPATH: $section->{ section }"

    $self->debug(
        "Initialising $section->{ section } script group: "
    ) if DEBUG;

    $self->init_items($items)
        if $items;
}


sub default {
    my ($self, $path, $value) = @_;
    my $data  = $self->{ data };
    my @parts = @$path;
    my $name  = pop @parts;
    $self->debug("default [", join('].[', @parts, $name), "] => $value") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } ||= { };
    }
    $data->{ $name } //= $value;
}


sub run {
    my ($self, $app) = @_;
    my $items = $self->script->{ items };

    $self->run_items($items, $app);
}

sub run_items {
    my ($self, $items, $app) = @_;

    foreach my $item (@$items) {
        $self->run_item($item, $app);
    }
}

sub run_item {
    my ($self, $item, $app) = @_;

    if ($item->{ section }) {
        return $self->run_section($item, $app);
    }

    #$self->debug_data("TODO: run item: ", $item);

    my $name = $item->{ name };
    $app->option_prompt($name, $item);
}


sub run_section {
    my ($self, $section, $app) = @_;
    my $items = $section->{ items };

    unless ($app->quiet) {
        $app->prompt_title( $section->{ title } )
            if $section->{ title };

        $app->prompt_about( $section->{ about } )
            if $section->{ about };

        $app->prompt_instructions
            if $section->{ instructions };
    }

    $self->run_items($items, $app)
        if $items;

    $app->prompt_newline
        unless $app->quiet;
}


sub program_helper {
    my ($self, $name, $item) = @_;
    find_program($name);
}


1;
