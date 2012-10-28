#============================================================= -*-perl-*-
#
# t/project.t
#
# Test project loading functionality.
#
# Written by Andy Wardley, October 2012
#
#========================================================================

use Badger
    lib        => '../lib',
    Filesystem => 'Bin';

use Badger::Test
    tests => 7,
    debug => 'Contentity::Project',
    args  => \@ARGV;

use Contentity::Project;

my $root    = Bin->parent;
my $project = Contentity::Project->new( root => $root );
ok( $project, "created contentity project: $project" );

my $form = $project->resource_data( 
    forms => 'wibble.yaml' 
);
ok( $form, "fetched form data: $form" );

pass("calling wibble");
wibble();
pass("returned from wibble");

sub wibble {
    my $project = Contentity::Project->new( root => $root );
    my $db1     = $project->module( database => { wibble => 'frusset pouch' } );
    my $db2     = $project->module( database => { wibble => 'another pouch' } );
    ok( $db1, 'got database module' );
    ok( $db2, 'got database module again' );
    ok( $db1 == $db2, "same database returned: $db1" );
}
