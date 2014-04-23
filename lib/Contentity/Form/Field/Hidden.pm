package Contentity::Form::Field::Hidden;

use Contentity::Class::Form::Field
    version  => 0.03,
    layout   => 'hidden',
    constant => {
        can_focus => 0,
    };


1;

__END__

=head1 NAME

Contentity::Form::Field::Hidden - hidden form field

=head1 DESCRIPTION

This module defines a hidden field object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field::Hidden> in 2001,
became C<Badger::Web::Form::Field::Hidden> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut
