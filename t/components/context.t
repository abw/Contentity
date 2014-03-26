#============================================================= -*-perl-*-
#
# t/components/context.t
#
# Test the Contentity::Component::Context module.
#
# Written by Andy Wardley, March 2014
#
#========================================================================

use Badger
    lib   => '../../lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 4,
    debug => 'Contentity::Component::Context',
    args  => \@ARGV;

use Contentity::Project;


my $root    = Bin->dir( test_files => 'comps1' );
my $project = Contentity::Project->new( 
    root => $root,
);
ok( $project, "created contentity project: $project" );

#-----------------------------------------------------------------------------
# Fetch a context
#-----------------------------------------------------------------------------

my $context = $project->context( env => { testing => 123 } );
ok( $context, "got a context: $context" );

my $request = $context->request;
ok( $request, "got a request: $request" );

my $response = $context->response;
ok( $response, "got a response: $response" );

