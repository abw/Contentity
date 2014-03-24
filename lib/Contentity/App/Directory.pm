package Contentity::App::Directory;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::App',
    accessors => 'root template index vfs',
    constants => ':html :http_status SLASH BLANK TRUE FALSE',
    utils     => 'extend join_uri VFS',
    constant  => {
        RENDERER => 'dynamic',
        TEMPLATE => 'directory/index.html',
    };

# TODO: This needs to take SCRIPT_NAME into account when generating URLs


sub init_app {
    shift->init_directory(@_);
}

sub init_directory {
    my ($self, $config) = @_;

    $self->debug_data( directory => $config ) if DEBUG;

    $self->{ template   } = $config->{ template } || $self->TEMPLATE;
    $self->{ index      } = $config->{ index };
    $self->{ files      } = { };
    $self->{ dirs       } = { };
    $self->{ redirects  } = { };
    $self->{ not_found  } = { };

    $self->init_vfs($config);
}

sub init_vfs {
    my ($self, $config) = @_;
    my $root = $config->{ root } || return $self->error_msg( missing => 'root' );
    my $vdir = $self->{ root } = $self->workspace->dir($root);

    $self->{ vfs } = VFS->new( root => $vdir->definitive );
    $self->debug(
        "created directory VFS with root $vdir => ", $vdir->definitive
    ) if DEBUG;
}

sub run {
    my $self = shift;
    my $root = $self->root;
    my $uri  = $self->uri;
    my ($path, $dir, $file, $url);

    $self->debug("URI: $uri") if DEBUG;

    # Is it a file we've previously found?
    return $self->present_file($uri, $file)
        if $file = $self->{ files }->{ $uri };

    # Or a directory we've previously found?
    return $self->present_dir($uri, $dir)
        if $dir = $self->{ dirs }->{ $uri };

    # Or something that required a redirect
    return $self->send_redirect($url)
        if $url = $self->{ redirects }->{ $uri };

    # Is it something we've previously looked for but not found?
    return $self->send_not_found($uri)
        if $self->{ not_found }->{ $uri };


    # Have a look for it in the virtual filesystem
    $path = $self->path($uri);

    $self->debug("URL: ", $path->definitive) if DEBUG;

    # Is it a file?
    return $self->found_file($uri, $self->file($path))
        if $path->is_file;

    # Is is a directory?
    if ($path->is_dir) {
        $dir  = $self->dir($path);
        $file = $dir->file(INDEX_HTML);

        # Is there an index.html file in the directory?  Redirect to it.
        return $self->found_redirect($uri, $file->path)
            if $file->exists;

        # Redirect to /some/dir/ if we're at /some/dir
        return $self->found_redirect($uri, $uri . SLASH)
            unless $uri =~ m/\/$/;

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

#-----------------------------------------------------------------------------
# Methods called to signal that a file or directory has been found (or not)
#-----------------------------------------------------------------------------

sub found_file {
    my ($self, $uri, $file) = @_;
    $self->debug("found a file for $uri: ", $file->definitive) if DEBUG;
    $self->{ files }->{ $uri } = $file;
    return $self->present_file($uri, $file);
}

sub found_dir {
    my ($self, $uri, $dir) = @_;
    $self->debug("found a dir for $uri: ", $dir->definitive) if DEBUG;
    $self->{ dirs }->{ $uri } = $dir;
    return $self->present_dir($uri, $dir);
}

sub found_redirect {
    my ($self, $uri, $url) = @_;
    $self->debug("found a redirect for $uri => $url") if DEBUG;
    my $base = $self->context->script_name;
    $self->debug("[base:$base] + [url:$url]") if DEBUG or 1;
    my $goto = join_uri($base, $url);
    $self->{ redirects }->{ $uri } = $goto;
    return $self->send_redirect($goto);
}

sub not_found {
    my ($self, $uri) = @_;
    $self->{ not_found }->{ $uri } = 1;
    return $self->send_not_found($uri);
}

#-----------------------------------------------------------------------------
# Presentation methods
#-----------------------------------------------------------------------------

sub present_file {
    my ($self, $uri, $file) = @_;
    my $type = $self->content_type($file);
    my $fh   = $file->open;

    # TODO
    #   - check file permissions
    #   - Last-Modified header?
    #     'Content-Length' => $stat[7],
    #     'Last-Modified'  => HTTP::Date::time2str( $stat[9] )

    $self->debug("sending [file:$file] [type:$type]  [fh:$fh]") if DEBUG or 1;

    return $self->response(
        status => OK,
        type   => $type,
        body   => $fh,
    );
}


sub present_dir {
    my ($self, $uri, $dir) = @_;

    # TODO: fix up the mess of file paths vs VFS paths vs resource URLS
    my $base = $self->context->script_name; #{ base };
    $base =~ s[/$][];

    return $self->send_html(
        $self->render(
            $self->template,
            {
                base => $base,
                uri  => $uri,
                dir  => $dir
            }
        )
    );
}


#-----------------------------------------------------------------------------
# Miscellaneous methods
#-----------------------------------------------------------------------------

sub content_type {
    shift->workspace->file_content_type(@_);
}

sub content_icon {
    my ($self, $file) = @_;
    my $type = $self->workspace->content_types->type($file->extension) || return;
    return $type->{ icon };
}

sub uri {
    shift->context->path || SLASH;
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

1;

__END__

#-----------------------------------------------------------------------------
# TODO: old extension-specific stuff is below - don't know if it still makes
# sense to access the $context->page to set wrapper...
#-----------------------------------------------------------------------------
==
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
