package Contentity::Component::Forms;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'resource',
    resource  => 'form';

sub return_resource {
    my ($self, $data) = @_;
    $data->{ EXTRA_STUFF } = 'Just Testing';
    return $data;
}

1;

