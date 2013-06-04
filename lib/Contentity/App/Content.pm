package Contentity::App::Content;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::App',
    constants => ':html SLASH';


sub run {
    my ($self, $context) = @_;
    my $site = $context->site;
    my $tmps = $site->templates;
    my $path = $context->path;
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

    # quick hack
    if ($path =~ /\.css$/) {
        $context->content_type('text/css');
    }
    elsif ($path =~ /\.js$/) {
        $context->content_type('text/javascript');
    }
    else {
        $context->set( wrapper => 'html' );
    }

    my $data = $context->data;
    local $data->{ App  } = $self;
    local $data->{ Site } = $site;
    $context->output(
        $tmps->render($file, $data)
    );

}

1;
