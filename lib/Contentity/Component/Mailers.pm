package Contentity::Component::Mailers;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    component => 'factory',
    asset     => 'mailer',
    constant  => {
        FACTORY_ITEM => 'mailer',
        FACTORY_TYPE => 'mailers',
        FACTORY_PATH => 'Contentity::Component::Mailer',
    };

1;


=head1 NAME

Contentity::Component::Mailers - factory module for loading and instantiating mailer modules

=head1 DESCRIPTION

This is a factory module for loading and instantiating mailer modules.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2016 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Component::Mailer>,
L<Contentity::Component::Factory>,
L<Contentity::Component::Asset>,
L<Badger::Factory>.

=cut
