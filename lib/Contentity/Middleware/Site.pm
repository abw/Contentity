package Contentity::Middleware::Site;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Middleware';


sub before {
    my($self, $env) = @_;
    my $project = $self->project;
    my $host    = $env->{ SERVER_NAME }        || return $self->error_msg( missing => 'SERVER_NAME' );
    my $site    = $project->domain_site($host) || return $self->error_msg( invalid => domain => $project->error );

    $env->{ Project } = $project;
    $env->{ Site    } = $site;

    $self->debug(
        "loaded site: $host => ",
        $self->dump_data($site)
    )   if DEBUG;
}


1;
