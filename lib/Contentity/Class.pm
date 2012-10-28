package Contentity::Class;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    uber      => 'Badger::Class',
#    hooks     => 'record entity entities crud table default type status progress constructor',
#    utils     => 'is_object',
#    constants => 'ARRAY DELIMITER',
    constant  => {
        UTILS      => 'Contentity::Utils',
        CONSTANTS  => 'Contentity::Constants',
    };


1;
