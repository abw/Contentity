package Contentity::Web::Apache2::Handler::Log;

use Contentity::Project;
use Contentity::Class
    version   => 0.5,
    debug     => 1,
    base      => 'Contentity::Web::Handler::Apache2',
    constants => ':http_status',
    constant  => {
        PROJECT_MODULE => 'Contentity::Project',
    };


sub handle {
    my $self = shift;

    $self->handle_app(
        $self->log
    );
}

1;

__END__
