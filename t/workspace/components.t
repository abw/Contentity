#============================================================= -*-perl-*-
#
# t/workspace/components.t
#
# Test workspace functionality to load and instantiate components.
#
# Written by Andy Wardley, May 2013, Dec 2013
#
#========================================================================

use Badger
    lib        => 'lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 17,
    debug => 'Contentity::Project Wibble::Module Badger::Config::Filesystem',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->dir( test_files => projects => 'alpha' );
my $project = Contentity::Project->new(
    root            => $root,
    component_path  => 'Wibble::Component',
);
ok( $project, "created contentity project: $project" );

#-----------------------------------------------------------------------------
# Fetch the database component
#-----------------------------------------------------------------------------

my $test = $project->component('test');
ok( $test, "Fetched test component: $test" );

my $s1 = $project->item_schema('test_one');
ok( $s1, 'got schema for test_one' );

my $test_one = $project->component('test_one');
ok( $test_one, "Fetched test_one component: $test_one" );

my $s2 = $project->item_schema('test_one');
ok( $s2, 'got schema for test_one');

my $test_two = $project->component('test_one');
ok( $test_two, "Fetched test_one component again: $test_two" );

isnt( $test, $test_one, 'test is not the same as test_one' );
is( $test_one, $test_two, 'both test_one objects are the same' );

#$project->debug("cache looks like that: ", $project->dump_data($project->{ component_cache }));

#$project->destroy;

#-----------------------------------------------------------------------------
# Fetch the database component
#-----------------------------------------------------------------------------

my $component = $project->component('database');
ok( $component, 'Fetched database component' );

# These should both return the same component instance
my $db1 = $project->component('database');
my $db2 = $project->component('database');

# This one should be a new instance because of the custom arguments
my $db3 = $project->component(
    database => {
#        wibble => 'another pouch'
    }
);

ok( $db1, 'got database component' );
ok( $db2, 'got database component again' );
ok( $db1 == $db2, "same database returned: $db1" );
ok( $db1 == $component, "same as previous database returned: $db1" );
#ok( $db2 != $db3, "different database returned with custom config: $db3" );


#-----------------------------------------------------------------------------
# Fetch a frusset pouch
#-----------------------------------------------------------------------------

my $pouch1 = $project->component('frusset');
ok( $pouch1, 'got a frusset pouch' );
is( $pouch1->greeting, 'nod at', 'frusset pouch has default greeting from config file' );

my $pouch2 = $project->component(
    frusset => {
        greeting => 'triple greet'
    }
);

ok( $pouch2, 'got another frusset pouch' );
is( $pouch2->greeting, 'triple greet', 'frusset pouch has custom greeting from config parameters' );
