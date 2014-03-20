package Contentity::Component::Web;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component Contentity::Plack::Component',
    accessors => 'env context';


sub new_context {
    my $self = shift;
    return $self->workspace->context(@_);
}



1;

__END__


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

