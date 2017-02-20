package Contentity::Router;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    constants => 'ARRAY HASH SLASH',
    accessors => 'routes midpoint endpoint',
    utils     => 'Path join_uri extend',
    constant  => {
        IMPLICIT_STAR => 0,              # TODO: make this configurable
        MATCH_MINUS   => qr/^(\-)$/,
        MATCH_PLUS    => qr/^(\+)$/,
        MATCH_STAR    => qr/^(\*)$/,
        MATCH_STATIC  => qr/^([\w\-\.]+)$/,
        MATCH_PLACE   => qr/^(:\w+)$/,
        MATCH_ANGLE   => qr/^<(.*)>$/,
        MATCH_PREFIX  => qr/^([\w\-\.]+):(.*)$/,
    },
    messages => {
        invalid_route    => 'Invalid route specified: %s',
        invalid_fragment => 'Invalid fragment "%s" in route: %s',
        not_last         => 'Intermix operator "%s" must be the last item in the route: %s',
    };

our $TYPES = {
    int    => \&matcher_int,
    word   => \&matcher_word,
    text   => \&matcher_text,
    path   => \&matcher_path,
    prefix => \&matcher_prefix,
};
our $DEFAULT_TYPE = 'text';
our $INDENT_WIDTH = 2;


#------------------------------------------------------------------------
# Initialisation methods
#------------------------------------------------------------------------

sub init {
    shift->init_router(@_);
}

sub init_router {
    my ($self, $config) = @_;

    $self->debugf(
        "init_router(%s)",
        $self->dump_data($config)
    ) if DEBUG;

    # Routes are split into individual slash-delimited components:
    #   /user/list      => user, list
    #   /user/add       => user, add
    #   /user/:id/info  => user, :id, info
    #   /user/:id/edit  => user, :id, edit
    #
    # A tree is constructed:
    #   user
    #     - list
    #     - add
    #     - :id
    #         - info
    #         - ban
    #
    # A router is built for each branch node of the tree (user and :id in
    # the above example).  Each route set can contain a mixture of static and
    # dynamic components.
    #
    # Static routes are fixed text components, e.g. user, list, add, info, ban.
    # We can match those via a simple hash array lookup table (static).
    #
    # Dynamic route components like ':id' are stored in a list (dynamic) and
    # matched in sequence.
    #
    # We also maintain an index of dynamic components so that we can reuse the
    # same intermediate dynamic component for different routes, e.g. the ':id'
    # matching component in both /user/:id/info and /user/:id/edit
    $self->{ static   } = { };
    $self->{ dynamic  } = [ ];
    $self->{ matchers } = { };
    $self->{ implicit } = $config->{ implicit_star } // $self->IMPLICIT_STAR;

    $self->add_routes($config->{ routes })
        if $config->{ routes };

    return $self;
}

sub new_route_set {
    shift->new(@_);
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
        if (ref $route eq HASH) {
            # The problem with hash arrays is that they're unordered.
            # We allow a route to be prefixed with digits and whitespace
            # for the purposes of ordering, e.g. "01 /route/one".  This
            # prefix is removed at the point of the route being added back
            # into the queue.  Note that this *ONLY* applies to entries in
            # hash arrays.
            unshift(
                @routes,
                map {
                    $_->[1], $_->[2]
                }
                sort {
                    $a->[0] cmp $b->[0]
                }
                map  {
                    my $key  = $_;
                    my $val  = $route->{ $key };
                    my $sort = $key;
                    $val->{_route_} = $key;
                    $key =~ s/^(\d+)\s+//g;
                    [$sort, $key, $val]
                }
                keys %$route
            );
            #return $self->error_msg( invalid => route => $route );
            next;
        }

        return $self->error_msg( no_route_to => $route )
            unless @_;

        # each route is a pair of ($route => $endpoint)
        $self->add_route(
            $route,
            shift @routes
        );
    }
}

sub add_route {
    my ($self, $route, $endpoint) = @_;
    my ($fragment) = ($route =~ s/\#(.*)$//) ? $1 : '';
    my ($params)   = ($route =~ s/\?(.*)$//) ? $1 : '';

    $self->add_route_parts(
        $route,
        [
            grep { defined && length }
            split(qr{/}, $route)
        ],
        $endpoint,
    );
}

sub add_route_parts {
    my ($self, $route, $parts, $endpoint) = @_;
    my $routes = $self->{ routes };
    my ($subset, $matcher, $match, $type, $name, @parts);

    $self->debug(
        "add_route_parts($route, ",
        $self->dump_data_inline($parts),
        ") =>  ",
        $self->dump_data_inline($endpoint),
    ) if DEBUG;

    my $head = shift @$parts
        || return $self->error_msg( invalid_route => $route );

    $self->debug("Route [$route] building matcher for [$head]") if DEBUG;

    if ($head =~ MATCH_MINUS) {
        $self->debug("dynamic minus: $1 in $head") if DEBUG;

        # A final element of '-' is an explicit way to set some endpoint data
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint);
    }
    elsif ($head =~ MATCH_PLUS) {
        $self->debug("dynamic plus: $1 in $head") if DEBUG;

        # A final element of '+' is a midpoint, applying to all paths that
        # have further items following
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint);
    }
    elsif ($head =~ MATCH_STAR) {
        $self->debug("dynamic star: $1 in $head") if DEBUG;

        # A final element of '*' is both a midpoint and an endpoint, applying
        # to both URLs with and without further path elements
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint)
                   ->add_endpoint($endpoint);
    }
    elsif ($head =~ MATCH_STATIC) {
        # A static route element
        $self->debug("dynamic static route part: $1 in $head") if DEBUG;

        return $self->add_static_route(
            $route,
            $1, $parts,
            $endpoint
        );
    }
    elsif ($head =~ MATCH_PLACE) {
        # A standard :name placeholder
        $self->debug("dynamic placeholder: $1 in $head") if DEBUG;

        return $self->add_dynamic_route(
            $route,
            $1, $parts,
            $endpoint
        );
    }
    elsif ($head =~ MATCH_ANGLE) {
        # An extended <type:name> placeholder
        $self->debug("dynamic angled placeholder: $1 | $head") if DEBUG;

        return $self->add_dynamic_route(
            $route,
            $1, $parts,
            $endpoint
        );
    }
    elsif ($head =~ MATCH_PREFIX) {
        # Additional hackage to support a :something placeholder with a
        # prefix, e.g. shops-to-let-in-:town
        $self->debug("prefixed placeholder: $1 | $2 | $head") if DEBUG;

        return $self->add_dynamic_route(
            $route,
            $2, $parts,
            $endpoint,
            $1         # NEW - prefix
        );
    }

    return $self->error_msg( invalid_fragment => $head, $route );
}

sub add_static_route {
    my ($self, $route, $head, $tail, $endpoint) = @_;
    my $subset = $self->{ static }->{ $head } ||= $self->new_route_set;

    if (@$tail) {
        $self->debug("adding static intermediary for [$head]") if DEBUG;
        return $subset->add_route_parts($route, $tail, $endpoint);
    }
    else {
        if ($self->{ implicit }) {
            # Assumes that /user is the same thing as /user/*
            $self->debug("adding implicit * on $route => $route/*") if DEBUG;
            $subset->add_midpoint($endpoint);
        }
        $self->debug("adding static endpoint for [$head]") if DEBUG;
        return $subset->add_endpoint($endpoint);
    }
}

sub add_dynamic_route {
    my ($self, $route, $head, $tail, $endpoint, $prefix) = @_;

    # $head can be 'foo' or ':foo', both of which are implicitly text types
    # 'text:foo', or an explicitly typed route part, e.g. int:foo
    my @parts = split(':', $head, 2);
    my ($type, $name) = @parts == 2 ? @parts : (text => @parts);
    $type ||= $DEFAULT_TYPE;

    # NEW: type is hard set to 'prefix' if there is a prefix to match
    $type = 'prefix' if $prefix;

    # The $type must have a basic matcher function defined in $TYPES
    my $matcher = $TYPES->{ $type }
        || return $self->error_msg( invalid => type => $type );

    # We want to share intermediate component.  For example, with two routes
    # /user/:id/info and /user/:id/edit we want to use the same dynamic rule
    # matching component for the middle :id part.  We create a canonical
    # type:name identifier for it to accommodate differences in syntax, e.g.
    # /user/:id/info, /user/text:id/edit and /user/<text:id>/ban will all use
    # the same intermediate text:id component.
    my $pfxid   = $prefix || '-';
    my $canon   = "$pfxid:$type:$name";
    my $subset  = $self->{ matchers }->{ $canon };

    $self->debug_data( canon => $canon ) if DEBUG;

    # escape any regex metacharacters in prefix string so we can
    # embed it directly into a larger regex
    $prefix = quotemeta $prefix
        if defined $prefix && length $prefix;

    # We don't already have a route set for this component so create one
    if (! $subset) {
        $self->debug("creating new subset router for [$prefix][$head]") if DEBUG;
        $subset = $self->{ matchers }->{ $canon } = $self->new_route_set;
        push(
            @{ $self->{ dynamic } },
            [ $type, $name, $matcher, $subset, $prefix ]
        );
    }

    # If there's any more of the route left to resolve then hand it over
    # to the new nested routeset for further processing.  Otherwise we set
    # the endpoint data in the current route set and return.
    if (@$tail) {
        $self->debug("adding dynamic intermediary for [$head]") if DEBUG;
        return $subset->add_route_parts($route, $tail, $endpoint);
    }
    else {
        $self->debug("adding dynamic endpoint for [$head]") if DEBUG;
        return $subset->add_endpoint($endpoint);
    }
}


sub add_endpoint {
    my ($self, $endpoint) = @_;
    my $current = $self->{ endpoint };

    if ($current) {
        @$current{ keys %$endpoint } = values %$endpoint;
    }
    else {
        $self->{ endpoint } = $endpoint;
    }

    return $self;
}

sub add_midpoint {
    my ($self, $midpoint) = @_;
    my $current = $self->{ midpoint };

    if ($current) {
        @$current{ keys %$midpoint } = values %$midpoint;
    }
    else {
        $self->{ midpoint } = $midpoint;
    }

    return $self;
}

sub point_data {
    my $self = shift;
    return extend({ }, $self->midpoint, $self->endpoint, @_);
}


#-----------------------------------------------------------------------------
# matcher
#-----------------------------------------------------------------------------

sub match {
    my $self = shift;
    my $path = Path(@_);
    my $todo = $path->todo;
    my $data = { };
    my (@matched, $part, $route, $type, $name, $dynamic, $matcher, $subset, $prefix);

    $self->debug(
        "matching path: $path => ",
        $self->dump_data_inline(\@$todo)
    ) if DEBUG;

    # $path may be empty, e.g. for the / URL but we still want to match
    # endpoint data defined as /* or /-
    # The continue { } block doesn't get trigged if @parts is empty so we
    # special-case it by copying any endpoint data into $params
    if (! $path->more && $self->{ endpoint }) {
        extend($data, $self->{ endpoint })
    }

    PART: while ($path->more) {
        $part = $path->next;

        # TODO: if it's zero-length and the last item then it indicates a
        # trailing slash?

        if ($subset = $self->{ static }->{ $part }) {
            $self->debug(
                "dynamic static part [$part]\n",
                "selected route subset: ",
                $self->dump_data($subset)
            ) if DEBUG;
            $self = $subset;
            $path->take_next;
            next PART;
        }

        foreach $dynamic (@{ $self->{ dynamic } }) {
            ($type, $name, $matcher, $subset, $prefix) = @$dynamic;
            $prefix ||= '';

            if ($self->$matcher($name, $path, $data, $prefix)) {
                $self->debug(
                    "dynamic dynamic part ($route) [$part]\n",
                    "selected route subset: ", $self->dump_data($subset)
                ) if DEBUG;
                $self = $subset;
                next PART;
            }
        }
        last;
    }
    continue {
        $self->debug("CONTINUE: [", $path->todo, "]") if DEBUG;
        # look at endpoint if @parts is empty and midpoint if there's more to come
        my $collect  = $path->more
            ? $self->{ midpoint }
            : $self->{ endpoint };
        if ($collect) {
            extend($data, $collect);
        }
    }

    return {
        path => $path,
        data => $data,
    };
}

sub match_all {
    my $self   = shift;
    my $result = $self->match(@_);
    my $path   = $result->{ path };
    if ($path->more) {
        # not a complete path match
        return $self->decline_msg( invalid => path => $path->path_todo );
    }
    return $result;
}

sub match_data {
    shift->match(@_)->{ data };
}

sub match_all_data {
    shift->match_all(@_)->{ data };
}


#-----------------------------------------------------------------------------
# Expansion
#-----------------------------------------------------------------------------

sub static_route_prefixes {
    my $self   = shift;
    my $static = $self->{ static };
    my $routes = { };

    foreach my $key (keys %$static) {
        my $route = $static->{ $key };
        my $data  = $self->point_data($route->point_data);
        $routes->{ $key } = $data;

        my $kids = $route->static_route_prefixes;
        while (my ($k, $v) = each %$kids) {
            $routes->{ join_uri($key, $k) } = $self->point_data($v);
        }
    }

    return $routes;
}


#-----------------------------------------------------------------------------
# Part matchers
#-----------------------------------------------------------------------------

sub matcher_int {
    my ($self, $name, $path, $params) = @_;

    if ($path->next =~ /^\d+$/) {
        $params->{ $name } = $path->take_next;
        return $params;
    }
}

sub matcher_word {
    my ($self, $name, $path, $params) = @_;

    if ($path->next =~ /^\w+$/) {
        $params->{ $name } = $path->take_next;
        return $params;
    }
}

sub matcher_text {
    my ($self, $name, $path, $params) = @_;

    if ($path->next =~ /^[^\/]+$/) {
        $params->{ $name } = $path->take_next;
        return $params;
    }
}

sub matcher_path {
    my ($self, $name, $path, $params) = @_;
    $params->{ $name } = $path->take_all;
    return $params;
}

sub matcher_prefix {
    my ($self, $name, $path, $params, $prefix_re) = @_;

    if ($path->next =~ /^${prefix_re}[^\/]+$/) {
        my $match = $path->take_next;
        my $value = $match;
        $value =~ s/^$prefix_re//;
        $params->{ $name } = $value;
        $self->debug("prefix match [$match] set [$name] to [$value]") if DEBUG;
        return $params;
    }
}


#-----------------------------------------------------------------------------
# Debugging
#-----------------------------------------------------------------------------

sub debug_routes {
    my $self = shift;
    $self->debug("Routes:");
    $self->debug_data( static => $self->{ static } );
    $self->debug_data( dynamic => $self->{ dynamic } );

}


1;

=head1 NAME

Contentity::Router - an advanced URL routing object

=head1 SYNOPSIS

    use Contentity::Router;

    my $router = Contentity::Router->new(
        routes => [
            # routes with static URLs
            '/user'                     => { ... },
            '/user/search'              => { ... },

            # routes with placeholders
            '/user/:id'                 => { ... },
            '/user/:id/search'          => { ... },
            '/user/:id/order/:order_no' => { ... },

            # routes with typed placeholders
            '/product/<int:id>'         => { ... },
            '/product/<text:uri>'       => { ... },

            # intermediate route matching
            '/help/-' => { ... },   # match only /help and /help/
            '/help/+' => { ... },   # match only /help/XXX
            '/help/*' => { ... },   # match /help, /help/ or /help/XXX
        ],
    );

    my $data = $router->match('/user/12345/order/98765')
        || die $router->error;

    print $data->{ id };        # 12345
    print $data->{ order_no };  # 98765

=head1 DESCRIPTION

This module implements a router for mapping URLs to actions, handlers,
metadata, or anything else you want to map URLs to.

Routes can be specified as static URLs, e.g.

    /search
    /user/home
    /stonehenge/where/the/demons/dwell

They can contain placeholders which match against any URL path segment.

    /user/:id                           # e.g. /user/12345
    /user/:id/info                      # e.g. /user/12345/info
    /user/:id/orders                    # e.g. /user/12345/orders

Routes can have multiple placeholders.

    /user/:user_id/order/:order_id      # e.g. /user/123/order/456
    /user/:user_id/orders/:year         # e.g. /user/123/orders/2013

Placeholders can be typed to match specific data types.

    /country/<int:id>                   # e.g. /country/420
    /country/<text:code>                # e.g. /country/greenland

The C<path> placeholder matches the rest of the path including any slashes.

    /country/<path:place>               # e.g. /country/uk/surrey/guildford

TODO: Typed placeholders can have parameters.

    /country/<text(length=2):iso2>      # e.g. /country/uk
    /country/<text(length=3):iso3>      # e.g. /country/gbr
    /country/<text(maxlength=16):uri>   # e.g. /country/united_kingdom

TODO: Typed placeholders have a default parameter of "length" (where appropriate).

    /country/<text(2):iso2>             # e.g. /country/uk
    /country/<text(3):iso3>             # e.g. /country/gbr

Intermediate routes can be specified that match all routes under that
prefix.  This can be used to define metadata for a section that is
effectively inherited by all routes beneath that URLs.

    /user/+                             # e.g. /user/foo, /user/bar
    /user/*                             # e.g. /user/, /user/foo, /user/bar

=head1 USAGE

A router is defined as a set of one or more routes.

    use Contentity::Router;

    my $router = Contentity::Router->new(
        routes => [
            '/user' => {
                your_data => 'goes here',
            }
        ]
    );

You can define routes when you create the router object, or subsequently via
the L<add_routes()> method.

    $router->add_routes(
        '/foo' => { msg => 'Welcome to /foo!' },
        '/bar' => { msg => 'Welcome to /bar!' },
    );

Given a URL to match, the router will return the data associated with that URL
or C<undef> if none of the pre-defined routes match.

    my $data = $router->match('/user')
        || die $router->error;

    print $data->{ your_data };     # goes here

Be aware that the router is deliberately ambivalent about leading and trailing
slashes and effectively ignores them.  A route can be defined as C<foo>,
C</foo> or C</foo/> and it will successfully match any of the URLs C<foo>,
C</foo> or C</foo/> (for the technically minded: the router treats slashes as
nothing more than delimiters and discards any empty path segments at the start,
middle or end of the route or URL).

If a route contains a placeholder then a copy of the dynamic URL part will
be added to the data returned by L<match()>.

    $router->add_route(
        '/hello/:name' => {
            msg => 'hello'
        }
    );

    my $data = $router->match('/hello/world');
    print $data->{ msg  };       # hello
    print $data->{ name };       # world

The C<*> operator can be specified as the final part of a route.  Any endpoint
data associated with the route will be added to all URLs that match the route
(without the C</*>) or any URL under that base part.

For example, a route of C</hello/*> can define data that will be added in to
matches for C</hello>, C</hello/> and any other URLs starting C</hello/>.

    $router->add_route(
        '/hello/* => {
            msg => 'hello'
        }
    );

    print $router->match('/hello')->{ msg };            # hello
    print $router->match('/hello/')->{ msg };           # hello
    print $router->match('/hello/foo')->{ msg };        # hello
    print $router->match('/hello/bar/baz')->{ msg };    # hello

The C<+> can be used in a similar way, except that it only matches URLs with
some additional component.

For example, a route of C</hello/+> with match any URLs starting C</hello/>
but will not match the C</hello> or C</hello/> URLs.

Endpoint data defined in this way is returned in addition to any other data
that may be defined for a particular endpoint or any other intermediate
midpoints.  The router will aggregate all applicable data into a single hash
array.

=head1 METHODS

=head2 new(\%config)

This is the constructor method to create a new C<Contentity::Router> object.

    use Contentity::Router;

    my $router = Contentity::Router->new(
        routes => [
            # routes with static URLs
            '/user'                     => { ... },
            '/user/search'              => { ... },

            # routes with placeholders
            '/user/:id'                 => { ... },
            '/user/:id/search'          => { ... },
            '/user/:id/order/:order_no' => { ... },

            # routes with typed placeholders
            '/product/<int:id>'         => { ... },
            '/product/<text:uri>'       => { ... },
        ],
    );

=head2 add_routes(@routes)

Docs TODO

=head2 add_route($route,$data)

Docs TODO

=head2 match($url)

Method to match a URL against the routes defined.  If the route matches,
the method returns an aggregate hash array of the endpoint data defined
for the matching route and any other intermediate matching routes.

=head1 INTERNAL METHODS

=head2 init(\%config)

=head2 init_router(\%config)

=head2 new_route_set()

=head2 add_route_parts($route, $parts, $endpoint)

=head2 add_static_route($route, $head, $tail, $endpoint)

=head2 add_dynamic_route($route, $head, $tail, $type, $name, $endpoint)

=head2 add_midpoint(\%data)

=head2 add_endpoint(\%data)

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
