package Contentity::Component::Sites;

use Contentity::Site;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'resource',
    resource  => 'site',
    constant  => {
        SITE_CLASS      => 'Contentity::Site',
        CACHE_INSTANCES => 1,
    };


sub return_resource {
    my ($self, $data) = @_;
    my $project = $self->project;
    my $base    = delete $data->{ base };

    $self->debug(
        "sub-site is $data->{ uri }\n",
        "parent project is $project->{ uri }\n",
    ) if DEBUG;

    # attach project to intermediary base class if there is one specified
    # (sites are subclasses of projects, so it's safe to cross-breed the two)
    $project = $project->site($base)
        if $base;

    $data->{_project_} = $project;
    $data->{ root    } = $project->dir( $data->{ root } ) 
        if $data->{ root };

    # create a new slave site hanging off the master project or site
    return $self->SITE_CLASS->new($data);
}


1;

