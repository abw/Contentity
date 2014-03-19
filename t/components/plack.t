#============================================================= -*-perl-*-
#
# t/components/plack.t
#
# Test the Contentity::Component::Plack module.
#
# Written by Andy Wardley, March 2014
#
#========================================================================

use Badger::Debug modules => 'Badger::Base';

use Badger
    lib   => '../../lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Component::Scaffold',
    args  => \@ARGV;

use Contentity::Workspace;


my $root  = Bin->dir( test_files => 'comps1' );
my $space = Contentity::Workspace->new( 
    root => $root,
);
ok( $space, "created contentity workspace: $space" );

#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $plack = $space->component('plack');
ok( $plack, "got plack component: $plack" );

#$scaf->build if DEBUG;
