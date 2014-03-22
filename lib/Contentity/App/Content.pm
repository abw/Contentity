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
    shift->init_content(@_);
}

sub init_content {
    my ($self, $config) = @_;
    my $workspace = $self->workspace;
    my $renderer  = $config->{ renderer } || $self->RENDERER;

    $self->debug_data( content => $config ) if DEBUG;

    $self->{ renderer   } = $workspace->renderer($renderer);
#   $self->{ extensions } = $workspace->extensions;
    $self->{ vfs        } = $self->renderer->source_vfs;
    $self->{ files      } = { };
    $self->{ dirs       } = { };
    $self->{ not_found  } = { };
}

sub run {
    my $self  = shift;
    my $uri   = $self->uri;
    my ($path, $dir, $file);

    # Is it something we've previously looked for but not found?
    return $self->not_found($uri)
        if $self->{ not_found }->{ $uri };

    # Is it a file we've previously found?
    return $self->found_file($uri, $file)
        if $file = $self->{ files }->{ $uri };

    # Or a directory we've previously found?
    return $self->found_dir($uri, $dir)
        if $dir = $self->{ dirs }->{ $uri };

    # Have a look for it in the virtual filesystem
    $path = $self->path($uri);

    # Is it a file?
    return $self->found_file($uri, $self->file($path))
        if $path->is_file;

    # Is is a directory?
    if ($path->is_dir) {
        $dir  = $self->dir($path);
        $file = $dir->file(INDEX_HTML);

        # Is there an index.html file in the directory?
        return $self->found_file($uri, $file)
            if $file->exists;

        return $self->found_dir($uri, $dir);
    }

    # Otherwise try appending '.html' to find a file
    $path = $self->path($uri.DOT_HTML);

    # Is it a file?
    return $self->found_file($uri, $self->file($path))
        if $path->is_file;

    # give up
    return $self->not_found($uri);
}

sub found_file {
    my ($self, $uri, $file) = @_;
    $self->debug("found a file for $uri: ", $file->definitive);
    $self->{ files }->{ $uri } = $file;
    return $self->present_file($uri, $file);
}

sub found_dir {
    my ($self, $uri, $dir) = @_;
    $self->debug("found a dir for $uri: ", $dir->definitive);
    $self->{ dirs }->{ $uri } = $dir;
    # TODO: put in a directory handler
    return $self->error_msg( missing => "TODO: directory index for $dir" );
}

sub not_found {
    my ($self, $uri) = @_;
    $self->{ not_found }->{ $uri } = 1;
    return $self->send_not_found(
        "Not found: $uri"
    );
}

sub present_file {
    my ($self, $uri, $file) = @_;
    my $data = $self->context->data;
    my $html = $self->renderer->render($file->absolute, $data);
    my $ext  = $file->extension;
    my $meta = $self->workspace->extension($ext);
    my $type = 'text/html';

    if ($meta) {
        $self->debug_data( "metadata for $ext extension" => $meta ) if DEBUG;
        $type = $meta->{ content_type } || $type;

        # TODO: other metadata
    }

    return $self->response(
        type => $type,
        body => $html,
    );
}

sub uri {
    shift->context->path;
}

sub path {
    shift->vfs->path(@_);
}

sub file {
    shift->vfs->file(@_);
}

sub dir {
    shift->vfs->dir(@_);
}

#-----------------------------------------------------------------------------
# TODO: old extension-specific stuff is below - don't know if it still makes
# sense to access the $context->page to set wrapper...
#-----------------------------------------------------------------------------

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
