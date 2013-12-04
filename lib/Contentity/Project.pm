package Contentity::Project;

use Contentity::Components;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Workspace',
    import      => 'class',
    utils       => 'params extend self_params',
    filesystem  => 'Dir VFS',
    accessors   => 'root hub XXXconfig',
    #autolook    => 'autoload_component autoload_resource autoload_delegate autoload_config autoload_master',
    #autolook    => 'autoload_config',
    constants   => 'DOT DELIMITER HASH ARRAY MIDDLEWARE',
    constant    => {
        SITEMAP           => 'Contentity::Sitemap',
        CONFIG_FILE       => 'project',
        DIRS              => 'dirs',
        WORKSPACE_TYPE    => 'project',
        COMPONENT_FACTORY => 'Contentity::Components',
    },
    messages => {
        load_fail => 'Failed to load data from %s: %s',
        no_config => 'No configuration file or directory for %s',
        no_domain_site => "There isn't any site defined for the '%s' domain",
    };
 #   auto_can    => 'auto_can';



#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workspace($config);

    # Careful now!  init_workspace() will have modified the $config hash
    $self->debug("intermediate config: ", $self->dump_data($config)) if DEBUG;
    $self->init_project($config);

    return $self;
}

sub init_project {
    my ($self, $config) = @_;
    return $self
        ->init_components($config)
        ->init_resources($config)
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
        $component = $self->component($key) || return $self->error_msg( invalid => 'resource component' => $key);
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
              : $component ? ( $_ => { }        )     # change true value to hash
              : ( )                                   # ignore false values
        }
        keys %$components
    };
}


#-----------------------------------------------------------------------------
# Methods for loading component modules
#-----------------------------------------------------------------------------

sub component {
    my $self = shift;
    my $type = shift;
    
    return $self->component_factory->item(
        $type => $self->component_config($type)
    );
}

sub has_component {
    my $self = shift;
    my $type = shift;
    return $self->{ components }->{ $type };
}

sub component_config {
    my $self   = shift;
    my $type   = shift;
    my $config = $self->config($type);

    $config->{ _workspace_} = $self;

    $self->debug("component config for $type: ", $self->dump_data($config)) if DEBUG;
    return $config;
}


sub OLD_component_config {
    my $self     = shift;
    my $type     = shift;
    my $params   = params(@_);
    my $component = $self->{ components }->{ $type } || { };
        #|| return $self->error_msg( invalid => component => $type );
    my $master   = $self->{ config }->{ $type };
    my $merged   = extend({ _component_ => $type }, $component, $master, $params);
    my $cfg_data = $self->config($type);
    my $config   = extend($cfg_data, $merged);

    $self->debug(
        "config for component $type:\n",
        "- component config ($self->{ config_file }/components/$type): ", $self->dump_data($component), "\n",
        "- Master config ($type): ", $self->dump_data($master), "\n",
        "- Local params (component_config(...)): ", $self->dump_data($params), "\n",
        "= Merged config ({} < component < master < local): ", $self->dump_data($merged), "\n",
        "- Config data from workspace ($type): ", $self->dump_data($cfg_data), "\n",
        "= Fully merged (file < merged): ", $self->dump_data($config), "\n",
    ) if DEBUG or 1;

    $config->{_workspace_} = $self;     # new?
    $config->{_project_} = $self;       # old

    return $config;
}

sub component_factory {
    my $self = shift;

    return  $self->{ component_factory }
        ||= $self->COMPONENT_FACTORY->new(
                path => $self->{ config }->{ component_path }
            );
}


1;

__END__





#-----------------------------------------------------------------------------
# General purpose methods
#-----------------------------------------------------------------------------



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
    my $rdname = $self->{ config }->{ resources_dir };
    my $rddir  = $self->dir($rdname);

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
            ); #->must_exist;
}

sub resource_file {
    my ($self, $type, $name) = @_;

    # look for the resource file in the local project directory
    my $dir = $self->resource_dir($type);

    if ($dir->exists) {
        my $file = $dir->file(
            $self->config_filename($name)
        );
        if ($file->exists) {
            return $file;
        }
    }

    # delegate to any master project
    my $master = $self->master;

    if ($master) {
        return $master->resource_file($type, $name);
    }

    # trigger exception
    #return $file->must_exist;
    return $self->error_msg( invalid => $type => $name );
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
# Middleware
#-----------------------------------------------------------------------------

sub middleware {
    my $self = shift;
    my $mids = $self->component(MIDDLEWARE);
    return @_
        ? $mids->middleware(@_)
        : $mids;
}

#-----------------------------------------------------------------------------
# Sub-projects
#-----------------------------------------------------------------------------

sub grand_master {
    my $self = shift;
    return $self->{ project }
        ?  $self->{ project }->grand_master
        :  $self;
}

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
# Mappings to various components, etc
#-----------------------------------------------------------------------------

sub plack {
    shift->component('plack');
}

sub domains {
    shift->component('domains');
}

sub domain {
    shift->domains->domain(@_);
}

sub domain_site {
    my ($self, $name) = @_;
    my $domain  = $self->domain($name) || return;
    my $siteurn = $domain->{ site }    || return $self->error_msg( no_domain_site => $name );
    return $self->site($siteurn);
}

sub site_domains {
    shift->domains->site_domains(@_);
}

sub OLD_sites {
    shift->component('sites');
}

sub OLD_site {
    shift->sites->resource(@_);
}

sub lists {
    shift->component('lists');
}

sub list {
    shift->lists->resource(@_);
}

sub templates {
    shift->component('templates');
}

sub template {
    shift->templates->template(@_);
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
    local $Contentity::Class::CALLUP = $Contentity::Class::CALLUP + 1;
    return $master->try->$name(@args);
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
