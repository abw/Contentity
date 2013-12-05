#============================================================= -*-perl-*-
#
# t/middleware.t
#
# Test Contentity::Middleware and Contentity::Middlewares factory module.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

#BEGIN { $Badger::Utils::DEBUG = 1 };
use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Middleware Contentity::Middlewares',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Fetch project site
#-----------------------------------------------------------------------------

my $root = Bin->parent->dir( t => projects => 'alpha' );
my $base = Contentity::Project->new( 
    root => $root,
);
ok( $base, "created contentity base site: $base" );

#print "componentns: ", main->dump_data($base->components), "\n";

my $site  = $base->middleware('site');
ok( $site, "got site middleware: $site" );

