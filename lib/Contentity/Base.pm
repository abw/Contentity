package Contentity::Base;

use Badger::Debug ':all';
use Badger::Rainbow
    ANSI      => 'cyan yellow grey green magenta bold';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    utils     => 'weaken',
    base      => 'Badger::Base',
    constants => 'SPACE',
    messages  => {
        invalid_in      => "Invalid %s specified: '%s' in %s",
        invalid_in_item => "Invalid %s specified: '%s' in %s: %s",
    };

our $DEBUG_FORMAT =
    cyan('[').
    bold(yellow('<where> ')).
    bold(cyan('line <line>')).
    cyan(']').
    "\n<msg>";

sub debug_magic {
    # called by Badger::Base to allow debugging messages to be customised
    return {
        format => $DEBUG_FORMAT,
    };
}

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
    my ($self, $msg, $data) = @_;
    local $Badger::Debug::CALLER_UP = 1;
    local $Badger::Debug::CALLER_AT = $self->debug_magic;
    my $dump = $self->dump_data($data);
    for ($dump) {
        s/(=>)\s([^\{\}\[\]].+)/$1.SPACE.yellow($2)/ge;
        s/(\S+)\s(=>)/bold(green($1)).SPACE.cyan($2)/ge;
        s/([{}]+)/green($1)/ge;
    }
    $self->debug(
        bold(cyan($msg)),
        ': ',
        $dump
    );
}

# Darn, the debug() method is inserted into each class by Badger::Class
# (via the "debug => 0" hook so we can't redefine the debug() method and
# expect subclasses to find it.

sub dbg {
    my $self = shift;
    local $Badger::Debug::CALLER_UP = 1;
    local $Badger::Debug::CALLER_AT = $self->debug_magic;
    $self->debug(@_);
}



1;


=head1 NAME

Contentity::Base - base class module for all other Contentity modules

=head1 DESCRIPTION

This module implement a common base class from which most, if not all other
modules are subclassed from.  It is implemented as a subclass of
L<Badger::Base>.

=head1 METHODS

All methods are inherited from the L<Badger::Base> base class.  It also
importa C<:all> exportable methods from L<Badger::Debug>.

The following methods are also defined.

=head2 dump_data_depth($data, $depth)

A wrapper around L<dump_data()|Badger::Debug/dump_data()> which limits the
depth of C<$data> dumped to C<$depth> levels.

=head2 dump_data1($data)

Method of convenience calling L<dump_data_depth()> with C<$depth> set to C<1>.

=head2 dump_data2($data)

Method of convenience calling L<dump_data_depth()> with C<$depth> set to C<2>.

=head2 debug_data($data)

Re-implementation (a quick hack) to add support for colour in data dumps.

=head2 debug_magic()

Part of an ugly hack to allow debugging message formats to be customised.

=head2 dbg()

The other part of the ugly L<debug_magic()> hack.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=cut
