package Contentity::Project;

use Contentity::Components;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Workspace::Web',
    utils       => 'self_params id_safe split_to_list join_uri extend',
    constants   => ':vhost DOT HASH',
    constant    => {
        SUBSPACE_MODULE => 'Contentity::Workspace',
        WORKSPACE_TYPE  => 'project',
        WORKSPACES      => 'workspaces',
    },
    messages => {
        no_workspaces       => "There aren't any other workspaces defined",
        no_domain_workspace => "There isn't any workspace defined for the '%s' domain",
    };



#-----------------------------------------------------------------------------
# Workspace management
#-----------------------------------------------------------------------------

sub workspace {
    my $self = shift;
    my $uri  = shift;
    return  $self->{ workspace }->{ $uri } //= $self->load_workspace($uri);
}

sub load_workspace {
    my $self   = shift;
    my $uri    = shift;
    my $base   = $self;
    # Additional argument may be passed to us, e.g. by reload_workspace()
    my $config = $self->workspace_config($uri, @_)
        || return $self->error( $self->reason );

    $self->debug("workspace config: ", $self->dump_data($config)) if DEBUG;

    # We want to be able to define the 'base' workspace in the config/site.yaml
    # (or appropriate) config file for a workspace.  This requires a bit of a
    # kludge in the workspace initialisation.  If it sees a 'base' parameter
    # then it looks at the parent workspace URI to see if it matches.  If it
    # doesn't then it calls back to the project to reload the workspace (via the
    # reload_workspace() method), specifying the new base class named which
    # gets patched into the configuration.  We end up back here in the
    # load_workspace() method with the base option set.  So we load it up and
    # ask it to create a subspace with the relevant configuration details.
    # Thus, the correct base workspace eventually becomes the parent of
    # the newly created workspace.
    if ($config->{ base }) {
        $self->debug("fetching base workspace for $uri: $config->{ base }") if DEBUG;
        $base = $self->workspace( $config->{ base } );
    }

    return $base->subspace(
        $config
    );
}

sub reload_workspace {
    my $self = shift;
    my $uri  = shift;

    # Note: we forward any extra arguments so they can be used to update the
    # relevant workspace_config() entry
    return $self->{ workspace }->{ $uri }
        =  $self->load_workspace($uri, @_);
}

sub workspace_configs {
    my $self = shift;
    return  $self->{ all_workspace_configs }
        ||= $self->load_workspace_configs;
}

sub reload_workspace_configs {
    my $self = shift;
    return $self->{ all_workspace_configs }
        =  $self->load_workspace_configs;
}

sub load_workspace_configs {
    my $self    = shift;
    my $configs = $self->config(WORKSPACES) || { };

    # In addition to any workspaces defined in workspaces.yaml, we also look
    # in any workspace_dirs defined to locate additional workspaces.  These
    # get added into $configs

    $self->workspace_dirs_configs($configs);

    return %$configs
        ?   $configs
        :   $self->decline_msg('no_workspaces');
}

sub workspace_config {
    my $self    = shift;
    my $uri     = shift;
    my $configs = $self->workspace_configs || return;
    my $config  = $configs->{ $uri }
        || return $self->error_msg( invalid => workspace => $uri );

    # subspace root directory is relative to project workspace root
    $config->{ root }   = $self->dir( $config->{ root } );
    $config->{ uri  } ||= $uri;

    if (@_) {
        # Additional arguments can be passed in to update the configuration.
        # For example, a workspace can discover that it's supposed to have a
        # base workspace via it's own workspace.yaml configuration file. In
        # that case it can call reload_workspace($uri, { base => $whatever})
        # which will pass those updated arguments onto this method.  Here we
        # push them into the configuration for that workspace
        extend($config, @_);
    }

    return $config;
}

sub workspace_names {
    my $self   = shift;
    my $spaces = $self->workspace_configs;
    my @names  = sort keys %$spaces;

    return wantarray
        ?  @names
        : \@names;
}

sub workspace_dirs_configs {
    my $self    = shift;
    my $configs = shift || { };
    my $dirs    = $self->config('workspace_dirs') || return $configs;
    my ($kids, $kid, $name, $kuri, $kdir, $config);

    $dirs = split_to_list($dirs);

    $self->debug_data("workspace dirs:" => $dirs ) if DEBUG;

    foreach my $dircfg (@$dirs) {
        my ($dir, $uri, $root, $type);

        if (ref $dircfg eq HASH) {
            $dir  = $dircfg->{ directory }
                || return $self->error_msg( missing => "workspace_dirs directory" );
            $uri  = $dircfg->{ uri } || $dir;
            $type = $dircfg->{ type };
            $root = $self->dir($dir)->must_exist;
        }
        elsif (! ref $dircfg) {
            $dir  = $dircfg;
            $uri  = $dircfg;
            $root = $self->dir($dir)->must_exist;
            $type = undef;
        }
        else {
            return $self->error_msg( invalid => workspace_dirs => $dir );
        }

        $self->debug("workspace dir: [uri:$uri] => [dir:$dir] => [root:$root]") if DEBUG;

        my @configs = $self->workspace_dir_configs($root, $dir, $uri, $type);
        $self->debug_data( configs => \@configs) if DEBUG;

        foreach my $config (@configs) {
            my $kuri = $config->{ uri };
            $configs->{ $kuri } = $config;
        }
    }
    return $configs;
}

sub workspace_dir_configs {
    my ($self, $base, $dir, $uri, $type) = @_;
    my $kids   = $base->dirs;
    my $cfgdir = $self->CONFIG_DIR;
    my @configs;

    $self->debug_data("sub-dirs" => $kids) if DEBUG;

    foreach my $kid (@$kids) {
        my $name   = $kid->name;
        my $kdir   = join_uri($dir, $name);
        my $kuri   = join_uri($uri, $name);

        if ($kid->dir($cfgdir)->exists) {
            # If the sub-directories has a config directory then we assume
            # it's a workspace.  It's not a perfect test but it's the one
            # thing that we require to create a workspace object for it, so
            # we should at least weed out those that don't.
            my $config = {
                uri  => $kuri,
                root => $kdir,
                type => $type,
            };
            $self->debug_data("added workspace config for $kuri" => $config ) if DEBUG;
            push(@configs, $config);
        }
        else {
            $self->debug("traversing into $dir directory") if DEBUG;
            # if there isn't a config directory then it's not a workspace
            # but it might be a directory containing workspaces in sub-dirs
            my @subcfgs = $self->workspace_dir_configs($kid, $kdir, $kuri, $type);
            $self->debug("grandkids: ", join(', ', @subcfgs)) if DEBUG;
            unshift(@configs, @subcfgs);
        }
    }
    return wantarray
        ?  @configs
        : \@configs;
}

sub workspace_dir_names {
    my $self = shift;
    my $dirs = $self->workspace_dirs || return;
    # TODO: should we check that these are real workspace directories?
    return [
        map { $self->name }
        @$dirs
    ];
}


sub workspace_name_hash {
    my $self  = shift;
    my $names = $self->workspace_names;
    return {
        map { $_ => $_ }
        @$names
    };
}

sub all_workspaces {
    my $self   = shift;
    my $names  = $self->workspace_names;
    my @spaces;
    foreach my $name (@$names) {
        push(@spaces, $self->workspace($name));
    }
    return wantarray
        ?  @spaces
        : \@spaces;
}

sub all_workspaces_hash {
    my $self   = shift;
    my $names  = $self->workspace_names;
    my $spaces = { };
    foreach my $name (@$names) {
        $spaces->{ $name } = $self->workspace($name);
    }
    return $spaces;
}

sub has_workspace {
    my $self = shift;
    my $hash = $self->workspace_name_hash;
    return $hash unless @_;
    my $name = shift;
    return $hash->{ $name };
}


#-----------------------------------------------------------------------------
# Virtual hosts
#-----------------------------------------------------------------------------

sub vhosts_file {
    my $self = shift;
    my $name = shift || return $self->error_msg( missing => 'vhosts file name' );
    $self->file( vhosts => id_safe($name).DOT.VHOST_EXTENSION );
}

sub vhosts_file_exists {
    shift->vhost_file(@_)->exists;
}

sub vhost_extension {
    return VHOST_EXTENSION;
}





1;


__END__


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

sub lists {
    shift->component('lists');
}

sub list {
    shift->lists->resource(@_);
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
    return $self->config($name);
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
