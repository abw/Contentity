package Contentity::Component::Sitemap;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    constant    => {
        SITE    => 'site',
        PAGES   => 'pages',
    };


#-----------------------------------------------------------------------------
# Methods for loading site and page metadata from project config directory
#-----------------------------------------------------------------------------

sub site_data {
    my $self   = shift;
    my $config = $self->config;

    return  $self->{ site_data }
        ||= $self->project->config_tree( 
                $config->{ site_config_uri } || $self->SITE 
            );
}

sub site {
    my $self = shift;

    $self->project->component(
        site => {
            site    => $self->site_data,
            sitemap => $self,
        }
    );
}

sub pages_data {
    my $self   = shift;
    my $config = $self->config;

    return  $self->{ pages_data }
        ||= $self->project->config_uri_tree( 
                $config->{ pages_config_uri } || $self->PAGES
            );
}

sub page_data {
    my $self  = shift;
    my $uri   = shift || return $self->error_msg( missing => 'page uri' );
    my $page  = $self->pages_data->{ $uri };

    if ($page) {
        $page->{ uri } ||= $uri;
    }

    return $page
        || $self->decline_msg( invalid => page => $uri );
}

sub page {
    my $self = shift;
    my $page = $self->page_data(@_) 
        || return $self->error( $self->reason );

    return $self->project->component(
        page => {
            page    => $page,
            sitemap => $self,
        }
    );
}



#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    my $site = delete $self->{ site };
    $site->destroy if $site;
    $self->debug("sitemap is destroyed") if DEBUG;
}

sub DESTROY {
    shift->destroy;
}


1;
