package Contentity::Web::App::Content;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Web::App::Directory',
    accessors => 'vfs',
    constants => ':html SLASH TRUE FALSE',
    constant  => {
        RENDERER => 'content',
    };


sub init_vfs {
    my ($self, $config) = @_;
    $self->{ vfs } = $self->renderer->source_vfs;
}

sub present_file {
    my ($self, $uri, $file) = @_;
    my $data = $self->context->data;
    $self->debug_data(
        "about to render [uri:$uri] from [file:$file] with",
        $data
    ) if DEBUG;
    my $html = $self->renderer->render($file->absolute, $data);
    my $type = $self->content_type($file);

    return $self->response(
        type => $type,
        body => $html,
    );
}

1;

__END__

#-----------------------------------------------------------------------------
# TODO: old extension-specific stuff is below - don't know if it still makes
# sense to access the $context->page to set wrapper...
#-----------------------------------------------------------------------------
==
sub extension_specific {
    my ($self, $context, $file, $ext) = @_;
    my $site = $context->site       || return;
    my $page = $context->page       || return;
    my $exts = $site->extensions    || return;
    my $meta = $exts->{ $ext }      || return;
    my $data;

    if ($data = $meta->{ wrapper }) {
        $page->{ wrapper } = $data;
        $self->debug("EXT[$ext] $file set wrapper to $data");
    }
}

1;
