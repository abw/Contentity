package Contentity::Web::Handler::App;

use Contentity::Class
    version   => 0.4,
    debug     => 1,
    base      => 'Contentity::Web::Handler';


sub handle {
    my $self = shift;

    $self->handle_app(
        $self->app
    );
}

1;

__END__
