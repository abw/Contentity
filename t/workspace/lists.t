#============================================================= -*-perl-*-
#
# t/workspace/lists.t
#
# Test Contentity::Component::Lists
#
# Written by Andy Wardley October 2015
#
#========================================================================

use Badger
    lib        => 'lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Component::Lists',
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

my $lists = $project->lists;
ok( $lists, "got lists component: $lists" );

my $people = $project->list('people');
ok( $people, "got people: $people" );
#print "People: ", $project->dump_data( $people );

my $cheeses = $project->list('cheeses');
ok( $cheeses, "got cheeses: $cheeses" );
#print $project->dump_data( cheeses => $cheeses );

print "sleeping...\n";
sleep(1);

$people = $project->list('people');
ok( $people, "got people after waiting a second: $people" );

print "sleeping...\n";
sleep(2);

$people = $project->list('people');
ok( $people, "got people after waiting another two seconds: $people" );
