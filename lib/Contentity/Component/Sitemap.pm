package Contentity::Component::Sitemap;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    utils       => 'params truelike',
    constants   => 'ARRAY',
    constant    => {
        PAGES   => 'pages',
        MENUS   => 'menus',
    };


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data("sitemap config", $config) if DEBUG;
    return $self;
}


#-----------------------------------------------------------------------------
# Methods for loading site and page metadata from project config directory
#-----------------------------------------------------------------------------

sub pages {
    my $self = shift;
    return  $self->{ pages }
        ||= $self->load_pages;
}

sub load_pages {
    my $self  = shift;
    my $pages = $self->workspace->config(PAGES);
    $self->debug_data( pages => $pages) if DEBUG;
    return $pages;
}

sub page {
    my $self   = shift;
    my $uri    = shift || return $self->error_msg( missing => 'page uri' );
    my $params = params(@_);
    my $strict = truelike $params->{ strict };
    my @paths  = $self->uri_walk_up($uri);
    my ($path, $page, $parent, @parents);

    $self->debug_data("page paths for $uri", \@paths) if DEBUG;

    # look for the longest parent URL of this page
    while (@paths) {
        $path = shift @paths;

        if ($page = $self->page_metadata($path)) {
            $self->debug_data("found page for $uri: $path", $page) if DEBUG;
            last;
        }
        elsif ($strict) {
            last;
        }
    }

    return $self->error_msg( invalid => page => $uri )
        unless $page;

    # fetch any and all parent pages
    while (@paths) {
        $path = shift @paths;
        if ($parent = $self->page_metadata($path)) {
            push(@parents, $parent);
        }
    }

    # merge data allowing page to inherit certain items
    $self->debug(
        "page inherits from ",
        scalar(@parents), " parents"
    ) if DEBUG;

    my $data = $self->merge_page_metadata(
        $page, @parents
    );

    $data->{ uri }   = $uri;
    $data->{ url } ||= $uri;

    $self->debug_data("merged page data for $uri", $data) if DEBUG;

    return $self->workspace->component(
        page => {
            data => $data,
        }
    );
}

sub page_metadata {
    my $self  = shift;
    my $uri   = shift || return $self->error_msg( missing => 'uri' );
    my $page  = $self->pages->{ $uri };

    $self->debug_data("page $uri", $page) if DEBUG;

    if ($page) {
        $page->{ uri } ||= $uri;
    }

    return $page
        || $self->decline_msg( invalid => page => $uri );
}


sub merge_page_metadata {
    my ($self, $page, @pages) = @_;
    return $page unless @pages;

    my $parents = $self->merge_page_metadata(@pages);
    my $inherit = $self->config->{ inherit };

    $self->debug(
        "sitemap inherits: ",
        $self->dump_data($inherit)
    ) if DEBUG;

    foreach my $i (@$inherit) {
        $self->debug("INHERIT $i <= $parents->{ $i }")
            if   DEBUG
            &&   $parents->{ $i }
            && ! $page->{ $i };

        $page->{ $i } //= $parents->{ $i }
            if defined $parents->{ $i };
    }

    return $page;
}


#-----------------------------------------------------------------------------
# Menus
#-----------------------------------------------------------------------------

sub menus {
    my $self = shift;
    return  $self->{ menus }
        ||= $self->load_menus;
}

sub load_menus {
    my $self  = shift;
    my $menus = $self->workspace->config(MENUS) || return;
    $self->debug_data( menus => $menus ) if DEBUG;
    return $menus;
}

sub menu {
    my ($self, $name, $uris) = @_;

    # if $uris isn't specified then $name must be the name of a menu
    # defined in the menus.yaml or menus/*.yaml metadata tree
    $uris
        ||= $self->menus->{ $name }
        ||  return $self->error_msg( invalid => "menu" => $name );

    # if $uris is specified as a word then it must be a menu defined as above
    $uris = $self->menus->{ $uris }
        ||  return $self->error_msg( invalid => "$name menu" => $uris )
            unless ref $uris eq ARRAY;

    return $self->menu_pages( $name => $uris );
}

sub menu_pages {
    my ($self, $name, $uris) = @_;
    return $self->try->fetch_pages($uris)
        || $self->error_msg( invalid => "menu '$name'" => $self->reason );
}


#-----------------------------------------------------------------------------
# URIs and URLs
#-----------------------------------------------------------------------------

sub uri_walk_up {
    my $self  = shift;
    my $uri   = shift || return $self->error_msg( missing => 'uri' );
    my $path  = $uri;
    my @paths;

    $path = '/' . $uri
        unless $path =~ m{^/};

    while (length $path) {
        push(@paths, $path);

        # Remove a filename extension (e.g. /foo.html -> /foo),
        # a trailing slash (e.g. /foo/ -> /foo) or a trailing word
        # (e.g. /foo/bar -> /foo/). Keep doing it until there's
        # nothing left to take away
        last unless (
                $path =~ s{ \.\w+ $ }{}x
            ||  $path =~ s{ (?<=.)/ $ }{}x
            ||  $path =~ s{ [\w\-]+ $ }{}x
        )   &&  length $path;
    }

    return wantarray
        ?  @paths
        : \@paths;
}

sub fetch_pages {
    my ($self, $uris) = @_;
    $self->debug_data( fetch_pages => $uris ) if DEBUG;
    return [
        map { $self->page($_) }
        @$uris
    ];
}


1;

__END__

# merging from Cog::Wegb::Site


sub lookup_page {
    shift->page(shift, 0);
}
