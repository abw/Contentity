package Contentity::Database::Record;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Badger::Database::Record Contentity::Base',
    utils     => 'extend';


sub init {
    my ($self, $config) = @_;
    $self->init_record($config);
    return $self;
}

sub init_record {
    my ($self, $config) = @_;
    extend($self, $config);
}

sub workspace {
    shift->table->workspace;
}

1;
