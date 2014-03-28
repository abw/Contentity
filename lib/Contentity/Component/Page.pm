package Contentity::Component::Page;

use Contentity::Class
    version => 0.01,
    debug   => 1,
    base    => 'Contentity::Component::Flyweight',
    utils   => 'resolve_uri is_object';



sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ data }->{ uri }, @_)
        : $self->{ data }->{ uri };
}

sub title {
    my $self = shift;
    return $self->{ data }->{ title }
      //   $self->{ data }->{ name  };
}

sub trail {
    my $self = shift;
    return [
        { name => 'trail test' }
    ];
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
  # this doesn't work very well.
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
