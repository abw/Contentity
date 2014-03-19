package Contentity::Hub;

use Badger;
die "Contentity::Hub requires Badger v0.091 or later"
    if $Badger::VERSION < 0.091;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Hub Contentity::Base',
    utils     => 'blessed params plural',
    accessors => 'project',              # WARNING: this will break project component loading
    constants => 'HASH',
    constant  => {
        SITE => 'Contentity::Site',
    };


our $CONFIG     = 'Contentity::Config';
our $COMPONENTS = {
    project     => 'Contentity::Project',
    middlewares => 'Contentity::Plack::Middlewares',
};



#-----------------------------------------------------------------------------
# Configuration fallback to project
#-----------------------------------------------------------------------------

sub no_config {
    my $self   = shift->prototype;
    my $name   = shift;
    my $params = shift;
    my $config;

    # avoid an infinite loop to fetch project config from the project
    return if $name eq 'project';

    # see if there's a project we can ask for configuration data
    my $project = $self->project;

    if ($project) {
        $config = $project->config($name);
    }

    if ($config) {
        return {
            %$config,
            %{$params||{}}
        };
    }

    return $self->SUPER::no_config($name, $params);
}


#-----------------------------------------------------------------------------
# Create sub-projects
#-----------------------------------------------------------------------------

sub subspace {
    my $self   = shift->prototype;
    my $type   = shift || return $self->error_msg( missing => 'subspace type' );
    my $name   = shift || return $self->error_msg( missing => "$type name" );
    my $params = shift || { };
    my $plural = $params->{ plural } || plural($type);
    my $uri    = "$type:$name";
    my $guard  = $self->{ subspace_guard } ||= { };

    # short-circuit for the case where we get passed an object
    return $name 
        if ref $name;

    # detect circular dependencies
    return $self->error("Circular dependency on $uri")
        if $guard->{ $uri };

    $self->debug("[$$] hub asked for $type: $name\n") if DEBUG;
    
    return $self->{ subspace }->{ $type }->{ $name } ||= do {
        $self->debug("[$$] hub creating new $type: $name\n") if DEBUG;
        my $project = $self->project;
        my $config  = $project->config("$plural.$name");
        my $base    = $config->{ base };
        $config->{ dir    }   = $project->dir($config->{ dir } || $name);
        $config->{ urn    } ||= $name;
        $config->{ module } ||= $params->{ module };
        local $guard->{ $uri } = 1;

        if ($base) {
            $config->{ base } = $self->subspace($type, $base);
        }
        else {
            $config->{ base } = $project;
        }

        $self->construct( 
            $name => $config
        );
    };
}

sub site {
    my ($self, $name) = @_;
    return $self->subspace(
        site => $name => {
            module => $self->SITE
        }
    );
}


1;
