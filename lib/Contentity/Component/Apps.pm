package Contentity::Component::Apps;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'factory',
    asset     => 'app',
    constant  => {
        FACTORY_ITEM => 'app',
        FACTORY_TYPE => 'apps',
        FACTORY_PATH => 'Contentity::Web::App Contentity::App',
        # Hmmm... I don't think we should cache app instances... what if we
        # have different instances of the same app running in different
        # locations?
        #SINGLETONS   => 1,
    };

1;

=head1 NAME

Contentity::Component::Apps - factory module for loading apps

=head1 DESCRIPTION

This module defines a factory component for loading apps.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Component>,
L<Badger::Factory>.

=cut

1;
