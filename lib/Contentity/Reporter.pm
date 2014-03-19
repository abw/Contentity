package Contentity::Reporter;

use Contentity::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Contentity::Base',
    import       => 'class',
    config       => 'verbose=0 quiet=0 nothing|dry_run=0 progress=0 colour|color=1',
    utils        => 'red green yellow cyan blue bold xprintf',
    accessors    => 'event_names',
    mutators     => 'verbose quiet nothing colour',
    constants    => 'ARRAY',
    constant     => {
        NO_REASON   => 'no reason given',
    },
    alias        => {
        color    => 'colour',
        dry_run  => 'nothing',
    };

our $EVENTS = [
    qw( pass fail skip warn info )
];

our $MESSAGES = {
    pass        => '%s',
    fail        => '%s',
    skip        => '%s',
    warn        => '%s',
    info        => '%s',
    stat_pass   => '%5d successful operations',
    stat_fail   => '%5d failed operations',
    stat_skip   => '%5d skipped operations',
    stat_warn   => '%5d warnings',
};

our $COLOURS = {
    pass      => \&green,
    fail      => \&red,
    skip      => \&yellow,
    warn      => \&bold_red,
    info      => \&cyan,
    stat_pass => \&green,
    stat_fail => \&red,
    stat_skip => \&yellow,
    stat_warn => \&bold_red,
    stat_info => \&blue,
};

sub bold_red {
    bold red @_;
}

#-----------------------------------------------------------------------
# init methods
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    # process the basic configurations: verbose, quiet, etc.
    $self->configure($config);

    # call the reporter-specific init method
    $self->init_reporter($config);

    return $self;
}

sub init_reporter {
    my ($self, $config) = @_;
    my $class = $self->class;

    # merge all event names
    my $events = $self->{ events } = $class->list_vars(
        EVENTS => $config->{ events }
    );

    # zero all the stats
    $self->{ stats } = {
        map { $_ => 0 }
        @$events
    };

    my $messages = $self->{ messages } = $class->hash_vars(
        MESSAGES => $config->{ messages }
    );

    my $colours = $self->{ colours } = $class->hash_vars(
        COLOURS => $config->{ colours }
    );

    $self->{ colour_messages } = {
        # create a mapping from event name ($_) to a coloured version of the 
        # message format.  To get that we call the relevant funtion defined in 
        # $colours, passing the plain $message format as an argument.
        map { $_ => $colours->{ $_ }->($messages->{ $_ }) }
        # ... for all event names
        @$events,
        # ... and also event names prefixed by 'stat_', e.g. stat_pass
        map { "stat_$_" }
        @$events
    };


    return $self;
}


#-----------------------------------------------------------------------------
# Bit of a hack to make it quick and easy to configure a reporter from command
# line arguments.
#-----------------------------------------------------------------------------

sub configure_args {
    my $self = shift;
    my @args = @_ == 1 && ref $_[0] eq ARRAY ? @{$_[0]} 
             : @_ ? @_
             : @ARGV;

    $self->debug("configure_args(", $self->dump_data(\@args)) if DEBUG;
    
    return $self->usage     if grep(/--?h(elp)?/, @args);
    $self->{ nothing  } = 1 if grep(/--?(n(othing)?|dry[-_]?run)/, @args);
    $self->{ verbose  } = 1 if grep(/--?v(erbose)?/, @args);
    $self->{ quiet    } = 1 if grep(/--?q(uiet)?/, @args);
    $self->{ colour   } = 1 if grep(/--?c(olou?r)?/, @args);

    # Get any extra configuration from the subclass scheme definition
    # NOTE: This only works in immediate subclasses. A more thorough 
    # implementation should call list_vars() and deal with everything,
    # thereby eliminating the above code.  However, that's something for 
    # Badger::Config
    my $config = $self->class->list_vars('CONFIG');     # may overwrite above
    if ($config) {
        foreach my $item (@$config) {
            my $name = quotemeta $item->{ name };
            $self->{ $name } = 1 if grep(/--?$name/, @args);
            if (DEBUG) {
                $self->debug("CONFIG $name => ", defined($self->{ name }) ? $self->{ name } : '<undef>');
            }
        }
    }

    $self->{ colour  } = 0 if grep(/--?no[-_]?c(olou?r)?/, @args);
    $self->{ colour  } = 0 if grep(/--?white/, @args);

    $self->init_output;
    
    return $self;
}



#-----------------------------------------------------------------------------
# output methods
#-----------------------------------------------------------------------------

sub say {
    my $self = shift;
    print @_, "\n";
}

sub say_msg {
    my $self = shift;
    $self->say(
        $self->msg(@_)
    );
}

sub msg {
    my $self   = shift;
    my $name   = shift 
        || $self->fatal("message() called without format name");
    my $scheme = $self->{ colour } ? $self->{ colour_messages } : $self->{ messages };
    my $format = $scheme->{ $name }
        || $self->fatal("msg() called with invalid message type: $name");
    xprintf($format, @_);
}

#-----------------------------------------------------------------------
# status methods
#-----------------------------------------------------------------------

sub event_msg {
    my $self = shift;
    my $type = shift;
    my $text = join('', grep { defined $_ } @_);
    $self->say_msg( $type => $text );
}

sub pass {
    my $self = shift;
    $self->{ stats }->{ pass }++;
    return if $self->{ quiet } || ! $self->{ verbose };
    $self->event_msg( pass => @_ );
    return 1;
}

sub fail {
    my $self = shift;
    $self->{ stats }->{ fail }++;
    return if $self->{ quiet };
    $self->event_msg( fail => @_ );
    return undef;
}

sub skip {
    my $self = shift;
    $self->{ stats }->{ skip }++;
    return if $self->{ quiet } || ! $self->{ verbose };
    $self->event_msg( skip => @_ );
    return 1;
}

sub warn {
    my $self = shift;
    $self->{ stats }->{ warn }++;
    return if $self->{ quiet };
    $self->event_msg( warn => @_ );
    return 1;
}

sub info {
    my $self = shift;
    return if $self->{ quiet }; # || ! $self->{ verbose };
    $self->event_msg( info => @_ );
    return 1;
}

sub pass_msg {
    my $self = shift;
    $self->pass( $self->message(@_) );
}

sub fail_msg {
    my $self = shift;
    $self->fail( $self->message(@_) );
}

sub skip_msg {
    my $self = shift;
    $self->skip( $self->message(@_) );
}

sub warn_msg {
    my $self = shift;
    $self->warn( $self->message(@_) );
}

sub info_msg {
    my $self = shift;
    $self->info( $self->message(@_) );
}


#-----------------------------------------------------------------------
# summary
#-----------------------------------------------------------------------

sub summary {
    my $self  = shift;
    my $stats = $self->{ stats };
    
    unless ($self->{ quiet }) {
        $self->say_msg( info => "Summary:" );
        $self->say_msg( stat_pass => $stats->{ pass } );
        $self->say_msg( stat_skip => $stats->{ skip } ) if $stats->{ skip };
        $self->say_msg( stat_warn => $stats->{ warn } ) if $stats->{ warn };
        $self->say_msg( stat_fail => $stats->{ fail } ) if $stats->{ fail };
    }
    
#    $self->init_stats;
}     



#-----------------------------------------------------------------------
# help/usage generators for scripts
#-----------------------------------------------------------------------

sub usage {
    my $options = shift->options_summary;
    die <<EOF;
$0 [options]

Options:
$options
EOF
}

sub options_summary {
    return <<EOF;
  -h  --help                    This help
  -v  --verbose                 Verbose mode (extra output)
  -q  --quiet                   Quiet mode (no output)
  -n  --nothing --dry-run       Dry run - no action performed
  -c  --colour --color          Colourful output
  -nc --no-colour --no-color    Uncolourful output
EOF
}


1;
