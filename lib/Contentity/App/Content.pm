package Contentity::App::Content;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::App',
    constants => ':html SLASH';

our $CONTENT_TYPE  = {
    xml => 'text/xml',
    css => 'text/css',
    js  => 'text/javascript',
    txt => 'text/plain',
};


sub run {
    my ($self, $context) = @_;
    my $path = $context->path;
    my $site = $context->site;
    my $tmps = $site->templates;
    my $exts = $site->extensions || { };
    my $file = $path;

    LOOK: {
        last if $tmps->template_file($file)->exists;
        $self->debug("$file not found, adding ", DOT_HTML);
        $file = $path . DOT_HTML;
        last if $tmps->template_file($file)->exists;
        $self->debug("$file not found, adding ", INDEX_HTML);
        $file = $path . SLASH . INDEX_HTML;
        last if $tmps->template_file($file)->exists;
        $self->debug("$file not found, returning ");
        $context->output(
            "Template not found: $path in ", 
            $self->dump_data($tmps->vfs->roots)
        );
        return;
    }
    $file =~ s[^/+][];

    if ($file =~ /\.(\w+)$/) {
        $self->extension_specific($context, $file, lc $1);
    }

    $context->output(
        $tmps->render($file, $context->data)
    );

}

sub extension_specific {
    my ($self, $context, $file, $ext) = @_;
    my $site = $context->site       || return;
    my $page = $context->page       || return;
    my $exts = $site->extensions    || return;
    my $meta = $exts->{ $ext }      || return;
    my $data;

    if ($data = $meta->{ content_type }) {
        $context->content_type($data);
        $self->debug("EXT[$ext] $file set content_type to $data");
    }

    if ($data = $meta->{ wrapper }) {
        $page->{ wrapper } = $data;
        $self->debug("EXT[$ext] $file set wrapper to $data");
    }
}

1;
