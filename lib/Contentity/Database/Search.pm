package Contentity::Database::Search;

use Cog::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Database::Query::Select Contentity::Base',
    import      => 'class',
    utils       => 'params self_params min Now numlike split_to_list extend',
    throws      => 'Contentity.Search',
    accessors   => 'default_page_size max_page_size max_page_no',
    constants   => 'ARRAY CODE DOT DELIMITER BLANK MYSQL_WILDCARD',
    words       => 'RELATIONS SEARCH_PARAMS SORT_ORDERS AUTOJOIN',
    alias       => {
        page => \&page_no,
    },
    constant    => {
        SELECT       => 'SELECT SQL_CALC_FOUND_ROWS',
        LIMIT_OFFSET => 'LIMIT ? OFFSET ?',
    },
    config      => [
        'autojoin|class:AUTOJOIN',
        'page_size|class:PAGE_SIZE',
        'default_page_size|class:DEFAULT_PAGE_SIZE=25',
        'max_page_size|class:MAX_PAGE_SIZE=500',
        'max_page_no|class:MAX_PAGE_NO=999',
    ],
    messages    => {
        dup_relation => 'Existing relation to %s (fixing this is TODO)',
    };



our $MATCH_FRAGMENT = qr/<(\??\w+(=\?)?)>/;
our $RELATIONS      = { };
our $SEARCH_PARAMS  = { };
our $SORT_ORDERS    = { };
our $SEARCH_TYPES   = {
    timestamp => \&timestamp_param,
    min       => \&min_param,
    max       => \&max_param,
};

sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $table = $config->{ table }
        || return self->error_msg( missing => 'table reference' );


    $self->debug("merge search config: ", $self->dump_data($config)) if DEBUG;

    $self->SUPER::init($config);

    my $search  = $class->hash_vars(SEARCH_PARAMS);
    my $columns = $self->{ columns };

    $self->{ search      } = { %$columns, %$search };
    $self->{ relations   } = $class->hash_vars(RELATIONS);
    $self->{ sort_orders } = $class->hash_vars(SORT_ORDERS);
    $self->{ table       } = $table;
    $self->{ idents      } = [ '#' . $class->id ];    # '#' sorts first

    if (DEBUG) {
        $self->debug_data( search => $self->{ search } );
        $self->debug_data( sort => $self->{ order } );
    }

    #$self->debug("table: $table") if DEBUG or 1;

    if ($self->{ autojoin }) {
        my $autojoin = split_to_list($self->{ autojoin });
        $self->debug_data( autojoin => $autojoin ) if DEBUG;
        $self->relation($_) for @$autojoin;
    }

    # TODO: prepare search parameter definitions

    return $self;
}


#-----------------------------------------------------------------------
# search
#-----------------------------------------------------------------------

sub search {
    shift->search_params(@_);
}


sub search_type {
    my ($self, $name) = @_;
    return $self->class->hash_value( SEARCH_TYPES => $name )
        || $self->error_msg( invalid => search_type => $name );
}


sub search_params {
    my ($self, $params) = self_params(@_);
    my $fields = $self->{ search };
    my $ignore = $params->{ ignore } || { };
    my ($name, $value, $field, $type, $like, $order, $code, @args);

    $self->debug("search_params(): $params => ", $self->dump_data($params))
        if DEBUG;

    if (DEBUG) {
        $self->debug_data( fields => $fields );
        $self->debug_data( ignore => $ignore );
    }

    while (($name, $value) = each %$params) {
        next
            if $ignore->{ $name };
        next
            unless defined $value
                && length  $value
                && ($field = $fields->{ $name });

        $self->debug("search_param [$name] = [$value]") if DEBUG;
        # allow field to be specified as [type => value]
        if (ref $field eq ARRAY) {
            ($type, $field, @args) = @$field;
            $self->debug("looking up handler for search type: $type") if DEBUG;
            $field = $self->expand($field);
            $self->search_type($type)->($self, $name, $field, $value, $params);
            next;
        }

        # allow code handler to interject
        if (ref $field eq CODE) {
            $self->debug("delegating to code handler for $name") if DEBUG;
            $field->($self, $name, $value, $params);
            next;
        }

        if (ref $value eq ARRAY) {
            $self->debug("got array of values for $name: ", $self->dump_data($value)) if DEBUG;
            $self->where($field, $value);
#           $self->no_cache;            # we don't have caching enabled
            next;
        }

        # we generate a unique identifier for each composed query as a
        # signature of the parameters that it uses
        $self->ident( $name => '?' );

        # The field name can be prefixed or suffixed with '%' to indicate
        # that the search term should be matched using a wildcard match and
        # LIKE instead of an absolute '=' equality test
        $like = 0;

        if ($field =~ s/^%//) {
            $like++;
            $value = '%'.$value;
        }
        if ($field =~ s/%$//) {
            $like++;
            $value = $value.'%'
        }
        $self->debug("where: $field\n") if DEBUG;
        $self->where(
            $field, $like ? (LIKE => '?') : '?'
        );
        $self->value($value);
    }

    if ($order = $self->sort_order($params->{ order })) {
        $self->order_by($order);
        # no need to add null order when using the default provided by sort_order()
        $self->ident( order => $params->{ order } ) if $params->{ order };
    }

    # TODO: use this to lookup a cached query
    $self->debug("prepared search params: ", $self->ident) if DEBUG;

    return $params;
}



sub sort_order {
    my $self  = shift;
    my $sorts = $self->{ sort_orders };
    my $name  = shift || BLANK;
    my $desc  = ($name =~ s/(_reverse|_desc)$//);       # TODO: look for separate reverse param
    my $field = $sorts->{ $name }
        || $self->{ search  }->{ $name }
        || $sorts->{ default }
        || BLANK;

    $self->debugf("sort order $name in %s => $field", $self->dump_data($sorts))
        if DEBUG;

    return unless $field;

    $field = $field->[1] if ref $field eq ARRAY;

    # strip any wildcard search markers
    $field =~ s/%//g;

    $self->debug("search field: $field") if DEBUG;

    my @fields =
        map { $self->column($_) }
        split(DELIMITER, $field);

    $self->debug("search columns: ", $self->dump_data(\@fields)) if DEBUG;

    return join(', ', map { $desc ? "$_ DESC" : $_ } @fields); # . ($desc ? ' DESC' : '');
}


sub page_no {
    my $self = shift;
    return @_
        ? do { $self->{ page_no } = shift; $self }
        : $self->{ page_no };
}


sub page_size {
    my $self = shift;
    return @_
        ? do { $self->{ page_size } = shift; $self }
        : $self->{ page_size };
}


sub limit_offset {
    my ($self, $params) = self_params(@_);

    # we want the *smaller* value of the page size requested (or the default
    # page size) and the maximum page size.
    my $page_size  = min(
        $params->{ page_size } || $self->{ page_size } || $self->{ default_page_size },
        $self->{ max_page_size }
    );

    my $page_no = $params->{ page_no } || $self->{ page_no } || 1;

    # clip the page no to the minimum/maximum page numbers
    $page_no %= $self->{ max_page_no };
    $page_no = 1 if $page_no < 1;

    # update params to correct any out-of-bound errors
    $params->{ page_no   } = $page_no;
    $params->{ page_size } = $page_size;

    # we use a 1-based index in the front end so that the first page is page
    # 1, but use a 0-based index in the database coz we is 1337 progrimmers
    return ($page_size, $page_size * --$page_no);
}

sub AFTER {
    # This is called by base class SQL composer to add any final bit to the
    # query.  In the usual case, we apply a limit/offset to prevent anyone
    # from hammering the database with massive queries.  However, there are
    # occasions when we want to allow a user to access all records returned
    # by a query (e.g. an admin downloading details of all recent orders).
    # In that case, the internal NO_LIMIT flag is set.
    my $self = shift;
    return $self->{ NO_LIMIT }
        ?  ''
        :   $self->LIMIT_OFFSET;
}


sub relation {
    my $self   = shift;
    my $name   = shift;
    my $type   = ($name =~ s/(\w+)://) ? $1 : '';
    my $proto  = $self->{ relations }->{ $name } || { };
    my $params = params(@_);
    my $join   = { %$proto, %$params };
    my $with   = $join->{ with };
    my $joined = $self->{ joined } ||= { };
    my $table  = $self->{ from }->[0] || '<no_table>';
    my (@sql, $fields);

    $join->{ type } ||= uc $type || '';

    # for now we'll just reject any duplicates, but at some point in the
    # future the code should be adapted to detect and handle them correctly
    return $self->error_msg( dup_relation => $name )
        if $joined->{ $name };

    if ($join->{ table } ||= $join->{ join }) {
        # foo => { table => bar } assumes 'foo' is the alias, e.g. bar as foo
        $join->{ as } ||= $name;
    }
    elsif ($join->{ as }) {
        # foo => { as => bar } assumes 'foo' is the table name, e.g. foo as bar
        $join->{ table } ||= $name;
    }
    else {
        # otherwise $name is the table name
        $join->{ table } = $name;
    }

    return $self->error("Don't know how to join onto $name")
        unless $join->{ on };

    # "on => [a, b, c]" is sugar for "ON a AND b AND c'"
    $join->{ on } = [ $join->{ on } ]
        unless ref $join->{ on } eq ARRAY;

    $join->{ on } = [
        map { $self->expand($_) }
        @{ $join->{ on } }
    ];

    $self->debugf("$name relation(%s)", $self->dump_data($join)) if DEBUG;

    if ($with) {
        if (ref $with) {
            $with = [ $with ]
                unless ref $with eq ARRAY;
        }
        else {
            $with = [ split(DELIMITER, $with) ];
        }
        $self->debug("with dependencies: ", $self->dump_data($with)) if DEBUG;

        foreach my $w (@$with) {
            $self->relation($w)
                unless $joined->{ $w };
        }
    }

    # TODO: check for duplicates, conflicts in configurations etc.
    $joined->{ $name } = $join;

    push(@sql, "\n");
    push(@sql, $join->{ type }, JOIN => $join->{ table });
    push(@sql, AS => $join->{ as }) if $join->{ as };
    push(@sql, ON => join(' AND ', @{ $join->{ on } }) );

    $self->SUPER::join(
        join(' ', grep { defined } @sql)
    );

    # add any select/column items
    if ($fields = $join->{ select }) {
        $self->debug("adding relation $name select items: $fields") if DEBUG;
        $self->select($fields);
    }
    if ($fields = $join->{ columns }) {
        $table  = $join->{ as } || $join->{ table };
        $fields = [ split(DELIMITER, $fields) ]
            unless ref $fields eq ARRAY;
        $fields = [
            map { /\W/ ? $_ : [$table.DOT.$_, $table.'_'.$_] }
            @$fields
        ];
        $self->debug("adding relation $name columns: ", $self->dump_data($fields)) if DEBUG;
        $self->columns($fields);
    }

    return $self;
}


sub joined {
    my $self   = shift;
    my $joined = $self->{ joined } ||= { };
    return @_
        ? $joined->{ $_[0] }
        : $joined;
}

sub column {
    my ($self, $name) = @_;
    my ($alias, $join, $desc);

    # Hack to account for sort_order needing some way to indicate descending
    # sort order.  e.g. table.field.desc
    if ($name =~ s/\.desc(ending)?$//i) {
        $desc = " DESC";
    }
    else {
        $desc = "";
    }

    if ($name =~ /^(\w+)\./) {
        if ($self->{ tables }->{ $1 }) {
            $self->debug("found reference to existing table: $1") if DEBUG;
        }
        else {
            # if the name has a dotted part then we make sure the relevant
            # relation is joined, e.g. employee.id performs an implicit call
            # to $self->relation('employee')
            $self->relation($1)
                unless $self->{ joined }->{ $1 };

            # relation may specify a table alias that we need to use
            $join  = $self->{ joined }->{ $1 };
            $alias = $join->{ as } || $join->{ table };
            if ($alias ne $1) {
                $name =~ s/^(\w+)\./$alias./;
            }
        }
    }
    elsif ($name =~ /^\w+$/) {
        # if the name is a single word, i.e. a column name then we prefix
        # it with the name of the last table declared
        my $tbl = $self->{ from }->[-1];
        $self->debug("WHERE: $tbl") if DEBUG;
        $name = $tbl.DOT.$name;
    }
    elsif ($name =~ s/^([\.=])//) {
        # Remove leading '.' or '=' from start of name.
        # This is a hack because the above code automagically adds the
        # table name.  Problem is that asking for foo when we have a query
        # like "SELECT XXX AS foo" ends up looking for table_name.foo.  So
        # we set the field to '.foo', '=foo' or something similar to default
        # this badly conceived table name mapping.
        # NOTE: we used to remove any non-alpha character but that
        # fails hard when the column name is "`property`.availability"
    }

    return $name . $desc;
}


sub where {
    my $self = shift;
    my ($name, $cmp, $value, $alias, $join);
    my $dbh = $self->{ queries }->dbh;

    if (@_ == 1 && ! ref $_[0]) {
        # single SQL string
        return $self->SUPER::where(@_);
    }

    while (@_) {
        my $x = $_[0];
        $name  = $self->column(shift);
        $value = @_
            ? shift
            : '?';         # placeholder by default

        if (@_) {
            # three args: ($field, $compare, $value)
            $cmp   = $value;
            $value = shift;
        }
        elsif (ref $value eq ARRAY) {
            $self->debug("* $x: where([]) [$name] [$value]") if DEBUG;
            # two value: ($field, [$value1, $value2, ...]) => x IN (..)
            # SHIT ON A STICK!  This allows for an SQL injection attack!
            # These must be escaped or converted to placeholders!
            $cmp   = 'in';
            $value = '(' . join(', ', map { $dbh->quote($_) } @$value) . ')';
        }
        else {
            # two value: ($field, $value)
            $self->debug("* $x: where(2) [$name] [$value]") if DEBUG;
            $cmp   = '=';
        }

        $self->SUPER::where("$name $cmp $value");

    }

    return $self;
}


sub fragments {
    my $self = shift;
    return $self->{ fragments } ||= {
        table => $self->{ from }->[0]
    };
}


# This is called by prepare_sql() in the Badger::Database::Query::Select
# base class to generate the high-level components.  There's a few we need
# to fix to account for the fact that we've got a table called 'order',
# for example, which is a reserved word in SQL.

sub sql_fragments {
    my $self  = shift;
    my $frags = $self->SUPER::sql_fragments;

    $frags->{ from } = $self->fix_name( $frags->{ from } );

    return $frags;
}


sub table_name {
    my $self = shift;
    return $self->fix_name( $self->{ from }->[-1] );
}


sub fix_name {
    my ($self, $name) = @_;
    $name = "`$name`"; # if $name eq 'order';
    return $name;
}

sub expand_fragments {
    my $self  = shift;
    my $text  = shift;
    my $frags = params(@_);

    $self->debug(
        "Expanding fragments in template: $text\n",
        " fragments: ", $self->dump_data($frags), "\n",
    ) if DEBUG;

    my $n = 16;
    1 while $n-- > 0
         && $text =~ s/$MATCH_FRAGMENT/$frags->{$1} || return $self->error_msg( bad_sql_frag => $1 => $text )/eg;

    $self->debug("Expanded fragments in template: $text\n")
        if DEBUG;

    return $text;
}



sub expand {
    my $self = shift;
    my $sql  = shift;

    return $self->expand_fragments(
        $sql,
        extend({ }, $self->fragments, @_)
    );
}


sub timestamp_param {
    my ($self, $name, $field, $value) = @_;

#    $self->debug("timestamp is [$name] [$field] [$value]\n");

    if ($value eq 'week') {
        $value = Now;
        my $wday = $value->format('%u');        # 1 - Monday, 2 - Tuesday, etc.
        $wday--;
        $value->adjust( days => -$wday ) if $wday;
        $value = $value->date;
    }
    elsif ($value eq 'month') {
        $value = Now->format('%Y-%m');
    }
    elsif ($value eq 'last_month') {
        $value = Now->adjust( month => -1 )->format('%Y-%m');
    }
    elsif ($value eq 'year') {
        $value = Now->format('%Y');
    }
    elsif ($value eq 'last_year') {
        $value = Now->adjust( year => -1 )->format('%Y');
    }
    elsif ($value eq 'yesterday') {
        $value = Now->adjust( day => -1 )->date;
    }
    elsif ($value =~ /^(to)?day$/) {
        $value = Now->date;
    }
    elsif ($value =~ /(\d+)days?/) {
        $value = Now->adjust( days => -$1 )->date;
    }
    elsif ($value =~ /(\d+)hours?/) {
        $value = Now->adjust( hours => -$1 )->timestamp;
    }

    $self->where( $field, '>=', '?' );
    $self->value( $value );
    $self->ident( $name => '?' );
}


sub min_param {
    my ($self, $name, $field, $value, $params) = @_;
    $self->debug("min: $name => $value ($field)") if DEBUG;
    $self->where( $field, '>=', '?' );
    $self->value( $value );
    $self->ident( $name => '?' );
}

sub max_param {
    my ($self, $name, $field, $value, $params) = @_;
    $self->debug("max: $name => $value ($field)") if DEBUG;
    $self->where( $field, '<=', '?' );
    $self->value( $value );
    $self->ident( $name => '?' );
}


sub results {
    my $self   = shift;
    my $params = $self->search_params(@_);
    my $table  = $self->{ queries };

    $self->debugf("results(%s)", $self->dump_data($params)) if DEBUG;

    my ($limit, $offset) = $self->limit_offset($params);

    if (DEBUG || $self->DEBUG) {
        $self->debug("SQL: ", $self->sql);
        $self->debug("Placeholder values: ", $self->dump_values);
        $self->debug("limit: $limit   offset: $offset");
        $self->debug("fetching rows...");
    }

    my $rows = $self->rows($limit, $offset);

    $self->prepare_rows($rows);

    if (DEBUG || $self->DEBUG) {
        my $n = scalar @$rows;
        $self->debug("fetched $n rows");
        $self->debug("rows: ", $self->dump_data($rows)) if DEBUG;
    }

    return $table->results(
        ident   => $self->ident,
        rows    => $rows,
#       records => $table->records($rows),      # TODO: make dynamic
        total   => $table->found_rows,
        limit   => $limit,
        offset  => $offset,
        query   => $self->sql,
        params  => $params,
        args    => $self->{ values },
    );
}

sub prepare_rows {
    # do nothing - stub for subclasses
}

sub prepare_row {
    # do nothing - stub for subclasses
}

sub prepare_all_rows {
    my ($self, $rows) = @_;
    for my $row (@$rows) {
        $self->prepare_row($row);
    }
}

sub all_results {
    my $self   = shift;
    my $params = $self->search_params(@_);
    my $table  = $self->{ table };

    $self->debugf("all_results(%s)", $self->dump_data($params)) if DEBUG;
    $self->debug("SQL: ", $self->sql) if $self->DEBUG;

    local $self->{ NO_LIMIT } = 1;
    my $rows = $self->rows;

    $self->debug("Values: ", $self->dump_values) if $self->DEBUG;
    $self->debug("rows: ", $self->dump_data($rows)) if DEBUG;

    return $table->results(
        ident   => $self->ident,
        rows    => $rows,
        total   => $table->found_rows,
        query   => $self->sql,
        params  => $params,
        args    => $self->{ values },
    );
}



sub ident {
    my $self   = shift;
    my $idents = $self->{ idents };
    return @_
        ? push( @$idents, join('=', @_) )
        : join( '/', sort @$idents );
}


sub dump_values {
    my $self = shift;
    return $self->dump_data($self->{ values });
}

#sub prepare_sql {
#    my $self = shift;
#    my $sql  = $self->SUPER::prepare_sql(@_);
#    return $sql;
#}

# We do this right at the end so that we don't have to worry about redefining
# the core join() function in any of the above code.  Ditto for params().
*join   = \&relation;
#*params = \&search_params;


1;

__END__
