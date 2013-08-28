package Contentity::Site;

use Contentity::Router;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Project',
    utils       => 'Colour',
    constant    => {
        CONFIG_FILE => 'site',
        ROUTER      => 'Contentity::Router'
    },
    messages => {
        no_app => "No application defined for $path",
    };

sub dispatch {
    my ($self, $context) = @_;
    my $path = $context->path;
    my $page = $self->match_route($path);
    my $appn = $page->{ app };

    $context->set( Site => $self );
    $context->set( Page => $page );

    $self->debug("site dispatching context: $path => ", $self->dump_data($page));

    if ($appn) {
        my $app = $self->app($appn);
        $self->debug("Got $appn app: $app");
        $context->set( App => $app );
        $app->dispatch($context);
    }
    else {
        $context->content(
            $self->message( no_app => $path )
        );
    }

    return $context->response;
}

#sub init {
#    my ($self, $config) = @_;
#    $self->init_project($config);
#    $self->debug("site init");
#    return $self;
#}


sub project {
    shift->grand_master;
}

sub domains {
    my $self = shift;
    return  $self->{ domains }
        ||= $self->project->site_domains($self->urn);
}

sub domain {
    my $self = shift;
    return  $self->{ domain }
        ||= $self->domains->[0];
}

#-----------------------------------------------------------------------------
# Mapping simple names to URLs, e.g. scheme_info => /scheme/:id/info
#-----------------------------------------------------------------------------

sub urls {
    my $self = shift;
    return  $self->{ urls }
        ||= $self->config_underscore_tree('urls');
}

sub url {
    my $self = shift;
    my $urls = $self->urls;
    my $name = shift || return $urls;
    return $urls->{ $name }
        || $self->decline_msg( invalid => url => $name );
}

#-----------------------------------------------------------------------------
# URL routing, e.g. from /scheme/:id/info to get the correct metadata
#-----------------------------------------------------------------------------

sub routes {
    my $self = shift;
    return  $self->{ routes }
        ||= $self->config_uri_tree('routes');
}

sub router {
    my $self = shift;
    return  $self->{ router }
        ||= $self->ROUTER->new(
                routes => $self->routes
            );
}


sub match_route {
    shift->router->match(@_);
}

sub add_route {
    shift->router->add_route(@_);
}

sub apps {
    shift->component('apps');
}

sub app {
    shift->apps->app(@_);
}

#-----------------------------------------------------------------------------
# RGB colours
#-----------------------------------------------------------------------------

sub rgb {
    my $self = shift;
    return  $self->{ rgb } 
        ||= $self->load_rgb;
}

sub load_rgb {
    my $self = shift;
    my $rgb  = $self->config_underscore_tree('rgb');
    foreach my $key (keys %$rgb) {
        $rgb->{ $key } = Colour($rgb->{ $key });
    }
    return $rgb;
}


#-----------------------------------------------------------------------------
# Font stacks
#-----------------------------------------------------------------------------

sub fonts {
    my $self = shift;
    return  $self->{ fonts } 
        ||= $self->config_underscore_tree('fonts');
}

sub font {
    my $self  = shift;
    my $fonts = $self->fonts;
    my $name  = shift || return $fonts;
    return $fonts->{ $name }
        || $self->decline_msg( invalid => font => $name );
}

#-----------------------------------------------------------------------------
# File extensions
#-----------------------------------------------------------------------------

sub extensions {
    my $self = shift;
    return  $self->{ extensions } 
        ||= $self->config('extensions');
}

1;
