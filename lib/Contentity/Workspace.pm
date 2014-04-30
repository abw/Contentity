package Contentity::Workspace;

use Contentity::Config;
use Contentity::Workspaces;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Workspace Contentity::Base',
    import      => 'class',
    utils       => 'truelike falselike extend merge params self_params
                    blessed reftype refaddr resolve_uri',
    autolook    => 'get',
    accessors   => 'type',
    as_text     => 'ident',
    constants   => 'HASH BLANK SLASH COMPONENT',
    constant    => {
        # configuration manager
        CONFIG_MODULE     => 'Contentity::Config',

        # component factories
        COMPONENT_FACTORY => 'Contentity::Components',
        WORKSPACE_FACTORY => 'Contentity::Workspaces',
        SUBSPACE_MODULE   => 'Contentity::Workspace',

        # empty workspace space - for subclasses to redefine
        WORKSPACE_TYPE    => '',
        WORKSPACE_FILE    => '',
        CONFIG_FILES      => '',
    },
    messages => {
        no_module        => 'No %s module defined.',
        no_config        => 'No configuration data for %s',
        no_resource_data => 'No resource data for %s/%s',
        no_parent_base   => 'No parent defined to fetch %s base workspace from',
    };


our $LOADED    = { };
our $BASEWATCH = { };

sub init {
    my ($self, $config) = @_;

    return
        $self->init_workplace($config)
             ->pre_init_workspace($config)
             ->init_workspace($config)
             ->post_init_workspace($config);
}

sub pre_init_workspace {
    my ($self, $config) = @_;
    $self->{ type } = $config->{ type } || $self->WORKSPACE_TYPE;
    $self->{ uri  } = $config->{ uri  } || $self->{ urn };
    return $self;
}

sub post_init_workspace {
    my ($self, $config) = @_;
    my $uri = $self->{ uri };

    # ugly temporary hack to allow 'component_path' configuration option to
    # be passed to component factory - see t/workspace/components.t around
    # line 30
    $self->{ factory_config } = $config;

    $self->init_data_files($config);

    # import all the pre-loaded config data into the workspace for efficiency
    my $data = $self->{ data } ||= { };
    merge($data, $self->config->data);

    # Now hold on a second!  If there's a 'base' URI defined and we don't have
    # a parent with a matching URI then we ask the master project to load it for
    # us.  It's troublesome because we want to allow the base to be defined in
    # the workspace.yaml file, so we have to bootstrap the workspace far enough
    # to see if a base configuration option is defined, and then start all over
    # again if it doesn't match the parent we've got
    my $base = $data->{ base };

    if ($base) {
        my $parent = $self->parent || return $self->error_msg( no_parent_base => $base );
        my $puri   = $parent->uri;

        if ($base eq $puri) {
            $self->debug("All is well - the parent is our base: $base") if DEBUG;
        }
        else {
            $self->debug("asking project to reload $uri workspace with new base: $base") if DEBUG;

            return $self->project->reload_workspace(
                $uri, { base => $base }
            );
        }
    }

    $self->debug_data("merged config data: ", $data) if DEBUG;

    return $self;
}


sub init_data_files {
    my ($self, $config) = shift;
    my $file = $self->WORKSPACE_FILE || $self->type;

    # import any data file corresponding to the workspace type, e.g. project,
    # site, portfolio, etc.
    $self->config->import_data_file_if_exists($file)
        if $file;

    # TODO: load any other data files, like deployment, local, etc
    my $files = $self->config('config_files') || $self->CONFIG_FILES;
    $self->debug_data( files => $files ) if DEBUG;
    $self->config->import_data_files($files);
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
    my $subcfg = $config->{ config } || { };
    my $single = truelike(
        $config->{ singleton } // $config->{ cache_object }
    );

    $self->debug(
        "ready to create $name component\n",
        "+ config: ", $self->dump_data($config), "\n",
        "+ sub-config: ", $self->dump_data($subcfg)
    ) if DEBUG;

    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $subcfg->{ module } || $config->{ module };
    my $object;

    if ($module) {
        # load the module
        $self->debug("instantiating $module for $name component") if DEBUG;
        $LOADED->{ $name } ||= class($module)->load;
        $object = $module->new($config) || return;
    }
    else {
        # component name may have been re-mapped by config or schema
        $name = $subcfg->{ component } || $config->{ component }  || $name;
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
    my $config = $self->config($name) || { };
    # NOTE: we MUST load the schema after loading the config, in case the config
    # file contains schema modifications
    my $schema = $self->item_schema($name) || { };

    # if $config isn't a HASH reference then we can't merge it with params
    $config = { $name => $config } unless ref $config eq HASH;

    $self->debug_data( "$name component config schema" => $schema ) if DEBUG;

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
        # We can't assume we're the workspace that this component is primarily
        # attached to.  A child workspace can automatically fetch and cache
        # a component from a parent workspace.  So we pass the workspace
        # reference to the component and let it decide if we're the master
        # workspace.  If we are then it calls its own destroy() method to
        # clean itself up.
        $value->detach_workspace($self) if $value;
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

sub project_uri {
    my $self = shift;
    my $base = $self->{ project_uri }
           ||= $self->init_project_uri;

    return @_
        ? sprintf("%s%s", $base, resolve_uri(SLASH, @_))
        : $base;
}

sub init_project_uri {
    my $self    = shift;
    my $uri     = $self->uri;
    my $project = $self->project;

    # Bit of a nasty situation here.  We use a URI like sites/completely
    # to reference a site, e.g. $project->workspace('sites/completely').
    # But we also need to have a global uri for caching that includes the
    # project uri, e.g. cog/sites/completely

    if (refaddr $project == refaddr $self) {
        # there isn't a project above us
        return $uri;
    }
    else {
        return $project->uri($uri);
    }
}

sub config_uri {
    # The Badger::Workspace base class calls this method to determine the uri
    # for the config module (and cache) to use.  We want it to have a uri that's
    # unique so we use the project-relative uri, e.g. cog/sites/completely
    # instead of the local uri, e.g. sites/completely.
    shift->project_uri(@_);
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
        ||  $self->{ urn };             # was uri
}

sub names {
    my $self = shift;
    my $noms = $self->{ names }
           ||= [$self->urn, $self->aliases];
    return wantarray
        ? @$noms
        :  $noms;
}

sub aliases {
    my $self = shift;
    my $akas = $self->{ aliases }
           ||= $self->config('aliases')
           ||  [ ];

    return wantarray
        ? @$akas
        :  $akas;
}


sub ident {
    my $self = shift;
    return sprintf(
        '%s:0x%x:%s', ref($self) || reftype($self), refaddr($self), $self->uri
    );
}


#-----------------------------------------------------------------------------
# Modified config() method - I don't think we need to fallback on the
# parent any more because Contentity::Config handles that.
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return $config unless @_;
    return $config->get(@_);
#       // $self->parent_config(@_);
}

#-----------------------------------------------------------------------------
# generic get (autoload) method using item_schema() to fetch schema
#-----------------------------------------------------------------------------

sub get {
    my ($self, $name, @args) = @_;
    my $data   = $self->config($name) // return;
    my $schema = $self->item_schema($name);

    if (DEBUG) {
        $self->debug_data("Workspace get($name) config: ", $data);
        $self->debug_data("Workspace get($name) schema: ", $schema);
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
    my $self   = shift;
    my $schema = $self->config->schema(@_) || return;

    # Badger::Config's simple lookup table for 'items' can have '1' as an
    # entry to indicate that it's a valid item.
    $schema = { }
        if $schema && $schema eq '1';

    return $schema;
}


#-----------------------------------------------------------------------------
# Cleanup
#-----------------------------------------------------------------------------

# hack to get skin reloaded for build watcher
sub builder_reset {
    my $self  = shift;
    my $cache = $self->{ component_cache };

    delete $cache->{ $_ }
        for qw( skin skitemap );

    $self->parent->builder_reset
        if $self->parent;
}

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
