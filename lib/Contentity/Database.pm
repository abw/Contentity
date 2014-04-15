package Contentity::Database;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component Badger::Database',
    utils     => 'join_uri self_params',
    accessors => 'ident',
    constants => 'PKG',
    import    => 'class',
    constant  => {
        TABLE_BASE => 'Contentity::Database::Table',
        MODEL      => 'Contentity::Database::Model',
        AUTOGEN    => '_autogen',
    };


sub init_component {
    my ($self, $config) = @_;

    # The urn in the component configuration gives us the local database name.
    # We prefer to use the workspace URN rather than the database name itself
    # because it's conceivable that we could have several database interfaces
    # defined in the workspace that use the same underlying database.
    $self->{ ident } = $config->{ ident } ||= $config->{ urn } || $config->{ database };

    $self->debug_data( $self->ident . ' database' => $config ) if DEBUG;

    # Badger::Database supports the specification of a hub (Badger::Hub) to
    # enable it to connect to other components in the application framework.
    # We're using a derivative of Badger::Workspace instead, but they're
    # sufficiently equal in terms of purpose and API (specifically the config()
    # method) for it to "Just Work".
    $config->{ hub } = $self->workspace;


    $self->init_database($config);

    return $self;
}


sub init_database {
    my ($self, $config) = @_;

    # This is a copy of the Badger::Database::init() method.  We should probably
    # do this instead:
    #   $self->Badger::Database::init($config);

    # init_engine() can do some extra massaging of $config
    $self->init_engine($config);

    # we don't want to create a Badger::Database::Model object, instead we
    # inherit the table() method and friends from Contentity::Database
    $self->init_model($config);

    # now call configure() again to merge config into $self
    $self->configure($config);

    # initialise the queries base class
    $self->init_queries($config);

    return $self;
}

sub new_model {
    my ($self, $params) = self_params(@_);
    my $modclass = $self->model_class($params);
    $self->debug("Creating new $modclass model: ", $self->dump_data($params)) if DEBUG;

    # We're using a derivative of Badger::Workspace instead of Badger::Hub but
    # the underlying purpose (and core API) is the same.
    local $params->{ hub } = $self->workspace;

    return $modclass->new($params);
}

sub table_names {
    shift->model->table_names(@_);
}

sub table_config {
    shift->model->table_config;
}


1;
