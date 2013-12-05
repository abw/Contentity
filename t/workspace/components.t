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
    lib        => 'lib ../lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 11,
    debug => 'Contentity::Project Wibble::Module',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->dir( test_files => projects => 'alpha' );
my $project = Contentity::Project->new( 
    directory       => $root,
    component_path  => 'Wibble::Component',
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch the database component
#-----------------------------------------------------------------------------

my $component = $project->component('database');
ok( $component, 'Fetched database component' );

# These should both return the same component instance
my $db1 = $project->component('database');
my $db2 = $project->database;

# This one should be a new instance because of the custom arguments
my $db3 = $project->component( 
    database => { 
        wibble => 'another pouch' 
    } 
);

ok( $db1, 'got database component' );
ok( $db2, 'got database component again' );
ok( $db1 == $db2, "same database returned: $db1" );
ok( $db1 == $component, "same as previous database returned: $db1" );
ok( $db2 != $db3, "different database returned with custom config: $db3" );


#-----------------------------------------------------------------------------
# Fetch a frusset pouch
#-----------------------------------------------------------------------------

my $pouch1 = $project->frusset;
ok( $pouch1, 'got a frusset pouch' );
is( $pouch1->greeting, 'nod at', 'frusset pouch has default greeting from config file' );

my $pouch2 = $project->component( 
    frusset => { 
        greeting => 'triple greet' 
    }
);

ok( $pouch2, 'got another frusset pouch' );
is( $pouch2->greeting, 'triple greet', 'frusset pouch has custom greeting from config parameters' );
