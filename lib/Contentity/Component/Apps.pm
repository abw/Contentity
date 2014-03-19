package Contentity::Component::Apps;

use Contentity::Apps;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    accessors => 'factory',
    component => 'asset',
    asset     => 'app',
    constants => 'SLASH',
    constant  => {
        APPS_FACTORY    => 'Contentity::Apps',
        CACHE_INSTANCES => 1,
    };


sub init_asset {
    my ($self, $config) = @_;

    $self->debug_data( apps => $config ) if DEBUG;
    $self->init_factory($config);

    return $self;
}

sub init_factory {
    my ($self, $config) = @_;
    my $module = $config->{ apps_factory } || $self->APPS_FACTORY;

    class($module)->load;

    $self->{ factory } = $module->new;

    return $self;
}

sub prepare_asset {
    my $self   = shift;
    my $config = $self->app_config(@_);
    my $urn    = $config->{ urn };

    $self->debug_data("creating app [$urn] [$config->{uri}]", $config) if DEBUG;

    return $self->factory->app($urn, $config);
}

sub app_config {
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


