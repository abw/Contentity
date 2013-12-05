#============================================================= -*-perl-*-
#
# t/entities.t
#
# Test entity loading functionality.
#
# Written by Andy Wardley, October 2012, May 2013
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    skip  => 'Not currently working',
    tests => 9,
    debug => 'Contentity::Component::Entities Contentity::Component::Resource',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->parent->dir( t => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root        => $root,
    component_path => 'Wibble::Component',
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch entities manager
#-----------------------------------------------------------------------------

my $entities = $project->component('entities');
ok( $entities, "loaded entities" );


#-----------------------------------------------------------------------------
# Fetch entity resource
#-----------------------------------------------------------------------------

my $user = $entities->resource('tom');
ok( $user, 'fetched tom' );
is( $user->{ email }, 'tom@example.com', "got Tom's email address" );


#-----------------------------------------------------------------------------
# All in one
#-----------------------------------------------------------------------------

my $dick = $project->resource( entity => 'dick' );
ok( $dick, 'fetched dick' );
is( $dick->{ email }, 'dick@example.com', "got Dick's address" );

my $harry = $project->entity( harry => { surname => 'Smith' } );
ok( $harry, 'fetched harry' );
is( $harry->{ email }, 'harry@example.com', "got Harry's address" );
is( $harry->{ surname }, 'Smith', "got Harry's surname" );
