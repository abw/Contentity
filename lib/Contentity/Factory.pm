package Contentity::Factory;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Factory',
    utils     => 'camel_case',
    constants => 'PKG';

our $PACKAGE_MAP = {
    url => 'URL',
};

sub module_names {
    my $self = shift;
    return join(
        PKG,
        map { $PACKAGE_MAP->{ $_ } || camel_case( $_ ) }
        map { split /[\.\/]+/ }
        @_
    );
}

1;
