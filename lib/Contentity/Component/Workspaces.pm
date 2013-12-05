package Contentity::Component::Workspaces;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'resource',
    resource  => 'workspace',
    constant  => {
        CACHE_INSTANCES => 1,
    };


sub return_resource {
    my ($self, $data) = @_;
    my $space = $self->workspace;
    my $base  = delete $data->{ parent } || delete $data->{ base };

    $self->debug(
        "subspace URI is $data->{ uri }\n",
        "superspace URI is $space->{ uri }\n",
    ) if DEBUG;

    # attach project to intermediary base class if there is one specified
    if ($base) {
        $self->debug("Intermediary space: $base");
        $space = $space->workspace($base);
    }

    # create a new slave hanging off the master, either main project or base
    return $space->subspace($data);
}


1;

