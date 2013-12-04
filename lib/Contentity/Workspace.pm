package Contentity::Workspace;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'resolve_uri truelike falselike Dir self_params',
    accessors   => 'root parent config_dir urn type',
    constants   => 'ARRAY HASH SLASH DELIMITER',
    constant    => {
        CACHE           => 'cache',
        CACHE_MANAGER   => 'Contentity::Cache',
        CONFIG_DIR      => 'config',
        CONFIG_FILE     => 'workspace',
        METADATA_MODULE => 'Contentity::Metadata::Filesystem',
        WORKSPACE_TYPE  => 'workspace',
        COMPONENTS      => 'components',
        RESOURCES       => 'resources',
        DELEGATES       => 'delegates',
    },
    messages => {
        no_module  => 'No %s module defined.',
    };

our $LOADED      = { };
our $COLLECTIONS = [COMPONENTS, RESOURCES];


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workspace($config);
    $self->init_config($config);

    # from this point on, all configuration is read from the config object
    # so we don't really need to pass $config, but it can't hurt, right?
    $self->init_cache($config);
    $self->init_collections($config);
    return $self;
}

sub init_workspace {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $type  = $config->{ type      } || $self->WORKSPACE_TYPE;
    my $dir   = $config->{ directory } || $config->{ dir } || return $self->error_msg( missing => 'directory' );

    # must have a root directory
    my $root = Dir($dir);

    return $self->error_msg( invalid => directory => $dir )
        unless $root->exists;

    $self->{ root   } = $root;
    $self->{ type   } = $type;
    $self->{ urn    } = $config->{ urn } || $root->name;
    $self->{ uri    } = $config->{ uri } || sprintf("%s:%s", $self->type, $self->urn);
    $self->{ type   } = $type;
    $self->{ parent } = $config->{ parent };

    return $self;
}

sub init_config {
    my ($self, $config) = @_;
    my $class   = $self->class;
    my $cspec   = $config->{ config } || { };
    my $metamod = delete $cspec->{ metadata_module } 
               || $self->METADATA_MODULE;
    my $cdir    = delete $cspec->{ directory  } 
               || delete $cspec->{ dir        } 
               || $config->{ config_dir       }
               || $config->{ config_directory }
               || $self->CONFIG_DIR;
    my $cfile   = delete $cspec->{ file }
               || $config->{ config_file } 
               || $self->CONFIG_FILE;
    my $cdata   = delete $cspec->{ data }
               || $config->{ config_data };
               #|| $config;
    my $parent = $self->{ parent };

    # load the configuration module (e.g. Badger::Config::Directory)
    class($metamod)->load;

    # config directory and filesystem
    my $config_dir = $self->dir($cdir);
    my $config_opt = {
        %$cspec,
        directory => $config_dir,
        file      => $cfile,
    };

    if ($cdata) {
        $config_opt->{ data } = $cdata;
    }
    if ($parent) {
        $config_opt->{ parent } = $parent->config;
    };
    my $meta_obj = $metamod->new($config_opt);

    # Hmmm... what about other stuff that's in the $config?  Can we ignore
    # it or do we need to pass it to the config module?  I think in most, if
    # not all cases, we can ignore it because the $config will usually only
    # contain the root directory reference and leave all the config data to
    # be defined in the config dir/file.

    $self->{ config_dir } = $config_dir;
    $self->{ config     } = $meta_obj;

    return $self;
}

sub init_cache {
    my ($self, $config) = @_;
    my $cache_config  = $self->config(CACHE) || return $self->warn('no cache');
    my $cache_manager = delete $config->{ cache_manager } 
        || $cache_config->{ manager }
        || $self->CACHE_MANAGER;

    class($cache_manager)->load;

    $self->debug(
        "cache manager config for $cache_manager: ", 
        $self->dump_data($cache_config)
    ) if DEBUG;

    my $cache = $cache_manager->new(
        uri => $self->uri,
        %$cache_config,
    );

    $self->debug("created new cache manager: $cache") if DEBUG;
    $self->{ cache } = $cache;

    # we must notify the config object that it has a cache to work with
    $self->config->configure( cache => $cache );
}

sub init_collections {
    my ($self, $config) = @_;
    my $cols = $self->{ collections } = $self->class->list_vars(
        COLLECTIONS => $config->{ collections }
    );

    $self->debug(
        "COLLECTIONS: ", $self->dump_data($cols)
    ) if DEBUG;

    $self->init_collection($_) 
        for @$cols;
}

sub init_collection {
    my ($self, $type) = @_;

    # First look for any hashes defined in package variables for this module
    # or any of its subclasses, e.g. $COMPONENTS, $RESOURCES, etc.
    my $pkg_vars = $self->class->list_vars( uc $type );

    $self->configure_collection( $type => $_ )
        for @$pkg_vars;

    # Then read any additional configuration data from the config object
    # e.g. config/components.yaml
    $self->configure_collection(
        $type => $self->config($type)
    );

    $self->debug(
        "init_collection: $type => ", 
        $self->dump_data($self->{ $type })
    ) if DEBUG;
}

#-----------------------------------------------------------------------------
# Configuration methods that can be called at init() time or some time later
#-----------------------------------------------------------------------------

sub configure {
    my ($self, $config) = self_params(@_);
    my $item;

    if ($item = delete $config->{ parent }) {
        # if we change the parent workspace we must also re-attach the 
        # workspace config manager to the parent workspace config manager
        $self->{ parent } = $item;
        $self->{ config }->configure(
            parent => $item->config
        );
        $self->debug(
            "attached workspace to new parent workspace @", 
            $item->uri
        ) if DEBUG;
    }

    foreach my $collection ($self->collection_names) {
        if ($item = delete $config->{ $collection }) {
            $self->configure_collection( $collection => $item );
        }
    }

    # Other things in Contentity::Workspace that we might want to merge
    # back upstream at some point
    #   my $dirs    = delete($config->{ dirs         });
    #   my $cfile   = delete($config->{ config_file  });
    #   my $cfiles  = delete($config->{ config_files });
    #   if ($dirs)   { $self->dirs($dirs);                }
    #   if ($cfile)  { $self->init_config_file($cfile);   }
    #   if ($cfiles) { $self->init_config_files($cfiles); }
}

sub configure_components {
    shift->configure_collection(COMPONENTS, @_);
}

sub configure_resources {
    shift->configure_collection(RESOURCES, @_);
}

sub configure_collection {
    my ($self, $type, $source) = @_;
    my $collection = $self->{ $type } ||= { };
    my $components = $self->prepare_components($type, $source) || return;

    $self->debug(
        "OLD $type collection: ", $self->dump_data($collection), "\n",
        "ADD $type components: ", $self->dump_data($components)
    ) if DEBUG;

    @$collection{ keys %$components } = values %$components;

    if (DEBUG) {
        $self->debug("NEW $type collection: ", $self->dump_data($collection));
    }
}

sub prepare_components {
    my ($self, $type, $components) = @_;
    my $collection = { };
    my $component;

    return $collection
        unless $components;

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

    # Components can be set to any simple true value to enable them (e.g. 1) 
    # or a false value to explicitly disable them (e.g. 0).  Otherwise we 
    # expect them to be a module name (e.g. My::Component) or a hash reference
    # of configuration options, possibly including a 'module' item.
    while (my ($key, $value) = each %$components) {
        $component = $components->{ $key };

        if (! $component) {
            # ignore false values
            next;
        }
        elsif (ref $component eq HASH) {
            # reference to a hash is fine
        }
        elsif (ref $component) {
            # reference to anything else is not
            return $self->error_msg( invalid => "'$key' $type" => $component );
        }
        elsif (truelike $component) {
            # simple true value means yes, make it available
            $component = { };
        }
        else {
            # any other non-reference value is assumed to be a module name
            $component = {
                module => $component
            };
        }

        $collection->{ $key } = $component;

    }

    return $collection;
}


#-----------------------------------------------------------------------------
# tmp
#-----------------------------------------------------------------------------
#sub init_config_files {
#    my ($self, $files) = @_;
#    foreach my $file (@$files) {
#        $self->init_config_file($file);
#    }
#}

#sub init_config_file {
#    my ($self, $file) = @_;
#
#    # config file can have '?' suffix if it's optional
#    my $opt  = ($file =~ s/\?$//);
#
#    # only ever need to load an initialisation config file once (I think!)
#    my $done = $self->{ config_files_loaded } ||= { };
#    return if $done->{ $file };
#    $done->{ $file } = 1;
#
#    # load the config file, throw an error if it's not found and not optional
#    my $data = $self->config($file) 
#        || return $opt 
#            ? undef # $self->warn("Optional config file '$file' not found")
#            : $self->error( $self->reason );
#
#    $self->debug(
#        "Loaded config data from file '$file': ",
#        $self->dump_data($data)
#    ) if DEBUG;
#
#    $self->configure($data);
#}




#-----------------------------------------------------------------------------
# fetch config data from the config object
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config }; return $config unless @_;
    my @names  = map { ref $_ eq ARRAY ? @$_ : split /\./ } @_;
    my $name   = shift @names;
    my $data   = $config->get($name) 
        || return $self->decline_msg( not_found => 'configuration option' => $name );

    if ($data) {
        $self->dump_data("got data for $name: ", $self->dump_data($data));
    }

    return @names
        ? $config->dot($name, $data, \@names)
        : $data;
}

#-----------------------------------------------------------------------------
# components
#-----------------------------------------------------------------------------

sub component {
    my ($self, $name) = @_;
    my $config = $self->{ components }->{ $name }
        || return $self->error_msg( invalid => component => $name );

    $config = {
        module => $config,
    } unless ref $config;

    $self->debug("$name component config: ", $self->dump_data($config));

    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $config->{ module }
        || return $self->error_msg( no_module => $name );

    # load the module
    $LOADED->{ $name } ||= class($module)->load;

    $self->debug(
        "$name module config: ", 
        $self->dump_data($config)
    ) if DEBUG;

    $config->{ workspace } = $self;

    return $module->new($config);
}

sub auto_component {
    my ($self, $name, $comp) = @_;
    my $class = ref $self || $self;


    return sub {
        my $self = shift;
        my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
        $self = $self->prototype unless ref $self;

        return $self->{ $name } 
            ||= $self->construct( 
                $name => { 
                    # TODO: figure out what's going on here in terms of
                    # possible combinations of configuration options
                    %$args, 
                    hub    => $self, 
                    module => $comp 
                } 
            );
    }
}


#-----------------------------------------------------------------------------
# relative workspaces
#-----------------------------------------------------------------------------

sub subspace {
    my ($self, $params) = self_params(@_);
    my $class = ref $self;
    $params->{ parent } = $self;
    return $class->new($params);
}

sub superspace {
    return shift->{ parent };
}

sub uberspace {
    my $self = shift;
    return $self->{ uberspace } 
       ||= $self->{ parent }
         ? $self->{ parent }->uberspace
         : $self;
}

#-----------------------------------------------------------------------------
# Miscellaneous methods
#-----------------------------------------------------------------------------

sub hub {
    my $self = shift;

    if (@_) {
        # got passed an argument (a new hub) which we connect $self to
        my $hub = shift;

        unless (ref $hub) {
            class($hub)->load;
            $self->debug("creating new hub, config is ", $self->config) if DEBUG;
            $hub = $hub->new(
                config => $self->config,
            );
        }
        $self->{ hub } = $hub;
    }

    return $self->{ hub };
}


sub uri {
    my $self = shift;
    return @_
        ? sprintf("%s%s", $self->{ uri }, resolve_uri(SLASH, @_))
        : $self->{ uri };
}

sub dir {
    my $self = shift;

    return @_
        ? $self->root->dir(@_)
#        ? $self->resolve_dir(@_)
        : $self->root;
}

sub collection_names {
    my $self = shift;
    my $cols = $self->{ collections } || [ ];
    return wantarray
        ? @$cols
        :  $cols;
}

sub destroy {
    my $self = shift;
    if ($self->{ hub }) {
        $self->debug("cleaning up hub") if DEBUG;
        $self->{ hub }->destroy;
        delete $self->{ hub };
    }
    delete $self->{ parent    };
    delete $self->{ uberspace };
}


sub DESTROY {
    shift->destroy;
}

1;

__END__
=============
#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

    $self->{ urn        } = delete $config->{ urn } || $root_dir->name;
    $self->{ uri        } = delete $config->{ uri } || sprintf("%s:%s", $type, $self->{ urn });
    $self->{ config_dir } = $conf_dir;
    $self->{ config_fs  } = $config_fs;
    $self->{ config     } = $config;
    $self->{ schemas    } = { };
    $self->{ metadata   } = { };
    $self->{ loaders    } = $class->hash_vars(
        LOADERS => $config->{ loaders }
    );

    # default the config_file parameter
    $config->{ config_file } ||= $self->CONFIG_FILE;

    $self->configure_workspace($config);


    return $self;
}


sub dir {
    my $self = shift;

    return @_
        ? $self->resolve_dir(@_)
        : $self->root;
}

sub dirs {
    my $self = shift;
    my $dirs = $self->{ dirs } ||= { };

    if (@_) {
        # resolve all new directories relative to workspace directory
        my $root  = $self->root;
        my $addin = params(@_);

        while (my ($key, $value) = each %$addin) {
            my $subdir = $root->dir($value);
            if ($subdir->exists) {
                $dirs->{ $key } = $subdir;
            }
            else {
                return $self->error_msg( 
                    invalid => "directory for $key" => $value 
                );
            }
        }
        $self->debug(
            "set dirs: ", 
            $self->dump_data($dirs)
        ) if DEBUG;
    }

    return $dirs;
}

sub resolve_dir {
    my ($self, @path) = @_;
    my $dirs = $self->dirs;
    my $path = join(SLASH, @path);
    my @pair = split(SLASH, $path, 2); 
    my $head = $pair[0];
    my $tail = $pair[1];
    my $alias;

    $self->debug("[HEAD:$head] [TAIL:$tail]") if DEBUG;

    # the first element of a directory path can be an alias defined in dirs
    if ($alias = $dirs->{ $head }) {
        $self->debug(
            "resolve_dir($path) => [HEAD:$head=$alias] + [TAIL:$tail]"
        ) if DEBUG;
        return defined($tail)
            ? $alias->dir($tail)
            : $alias;
    }

    $self->debug("resolving: ", $self->dump_data(\@path)) if DEBUG;
    return $self->root->dir(@path);
}


sub file {
    my $self = shift;
    return $self->root->file(@_);
}


1;

__END__

=head1 NAME

Contentity::Workspace - an object representing a project workspace

=head1 DESCRIPTION

This module implements an object for representing a Contentity workspace.

NOTE: this documentation was cut-n-pasted from Contentity::Project which 
is in the process of being refactored.  Don't trust it to be accurate or
up to date.  The documentation will be updated when the refactoring is 
complete and the architecure more stable.

=head1 CLASS METHODS

=head2 new(\%config)

This is the constructor method to create a new C<Contentity::Project> object.

    use Contentity::Workspace;
    
    my $space = Contentity::Workspace->new(
        directory => '/path/to/workspace'
    );

=head3 CONFIGURATION OPTIONS

=head4 directory

This mandatory parameter must be provided to indicate the filesystem path
to the project directory.  It can be also specified as either of the aliases
C<dir> or C<root>

=head4 config_dir

This optional parameter can be used to specify the name of the configuration
direction under the L<root> project directory.  The default configuration 
directory name is C<config>.

=head4 config_file

This optional parameter can be used to specify the name of the main 
configuration file (without file extension) that should reside in the 
L<config_dir> directory under the C<root> project directory.  The default 
configuration file name is C<contentity>.

=head1 GENERAL PURPOSE OBJECT METHODS

=head2 uri($path)

When called without any arguments this method returns the base URI for the 
project.

    print $project->uri;            # e.g. foo

When called with a relative URI path as an argument, it returns the URI
resolved relative to the project base URI. 

    print $project->uri;

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

=head1 OBJECT METHODS FOR READING CONFIGURATION FILES

=head2 config_dir($path)

When called without any arguments this returns a L<Badger::Filesystem::Directory>
object representing the configuration directory for the project.

    my $dir = $project->config_dir;

When called with a relative directory path as argument it returns a 
L<Badger::Filesystem::Directory> representing the directory relative to
configuration directory. 

    my $dir = $project->config_dir('forms');

=head2 config_filename($name)

This method is used to construct the name of configuration files under the 
configuration directory.  It automatically appends the correct file extension.

    my $filename = $project->config_filename('foo');

=head2 config_filespec($params)

Returns a reference to a hash array containing appropriate initialisation
parameters for L<Badger::Filesystem::File> objects created to read general
and resource-specific configuration files.  The parameters are  constructed
from the C<config_codec> (default: C<yaml>) and C<config_encoding> (default:
C<utf8>) configuration options.  These can be overridden or augmented by extra
parameters passed as arguments.

=head2 config_file($name)

This method returns a L<Badger::Filesystem::File> object representing a 
configuration file in the configuration directory.  It will automatically
have the correct filename extension added (via a call to L<config_filename>)
and the correct C<codec> and C<encoding> parameters set (via a call to 
L<config_filespec>) so that the data in the configuration file can be 
automatically loaded (see L<config_data($name)>).

EDIT: Hmmm... it appear it doesn't add the filename extension, etc.  You 
have to do that via an additional call to L<config_filename()>.  This may
get changed RSN.  Watch this space.

=head2 config_data($name)

This method fetches a configuration file via a call to L<config_file()>
and then returns the data contained therein.

=head2 config_tree($name)

This method constructs a tree of configuration data from one or more 
configuration files under the configuration directory.  For example,
suppose there are F<config/urls.yaml> and F<config/urls/admin.yaml>
files that look like this:

Example F<config/urls.yaml>

    foo: /path/to/foo

Example F<config/urls/admin.yaml>

    bar: /path/to/bar

Then call the C<config_tree()> method like so:

    my $tree = $project->config_tree('urls');

The returned tree will contain the items defined in both files:

    {
        foo   => '/path/to/foo',
        admin => {
            bar => '/path/to/bar',
        }
    }

=head2 config_uri_tree($name)

This method works in a similar way to L<config_tree> but it merges nested
configuration files into a flat structure, using the file name (without the
file extension) as an intermediate URI component.  Consider the following
configuration files:

Example F<config/urls.yaml>

    foo: /path/to/foo

Example F<config/urls/admin.yaml>

    bar:  /path/to/bar
    /baz: /path/to/baz

Calling the C<config_uri_tree()> method like so:

    my $tree = $project->config_uri_tree('urls');

Will return a hash array like this:

    {
        foo         => '/path/to/foo',
        /admin/bar  => '/path/to/bar',
        /baz        => '/path/to/baz',
    }

Note that relative URIs (e.g. C<bar>) in nested files get appended to the 
file basename (e.g. C</admin/bar>) whereas those that are absolute (starting
with a C</> do not).  At present all resultant URIs from nested files are
absolute (i.e. C</admin/bar> instead of C<admin/bar>).  I'm not sure that's
necessarily correct but that's how it is for now.

=head2 scan_config_dir()

This method is used internally by L<config_tree()> to scan the files in a 
configuration directory.

=head2 scan_config_file()

This method is used internally by L<config_tree()> to load an individual 
files in a configuration directory.

=head2 uri_binder()

This method is used internally by L<config_uri_tree()> for resolving for 
constructing composite URIs.

=head1 OBJECT METHODS FOR LOADING COMPONENTS

Components are one-off (singleton) objects that can be loaded into a contentity
project.  For example, a database can be implemented as a component.  You 
generally only ever need to load one database component into a project and 
all other internal components and external code using the project can share it.

=head2 component($name)

Returns a cached instance of a named component or loads (and caches) it via
a call to L<load_component()>.

=head2 has_component($name)

Return a boolean value to indicate if this project has a named component

=head2 load_component($name)

=head2 component_config($name)

=head2 component_factory()



=head1 OBJECT METHODS FOR LOADING RESOURCES

=head1 INITIALISATION METHODS

These methods are used internally to initialise the C<Contentity::Project>
object.

=head2 init(\%config)

This is the main initialisation method.  It performs some object initalisation,
sets sensible defaults for any missing values in the C<\%config> parameters 
and loads the configuration data defined in the main configuration file.  It 
then calls each of the following initialisation methods passing a reference 
to a hash array of merged configuration parameters.

=head2 init_project(\%merged_config)

This doesn't do anything much at present but is provided as a stub for 
future expansion.

=head2 init_components(\%merged_config)

This calls the L<prepare_components()> method to initialise all C<components>
defined in the merged configuration.

=head2 init_resources(\%merged_config)

This calls the L<prepare_components()> method to initialise all C<resources>
defined in the merged configuration.

=head2 prepare_components(\%components)

This initialises the configuration data for a set of plugin components.


=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
