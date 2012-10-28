package Contentity::Utils;

use warnings            qw( FATAL utf8 );
use open                qw< :std :utf8 >;
use Carp;
use Badger::Debug       'debug_caller';
use Badger::Filesystem  'File';
use Badger::Timestamp   'Timestamp Now';
use Badger::URL         'URL';
use Badger::Utils       'params';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Utils',
    constants => 'HASH',
    exports   => {
        any => 'Timestamp Now URL File debug_caller extend'
    };


sub extend {
    my $hash = shift;
    my $more;

    while (@_) {
        if (! $_[0]) {
            # ignore undefined/false values
            shift;
            next;
        }
        elsif (ref $_[0] eq HASH) {
            $more = shift;
        }
        else {
            $more = params(@_);
            @_    = ();
        }
        @$hash{ keys %$more } = values %$more;
    }
    
    return $hash;
}


1;

=head1 NAME

Contentity::Utils - various utility functions for Contentity

=head1 SYNOPSIS

    use Contentity::Utils 'Now';
    print Now;      # prints timestamp for current date/time

=head1 DESCRIPTION

This module is a subclass of the L<Badger::Utils> module.  It defines some
additional utility function specific to the Contentity modules.

=head1 EXPORTABLE FUNCTIONS

The following utility functions are defined in addition to those inherited
from L<Badger::Utils>.

=head2 File

Function for creating a file object, imported from L<Badger::Filesystem>.

=head2 Now

Function for returning a L<Badger::Timestamp> object representing the 
current date and time.  Imported from L<Badger::Timestamp>.

=head2 Timestamp

Function for creating a L<Badger::Timestamp> object. Imported from
L<Badger::Timestamp>.

=head2 URL

Function for creating a L<Badger::URL> object for representing and
manipulating a URL.  Imported from L<Badger::URL>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

=cut
