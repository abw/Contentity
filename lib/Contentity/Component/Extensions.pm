package Contentity::Component::Extensions;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Contentity::Component';


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data( extensions => $config ) if DEBUG;

    return $self;
}

sub extension {
    my ($self, $ext) = @_;
    return $self->config($ext);
}



1;
