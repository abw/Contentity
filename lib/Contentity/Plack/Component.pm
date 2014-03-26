package Contentity::Plack::Component;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Plack::Base Plack::Component';


sub call {
    shift->not_implemented('in base class');
}

sub add_middleware {
    my $self  = shift;
    my $wares = $self->middleware(@_);
    return $wares->wrap(
        $self->to_app
    );
}

sub middleware {
    shift->workspace->middleware(@_);
}


1;

__END__

=head1 NAME

Contentity::Plack::Component - Contentity base class for Plack components

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

