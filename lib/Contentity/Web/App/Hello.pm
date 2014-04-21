package Contentity::Web::App::Hello;

use Contentity::Class
    debug   => 0,
    base    => 'Contentity::Web::App';


sub run {
    my $self = shift;

    if (DEBUG) {
        $self->debug_data( headers => $self->request->headers );
        $self->debug_data( accept_type => $self->context->accept_type );
        $self->debug_data( accept_encoding => $self->context->accept_encoding );
        $self->debug_data( accept_language => $self->context->accept_language );
    }
#    $self->debug_data( env => $self->env ) if DEBUG;

    my $message = $self->config('message') || 'Hello World';

    $self->send_html($message);
}


1;
