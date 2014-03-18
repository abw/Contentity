package Contentity::Component::Apps;

use Contentity::Apps;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'asset',
    asset     => 'app',
    constant => {
        APPS_FACTORY    => 'Contentity::Apps',
        CACHE_INSTANCES => 1,
    };

sub prepare_asset {
    my ($self, $data) = @_;
    my $space = $self->workspace;
    my $urn   = $data->{ urn };
    $data->{ workspace } = $space;
    return $self->APPS_FACTORY->app($urn, $data);
}


1;


