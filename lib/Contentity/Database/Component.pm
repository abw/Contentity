package Contentity::Database::Component;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Base';

sub workspace {
    shift->hub;
}

1;

=head1 NAME

Contentity::Database::Component - a base class for database sub-compoents

=head1 DESCRIPTION

This module defines a base class for other database sub-components.

=head1 METHODS

=head2 workspace()

Returns a reference to the workspace that this database is currently deployed in.

The L<Badger::Database> modules permit the identification of a "hub" reference
(typically a L<Badger::Hub> object) which is passed around to allow various
components to access it.  In the Contentity framework we're using a variant
of L<Badger::Workspace> instead, but it serves the same purpose.

So this method simply maps the L<workspace()> method to the L<hub()> method.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=cut
