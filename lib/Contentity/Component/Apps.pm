package Contentity::Component::Apps;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'factory',
    asset     => 'app',
    constant  => {
        FACTORY_ITEM => 'app',
        FACTORY_TYPE => 'apps',
        FACTORY_PATH => 'Contentity::Web::App Contentity::App',
        # Hmmm... I don't think we should cache app instances... what if we
        # have different instances of the same app running in different
        # locations?
        SINGLETONS   => 1,
    };

1;
