package Contentity::Web::Handler::Apache2;

use Cog::Class
    version   => 0.5,
    debug     => 1,
    base      => 'Contentity::Web::Handler Plack::Handler::Apache2',
    accessors => 'apache';


#-----------------------------------------------------------------------------
# Handler hook method
#-----------------------------------------------------------------------------

sub handler : method {
    my ($class, $apache) = @_;
    my $self = bless { apache => $apache }, $class;
    return $self->handle;
}

sub handle_app {
    my ($self, $app) = @_;
    $self->call_app($self->apache, $app);
}


#-----------------------------------------------------------------------------
# Methods to fetch configuration values from Apache directory/location config
#-----------------------------------------------------------------------------

sub config {
    my ($self, $item) = @_;
    return $self->apache->dir_config($item)
        || $self->SUPER::config($item);
}


1;

__END__
