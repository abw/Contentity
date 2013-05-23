package Contentity::Module;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    utils       => 'weaken',
    accessors   => 'project';


sub init {
    my ($self, $config) = @_;
    my $project = delete $config->{ project }
        || return $self->error_msg( missing => 'project' );

    $self->debug(
        "initialising $config->{ module } module: ", 
        $self->dump_data($config)
    ) if DEBUG;

    $self->{ project } = $project;
    $self->{ module  } = $config->{ module  };
    $self->{ config  } = $config;

    # avoid circular refs from keeping the project alive
    weaken $self->{ project };

    return $self->init_module($config);
}


sub init_module {
    my ($self, $config) = @_;
    # stub for sub-classes to re-implement
    return $self;
}


sub destroy {
    my $self = shift;
    delete $self->{ project };
    delete $self->{ config  };
    $self->debug("$self->{ module } module is destroyed") if DEBUG;
}


sub DESTROY {
    shift->destroy;
}


1;

