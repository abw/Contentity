package Contentity::Config;

use Contentity::Cache;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Config::Filesystem Contentity::Base',
    utils     => 'truelike falselike extend merge split_to_list blessed Filter',
    accessors => 'parent',
    constants => 'HASH ARRAY',
    constant    => {
        # caching options
        CACHE_MANAGER => 'Contentity::Cache',
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    $self->debug_data("config", $config) if DEBUG;

    $self->{ parent } = $config->{ parent };

    # First call Badger::Config base class method to handle any 'items'
    # definitions and other general initialisation
    $self->init_config($config);

    # Then call the Badger::Config::Filesystem initialiser
    $self->init_filesystem($config);

    # Then call our own initialisation method
    $self->init_contentity($config);

    return $self;
}

sub init_contentity {
    my ($self, $config) = @_;
    $self->init_cache($config);
    $self->init_data_files;
    return $self;
}

sub init_cache {
    my ($self, $config) = @_;
    my $cache = $config->{ cache };

    if ($cache && blessed $cache) {
        $self->debug("got a cache object: $cache") if DEBUG;
        $self->{ cache } = $cache;
        return;
    }

    my $cconfig = $self->get('cache')  || return;
    my $manager = $config->{ manager } || $self->CACHE_MANAGER;

    class($manager)->load;

    $self->debug(
        "cache manager config for $manager: ",
        $self->dump_data($cconfig)
    ) if DEBUG;

    $self->debug("cache URI: ", $self->uri) if DEBUG;

    $cache = $manager->new(
        uri => $self->uri,
        %$cconfig,
    );

    $self->debug("created new cache manager: $cache") if DEBUG;
    $self->{ cache } = $cache;
}

sub init_data_files {
    my $self  = shift;
    my $files = $self->get('data_files') || return;
    $self->import_data_files($files);
    $files = split_to_list($files);
    $self->debug_data("data files: ", $files);
}

sub import_data_files {
    my $self = shift;

    while (@_) {
        my $files = shift;
        $files = split_to_list($files);

        foreach my $file (@$files) {
            $self->import_data_file($file)
        }
    }
}

sub import_data_file {
    my ($self, $file) = @_;
    my $data = $self->get($file)
        || $self->error_msg( invalid => 'data file' => $file );
    $self->debug_data("imported data from $file: ", $data) if DEBUG;
    merge($self->{ data }, $data);
}

sub import_data_file_if_exists {
    my ($self, $file) = @_;
    my $data = $self->get($file) || return;
    $self->debug_data("imported data from $file: ", $data) if DEBUG;
    merge($self->{ data }, $data);
}

# TODO: init_schema() init_schemas() and other configure_XXX() methods in
# Contentity::Metadata


#-----------------------------------------------------------------------------
# Additional methods used for getting and setting.
#
# head() is called to fetch the first (or only) item in a get() request
# tail() is called when the above head() call locates the data in question
#-----------------------------------------------------------------------------

sub head {
    my ($self, $name) = @_;
    my $data = $self->{ data };

    $self->debug_data("head($name) in ", $data) if DEBUG;

    # may be a cached result, including undef
    return $data->{ $name }
        if exists $data->{ $name };

    my $item =
            $self->cache_fetch($name)
        //  $self->fetch($name)
        //  $self->parent_fetch($name);

    # store undefined value to avoid repeated false lookups
    $data->{ $name } = $item if ! $item;

    return $item
}

# this is called after a successful fetch();

sub tail {
    my ($self, $name, $data, $schema) = @_;

    $schema ||= $self->schema($name);

    if (DEBUG) {
        $self->debug_data( "tail($name) data"   => $data );
        $self->debug_data( "tail($name) schema" => $schema );
    }

    # should we merge this with any parent data?

    if ($schema->{ merge }) {
        my $pdata = $self->parent_head($name);

        $self->debug(
            "MERGE\nparent=", ($self->{ parent } ?  $self->{ parent }->uri : 'none'), " ",
            "parent_head($name): ", $self->dump_data($pdata),
        ) if DEBUG;

        if ($pdata) {
            # we may fetch the parent data if the merge ruleset says we can
            $data = $self->merge_data($name, $pdata, $data, $schema);
        }

        $self->debug("merged data for $name: ", $self->dump_data($data)) if DEBUG;
    }

    return $self->tail_cache($name, $data, $schema);
}

sub tail_cache {
    my ($self, $name, $data, $schema) = @_;
    my $duration;

    $schema ||= $self->schema($name);

    $self->debug_data("tail_cache $name", $schema) if DEBUG;

    if ($data && $self->{ cache } && ($duration = $schema->{ cache })) {
        $self->debug("found cache duration option: $duration") if DEBUG;
        $self->cache_store($name, $data, $duration, $schema);
    }
    return $data;
}


#-----------------------------------------------------------------------------
# Methods for fetching and storing data in an optional cache
#-----------------------------------------------------------------------------

sub cache {
    my $self = shift;

    return $self->{ cache }
        unless @_;

    return @_ > 1
        ? $self->cache_store(@_)
        : $self->cache_fetch(@_);
}

sub cache_fetch {
    my ($self, $name) = @_;
    my $cache = $self->cache || return;
    my $data  = $cache->get($name);

    if (DEBUG) {
        if ($data) {
            $self->debug("cache_fetch($name) got data: ", $self->dump_data($data));
        }
        else {
            $self->debug("cache_fetch($name) found nothing");
        }
    }
    return $data;
}

sub cache_store {
    my ($self, $name, $data, $duration) = @_;
    my $cache = $self->cache || return;

    if (falselike($duration)) {
        $self->debug("cache $name never (duration:$duration)") if DEBUG;
        return;
    }

    # see if we need to set an expiry timestamp
    if (truelike($duration)) {
        $self->debug("cache $name forever (duration:$duration)") if DEBUG;
        $cache->set($name, $data);
    }
    else {
        $self->debug("cache $name for duration:$duration") if DEBUG;
        $cache->set($name, $data, "$duration");
    }
}


#-----------------------------------------------------------------------------
# Methods for fetching data from a parent configuration object
#-----------------------------------------------------------------------------

sub parent_fetch {
    my ($self, $name) = @_;
    #$self->debug("parent_fetch($name)  parent:$self->{parent}");
    my $parent = $self->{ parent  }   || return;
    my $data   = $parent->head($name) // return;

    $self->debug(
        "parent_fetch($name)\n",
        "DATA: ", $self->dump_data($data), "\n"
    ) if DEBUG;

    return $self->tail_cache($name, $data);
}

sub parent_head {
    my ($self, $name) = @_;
    my $parent = $self->{ parent  }   || return;
    return $parent->head($name);
}


#-----------------------------------------------------------------------------
# Methods for inheriting and/or merging data from child with data from parent
#-----------------------------------------------------------------------------

sub merge_data {
    my ($self, $name, $parent, $child, $schema) = @_;
    my $merged;

    $parent = {
        map { $_ => 1 }
        @$parent
    } if ref $parent eq ARRAY;

    if (DEBUG) {
        $self->debug("merge_data($name)");
        $self->debug("  PARENT: ", $self->dump_data($parent));
        $self->debug("  CHILD: ", $self->dump_data($child));
        $self->debug("  SCHEMA: ", $self->dump_data($schema));
    }

    return $child || $parent
        unless $child && $parent
            && ref($child)  eq HASH
            && ref($parent) eq HASH;

    my $submerge = $schema->{ submerge };

    if (! $submerge) {
        $self->debug("No submerge rules - doing a simple inherit") if DEBUG;
        $merged = {
            %$parent,
            %$child
        };
    }
    else {
        my $filter = $self->new_filter($submerge);

        # first inherit all items from the parent data set
        $merged = { %$parent };

        # then add (or merge) in any items from the child data set
        while (my ($key, $value) = each %$child) {
            if ($filter->item_accepted($key)) {
                $self->debug("merging $key") if DEBUG;
                my $old = $merged->{ $key };
                $value = $self->merge_data_item($name, $key, $old, $value)
                    if defined $old;
            }
            $merged->{ $key } = $value;
        }
    }

    $self->debug("MERGED: ", $self->dump_data($merged)) if DEBUG;
    return $merged;
}

sub merge_data_item {
    my ($self, $name, $key, $parent, $child) = @_;
    my $pref = ref $parent;
    my $cref = ref $child;

    if (DEBUG) {
        $self->debug("$name.$key parent: ", $self->dump_data($parent));
        $self->debug("$name.$key child:  ", $self->dump_data($child));
    }

    if ($pref eq HASH && $cref eq HASH) {
        $self->debug("$name.$key merging two hashes") if DEBUG;
        return { %$parent, %$child };
    }

    if ($pref eq ARRAY) {
        if ($cref eq ARRAY) {
            $self->debug("$name.$key merging two lists") if DEBUG;
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

sub new_filter {
    my ($self, $spec) = @_;

    if (! ref $spec) {
        # single word like 'all' or 'none'
        $spec = {
            accept => $spec
        };
    }
    elsif (ref $spec ne HASH) {
        $spec = {
            include => $spec
        };
    }

    $self->debug(
        "filter spec: ",
        $self->dump_data($spec),
    ) if DEBUG;

    return Filter($spec);
}


#-----------------------------------------------------------------------------
# Data schema management
#-----------------------------------------------------------------------------

sub schemas {
    # for now, schemas as the same thing as config items, but that may change
    # at some point in the future
    shift->{ item };
}

sub schema {
    # for now, schemas as the same thing as config items, but that may change
    # at some point in the future
    shift->item_schema(@_);
}

sub lookup_item {
    my $self    = shift;
    my $name    = shift;
    my $urn     = $name;
    my $schemas = $self->schemas;
    my $schema  = $schemas->{ $name };

    while (! $schema && length $name) {
        # keep chopping bits off the end of the name to find a more generic
        # schema, e.g. forms/user/login -> forms/user -> forms
        last unless $name =~ s/\W\w+\W?$//;
        $self->debug("trying $name") if DEBUG;
        $schema = $schemas->{ $name };
    }

    $self->debug("lookup_item for $name returning $schema") if DEBUG;
    return $schema;
}

#-----------------------------------------------------------------------------
# Parent management
#-----------------------------------------------------------------------------

sub attach {
    my ($self, $parent) = @_;
    $self->{ parent } = $parent;
}

sub detach {
    my $self = shift;
    delete $self->{ parent };
}


1;
