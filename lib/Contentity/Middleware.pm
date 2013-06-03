package Contentity::Middleware;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base Plack::Middleware',
    accessors => 'project';


sub init {
    my ($self, $config) = @_;

    $self->{ project } = $config->{ project }
        || return $self->error_msg( missing => 'project' );

    return $self;
}


sub call {
    my($self, $env) = @_;

    $self->before($env);

    my $res = $self->app->($env);

    return $self->after($env, $res);
}


sub before {
    my ($self, $env) = @_;
    return $env;
}


sub after {
    my ($self, $env, $res) = @_;
    return $res;
}

1;

