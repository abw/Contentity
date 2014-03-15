package Contentity::Plack::App::File;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Plack::App::File Contentity::Base';

sub NOT_return_404 {
    my $self = shift;
    $self->debug("returning 404 as undef");
    return undef;
}


1;
