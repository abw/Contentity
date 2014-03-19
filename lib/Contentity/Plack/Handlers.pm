package Contentity::Plack::Handlers;

use Badger::Factory::Class
    version  => 0.01,
    debug    => 0,
    item     => 'handler',
    path     => 'Contentity(X)::Plack::Handler',
    handlers => {
        # most names can be grokked automagically, but this one has unusual
        # capitalisation
        url_map => 'Contentity::Plack::Handler::URLMap',
    };

1;

__END__

=head1 NAME

Contentity::Plack::Apps - factory module for loading and instantiating Plack apps

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This is a factory module for loading and instantiating Plack apps. It
is a subclass of L<Badger::Factory> which provides most of the functionality.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>, L<Contentity::Middleware>

=cut
