package Contentity::Plack::Builder;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Plack::Base Badger::Prototype',
    accessors => 'middlewares',
    constants => 'CODE';


sub init {
    my ($self, $config) = @_;
    @$self{ keys %$config } = values %$config;
    $self->{ middlewares } = [ ];
    $self->init_builder($config);
    return $self;
}

sub init_builder {
    # stub for subclasses
}

sub build {
    shift->not_implemented('in base class');
}

sub add_middleware {
    my ($self, $mw, @args) = @_;

    if (ref $mw ne CODE) {
        my $module = $self->middleware(@_)
            || return $self->error_msg( invalid => middleware => $_[0] );
        $mw = sub { $module->wrap( $_[0], @args ) };
    }

    push @{ $self->{ middlewares } }, $mw;
}

sub wrap {
    my ($self, $app) = @_;

    for my $mw (reverse @{ $self->{ middlewares } }) {
        $app = $mw->($app);
    }

    return $app;
}

1;

__END__

=head1 NAME

Contentity::Plack::Builder - Contentity base class for Plack application builders

=head1 DESCRIPTION

This module is a base class for all Plack application builders used 
in the Contentity system.  

=head1 METHODS

This module inherits all methods from the L<Contentity::Base> base class.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut

