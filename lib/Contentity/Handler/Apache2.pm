package Contentity::Handler::Apache2;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    base      => 'Contentity::Base Plack::Handler::Apache2',
    constant    => {
        ROOT_CONFIG => 'root',
        SITE_CONFIG => 'site',
        APP_CONFIG  => 'app',
    };



sub handler : method {
    my ($class, $apache) = @_;
    my $uri  = $apache->location;
    my $root = $apache->dir_config($self->ROOT_CONFIG);
    my $site = $apache->dir_config($self->SITE_CONFIG);
    my $app  = $apache->dir_config($self->APP_CONFIG);

    $self->todo;
}

1;
