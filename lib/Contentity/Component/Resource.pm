package Contentity::Component::Resource;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'resources',
    utils     => 'extend params plural',
    constant  => {
        RESOURCE  => undef,
        RESOURCES => undef,
    };


sub init_component {
    # For the sake of easier subclassing
    shift->init_resource(@_);
}

sub init_resource {
    my ($self, $config) = @_;

    my $resource = $config->{ resource  } 
        || $self->RESOURCE
        || return $self->error_msg( missing => 'resource' );

    my $resources = $config->{ resources } 
        || $self->RESOURCES
        || plural($resource);

    $self->debug(
        "Entities component init_resource() [$resource] [$resources]"
    ) if DEBUG;

    $self->{ resource        } = $resource;
    $self->{ resources       } = $resources;
    $self->{ cache_instances } = $config->{ cache_instances };

    return $self;
}


#-----------------------------------------------------------------------------
# resource($name) is the public-facing API method
# lookup_resource($name) is the cache-aware method
# fetch_resource($name) always fetches the resource
#-----------------------------------------------------------------------------

sub resource {
    my $self = shift;

    return @_
        ? $self->lookup_resource(@_)
        : $self->{ resource };
}

sub lookup_resource {
    my $self = shift;

    # Cache-aware resource fetcher

    if ($self->{ cache_instances }) {
        my $name  = shift;
        my $cache = $self->{ instance_cache } ||= { };
        return  $cache->{ $name } 
            ||= $self->fetch_resource($name, @_);
    }

    return $self->fetch_resource(@_);
}


sub fetch_resource {
    my $self   = shift;
    my $name   = shift;
    my $data   = $self->resource_data($name);
    my $params = extend(
        { 
            urn => $name,
            uri => $self->uri( $self->{ resources }, $name ),
        },
        $data, 
        @_
    );

    $self->debug(
        "loaded resource data: ", $self->dump_data($params)
    ) if DEBUG;

    return $self->return_resource($params);
}

sub resource_data {
    my ($self, $name) = @_;

    return $self->project->resource_data(
        $self->{ resources } => $name
    );
}

sub return_resource {
    my ($self, $data) = @_;
    # stub method for subclasses to re-implement
    return $data;
}

1;

