package Contentity::Component::Asset;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'assets singletons',
    utils     => 'extend params plural is_object',
    constant  => {
        ASSET      => undef,
        ASSETS     => undef,
        SINGLETONS => 0,
        COMPONENT  => 'Contentity::Component',
    };


sub init_component {
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

    $self->{ asset      } = $asset;
    $self->{ assets     } = $assets;
    $self->{ instances  } = { };
    $self->{ singletons } = $config->{ singletons }
                        //= $self->SINGLETONS;

    return $self->init_asset($config);
}


sub init_asset {
    # For the sake of easier subclassing
    return $_[0];
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
    my $self  = shift;
    my $name  = shift;
    my $cache = $self->{ instances };
    my $asset = $cache->{ $name };

    # Yay!  We found a cached instance
    return $asset if $asset;

    # Otherwise go and fetch it anew
    $asset = $self->fetch_asset($name, @_)
        || return;

    # Maybe store this instance in the cache?
    $cache->{ $name } = $asset
        if $self->cache_asset($name, $asset);

    return $asset;
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
        "$self->{ asset } asset $name", $config
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

sub cache_asset {
    my ($self, $name, $asset) = @_;
    my $single = $asset->singleton
        if is_object(COMPONENT, $asset);

    # Each component can be declared as a singleton via a scheme definition,
    # or configuration option.
    if (defined $single) {
        $self->debug(
            "$name asset declared itself as ",
            $single ? "being" : "not being",
            " a singleton"
        ) if DEBUG;
        return $single;
    }

    # Default behaviour is to depend on singletons config option, subclasses
    # may modify this to test each asset to determine if it should be cached
    $self->debug(
        "using default singletons rule for $name which says they ",
        $self->singletons ? "are" : "are not",
        " singletons"
    ) if DEBUG;

    return $self->singletons;
}


# TODO: methods to fetch index, all assets, etc.

1;
