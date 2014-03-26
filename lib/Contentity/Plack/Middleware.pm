package Contentity::Plack::Middleware;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Plack::Component Plack::Middleware';

sub wrap {
    my ($self, $app) = @_;

    $self->{ app } = $app;

    # we want to be able to chain ->add_middleware() calls, so we return the
    # middleware object rather than the plack handler from $self->to_app;
    return $self;
#   return $self->to_app;
}

1;

__END__

=head1 NAME

Contentity::Plack::Middleware - Contentity base class for middleware components

=head1 DESCRIPTION

This module is a base class for all custom Plack middleware components used 
in the Contentity system.  It is a subclass of the L<Contentity::Plack::Component> 
module.

=head1 METHODS

This module inherits all methods from the L<Contentity::Plack::Component> base 
class.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut

