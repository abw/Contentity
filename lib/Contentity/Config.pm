# New attempt (Feb 11th 2014) to make subclass of Badger::Config with 
# additional caching

# Work in progress

package Contentity::Config;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Config Contentity::Base',
    utils     => 'truelike falselike extend Filter',
    constants => 'HASH ARRAY';

sub NOT_init {
    my ($self, $config) = @_;
    $self->init_config($config);
#    $self->init_contentity($config);  # ??
    $self->init_schemas($config);
#    $self->configure($config);
    return $self;
}

sub init_contentity {
    my ($self, $config) = @_;
    return $self;
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
    return $self->{ data }->{ $name }
        // $self->cache_fetch($name)
        // $self->fetch($name)
        // $self->parent_fetch($name);
}

sub tail {
    my ($self, $name, $data, $schema) = @_;
    my $rules = $self->{ inherit } || $self->{ merge };
    my $pdata = $self->parent_head($name, $rules);
    my $duration;

    $schema ||= $self->schema($name);

    $self->debug(
        "tail($name)\n  DATA: ", $self->dump_data($data), 
        "\n SCHEMA: ", $self->dump_data($schema)
    ) if DEBUG;

    $self->debug(
        "parent=", ($self->{ parent } ?  $self->{ parent }->uri : 'none'), " ",
        "parent_head($name): ", $self->dump_data($pdata), 
    ) if DEBUG;

    # if we've got some data from the parent item (implying that there is a 
    # parent and the rules in $self->{ merge } permit us to merge in data 
    # from the parent) then we merge it into the child data set.

    if ($pdata) {
        # we may fetch the parent data if the merge ruleset says we can 
        $data = $self->merge_data($name, $pdata, $data, $schema);
    }

    $self->debug("merged data for $name: ", $self->dump_data($data)) if DEBUG;

    if ($data && $self->{ cache } && ($duration = $schema->{ cache })) {
        $self->debug("found cache duration option: $duration") if DEBUG;
        $self->cache_store($name, $data, $duration, $schema);
    }
    return $data;
}


#-----------------------------------------------------------------------------
# Stub for subclasses
#-----------------------------------------------------------------------------

sub fetch {
    my ($self, $uri) = @_;
    return undef;
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
    my ($self, $name, $data, $expires) = @_;
    my $cache = $self->cache || return;

    if (falselike($expires)) {
        $self->debug("cache $name never") if DEBUG;
        return;
    }

    # see if we need to set an expiry timestamp
    if (truelike($expires)) {
        $self->debug("cache $name forever") if DEBUG;
        $cache->set($name, $data);
    }
    else {
        $self->debug("cache $name for $expires") if DEBUG;
        $cache->set($name, $data, "$expires");
    }
}


#-----------------------------------------------------------------------------
# Methods for fetching data from a parent configuration object
#-----------------------------------------------------------------------------

sub parent_fetch {
    my ($self, $name) = @_;
    my $parent = $self->{ parent  }                     || return;
    my $rules  = $self->{ inherit } || $self->{ merge } || return;
    my $data   = $self->parent_head($name, $rules)      // return;
    my $schema = $self->schema($name);
    my $duration;

    $self->debug(
        "parent_fetch($name)\n",
        "DATA: ", $self->dump_data($data), "\n",
        "SCHEMA: ", $self->dump_data($schema) 
    ) if DEBUG;

    # The schema for this particular data item may have rules about the 
    # items within it that should be inherited and/or merged from the 
    # parent data into the (empty) child
    $data = $self->merge_data($name, $data, undef, $schema);

    $self->debug("merged data for $name: ", $self->dump_data($data)) if DEBUG;

    if ($self->{ cache } && ($duration = $schema->{ cache })) {
        $self->debug("found cache duration option: $duration") if DEBUG;
        $self->cache_store($name, $data, $duration, $schema);
    }

    return $data;
}

sub parent_head {
    my ($self, $name, $rules) = @_;
    my $parent = $self->{ parent } || return;

    # The $rules option is either the "inherit" or "merge" Filter 
    # for the top-level config items.  This tells us if we're allowed
    # to inherit/merge from the parent
    if (! $rules) {
        $self->debug("No merge rules") if DEBUG;
        return undef;
    }

    if ($rules->item_accepted($name)) {
        $self->debug("YES, we can inherit/merge $name from parent") if DEBUG;
    }
    else {
        $self->debug("NO, we cannot inherit/merge $name from parent") if DEBUG;
        return undef;
    }

    $self->debug("Asking parent for $name") if DEBUG;

    return $parent->head($name);
}

#-----------------------------------------------------------------------------
# Methods for inheriting and/or merging data from child with data from parent
#-----------------------------------------------------------------------------

sub merge_data {
    my ($self, $name, $parent, $child, $schema) = @_;
    my $merged = { };

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

    my @keys = keys %$parent;
    my $inherit = $schema->{ inherit_filter };
    my $merge   = $schema->{ merge_filter   };

    if (! $inherit && ! $merge) {
        $self->debug("No inherit or merge rules - doing a simple inherit") if DEBUG;
        return {
            %$parent,
            %$child
        };
    }

    # first inherit the relevant items from the parent data set
    while (my ($key, $value) = each %$parent) {
        next if $inherit
            &&  $inherit->item_rejected($key);
        $merged->{ $key } = $value;
    }

    # then add (or merge) in any items from the child data set
    while (my ($key, $value) = each %$child) {
        if ($merge && $merge->item_accepted($key)) {
            my $old = $merged->{ $key };
            $value = $self->merge_data_item($name, $key, $old, $value)
                if defined $old;
        }
        $merged->{ $key } = $value;
    }

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


#-----------------------------------------------------------------------------
# Data schema management
#-----------------------------------------------------------------------------

sub schema {
    my $self = shift;
    my $name = shift || return $self->{ schema };
    my $full = $self->{ merged_schemas } ||= { };
    delete $full->{ $name } if @_;
    return $full->{ $name } 
        ||= $self->prepare_schema($name, @_);
}

sub prepare_schema {
    my ($self, $name, @args) = @_;
    my $schema = extend(
        { },
        $self->{ schema  },
        $self->lookup_schema($name),
        @args
    );
    if ($schema->{ inherit }) {
        $self->debug("adding inherit filter: ", $self->dump_data($schema->{ inherit })) if DEBUG;
        $schema->{ inherit_filter } = $self->configure_filter(
            inherit => $schema->{ inherit }
        );
    }
    if ($schema->{ merge }) {
        $self->debug("adding merge filter: ", $self->dump_data($schema->{ merge })) if DEBUG;
        $schema->{ merge_filter } = $self->configure_filter(
            merge => $schema->{ merge }
        );
    }
    return $schema;
}

sub lookup_schema {
    my $self    = shift;
    my $name    = shift;
    my $schemas = $self->{ schemas };
    my $schema  = $schemas->{ $name };

    while (! $schema && length $name) {
        # keep chopping bits off the end of the name to find a more generic
        # schema, e.g. forms/user/login -> forms/user -> forms
        last unless $name =~ s/\W\w+\W?$//;
        $self->debug("trying $name") if DEBUG;
        $schema = $schemas->{ $name };
    }
    return $schema;
}


1;
