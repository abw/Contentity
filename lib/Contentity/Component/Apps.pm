package Contentity::Component::Apps;

use Contentity::Apps;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'factory',
    asset     => 'app',
    constant  => {
        FACTORY_TYPE    => 'apps',
        FACTORY_MODULE  => 'Contentity::Apps',
        CACHE_INSTANCES => 1,
    };

1;


