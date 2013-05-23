package Contentity::Module::Database;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Module';


sub init_module {
    my ($self, $config) = @_;
    $self->debug("Database module init_module()") if DEBUG;
    return $self;
}


1;

