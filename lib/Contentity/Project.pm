package Contentity::Project;

use Contentity::Components;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'params extend weaken resolve_uri',
    filesystem  => 'Dir VFS',
    accessors   => 'root config',
    auto_can    => 'auto_can',
    constants   => ':config DOT DELIMITER HASH ARRAY',
    constant    => {
        COMPONENT_FACTORY => 'Contentity::Components',
    },
    messages => {
        load_fail => 'Failed to load data from %s: %s',
        no_config => 'No configuration file or directory for %s',
    };
 #   auto_can    => 'auto_can';



#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    my $root_dir     = $config->{ root             } || return $self->error_msg( missing => 'root' );
    my $cfg_dir      = $config->{ config_dir       } || $self->CONFIG_DIR;
    my $cfg_file     = $config->{ config_file      } || $self->CONFIG_FILE;
    my $cfg_codec    = $config->{ config_codec     } || $self->CONFIG_CODEC;
    my $cfg_ext      = $config->{ config_extension } || $self->CONFIG_EXTENSION || $cfg_codec;
    my $cfg_encoding = $config->{ config_encoding  } || $self->CONFIG_ENCODING;
    my $cfg_filespec = {
        codec    => $cfg_codec,
        encoding => $cfg_encoding,
    };
    my $cfg_defaults = {
        resources_dir => $self->RESOURCES_DIR,
    };

    $root_dir = Dir($root_dir)->must_exist;
    $cfg_dir  = $root_dir->dir($cfg_dir, $cfg_filespec)->must_exist;

    # set this lot up early so we can load further config files
    my $qm_ext = quotemeta $cfg_ext;
    my $ext_re = qr/.$cfg_ext$/i;

    $self->{ uri              } = $config->{ uri } || $root_dir->name;
    $self->{ root             } = $root_dir;
    $self->{ config_dir       } = $cfg_dir;
    $self->{ config_file      } = $cfg_file;
    $self->{ config_codec     } = $cfg_codec;
    $self->{ config_encoding  } = $cfg_encoding;
    $self->{ config_filespec  } = $cfg_filespec;
    $self->{ config_extension } = $cfg_ext;
    $self->{ config_match_ext } = $ext_re;

    my $cfg_data = $self->config_data($cfg_file);

    $config = $self->{ config } = extend(
        # Merge contentity defaults with config file parameters and finally
        # the configuration parameters.  Values defined in successive 
        # configurations will replace those in earlier ones, e.g. 
        # a value for 'resources_dir' defined in the config file will replace
        # the default value defined in RESOURCE_DIR, but a value defined in 
        # $config will override that.
        $cfg_defaults, 
        $cfg_data, 
        $config
    );

    return $self
        ->init_project($config)
        ->init_components($config)
        ->init_resources($config)
}


sub init_project {
    my ($self, $config) = @_;
    $self->debug("init_project() : ", $self->dump_data($config)) if DEBUG;
    return $self;
}

sub init_components {
    my ($self, $config) = @_;
    my $comps = $config->{ components } || return $self;

    $self->{ components } = $self->prepare_components($comps);

    return $self;
}

sub init_resources {
    my ($self, $config) = @_;
    my $resources = $config->{ resources }                || return $self;
    my $rcomps    = $self->prepare_components($resources) || return $self;
    my $comps     = $self->{ components };
    my $singles   = $self->{ resource   } = { };
    my $plurals   = $self->{ resources  } = { };
    my ($key, $value, $single, $plural, $component);

    if ($comps) {
        # merge resource components into regular components
        $self->{ components } = { %$comps, %$rcomps };
        $self->debug(
            "Merged components+resources: ", 
            $self->dump_data($self->{ components })
        ) if DEBUG;
    }
    else {
        # we only have resources, no components
        $self->{ components } = $rcomps;
    }

    while (($key, $value) = each %$rcomps) {
        $component = $self->component($key);
        $single    = $component->resource;
        $plural    = $component->resources;
        $singles->{ $single } = $component;
        $plurals->{ $plural } = $component;
    }

    if (DEBUG) {
        $self->debug(
            "single resources: ", $self->dump_data($self->{ resource }), "\n",
            "plural resources: ", $self->dump_data($self->{ resources }), "\n",
        );
    }

    return $self;
}

sub prepare_components {
    my ($self, $components) = @_;
    my $component;

    # text string is split to a list reference, 
    # e.g. 'database sitemap' => ['database','sitemap']
    $components = [ split(DELIMITER, $components) ]
        unless ref $components;

    # a list reference is mapped to a hash reference of hash refs
    # e.g. ['database','sitemap'] => { database => { }, sitemap => { } }
    $components = { 
        map { $_ => { } }
        @$components
    }   if ref $components eq ARRAY;

    # if it isn't a hash ref by this point then we can't handle it
    return $self->error_msg( invalid => components => $components )
        unless ref $components eq HASH;

    # components can be set to any simple true value to enable them (e.g. 1) or 
    # a false value to explicitly disable them (e.g. 0)
    return {
        map {
            $component = $components->{ $_ };
            ref $component ? ( $_ => $component )     # leave as is
              : $component ? ( $_ => { }     )     # change true value to hash
              : ( )                             # ignore false values
        }
        keys %$components
    };
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

sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ uri }, @_)
        : $self->{ uri };
}


#-----------------------------------------------------------------------------
# Methods for loading configuration files
#-----------------------------------------------------------------------------

sub config_dir {
    my $self = shift;
    my $dir  = $self->{ config_dir };
    return @_
        ? $dir->dir(@_)
        : $dir;
}

sub config_filename {
    my ($self, $name) = @_;
    return $name.DOT.$self->{ config_extension };
}

sub config_file {
    my $self = shift;
    return @_
        ? $self->{ config_dir  }->file(@_)
        : $self->{ config_file };
}

sub config_data {
    my ($self, $name) = @_;
    my $path = $self->config_filename($name);
    my $file = $self->config_file($path);
    my $data = $file->try->data;
    return $@
        ? $self->error_msg( load_fail => $file => $@ )
        : $data;
}

sub config_filespec {
    my $self     = shift;
    my $defaults = $self->{ config_filespec };

    return @_ 
        ? extend({ }, $defaults, @_)
        : { %$defaults };
}

sub config_uri_tree {
    my ($self, $name) = @_;
    return $self->config_tree($name, $self->can('uri_binder'));
}

sub config_tree {
    my ($self, $name, $binder) = @_;
    my $confdir = $self->config_dir;
    my $file    = $self->config_file( $self->config_filename($name) );
    my $dir     = $confdir->dir($name);
    my $data;

    if ($file->exists) {
        $data = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
    }
    elsif ($dir->exists) {
        $data = { };
    }
    else {
        return $self->error_msg( no_config => $name );
    }

    # if the master metadata file is empty then $data could be undefined
    $data ||= { };

    if ($file->exists) {
        $self->debug("Read metadata from file: ", $file) if DEBUG;
    }
    if ($dir->exists) {
        # create a virtual file system rooted on the metadata directory
        # so that all file paths are resolved relative to it
        my $vfs = VFS->new( root => $dir );
        $self->debug("Reading metadata from dir: ", $dir->name) if DEBUG;
        $self->scan_config_dir($vfs->root, $data, $binder);
    }

    $self->debug("$name config: ", $self->dump_data($data)) if DEBUG;

    return $data;

#    return $each_fn
#        ? hash_each($data, $each_fn)
#        : $data;
}

sub scan_config_dir {
    my ($self, $dir, $data, $binder) = @_;
    my $files  = $dir->files;
    my $dirs   = $dir->dirs;

    $data ||= { };

    foreach my $file (@$files) {
        next unless $file->name =~ $self->{ config_match_ext };
        $self->debug("found file: ", $file->name, ' at ', $file->path) if DEBUG;
        $self->scan_config_file($file, $data, $binder);
    }
    foreach my $dir (@$dirs) {
        $self->debug("found dir: ", $dir->name, ' at ', $dir->path) if DEBUG;
        $self->scan_config_dir($dir, $data, $binder);
    }
}

sub scan_config_file {
    my ($self, $file, $data, $binder) = @_;

    $file->codec( $self->{ config_codec } );
    $file->encoding( $self->{ config_encoding } );

    my $base = $file->path;
    my $meta = $file->try->data;
    my $uri;

    return $self->error_msg( load_fail => $file => $@ ) if $@;

    # remove file extension
    $base =~ s/$self->{ config_match_ext }//i;

    if ($binder) {
        $binder->($self, $data, $base, $meta);
    }
    else {
        $base =~ s[^/][];
        $data->{ $base } = $meta;
    }
}

sub uri_binder {
    my ($self, $data, $base, $meta) = @_;

    while (my ($key, $value) = each %$meta) {
        my $uri = resolve_uri($base, $key);
        $data->{ $uri } = $value;
        $self->debug(
            "loaded metadata for [$base] + [$key] = [$uri]"
        ) if DEBUG;
    }
}

#-----------------------------------------------------------------------------
# Methods for loading resources
#-----------------------------------------------------------------------------

sub has_resource {
    my $self = shift;
    my $type = shift;
    return $self->{ resource }->{ $type };
}

sub has_resources {
    my $self = shift;
    my $type = shift;
    return $self->{ resources }->{ $type };
}

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
    my ($self, $type, $name) = @_;

    return $self
        ->resource_dir($type)
        ->file( $self->config_filename($name) )
        ->must_exist;
}

sub resource_data {
    return shift                    # TODO: memcached
        ->resource_file(@_)
        ->data
}


#-----------------------------------------------------------------------------
# Methods for loading component modules
#-----------------------------------------------------------------------------

sub component {
    my $self = shift;
    my $type = shift;

    return  $self->{ component }->{ $type }
        ||= $self->load_component( $type => @_ );
}

sub has_component {
    my $self = shift;
    my $type = shift;
    return $self->{ components }->{ $type };
}

sub load_component {
    my $self    = shift;
    my $type    = shift;
    my $config  = $self->component_config( $type => @_ );
    my $factory = $self->component_factory;

    return $factory->item(
        $type => $config
    );
}

sub component_config {
    my $self     = shift;
    my $type     = shift;
    my $params   = params(@_);
    my $component   = $self->{ components }->{ $type }
        || return $self->error_msg( invalid => component => $type );
    my $master   = $self->{ config }->{ $type };
    my $merged   = extend({ _component_ => $type }, $component, $master, $params);
    my $cfg_file = $merged->{ config_file } || $self->config_filename($type);
    my $cfg_fobj = $self->config_file($cfg_file);
    my $cfg_data = $cfg_fobj->exists ? $cfg_fobj->data : undef;
    my $config   = extend($cfg_data, $merged);

    $self->debug(
        "config for component $type:\n",
        "- component config ($self->{ config_file }/components/$type): ", $self->dump_data($component), "\n",
        "- Master config ($type): ", $self->dump_data($master), "\n",
        "- Local params (component_config(...)): ", $self->dump_data($params), "\n",
        "= Merged config ({} < component < master < local): ", $self->dump_data($merged), "\n",
        "- Config file ($cfg_file): ", $self->dump_data($cfg_file), "\n",
        "= Fully merged (file < merged): ", $self->dump_data($config), "\n",
    ) if DEBUG;

    $config->{_project_} = $self;

    return $config;
}

sub component_factory {
    my $self = shift;

    return  $self->{ component_factory }
        ||= $self->COMPONENT_FACTORY->new(
                path => $self->{ config }->{ component_path }
            );
}


#-----------------------------------------------------------------------------
# Delegates
#-----------------------------------------------------------------------------

sub has_delegate {
    my $self   = shift;
    my $name   = shift                          || return $self->decline_msg( missing => 'delegate'  );
    my $delegs = $self->config->{ delegates }   || return $self->decline_msg( missing => 'delegates' );
    my $deleg  = $delegs->{ $name }             || return $self->decline_msg( invalid => delegate => $name );
    my ($component, $method) = split(':', $deleg, 2);

    $method ||= $name;
    $self->debug(
        "found '$deleg' for '$name' delegate in ", $self->dump_data($delegs)
    ) if DEBUG;

    return [$component, $method];
}

#-----------------------------------------------------------------------------
# The auto_can method is called when an unknown method is called.  It looks
# to see if the method corresponds to a component module or a method delegated 
# to a component.
#-----------------------------------------------------------------------------

# HMM... I don't like this at all.  In a multi-site environment there's 
# too much potential for auto-generated methods to do different things.
# I do not want to debug that when it goes wrong.

# TODO: replace this with AUTOLOAD

sub auto_can {
    my ($self, $name) = @_;
    my ($pair);

    if ($self->has_resource($name)) {
        $self->debug("project has $name resource") if DEBUG;
        return sub {
            return shift->{ resource }->{ $name }->resource(@_);
        }
    }

    if ($self->has_resources($name)) {
        $self->debug("project has $name resources") if DEBUG;
        return sub {
            return shift->{ resources }->{ $name };
        }
    }

    if ($pair = $self->has_delegate($name)) {
        my ($name, $method) = @$pair;
        $self->debug("project has [$name,$method] delegate") if DEBUG;
        return sub {
            return shift->component($name)->$method(@_);
        }
    }

    if ($self->has_component($name)) {
        $self->debug("project has $name component module") if DEBUG;
        return sub {
            return shift->component($name, @_);
        }
    }

    return undef;
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ component  };
    delete $self->{ components };
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


