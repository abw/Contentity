#============================================================= -*-perl-*-
#
# t/entities.t
#
# Test entity loading functionality.
#
# Written by Andy Wardley, October 2012
#
#========================================================================

use Badger
    lib        => '../lib',
    Filesystem => 'Bin';

use Badger::Test
    tests => 4,
    debug => 'Contentity::Module::Entities Contentity::Module::Resource',
    args  => \@ARGV;

use Contentity::Project;

my $root    = Bin->parent;
my $project = Contentity::Project->new( root => $root );
ok( $project, "created contentity project: $project" );

my $entities = $project->module('entities');
ok( $entities, "loaded entities" );

my $user = $entities->resource('tom');
ok( $user, 'fetched tom' );
is( $user->{ email }, 'tom@example.com', 'got email address' );
