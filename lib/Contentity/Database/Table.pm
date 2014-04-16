package Contentity::Database::Table;

use Contentity::Utils;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Table Contentity::Database::Component',
    import    => 'class',
    accessors => 'columns singular plural',
    constants => 'DOT',
    constant  => {
        RECORD  => 'Contentity::Database::Record',
    };


sub init {
    my ($self, $config) = @_;

    $self->debug_data( table => $config ) if DEBUG;

    $self->{ model } = $config->{ model }
        || return $self->error_msg( missing => 'model' );

    $self->{ columns  } = $config->{ columns  };
    $self->{ messages } = $config->{ messages };

    $self->{ singular } = $config->{ singular }
       || $config->{ record }      # See note below
       || $config->{ name   }
       || $config->{ table  };

    $self->{ plural } = $config->{ plural }
       || Contentity::Utils::plural($self->{ singular });

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




1;
