package Contentity::Configure::Script;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    utils     => 'find_program',
    constants => 'HASH',
    constant  => {
        INTRO   => 'intro',
        SECTION => 'section',
    },
    accessors => 'script option';

sub init {
    my ($self, $config) = @_;
    my $script = $config->{ script }
        || return $self->error_msg( missing => 'script' );

    $self->{ script } = $script;
    $self->{ option } = { };
    $self->{ data   } = $config->{ data };
    $self->{ quiet  } = $self->{ data }->{ quiet };
    $self->debug("init data: ", $self->dump_data($self->{ data })) if DEBUG;

    $self->init_script($script);

    return $self;
}

sub init_script {
    my ($self, $script) = @_;
    my $group;

    foreach $group (@$script) {
        $self->init_group($group);
    }
}

sub init_group {
    my ($self, $group) = @_;
    my $opts  = { };
    my $urn   = undef;
    my ($section, $name, $spec);

    if (ref $group->[0] eq HASH) {
        my $hash = shift @$group;
        my $key  = (keys %$hash)[0];
        my $val  = (values %$hash)[0];
        $self->debug("expanded hash $key => $val") if DEBUG;
        unshift(@$group, $key, $val);
    }

    my @items = @$group;

    if ($items[0] eq SECTION) {
        shift @items;
        $section = shift @items;
        $urn = $section->{ urn } || $section->{ name } || $urn;
        $opts->{ cmdarg } = $section->{ cmdarg } || $urn;
        $self->debug("Initialising $urn script group") if DEBUG;
    }
    elsif ($items[0] eq INTRO) {
        shift @items;
        $section = shift @items;
        $self->debug("Skipping intro section") if DEBUG;
    }

    while (@items) {
        $name = shift @items;
        if (ref $name eq HASH) {
            $spec = (values %$name)[0];
            $name = (keys   %$name)[0];
        }
        else {
            $spec = shift @items || die "missing spec for $name";
        }
        $spec->{ path } = [ $urn || (), $name ];
        $self->init_option($name, $spec, $opts);
    }
}

our $HELPERS = {
    program => \&find_program,
};

sub init_option {
    my ($self, $name, $option, $options) = @_;
    my $cmdarg = $option->{ cmdarg } ||= join(
        '_', 
        grep { defined $_ } 
        $options->{ cmdarg }, 
        $name
    );
    my $default = $option->{ default };
    my $short   = $option->{ short };
    $self->{ option }->{ $cmdarg } = $option;
    $self->{ option }->{ $short  } = $option if $short;
    
    if ($default) {
        if ($default =~ /^(\w+):(\w.*)/) {
            my $type = $1;
            my $item = $2;
            my $help = $HELPERS->{ $type }
                || return $self->error_msg( invalid => "default for $name" => $default );
            $option->{ default } = find_program($item);
            $self->debug("found program $item: $option->{ default }") if DEBUG;
        }
        $self->default($option->{ path }, $option->{ default });
    }

    $self->debug("Initialising $name option ($cmdarg)") if DEBUG;
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

1;
