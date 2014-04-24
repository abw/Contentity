package Contentity::Form::Field::Submit;

use Contentity::Class::Form::Field
    version => 0.04,
    base    => 'Contentity::Form::Field::Button',
    display => 'submit',
    default => 'Submit';


sub validate {
    return 1;
}

sub reset {
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Submit - submit button for web form

=head1 SYNOPSIS

    use Contentity::Form::Field::Submit;
    my $submit = Contentity::Form::Field::Submit->new({
        name  => 'submit',
        value => 'Save',
    });

=head1 DESCRIPTION

This module defines a submit button for web forms.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field::Submit> in 2001,
became C<Badger::Web::Form::Field::Submit> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut
