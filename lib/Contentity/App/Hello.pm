package Contentity::App::Hello;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Contentity::App';


sub run {
    my ($self, $context) = @_;
    $context->output("Hello from the Hello App!");
}

1;
