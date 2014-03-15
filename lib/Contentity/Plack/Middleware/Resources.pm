package Contentity::Middleware::Resources;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Middleware',
    accessors => 'site',
    constant  => {
        URL_MAP => 'Contentity::Plack::App::URLMap',
        DIR_APP => 'Contentity::Plack::App::Directory',
    };

use Contentity::Plack::App::URLMap;
use Contentity::Plack::App::Directory;


sub init_component {
    my ($self, $config) = @_;
    my $site = $config->{ site }
        || return $self->error_msg( missing => 'site' );

    $self->{ resources } = $self->resources_url_map;
}


sub resources_url_map {
    my $self    = shift;
    my $site    = $self->site;
    my $resources  = $site->resource_list;
    my $urlmap  = $self->URL_MAP->new;

    # create routes for all static resources
    foreach my $resource (@$resources) {
        $self->debug(
            "adding static resource route: $resource->{ url } => $resource->{ location }"
        ) if DEBUG;
        $urlmap->map(
            $resource->{ url } => $self->DIR_APP->new(
                { root => $resource->{ location } }
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
