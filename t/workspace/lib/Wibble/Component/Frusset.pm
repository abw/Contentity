package Wibble::Component::Frusset;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    accessors   => 'greeting',
    base        => 'Contentity::Component';

sub init_component {
    my ($self, $config) = @_;

    $self->debug("You have pleasantly wibbled my frusset pouch") if DEBUG;

    if (my $greet = $config->{ greeting }) {
        $self->{ greeting } = $greet;
        $self->debug("I $greet you") if DEBUG;
    }

    return $self;
}

1;

