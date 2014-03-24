package Contentity::Middleware::Resources;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'middleware',
    constant  => {
        URL_MAP => 'URLMap',
        DIR_APP => 'Directory',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data( resources => $config ) if DEBUG;

    $self->{ resources } = $self->resources_url_map;

    return $self;
}


sub resources_url_map {
    my $self    = shift;
    my $site    = $self->workspace;
    my $reslist = $site->resource_list;
    my $urlmap  = $self->handler( $self->URL_MAP );

    # create routes for all static resources
    foreach my $resource (@$reslist) {
        $self->debug_data( $resource->{ url } => $resource ) if DEBUG;

        $urlmap->map(
            $resource->{ url } => $self->resource_handler($resource)->to_app
        );
    }

    return $urlmap->to_app;
}

sub resource_handler {
    my ($self, $resource) = @_;
    my $space = $self->workspace;
    my $devel = $space->development;
    my $app   = $resource->{ app };

    # use the dynamic handler if we're in development mode
    if ($app) {
       $self->debug("found a pre-defined app for $resource->{ url }: $app") if DEBUG;
       return $app;
    }
    else {
       $self->debug("creating directory handler for $resource->{ url }") if DEBUG;
    }

    $self->debug_data( resource => $resource ) if DEBUG;

    my $dirapp = $space->app(
        $self->DIR_APP => {
            root      => $resource->{ location },
            # allow directory indexes if we're in development mode
            index     => $devel,
            singleton => 0,
        }
    );

    $self->debug(
        "created directory app for $resource->{ location }: $dirapp"
    ) if DEBUG;

    return $dirapp;
}


sub call {
    my($self, $env) = @_;
    my $resources = $self->{ resources };
    my $res       = $resources->($env);

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
