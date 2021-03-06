package Contentity::Plack::Builder::Site;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Plack::Builder',
    utils     => 'self_params',
    accessors => 'site';


sub init_builder {
    my ($self, $config) = @_;

    return $self->error_msg( missing => 'site' )
        unless $config->{ site };
}


sub build {
    my $self = shift;
    my $site = $self->site;

    # TODO: $app = ???
    $self->debug("site builder is building") if DEBUG;

    my $index = sub {
        my $env = shift;
        return [
            200, 
            [ 'Content-Type' => 'text/plain' ],
            [ "Yah, hello world" ],
        ];
    };

    return $self->resources_app($index);
}


sub resources_app {
    my $self = shift;
    my $app  = shift;
    $self->middleware( 
        resources => {
            site => $self->site,
        }
    )->wrap($app);
}


1;

__END__

=head1 NAME

Contentity::Plack::Builder::Site - Plack application builder for web sites

=head1 DESCRIPTION

This module implements an application builder for web sites for using under
the Plack web environment.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut

