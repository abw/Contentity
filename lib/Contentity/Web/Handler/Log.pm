package Contentity::Web::Handler::Log;

use Contentity::Class
    version   => 0.4,
    debug     => 1,
    base      => 'Contentity::Web::Handler';



sub handle {
    my $self = shift;

    $self->handle_app(
        $self->log
    );
}

sub handle_error {
    my $self = shift;
    # we can't use $apache->print() to print an error before the request phase
    # so we just log the error and throw an error.
    $self->warn("handle_error() can't handle an error: ", @_);

    #my $apache = $self->apache;
    #$apache->content_type(TEXT_HTML . '; ' . CHARSET_UTF8);
    #$apache->status(SERVER_ERROR);
    return 500;
}

1;

__END__
