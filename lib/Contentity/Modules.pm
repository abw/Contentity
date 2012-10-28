package Contentity::Modules;

use Badger::Factory::Class
    version => 0.01,
    debug   => 0,
    item    => 'module',
    path    => 'Contentity(X)::Module';

1;

__END__

=head1 NAME

Contentity::Modules - factory module for loading and instantiating plugin modules

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This is a factory module for loading and instantiating extension modules. It
is a subclass of L<Badger::Factory> which provides most of the functionality.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>.

=cut
