package Contentity::Plack::Handler::File;

#use Carp 'confess';
#confess __PACKAGE__, " is deprecated";

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Plack::App::File Contentity::Plack::Base';

sub NOT_return_404 {
    my $self = shift;
    $self->debug("returning 404 as undef") if DEBUG;
    return undef;
}


1;
