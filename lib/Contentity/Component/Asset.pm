package Contentity::Component::Asset;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'assets',
    utils     => 'extend params plural',
    constant  => {
        ASSET           => undef,
        ASSETS          => undef,
        CACHE_INSTANCES => 0,
    };


sub init_component {
    # For the sake of easier subclassing
    shift->init_asset(@_);
}

sub init_asset {
    my ($self, $config) = @_;

    my $asset = $config->{ asset } 
        || $self->ASSET
        || return $self->error_msg( missing => 'asset' );

    my $assets = $config->{ assets } 
        || $self->ASSETS
        || plural($asset);

    $self->debug_data(
        "Asset component [singular:$asset] [plural:$assets]", $config
    ) if DEBUG;

    $self->{ asset           } = $asset;
    $self->{ assets          } = $assets;
    $self->{ cache_instances } = $config->{ cache_instances } 
                             //= $self->CACHE_INSTANCES;

    return $self;
}


#-----------------------------------------------------------------------------
# asset($name) is the public-facing API method
# lookup_asset($name) is the cache-aware method
# fetch_asset($name) always fetches the asset
#-----------------------------------------------------------------------------

sub asset {
    my $self = shift;

    return @_
        ? $self->lookup_asset(@_)
        : $self->{ asset };
}

sub lookup_asset {
    my $self = shift;

    # Cache-aware asset fetcher

    if ($self->{ cache_instances }) {
        my $name  = shift;
        my $cache = $self->{ instance_cache } ||= { };
        return  $cache->{ $name } 
            ||= $self->fetch_asset($name, @_);
    }

    return $self->fetch_asset(@_);
}


sub fetch_asset {
    my $self   = shift;
    my $name   = shift;
    my $config = extend(
        { 
            urn => $name,
        #   uri => $self->uri( $self->{ assets }, $name ),
        },
        $self->asset_config($name), 
        @_
    );

    $self->debug_data(
        "$self->{ asset } asset $name: ", $config
    ) if DEBUG;

    return $self->prepare_asset($config);
}

sub asset_config {
    my ($self, $name) = @_;

    return $self->workspace->asset_config(
        $self->{ assets } => $name
    );
}

sub prepare_asset {
    my ($self, $data) = @_;
    # stub method for subclasses to re-implement
    return $data;
}

# TODO: methods to fetch index, all assets, etc.

1;

