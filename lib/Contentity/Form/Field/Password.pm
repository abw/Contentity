package Contentity::Form::Field::Password;

use Contentity::Class::Form::Field
    version   => 0.04,
    debug     => 0,
    config    => [
        'mandatory=1',
        'min_length=6',
    ],
    messages  => {
        mismatch  => 'The two passwords you entered do not match.',
        incorrect => 'Incorrect password.',
    };

our $PREPARE = {
    strip_tags      => 0,
    strip_entities  => 0,
    trim_wspace     => 1,
    collapse_wspace => 0,
};

1;

__END__

=head1 NAME

Contentity::Form::Field::Password - password form field

=head1 SYNOPSIS

    use Contentity::Form::Field::Password;

    my $field = Contentity::Form::Field::Password->new({
        name      => 'password',
        label     => 'Password',
        size      => 32,
        mandatory => 1,
    });

=head1 DESCRIPTION

This module defines a password field object.  It is a subclass of
L<Contentity::Form::Field> that defines some additional configuration
parameters and related default values relevant to password fields.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field::Password> in 2001,
became C<Badger::Web::Form::Field::Password> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut
