package Contentity::App::Dynamic;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::App::Content',
    accessors => 'uri_prefix uri_match',
    constant  => {
        RENDERER  => 'dynamic',
        SINGLETON => 0,
    };


# ARSE!  In the case of js, for example, we have both static files in
# static/js and dynamic templates in templates/static/js

sub init_app {
    my ($self, $config) = @_;

    $self->debug_data( dynamic => $config ) if DEBUG;

    $self->init_directory($config);

    $self->{ uri_prefix } = $config->{ uri_prefix };

    if (my $prefix  = $config->{ uri_strip }) {
        my $escaped = quotemeta $prefix;
        $self->{ uri_strip } = $prefix;
        $self->{ uri_match } = qr/^$escaped/;
        $self->debug("got a uri_prefix: $prefix matched by $self->{ uri_match }") if DEBUG;
    }

    return $self;
}

sub uri {
    my $self   = shift;
    my $match  = $self->uri_match;
    my $prefix = $self->uri_prefix;
    my $uri    = $self->context->path;
    my $path   = $uri;

    $self->debug("uri: $uri") if DEBUG;

    if ($match && $path =~ s/$match//) {
        $self->debug("stripped '$self->{uri_strip}' prefix $uri => $path") if DEBUG;
    }

    if ($prefix) {
        $path = $prefix . $path;
        $self->debug("appended '$self->{uri_prefix}' prefix $uri => $path") if DEBUG;
    }

    return $path;
}


1;
