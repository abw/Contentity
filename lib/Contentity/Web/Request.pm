package Contentity::Web::Request;

use Contentity::Web::Response;
use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Plack::Request::WithEncoding Contentity::Base',
    constant    => {
        RESPONSE_MODULE => 'Contentity::Web::Response',
    };


sub new_response {
    shift->RESPONSE_MODULE->new(@_);
}

1;
