package Contentity::Workspace;

use Contentity::Config;
use Contentity::Workspaces;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Workspace Contentity::Base',
    import      => 'class',
    utils       => 'truelike falselike extend merge params self_params blessed reftype refaddr',
    autolook    => 'get',
    accessors   => 'type',
    as_text     => 'ident',
    constants   => 'BLANK COMPONENT',
    constant    => {
        # configuration manager
        CONFIG_MODULE     => 'Contentity::Config',

        # component factories
        COMPONENT_FACTORY => 'Contentity::Components',
        WORKSPACE_FACTORY => 'Contentity::Workspaces',
        SUBSPACE_MODULE   => 'Contentity::Workspace',

        # empty workspace space - for subclasses to redefine
        WORKSPACE_TYPE    => '',
    },
    messages => {
        no_module        => 'No %s module defined.',
        no_config        => 'No configuration data for %s',
        no_resource_data => 'No resource data for %s/%s',
    };


our $LOADED = { };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init_workspace {
    my ($self, $config) = @_;

    $self->SUPER::init_workspace($config);

    my $type = $self->{ type } = $config->{ type } || $self->WORKSPACE_TYPE;
    my $uri  = $self->{ uri  } = $config->{ uri  } || join(
        ':', 
        grep { defined $_ and length $_ }
        $self->{ type },
        $self->{ urn }
    );

    # ugly temporary hack to allow 'component_path' configuration option to 
    # be passed to component factory - see t/workspace/components.t around
    # line 30
    $self->{ factory_config } = $config;

    $self->init_data_files($config);

    # import all the pre-loaded config data into the workspace for efficiency
    my $data = $self->{ data } ||= { };
    merge($data, $self->config->data);
    $self->debug_data("merged config data: ", $data) if DEBUG;

    return $self;
}

sub init_data_files {
    my ($self, $config) = shift;
    my $type = $self->type;

    # import any data file corresponding to the workspace type, e.g. project,
    # site, portfolio, etc.
    $self->config->import_data_file_if_exists($type)
        if $type;

    # TODO: load any other data files, like deployment, local, etc
}


sub component_factory {
    my $self = shift;
    return  $self->{ component_factory }
        ||= $self->init_factory( component => $self->COMPONENT_FACTORY );
}

sub workspace_factory {
    my $self = shift;
    return  $self->{ workspace_factory }
        ||= $self->init_factory( workspace => $self->WORKSPACE_FACTORY );
}

sub init_factory {
    my ($self, $type, $default) = @_;
    my $name    = "${type}_factory";
    my $fconfig = $self->{ factory_config };
    my $factory = $fconfig->{ $name } || $self->config($name) || $default;

    if (blessed $factory) {
        return $factory;
    }
    else {
        class($factory)->load;
        return $factory->new($fconfig);
    }
}




#-----------------------------------------------------------------------------
# Methods for creating components
#-----------------------------------------------------------------------------

sub component {
    my $self   = shift;
    my $name   = shift;
    return  $self->{ component_cache }->{ $name }
        ||  $self->load_component($name, @_);
}

sub load_component {
    my $self   = shift;
    my $urn    = shift; # urn is what they ask for
    my $name   = $urn;  # name is initially the same but may change
    my $config = $self->component_config($name, @_);
    my $single = truelike( 
        $config->{ singleton } // $config->{ cache_object }
    );

    $self->debug(
        "ready to create $name component\n",
        "+ config: ", $self->dump_data($config)
    ) if DEBUG;


    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $config->{ module };
    my $object;

    if ($module) {
        # load the module
        $self->debug("instantiating $module for $name component") if DEBUG;
        $LOADED->{ $name } ||= class($module)->load;
        $object = $module->new($config) || return;
    }
    else {
        # component name may have been re-mapped by config or schema
        $name = $config->{ component } || $name;
        $object = $self->component_factory->item( $name => $config ) || return;
    }

    if ($single) {
        $self->debug("caching singleton component $name as $object") if DEBUG;
        $self->{ component_cache }->{ $urn } = $object;
    }

    #$self->debug("cache looks like this: ", $self->dump_data($self->{ component_cache }));

    return $object;
}


sub component_config {
    my $self   = shift;
    my $name   = shift;
    my $params = params(@_);
    my $schema = $self->item_schema($name) || { };
    my $config = $self->config($name) || { };
    my $merged = extend({ }, $config, $params);
    my $final  = { 
        component => $name,
        urn       => $name,
        schema    => $schema,
        %$schema,
        workspace => $self,
        config    => $merged,
    };

    $self->debug(
        "config for component $name:",
        $self->dump_data1($final)
    ) if DEBUG;

    return $final;
}


sub clear_component_cache {
    my $self  = shift;
    my $cache = delete($self->{ component_cache }) || return;

    while (my ($key, $value) = each %$cache) {
        $self->debug("clearing component cache of $key => $value") if DEBUG;
        $value->destroy if $value;
    }
}



#-----------------------------------------------------------------------------
# The project is deemed to be the parent at the top of the chain
#-----------------------------------------------------------------------------

sub project {
    my $self = shift;
    return $self->{ project } 
       ||= $self->{ parent  }
         ? $self->{ parent  }->project
         : $self;
}


#-----------------------------------------------------------------------------
# subspaces require the use of a factory
#-----------------------------------------------------------------------------

sub subspace {
    my ($self, $params) = self_params(@_);
    my $type = $params->{ type };

    $params->{ parent } = $self;

    $self->debug("subspace() params: ", $self->dump_data($params)) if DEBUG;

    if ($type) {
        $self->debug("subspace() found workspace type: $type") if DEBUG;
        return $self->workspace_factory->workspace(
            $type => $params
        );
    }

    $self->debug("No type, using default: ", $self->SUBSPACE_MODULE) if DEBUG;

    return class($self->SUBSPACE_MODULE)->load->instance($params);
}


sub dirs_up {
    my ($self, @path) = @_;
    my $spaces = $self->ancestors;
    my ($space, $dir, @dirs);

    foreach $space (@$spaces) {
        $dir = $space->dir(@path);
        push(@dirs, $dir) if $dir->exists;
    }

    return wantarray
        ?  @dirs
        : \@dirs;
}


#-----------------------------------------------------------------------------
# name and object identifier for debugging purposes
#-----------------------------------------------------------------------------

sub name {
    my $self = shift;
    return  $self->{ name }
        ||= $self->config('name')
        ||  $self->{ uri };
}

sub ident {
    my $self = shift;
    return sprintf(
        '%s:0x%x:%s', ref($self) || reftype($self), refaddr($self), $self->uri
    );
}


#-----------------------------------------------------------------------------
# generic get (autoload) method using item_schema() to fetch schema
#-----------------------------------------------------------------------------

sub get {
    my ($self, $name, @args) = @_;
    my $data   = $self->config($name) // return;
    my $schema = $self->item_schema($name);

    if (DEBUG) {
        $self->debug("Workspace got config: ", $self->dump_data($data));
        $self->debug("Workspace got schema: ", $self->dump_data($schema));
    }

    my $type = $schema->{ type } || BLANK;

    if ($schema->{ component } || $type eq COMPONENT) {
        $self->debug("Found a component for $name: ", $self->dump_data($schema)) if DEBUG;
        return $self->component($name)
    }
    # else other types...

    return $data;
}

sub item_schema {
    shift->config->item(shift);
}


#-----------------------------------------------------------------------------
# Cleanup
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    $self->clear_component_cache;
    $self->SUPER::destroy;
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

This is the constructor method to create a new C<Contentity::Workspace> object.

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
configuration file name is C<workspace>.

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

TODO

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

These methods are used internally to initialise the C<Contentity::Workspace>
object.

=head2 init_workspace(\%config)

This replaces the stub method inherited from L<Badger::Workspace>.  It calls
the following initialisation methods

=head2 init_cache(\%config)

This initialises a L<Contentity::Cache> object to cache configuration data.
It depends on there being a L<cache.XXX> configuration file in the C<config>
directory.

=head2 init_collections(\%config)

This calls the L<init_collection()> method for each of the collection types:
components, resources.

=head2 init_collection($type, $config)

This calls the L<prepare_components()> method to initialise all C<resources>
defined in the merged configuration.

=head2 prepare_components(\%components)

This initialises the configuration data for a set of plugin components.


=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
