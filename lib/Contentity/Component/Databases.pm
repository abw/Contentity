package Contentity::Component::Databases;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'asset',
    asset     => 'database',
    constant  => {
        SINGLETONS => 1,
    };

sub init_asset {
    my ($self, $config) = @_;
    $self->debug_data( databases => $config ) if DEBUG;;
    return $self;
}

sub prepare_asset {
    my ($self, $data) = @_;
    $self->debug_data( database => $data ) if DEBUG;
    return $self->workspace->component( database => $data );
}

1;
