package Contentity::App::Dynamic;

# Oh dear, this is a mess.  The problem is that we're trying to map a URL like
# /cog/css onto the templates/static/css directory.  Sounds easy.  The problem
# is that the page metadata is based on the template filename relative to the
# templates/static directory e.g. /css/cog.css.  We need the page to be able
# to read its metadata so that it ends up with the correct page layout, wrapper,
# filters, etc.
#
# So it makes sense that we use a variant of the 'static' renderer which uses
# the templates/static directory as the root of a virtual file system, ensuring
# that the templates/static/css/cog.css template thinks its file path is simply
# /css/cog.css.  Then it can find the metadata and we're done!
#
# Well, no.  The problem now is that we have to map the /cog/css/cog.css URL
# onto /css/cog.css.  Sounds simple, but only because our URL mount point and
# directory name happen to coincide.  One day /cog/css could be changed to
# /styles and then we need to map /styles/cog.css to /css/cog.css.
#
# The full URL is broken down to the URL mount point, e.g. /cog/css or /styles
# (stored in SCRIPT_NAME) and the relative path, e.g. cog.css (in PATH_INFO).
#
#  /cog/css + cog.css = /cog/css/cog.css  => templates/static + /css/cog.css
#  /styles  + cog.css = /styles/cog.css   => templates/static + /css/cog.css
#
# The uri() method usually returns the PATH_INFO and nothing else.  In this
# case we need to prefix it with the '/css' part relative to the static
# templates directory, so the cog.css page thinks that it's /css/cog.css.
# This also makes directory indexes work just fine.
#
# However, in the template the file's path doesn't match the expected URL.
#
#

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::App::Content',
    accessors => 'uri_prefix uri_match',
    utils     => 'VFS join_uri',
    constant  => {
        RENDERER  => 'dynamic',
        SINGLETON => 0,
    };


sub init_app {
    my ($self, $config) = @_;

    $self->debug_data( dynamic => $config ) if DEBUG;

    $self->init_directory($config);

    $self->{ uri_prefix } = $config->{ uri_prefix };

    if (my $prefix  = $config->{ uri_strip } || $config->{ uri_prefix }) {
        my $escaped = quotemeta $prefix;
        $self->{ uri_strip } = $prefix;
        $self->{ uri_match } = qr/^$escaped/;
        $self->debug("got a uri_prefix: $prefix matched by $self->{ uri_match }") if DEBUG;
    }

    return $self;
}

sub init_vfs {
    my ($self, $config) = @_;
    my $renderer = $self->renderer;
    my $outdir   = $renderer->output_dir;
    my $vfs;

    if ($outdir) {
        # ARSE!  In the case of js, for example, we have both static files in
        # static/js and dynamic templates in templates/static/js
        $self->debug("vfs has got output dir: $outdir") if DEBUG;
        my @paths = (@{ $renderer->source_dirs }, $outdir);
        $self->debug_data( paths => \@paths ) if DEBUG;

        $vfs = VFS->new( root => \@paths );
        $self->{ output_dir } = $outdir;
    }
    else {
        # simple source-only renderer
        $self->debug("no output dir") if DEBUG;
        $vfs = $renderer->source_vfs;
    }

    $self->{ vfs } = $vfs;

    return $vfs;
}

sub TEST_uri {
    my $self   = shift;
    my $uri    = $self->context->path;
    my $script = $self->context->script_name;
    my $path   = join_uri($uri, $script);
    $self->debug("[script:$script] + [uri:$uri] => [path:$path]") if DEBUG;
    return $path;
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
        $path = join_uri($prefix, $path);
        $self->debug("appended '$self->{uri_prefix}' prefix $uri => $path") if DEBUG;
    }

    return $path;
}

sub file_uri {
    my ($self, $file) = @_;
    my $path = $file->absolute;
    my $base = $self->{ uri_prefix };

}


1;
