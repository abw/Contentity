#============================================================= -*-perl-*-
#
# t/components/content_types.t
#
# Test the Contentity::Component::ContentTypes module.
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
    debug => 'Contentity::Component::ContentTypes',
    args  => \@ARGV;

use Contentity::Workspace::Web;


my $root  = Bin->dir( test_files => 'comps1' );
my $space = Contentity::Workspace::Web->new( 
    root => $root,
);
ok( $space, "created contentity workspace: $space" );

#-----------------------------------------------------------------------------
# Fetch content_types component
#-----------------------------------------------------------------------------

my $types = $space->content_types;
ok( $types, "got content_types component: $types" );

