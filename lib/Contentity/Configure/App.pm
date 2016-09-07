package Contentity::Configure::App;

use AppConfig;
use Contentity::Prompter;
use Contentity::Workspace;
use Contentity::Configure::Script;
use Contentity::Class
    version     => 0.02,
    debug       => 0,
    base        => 'Contentity::Base Badger::Workplace',
    import      => 'class',
    utils       => 'extend merge Dir File Cwd',
    accessors   => 'root option args',
    constants   => 'ARRAY',
    constant    => {
        CODEC       => 'yaml',
        ENCODING    => 'utf8',
        APPCONFIG   => 'AppConfig',
        WORKSPACE   => 'Contentity::Workspace',
        PROMPTER    => 'Contentity::Prompter',
        SCRIPT      => 'Contentity::Configure::Script',
    },
    messages => {
        bad_args => 'Error processing command line arguments: %s',
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

    # Note that the $config is a bit of a mess with everything thrown
    # into one hash and passed around the various delegate constructors,
    # leading to possible parameter collision

    $self->init_config($config);
    $self->init_args($config);
    $self->init_app($config);

    if ($config->{ help }) {
        $self->help;
    }

    if (DEBUG) {
        $self->debug_data("post-init config: ", $self->{ config });
        $self->debug_data("post-init data: ", $self->{ data });
    }

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

    my $root = $config->{ root } || $config->{ directory } || Cwd;

    $self->{ root   } = Dir($root);
    $self->{ data   } = $config->{ data } ||= { };
    $self->{ config } = $config;

    $self->load_data_file;

    $self->debug(
        "extended config: ",
        $self->dump_data($config)
    ) if DEBUG;
}

sub init_args {
    my ($self, $config) = @_;
    my $args = $self->{ args } = $config->{ args } || [ ];
    my $appc = $self->appconfig;
    my $arg;

    $self->debug_data("init_args()", $args) if DEBUG;

    $appc->args($args)
        || return $self->help;
}

sub init_app {
    # stub for subclasses
}


#-----------------------------------------------------------------------------
# config() method provides access to the central configuration hash $config,
# as passed to the init() method.  This is where we store the runtime
# configuration options for the object.  Additional data (including the
# questions we might want to ask the user, and the answers they provide are
# store in separate configuration files and/or data hashes)
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return @_
        ? $config->{ $_[0] }
        : $config;
}


#-----------------------------------------------------------------------------
# Autogenerate various shortcut methods which delegate to items in the config
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
# Generic methods for loading and saving configuration files
#-----------------------------------------------------------------------------

sub config_file {
    my $self = shift;
    my $path = shift || return $self->error_msg( missing => 'config_file' );
    return $self->root->file($path, $self->config_filespec);
}

sub config_filespec {
    my $self = shift;
    return  $self->{ filespec }
        ||= {
                codec    => $self->config->{ codec    } || $self->CODEC,
                encoding => $self->config->{ encoding } || $self->ENCODING,
            };
}

#-----------------------------------------------------------------------------
# The script is a configuration file containing all the questions that need
# answering.  The file also defines those values that can be set via command
# line arguments.
#-----------------------------------------------------------------------------

sub script {
    my $self = shift;
    return  $self->{ script }
        ||= $self->load_script;
}

sub load_script {
    my $self   = shift;
    my $config = $self->config;
    my $script = $config->{ script } || return;
    my $sdata  = $self->config_file($script)->data;

    $self->debug_data("script data: ", $sdata) if DEBUG;
    local $config->{ script } = $sdata;

    return $self->SCRIPT->new($config);
}


#-----------------------------------------------------------------------------
# The data_file is where we store the answers that the user gives to the
# questions asked.  This is loaded (if it exists) at the start and saved at
# the end of the configuration process
#-----------------------------------------------------------------------------

sub data_file {
    my $self = shift;
    return  $self->{ data_file }
        ||= $self->config_file( $self->config->{ data_file } || return );
}

sub load_data_file {
    my $self = shift;
    my $file = $self->data_file || return;
    return unless $file->exists;
    my $data = $file->data;
    $self->debug_data("read config file: $file : ", $data) if DEBUG;
    merge($self->{ data }, $data);
}

sub save_data_file {
    my $self = shift;
    my $file = $self->data_file || return;
    my $data = $self->save_data;
    $self->debug_data("writing config file: $file : ", $data) if DEBUG;
    $file->data($data);
}

sub save_data {
    # We save all data by default, subclasses may redefine to filter it
    shift->{ data };
}


#-----------------------------------------------------------------------------
# Methods for getting, setting and deleting data values (including nested)
#-----------------------------------------------------------------------------

sub get {
    my ($self, $path) = @_;
    my $data = $self->{ data } ||= { };
    foreach my $part (@$path) {
        $data = $data->{ $part } || return;
    }
    return $data;
}

sub set {
    my ($self, $path, $value) = @_;
    my $data  = $self->{ data } ||= { };
    my @parts = ref $path eq ARRAY ? @$path : $path;
    my $name  = pop @parts;
    $self->debug("set [", join('].[', @parts, $name), "] => $value") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } ||= { };
    }
    $data->{ $name } = $value;
}

sub zap {
    my ($self, $path, $src) = @_;
    my $data  = $src || ($self->{ data } ||= { });
    my @parts = ref $path eq ARRAY ? @$path : $path;
    my $name  = pop @parts;
    $self->debug("zap [", join('].[', @parts, $name), "]") if DEBUG;
    foreach my $part (@parts) {
        $data = $data->{ $part } || return;
    }
    delete $data->{ $name };
}


#-----------------------------------------------------------------------------
# Configuration module (AppConfig) for handling command line arguments.
# This is a temporary measure until Contentity::Configure::Script can
# handle it.
#-----------------------------------------------------------------------------

sub appconfig {
    my $self = shift;

    return $self->{ appconfig } ||= $self->APPCONFIG->new(
        $self->appconfig_config
    );
}

sub appconfig_config {
    my $self = shift;
    return $self->script
        ? $self->script_appconfig_args
        : $self->config_appconfig_args;
}

sub config_appconfig_args {
    my $self = shift;
    my $cmds = $self->class->list_vars('CMD_ARGS');
    return (
        map {
            $_ => {
                # each of the CMD_ARGS sets a value in $self->{ config }
                ACTION => sub {
                    my ($state, $var, $val) = @_;
                    $self->debug("CMD SET $var => $val") if DEBUG;
                    $self->{ config }->{ $var } = $val;
                }
            }
        }
        @$cmds
    );
}

sub script_appconfig_args {
    my $self   = shift;
    my $script = $self->script || return ();
    my $option = $script->option;
    my $seen   = { };
    my (@args, $key, $value);

    while (($key, $value) = each %$option) {
        my $long   = $value->{ option };
        my $short  = $value->{ short  };
        my $path   = $value->{ path   } || next;
        my $is_cfg = $value->{ is_config };

        next if $seen->{ $long };
        $seen->{ $long } = 1;

        my $spec = { };

        $spec->{ ARGCOUNT } = $value->{ is_flag } ? 0 : 1;
        $spec->{ ALIAS    } = $short if $short;
        $spec->{ DEFAULT  } = $value->{ default };
        $spec->{ ACTION   } = sub {
            # each of the items in the script sets a value in $self->{ data }
            my ($state, $var, $val) = @_;
            if ($is_cfg) {
                $self->debug_data("config [$var] to [$val] via ", $path) if DEBUG;
                $self->{ config }->{ $var } = $val;
            }
            else {
                $self->debug_data("set [$var] to [$val] via ", $path) if DEBUG;
                $self->set($path, $val);
            }
        };
        push(@args, $long => $spec);
    }

    return @args;
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
        ||  $self->PROMPTER->new(
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
        prompt prompt_list prompt_expr prompt_newline prompt_error
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
    my $list    = $option->{ list      };
    my $prepare = $option->{ prepare   };
    my $value   = $self->get($path); # || $option->{ default };
    my $result;

    if (DEBUG) {
        $self->debug_data( path => $path );
        $self->debug("$name VALUE: [$value]  DEFAULT: [$default]");
    }

    # call prepare method if there is one
    $self->$prepare($option) if $prepare;

    local $option->{ value } = $value || $default;

    if ($list) {
        $self->debug_data("found a list for $name" => $option ) if DEBUG;
        $result = $self->prompt_list($list, $option->{ value }, $option);
    }
    else {
        $result = $self->prompt($title, $option->{ value }, $option);
        $self->prompt_newline;
    }

    $self->debug_data("got [$result] for ", $path) if DEBUG;

    $self->set($path, $result);
}


#-----------------------------------------------------------------------------
# The configuration app is primarily intended for configuring workspaces of
# different types: projects, sites, portfolios, etc.
# This is handled by a workspace component, Contentity::Component::Scaffold
#-----------------------------------------------------------------------------

sub workspace {
    my $self = shift;
    return  $self->{ workspace }
        ||= $self->init_workspace;
}

sub init_workspace {
    my $self   = shift;
    my $config = $self->config;

    # NOTE: 'root' is defined in a saved config file, or via command line
    # options.  'directory' is typically defined as a config option passed
    # by the calling script as the default.  If none are defined then we
    # assume it's the current working directory.
    $self->debug("[ROOT:$config->{root}] [DIR:$config->{directory}") if DEBUG;

    my $dir   = $config->{ root      } || $config->{ directory } || Cwd;
    my $space = $config->{ workspace } || $self->WORKSPACE->new(
        root  => $dir,
        quiet => 1,     # may not have a workspace.yaml or project.yaml
    );
    $self->{ workspace } = $space;

    my $rent = $config->{ data }->{ parent };
    if ($rent) {
        my $base = $self->WORKSPACE->new(
            root => $rent,
        );
        $self->debug("attaching to parent: $rent => $base") if DEBUG;
        $space->attach($base);
    }
    return $space;
}



#-----------------------------------------------------------------------------
# Scaffolding is the processes of generating configuration files, etc.
# This is handled by a workspace component, Contentity::Component::Scaffold
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
        $self->save_data_file;
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

    if ($self->script) {
        $self->help_script_options;
    }
    else {
        $self->prompt_entry(
            $self->help_options
        );
    }

    exit;
}

sub help_script_option {
    my ($self, $option, $default) = @_;
    my $script = $self->script || return $default;
    return $script->$option || $default;
}

sub help_title {
    shift->help_script_option( title => "Contentity Command Line Application" );
}

sub help_about {
    shift->help_script_option( about => "" );
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

sub help_script_options {
    my $self   = shift;
    my $script = $self->script || return '';

    #$self->debug_data( script => $script );

    return join('', $self->help_script_option_items($script->items));
}

sub help_script_option_items {
    my ($self, $items) = @_;
    return
        map { $self->help_script_option_item($_) }
        @$items;
}

sub help_script_option_item {
    my ($self, $item) = @_;
    my $type = $item->{ type } || '';

    if ($type eq 'section') {
        return $self->help_script_option_section($item);
    }
    my $long  = $item->{ option } || return;
    my $short = $item->{ short  };
    my $title = $item->{ title  };

    $self->prompt_help_option($long, $short, $title);
}

sub prompt_help_option {
    my ($self, $long, $short, $title) = @_;
    my $slen   = $short ? length $short : 0;
    my $llen   = length $long;
    my $len    = $llen + 2;               # --$long
       $len   += ($slen + 4) if $slen;       # -$short / <long>
    my $pad    = 20 - $len;
    my $prompt = $self->prompter;
    my @bits;

    push(
        @bits,
        $prompt->col_expr([
            [cmd_dash => '-'],
            [cmd_arg  => $short],
            [cmd_alt  => ' / '],
        ])
    ) if $short;

    push(
        @bits,
        $prompt->col_expr([
            [cmd_dash => '--'],
            [cmd_arg  => $long]
        ]),
        ' ' x $pad,
        $prompt->col(
            cmd_title => $title
        )
    );
    print "    ", @bits, "\n";
}

sub help_script_option_section {
    my ($self, $item) = @_;
    my $items  = $item->{ items } || return;
    $self->prompt_title( $item->{ title } );
    $self->help_script_option_items($items);
    $self->prompt_newline;
}



__END__
==


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
