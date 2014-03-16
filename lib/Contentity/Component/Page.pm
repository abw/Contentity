package Contentity::Component::Page;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Contentity::Component::Flyweight',
    utils   => 'resolve_uri';

sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ config }->{ uri }, @_)
        : $self->{ config }->{ uri };
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

