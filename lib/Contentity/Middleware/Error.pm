package Contentity::Middleware::Error;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Middleware';


sub call {
    my($self, $env) = @_;

    my $res = eval {
        $self->app->($env);
    };

    if ($@) {
        $self->debug("Caught error: $@");
        return [ 500, [], ["OOPS!  Server Error: $@"]];
    }
    return $res;
}

1;
