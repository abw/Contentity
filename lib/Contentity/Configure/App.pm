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
    utils       => 'extend merge red yellow green cyan split_to_list File Cwd',
    accessors   => 'opts args workspace script',
    constant    => {
        APPCONFIG_MODULE => 'AppConfig',
        CODEC            => 'yaml',
        ENCODING         => 'utf8',
        WORKSPACE_MODULE => 'Contentity::Workspace',
        PROMPTER_MODULE  => 'Contentity::Prompter',
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

    # Also note that the $config is a bit of a mess with everything thrown
    # into one hash and passed around the various delegate constructors, 
    # leading to possible parameter collision (e.g. config_file)

    $self->init_config($config);
    $self->init_config_file($config);
    $self->init_config_args($config);

    $self->init_workspace($config);
    $self->init_script($config);
    $self->init_app($config);

    if ($config->{ help }) {
        $self->help;
        exit;
    }

    $self->debug_data("post-init config: ", $self->{ config }) if DEBUG;

    return $self;
}

sub init_config {
    my ($self, $config) = @_;

    # look for any $CONFIG definitions in subclasses and merge into $config
    extend(
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

sub init_config_file {
    my ($self, $config) = @_;

    # ICKY: delete any reference to config_file so we don't confuse delegates 
    # that share the same config.
    my $path = delete($config->{ config_file }) || return;
    my $file = File(
        $path, { 
            codec    => $config->{ codec    } || $self->CODEC,
            encoding => $config->{ encoding } || $self->ENCODING,
        }
    );
    $self->{ config_file } = $file;

    if ($file->exists) {
        $self->load_config_file;
    }
}

sub load_config_file {
    my $self = shift;
    my $file = $self->{ config_file } || return;
    my $data = $file->data;
    $self->debug_data("read config file: $file : ", $data) if DEBUG;
    merge($self->{ data }, $data);
}

sub save_config_file {
    my $self = shift;
    my $file = $self->{ config_file } || return;
    my $data = $self->saveable_data;
    $self->debug_data("writing config file: $file : ", $data) if DEBUG;
    $file->data($data);
}


sub init_config_args {
    my ($self, $config) = @_;
    my $args = $self->{ args } = $config->{ args } || [ ];
    my $appc = $self->appconfig;
    my $arg;

    $appc->args($args)
        || return $self->error($appc->error);

    my $argcfg = { 
        $appc->varlist('.') 
    };

    $self->debug_data( argcfg => $argcfg );

    # merge all command line arguments into the config
    extend($config, $argcfg);
}

sub init_workspace {
    my ($self, $config) = @_;
    # NOTE: 'root' is defined in a saved config file, or via command line 
    # options.  'directory' is typically defined as a config option passed
    # by the calling script as the default.  If none are defined then we 
    # assume it's the current working directory.
    $self->debug("[ROOT:$config->{root}] [DIR:$config->{directory}") if DEBUG;
    my $dir   = $config->{ root      } ||$config->{ directory } || Cwd;
    my $space = $config->{ workspace } || $self->WORKSPACE_MODULE->new(
        root  => $dir,
        quiet => 1,     # may not have a workspace.yaml or project.yaml
    );
    $self->{ workspace } = $space;
    $self->{ directory } = $space->dir;
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


#-----------------------------------------------------------------------------
# Configuration module (AppConfig) for handling command line arguments
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# config() method provides access to 
# and config() method for accessing the resulting configuration values
#-----------------------------------------------------------------------------
sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return @_
        ? $config->{ $_[0] }
        : $config;
}



#-----------------------------------------------------------------------------
# Prompting the user to answer questions is handled by a separate prompter
# object.  We autogenerate various prompt_XXX() methods which delegate to it.
# e.g. 
#   sub prompt_about {
#       shift->prompter->prompt_about(@_);
#   }
#-----------------------------------------------------------------------------

sub prompter {
    my $self = shift;
    return  $self->{ prompter } 
        ||=($self->config->{ prompter } 
        ||  $self->PROMPTER_MODULE->new(
                $self->config
            ));
}

class->methods(
    map { 
        my $name = $_;
        $name => sub {
            shift->prompter->$name(@_);
        }
    }
    qw(
        prompt prompt_expr prompt_newline
        prompt_title prompt_about prompt_action prompt_comment prompt_entry
    )
);


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



#-----------------------------------------------------------------------------
# Scaffolding
#-----------------------------------------------------------------------------

sub scaffold {
    my $self     = shift;
    my $space    = $self->workspace;
    my $scaffold = $space->scaffold( $self->config );
    $scaffold->build;
}

#-----------------------------------------------------------------------------
# Stub for main run method
#-----------------------------------------------------------------------------

sub run {
    my $self = shift;

    # TMP
    if ($self->script) {
        $self->run_script;
        $self->scaffold if $self->config('scaffold');
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


sub saveable_data {
    shift->{ data };
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


#-----------------------------------------------------------------------------
# Help
#-----------------------------------------------------------------------------

sub help {
    my $self = shift;

    $self->prompt_title(
        $self->help_title
    );

    $self->prompt_about( 
        $self->help_about
    );

    $self->prompt_comment(
        $self->help_instructions
    );

    $self->prompt_entry( 
        $self->help_options
    );
}

sub help_title {
    return 'Contentity Command Line Application';
}

sub help_about {
    return <<EOF;
This is the stub help for a Contentity command line application.
It looks like the author neglected to update this text.
EOF
}

sub help_instructions {
    return <<EOF;
The following command line options can be provided.
EOF
}

sub help_options {
    return <<EOF;
    -y / --yes          Accept all defaults
    -n / --nothing      Do nothing (dry run)
    -v / --verbose      Verbose mode
    -q / --quiet        Quiet mode
    -d / --debug        Debugging mode
    -h / --help         This help
EOF
}

__END__

#-----------------------------------------------------------------------------
# OLD STUFF - being merged in from Contentity::Configure
# comment
#-----------------------------------------------------------------------------

    # NOTE: root/directory defined in saved config file may be ignored because
    # of the order of the following initialisers.  It's a bit of a chicken
    # and egg problem.  My real home directory might be /Users/abw/project/cog
    # but I prefer to use the /home/cog/cog alias (symlinked to the above).
    # I expect this preference to be saved in the configuration file so it is
    # remembered the next time I run the bin/configure script.  In this case,
    # it's just a matter of semantics because both names resolve to the same
    # place.  But if the root was defined as somewhere else (perfectly legal
    # if inadvisable) then it does matter.  
    #
    # The preferences are loaded and saved by the workspace configuration 
    # manager, but the workspace needs to be defined with a root directory.
    # Furthermore, a command line argument should over-ride any value saved
    # in the configuration file, implying that the args should be processed
    # before the config file.  But processing the arguments requires access
    # to the script file read from the workspace!
    #
    # So we read the command line argument first - this sets 'root', otherw



==

sub init {
    my $sfile    = $config->{ config_save   } || $self->CONFIG_SAVE;
    my $data     = $config->{ data          } ||= { };

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

    ...

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




