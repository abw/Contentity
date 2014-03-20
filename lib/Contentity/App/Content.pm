package Contentity::App::Content;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::App',
    accessors => 'renderer vfs',
    constants => ':html SLASH',
    constant  => {
        RENDERER => 'content',
    };


# TODO: set the appropriate content type from the file extension
our $CONTENT_TYPE  = {
    xml => 'text/xml',
    css => 'text/css',
    js  => 'text/javascript',
    txt => 'text/plain',
};


sub init_app {
    my ($self, $config) = @_;
    my $workspace = $self->workspace;
    my $renderer  = $config->{ renderer } || $self->RENDERER;
    $self->{ renderer } = $workspace->renderer($renderer);
    $self->{ vfs      } = $self->renderer->source_vfs;
    $self->{ found    } = { };
    $self->debug("$renderer renderer is $self->{ renderer }");
    $self->debug("content app is in ", $workspace->ident, " workspace") if DEBUG;
}


sub run {
    my $self  = shift;
    my $uri   = $self->context->path;
    my $found = $self->{ found }->{ $uri };

    if (defined $found) {
        return $found
            ? $self->found($uri, $found)
            : $self->not_found($uri);
    }

    my $vfs  = $self->vfs;
    my $path = $vfs->path($uri);
    my ($dir, $file);

    #$self->debug(
    #    "self is $self, renderer is $self->{ renderer }, uri:$uri path:$path is_file:", 
    #    $path->is_file, "  is_dir:", $path->is_dir
    #);
    #$self->debug_data("$vfs roots", [$self->vfs->roots]);

    if ($path->is_file) {
        # Yay!  We found a file
        $self->debug("$path is a file: ", $path->definitive);
        $file = $vfs->file($path);
        $dir  = $file->dir;
    }
    elsif ($path->is_dir) {
        # We found a directory, so look for an index.html file in it
        $self->debug("$path is a directory: ", $path->definitive);
        $dir  = $vfs->dir($path);
        $file = $dir->file(INDEX_HTML);

        if ($file->exists) {
            $self->debug("found index.html  $uri => $file");
        }
        else {
            # no index file!
            # TODO: put in a directory handler
            return $self->error_msg( missing => "index.html in $dir" );
        }
    }
    else {
        # Otherwise try appending '.html' to find a file
        $path = $vfs->path($uri.DOT_HTML);

        if ($path->is_file) {
            $file = $vfs->file($path);
            $dir  = $file->dir;
        }
        else {
            return $self->not_found($uri);
        }
    }

    return $self->found($uri, $file);

}

sub found {
    my ($self, $uri, $file) = @_;
    $self->{ found }->{ $uri } = $file;
    return $self->render($file);
}

sub not_found {
    my ($self, $uri) = @_;

    $self->{ found }->{ $uri } = 0;

    return $self->send_not_found(
        "Not found: $uri"
    );
}

sub render {
    my ($self, $file) = @_;
    my $data = $self->context->data;
    my $html = $self->renderer->render($file->absolute, $data);
    my $ext  = $file->extension;
    $self->debug("TODO: extension-specific handling for $ext");
    return $self->send_html($html);
}

#    if ($file =~ /\.(\w+)$/) {
#        $self->extension_specific($context, $file, lc $1);
#    }


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
