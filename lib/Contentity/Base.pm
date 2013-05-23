package Contentity::Base;

use Badger::Debug ':all';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base';

1;


=head1 NAME

Contentity::Base - base class module for all other Contentity modules

=head1 DESCRIPTION

This module implement a common base class from which most, if not all other
modules are subclassed from.  It is implemented as a subclass of
L<Badger::Base>.  

=head1 METHODS

All methods are inherited from the L<Badger::base> base class.

It also imports the C<debugf> method and C<:dump> methods from 
L<Badger::Debug>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

=cut

