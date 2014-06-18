package Contentity::Component::ContentTypes;

use Contentity::Class
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'types accepts',
    constants => 'TEXT_HTML',
    utils     => 'split_to_list';


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( content_types => $config ) if DEBUG;
    $self->init_content_types($config);
    return $self;
}

sub init_content_types {
    my ($self, $config) = @_;
    my $types  = $self->{ types   } = $config;
    my $accept = $self->{ accepts } = { };

    while (my ($key, $spec) = each %$types) {
        my $ctype   = $spec->{ content_type };
        my $acclist = $spec->{ accept };
        my $urn     = $spec->{ urn } ||= $key;
        $spec->{ id } = $key;

        if ($ctype) {
            # add an accept mapping from the main content type to the entry
            # e.g. application/json => { ... }
            $accept->{ $ctype } = $spec;
        }

        if ($acclist) {
            $acclist = split_to_list($acclist);

            # also add accept mappings from any additional accept types
            # e.g. text/json => { ... }
            foreach my $item (@$acclist) {
                $accept->{ $item } = $spec;
            }
        }
    }

    if (DEBUG) {
        $self->debug_data( types   => $self->types   );
        $self->debug_data( accepts => $self->accepts );
    }
}

sub type {
    my ($self, $type) = @_;
    return $self->types->{ $type };
}

sub content_type {
    my ($self, $urn) = @_;
    my $meta = $self->type($urn);
    my $type; # = TEXT_HTML;
    my $char;

    if ($meta) {
        $self->debug_data( "metadata for $urn content type" => $meta ) if DEBUG;
        $type = $meta->{ content_type } || $type;
        $char = $meta->{ charset };
        $type .= "; charset=$char" if $char;
    }

    return $type;
}

sub media_type {
    my $self = shift;
    my $type = $self->type(@_) || return;
    return $type->{ media_type };
}

sub file_type {
    my $self = shift;
    my $type = $self->type(@_) || return;
    return $type->{ urn };
}

sub file_content_type {
    my ($self, $file) = @_;
    return $self->content_type($file->extension);
}

sub file_media_type {
    my ($self, $file) = @_;
    return $self->media_type($file->extension);
}

sub accept_types {
    my ($self, $types) = @_;
    my @keys    = keys %$types;
    my $accepts = $self->accepts;

    $self->debug_data( accepts => $accepts ) if DEBUG;
    $self->debug_data( client  => $types ) if DEBUG;

    foreach my $key (@keys) {
        my $type = $accepts->{ $key } || next;
        $self->debug_data("$key" => $type ) if DEBUG;
        $types->{ $type->{ id } } = $type->{ content_type };
    }

    $self->debug_data( merged_accept_types => $types ) if DEBUG;

    return $types;
}

1;
