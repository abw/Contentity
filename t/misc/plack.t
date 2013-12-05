#============================================================= -*-perl-*-
#
# t/plack.t
#
# Test plack component.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 4,
    debug => 'Contentity::Project Contentity::Component::Plack',
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


#-----------------------------------------------------------------------------
# Fetch plack component
#-----------------------------------------------------------------------------

my $plack = $hotel->plack;
ok( $plack, "got plack component: $plack" );

my $app = $plack->app;
ok( $app, "got plack app : $app" );
