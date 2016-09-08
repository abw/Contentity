package Contentity::Web::Handler::Apache2::App;

use Contentity::Project;
use Contentity::Class
    version   => 0.5,
    debug     => 1,
    base      => 'Contentity::Web::Handler::Apache2',
    constant  => {
        PROJECT_MODULE => 'Contentity::Project',
    };


sub handle {
    my $self = shift;
    $self->handle_app(
        $self->app
    );
}

1;
