#============================================================= -*-perl-*-
#
# t/components/router.t
#
# Test for Contentity::Router
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 31,
    debug => 'Contentity::Router',
    args  => \@ARGV;

use Contentity::Router;
use constant ROUTER => 'Contentity::Router';


#-----------------------------------------------------------------------------
# Instantiate router object
#-----------------------------------------------------------------------------

my $router = ROUTER->new;
ok( $router, "created contentity router: $router" );


#-----------------------------------------------------------------------------
# Create some simple static routes
#-----------------------------------------------------------------------------

$router->add_routes(
    'foo' => {
        message => 'This is foo'
    },
    '/bar' => {
        message => 'This is bar'
    },
    '/baz/' => {
        message => 'This is baz'
    },
);

#-----------------------------------------------------------------------------
# We deliberately obscure the difference (or lack of it) between paths that
# have leading or trailing slashes.
#-----------------------------------------------------------------------------

is( $router->match_data('foo')->{ message },     'This is foo', 'foo matches foo' );
is( $router->match_data('/foo')->{ message },    'This is foo', '/foo matches foo' );
is( $router->match_data('/foo/')->{ message },   'This is foo', '/foo/ matches foo' );
is( $router->match_data('bar')->{ message },     'This is bar', 'bar matches /bar' );
is( $router->match_data('/bar')->{ message },    'This is bar', '/bar matches /bar' );
is( $router->match_data('/bar/')->{ message },   'This is bar', '/bar/ matches /bar' );
is( $router->match_data('baz')->{ message },     'This is baz', 'baz matches /baz' );
is( $router->match_data('/baz')->{ message },    'This is baz', '/baz matches /baz/' );
is( $router->match_data('/baz/')->{ message },   'This is baz', '/baz/ matches /baz/' );


#-----------------------------------------------------------------------------
# Add a route with a single placeholder
#-----------------------------------------------------------------------------

$router->add_routes(
    '/widget/:id' => {
        message => 'This is a widget'
    },
);

is( $router->match_data('/widget/12345')->{ message },
    'This is a widget',
    '/widget/12345 matches /widget/:id'
);
is( $router->match_data('widget/45678')->{ id },
    '45678',
    'widget/45678 returns id 45678'
);


#-----------------------------------------------------------------------------
# Add a route with multiple placeholders
#-----------------------------------------------------------------------------

$router->add_routes(
    '/order/:order_id/item/:item_id' => {
        message => 'This is an order item'
    },
);

is( $router->match_data('/order/12345/item/42')->{ message },
    'This is an order item',
    '/order/12345/item/42 matches /order/:order_id/item/:item_id'
);
is( $router->match_data('/order/12345/item/42')->{ order_id },
    12345,
    '/order/12345/item/42 returns order_id 12345'
);
is( $router->match_data('/order/12345/item/42')->{ item_id },
    42,
    '/order/12345/item/42 returns item_id 42'
);


#-----------------------------------------------------------------------------
# Add routes with typed placeholders
#-----------------------------------------------------------------------------

$router->add_routes(
    '/country/<int:id>' => {
        uri => 'country.by.id'
    },
    '/country/<text:code>' => {
        uri => 'country.by.code'
    },
);

is( $router->match_data('/country/21')->{ uri },
    'country.by.id',
    '/country/21 matches /country/<int:id>'
);
is( $router->match_data('/country/21')->{ id },
    21,
    '/country/21 returns id 21'
);

is( $router->match_data('/country/uk')->{ uri },
    'country.by.code',
    '/country/uk matches /country/<text:code>'
);
is( $router->match_data('/country/uk')->{ code },
    'uk',
    '/country/uk returns code uk'
);


#-----------------------------------------------------------------------------
# Add routes with intermediate data
#-----------------------------------------------------------------------------

$router->add_routes(
    # This applies to the /user and /user/ URLs only
    '/user' => {
        uri         => 'user.home',
        title       => 'User Home Page',
    },
    # This applies to /user, /user/ and /user/XXX
    '/user/*' => {
        section     => 'user_section',
        css         => 'user.css',
    },
    # This applies to /user, /user/ and /user/XXX
    '/user/+' => {
        under       => 'user',
    },
    # This applies to /user/help only, but inherits things from /user/*
    '/user/help' => {
        uri         => 'user.help',
    },
);
is( $router->match_data('/user')->{ uri },
    'user.home',
    '/user matches /user'
);
is( $router->match_data('/user')->{ section },
    'user_section',
    '/user matches /user/*'
);
is( $router->match_data('/user')->{ css },
    'user.css',
    '/user inherits css from /user/*'
);
ok( ! $router->match_data('/user')->{ under },
    '/user does not inherit under from /user/*+'
);

is( $router->match_data('/user/help')->{ uri },
    'user.help',
    '/user/help matches /user/help'
);
is( $router->match_data('/user/help')->{ css },
    'user.css',
    '/user/help inherits css from /user/*'
);
is( $router->match_data('/user/help')->{ under },
    'user',
    '/user/help inherits under from /user/+'
);
ok( ! $router->match_data('/user/help')->{ title },
    '/user/help does not inherit title from /user'
);


#-----------------------------------------------------------------------------
# test router with very simple routes
#-----------------------------------------------------------------------------


$router = ROUTER->new(
    routes => {
        '/blurb' => {
            app => 'content',
        }
    }
);
ok( $router, 'created /blurb router' );
ok( $router->match('/blurb/yada/blah/'), 'matched longer /blurb' );
ok( ! $router->match_all('/blurb/yada/blah/'), 'did not match all of longer /blurb' );
is( $router->reason, 'Invalid path specified: yada/blah/', 'gave a good reason' );
#print $router->reason, "\n";


#Contentity->debug_data( data =>)

__END__
# TODO
    # This is a catch-all
    '/user/<path:path_info>' => {
        uri         => 'user.catchall',
    },
    '/user/<text:uri>/welcome' => {
        uri         => 'user.welcome.email',
    },
