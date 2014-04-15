package Contentity::Database::Table;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Table Contentity::Database::Component',
    accessors => 'columns',
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

    # Variant of Badger::Database::Table init() method
    #$self->init_database($config);
    $self->init_schema($config);
    $self->init_queries($config);
    $self->init_table($config);


    return $self;
}


sub init_table {
    # stub for subclasses
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
