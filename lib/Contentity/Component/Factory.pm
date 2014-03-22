package Contentity::Component::Factory;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    utils     => 'self_params',
    accessors => 'type factory',
    component => 'asset',
    constants => 'SLASH',
    constant  => {
        FACTORY_TYPE => 'anon',
        SINGLETONS   => 0,
    };


sub init_asset {
    my ($self, $config) = @_;
    $self->debug_data( factory => $config ) if DEBUG;
    $self->init_factory($config);
    return $self;
}

sub init_factory {
    my ($self, $config) = @_;
    my $type   = $config->{ factory_type } || $self->FACTORY_TYPE;
    my $module = $config->{ $type        } || $self->FACTORY_MODULE;

    class($module)->load;

    $self->{ type    } = $type;
    $self->{ factory } = $module->new;

    return $self;
}

sub prepare_asset {
    my ($self, $params) = self_params(@_);

    # In the usual case the type of asset object we want to create is the 
    # same as the component name/config file, e.g. the 'content' app corresponds
    # to Contentity::App::Content and can be loaded and instantiated via the
    # Contentity::Component::Apps factory module.  The asset configuration can
    # contain an entry indicating that a different object type should be used
    # instead, e.g. app_type for an 'app' asset, 'form_type' for a form, etc.
    my $config = $self->instance_config($params);
    my $urn    = $config->{ urn };
    my $asset  = $self->{ asset };
    my $type   = $params->{"${asset}_type"} || $urn;

    $self->debug_data(
        "creating app [$urn] [${asset}_type:$type] [$config->{uri}]", 
        $config
    ) if DEBUG;

    return $self->factory->item($type, $config);
}

sub instance_config {
    my ($self, $data) = @_;
    return {
        workspace => $self->workspace,
        component => $self->{ asset },
        urn       => $data->{ urn },
        uri       => $self->{ asset }.SLASH.$data->{ urn },
        config    => $data,
    #    schema    => $config->{ schema };
    };
}

1;

