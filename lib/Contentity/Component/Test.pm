package Contentity::Component::Test;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    accessors   => '';


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Test component init_component(): ", 
        $self->dump_data($config)
    ) if DEBUG;

    return $self;
}


1;

