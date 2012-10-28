package Contentity::Project;

use Contentity::Modules;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'params extend weaken',
    filesystem  => 'Dir VFS',
    accessors   => 'root',
    constants   => ':config DOT DELIMITER HASH ARRAY',
    constant    => {
        MODULE_FACTORY => 'Contentity::Modules',
    };
 #   auto_can    => 'auto_can';



#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    my $root_dir     = $config->{ root            } || return $self->error_msg( missing => 'root' );
    my $cfg_dir      = $config->{ config_dir      } || $self->CONFIG_DIR;
    my $cfg_file     = $config->{ config_file     } || $self->CONFIG_FILE;
    my $cfg_codec    = $config->{ config_codec    } || $self->CONFIG_CODEC;
    my $cfg_encoding = $config->{ config_encoding } || $self->CONFIG_ENCODING;
    my $cfg_filespec = {
        codec    => $cfg_codec,
        encoding => $cfg_encoding,
    };
    my $cfg_defaults = {
        resources_dir => $self->RESOURCES_DIR,
    };

    $root_dir = Dir($root_dir)->must_exist;
    $cfg_dir  = $root_dir->dir($cfg_dir, $cfg_filespec)->must_exist;
    $cfg_file = $cfg_dir->file($cfg_file)->must_exist;
    $config   = extend(
        # Merge contentity defaults with config file parameters and finally
        # the configuration parameters.  Values defined in successive 
        # configurations will replace those in earlier ones, e.g. 
        # a value for 'resources_dir' defined in the config file will replace
        # the default value defined in RESOURCE_DIR, but a value defined in 
        # $config will override that.
        $cfg_defaults, 
        $cfg_file->data, 
        $config
    );

    $self->{ root            } = $root_dir;
    $self->{ config_dir      } = $cfg_dir;
    $self->{ config_file     } = $cfg_file;
    $self->{ config_codec    } = $cfg_codec;
    $self->{ config_encoding } = $cfg_encoding;
    $self->{ config_filespec } = $cfg_filespec;
    $self->{ config          } = $config;

    return $self
        ->init_project($config)
        ->init_modules($config);
}


sub init_project {
    my ($self, $config) = @_;
    $self->debug("init_project() : ", $self->dump_data($config)) if DEBUG;

    my $rtype     = $self->{ resource_type } = { };
    my $resources = $config->{ resources };
    my $resource;

    foreach $resource (@$resources) {
        # TODO: check args that may specify different file specs, etc.
        # singular, plural
    }

    return $self;
}


sub init_modules {
    my ($self, $config) = @_;
    my $modules = $config->{ modules } || return;
    my $module;

    # text string is split to a list reference, 
    # e.g. 'database sitemap' => ['database','sitemap']
    $modules = [ split(DELIMITER, $modules) ]
        unless ref $modules;

    # a list reference is mapped to a hash reference of hash refs
    # e.g. ['database','sitemap'] => { database => { }, sitemap => { } }
    $modules = { 
        map { $_ => { } }
        @$modules
    }   if ref $modules eq ARRAY;

    # if it isn't a hash ref by this point then we can't handle it
    return $self->error_msg( invalid => modules => $module )
        unless ref $modules eq HASH;

    # modules can be set to any simple true value to enable them (e.g. 1) or 
    # a false value to explicitly disable them (e.g. 0)
    $self->{ modules } = {
        map {
            $module = $modules->{ $_ };
            ref $module ? ( $_ => $module )     # leave as is
              : $module ? ( $_ => { }     )     # change true value to hash
              : ( )                             # ignore false values
        }
        keys %$modules
    };

    return $self;
}


#-----------------------------------------------------------------------------
# General purpose methods
#-----------------------------------------------------------------------------

sub dir {
    my $self = shift;

    return @_
        ? $self->root->dir(@_)
        : $self->root;
}


#-----------------------------------------------------------------------------
# Methods for loading configuration files
#-----------------------------------------------------------------------------

sub config_filename {
    my ($self, $name) = @_;
    return $name.DOT.$self->{ config_codec };
}


sub config_file {
    my $self = shift;
    return @_
        ? $self->{ config_dir  }->file(@_)->must_exist
        : $self->{ config_file };
}


sub config_data {
    my ($self, $name) = @_;

    return $self->config_file(
        $self->config_filename($name)
    )->data;
}


sub config_filespec {
    my $self     = shift;
    my $defaults = $self->{ config_filespec };

    return @_ 
        ? extend({ }, $defaults, @_)
        : { %$defaults };
}


#-----------------------------------------------------------------------------
# Methods for loading resources
#-----------------------------------------------------------------------------

sub resources_dir {
    my $self = shift;
    my $rdir = $self->{ resources_dir } ||= $self->dir(
        $self->{ config }->{ resources_dir }
    )->must_exist;

    return @_
        ? $rdir->dir(@_)
        : $rdir;
}


sub resource_dir {
    my ($self, $type, @spec) = @_;

    return  $self->{"${type}_resource_dir"} 
        ||= $self->resources_dir(
                $type,
                $self->config_filespec(@spec)
            )->must_exist;
}


sub resource_file {
    my ($self, $type, @file) = @_;

    return $self
        ->resource_dir($type)
        ->file(@file)
        ->must_exist;
}


sub resource_data {
    return shift
        ->resource_file(@_)
        ->data
}


#-----------------------------------------------------------------------------
# Methods for loading extension modules
#-----------------------------------------------------------------------------

sub module {
    my $self = shift;
    my $type = shift;

    return  $self->{ module }->{ $type }
        ||= $self->load_module( $type => @_ );
}


sub has_module {
    my $self = shift;
    my $type = shift;
    return $self->{ modules }->{ $type };
}


sub load_module {
    my $self    = shift;
    my $type    = shift;
    my $config  = $self->module_config( $type => @_ );
    my $factory = $self->module_factory;

    return $factory->item(
        $type => $config
    );

    $self->debug("TODO: load_module\n")
}


sub module_config {
    my $self     = shift;
    my $type     = shift;
    my $params   = params(@_);
    my $module   = $self->{ modules }->{ $type }
        || return $self->error_msg( invalid => module => $type );
    my $master   = $self->{ config }->{ $type };
    my $merged   = extend({ module => $type }, $module, $master, $params);
    my $cfg_file = $merged->{ config_file } || $self->config_filename($type);
    my $cfg_data = $self->config_file($cfg_file)->data;

    my $config   = extend($cfg_data, $merged);

    $self->debug(
        "config for module $type:\n",
        "- Module config ($self->{ config_file }/modules/$type): ", $self->dump_data($module), "\n",
        "- Master config ($type): ", $self->dump_data($master), "\n",
        "- Local params (module_config(...)): ", $self->dump_data($params), "\n",
        "= Merged config ({} < module < master < local): ", $self->dump_data($merged), "\n",
        "- Config file ($cfg_file): ", $self->dump_data($cfg_file), "\n",
        "= Fully merged (file < merged): ", $self->dump_data($config), "\n",
    ) if DEBUG;

    $config->{ project } = $self;

    return $config;
}


sub module_factory {
    my $self = shift;

    return  $self->{ module_factory }
        ||= $self->MODULE_FACTORY->new(
                path => $self->{ config }->{ module_path }
            );
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ module  };
    delete $self->{ modules };
    $self->debug("project is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}

1;

__END__

=head1 INITIALISATION METHODS

These methods are used internally to initialise the C<Contentity::Project>
object.

=head2 init(\%config)

=head2 init_project(\%merged_config)

=head2 init_modules(\%merged_config)

=head1 PUBLIC METHODS

These methods are provided for general purpose use.

=head2 dir($path)

Returns a L<Badger::Filesystem::Directory> object representing a directory
under the project root directory denoted by the C<$path> argument (or 
arguments).  Returns the root directory object when called without any 
arguments.

    my $root   = $project->dir;
    my $images = $project->dir('images');

=head2 resources_dir($path)

Returns a L<Badger::Filesystem::Directory> object for the directory in 
which resource data files are stored.  This is defined via the 
C<resources_dir> configuration option and is usually specified relative 
to the project root directory (C<resources> by default).  If one or more
C<$path> arguments are specified then it returns a directory underneath 
the resources directory, in a similar fashion to L<dir()>.

    my $resources = $project->resources_dir;
    my $forms     = $project->resources_dir('forms');
    my $widgets   = $project->resources_dir('ui/widgets');

=head2 resource_dir($type,$spec)

This is a more strict wrapper around L<resources_dir()> which provides
additional configuration parameters (from L<config_filespec()>) and asserts 
that the directory exists.  It caches the directory object for subequent use.
This should generally be used in preference to L<resources_dir()>.

    my $forms = $project->resource_dir('forms');

=head2 config_filespec($params)

Returns a reference to a hash array containing appropriate initialisation
parameters for L<Badger::Filesystem::File> objects created to read  general
and resource-specific configuration files.  The parameters are  constructed
from the C<config_codec> (default: C<yaml>) and C<config_encoding> (default:
C<utf8>) configuration options.  These can be overridden or augmented by extra
parameters passed as arguments.


