package Contentity::Component::Plack::Resources;

# Work in progress

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Component::Plack',
    constant  => {
        URL_MAP => 'URLMap',
        DIR_APP => 'Directory',
    };

sub init_component {
    my ($self, $config) = @_;

    $self->debug_data("config", $config) if DEBUG;

    $self->{ resources } = $self->resources_url_map;
}

sub resources_url_map {
    my $self    = shift;
    my $site    = $self->workspace;
    my $reslist = $site->resource_list;
    my $urlmap  = $self->handler( $self->URL_MAP );

    # create routes for all static resources
    foreach my $resource (@$reslist) {
        $self->debug(
            "adding static resource route: $resource->{ url } => $resource->{ location }"
        ) if DEBUG;

        $urlmap->map(
            $resource->{ url } => $self->handler( 
                $self->DIR_APP => {
                    root => $resource->{ location }
                }
            )->to_app
        );
    }

    return $urlmap->to_app;
}


sub resources_app {
    my $self = shift;
    my $app  = shift;
    $self->middleware( 
        resources => {
            site => $self->site,
        }
    )->wrap($app);
}





sub call {
    my($self, $env) = @_;
    my $resources = $self->{ resources };
    my $res    = $resources->($env);

    if ($res) {
        $self->debug("resources response: ", $self->dump_data($res)) if DEBUG;
        return $res;
    }
    else {
        $self->debug("No resource response") if DEBUG;
        return $self->app->($env);
    }
}


1;

1;
