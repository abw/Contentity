#============================================================= -*-perl-*-
#
# t/apps.t
#
# Test apps component.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger::Debug modules => 'Badger::Utils';
use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    skip  => 'Not currently working',
    tests => 3,
    debug => 'Contentity::Apps Contentity::Component::App',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Fetch hotel site
#-----------------------------------------------------------------------------

my $root = Bin->parent->dir( t => projects => 'alpha' );
my $base = Contentity::Project->new( 
    root => $root,
);
ok( $base, "created contentity base site: $base" );

my $hotel = $base->site('hotel');
ok( $hotel, 'got hotel site' );

my $app = $hotel->app('hello');
ok( $app, 'got hello app' );


