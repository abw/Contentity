package Contentity::Component;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    utils       => 'weaken',
    accessors   => 'workspace component config';


sub init {
    my ($self, $config) = @_;
    my $component = delete $config->{_component_} || 'component';
    my $workspace = delete $config->{_workspace_} || return $self->error_msg( missing => '_workspace_' );

    $self->debug(
        "initialising $config->{ component } component module: ", 
        $self->dump_data($config)
    ) if DEBUG;

    $self->{ workspace } = $workspace;
    $self->{ component } = $component;
    $self->{ config    } = $config;

    return $self
        ->init_component($config);
}


sub init_component {
    my ($self, $config) = @_;
    # stub for sub-classes to re-implement
    return $self;
}


#-----------------------------------------------------------------------------
# Various useful accessor methods
#-----------------------------------------------------------------------------

sub hub {
    shift->workspace->hub;
}

sub uri {
    shift->workspace_uri(@_);
}

sub dir {
    shift->workspace_dir(@_);
}

sub workspace_uri {
    shift->workspace->uri(@_);
}

sub workspace_dir {
    shift->workspace->dir(@_);
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ workspace };
    delete $self->{ config    };
    $self->debug("$self->{ component } component is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}


1;

