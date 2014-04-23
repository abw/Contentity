package Contentity::Form::Field::Text;

use Contentity::Class::Form::Field
    version => 0.05,
    debug   => 0;

1;

__END__

=head1 NAME

Contentity::Form::Field::Text - text form field

=head1 SYNOPSIS

    use Contentity::Form::Field::Text;

    my $field = Contentity::Form::Field::Text->new({
        name      => 'username',
        label     => 'Username',
        size      => 32,
        mandatory => 1,
    });

=head1 DESCRIPTION

This module defines a text field object.  It is a direct subclass of
L<Contentity::Form::Field>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field::Text> in 2001,
became C<Badger::Web::Form::Field::Text> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut
