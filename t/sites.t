#============================================================= -*-perl-*-
#
# t/sites.t
#
# Test sites loaded by a master project.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 10,
    debug => 'Contentity::Project Contentity::Site',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $root    = Bin->parent->dir( t => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root => $root,
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch echo site
#-----------------------------------------------------------------------------

my $echo = $project->site('echo');

ok( $echo, 'got echo site' );
is( $echo->name, 'The Echo Site', 'got echo site name' );
is( $echo->greeting, 'Hello from the echo site', 'got echo greeting' );
is( $echo->mastermsg, 'The master message', 'got echo master project message' );


#-----------------------------------------------------------------------------
# Fetch foxtrot site, based on echo site
#-----------------------------------------------------------------------------

my $fox = $project->site('foxtrot');

ok( $fox, 'got foxtrot site' );
is( $fox->name, 'The Foxtrot Site', 'got foxtrot site name' );
is( $fox->greeting, 'Hello from the foxtrot site', 'got foxtrot greeting' );
is( $fox->mastermsg, 'The master message', 'got foxtrot master project message' );
is( $fox->master->name, 'The Echo Site', 'foxtrot is a slave of echo' );


