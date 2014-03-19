package Contentity::Component::Plack;

use Contentity::Request;
use Contentity::Context;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    # TODO: remove dependence on C::P::Base?
    base      => 'Contentity::Component Contentity::Plack::Base', # Plack::Component',
    accessors => 'env request',
    constant  => {
        CONTEXT => 'Contentity::Context',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data("Plack init_component()", $config) if DEBUG;

    return $self;
}

#-----------------------------------------------------------------------------
# Custom to_app() method which calls wrap_app() to add an extra runtime
# wrapper to store local (temporary) environment reference in $self->{ env }.
#-----------------------------------------------------------------------------

sub to_app {
    my $self = shift;
    return $self->wrap_app(
        $self->SUPER::to_app(@_)
    );
}

sub wrap_app {
    my $self = shift;
    my $app  = shift;
    return sub {
        #local $self->{ env } = $_[0];
        $self->debug("Running app");
        $app->(@_);
    };
}

1;
__END__

sub NOT_app {
    my $self = shift;
    my $app  = $self->dispatcher;

    return sub {
        return $app->(@_)->finalize;
    };
}

sub NOT_dispatcher {
    my $self = shift;

    return sub {
        $self->dispatch(@_);
    }
}

sub dispatch {
    my ($self, $env) = @_;
    my $site    = $self->site($env);
    my $context = $self->context($env, $site);
    $self->debug("RUN env: ", $self->dump_data($env)) if DEBUG;

    return $site->dispatch($context);
}

sub hostname {
    my ($self, $env) = @_;
    my $host = $env->{ SERVER_NAME }
            || $env->{ HTTP_HOST   }
            || return $self->error_msg( missing => 'SERVER_NAME or HTTP_HOST' );

    $self->debug("HOST: $host");
    # remove port
    $host =~ s/:\d+$//g;

    return $host;
}

sub site {
    my ($self, $env) = @_;
    my $host    = $self->hostname($env);
    my $project = $self->project;

    return $project->domain_site($host) 
        || $self->error_msg( invalid => domain => $host );
}

sub context {
    my ($self, $env, $site) = @_;

    $site ||= $self->site($env);

    return $self->CONTEXT->new(
        env  => $env,
        site => $site,
        hub  => $self->project->hub,
    );
}


1;

__END__

From workspace::web

sub plack {
    #my $self = shift;
    #my $builder = $self->BUILDER->new(
    #    site => $self
    #);
    #$self->debug("builder: $builder");
    #$builder->build;

# TODO: Move Contentity::Plack::Builder::Site into Contentity::Component::Plack::Builder::Site
# and have Contentity::Component::Plack delegate to it, e.g. $self->plack returns
# plack component, $self->plack->builder returns the appropriate builder class
# for the workspace type. 

