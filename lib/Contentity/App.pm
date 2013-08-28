package Contentity::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    accessors => 'context';


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
