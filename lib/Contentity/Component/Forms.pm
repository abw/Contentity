package Contentity::Component::Forms;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'asset',
    asset     => 'form';

sub prepare_asset {
    my ($self, $data) = @_;
    $data->{ EXTRA_STUFF } = 'Just Testing';
    $self->debug_data( form => $data ) if DEBUG;
    return $data;
}

1;

