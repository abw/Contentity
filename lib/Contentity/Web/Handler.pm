package Contentity::Web::Handler;

use Contentity::Project;
use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Base',
    constant  => {
        IN_BASE_CLASS    => 'in base class',
        PROJECT_MODULE   => 'Contentity::Project',
        ROOT_CONFIG_ITEM => 'root',
        SITE_CONFIG_ITEM => 'site',
        APP_CONFIG_ITEM  => 'app',
        LOG_CONFIG_ITEM  => 'log',
    };


#-----------------------------------------------------------------------------
# Main handler methods which subclasses must implement
#-----------------------------------------------------------------------------

sub handle {
    shift->not_implemented(IN_BASE_CLASS);
}

sub handle_app {
    shift->not_implemented(IN_BASE_CLASS);
}


#-----------------------------------------------------------------------------
# Methods to fetch project, site, response app and logging app
#-----------------------------------------------------------------------------

our $PROJECTS = { };           # cache project objects by their root directory

sub project {
    my $self = shift;
    my $root = $self->root;
    return  $PROJECTS->{ $root }
        ||= $self->PROJECT_MODULE->new( root => $root );
}

sub site {
    my $self = shift;
    return $self->project->site(
        $self->site_name
    );
}

sub app {
    my $self = shift;
    return $self->site->app(
        $self->app_name
    );
}

sub log {
    my $self = shift;
    return $self->site->app(
        join_uri( log => $self->log_name )
    );
}


#-----------------------------------------------------------------------------
# Stub methods to return configuration values - subclasses may reimplement
#-----------------------------------------------------------------------------

sub config {
    my ($self, $item) = @_;
    return $self->{ $item }
        || $self->{ config }->{ $item }
        || $self->error_msg( missing => $item );
}

sub root {
    my $self = shift;
    $self->config( $self->ROOT_CONFIG_ITEM );
}

sub site_name {
    my $self = shift;
    $self->config( $self->SITE_CONFIG_ITEM );
}

sub app_name {
    my $self = shift;
    $self->config( $self->APP_CONFIG_ITEM );
}

sub log_name {
    my $self = shift;
    $self->config( $self->LOG_CONFIG_ITEM );
}



1;
