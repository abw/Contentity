package Contentity::Component::Page;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Contentity::Component::Sitemap::Component',
    utils   => 'resolve_uri';

sub uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ data }->{ uri }, @_)
        : $self->{ data }->{ uri };
}


1;

