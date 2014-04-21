#============================================================= -*-perl-*-
#
# t/workspace/routes.t
#
# Tests for Contentity::Component::Routes which constructs a
# Contentity::Router object to match URLs against a set of routes.
#
# Written by Andy Wardley, May 2013, updated April 2014
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 9,
    debug => 'Contentity::Component::Routes Contentity::Router',
    args  => \@ARGV;

use Badger::Exception trace => 1;
use Contentity::Project;
use Contentity::Utils 'refaddr';


#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $root = Bin->dir(
    test_files => projects => 'golf'
);
my $site = Contentity::Project->new(
    root => $root,
);

ok( $site, "created contentity project: $site" );

my $routes = $site->routes;
ok( $routes, "Got project routes: $routes" );

my $routes2 = $site->routes;
ok( $routes2, "Got project routes again: $routes2" );
is( refaddr($routes), refaddr($routes2), 'same reference' );

my $match = $site->match_route('foo');
ok( $match, 'matched foo' );
is( $match->{ data }->{ title }, 'The Foo Page', 'got the foo page title' );

$site->add_route(
    '/user/:id' => {
        uri => 'some.user.info'
    }
);

$match = $site->match_route('/user/abw');
ok( $match, 'matched /user/abw' );
is( $match->{ data }->{ uri }, 'some.user.info', 'got the /user/abw uri' );
is( $match->{ data }->{ id  }, 'abw', 'got the /user/abw user id' );

#print $project->router->dump;
