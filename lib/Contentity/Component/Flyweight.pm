package Contentity::Component::Flyweight;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    autolook    => 'get';


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Flyweight component init_component(): ", 
        $self->dump_data($config)
    ) if DEBUG;

    return $self;
}


sub get {
    my ($self, $name, @args) = @_;

    # Hmmm... not sure about this - do we want to automatically "inherit"
    # everything from the workspace?
    return $self->config($name);
#        // $self->workspace->get($name, @args);
}


1;

