package Contentity::Class;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    uber      => 'Badger::Class',
    hooks     => 'component resource resources',
    utils     => 'camel_case',
    constant  => {
        UTILS            => 'Contentity::Utils',
        CONSTANTS        => 'Contentity::Constants',
        COMPONENT_FORMAT => 'Contentity::Component::%s',
    };


sub component {
    my ($self, $name) = @_;

    # If a module declares itself to be a component then we make it a subclass 
    # of Contentity::Component, e.g. , e.g. C<component => "resource"> creates
    # a base class of Contentity::Component::Resource
    $self->base(
        sprintf($self->COMPONENT_FORMAT, camel_case($name))
    );

    return $self;
}


sub resource {
    my ($self, $name) = @_;
    $self->constant( RESOURCE => $name );
    return $self;
}


sub resources {
    my ($self, $name) = @_;
    $self->constant( RESOURCES => $name );
    return $self;
}

1;
