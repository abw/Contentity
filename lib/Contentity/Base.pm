package Contentity::Base;

use Badger::Debug ':all';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    utils     => 'weaken',
    base      => 'Badger::Base',
    messages  => {
        invalid_in      => "Invalid %s specified: '%s' in %s",
        invalid_in_item => "Invalid %s specified: '%s' in %s: %s",
    };


sub dump_data_depth {
    my ($self, $data, $depth) = @_;
    local $Badger::Debug::MAX_DEPTH = $depth;
    $self->dump_data($data);
}

sub dump_data1 {
    shift->dump_data_depth(shift, 1);
}

sub dump_data2 {
    shift->dump_data_depth(shift, 2);
}

sub debug_data {
    my $self = shift;
    local $Badger::Debug::CALLER_UP = 1;
    $self->debug(
        map { ref $_ ? $self->dump_data($_) : $_ }
        @_
    );
}


1;


=head1 NAME

Contentity::Base - base class module for all other Contentity modules

=head1 DESCRIPTION

This module implement a common base class from which most, if not all other
modules are subclassed from.  It is implemented as a subclass of
L<Badger::Base>.  

=head1 METHODS

All methods are inherited from the L<Badger::Base> base class.

It also imports the C<debugf> method and C<:dump> methods from 
L<Badger::Debug>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

=cut

