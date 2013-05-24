package Contentity::Component::Projects;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'resource',
    resource  => 'project';


sub return_resource {
    my ($self, $data) = @_;
    $self->debug("created sub-project") if DEBUG;
    return $self->project->slave($data);
}


1;

