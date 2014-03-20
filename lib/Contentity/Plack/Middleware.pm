package Contentity::Plack::Middleware;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Plack::Component Plack::Middleware';

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

