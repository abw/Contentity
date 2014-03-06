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


1;

