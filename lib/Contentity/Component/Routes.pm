package Contentity::Component::Routes;

die __PACKAGE__, " is deprecated - see routes() method in Contentity::Site\n";

use Contentity::Router;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'router',
    auto_can  => 'auto_can',
    constant  => {
        ROUTER => 'Contentity::Router'
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Routes init_component() => ",
        $self->dump_data($config)
    ) if DEBUG;

    $self->{ router } = $self->ROUTER->new(
        routes => $config
    );

    # no need to keep copy of potentially large set of config data lying around
    delete $self->{ config };

    return $self;
}

#-----------------------------------------------------------------------------
# auto_can() registered via the Badger::Class 'auto_can' hook in the module
# bootstrap at the top of the page.  This generates methods on demand that
# delegate to the router object.
#-----------------------------------------------------------------------------

sub auto_can {
    my ($self, $name) = @_;


    if ($self->router->can($name)) {
        return sub {
            shift->router->$name(@_);
        }
    }
}


1;

