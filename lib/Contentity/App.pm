package Contentity::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'context';


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data( config => $config );

    return $self;
}

1;

__END__

==

sub dispatch {
    my ($self, $context) = @_;
    local $self->{ context } = $context;
    return $self->run($context);
}

sub site {
    shift->context->site;
}

sub page {
    shift->context->page;
}


1;
