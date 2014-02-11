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
    my $base  = delete $data->{ base };
    my $root  = delete $data->{ root }
        || return $self->error_msg( missing => 'root' );

    $root = $space->directory($root);

    $self->debug("Real directory is $root") if DEBUG;
    $data->{ root } = $root;

    $self->debug(
        "subspace URN is $data->{ urn }\n",
        "superspace URI is $space->{ uri }\n",
    ) if DEBUG;

    # attach project to intermediary base class if there is one specified
    if ($base) {
        $self->debug("Intermediary space: $base") if DEBUG;
        $space = $space->workspace($base);
    }

    $self->debug("creating subspace via [$space]: ", $self->dump_data($data)) if DEBUG;

    # create a new slave hanging off the master, either main project or base
    return $space->subspace($data);
}


1;

