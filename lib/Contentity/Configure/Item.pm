package Contentity::Configure::Item;

use Badger::Rainbow 
    ANSI => 'red green yellow cyan blue white grey';

use Contentity::Utils;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    accessors   => 'name urn path options optional',
    utils       => 'falselike split_to_list',
    constants   => 'HASH BLANK',
    constant    => {
    };

*title_colour  = \&white;
*about_colour  = \&grey;
*option_colour = \&yellow;
*optarg_colour = \&green;
*opttxt_colour = \&cyan;
*note_colour   = \&yellow;
*info_colour   = \&grey;
*_prompt       = \&Contentity::Utils::prompt;

sub init {
    my ($self, $config) = @_;
    my $name = $config->{ name } || return $self->error_msg( missing => 'name' );
    my $urn  = $config->{ urn  };

    if ($urn && falselike($urn)) {
        $urn = undef;
    }
    else {
        $urn ||= $name;
    }

    $self->{ name   } = $name;
    $self->{ urn    } = $urn;
    $self->{ title  } = $config->{ title  } // $name;
    $self->{ prompt } = $config->{ prompt } // $self->{ title };

    # not sure about this, doing it for now
    foreach (
        qw( cmdarg cmdargs short )
    ) {
        $self->{ $_ } = $config->{ $_ };
    }

    return $self;
}

sub help {
    my ($self, $helper) = @_;
    my $name    = $self->{ name };
    my $cmdarg  = $self->{ cmdarg  } || $name;
    my $cmdargs = $self->{ cmdargs } || '';
    my $title   = $self->{ title   } || '';
    my $short   = $self->{ short   } || '';
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


sub prompt {
    my ($self, $prompter, $model) = @_;

    # 'prompt' can be explcitly set to a false value to disable it
    return if defined $self->{ prompt } 
                 && ! $self->{ prompt };

    my $cmdargs = $self->{ cmdargs   } || '';
    my $title   = $self->{ title     } || '';
    my $path    = $self->{ path      };
    my $default = $self->{ default   };
    my $mandy   = $self->{ mandatory };
    my $options = $self->{ options   };
    my $value   = $model && $model->get($path);
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
        $result = _prompt($title, $value || $default, $yes, $self);
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

#    $self->set($path, $result);
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
