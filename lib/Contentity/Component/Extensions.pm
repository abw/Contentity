package Contentity::Component::Extensions;

die __PACKAGE__, " is deprecated - moved in to Contentity::Component::ContentTypes";

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

sub content_type {
    my ($self, $file) = @_;
    my $ext  = $file->extension;
    my $meta = $self->workspace->extension($ext);
    my $type = TEXT_HTML;
    my $char;

    if ($meta) {
        $self->debug_data( "metadata for $ext extension" => $meta ) if DEBUG;
        $type = $meta->{ content_type } || $type;
        $char = $meta->{ charset };
        $type .= "; charset=$char" if $char;
    }

    return $type;
}



1;
