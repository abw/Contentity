package Contentity::Database::Table;

use Contentity::Utils;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Table Contentity::Database::Component',
    import    => 'class',
    accessors => 'spec singular plural about',
    utils     => 'split_to_list self_params self_keys params',
    autolook  => 'autolook_query',
    constants => 'DOT ARRAY HASH MYSQL_WILDCARD',
    constant  => {
        RECORD  => 'Contentity::Database::Record',
        RESULTS => 'Contentity::Database::Results',
        SEARCH  => 'Contentity::Database::Search',
    };

our $FRAGMENTS = {
    select_rows  => 'SELECT <tcolumns> FROM <table>',
    row_compare  => '<table>.name',      # subclasses may need to redefine this
    group_by     => ' ',
    row_order    => ' ',
};

our $QUERIES = {
    all_rows => q{
        <select_rows>
        <group_by>
        <row_order>
    },
    any_rows => q{
        <select_rows>
        WHERE       <row_compare> = ?
        <group_by>
        <row_order>
    },
    any_rows_like => q{
        <select_rows>
        WHERE       <row_compare> like ?
        <group_by>
        <row_order>
    },
    found_rows      => 'SELECT FOUND_ROWS() AS count',
};

sub init {
    my ($self, $config) = @_;

    $self->debug_data( table => $config ) if DEBUG;

    $self->{ model } = $config->{ model }
        || return $self->error_msg( missing => 'model' );

    $self->{ hub } = $self->{ model }->workspace;
    $self->debug("Table hub: ", $self->hub) if DEBUG;

    # Bother.  Badger::Database::Table is already storing a list of column
    # names in $self->{ columns }
    my $schema = { %$config };
    delete $schema->{ model  };
    delete $schema->{ engine };
    $self->{ spec } = $schema;
    $self->debug_data( schema => $schema ) if DEBUG;

    my $cols = $config->{ columns };

    # Additional initialisation for columns before we hand things over to the
    # Badger::Database::Table base class initialiser methods.
    $self->init_columns($config, $cols) if $cols;

    $self->{ messages } = $config->{ messages };
    $self->{ singular } = $config->{ singular }
       || $config->{ record }      # See note below
       || $config->{ name   }
       || $config->{ table  };

    $self->{ plural } = $config->{ plural }
       || Contentity::Utils::plural($self->{ singular });

    # save some other things of interest
    $self->{ about } = $config->{ about };

    # In the contentity config, we're using table/record to denote the
    # plural/singular forms, e.g. users/user, and the more explicit
    # table_module and record_module to indicate the relevant module classes.
    # So we temporarily blank any 'record' entry defined in here
    local $config->{ record } = undef;

    # Variant of Badger::Database::Table init() method
    #$self->init_database($config);
    $self->init_schema($config);
    $self->init_queries($config);
    $self->init_table($config);

    # set the THROWS to a sensible name for the record class
    class($self->{ record })->throws(
        $self->model->table_throws( $self->{ singular } )
    );

    return $self;
}

sub init_columns {
    my ($self, $config, $columns) = @_;

    # fields defaults to everything specified in columns
    $config->{ fields } ||= [ keys %$columns ];

    # if there isn't an update or updateable list defined then we extract those
    # columns that have an update flag set to any true-ish value
    #$config->{ update } ||= $config->{ updateable } || [
    #    grep { truelike( $columns->{ $_ }->{ update } ) }
    #    keys %$columns
    #];
    return $self;
}


sub init_table {
    # stub for subclasses
}

sub record_throws {
    my $self = shift;
    return join( DOT, $self->model->ident, @_ );
}

#sub model {
#    shift->database->model;
#}

# Shitola! Here's a box full of fragile base class fail!
# I wanted to call this column() but it collides with the column() method in
# Badger::Database::Queries.  This whole thing really needs refactoring but we
# just don't have the time right now!

sub column_schema {
    my $self = shift;
    my $cols = $self->spec->{ columns };
    my $name = shift || return $cols;
    return $cols->{ $name }
        || $self->error_msg( invalid => column => $name );
}

#-----------------------------------------------------------------------------
# Record methods
#-----------------------------------------------------------------------------

sub subclass_record {
    my $self = shift;
    my $key  = shift;
    my $args = params(@_);
    my $type = $args->{ $key }     || return $self->error_msg( missing => $key );
    my $record = $self->{ record } || return $args;
    $self->{ module } ||= { };

    # generate a subclass module name
    my $module = $self->{ module }->{ $type } ||= do {
        # generate subclass name from record base and class argument,
        # e.g. 'My::Record::Resource' + 'document'
        #   => 'My::Record::Resource::Document'
        my $subtype = module_name($record, $type);
        $self->debug_data( "subtype $subtype for " => $args ) if DEBUG;
        class($subtype)->load;
        $subtype;
    };

    $args->{ _table } = $self;
    $args->{ _model } = $self->{ model };

    my $result = $module->new($args);

    return defined $result
        ? $result
        : $self->error_msg( new_record => $module, $module->error );
}

#-----------------------------------------------------------------------------
# Meta-methods for common query patterns
# e.g. $table->query_keys_rows( query_name => 'arg1 arg2 etc', @args );
#-----------------------------------------------------------------------------

sub query_keys_count {
    my ($self, $query, $keys, @args) = @_;
    ($self, @args) = self_keys( $keys => $self, @args );
    return $self->query($query)->column(@args)->[0];
}

sub query_keys_rows {
    my ($self, $query, $keys, @args) = @_;
    ($self, @args) = self_keys( $keys => $self, @args );
    return $self->rows( $query => @args );
}

sub query_keys_records {
    my $self = shift;
    return $self->records( $self->query_keys_rows(@_) );
}

sub query_keys_row {
    my ($self, $query, $keys, @args) = @_;
    ($self, @args) = self_keys( $keys => $self, @args );
    return $self->row( $query => @args );
}

sub query_keys_record {
    my $self = shift;
    my $row  = $self->query_keys_row(@_) || return;
    return $self->record($row);
}

#-----------------------------------------------------------------------------
# Hook methods - provide default functionality for things like autocomplete.
# Subclasses can redefine these to do something different if necessary.
#-----------------------------------------------------------------------------

sub autocomplete {
    shift->all_rows(@_);
}

#-----------------------------------------------------------------------------
# Generic row lookup used for things like autocomplete.  See POD docs below.
#-----------------------------------------------------------------------------

sub all_rows {
    my ($self, $params) = self_params(@_);
    $self->all_rows_query(
        any_rows => any_rows_like => all_rows => $params
    );
}

sub all_rows_query {
    my ($self, $exact, $like, $all, $params) = @_;
    my $value;

    if ($value = $params->{ name }) {
        return $self->rows($exact, $value);
    }
    elsif ($value = $params->{ starting }) {
        return $self->rows($like, $self->wildcard_starting($value));
    }
    elsif ($value = $params->{ containing }) {
        return $self->rows($like, $self->wildcard_containing($value));
    }
    elsif ($all) {
        return $self->rows($all);
    }
}

sub wildcard_starting {
    my ($self, $value) = @_;
    return $value . MYSQL_WILDCARD;
}

sub wildcard_containing {
    my ($self, $value) = @_;
    return MYSQL_WILDCARD . $value . MYSQL_WILDCARD;
}

sub wildcard_multi {
    my ($self, $value) = @_;
    for ($value) {
        s/^\s+//;   # remove leading whitespace
        s/\s+$//g;   # remove trailing whitespace
        s/\s+/%/g;   # collapse multiple whitespace into '%'
    }
    return MYSQL_WILDCARD . $value . MYSQL_WILDCARD;
}

#-----------------------------------------------------------------------------
# Search methods
#-----------------------------------------------------------------------------

sub search {
    my ($self, $params) = self_params(@_);
    my $rclass = $self->SEARCH;
    my $config = $self->{ spec }->{ search } || { };

    $config = { %$config };
    $config->{ columns } ||= $self->fields;
    $self->debug_data( "search config" => $config ) if DEBUG or 1;
    $self->debug_data( "search params" => $params ) if DEBUG or 1;

    my $search = $self->prepare_query_module($rclass, $config);
    $self->debug("got search: $search") if DEBUG;

    return $search->results(%$params);
    #return $rclass->new($params);
}

#-----------------------------------------------------------------------------
# Results methods
#-----------------------------------------------------------------------------

sub query_results {
    my $self   = shift;
    my $name   = shift;
    my $params = params(@_);
    my $query  = $self->query($name);
    return $query->results(%$params);
}

sub results {
    my ($self, $params) = self_params(@_);
    my $rclass = $self->RESULTS;
    class($rclass)->load;
    $params->{ table } ||= $self;
    return $rclass->new($params);
}

sub search_results {
    my $self = shift;
    $self->query_results( search => @_ );
}

sub found_rows {
    shift->row('found_rows')->{ count };
}


#-----------------------------------------------------------------------------
# Data de-multiplexer
#
# Extracts all the items from $row (or $rows) that match one of a set of
# prefixes.  e.g.
#
#  $row = {
#      a       => 1,
#      user_b  => 2,
#      user_c  => 3,
#      login_d => 4,
#  };
#
#  $split = $table->demux( 'user login' => $row )
#  # $row is now: { a => 1 }
#  # $split is now { user => { b => 2, c => 3 }, login => { d => 4 } }
#
# This will extract all items in $row that have a key starting user_ or
# login_.  The items are removed from the $row and added to new hash arrays,
# one for user_ items and one for login_ items.  The keys in the new hash
# arrays DON'T have the user_ or login_ prefixes.  The method then returns
# a hash reference containing user and login keys pointing to those new
# hash arrays.
#
#-----------------------------------------------------------------------------

sub demux {
    my ($self, $keys, $row_or_rows) = @_;
    my $output = { };
    my $match;

    $keys  = split_to_list($keys);
    $match = join(
        '|',
        # Schwartzian transform to sort longest first
        map  { quotemeta $_->[1] }
        sort { $b->[0] <=> $a->[0] }
        map  { [length $_, $_ ] }
        @$keys
    );
    $match = qr/$match/;

    my $ref = ref($row_or_rows) || '';

    if ($ref eq HASH) {
        return $self->_demux_row($match, $row_or_rows, $output);
    }
    elsif ($ref eq ARRAY) {
        return $self->_demux_rows($match, $row_or_rows, $output);
    }
    else {
        return $self->error_msg( invalid => "row or rows" =>  $row_or_rows );
    }
}

sub _demux_row {
    my ($self, $match, $row, $output) = @_;
    $output ||= { };

    $self->debug_data("demux row [$match]", $row) if DEBUG;

    foreach my $key (keys %$row) {
        my $copy = $key;
        if ($copy =~ s/^($match)_//) {
            $output->{ $1 }->{ $copy } = delete $row->{ $key };
            $self->debug("match [$1].[$copy] => $key => ", $output->{ $1 }->{ $copy }) if DEBUG;
        }
    }

    return $output;
}

sub _demux_rows {
    my ($self, $match, $rows, $output) = @_;
    $self->debug_data("demux rows [$match]", $rows) if DEBUG or 1;
    return [
        map { [ $_, $self->_demux_row($match, $_) ] }
        @$rows
    ];
}



#-----------------------------------------------------------------------------
# AUTOLOAD
#-----------------------------------------------------------------------------

sub autolook_query {
    my $self  = shift;
    my $name  = shift;
    $self->debug("autolook_query($name)") if DEBUG;
    if ($self->{ queries } ->{ $name }) {
        return $self->rows($name);
    }
    else {
        return undef;
    }
}

1;


=head1 NAME

Contentity::Database::Table - base class for database table modules

=head1 DESCRIPTION

This is a base class for all Contentity database table modules.

=head1 METHODS

=head2 all_rows($params)

Generic row lookup used for things like autocomplete.  The params can specify
a C<name> for an exact match, or C<starting> or C<containing> for wildcard
matches.

=head2 all_rows_query($any_rows, $any_rows_like, $all_rows, $params)

This method backs onto L<all_rows()> to do the work.  It expects three query
names (or SQL fragments) that respectively: fetch any rows with an exact name
match ($any_rows, e.g. SELECT ... WHERE name=?), fetch all rows with a wildcard
match ($any_rows_like, e.g. SELECT ... WHERE name LIKE ?) and fetch all rows
($all_rows, e.g. SELECT ...)

The fourth argument should be a hash reference of parameters. If a C<name>
parameter is specified then it uses the <$any_rows> query for an exact match.
If C<starting> or C<containing> is specified then it uses the C<$any_rows_like>.
The parameter provided is then modified by adding a C<%> at the end for
matches starting with a string (e.g. C<Kings%>) and additionally at the
beginning for matches containing a string (e.g. C<%Kings%>)

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2016 Andy Wardley.  All Rights Reserved.

=cut
