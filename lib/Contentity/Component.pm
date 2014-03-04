package Contentity::Component;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    utils       => '',
    accessors   => 'workspace component urn schema config';


sub init {
    my ($self, $config) = @_;

    $self->debug(
        "initialising $config->{ component } component module: ", 
        $self->dump_data1($config)
    ) if DEBUG;

    my $component = $config->{ component } 
        || 'component';

    my $workspace = $config->{ workspace } 
        || return $self->error_msg( missing => 'workspace' );

    my $subconfig = $config->{ config } || $config;


    $self->{ workspace } = $workspace;
    $self->{ component } = $component;
    $self->{ schema    } = $config->{ schema };
    $self->{ urn       } = $config->{ urn    };
    $self->{ config    } = $subconfig;

    return $self
        ->init_component($subconfig);
}


sub init_component {
    my ($self, $config) = @_;
    # stub for sub-classes to re-implement
    return $self;
}


#-----------------------------------------------------------------------------
# Various useful accessor methods
#-----------------------------------------------------------------------------

sub NOT_hub {
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
    delete $self->{ schema    };
    $self->debug("$self: $self->{ component } [$self->{ urn }] component is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}


1;

