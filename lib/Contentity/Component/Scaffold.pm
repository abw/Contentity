package Contentity::Component::Scaffold;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component::Builder',
    constant    => {
        RENDERER => 'scaffold',
    };


#sub output_dir {
#    shift->workspace->dir;
#}

1;
