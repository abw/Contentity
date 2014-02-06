package Contentity::Metadata;

use Badger::Debug ':all';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Contentity::Base',
    utils     => 'blessed self_params numlike falselike truelike extend
                  join_uri resolve_uri Filter',
    constants => 'SLASH HASH ARRAY CODE',
    accessors => 'schemas data',
    messages  => {
        get         => 'Cannot fetch configuration item <1>.<2> (<1> is <3>)',
        no_metadata => 'No metadata found for %s',
    };

our $CODECS     = { };
our $TREE_TYPE  = 'nest';
our $TREE_JOINT = '_';


#-----------------------------------------------------------------------------
# Initialisation methods called at object creation time
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->debug("init_metadata() config: ", $self->dump_data($config)) if DEBUG;
    $self->init_metadata($config);
    $self->init_schemas($config);
    $self->configure($config);
    return $self;
}

sub init_metadata {
    my ($self, $config) = @_;
    $self->{ data } = { };#delete $config->{ data } || $config; #{ %$config };
    #$self->debug("init_data(): ", $self->dump_data($self->{ data }));
}

sub init_schemas {
    my ($self, $config) = @_;
    my $class   = $self->class;
    my $schema  = $config->{ schema  } || { };
    my $schemas = $config->{ schemas };

    $self->{ schema  } = { };
    $self->{ schemas } = { };

    $schema->{ uri_paths  } 
        ||= delete $config->{ uri_paths }
        ||  $class->any_var('URI_PATHS');

    $schema->{ tree_type  } 
        ||= delete $config->{ tree_type }
        ||  $class->any_var('TREE_TYPE');

    $schema->{ tree_joint } 
        ||= delete $config->{ tree_joint }
        ||  $class->any_var('TREE_JOINT');

    $self->configure_schema($schema);
    $self->configure_schemas($schemas) if $schema;
}


#-----------------------------------------------------------------------------
# Configuration methods called at initialisation time or some time after
#-----------------------------------------------------------------------------

sub configure {
    my ($self, $config) = self_params(@_);
    my $item;

    # simple values we can copy straight in
    foreach $item (qw( uri parent )) {
        $self->{ $item } = delete $config->{ $item }
            if $config->{ $item };
    }

    # A bit of hackery to allow the config object to load configuration options
    # for the cache and store it like any other data.  Badger::Workspace then
    # reads the cache config, creates a cache object and passes it to this 
    # method to have it set.  So me must detect the difference between an
    # object and raw data.
    $self->configure_cache($item) 
        if ($item = delete $config->{ cache });

    # various other configuration options
    $self->configure_schema($item) 
        if ($item = delete $config->{ schema });

    $self->configure_schemas($item)
        if ($item = delete $config->{ schemas });

    $self->{ inherit } = $self->configure_filter( inherit => $item )
        if ($item = delete $config->{ inherit });

    $self->{ merge } = $self->configure_filter( merge => $item )
        if ($item = delete $config->{ merge });

    #$self->configure_file($item)
    #    if ($item = delete $config->{ file });

    $self->configure_data($config);
}

sub configure_cache {
    my ($self, $cache) = @_;

    # A bit of hackery to allow the config object to load configuration options
    # for the cache and store it like any other data.  Badger::Workspace then
    # reads the cache config, creates a cache object and passes it to this 
    # method to have it set.  So me must detect the difference between an
    # object and raw data.
    if (blessed $cache) {
        $self->debug("Got a new cache object: $cache") if DEBUG;
        $self->{ cache } = $cache;
    }
    else {
        $self->debug("Got a new cache config: ", $self->dump_data($cache)) if DEBUG;
        $self->{ data }->{ cache } = $cache;
    }
}

sub configure_schema {
    my ($self, $more) = @_;
    my $schema = $self->{ schema } ||= { };
    @$schema{ keys %$more } = values %$more;
}

sub configure_schemas {
    my ($self, $more) = @_;
    my $schemas = $self->{ schemas } ||= { };
    @$schemas{ keys %$more } = values %$more;
}

sub configure_filter {
    my ($self, $name, $spec) = @_;

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
        "$name filter spec: ", 
        $self->dump_data($spec),
    ) if DEBUG;

    return Filter($spec);
}

sub configure_data {
    my ($self, $data) = @_;

    if (%$data) {
        $self->debug(
            "merging data, OLD: ", 
            $self->dump_data($self->{ data }),
            "\nNEW: ",
            $self->dump_data($data)
        ) if DEBUG;
        my $main_data = $self->{ data };
        @$main_data{ keys %$data } = values %$data; 
    }
}


#sub configure_file {
#    my ($self, $name) = @_;
#    my $data = $self->config_file_data($name)
#        || return $self->error_msg( invalid => file => $name );
#
#    $self->debug(
#        "Config file data from $name: ",
#        $self->dump_data($data)
#    ) if DEBUG;
#
#    $self->configure($data);
#}



#-----------------------------------------------------------------------------
# Public-facing get() and set() methods
#-----------------------------------------------------------------------------

sub get {
    my $self  = shift;
    my @names = map { ref $_ eq ARRAY ? @$_ : split /\./ } @_;
    my $name  = shift @names;

    $self->debug(
        "get: [", 
        join('].[', $name, @names),
        "]"
    ) if DEBUG;
    
    # fetch the head item
    my $data = $self->head($name) 
        //  return $self->decline_msg( 
                no_metadata => $name
            );

    return @names
        ? $self->dot($name, $data, \@names)
        : $data;
}

sub set {
    my $self = shift->prototype;
    my $name = shift;
    my $data = @_ == 1 ? shift : { @_ };
    $self->debug("set $name => $data") if DEBUG;
    $self->{ data }->{ $name } = $data;
    return $data;
}



#-----------------------------------------------------------------------------
# Additional methods used for getting and setting.
#
# head() is called to fetch the first (or only) item in a get() request
# tail() is called when the above head() call locates the data in question
# dot() is used to resolve any further navigation into the data.
#
# e.g. get('user.name') is roughly equivalent to dot(head('user'), 'name')
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

sub dot {
    my ($self, $name, $data, $dots) = @_;
    my @done = ($name);
    my ($dot, $last, $method);

    $self->debug(
        "dot: [", 
        join('].[', $name, @$dots),
        "]"
    ) if DEBUG;
    

    # resolve any dotted paths after the head
    foreach $dot (@$dots) {
        # call any function reference to return a value
        if (ref $data eq CODE) {
            $data = $data->();
        }

        CHECK: {
            if (ref $data eq HASH) {
                $data = $data->{ $dot };
                last CHECK;
            }
            elsif (ref $data eq ARRAY) {
                if (numlike $dot) {
                    $data = $data->[$dot];
                    last CHECK;
                }
                # else vmethods?
            }
            elsif (blessed $data) {
                if ($method = $data->can($dot)) {
                    $data = $method->($dot);
                    last CHECK;
                }
            }
            return $self->decline_msg( 
                no_metadata => join('.', @done, $dot)
            );
        }

        if (! defined $data) {
            return $self->decline_msg( 
                no_metadata => join('.', @done, $dot)
            );
        }
        push(@done, $dot);
    }

    return $data;
}

#-----------------------------------------------------------------------------
# fetch() is designed to be re-implemented by sub-classes
#-----------------------------------------------------------------------------

sub fetch {
    my ($self, $name) = @_;
    return $self->{ data }->{ $name };
}

#-----------------------------------------------------------------------------
# Methods for fetching and storing data in a cache
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
# Parent: fallback for when data isn't found
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
# Binder methods for combining multiple data sources (e.g. files in sub-
# directories) into a single tree.
#-----------------------------------------------------------------------------

sub tree_binder {
    my $self = shift;
    my $name = shift 
        || $self->{ tree_type } 
        || return $self->error_msg( missing => 'tree_type' );

    return $self->can("${name}_binder")
        || return $self->decline_msg( invalid => binder => $name );
}

sub nest_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $data = $parent;

    foreach my $key (@$path) {
        $data = $data->{ $key } ||= { };
    }
    while (my ($key, $value) = each %$child) {
        $data->{ $key } = $value;
    }
}

sub flat_binder {
    my ($self, $parent, $path, $child, $schema) = @_;

    while (my ($key, $value) = each %$child) {
        $parent->{ $key } = $value;
    }
}

sub join_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $joint = $schema->{ tree_joint } || $self->{ tree_joint };
    my $base  = join($joint, @$path);

    $self->debug(
        "join_binder path is set: ", 
        $self->dump_data($path),
        "\nnew base is $base"
    ) if DEBUG;

    # Similar to the above but this joins items with underscores
    # e.g. an entry "foo" in site/bar.yaml will become "bar_foo"
    while (my ($key, $value) = each %$child) {
        if ($key =~ s/^\///) {
            # if the child item has a leading '/' then we want to put it in 
            # the root so we leave $key unchanged
        }
        elsif (length $base) {
            # otherwise the $key is appended onto $base
            $key = join($joint, $base, $key);
        }
        $parent->{ $key } = $value;
    }
}

sub uri_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $opt  = $schema->{ uri_paths } || $self->{ uri_paths };
    my $base = join_uri(@$path);

    $self->debug("uri_paths option: $opt") if DEBUG;

    $self->debug(
        "uri_binder path is set: ", 
        $self->dump_data($path),
        "\nnew base is $base"
    ) if DEBUG;

    # This resolves base items as URIs relative to the parent
    # e.g. an entry "foo" in the site/bar.yaml file will be stored in the parent 
    # site as "bar/foo", but an entry "/bam" will be stored as "/bam" because 
    # it's an absolute URI rather than a relative one (relative to the $base)
    while (my ($key, $value) = each %$child) {
        my $uri = $base ? resolve_uri($base, $key) : $key;
        if ($opt) {
            $uri = $self->fix_uri_path($uri, $opt);
        }
        $parent->{ $uri } = $value;
        $self->debug(
            "loaded metadata for [$base] + [$key] = [$uri]"
        ) if DEBUG;
    }
}

sub fix_uri_path {
    my ($self, $uri, $option) = @_;

    $option ||= $self->{ uri_paths } || return $uri;

    if ($option eq 'absolute') {
        $self->debug("setting absolute URI path") if DEBUG;
        $uri = "/$uri" unless $uri =~ /^\//;
    }
    elsif ($option eq 'relative') {
        $self->debug("setting relative URI path") if DEBUG;
        $uri =~ s/^\///;
    }
    else {
        return $self->error_msg( invalid => 'uri_paths option' => $option );
    }

    return $uri;
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

#-----------------------------------------------------------------------------
# Internal methods
#-----------------------------------------------------------------------------

sub uri {
    my $self = shift;
    my $base = $self->{ uri };
    return $base unless @_;
    my $path = resolve_uri(SLASH, @_);
    return $path unless $base;
    return sprintf("%s%s", $base, $path);
}




1;

__END__

=head1 NAME

Contentity::Metadata - metadata management module

=head1 SYNOPSIS

    use Contentity::Metadata;
    
    my $meta = Contentity::Metadata->new(
        foo => 10,
        bar => [20, 30, 40],
        baz => { wam => 'bam' },
    );

    print $meta->get('foo');        # 10
    print $meta->get('bar.0');      # 20
    print $meta->get('baz.wam');    # bam

=head1 DESCRIPTION

This module implements a metadata management system. 

=head1 CONFIGURATION OPTIONS

=head2 data

Metadata can be provided via the C<data> named parameter:

    my $config = Contentity::Metadata->new(
        data => {
            name  => 'Arthur Dent',
            email => 'arthur@dent.org',
        },
    );

=head2 schema

The default schema for metadata items.

=head2 schemas

A hash array of schemas for specific metadata items.

=head2 tree_type

This option can be used to sets the default tree type for any configuration 
items that don't explicitly declare it by other means.  The default tree
type is C<nest>.  

The following tree types are supported:

=head3 nest

This is the default tree type, creating nested hash arrays of data.

=head3 join

Joins data paths together using the C<tree_joint> string which is C<_> by
default.

=head3 uri

Joins data paths together using slash characters to create URI paths.
An item in a sub-directory can have a leading slash (i.e. an absolute path)
and it will be promoted to the top-level data hash.

e.g.

    foo/bar + baz  = foo/bar/baz
    foo/bar + /bam = /bam

=head3 none

No tree is created.  No sub-directories are scanned.   You never saw me.
I wasn't here.

=head2 tree_joint

This option can be used to sets the default character sequence for joining
paths

=head1 METHODS

The following methods are implemented in addition to those inherited from
the L<Badger::Config> base class.

new, configure
get set


=head1 INTERNAL METHODS

=head2 init_metadata($config)

=head2 init_schemas($config)

=head2 configure_cache($cache)

=head2 configure_schema($schema)

=head2 configure_schemas($schemas)

=head2 configure_filter($filter)

=head2 configure_data($data)

=head2 head($name)

=head2 tail($name, $data, $schema)

=head2 dot($name, $data, $dots)

=head2 fetch($name)

=head2 cache($name)

=head2 cache_fetch($name)

=head2 cache_store($name, $data, $expires)

=head2 parent_fetch($name)

=head2 parent_head($name)

=head2 merge_data($name, $parent, $child, $schema)

=head2 merge_data_item($name, $item, $parent, $child, $schema)

=head2 schema($name)

=head2 prepare_schema($name, @args)

=head2 lookup_schema($name)

=head2 tree_binder($name)

This method returns a reference to one of the binder methods below based
on the C<$name> parameter provided.

    # returns a reference to the nest_binder() method
    my $binder = $config->tree_binder('nest');

If no C<$name> is specified then it uses the default C<tree_type> of C<nest>.
This can be changed via the L<tree_type> configuration option.

=head2 nest_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<nest> L<tree_type>.

=head2 flat_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<flat> L<tree_type>.

=head2 uri_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<uri> L<tree_type>.

=head2 join_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<join> L<tree_type>.

=head2 uri($urn)

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
