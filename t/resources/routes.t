#============================================================= -*-perl-*-
#
# t/routes.t
#
# Tests for Contentity::Component::Routes which constructs a 
# Contentity::Router object to match URLs against a set of routes.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 7,
    debug => 'Contentity::Component::Routes',
    args  => \@ARGV;

use Badger::Exception trace => 1;
use Contentity::Project;
use Contentity::Site;


#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $root = Bin->parent->dir( 
    t => projects => 'golf' 
);
my $site = Contentity::Site->new( 
    root => $root,
);

ok( $site, "created contentity project: $site" );

my $routes = $site->routes;
ok( $routes, "Got project routes: $routes" );

my $match = $site->match_route('foo');
ok( $match, 'matched foo' );
is( $match->{ title }, 'The Foo Page', 'got the foo page title' );

$site->add_route(
    '/user/:id' => {
        uri => 'some.user.info'
    }
);

$match = $site->match_route('/user/abw');
ok( $match, 'matched /user/abw' );
is( $match->{ uri }, 'some.user.info', 'got the /user/abw uri' );
is( $match->{ id  }, 'abw', 'got the /user/abw user id' );

#print $project->router->dump;
