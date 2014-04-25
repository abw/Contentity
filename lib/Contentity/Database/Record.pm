package Contentity::Database::Record;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
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

sub reload {
    my $self = shift;
    my $key  = $self->key;
    my $data = $self->table->fetch_one_row( $key => $self->{ $key } );
    $self->debug_data( reload => $data ) if DEBUG;
    extend($self, $data);
    return $self;
}

1;
