package Contentity::Component::Forms;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    component => 'asset',
    asset     => 'form',
    utils     => 'extend',
    constant  => {
        SINGLETONS => 0,
    };

sub prepare_asset {
    my ($self, $data) = @_;
    $self->debug_data( form => $data ) if DEBUG;
    return $self->workspace->component( form => $data );
}

sub asset_config {
    my ($self, $name) = @_;

    # we must have a XXX.yaml file defined for a form
    my $config = $self->workspace->asset_config( $self->{ assets } => $name )
        || return $self->error_msg( invalid => form => $name );

    $self->debug_data( "$name form config" => $config ) if DEBUG;

    return extend(
        { },
        $config,
    );
}

1;
