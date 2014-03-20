#============================================================= -*-perl-*-
#
# t/workspace/apps.t
#
# Test Contentity::Component::Apps and Contentity::Apps
#
# Written by Andy Wardley March 2014
#
#========================================================================

use Badger
    lib        => 'lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 7,
#    debug => 'Contentity::Apps Contentity::Component::Apps Contentity::Component::Asset',
    debug => 'Contentity::Config Badger::Config::Filesystem',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->dir( test_files => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root    => $root,
);
ok( $project, "created contentity project: $project" );

my $apps1 = $project->apps;
ok( $apps1, "got apps component: $apps1" );

my $apps2 = $project->apps;
ok( $apps2, "got apps component: $apps2" );

is( $apps1, $apps2, 'apps component is cached' );


my $app1 = $project->app( 'hello', pleasantly => 'Wibble my Frusset Pouch' );
ok( $app1, "got hello app once: $app1" );

my $app2 = $project->app( 'hello', pleasantly => 'Jangle my mangle' );
ok( $app2, "got hello app again: $app2" );

is( $app1, $app2, 'content app is cached' );
