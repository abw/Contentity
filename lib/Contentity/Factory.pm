package Contentity::Factory;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Factory Contentity::Base',
    utils     => 'camel_case',
    constants => 'PKG HASH';

our $PACKAGE_MAP = {
    url => 'URL',
};


sub type_args {
    my ($self, $type, $args) = @_;
    $self->debug_data("type_args: $type", $args) if DEBUG;
    if (ref $type eq HASH) {
        $args = $type;
        $type = $args->{ type };
    }
    $self->debug_data("type => $type", $args) if DEBUG;

    return ($type, $args);
}

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
