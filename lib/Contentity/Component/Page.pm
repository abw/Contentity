package Contentity::Component::Page;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component::Flyweight',
    utils     => 'resolve_uri is_object',
    constants => 'SLASH BLANK',
    messages  => {
        bad_trail => "Unabled to fetch breadcrumb trail metadata: %s",
    };



sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ data }->{ uri }, @_)
        : $self->{ data }->{ uri };
}

sub filename {
    my $self = shift;
    return (split(SLASH, $self->uri))[-1];
}

sub title {
    my $self = shift;
    return $self->{ data }->{ title }
      //   $self->{ data }->{ name  };
}

sub sitemap {
    shift->workspace->sitemap;
}

sub menu {
    my $self = shift;
    my $name = shift || 'menu';

    # Append _menu suffix unless it already has one, e.g.
    #   menu    => menu
    #   my_menu => my_menu
    #   main    => main_menu,
    #   section => section_menu
    $name .= '_menu' unless $name =~ /menu$/;

    # Now lookup the name (or definition) in the page metadata, e.g.
    #   menu:           style_guide     # => menus.style_guide
    #   section_menu:   widgets         # => menus.widgets
    my $menu = $self->get($name)
        || return $self->error_msg( invalid => menu => "$name" );

    return $self->sitemap->menu($menu);
}

sub under {
    # this doesn't work very well due to the vagarities of how page URIs
    # can be specified: e.g. / vs /index vs /index.html
    my ($self, $path) = @_;
    my $result;

    return 0 unless $path;
    $path = $path->uri if is_object(ref $self, $path);

    my $uri = $self->uri;

    $self->debug("Is $uri under $path?") if DEBUG;

    if ($uri eq $path) {
        $self->debug("Exact match!") if DEBUG;
        # exact match
        return 1;
    }
    elsif (defined ($result = $self->{ data }->{ under }->{ $path })) {
        $self->debugf("explicit rule says page %s under $path", $result ? 'is under' : 'is NOT under') if DEBUG;
        # explicit rule in the sitemap
        return $result;
    }
    #elsif ($path =~ s/\/index\.html$//) {
    #    $self->debug("special case for index.html => $path vs $uri") if DEBUG;
    #    # special case to match /foo under /foo/index.html
    #    return $uri eq $path;
    #}
    else {
        # Otherwise make sure we add a '/' to the end of the uri so that we only
        # match at directory boundaries.  So a page at /food/berries, for example,
        # should match under /food (/food/) but not /foo (/foo/)
        $path .= '/' unless $path =~ m{/$};
        $self->debug("MATCHING $uri against qr[^$path]") if DEBUG;
        return $uri =~ /^$path/;
    }
}


# fetch all the pages on the breadcrumb trail from root to the current page

sub trail {
    my $self  = shift;
    delete $self->{ trail } if @_;
    return $self->{ trail }
        ||= $self->make_trail(@_);
}

sub make_trail {
    my $self = shift;
    my $uri  = $self->uri;

    $uri =~ s[^/][];
    $uri =~ s[\/index.html][];

    my @path  = split(/\/+/, $uri);
    my @trail = map {
        SLASH
      . join(SLASH, @path[0..$_])
      . ($path[$_] =~ /\.\w+$/ ? BLANK : SLASH)
    } 0..$#path;

    $self->debug("TRAIL: ", join(', ', @trail), "\n") if DEBUG;

    my $sitemap = $self->sitemap;
    my $pages   = $sitemap->try->fetch_pages(\@trail)
        || return $self->error_msg( bad_trail => $sitemap->reason );

    return [
        # TODO: move this into sitemap and/or candidate pages
        grep { ! $_->{ data }->{ skip_trail } }
        @$pages
    ];
}



1;

__END__

==
sub trail {}
    delete $self->{ trail } if @_;
    return $self->{ trail } ||= do {
        my $uri   = $self->{ uri };
        $uri =~ s[^/][];
        $uri =~ s[\/index.html][];
        my @path  = split(/\/+/, $uri);
        my @trail = map { '/' . join('/', @path[0..$_]) } 0..$#path;
#        $self->debug("TRAIL: ", join(', ', @trail), "\n");
        # we don't throw errors by default because there could be pages missing
        # in the trail (e.g. /foo/bar/baz but no /foo/bar).  However, we forward
        # any arguments passed, so the caller can add { throw => 1 } if they like.
        my $pages = $self->{ site }->pages(@trail, @_);
        [
            grep { ! $_->{ page }->{ skip_trail } }
            @$pages
        ];
    };
}


1;
