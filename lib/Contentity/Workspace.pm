package Contentity::Workspace;

use Contentity::Config::Filesystem;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    utils       => 'params extend weaken join_uri resolve_uri self_params Duration',
    filesystem  => 'Dir VFS',
    accessors   => 'root superspace hub config_dir config_fs urn type',
    #autolook    => 'autoload_config',
    constants   => ':config DOT DELIMITER HASH ARRAY CODE SLASH',
    constant    => {
        DIRS           => 'dirs',
        DEFAULT_SCHEMA => '_default_',
        COMMON_SCHEMA  => '_common_',
        WORKSPACE_TYPE => 'workspace',
    },
    messages => {
        no_config             => 'No metadata found for %s',
        cannot_merge_metadata => "Cannot merge metadata for %s.%s (%s and %s)",
    };

# word: prefixes in directories and other paths are mapped to methods that 
# resolves the relative space, e.g. super => superspace, uber => uberspace
#our $RELATIVE_SPACES = {
#    map { $_ => $_ . 'space' }
#    qw( super uber )
#};

our $LOADERS    = {
    file       => 'config_file',
    tree       => 'config_tree',
    uri_tree   => 'config_uri_tree',
    under_tree => 'config_under_tree',
};


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workspace($config);
}

# TODO: we would like to be able to instantiate these objects from cached 
# config data... hmmm... or do we?  Perhaps we can keep the workspace live
# for a long time (which avoids having to stat the disk to check dirs, etc,
# on init) and instead agressively cache any additional metadata (pages, forms,
# etc)

sub init_workspace {
    my ($self, $config) = @_;
    my $class    = $self->class;
    my $hub      = delete $config->{ hub        } 
                || return $self->error_msg( missing => 'hub' );
    my $root     = delete $config->{ root       } 
                || delete $config->{ directory  }
                || delete $config->{ dir        } 
                || return $self->error_msg( missing => 'root' );
    my $type     = delete $config->{ type       }
                || $self->WORKSPACE_TYPE;
    my $cdir     = delete $config->{ config_dir }
                || $self->CONFIG_DIR;

    # root directory
    my $root_dir = Dir($root);
    unless ($root_dir->exists) {
        return $self->error_msg( invalid => 'root directory' => $root_dir );
    }

    # config directory and filesystem
    my $conf_dir = $root_dir->dir($cdir);
    my $config_fs = $self->CONFIG_FILESYSTEM->new(
        dir => $conf_dir,
    );

    # clean up anything else we don't want to store in the config
    delete $config->{ module };     # from hub/construct

    $self->{ hub        } = $hub;
    $self->{ root       } = $root_dir;
    $self->{ type       } = $type;
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

    # Should we now explicitly load any dirs.yaml file?
    # I'm thinking not.  There are issues with inheritance and resolving
    # directories relative to the workspace root.

    #$self->{ relative_spaces  } = $class->hash_vars( RELATIVE_SPACES => $config->{ relative_spaces } );

    return $self;
}

sub configure_workspace {
    my ($self, $config) = @_;
    my $base    = delete($config->{ base         }) || delete($config->{ superspace });
    my $dirs    = delete($config->{ dirs         });
    my $schemas = delete($config->{ schemas      });
    my $meta    = delete($config->{ metadata     });
    my $cfile   = delete($config->{ config_file  });
    my $cfiles  = delete($config->{ config_files });

    if ($base)      { $self->init_superspace($base);     }
    if ($dirs)      { $self->dirs($dirs);                }
    if ($schemas)   { $self->schemas($schemas);          }
    if ($meta)      { $self->metadata($meta);            }
    if ($cfile)     { $self->init_config_file($cfile);   }
    if ($cfiles)    { $self->init_config_files($cfiles); }

    if (%$config) {
        $self->debug(
            "things left over in $config: ", 
            $self->dump_data($config)
        ) if DEBUG;
        my $saved = $self->{ config };
        @$saved{ keys %$config } = values %$config; 
    }
}

sub init_config_files {
    my ($self, $files) = @_;
    foreach my $file (@$files) {
        $self->init_config_file($file);
    }
}

sub init_config_file {
    my ($self, $file) = @_;

    # config file can have '?' suffix if it's optional
    my $opt  = ($file =~ s/\?$//);

    # only ever need to load an initialisation config file once (I think!)
    my $done = $self->{ config_files_loaded } ||= { };
    return if $done->{ $file };
    $done->{ $file } = 1;

    # load the config file, throw an error if it's not found and not optional
    my $data = $self->config_file($file) 
        || return $opt 
            ? undef # $self->warn("Optional config file '$file' not found")
            : $self->error( $self->reason );

    $self->debug(
        "Loaded config data from file '$file': ",
        $self->dump_data($data)
    ) if DEBUG;

    $self->configure_workspace($data);
}

# make this just superspace() as a generic getter/setter?
sub init_superspace {
    my ($self, $superspace) = @_;
    unless (ref $superspace) {
        $self->todo("load superspace object: $superspace");
    }
    $self->debug("set superspace to $superspace") if DEBUG;
    $self->{ superspace } = $superspace;
}

sub init_schema {
    my ($self, $urn, $schema) = @_;
    my $schemas = $self->{ schemas };
    my $common  = $schemas->{ $self->COMMON_SCHEMA };
    my $cache;

    $self->debugf(
        "init_schema($urn, %s)",
        $self->dump_data_inline($schema)
    ) if DEBUG;

    # merge in any _common_ schema configuration
    if ($common) {
        $schema = {
            %$common,
            %$schema,
        };
        if (DEBUG) {
            $self->debug(
                "Common schema configuration: ", 
                $self->dump_data($common)
            );
            $self->debug(
                "Merged schema configuration: ", 
                $self->dump_data($schema)
            );
        }
    }

    # convert any cache parameter to a Badger::Duration object in order to 
    # validate it and internally convert it to a number of seconds.
    if ($cache = $schema->{ cache }) {
        $self->debug(
            "Found cache specification in '$urn' schema: $cache"
        ) if DEBUG;

        eval {
            $schema->{ cache } = Duration($cache);
        };
        if ($@) {
            return $self->error_msg( 
                invalid => "cache duration for $urn schema" => $cache
            );
        }
    }

    # stash the schema
    $schemas->{ $urn } = $schema;
}

sub metadata {
    my $self     = shift;
    my $metadata = $self->{ metadata } ||= { };
    if (@_ > 1) {
        my $addin = params(@_);
        @$metadata{ keys %$addin } = values %$addin;
    }
    elsif (@_ == 1) {
        return $metadata->{ $_[0] };
    }
    return $metadata;
}


#-----------------------------------------------------------------------------
# Methods for loading configuration files via config filesystem object
#-----------------------------------------------------------------------------

sub config {
    my ($self, @path) = @_;
    return $self->{ config } unless @path;
    my @todo = map { split /\./ } @path;
    my $head = shift @todo;
    my @done = ($head);

    $self->debug(
        "config path: [$head] ", 
        $self->dump_data(\@todo)
    ) if DEBUG;

    # get the data for the head item
    my $data =  
        $self->{ config }->{ $head }
    ||  $self->config_head($head) 
    ||  return $self->decline_msg( 
            no_config => $head
        );

    # resolve any dotted paths after the head
    while (@todo) {
        my $bit = shift @todo;

        if (exists $data->{ $bit }) {
            $data = $data->{ $bit };
            push(@done, $bit);
        }
        else {
            return $self->decline_msg( 
                no_config => join('.', @done, $bit)
            );
        }
    }

    return $data;
}

sub config_head {
    my ($self, $uri) = @_;
    my $schema = $self->schema($uri);
    my $cache  = $schema->{ cache };
    my $cdata  = $self->fetch_cached_data($uri, $schema) if $cache;
    my $data   = $cdata || $self->config_filesystem($uri, $schema);

    $self->debug(
        "metdata for $uri\nSCHEMA: ", 
        $self->dump_data($schema), 
        "\nDATA: ", 
        $self->dump_data($data)
    )  if DEBUG;

    if ($cdata) {
        # got data from the cache, that's cool
        $self->debug(
            "Got data from cache for $uri: ", 
            $self->dump_data($cdata)
        ) if DEBUG;
        return $cdata;
    }

    if ($schema) {
        # look to see if the schema says we should inherit some or all of 
        # this data from the parent superspace
        my $inherit = $schema->{ inherit };
        $self->debug("inherit option: $inherit") if DEBUG;
        $data = $self->inherit_metadata($uri, $data, $inherit)
            if $inherit;
    }

    $self->store_cached_data($uri, $data, $schema) 
        if $cache && $data;

    return $data;
}

sub config_filesystem {
    my ($self, $uri, $schema) = @_;

    if ($schema) {
        # look to see if the schema says we should inherit some or all of 
        # this data from the parent superspace
        my $loader = $schema->{ loader };

        if ($loader) {
            $self->debug("delegating $uri to $loader loader") if DEBUG;
            return $self->load($loader, $uri, $schema);
        }
    }

    return $self->config_file($uri);
}

sub config_file {
    shift->config_fs_method(
        file => fetch_file => @_
    );
}

sub config_tree {
    shift->config_fs_method(
        tree => fetch_tree => @_
    );
}

sub config_uri_tree {
    shift->config_fs_method(
        tree => fetch_uri_tree => @_
    );
}

sub config_under_tree {
    shift->config_fs_method(
        tree => fetch_uri_tree => @_
    );
}

sub config_fs_method {
    my ($self, $type, $method, @args) = @_;
    my $cfs = $self->config_fs;
    return $cfs->$method(@args)
        || $self->decline_msg( invalid => "config $type" => $cfs->reason );
}

#-----------------------------------------------------------------------------
# Loaders
#-----------------------------------------------------------------------------

sub load {
    my ($self, $load, $uri, $schema) = @_;
    my $loader = $self->loader($load) || return;
    $self->debug("loading via loader: $load") if DEBUG;
    return $loader->($self, $uri, $schema);
}

sub loader {
    my ($self, $name) = @_;
    my $loader = $self->loaders->{ $name }
        || return $self->error_msg( invalid => loader => $name );

    return $loader
        if ref $loader eq CODE;

    return $self->can($loader)
        || $self->error_msg( invalid => loader => "$name ($loader)" );
}

sub loaders {
    my $self    = shift;
    my $loaders = $self->{ loaders } ||= { };
    if (@_) {
        my $addin = params(@_);
        @$loaders{ keys %$addin } = values %$addin;
        $self->debug(
            "set loaders: ", 
            $self->dump_data($loaders)
        ) if DEBUG;
    }
    return $loaders;
}


#-----------------------------------------------------------------------------
# Schemas
#-----------------------------------------------------------------------------

sub schemas {
    my $self    = shift;
    my $schemas = $self->{ schemas } ||= { };
    if (@_) {
        my $addin = params(@_);

        # NOTE: this "Only Just Works[tm]" by chance because _common_ sorts 
        # before _default_ sort before all other alphanumeric strings.  So
        # the _common_ set gets installed first and this will be merged into
        # all subsequent schemas by init_schema()
        foreach my $key (sort keys %$addin) {
            $schemas->{ $key } = $self->init_schema($key, $addin->{$key})
        }
        $self->debug(
            "set schemas: ", 
            $self->dump_data($schemas)
        ) if DEBUG;
    }
    return $schemas;
}

sub schema {
    my ($self, $path) = @_;
    my $schemas = $self->schemas;
    my $name    = $path;
    my $schema  = $schemas->{ $name };

    $self->debug("tried $name") if DEBUG;

    while (! $schema && length $name) {
        # keep chopping bits off the end of the name to find a more generic
        # schema, e.g. forms/user/login -> forms/user -> forms
        last unless $name =~ s/\W\w+\W?$//;
        $self->debug("trying $name") if DEBUG;
        $schema = $schemas->{ $name };
    }

    if (! $schema) {
        $name   = $self->DEFAULT_SCHEMA;
        $schema = $schema->{ $name };
    }

    if ($schema) {
        $self->debug("Got schema for [$name] when [$path] was requested") if DEBUG;
    }

    return $schema;
}


#-----------------------------------------------------------------------------
# Metadata inheritance
#-----------------------------------------------------------------------------

sub inherit_metadata {
    my ($self, $uri, $data, $inherit) = @_;
    my (@inc, @exc, @mer, @items, $spec);

    $self->debug("inherit: $uri rule: $inherit") if DEBUG;

    # Inspect the $inherit option which can be one of:
    #   'none'                      - no inheritance
    #   'all'                       - inherit everything
    #   'foo bar -baz +bam'         - include foo and bar, exclude baz, merge bam
    #   ['foo','bar','-baz','+bam'] - same as above as list
    #   { include => 'foo bar',     - same as above as hash
    #     exclude => 'baz',
    #     merge   => 'bam',
    #   }
    if (! ref $inherit) {
        if ($inherit eq 'none') {
            return $data;
        }
        elsif ($inherit eq 'all') {
            # no specific inherit rules - accept everything
            $inherit = { };
        }
        else {
            # list of "item" (include), "-item" (exclude) or "+item" (merge)
            @items = split(/[^\w\-\+]+/, $inherit);
            $inherit = { };
        }
    }
    elsif (ref $inherit eq HASH) {
        $spec = $inherit->{ include };
        @inc  = split(/\W+/, $spec) if $spec;
        $spec = $inherit->{ exclude };
        @exc  = split(/\W+/, $spec) if $spec;
        $spec = $inherit->{ merge };
        @mer  = split(/\W+/, $spec) if $spec;
    }
    elsif (ref $inherit eq ARRAY) {
        @items = @$inherit;
        $inherit = { };
    }
    else {
        return $self->error_msg( invalid => 'inherit option' => $inherit );
    }

    # Now that we know there's something to be inherited, we go and see if 
    # there's a superspace and if it has any data for us to inherit, otherwise
    # we return the subspace data (which may be undef)
    my $super = $self->superspace      || return $data;
    $self->debug("superspace of $self: $super") if DEBUG;
    my $sdata = $super->config_head($uri) || return $data;
    $self->debug("superdata: $sdata: ", $self->dump_data($sdata)) if DEBUG;

    # if we have a list of mixed items we need to separate them into include,
    # exclude (-) and merge (+) items
    if (@items) {
        foreach my $item (@items) {
            if      ($item =~ s/^\-//)  { push(@exc, $item); }
            elsif   ($item =~ s/^\+//)  { push(@mer, $item); }
            else                        { push(@inc, $item); }
        }
        if (DEBUG) {
            $self->debug("include items: ", $self->dump_data(\@inc));
            $self->debug("exclude items: ", $self->dump_data(\@exc));
            $self->debug("merge items:   ", $self->dump_data(\@mer));
        }
    }

    # build hash lookup tables for include, exclude and merge items
    my $inc = $inherit->{ include } = { map { $_ => 1 } @inc } if @inc;
    my $exc = $inherit->{ exclude } = { map { $_ => 1 } @exc } if @exc;
    my $mer = $inherit->{ merge   } = { map { $_ => 1 } @mer } if @mer;

    $self->debug(
        "inherit rules: ", 
        $self->dump_data($inherit)
    )  if DEBUG;

    # construct composite hash from parent data and current data, 
    # using the include, exclude and merge rules defined above
    my $comp = { };

    # $data might be undef if there's no child data, but we know we've got stuff
    # to inherit now so we can assume it's an empty hash
    $data ||= { };

    # first inherit the relevant items from the parent data set
    while (my ($key, $value) = each %$sdata) {
        if ($inc) {
            # only include items lists (or those listed as merge items)
            next unless $inc->{ $key }
                || $mer && $mer->{ $key };
        }
        if ($exc) {
            # specifically exclude items lists
            next if $exc->{ $key };
        }
        $comp->{ $key } = $value;
    }

    # then add (or merge) in any items from the child data set
    while (my ($key, $value) = each %$data) {
        if ($mer && $mer->{ $key }) {
            my $old = $comp->{ $key };
            $value = $self->merge_metadata($uri, $key, $old, $value)
                if defined $old;
        }
        $comp->{ $key } = $value;
    }

    return $comp;
}

sub merge_metadata {
    my ($self, $uri, $key, $parent, $child) = @_;
    my $pref = ref $parent;
    my $cref = ref $child;

    if (DEBUG) {
        $self->debug("$uri.$key parent: ", $self->dump_data($parent));
        $self->debug("$uri.$key child:  ", $self->dump_data($child));
    }

    if ($pref eq HASH && $cref eq HASH) {
        $self->debug("$uri.$key merging two hashes") if DEBUG;
        return { %$parent, %$child };
    }

    if ($pref eq ARRAY) {
        if ($cref eq ARRAY) {
            $self->debug("$uri.$key merging two lists") if DEBUG;
            return [ @$parent, @$child ];
        }
        else {
            return [ @$parent, $child ];
        }
    }

    if ($cref eq ARRAY) {
        return [ $parent, @$child ];
    }

    return [ $parent, $child ];
}


#-----------------------------------------------------------------------------
# Data cache
#-----------------------------------------------------------------------------

sub cache {
    # subclasses may define a cache
    return undef;
}

sub fetch_cached_data {
    my ($self, $key, $schema) = @_;
    my $cache    = $self->cache       || return;
    my $duration = $schema->{ cache } || return;
    my $uri      = $self->uri($key);
    my $data     = $cache->get($uri);

    $self->debug(
        "fetch_cached_data($key, [uri:$uri] [duration:$duration])\n",
        "Data loaded from cache: ",
        $self->dump_data($data)
    ) if DEBUG && $data;

    return $data;
}

sub store_cached_data {
    my ($self, $key, $data, $schema) = @_;
    my $cache    = $self->cache       || return;
    my $duration = $schema->{ cache } || return;
    my $uri      = $self->uri($key);
    my $seconds  = $duration->seconds;

    # TODO: expiry times > 30 days are assumed to be unix timestamps
    $cache->set($uri, $data, $seconds);
    $self->debug(
        "store_cached_data($key [uri:$uri] [duration:$duration]): ", 
        $self->dump_data($data)
    ) if DEBUG;

    return $data;
}

#-----------------------------------------------------------------------------
# General purpose methods
#-----------------------------------------------------------------------------

sub uri {
    my $self = shift;
    return @_
        ? sprintf("%s%s", $self->{ uri }, resolve_uri(SLASH, @_))
        : $self->{ uri };
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


sub project {
    shift->hub->project;
}

#-----------------------------------------------------------------------------
# Sub-projects
#-----------------------------------------------------------------------------

sub uberspace {
    my $self = shift;
    return $self->{ superspace }
        ?  $self->{ superspace }->uberspace
        :  $self;
}

sub roots {
    my $self   = shift;
    my $super  = $self->superspace;
    my $roots  = $super ? $super->roots : [ ];
    push(@$roots, $self->root);
    return $roots;
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    $self->debug("space $self->{ uri } is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
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
