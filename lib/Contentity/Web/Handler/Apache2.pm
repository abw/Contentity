package Contentity::Web::Handler::Apache2;

use Contentity::Class
    version   => 0.5,
    debug     => 1,
    base      => 'Contentity::Web::Handler Plack::Handler::Apache2',
    constants => ':http_status :html',
    accessors => 'apache';


#-----------------------------------------------------------------------------
# Handler hook method
#-----------------------------------------------------------------------------

sub handler : method {
    my ($class, $apache) = @_;
    my $self = bless { apache => $apache }, $class;
    my $response = eval {
        $self->handle;
    };
    if ($@) {
        return $self->handle_error($@);
    }
    else {
        return $response;
    }
}

sub handle_app {
    my ($self, $app) = @_;
    $self->call_app($self->apache, $app);
}

sub handle_error {
    my $self = shift;
    my $apache = $self->apache;
    $apache->content_type(TEXT_HTML . '; ' . CHARSET_UTF8);
    $apache->status(SERVER_ERROR);
    $apache->print(
      '<html><head><title>Application Error</title></head><body>',
      "An uncaught error occurred: ", @_,
      '</body></html>',
    );
    return;
}

#-----------------------------------------------------------------------------
# Methods to fetch configuration values from Apache directory/location config
#-----------------------------------------------------------------------------

sub config {
    my ($self, $item) = @_;
    return $self->apache->dir_config($item)
        || $self->SUPER::config($item);
}


1;

__END__
