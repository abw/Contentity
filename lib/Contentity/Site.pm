package Contentity::Site;

use Contentity::Router;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Project',
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
    return $urls unless @_;
    $self->todo("URL lookup");
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


1;
