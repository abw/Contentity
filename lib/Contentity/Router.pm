package Contentity::Router;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    constants   => 'ARRAY',
    accessors   => 'routes',
    messages => {
        invalid_route    => 'Invalid route specified: %s',
        invalid_fragment => 'Invalid fragment "%s" in route: %s',
    };

#------------------------------------------------------------------------
# Initialisation methods
#------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_routes($config);
    return $self;
}

sub init_routes {
    my ($self, $config) = @_;
    $self->{ routes } = $self->new_route_set;
    $self->add_routes($config->{ routes })
        if $config->{ routes };
    return $self;
}

#------------------------------------------------------------------------
# Methods for adding routes
#------------------------------------------------------------------------

sub add_routes {
    my ($self, @routes) = @_;

    while (@routes) {
        my $route = shift @routes;

        if (ref $route eq ARRAY) {
            unshift(@routes, @$route);
            next;
        }

        return $self->error_msg( no_route_to => $route )
            unless @_;

        $self->add_route(
            $route,
            shift @routes
        );
    }
}

sub add_route {
    my ($self, $route, $to) = @_;
    my $routes     = $self->{ routes };
    my ($fragment) = ($route =~ s/\#(.*)$//) ? $1 : '';
    my ($params)   = ($route =~ s/\?(.*)$//) ? $1 : '';
    my @parts      = grep { defined && length } split(qr{/}, $route);

    $self->debug(
        "adding route: $route => ", 
        $self->dump_data_inline(\@parts),
        " [$params] [$fragment] => $to"
    );

    $self->add_route_to_set($route, $to, $routes, \@parts);
}

sub add_route_to_set {
    my ($self, $route, $to, $set, $parts) = @_;
    my ($subset, $matcher);

    my $first = shift @$parts
        || return $self->error_msg( invalid_route => $route );

    if ($self->part_is_fixed($first)) {
        $subset = $set->{ fixed }->{ $first } ||= $self->new_route_set;
        if (@$parts) {
            $self->add_route_to_set($route, $to, $subset, $parts);
        }
        else {
            $subset->{ default } = $to;
        }
    }
    else {
        $matcher = $self->part_matcher($first, $route);
        $subset  = $self->new_route_set;
        $subset->{ default } = $to;
        push(@{ $set->{ match } }, [$first, $subset]);
    }
}

sub part_is_fixed {
    my ($self, $part) = @_;
    return $part =~ /^\w+$/;
}

sub part_matcher {
    my ($self, $part, $route) = @_;

    if ($part =~ s/^:(\w+)//) {
        $self->debug("matched placeholder: $1 | $part");
    }
    elsif ($part eq '*') {
        $self->debug("matched wildcard: $part");
    }
    else {
        return $self->error_msg( invalid_fragment => 'route fragment' => $part, $route );
    }
}


sub new_route_set {
    return {
        fixed => { },
        match => [ ],
    };
}

1;