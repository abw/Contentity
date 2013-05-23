package Contentity::Component::Database;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component';


sub init_component {
    my ($self, $config) = @_;
    $self->debug("Database component init_module()") if DEBUG;
    return $self;
}


1;

