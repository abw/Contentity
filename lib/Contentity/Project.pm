package Contentity::Project;

use Contentity::Components;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'params extend weaken resolve_uri self_params',
    filesystem  => 'Dir VFS',
    accessors   => 'root config',
    autolook    => 'autoload_component autoload_resource autoload_delegate autoload_config autoload_master',
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

    # Hmmm... should this be "master" or simply "project" in keeping with
    # components?  Or "base" in keeping with sites that have base sites?
    if ($config->{_project_}) {
        $self->attach_project($config);
        $self->debugf(
            "attaching slave project [%s] to master project [%s]",
            $self->uri,
            $self->master->uri
        ) if DEBUG;
    }

    my $cfg_data = $self->config_data($cfg_file);

    # TODO: handle base projects?

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

sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ uri }, @_)
        : $self->{ uri };
}

sub dir {
    my $self = shift;

    return @_
        ? $self->root->dir(@_)
        : $self->root;
}

sub resolve_dir {
    my ($self, $dir) = @_;

    if ($dir =~ s/^base://g) {
        my $base = $self->master || $self;
        return $base->dir($dir);
    }
    else {
        return $self->dir($dir);
    }
}


#-----------------------------------------------------------------------------
# Methods for loading configuration files
#-----------------------------------------------------------------------------


sub EX_config {
    my $self   = shift;
    my $config = $self->{ config };
    return $config unless @_;

    my $item = shift;
    if (exists $config->{ $item }) {
        return $config->{ $item };
    }
    else {
        return $self->decline_msg("$item is undefined")
            unless defined $config;
    }
}

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

    if (! $file->exists && $self->master) {
        return $self->master->config_data($name);
    }
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

sub config_tree {
    my ($self, $name, $binder, $slave) = @_;
    my $confdir = $self->config_dir;
    my $file    = $self->config_file( $self->config_filename($name) );
    my $dir     = $confdir->dir($name);
    my $master  = $self->master;
    my $data    = $master 
        ? $master->config_tree($name, $binder, $self) 
        : { };

    if ($file->exists) {
        # we're expecting to find a $name.yaml file...
        my $more = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        @$data{ keys %$more } = values %$more;
    }
    elsif ($dir->exists) {
        # ...or perhaps a $name directory with XXX.yaml files in it
        # we'll handle that below
    }
    elsif ($slave) {
        # If we're being called as the master of some slave then we don't
        # need to report any missing files/dirs as errors as it's up to the
        # slave to take care of that
        return $data;
    }
    elsif ($master && %$data) {
        # If we're a slave and the master returned some data then we're good
        return $data;
    }
    else {
        # There's nobody else to blame
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

        # TODO: add in multiple roots where project has a parent project
        my $vfs = VFS->new( root => $dir );
        $self->debug("Reading metadata from dir: ", $dir->name) if DEBUG;
        $self->scan_config_dir($vfs->root, $data, $binder);
    }

    $self->debug("$name config: ", $self->dump_data($data)) if DEBUG;

    return $data;

    # return $each_fn
    #    ? hash_each($data, $each_fn)
    #    : $data;

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

sub config_uri_tree {
    my ($self, $name) = @_;
    return $self->config_tree($name, $self->can('uri_binder'));
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
# Methods for loading component modules
#-----------------------------------------------------------------------------

sub component {
    my $self = shift;
    my $type = shift;

    # Always create a new instance if arguments are specified
    if (@_) {
        $self->debug(
            "Creating custom $type component with config: ", 
            $self->dump_data(\@_)
        ) if DEBUG;

        return $self->load_component( $type => @_ );
    }

    # Otherwise create and cache a component using the project config defaults
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
    my $component = $self->{ components }->{ $type }
        || return $self->error_msg( invalid => component => $type );
    my $master   = $self->{ config }->{ $type };
    my $merged   = extend({ _component_ => $type }, $component, $master, $params);
    my $cfg_file = $merged->{ config_file } || $self->config_filename($type);
    my $cfg_fobj = $self->config_file($cfg_file);                             # TODO: doesn't account for inheritance
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
# Methods for loading resources
#-----------------------------------------------------------------------------


sub resources {
    my ($self, $type) = @_;

    return $self->{ resources }->{ $type }
        || $self->{ resource  }->{ $type }
        || return $self->error_msg( invalid => resources => $type );
}

sub resource {
    my ($self, $type, $name, @args) = @_;

    return $self->resources($type)->resource($name, @args)
        || return $self->error_msg( invalid => $type => $name );
}

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

    # look for the resource file in the local project directory
    my $file = $self
        ->resource_dir($type)
        ->file( $self->config_filename($name) );

    if ($file->exists) {
        return $file;
    }

    # delegate to any master project
    my $master = $self->master;
    if ($master) {
        return $master->resource_file($type, $name);
    }

    # trigger exception
    return $file->must_exist;
}

sub resource_vfs {
    my ($self, $type) = @_;

    return VFS->new( 
        root => $self->resource_dir($type)
    );
}

sub resource_files {
    my ($self, $type) = @_;
    my $vfs   = $self->resource_vfs($type);
    my @files = $vfs->collect( files => 1, in_dirs => 1, dirs => 0 );
    return wantarray
        ?  @files
        : \@files;
}

sub resource_names {
    my ($self, $type) = @_;
    my $files = $self->resource_files($type);
    my @names = map { $_->basename } @$files;
    return wantarray
        ?  @names
        : \@names;
}


sub resource_data {
    return shift                    # TODO: memcached
        ->resource_file(@_)
        ->data
}


#sub resource_index {
#    my ($self, $type) = @_;

    # look for the resource file in the local project directory
#    my $root = $self->resource_dir($type)
#    my $src_vfs = VFS->new( root => $srcdir );
#my @files   = $src_vfs->collect( files => 1, in_dirs => 1, dirs => 0 );


#-----------------------------------------------------------------------------
# Delegates
#-----------------------------------------------------------------------------

sub has_delegate {
    my $self   = shift;
    my $name   = shift                              || return $self->decline_msg( missing => 'delegate'  );
    my $delegs = $self->{ config }->{ delegates }   || return $self->decline_msg( missing => 'delegates' );
    my $deleg  = $delegs->{ $name }                 || return $self->decline_msg( invalid => delegate => $name );
    my ($component, $method) = split(/\W+/, $deleg, 2);

    $method ||= $name;
    $self->debug(
        "found '$deleg' for '$name' delegate in ", $self->dump_data($delegs)
    ) if DEBUG;

    return [$component, $method];
}

#-----------------------------------------------------------------------------
# Sub-projects
#-----------------------------------------------------------------------------

sub master {
    shift->{ project };
}

sub slave {
    my ($self, $params) = self_params(@_);
    my $class = ref $self;
    $params->{_project_} = $self;
    $params->{ root    } = $self->dir( $params->{ root } ) if $params->{ root };
    $self->debug_data("slave $params->{ uri } initialising new params: ", $params) if DEBUG;
    return $class->new($params);
}

sub roots {
    my $self   = shift;
    my $master = $self->master;
    my $roots  = $master ? $master->roots : [ ];
    push(@$roots, $self->root);
    return $roots;
}



#-----------------------------------------------------------------------------
# Autoload methods for looking up components, resources, delegates, etc.
#-----------------------------------------------------------------------------

sub autoload_component {
    my ($self, $name, @args) = @_;
    $self->debug("$self->{uri}: autoload_component($name)") if DEBUG;
    return $self->has_component($name)
        && $self->component($name, @args);
}

sub autoload_resource {
    my ($self, $name, @args) = @_;
    $self->debug("$self->{uri}: autoload_resource($name)") if DEBUG;
    return $self->has_resource($name)
        && $self->resource($name, @args);
}

sub autoload_delegate {
    my ($self, $name, @args) = @_;
    $self->debug("$self->{uri}: autoload_delegate($name)") if DEBUG;
    my $pair = $self->has_delegate($name) || return;
    my ($component, $method) = @$pair;
    $self->debug("project has [$component,$method] delegate") if DEBUG;
    return $self->component($component)->$method(@args);
}

sub autoload_config {
    my ($self, $name, @args) = @_;
    $self->debug("$self->{uri}: autoload_config($name)") if DEBUG;
    my $config = $self->config;

    return  exists $config->{ $name }
        ?   $config->{ $name }
        :   undef;
}

sub autoload_master {
    my ($self, $name, @args) = @_;
    $self->debug("$self->{uri}: autoload_master($name)") if DEBUG;
    my $master = $self->master || return;
    return $master->$name(@args);
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ component  };
    delete $self->{ components };
    delete $self->{ _project_  };
    $self->debug("project $self->{ uri } is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}

1;

__END__

=head1 NAME

Contentity::Project - an object representing a project

=head1 DESCRIPTION

This module implements an object for representing a Contentity project.
A project is comprised of a root directory, a master configuration
file and perhaps other configuration files, resource files and other 
bits and pieces.  A C<Contentity::Project> object is a central manager
for such a collection of data.

=head1 CLASS METHODS

=head2 new(\%config)

This is the constructor method to create a new C<Contentity::Project> object.

    use Contentity::Project;
    
    my $project = Contentity::Project->new(
        root => '/path/to/project'
    );

=head3 CONFIGURATION OPTIONS

=head4 root

This mandatory parameter must be provided to indicate the filesystem path
to the project directory.

=head4 config_dir

This optional parameter can be used to specify the name of the configuration
direction under the L<root> project directory.  The default configuration 
directory name is C<config>.

=head4 config_file

This optional parameter can be used to specify the name of the main 
configuration file (without file extension) that should reside in the 
L<config_dir> directory under the C<root> project directory.  The default 
configuration file name is C<contentity>.

=head4 config_codec

This optional parameter can be used to specify an alternate data codec 
for reading the data in the configuration files.  By default, Contentity
used YAML for configuration files.  Thus, the default C<config_codec>
value is C<yaml>.

=head4 config_extension

This optional parameter can be used to specify the file extension on 
configuration files.  It defaults to the value in C<config_code>.  
Assuming you don't change that value, all configuration files will be 
expected to have a C<.yaml> file extension.

=head4 config_encoding

This optional parameter can be used to specify the character encoding
of configuration files.  The default value is C<utf8>.

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
