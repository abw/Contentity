package Contentity::Component::Plack;

use Plack::Request;
use Contentity::Request;
use Contentity::Context;
#use Contentity::Middlewares;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'env request',
#    auto_can  => 'auto_can',
    constant  => {
        REQUEST     => 'Plack::Request',
        #REQUEST     => 'Contentity::Request',
        CONTEXT     => 'Contentity::Context',
        MIDDLEWARES => 'Contentity::Middlewares',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Plack init_component() => ",
        $self->dump_data($config)
    ) if DEBUG or 1;

    return $self;
}


sub app {
    my $self = shift;
    my $app  = $self->dispatcher;

    return sub {
        my $env = shift;
        my $res = eval {
            $app->($env);
        };
        if ($@) {
            $self->debug("Caught error: $@");
            return [ 500, [], ["Error: $@"]];
        }
        return $res->finalize;
    };
}


sub dispatcher {
    my $self    = shift;
    my $project = $self->project;

    return sub {
        my $env     = shift;
        my $host    = $env->{ SERVER_NAME }        || return $self->error_msg( missing => 'SERVER_NAME' );
        my $site    = $project->domain_site($host) || return $self->error_msg( invalid => domain => $project->error );
        my $context = $self->CONTEXT->new(
            env  => $env,
            site => $site,
        );
        $self->debug("RUN env: ", $self->dump_data($env));
        return $site->dispatch($context);
    }
}

1;
