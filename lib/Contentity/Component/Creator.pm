package Contentity::Component::Creator;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component::Builder',
    constant    => {
        RENDERER => 'create',
    };


sub create {
    shift->build(@_);
}

1;
