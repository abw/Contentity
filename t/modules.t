#============================================================= -*-perl-*-
#
# t/modules.t
#
# Test module loading functionality.
#
# Written by Andy Wardley, October 2012
#
#========================================================================

use Badger
    lib        => './lib ../lib',
    Filesystem => 'Bin';

use Badger::Test
    tests => 6,
    debug => 'Contentity::Project Wibble::Module',
    args  => \@ARGV;

use Contentity::Project;

my $root    = Bin->parent;
my $project = Contentity::Project->new(
    root        => $root,
    module_path => 'Wibble::Module',
);
ok( $project, 'Created contentity project' );

my $module = $project->module('database');
ok( $module, 'Fetched database module' );

my $db1 = $project->module('database');
my $db2 = $project->module( database => { wibble => 'another pouch' } );
ok( $db1, 'got database module' );
ok( $db2, 'got database module again' );
ok( $db1 == $db2, "same database returned: $db1" );

my $pouch = $project->module( frusset => { greeting => 'triple greet' } );
ok( $pouch, 'got a frusset pouch' );

