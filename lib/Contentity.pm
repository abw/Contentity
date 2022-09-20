package Contentity;

use Badger::Debug ':all';
use Contentity::Config;
use Contentity::Class
    debug      => 0,
    base       => 'Badger::Prototype Contentity::Base',
    import     => 'class',
    autolook   => 'autoload_hub';

our $VERSION = 0.15;
our $HUB = 'Contentity::Hub' unless defined $HUB;


sub init {
    my ($self, $config) = @_;
    $self->{ config } = $config;
    return $self;
}


#-----------------------------------------------------------------------------
# Methods to access the central hub, database and other shared components
#-----------------------------------------------------------------------------

sub hub {
    my $self = shift->prototype;

    if (@_) {
        # got passed an argument (a new hub) which we connect $self to
        return ($self->{ hub } = shift);
    }
    else {
        # return the existing hub, or connect up to one
        return $self->{ hub } ||= do {
            my $module = $self->class->any_var('HUB');
            $self->debug("Connecting to hub: $module\n") if DEBUG;
            class($module)->load;
            $module->new($self->{ config });
        };
    }
}


#-----------------------------------------------------------------------------
# The auto_can method is called when an unknown method is called.  It looks
# to see if the method can be delegated to either the database model or the
# hub.
#-----------------------------------------------------------------------------

sub autoload_hub {
    my ($self, $name, @args) = @_;
    my $hub = $self->hub;

    return  $hub->can($name)
        ?   $hub->$name(@args)
        :   undef;
}


1;

__END__

=head1 NAME

Contentity - web application framework

=head1 DESCRIPTION

This implements the basic framework of a web site deployment system.

=head1 METHODS


=head1 CORE MODULES

=head2 Contentity::Base

A base class object from which most other C<Contentity::*> modules are
derived.  It is itself a subclass of L<Badger::Base>.

=head2 Contentity::Cache

A wrapper around any C<Cache::Cache> implementation (e.g. memory cache,
memcache, etc) which adds some additional functionality specific to this
system.

=head2 Contentity::Class

A metaclass object that is used to construct other C<Contentity::Modules>.
It is a subclass of L<Badger::Class>

=head2 Contentity::Constants

Defines various constants used by the Contentity system.

=head2 Contentity::Configure

A module for running configuration scripts that prompt the user to answer
various questions, typically when configuring a new web site or virtual
host.

=head2 Contentity::Router

An advanced module for matching URLs to pre-defined routes.

=head2 Contentity::Workspace

A workspace is used to represent the root directory of a web site or other
project.  The precise location may vary from one machine to another.  There
could also be multiple copies of a site on the same machine, e.g. for
development, staging, testing, production, etc.  To avoid hard-coding paths
into library and application code we delegate to a workspace object (which
"knows" where its root directory is) to resolve relative filesystem paths.

=head2 Contentity::Utils

Contains various utility functions.


=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
