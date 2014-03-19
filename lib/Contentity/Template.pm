package Contentity::Template;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template Contentity::Base',
    utils     => 'self_params';


sub new {
    my ($class, $params) = self_params(@_);

    $class->debug_data(
        "Contentity::Template engine params: ", 
        $params
    ) if DEBUG;

    return $class->SUPER::new($params);
}


1;
