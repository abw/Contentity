package Contentity::Component::Apps;

use Contentity::Apps;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    component => 'resource',
    resource  => 'app',
    constant => {
        APPS_FACTORY    => 'Contentity::Apps',
        CACHE_INSTANCES => 1,
    };

sub return_resource {
    my ($self, $data) = @_;
    my $project = $self->project;
    my $urn     = $data->{ urn };
    $data->{ project } = $project;
    return $self->APPS_FACTORY->app($urn, $data);
}

sub app {
    shift->resource(@_);
}


1;
