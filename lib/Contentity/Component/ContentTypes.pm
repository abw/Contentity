package Contentity::Component::ContentTypes;

use Contentity::Class
    debug     => 1,
    base      => 'Contentity::Component',
    accessors => 'request_types response_types';


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( content_types => $config ) if DEBUG;
    $self->init_content_types($config);
    return $self;
}

sub init_content_types {
    my ($self, $types) = @_;
    my $reqt = $self->{ request_types  } = { };
    my $rest = $self->{ response_types } = { };

    while (my ($key, $list) = each %$types) {
        foreach my $item (@$list) {
            $reqt->{ $item } = $key;
            $rest->{ $key } ||= $item;
        }
    }

    if (DEBUG) {
        $self->debug_data( request_types  => $self->request_types );
        $self->debug_data( response_types => $self->response_types );
    }
}

sub request_type {
    my ($self, $type) = @_;
    return $self->request_types->{ $type };
}

sub response_type {
    my ($self, $type) = @_;
    return $self->response_types->{ $type };
}

sub accept_types {
    my ($self, $types) = @_;
    my @keys = keys %$types;
    my $reqt = $self->request_types;

    foreach my $key (@keys) {
        my $type = $reqt->{ $key } || next;
        $types->{ $type } = $type;
    }

    $self->debug_data( merged_accept_types => $types ) if DEBUG;

    return $types;
}



1;

