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
    };

#sub init {
#    my ($self, $config) = @_;
#    $self->init_project($config);
#    $self->debug("site init");
#    return $self;
#}


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
    my $rgb  = $self->config_uri_tree('rgb');
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
        ||= $self->config_uri_tree('fonts');
}

sub font {
    my $self  = shift;
    my $fonts = $self->fonts;
    my $name  = shift || return $fonts;
    return $fonts->{ $name }
        || $self->decline_msg( invalid => font => $name );
}


1;
