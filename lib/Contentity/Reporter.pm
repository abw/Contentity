package Contentity::Reporter;

use Contentity::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Reporter Contentity::Base',
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
    {
        name    => 'pass',
        colour  => 'green',
        message => "%s",
        verbose => 1,
        summary => 1,
    },
    {
        name    => 'fail',
        colour  => 'red',
        message => "%s",
        summary => 1,
    },
    {
        name    => 'skip',
        colour  => 'yellow',
        message => '%s',
        verbose => 1,
        summary => 1,
    },
    {
        name    => 'warn',
        colour  => 'yellow',
        message => '%s',
    },
    {
        name    => 'info',
        colour  => 'cyan',
        message => '%s',
        summary => '',
    },
];

# OLD
our $MESSAGES = {
    stat_pass   => '%5d successful operations',
    stat_fail   => '%5d failed operations',
    stat_skip   => '%5d skipped operations',
    stat_warn   => '%5d warnings',
};

our $COLOURS = {
    stat_pass => \&green,
    stat_fail => \&red,
    stat_skip => \&yellow,
    stat_warn => \&bold_red,
    stat_info => \&blue,
};

sub bold_red {
    bold red @_;
}



sub OLD_options_summary {
    return <<EOF;
  -h  --help                    This help
  -v  --verbose                 Verbose mode (extra output)
  -p  --progress                Progress mode
  -q  --quiet                   Quiet mode (no output)
  -n  --nothing --dry-run       Dry run - no action performed
  -c  --colour --color          Colourful output
  -nc --no-colour --no-color    Uncolourful output
EOF
}


1;
