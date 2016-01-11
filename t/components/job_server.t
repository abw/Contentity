#============================================================= -*-perl-*-
#
# t/components/job_server.t
#
# Test the Contentity::Component::Job::Server module.
#
# Written by Andy Wardley, January 2014
#
#========================================================================

use Badger
    lib   => '../../lib /Users/abw/projects/badger/lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Component::Job::Server',
    args  => \@ARGV;

use Contentity::Project;
use warnings FATAL => 'all';


my $root    = Bin->dir( test_files => 'comps1' );
my $project = Contentity::Project->new(
    root => $root,
);
ok( $project, "created contentity project: $project" );

#-----------------------------------------------------------------------------
# Fetch a job server
#-----------------------------------------------------------------------------

my $server = $project->component('job/server');
ok( $server, "got a job server: $server" );

$server->log( info => 'hello world!' );

#my $request = $context->request;
#ok( $request, "got a request: $request" );
#
#my $response = $context->response;
#ok( $response, "got a response: $response" );
