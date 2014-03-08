package Contentity::Configure::App;

use AppConfig;
use Contentity::Prompter;
use Contentity::Workspace;
use Contentity::Configure::Script;
use Contentity::Class
    version     => 0.02,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'extend red yellow green cyan split_to_list Bin',
    accessors   => 'opts args prompter workspace script',
    constant    => {
        APPCONFIG_MODULE => 'AppConfig',
        WORKSPACE_MODULE => 'Contentity::Workspace',
        PROMPTER_MODULE  => 'Contentity::Prompter',
        #CONFIG_SAVE      => 'config_save',
        SCRIPT_MODULE    => 'Contentity::Configure::Script',
        SCAFFOLD_MODULE  => 'Contentity::Configure::Scaffold',
    };

our $CMD_ARGS = [
#    'all|a!',
    'yes|y!',
    'verbose|v!',
    'quiet|q!',
    'nothing|n!',
    'debug|d!',
    'help|h!',
];


sub init {
    my ($self, $config) = @_;

    # NOTE: root/directory defined in saved config file may be ignored because
    # of the order of the following

    #$self->extend($config);

    $self->init_config($config);
    $self->init_args($config);
    $self->init_workspace($config);
    $self->init_script($config);
    $self->init_prompter($config);
    $self->init_app($config);

    if ($config->{ help }) {
        print $self->help;
        exit;
    }

    $self->debug_data("post-init config: ", $self->{ config }) if DEBUG;

    return $self;
}

sub init_config {
    my ($self, $config) = @_;

    # look for any $CONFIG definitions in subclasses and merge into $config
    $config = extend(
        $config,
        $self->class->hash_vars('CONFIG'),
        $config
    );

    $self->{ config } = $config;
    $self->{ data   } = $config->{ data } ||= { };

    $self->debug(
        "extended config: ", 
        $self->dump_data($config)
    ) if DEBUG;
}

sub init_prompter {
    my ($self, $config) = @_;
    $self->{ prompter } = $config->{ prompter } || $self->PROMPTER_MODULE->new(
        $config
    );
}

sub init_workspace {
    my ($self, $config) = @_;
    my $dir   = $config->{ directory } || Bin;
    my $space = $config->{ workspace } || $self->WORKSPACE_MODULE->new(
        root  => $dir,
        quiet => 1,     # may not have a workspace.yaml or project.yaml
    );
    $self->{ workspace } = $space;
    $self->{ directory } = $space->dir;
}

sub init_args {
    my ($self, $config) = @_;
    my $args = $self->{ args } = $config->{ args };
    my $opts = $self->{ opts } = { };
    my $arg;

    return unless $args;

    my $appc = $self->appconfig;

    $appc->args($args)
        || return $self->error($appc->error);

    my $vars = { $appc->varlist('.') };
    $self->dump_data("merging ", $self->dump_data($vars), " into ", $self->dump_data($config));
    extend($config, $vars);

    $self->debug("args: ", $self->dump_data($args)) if DEBUG;
}


sub init_script {
    my ($self, $config) = @_;
    my $script = $config->{ script } || return;
    my $space  = $self->workspace;
    my $sdata  = $space->config($script)
        || return $self->error_msg( invalid => script => $script );

    $self->debug_data("script data: ", $sdata) if DEBUG;

    local $config->{ script } = $sdata;

    $self->{ script } = $self->SCRIPT_MODULE->new($config);
    $self->{ option } = $self->script->option;
}


sub init_app {
    my $self   = shift;
    my $config = $self->config;
    my $opts   = $self->opts;
    $self->debug_data("init_app() CONFIG: ", $config) if DEBUG;
    $self->debug_data("init_app() OPTIONS: ", $opts)  if DEBUG;
    # stub for subclasses
}


sub appconfig {
    my $self = shift;

    return $self->{ appconfig } ||= AppConfig->new(
        $self->appconfig_config
    );
}

sub appconfig_config {
    my $self = shift;
    return @{ 
        $self->class->list_vars('CMD_ARGS') 
    };
}

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return @_
        ? $config->{ $_[0] }
        : $config;
}


#-----------------------------------------------------------------------------
# Stub for main run method
#-----------------------------------------------------------------------------

sub run {
    my $self = shift;

    # TMP
    if ($self->script) {
        $self->run_script;
    }
    else {
        # must be implemented by subclasses
        $self->not_implemented('in base class');
    }
}

sub run_script {
    my $self = shift;
    my $script = $self->script
        || return $self->error_msg( missing => 'script' );

    $script->run($self);

    $self->debug_data("DATA: ", $self->{ data }) if DEBUG;
}



#-----------------------------------------------------------------------------
# Data methods for getting and setting configuration options
#-----------------------------------------------------------------------------

sub set {
    my ($self, $path, $value) = @_;
    my $data  = $self->{ data } ||= { };
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
    my $data = $self->{ data } ||= { };
    foreach my $part (@$path) {
        $data = $data->{ $part } || return;
    }
    return $data;
}

sub zap {
    my ($self, $path, $src) = @_;
    my $data  = $src || ($self->{ data } ||= { });
    my @parts = @$path;
    my $name  = pop @parts;
    $self->debug("zap [", join('].[', @parts, $name), "]") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } || return;
    }
    delete $data->{ $name };
}


#-----------------------------------------------------------------------------
# Shortcuts to command line options
#
# Autogenerate various methods which delegate to items in the config
# e.g.
#   sub verbose {
#       shift->config->{ verbose };
#   }
#-----------------------------------------------------------------------------

#sub all {
#    shift->config->{ yes };
#}
#

class->methods(
    map { 
        my $name = $_;
        $name => sub {
            shift->config->{ $name };
        }
    }
    qw(
        yes verbose quiet nothing
    )
);

sub dry_run {
    # old alias for 'nothing'
    shift->config->{ nothing };
}

#-----------------------------------------------------------------------------
# Shortcuts to prompter methods
#
# Autogenerate various prompt_XXX() methods which delegate to the prompter,
# e.g. 
#   sub prompt_about {
#       shift->prompter->prompt_about(@_);
#   }
#-----------------------------------------------------------------------------

class->methods(
    map { 
        my $name = $_;
        $name => sub {
            shift->prompter->$name(@_);
        }
    }
    qw(
        prompt
        prompt_title prompt_about prompt_action prompt_expr prompt_newline
    )
);


sub help {
    my $self = shift;
    my $help = $self->help_text;
    my $opts = $self->help_options;
    return <<EOF;
$help
Options can be specified in either short (e.g. '-a') or long (e.g. '--all')
form.

$opts
EOF
}

sub help_text {
    return <<EOF;
Contentity Command Line Application

This is the stub help for a Contentity command line application.
It looks like the author neglected to update this text.
EOF
}

sub help_options {
    return <<EOF;
    -y      --yes       Accept all defaults
    -n      --nothing   Do nothing (dry run)
    -v      --verbose   Verbose mode
    -q      --quiet     Quiet mode
    -d      --debug     Debugging mode
    -h      --help      This help
EOF
}

sub prompt_instructions {
    my $self = shift;
    $self->prompter->prompt_instructions(
        "Please answer the following questions to configure the system.\n"
    );
}

#-----------------------------------------------------------------------------
# Old stuff pasted in as a temporary measure
#-----------------------------------------------------------------------------

sub option_prompt {
    my ($self, $name, $option) = @_;
    return if defined $option->{ prompt } && ! $option->{ prompt };

    my $cmdargs = $option->{ cmdargs   } || '';
    my $title   = $option->{ title     } || '';
    my $path    = $option->{ path      };
    my $default = $option->{ default   };
    my $value   = $self->get($path); # || $option->{ default };

    $self->debug("VALUE: [$value]  DEFAULT: [$default]") if DEBUG;

    local $option->{ value } = $value || $default;
  
    my $result  = $self->prompt($title, $option->{ value }, $option);

    $self->debug_data("got [$result] for ", $path) if DEBUG;
  
    $self->set($path, $result);
}





__END__

#-----------------------------------------------------------------------------
# OLD STUFF - being merged in from Contentity::Configure
# comment
#-----------------------------------------------------------------------------
==

sub init {
    my $sfile    = $config->{ config_save   } || $self->CONFIG_SAVE;
    my $data     = $config->{ data          } ||= { };


    # quick hack to set quite/verbose mode ahead of full config read
    if ($args) {
        $self->{ verbose } = grep { /^--?v(erbose)?$/ } @$args;
        $self->{ quiet   } = grep { /^--?q(uiet)?$/   } @$args;
        $self->{ white   } = grep { /^--?w(hite)?$/   } @$args;
        $self->{ reset   } = grep { /^--?r(eset)?$/   } @$args;
    }

    # set the current root directory, but note that it may be modified by 
    # a value set in config/config_save.yaml
    $data->{ root } ||= $root->definitive;

    if ($sfile && ! $self->{ reset }) {
        my $lastrun = $space->config->get($sfile);
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

sub note {
    my $self = shift;
    return if $self->{ quiet };
    print STDERR yellow("NOTE: "), cyan(@_), "\n";
}

1;

__END__
