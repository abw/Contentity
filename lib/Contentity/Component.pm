package Contentity::Component;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    utils       => 'weaken',
    accessors   => 'project component config';


sub init {
    my ($self, $config) = @_;
    my $project   = delete $config->{_project_}
        || return $self->error_msg( missing => 'project' );
    my $component = delete $config->{_component_} || 'component';

    $self->debug(
        "initialising $config->{ component } component module: ", 
        $self->dump_data($config)
    ) if DEBUG;

    $self->{ config    } = $config;
    $self->{ project   } = $project;
    $self->{ component } = $component;

    # avoid circular refs from keeping the project alive
    weaken $self->{ project };

    return $self->init_component($config);
}


sub init_component {
    my ($self, $config) = @_;
    # stub for sub-classes to re-implement
    return $self;
}

#-----------------------------------------------------------------------------
# Various useful accessor methods
#-----------------------------------------------------------------------------

sub project_uri {
    shift->project->uri(@_);
}

sub project_dir {
    shift->project->dir(@_);
}

sub uri {
    shift->project_uri(@_);
}

sub dir {
    shift->project_dir(@_);
}


#-----------------------------------------------------------------------------
# Autoload methods, applied by 'autolook' hook to Contentity::Class above
#-----------------------------------------------------------------------------

sub autoload_config {
    my ($self, $name, @args) = @_;
    $self->debug("autoload_config($name)") if DEBUG;
    my $config = $self->{ config };

    return  exists $config->{ $name }
        ?   $config->{ $name }
        :   undef;
}

sub autoload_project {
    my ($self, $name, @args) = @_;
    $self->debug("autoload_project($name)") if DEBUG;
    return $self->project->$name(@args);
}

#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ project };
    delete $self->{ config  };
    $self->debug("$self->{ component } component is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}


1;

