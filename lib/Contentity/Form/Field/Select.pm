package Contentity::Form::Field::Select;

use Contentity::Class::Form::Field
    version   => 0.03,
    words    => 'ARRAY OPTIONS';


sub options {
    my $self = shift;

    if (@_) {
        $self->{ options } =
            (@_ == 1 && ref $_[0] eq ARRAY) # if we get a single array ref
            ? [ @{ $_[0] } ]                # then we clone it,
            : [ @_ ];                       # otherwise construct list ref from args
    }
    else {
        $self->{ options } ||= do {
            my $opts = $self->bclass->var(OPTIONS);
            $opts ? [ @$opts ] : [ ];
        };
    }

    return $self->{ options };
}

sub size {
    my $self = shift;
    return $self->{ size } || 0;
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Select - pull-down selection field

=head1 SYNOPSIS

    use Contentity::Form::Field::Select;

    my $field = Contentity::Form::Field::Select->new({
        name     => 'fave_number',
        label    => 'Your favourite number',
        value    => 42,
        options  => [
            { name => 'Pi', value => 3.14159 }
            { name => 'Forty-Two', value => 42 }
            { name => 'Sixty-Nine', value => 69 }
        ]
    });

=head1 DESCRIPTION

This module defines a C<select> form field for choosing an item
from a pull-down list.

This module was previously known as C<Badger::Web::Form::Field::Select>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
