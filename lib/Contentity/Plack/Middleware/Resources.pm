package Contentity::Plack::Middleware::Resources;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Plack::Middleware',
    accessors => 'site',
    constant  => {
        URL_MAP => 'URLMap',
        DIR_APP => 'Directory',
    };


sub init_component {
    my ($self, $config) = @_;
    my $site = $config->{ site }
        || return $self->error_msg( missing => 'site' );

    $self->{ resources } = $self->resources_url_map;
}


sub resources_url_map {
    my $self    = shift;
    my $site    = $self->site;
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
