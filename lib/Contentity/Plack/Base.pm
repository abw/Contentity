package Contentity::Plack::Base;

use Contentity::Plack::Handlers;
use Contentity::Plack::Middlewares;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    constant  => {
        HANDLERS    => 'Contentity::Plack::Handlers',
        MIDDLEWARES => 'Contentity::Plack::Middlewares',
    };


sub handler {
    shift->HANDLERS->handler(@_);
}

sub middleware {
    shift->MIDDLEWARES->middleware(@_);
}

1;

__END__

=head1 NAME

Contentity::Plack::Base - Contentity base class for Plack modules
=head1 DESCRIPTION

This module is a base class for all Plack modules in the Contentity system.  

=head1 METHODS

This module inherits all methods from the L<Contentity::Base> base class.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut

