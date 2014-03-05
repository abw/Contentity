package Contentity::Plack::Component;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base Plack::Component',
    accessors => 'env',
    constants => 'HASH';


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    $self->debugf("init(%s)", $self->dump_data($config)) 
        if $self->DEBUG;

    # copy all config items into self
    @$self{ keys %$config } = values %$config;

    # call component-specific init method
    $self->init_component($config);

    return $self;
}

sub init_component {
    # stub for subclasses
}


#-----------------------------------------------------------------------------
# Custom to_app() method which calls wrap_app() to add an extra runtime
# wrapper to store local (temporary) environment reference in $self->{ env }.
#-----------------------------------------------------------------------------

sub to_app {
    my $self = shift;
    return $self->wrap_app(
        $self->SUPER::to_app(@_)
    );
}

sub wrap_app {
    my $self = shift;
    my $app  = shift;
    return sub {
        local $self->{ env } = $_[0];
        $app->(@_);
    };
}


#-----------------------------------------------------------------------------
# Within the Plack environment we store a 'context' hash reference containing
# all the application-specific data we need to keep in context.
#-----------------------------------------------------------------------------

sub context {
    my $self    = shift;
    my $context = $self->env->{ context } ||= { };

    return $self->get_or_set(
        $context, @_
    );
}

#-----------------------------------------------------------------------
# Access to the context.data hash, optionally getting or setting an item
#-----------------------------------------------------------------------

sub data {
    my $self    = shift;
    my $context = $self->context;
    my $data    = $context->{ data } ||= { };
    return $self->get_or_set(
        $data, @_
    );
}

#-----------------------------------------------------------------------------
# Delete an item from context.data
#-----------------------------------------------------------------------------

sub delete {
    my ($self, $name) = @_;
    return CORE::delete $self->data->{ $name };
}


#-----------------------------------------------------------------------------
# Generic method for getting or setting an item in a hash reference, depending
# on the number of additional arguments.  One extra argument to get, two or
# more arguments to set an item or items.  No extra arguments returns the 
# hash reference itself.
#-----------------------------------------------------------------------------

sub get_or_set {
    my $self = shift;
    my $hash = shift;

    if (@_ == 0) {
        return $hash;
    }
    elsif (@_ == 1 && ! ref $_[0]) {
        return $hash->{ $_[0] };
    }
    else {
        my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
        while (my ($key, $value) = each %$args) {
            $hash->{ $key } = $value;
        }
        return $hash;
    }
}



1;

__END__

=head1 NAME

Contentity::Web::Plack::Component - Contentity base class for Plack components

=head1 DESCRIPTION

This module is a base class for all custom Plack components used in the Contentity
system.  It is a subclass of the L<Contentity::Base> and L<Plack::Component> modules.

=head1 METHODS

=head2 init($config)

The module redefines the C<init()|Contentity::Base/init()> method inherited from 
L<Contentity::Base>.  This is called automatically when a new component object is
instantiated.

It stores all the configuration items passed to it as items in the C<$self>
object (as is required to provide compatibility with L<Plack::Component>) and
then calls the component-specific L<init_component()> method.

=head2 init_component($config)

This is an empty method that does nothing.  Subclasses may redefine it to 
provide further initialisation.

=head2 to_app()

This method is called by Plack when a component is converted to an application 
subroutine reference.  This custom implementation is a wrapper around the 
default implementation provided by L<Plack::Component> (which it calls), 
adding an extra function wrapper around the application via the 
L<wrap_app()> method.

=head2 wrap_app($app)

This method creates an additional function wrapper around C<$app> which stores 
a local (temporary) reference to the C<$env> environment (passed automatically
as the first argument to all components when they're called) in the component
object as C<$self-E<gt>{ env }>.  

This allows Contentity components to access the environment as C<$self-E<gt>env> and 
avoids the need to pass the environment around to any and all methods that 
might need to access it.

=head2 context()

This method returns a reference to the C<context> hash array in the Plack
environment, creating it if it doesn't already exist.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut

