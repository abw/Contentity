package Contentity::Component;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    accessors   => 'workspace component urn schema singleton',
    constant    => {
        SINGLETON => undef,
    };


sub init {
    my ($self, $config) = @_;

    $self->debug_data(
        "initialising $config->{ component } component module: ",
        $config
    ) if DEBUG;

    my $component = $config->{ component }
        || 'component';

    my $workspace = $config->{ workspace }
        || return $self->error_msg( missing => 'workspace' );

    my $subconfig = $config->{ config } || $config;
    my $schema    = $config->{ schema };
    my $single    = $subconfig->{ singleton }
                 // $config->{ singleton }
                 // $schema->{ singleton }
                 // $self->SINGLETON;

    $self->{ urn       } = $config->{ urn    };
    $self->{ workspace } = $workspace;
    $self->{ component } = $component;
    $self->{ schema    } = $schema;
    $self->{ config    } = $subconfig;
    $self->{ singleton } = $single;

    return $self->init_component($subconfig);
}


sub init_component {
    my ($self, $config) = @_;
    # stub for sub-classes to re-implement
    return $self;
}


#-----------------------------------------------------------------------------
# Various useful accessor methods
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return @_
        ? $config->{ $_[0] }
        : $config;
}

sub hub {
    shift->workspace->hub;
}

sub uri {
    shift->workspace->uri(@_);
}

sub dir {
    shift->workspace->dir(@_);
}


sub ancestral_dirs {
    my ($self, @path) = @_;
    my $space     = $self->workspace;
    my $ancestors = $space->ancestors;
    my ($ancestor, $dir, @dirs);

    foreach $ancestor (@$ancestors) {
        $dir = $ancestor->dir(@path);
        push(@dirs, $dir) if $dir->exists;
    }

    return wantarray
        ?  @dirs
        : \@dirs;
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


=head1 NAME

Contentity::Component - base class for component modules

=head1 SYNPOSIS

    package Your::Component::Module;

    use Contentity::Class
        base => 'Contentity::Component';

    sub init_component {
        my ($self, $config) = @_;
        # your initialisation code here
        return $self;
    }

    sub some_other_method {
        my $self   = shift;

        # component has access to numerous useful things
        my $wspace = $self->workspace;  # parent workspace
        my $schema = $self->schema;     # data schema from workspace
        my $config = $self->config;     # configuration options from workspace

        # your method code here
    }

    1;

=head1 DESCRIPTION

This is a base class for component modules which plug into a workspace.
Components are created by a L<Contentity::Workspace>, typically via the
L<Contentity::Components> factory module.

The base class implements a custom L<init()> method which attaches the
component to the parent workspace, extracts the component name and data
schema from the arguments passed (from the L<Contentity::Workspace>
L<component()|Contentity::Workspace/component()> method) and then calls the
L<init_component()> method.

The L<init_component()> method does nothing in the base class.  Subclasses
may redefine it to implement custom initialisation functionality.

=head1 CONFIGURATION OPTIONS

The following configuration options can be passed to the L<new()> constructor
method.  These are usually provided by the
L<component_config()|Contentity::Workspace/component_config()> method in
L<Contentity::Workspce>.

=head2 workspace

A mandatory reference to the workspace in which the component is operating.

=head2 component

A short identifier indicating the component type, e.g. C<database>, C<site>,
C<page>, etc.  This defaults to 'component'.

=head2 urn

A short identifier indicating the component name.  In most case this will be
the same as L<component>.  However, it's possible to have multiple components
of the same type with different names.

=head2 schema

An optional hash reference containing the data schema for this component.
This would typically be defined in a C<schemas> block in the main
C<workspace> configuration file, or possible in a separate C<schemas>
configuration file.

=head2 config

A hash reference of configuration data, typically read from a workspace
configuration file.  If this is undefined then the configuration is assumed
to be all configuration options passed to the constructor function.

=head1 CLASS METHODS

=head2 new()

Public constructor method called to create a new workspace.

See L<CONFIGURATION OPTIONS> for further information about the parameters
this method accepts.

=head1 OBJECT METHODS

=head2 uri($uri)

Delegates to the L<Contentity::Workspace> L<uri()|Contentity::Workspace/uri()>
method.

=head2 dir($dir)

Delegates to the L<Contentity::Workspace> L<dir()|Contentity::Workspace/dir()>

=head1 INTERNAL METHODS

=head2 init($config)

Initialisation method called automatically when an object is contsructed
via L<new()>.  It performs some internal initialisation and then calls the
L<init_component()> method.

=head2 init_component($config)

Stub method which subclasses can redefine to implement any component-specific
initialisation.

=head2 destroy()

Called automatically when the component is no longer referenced.  Can also be
called manually by a L<Contentity::Workspace> as part of a clean-up process.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>.

=cut
