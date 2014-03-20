package Contentity::Component::Factory;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    accessors => 'type factory',
    component => 'asset',
    constants => 'SLASH',
    constant  => {
        FACTORY_TYPE    => 'anon',
        CACHE_INSTANCES => 0,
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
    my $self   = shift;
    my $config = $self->instance_config(@_);
    my $urn    = $config->{ urn };

    $self->debug_data("creating app [$urn] [$config->{uri}]", $config) if DEBUG;

    return $self->factory->item($urn, $config);
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

