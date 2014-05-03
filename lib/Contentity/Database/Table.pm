package Contentity::Database::Table;

use Contentity::Utils;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Table Contentity::Database::Component',
    import    => 'class',
    accessors => 'columns singular plural about',
    utils     => 'split_to_list',
    constants => 'DOT ARRAY HASH',
    constant  => {
        RECORD  => 'Contentity::Database::Record',
    };


sub init {
    my ($self, $config) = @_;

    $self->debug_data( table => $config ) if DEBUG;

    $self->{ model } = $config->{ model }
        || return $self->error_msg( missing => 'model' );

    my $cols = $self->{ columns  } = $config->{ columns  };

    if ($cols && ! $config->{ fields }) {
        # fields defaults to everything specified in columns
        $config->{ fields } = [ keys %$cols ];
    }

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

# Darn! Fragile base class fail
# I wanted to call this column() but it collides with the column() method in
# Badger::Database::Queries.

sub column_schema {
    my $self = shift;
    my $cols = $self->columns;
    my $name = shift || return $cols;
    return $cols->{ $name }
        || return $self->error_msg( invalid => column => $name );
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
        map { [ $_, $self->demux_row($match, $_) ] }
        @$rows
    ];
}



1;
