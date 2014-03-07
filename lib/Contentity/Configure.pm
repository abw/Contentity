package Contentity::Configure;

use Badger::Rainbow 
    ANSI => 'red green yellow cyan blue white grey';

use Badger::Config::Filesystem;
use Contentity::Configure::Script;
use Contentity::Configure::Scaffold;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    accessors   => 'script data',
    utils       => 'Bin Dir prompt split_to_list floor',
    constants   => 'HASH BLANK',
    constant    => {
        INTRO           => 'intro',
        SECTION         => 'section',
        CONFIG_SCRIPT   => 'config_script',
        CONFIG_SAVE     => 'config_save',
        SCRIPT_MODULE   => 'Contentity::Configure::Script',
        SCAFFOLD_MODULE => 'Contentity::Configure::Scaffold',
        CONFIG_MODULE   => 'Badger::Config::Filesystem',
    };

*title_colour  = \&white;
*about_colour  = \&grey;
*option_colour = \&yellow;
*optarg_colour = \&green;
*opttxt_colour = \&cyan;
*note_colour   = \&yellow;
*info_colour   = \&grey;

sub init {
    my ($self, $config) = @_;
    my $dir      = $config->{ directory     } ||= Bin;
    my $cdir     = $config->{ config_dir    } ||= 'config';
    my $sfile    = $config->{ config_save   } || $self->CONFIG_SAVE;
    my $script   = $config->{ config_script } || $self->CONFIG_SCRIPT;
    my $root     = $self->{ root        } = Dir($dir);
    my $cfgdir   = $self->{ config_dir  } = $root->dir($cdir);
    my $data     = $self->{ data        } = $config->{ data } ||= { };
    my $args     = $config->{ args };
    my $confmod  = $self->CONFIG_MODULE->new( directory => $cfgdir );
    my $metadata = $confmod->get($script)
        || return $self->error("Configuration script not found: $cdir/$script.yaml");

    # quick hack to set quite/verbose mode ahead of full config read
    if ($args) {
        $self->{ verbose } = grep { /^--?v(erbose)?$/     } @$args;
        $self->{ quiet   } = grep { /^--?q(uiet)?$/       } @$args;
        $self->{ dry_run } = grep { /^--?d(ry[-_]?run)?$/ } @$args;
        $self->{ white   } = grep { /^--?w(hite)?$/       } @$args;
        $self->{ reset   } = grep { /^--?r(eset)?$/       } @$args;
    }

    $config->{ script } ||= $metadata;

    # set the current root directory, but note that it may be modified by 
    # a value set in config/config_save.yaml
    $data->{ root } ||= $root->definitive;

    if ($sfile && ! $self->{ reset }) {
        my $lastrun = $confmod->get($sfile);
        if ($lastrun) {
            $self->note("Loaded saved configuration values from $cdir/$sfile");
            $self->debug("last run:", $self->dump_data($lastrun)) if DEBUG;
            $self->merge($lastrun);
        }
        else {
            $self->note("Saved configuration values not found: $cdir/$sfile")
                if $self->{ verbose };
        }
    }

    #$self->debug("root: $root");
    #$self->debug("loaded metadata: ", $self->dump_data($metadata));
    $self->{ root     } = $root;
    $self->{ script   } = $self->SCRIPT_MODULE->new($config);
    $self->{ option   } = $self->script->option;
    $self->{ data     } = $config->{ data   } || { };
    $self->{ colour   } = $config->{ colour } // ($self->{ white } ? 0 : 1);
    $self->{ config   } = $config;

    if ($config->{ args }) {
        $self->args($config->{ args });
    }
    $self->{ verbose } = $data->{ verbose };
    $self->{ quiet   } = $data->{ quiet   };
    $self->{ white   } = $data->{ white   };
    $self->{ colour  } = 0 if $self->{ white };

    if ($self->{ data }->{ help }) {
        warn $self->help, "\n";
        exit;
    }

    $config->{ verbose } = $self->{ verbose };
    $config->{ quiet   } = $self->{ quiet   };
    $config->{ dry_run } = $data->{ dry_run };

    if ($config->{ prompt }) {
        $self->options_prompt;
    }

    if ($config->{ scaffold }) {
        $self->scaffold;
    }

    if ($sfile) {
        $confmod->write_config_file(
            $sfile => $self->stripped_data
        );
        $self->note("Saved current configuration as $sfile");
    }

    return $self;
}

sub stripped_data {
    my $self = shift;
    my $data = $self->data;
    my $opts = $self->{ option };

    $data = { %$data };

    while (my ($key, $value) = each %$opts) {
        if (defined $value->{ prompt } && ! $value->{ prompt }) {
            $self->debug("deleting $key from data: ", $self->dump_data($value)) if DEBUG;
            $self->zap($value->{ path }, $data);
        }
    }
    return $data;
}

sub set {
    my ($self, $path, $value) = @_;
    my $data  = $self->{ data };
    my @parts = @$path;
    my $name  = pop @parts;
    $self->debug("set [", join('].[', @parts, $name), "] => $value") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } ||= { };
    }
    $data->{ $name } = $value;
}

sub get {
    my ($self, $path) = @_;
    my $data = $self->{ data };
    foreach my $part (@$path) {
        $data = $data->{ $part } || return;
    }
    return $data;
}

sub zap {
    my ($self, $path, $src) = @_;
    my $data  = $src || $self->{ data };
    my @parts = @$path;
    my $name  = pop @parts;
    $self->debug("zap [", join('].[', @parts, $name), "]") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } || return;
    }
    delete $data->{ $name };
}


sub merge {
    my ($self, $merge) = @_;
    $self->merge_hash($merge, $self->data);
    $self->debug("merged data: ", $self->dump_data($self->data)) if DEBUG;
}

sub merge_hash {
    my ($self, $from, $to) = @_;
    my $old;

    while (my ($key, $value) = each %$from) {
        if (ref $value eq HASH && ($old = $to->{ $key }) && ref $old eq HASH) {
            $self->debug("merging hashes for $key") if DEBUG;
            $self->merge_hash($value, $old);
        }
        else {
            $self->debug("merging $key => $value") if DEBUG;
            $to->{ $key } = $value;
        };
    }
}


sub args {
    my ($self, $args) = @_;

    while (@$args && $args->[0] =~ /^-/) {
        my $arg  = shift @$args;
        $arg =~ s/^-+//;
        my $val  = ($arg =~ s/=(.*)// && $1);
        my $opt  = $self->{ option }->{ $arg }
            || return $self->error_msg( invalid => option => $arg );
        my $args = $opt->{ cmdargs };
        if ($args) {
            if (! $val) {
                return $self->error_msg( missing => $arg );
            }
        }
        else {
            $val = 1;
        }
        my $path = $opt->{ path }
            || return $self->error_msg( invalid => option => "$arg (no data path)" );
        $self->set($path, $val);
    }
    if (@$args) {
        return $self->error_msg( invalid => argument => $args->[0] );
    }
}

#-----------------------------------------------------------------------------
# help
#-----------------------------------------------------------------------------

sub help {
    shift->options_help;
}

sub options_help {
    my $self   = shift;
    my $script = $self->script->script;
    my $group;
    my @output;

    foreach $group (@$script) {
        push(@output, $self->option_group_help($group));
    }
    return join("\n", @output);
}

sub option_group_help {
    my ($self, $group) = @_;
    my @items = @$group;
    my (@output, $section, $title, $about, $urn, $sarg, $name, $spec);

    if ($items[0] eq INTRO) {
        shift @items;
        $section = shift @items;
        if ($title = $section->{ title }) {
            my $bar = '=' x length $title;
            $title = title_colour($title) if $self->{ colour };
            push(@output, $title, $bar, BLANK);
        }
        if ($about = $section->{ about }) {
            $about = about_colour($about) if $self->{ colour };
            push(@output, $about, BLANK);
        }
        return join("\n", @output);
    }

    if ($items[0] eq SECTION) {
        shift @items;
        $section = shift @items;

        if ($title = $section->{ title }) {
            $title = title_colour($title) if $self->{ colour };
            push(@output, "  $title:");
            $urn  = $section->{ urn };
            $sarg = $section->{ cmdarg };
        }
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
        push(@output, $self->option_help($name, $spec));
    }
    push(@output, "");
    return join("\n", @output);
}

sub option_help {
    my ($self, $name, $option) = @_;
    my $cmdarg  = $option->{ cmdarg  } || $name;
    my $cmdargs = $option->{ cmdargs } || '';
    my $title   = $option->{ title   } || '';
    my $short   = $option->{ short   } || '';
    my $length  = length $cmdarg;
    my $pad;

    $length++ if $cmdargs;
    $length += length($cmdargs)   if $cmdargs;
    $length += length($short) + 4 if $short;
    $length += 2;
    $pad     = 30 - $length;
    $pad     = ' ' x $pad;

    if ($self->{ colour }) {
        $cmdarg  = option_colour($cmdarg);
        $cmdargs = optarg_colour($cmdargs) if $cmdargs;
        $title   = opttxt_colour($title);
        $short   = ' (-' . option_colour($short) . ')' if $short;
    }
    $cmdargs = "=$cmdargs" if $cmdargs;
    $cmdarg .= $cmdargs;
    return sprintf("    --%s%s%s %s", $cmdarg, $short, $pad, $title);
}

sub heading {
    my $text = shift;
    print "\n";
    print $text, "\n";
    print blue( join('', ('-') x length($text)) ), "\n\n";
}



#-----------------------------------------------------------------------------
# prompts
#-----------------------------------------------------------------------------

sub options_prompt {
    my $self   = shift;
    my $script = $self->script->script;
    my $group;
    my @output;

    foreach $group (@$script) {
        $self->option_group_prompt($group);
    }
}

sub option_group_prompt {
    my ($self, $group) = @_;
    my @items = @$group;
    my (@output, $type, $section, $title, $about, $urn, $sarg, $name, $spec);
    my $intro = $items[0] eq INTRO;

    if ($intro || $items[0] eq SECTION) {
        $type    = shift @items;
        $section = shift @items;

        unless ($self->{ quiet }) {
            print "\n" if $intro;

            if ($title = $section->{ title }) {
                my $char = $intro ? '=' : '-';
                my $bar = $char x length $title;
                $title = title_colour($title) if $self->{ colour };
                print "$title\n$bar\n";
            }
            if ($about = $section->{ about }) {
                $about = about_colour($about) if $self->{ colour };
                print "$about\n";
                print "\n" unless $intro;
            }

            $self->option_group_blurb
                if $intro;
        }

        return
            if $intro;

        $urn  = $section->{ urn };
        $sarg = $section->{ cmdarg };
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
        $self->option_prompt($name, $spec);
    }
    print "\n" unless $self->{ quiet };
}

sub option_group_blurb {
    my $self = shift;
    print info_colour("Please provide values for the following configuration options."), "\n";
    print info_colour('Press '), 
          green('RETURN'), 
          info_colour(' to accept the '), 
          $self->colour_default('default value'),
          info_colour('. Enter '),
          green('-'),
          info_colour(' to clear any current value.'),
          "\n\n";

}

sub option_prompt {
    my ($self, $name, $option) = @_;
    return if defined $option->{ prompt } && ! $option->{ prompt };
    my $cmdargs = $option->{ cmdargs   } || '';
    my $title   = $option->{ title     } || '';
    my $path    = $option->{ path      };
    my $default = $option->{ default   };
    my $mandy   = $option->{ mandatory };
    my $options = $option->{ options   };
    my $value   = $self->get($path);
    my $yes     = $self->{ data }->{ yes };
    my $attempt = 0;
    my ($result, $valid);
    $self->debug("DEF: $default   VAL: $value  PATH: ", $self->dump_data($path)) if DEBUG;
    $self->debug("DATA: ", $self->dump_data($self->{data})) if DEBUG;

    if ($options) {
        $options = split_to_list($options);
        $options = { map { $_ => $_ } @$options };
        $self->debug("options: ", $self->dump_data($options)) if DEBUG;
    }

    while (1) {
        $result = prompt($title, $value || $default, $yes, $option);
        $self->debug("read: $result") if DEBUG;

        if (! length($result)) {
            if ($mandy || $options) {
                print red $self->random_insult($attempt++), "\n";
                print red "You must enter a value for this configuration option\n";
            }
            else {
                last;
            }
        }
        elsif ($options && ! $options->{ $result }) {
            print red $self->random_insult($attempt++), "\n";
            print red "That's not an acceptable value for this configuration option\n";
        }
        else {
            last;
        }
    }

    $self->set($path, $result);
}

our $INSULTS = [
    [
        'Please try again.', 
        'Oops, you made a mistake!', 
        "Oh dear, I'm afraid that's not good enough."
    ],
    [
        'You muppet!',
        'Are you on drugs?', 
        'Do you have trouble typing or did someone cut your fingers off?', 
    ],
    [
        'Are you taking the piss?', 
        "I'm getting rather annoyed with you.", 
        "I'm tutting quietly under my breath."
    ],
    [
        "Look, I may be a dumb computer but I've got better things to be doing with my time.",
        "Now I know you're just doing this to see all the silly error messages.",
        "Your mother was a hamster and your father smelled of elderberries.",
        "I blow my nose at you and all your silly ker-nig-herts.",
    ],
    [
        "Stop it!",
        "Bugger off!",
    ],
    [
        "Seriously, stop messing!",
        "Get lost!",
    ],
    [
        "I'm not playing any more.",
    ]
];

sub random_insult {
    my ($self, $level) = @_;
    $level = floor($level / 5);
    my $set = $INSULTS->[$level] || $INSULTS->[-1];
    return $set->[rand @$set];
}

sub scaffold {
    shift->scaffold_module->build;
}

sub scaffold_module {
    my $self = shift;
    my $conf = $self->{ config };

#    $conf = { 
#        %$conf,
##        data => $self->{ data }
#    };

    return  $self->{ scaffold_module }
        ||= $self->SCAFFOLD_MODULE->new($conf);
}

sub note {
    my $self = shift;
    return if $self->{ quiet };
    print STDERR yellow("NOTE: "), cyan(@_), "\n";
}

sub colour_default {
    my ($self, $default) = @_;
    return '' unless defined $default;
    return $default unless $self->{ colour };
    return yellow("[") . green($default) . yellow("]");
}

1;

__END__
