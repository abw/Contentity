package Contentity::Router;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Base',
    constants   => 'ARRAY HASH',
    accessors   => 'routes',
    constant    => {
        MATCH_MINUS => qr/^(\-)$/,
        MATCH_PLUS  => qr/^(\+)$/,
        MATCH_STAR  => qr/^(\*)$/,
        MATCH_FIXED => qr/^([\w\-\.]+)$/,
        MATCH_PLACE => qr/^(:\w+)$/,
        MATCH_ANGLE => qr/^<(.*)>$/,
    },
    messages => {
        invalid_route    => 'Invalid route specified: %s',
        invalid_fragment => 'Invalid fragment "%s" in route: %s',
        not_last         => 'Intermix operator "%s" must be the last item in the route: %s',
    };

our $TYPES = {
    int  => \&match_int,
    word => \&match_word,
    text => \&match_text,
    path => \&match_path,
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

    # Fixed routes are static text, e.g. in '/user/list' both 'user' and 'list'
    # are fixed route components.  Matched route components like ':id' 
    # are matched in sequence through the list in $routes->{ dynamic }.  
    # See below for what that contains.  We also maintain an index of matched
    # components so that we can reuse the same intermediate dynamic component 
    # for, e.g. the ':id' matching routeset in both '/user/:id/info' and 
    # '/user/:id/contact'
    $self->{ fixed    } = { };
    $self->{ matched  } = [ ];
    $self->{ matchndx } = { };

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
                    $key =~ s/^\d+\s+//g;
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
        $self->debug("matched minus: $1 in $head") if DEBUG;

        # A final element of '-' is an explicit way to set some endpoint data
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint);
    }
    elsif ($head =~ MATCH_PLUS) {
        $self->debug("matched plus: $1 in $head") if DEBUG;

        # A final element of '+' is a midpoint, applying to all paths that
        # have further items following
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint);
    }
    elsif ($head =~ MATCH_STAR) {
        $self->debug("matched star: $1 in $head") if DEBUG;

        # A final element of '*' is both a midpoint and an endpoint, applying
        # to both URLs with and without further path elements
        return @$parts
            ? $self->error_msg( not_last => $1, $route )
            : $self->add_midpoint($endpoint)
                   ->add_endpoint($endpoint);
    }
    elsif ($head =~ MATCH_FIXED) {
        # A fixed route element
        $self->debug("matched fixed route part: $1 in $head") if DEBUG;

        return $self->add_fixed_route(
            $route, 
            $1, $parts, 
            $endpoint
        );
    }
    elsif ($head =~ MATCH_PLACE) {
        # A standard :name placeholder
        $self->debug("matched placeholder: $1 in $head") if DEBUG;

        return $self->add_matched_route(
            $route, 
            $1, $parts,
            $endpoint
        );
    }
    elsif ($head =~ MATCH_ANGLE) {
        # An extended <type:name> placeholder
        $self->debug("matched angled placeholder: $1 | $head") if DEBUG;

        return $self->add_matched_route(
            $route, 
            $1, $parts, 
            $endpoint
        );
    }

    return $self->error_msg( invalid_fragment => $head, $route );
}

sub add_fixed_route {
    my ($self, $route, $head, $tail, $endpoint) = @_;
    my $subset = $self->{ fixed }->{ $head } ||= $self->new_route_set;

    if (@$tail) {
        $self->debug("adding fixed intermediary for [$head]") if DEBUG;
        return $subset->add_route_parts($route, $tail, $endpoint);
    }
    else {
        $self->debug("adding fixed endpoint for [$head]") if DEBUG;
        return $subset->add_endpoint($endpoint);
    }
}

sub add_matched_route {
    my ($self, $route, $head, $tail, $endpoint) = @_;

    # $head can be 'foo' or ':foo', both of which are implicitly text types
    # 'text:foo', or an explicitly typed route part, e.g. int:foo
    my @parts = split(':', $1, 2);
    my ($type, $name) = @parts == 2 ? @parts : (text => @parts);
    $type ||= $DEFAULT_TYPE;

    # The $type must have a basic matcher function defined in $TYPES
    my $matcher = $TYPES->{ $type }
        || return $self->error_msg( invalid => type => $type );

    # We want to share intermediate component.  For example, with two routes
    # /user/:id/foo and /user/:id/bar we want to use the same dynamic rule 
    # matching component for the middle :id part.  We create a canonical
    # type:name identifier for it to accommodate differences in syntax, e.g.
    # /user/:id/foo, /user/text:id/bar and /user/<text:id>/baz will all use
    # the same intermediate text:id component.
    my $canon   = "$type:$name";
    my $subset  = $self->{ matchndx }->{ $canon };

    # We don't already have a route set for this component so create one
    if (! $subset) {
        $self->debug("creating new subset router for [$head]") if DEBUG;
        $subset = $self->{ matchndx }->{ $canon } = $self->new_route_set;
        push(
            @{ $self->{ match } }, 
            [ $type, $name, $matcher, $subset ]
        );
    }

    # If there's any more of the route left to resolve then hand it over 
    # to the new nested routeset for further processing.  Otherwise we set
    # the endpoint data in the current route set and return.
    if (@$tail) {
        $self->debug("adding matched intermediary for [$head]") if DEBUG;
        return $subset->add_route_parts($route, $tail, $endpoint);
    }
    else {
        $self->debug("adding matched endpoint for [$head]") if DEBUG;
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


#-----------------------------------------------------------------------------
# matcher
#-----------------------------------------------------------------------------

sub match {
    my ($self, $path) = @_;
    my ($fragment) = ($path =~ s/\#(.*)$//) ? $1 : '';
    my ($reqparms) = ($path =~ s/\?(.*)$//) ? $1 : '';
    my @parts      = grep { defined && length } split(qr{/}, $path);
    my $params     = { };
    my ($part, $route, $type, $name, $match, $matcher, $subset);

    $self->debug(
        "matching path: $path => ", 
        $self->dump_data_inline(\@parts),
        " [$params] [$fragment]"
    ) if DEBUG;

    # $path may be empty, e.g. for the / URL but we still want to match 
    # endpoint data defined as /* or /- 
    # The continue { } block doesn't get trigged if @parts is empty so we
    # special-case it by copying any endpoint data into $params
    if (! @parts && $self->{ endpoint }) {
        $params = { %{ $self->{ endpoint } } };
    }

    PART: while (@parts) {
        $part = $parts[0];

        if ($subset = $self->{ fixed }->{ $part }) {
            $self->debug(
                "matched fixed part [$part]\n",
                "selected route subset: ",
                $self->dump_data($subset)
            ) if DEBUG;
            $self = $subset;
            shift @parts;
            next PART;
        }

        foreach $match (@{ $self->{ match } }) {
            ($type, $name, $matcher, $subset) = @$match;
            if ($self->$matcher($name, \@parts, $params)) {
                $self->debug(
                    "matched dynamic part ($route) [$part]\n",
                    "selected route subset: ", $self->dump_data($subset)
                ) if DEBUG;
                $self = $subset;
                next PART;
            }
        }
        return $self->error("Invalid path: $path");
    }
    continue {
        $self->debug("CONTINUE: [", join(', ', @parts), "]");
        # look at endpoint if @parts is empty and midpoint if there's more to come
        my $collect  = @parts
            ? $self->{ midpoint }
            : $self->{ endpoint };
        if ($collect) {
            @$params{ keys %$collect } = values %$collect;
        }
    }

    return $params;
}


#-----------------------------------------------------------------------------
# Part matchers
#-----------------------------------------------------------------------------

sub match_int {
    my ($self, $name, $path, $params) = @_;

    if ($path->[0] =~ /^\d+$/) {
        $params->{ $name } = shift @$path;
        return $params;
    }
}

sub match_word {
    my ($self, $name, $path, $params) = @_;

    if ($path->[0] =~ /^\w+$/) {
        $params->{ $name } = shift @$path;
        return $params;
    }
}

sub match_text {
    my ($self, $name, $path, $params) = @_;

    if ($path->[0] =~ /^[^\/]+$/) {
        $params->{ $name } = shift @$path;
        return $params;
    }
}

sub match_path {
    my ($self, $name, $path, $params) = @_;
    $params->{ $name } = join('/', splice @$path);
    return $params;
}



1;

=head1 NAME

Contentity::Router - an advanced URL routing object

=head1 SYNOPSIS

    use Contentity::Router;
    
    my $router = Contentity::Router->new(
        routes => [
            # routes with fixed URLs
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

Routes can be specified as fixed URLs, e.g.

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

If a route contains a placeholder then a copy of the matched URL part will
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
            # routes with fixed URLs
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

=head2 add_fixed_route($route, $head, $tail, $endpoint)

=head2 add_matched_route($route, $head, $tail, $type, $name, $endpoint)

=head2 add_midpoint(\%data)

=head2 add_endpoint(\%data)

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
