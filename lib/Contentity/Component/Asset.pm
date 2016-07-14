package Contentity::Component::Asset;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'assets singletons',
    utils     => 'extend params plural is_object truelike',
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
    my $cache_flag = $self->cache_asset($name, $asset);
    if ($cache_flag) {
        $cache->{ $name } = $asset;
        $self->debug("caching assest (flag: $cache_flag)") if DEBUG;
    }
    else {
        $self->debug("Not caching asset (flag: $cache_flag)") if DEBUG;
    }
    return $asset;
}


sub fetch_asset {
    my $self   = shift;
    my $name   = shift;
    my $config = $self->asset_config($name, @_);

    $self->debug_data(
        "$self->{ asset } asset $name", $config
    ) if DEBUG;

    return $self->prepare_asset($config);
}

sub asset_config {
    my ($self, $name, @args) = @_;
    if (DEBUG) {
        my $data = $self->workspace->asset_config(
            $self->{ assets } => $name
        );
        $self->debug_data("[$self->{ assets }] => $name", $data);
        $self->debug_data( args => \@args );
    }

    return extend(
        { urn => $name },
        $self->{ config }->{ $name },
        $self->workspace->asset_config(
            $self->{ assets } => $name
        ),
        @args
    );
}

sub prepare_asset {
    my ($self, $data) = @_;
    # stub method for subclasses to re-implement
    return $data;
}

sub cache_asset {
    my ($self, $name, $asset) = @_;
    my $single = truelike($asset->singleton)
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
    my $singles = truelike $self->singletons;
    $self->debug(
        "using default singletons rule for $name which says they ",
        $singles ? "are" : "are not",
        " singletons"
    ) if DEBUG;

    return $singles;
}


# TODO: methods to fetch index, all assets, etc.

1;
