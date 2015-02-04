package Contentity::Web::Handler::Auth;

use Contentity::Class
    version   => 0.4,
    debug     => 1,
    base      => 'Contentity::Web::Handler';

sub handler : method {
    my ($class, $apache) = @_;
    my $self = bless { apache => $apache }, $class;
    $self->handle;
}

sub handle {
    shift->not_implemented('in base class');
}

1;

__END__
