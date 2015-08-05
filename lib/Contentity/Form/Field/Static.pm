package Contentity::Form::Field::Static;

use Contentity::Class::Form::Field
    version  => 0.05,
    debug    => 0,
    display  => 'static',
    constant => {
        can_focus => 0,
    };

sub validate {
    my $self = shift;
    return ($self->{ valid } = 1);
}

1;

__END__

=head1 NAME

Contentity::Form::Field::Static - static text form field

=head1 SYNOPSIS

TODO:

=head1 DESCRIPTION

This module defines a static text field object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
