package Contentity::Web::Handler;

use Contentity::Project;
use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Base',
    constant  => {
        PROJECT_MODULE    => 'Contentity::Project',
        ROOT_CONFIG_ITEM  => 'root',
        SITE_CONFIG_ITEM  => 'site',
        SPACE_CONFIG_ITEM => 'workspace',
        APP_CONFIG_ITEM   => 'app',
        AUTH_CONFIG_ITEM  => 'auth',
        LOG_CONFIG_ITEM   => 'log',
    };


#-----------------------------------------------------------------------------
# Main handler methods which subclasses must implement
#-----------------------------------------------------------------------------

sub handle {
    shift->not_implemented('in base class');
}

sub handle_app {
    shift->not_implemented('in base class');
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

sub workspace {
    my $self    = shift;
    my $project = $self->project;
    my $wsname  = $self->try->workspace_name || return $project;
    return $project->workspace($wsname);
}

sub app {
    my $self = shift;
    return $self->workspace->app(
        $self->app_name
    );
}

sub auth {
    my $self = shift;
    return $self->workspace->auth(
        $self->auth_name
    );
}

sub log {
    my $self = shift;
    # Hmmm... why is this calling site() and not workspace()?
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

sub workspace_name {
    my $self = shift;
    $self->config( $self->SPACE_CONFIG_ITEM );
}

sub app_name {
    my $self = shift;
    $self->config( $self->APP_CONFIG_ITEM );
}

sub auth_name {
    my $self = shift;
    $self->config( $self->AUTH_CONFIG_ITEM );
}

sub log_name {
    my $self = shift;
    $self->config( $self->LOG_CONFIG_ITEM );
}

1;
