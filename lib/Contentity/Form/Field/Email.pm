package Contentity::Form::Field::Email;

use Contentity::Class::Form::Field
    version  => 0.03,
    debug    => 0,
    base     => 'Contentity::Form::Field::Text',
    config   => 'format|class:FORMAT!',
    display  => 'text',
    label    => 'Email Address',
    messages => {
        bad_address => 'Invalid email address',
    };

our $FORMAT = qr/^[\w\-\+\=\.]{1,64}@[a-zA-Z0-9\-\.]{5,128}$/;


sub validate {
    my $self   = shift;
    my $value  = $self->prepare(shift);
    my $format = $self->{ format };

    if (length $value) {
        # if there's a value defined, check it for correctness
        $self->debug("checking [$value] against [$format]") if DEBUG;
        if ($value =~ /$format/) {
            return ($self->{ valid } = 1);
        }
        else {
            return $self->invalid_msg('bad_address')
        }
    }
    elsif ($self->{ mandatory }) {
        # otherwise barf for mandatory fields
        return $self->invalid_msg( mandatory => $self->label );
    }
    else {
        return ($self->{ valid } = 1);
    }
    # not reached!
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Email - custom form field for email addresses.

=head1 SYNOPSIS

    use Contentity::Form::Field::Email;

    my $field = Contentity::Form::Field::Email->new({
        name      => 'email_address',
        label     => 'Email Address',
        size      => 32,
        mandatory => 1,
    });

    if ($field->validate($email)) {
        print $email, ' is a valid email address';
    }

=head1 DESCRIPTION

This module is a subclass of L<Contentity::Form::Field::Text> implementing
a web form field for entering email addresses.  It defines a custom
L<validate()> method which checks that the email address entered matches
the L<$FORMAT> regular expression.

The format of email addresses is defined by RFC2822. This permits all sorts of
characters in the local part and a maximum length of 255 chars in the domain.
However, this implementation places arbitrary restrictions on the format for
the purpose of form validation and data cleansing.

It limits the local part of an email address (before the C<@>) to a maximum
length of 64 characters. Only word characters are permitted, along with C<->,
C<+> and C<=>. The domain part (after the C<@>) is limited to a total length
of 128 characters and may only contain alphanumeric characters, C<-> and C<.>.
Note that underscores are not permitted in domain names as dictated by
RFC1034.

You can provide a different regular expression to match the email address
against using the L<format> option.

=head1 METHODS

The following methods are defined in addition to those inherited from the
C<Contentity::Form::Field::Text> base class.

=head2 validate($email)

A custom validation method which checks that the email address passed as
an argument has a valid format.  It does this by matching it against the
L<format> regular expression.
against the permitted

=head1 CONFIGURATION OPTIONS

The following configuration options are defined in addition to those
inherited from the C<Contentity::Form::Field::Text> base class.

=head2 format

A regular expression defining the permitted format for email addresses.
This defaults to the regular expression defined in the L<$FORMAT> package
variable.

=head1 PACKAGE VARIABLES

=head2 $FORMAT

This defines the default regular expression for matching email addresses.
You can re-define this in a subclass to provide a different default.

    package Your::Email::Field;
    use base 'Contentity::Form::Field::Email';
    our $FORMAT = qr/\w+{1,12}@[a-zA-Z0-9\-\.]{5,64}$/;

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field::Email> in 2001,
became C<Badger::Web::Form::Field::Email> in 2004 and was moved into the
C<Contentity> module set in April 2014.


=cut
