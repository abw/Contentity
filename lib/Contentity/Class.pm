package Contentity::Class;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    uber      => 'Badger::Class',
    hooks     => 'module resource resources',
    utils     => 'camel_case',
    constant  => {
        UTILS           => 'Contentity::Utils',
        CONSTANTS       => 'Contentity::Constants',
        MODULE_FORMAT   => 'Contentity::Module::%s',
    };


sub module {
    my ($self, $name) = @_;

    # If a module declares itself to be a module, e.g. C<module => "resource">
    # then we make it a subclass of Contentity::Module::Resource
    $self->base(
        sprintf($self->MODULE_FORMAT, camel_case($name))
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
