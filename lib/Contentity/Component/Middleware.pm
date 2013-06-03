package Contentity::Component::Middleware;

use Contentity::Middlewares;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    utils     => 'params',
    constant  => {
        MIDDLEWARES     => 'Contentity::Middlewares',
        CACHE_INSTANCES => 1,
    };


sub middleware {
    my $self   = shift;
    my $type   = shift || return $self->error_msg( missing => 'middleware type' );
    my $params = params(@_);
    $params->{ project } = $self->project;

    $self->debug("creating new $type middleware") if DEBUG;

    return $self->MIDDLEWARES->middleware(
        $type => $params
    );
}


1;

