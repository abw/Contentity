package Contentity::Component::Flyweight;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    constants   => 'HASH',
    autolook    => 'get shut_up';


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Flyweight component init_component(): ",
        $self->dump_data($config)
    ) if DEBUG;

    $self->{ data } = $config->{ data } || $config;

    $self->debug_data( "Flyweight data ", $self->{ data }) if DEBUG;

    return $self;
}

sub data {
    my $self = shift;
    my $data = $self->{ data };

    if (@_ == 1) {
        return $self->get(@_);
    }

    if (@_ > 1) {
        $self->set(@_);
    }

    return $data;
}

sub get {
    my ($self, $name) = @_;
    return $self->{ data } ->{ $name };
}


sub set {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $data = $self->{ data };

    while (my ($key, $value) = each %$args) {
        $data->{ $key } = $value;
    }

    return $self;
}

sub shut_up {
    return '';
}

#sub get {
#    my ($self, $name, @args) = @_;
#    # Hmmm... not sure about this - do we want to automatically "inherit"
#    # everything from the workspace?
#    return $self->config($name);
##        // $self->workspace->get($name, @args);
#}


1;
