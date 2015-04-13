package Contentity::Form::Field::Textarea;

use Contentity::Class::Form::Field
    version   => 0.04,
    base      => 'Contentity::Form::Field::Text',
    label     => 'Text',
    accessors => 'rows columns',
    methods   => {
        cols  => \&columns,
    },
    config    => [
        'columns|cols|size',
        'rows',
    ];

1;

__END__

=head1 NAME

Contentity::Form::Field::Textarea - text form field

=head1 SYNOPSIS

    use Contentity:Form::Field::Textarea;

    my $field = Conentity::Form::Field::Textarea->new({
        name      => 'username',
        label     => 'Username',
        rows      => 5,
        size      => 32,   # columns
        mandatory => 1,
    });

=head1 DESCRIPTION

This module implements a textarea form field object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2015 Andy Wardley.  All Rights Reserved.

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
