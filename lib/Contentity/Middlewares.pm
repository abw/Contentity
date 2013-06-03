package Contentity::Middlewares;

use Badger::Factory::Class
    version => 0.01,
    debug   => 0,
    item    => 'middleware',
    path    => 'Contentity(X)::Middleware';

1;

__END__

=head1 NAME

Contentity::Middlewares - factory module for loading and instantiating middleware modules

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This is a factory module for loading and instantiating middleware modules. It
is a subclass of L<Badger::Factory> which provides most of the functionality.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>, L<Contentity::Middleware>

=cut
