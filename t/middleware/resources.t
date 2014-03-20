#============================================================= -*-perl-*-
#
# t/middleware/resources.t
#
# Test the Contentity::Middleware::Resources module.
#
# Written by Andy Wardley, March 2014
#
#========================================================================

use Badger
    lib   => '../../lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Middleware::Resources',
    args  => \@ARGV;

use Contentity::Project;


my $root  = Bin->dir( test_files => 'space1' );
my $space = Contentity::Project->new( 
    root => $root,
);
ok( $space, "created contentity workspace: $space" );

#-----------------------------------------------------------------------------
# Fetch resources middleware
#-----------------------------------------------------------------------------

my $res = $space->middleware('resources');
ok( $res, "got resources middleware: $res" );

