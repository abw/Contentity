package Contentity::Component::Projects;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'resource',
    resource  => 'project',
    constant  => {
        CACHE_INSTANCES => 1,
    };


sub return_resource {
    my ($self, $data) = @_;
    my $project = $self->project;
    my $base    = delete $data->{ base };

    $self->debug(
        "sub-project is $data->{ uri }\n",
        "parent project is $project->{ uri }\n",
    ) if DEBUG;

    # attach project to intermediary base class if there is one specified
    $project = $project->project($base)
        if $base;

    # create a new slave hanging off the master, either main project or base
    return $project->slave($data);
}


1;

