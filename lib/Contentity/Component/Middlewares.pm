package Contentity::Component::Middlewares;

use Contentity::Middlewares;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'factory',
    asset     => 'middleware',
    constant  => {
        FACTORY_TYPE    => 'middlewares',
        FACTORY_MODULE  => 'Contentity::Middlewares',
        # See comment in C::Component::Apps
        CACHE_INSTANCES => 1,
    };

1;


