#============================================================= -*-perl-*-
#
# t/urls.t
#
# Test site urls.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    skip  => 'Not currently working',
    tests => 6,
    debug => 'Contentity::Site',
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
# Fetch urls
#-----------------------------------------------------------------------------

my $urls = $hotel->urls;
ok( $urls, "got site urls: $urls" );
is( $urls->{ foo }, '/path/to/foo', 'got URL inherited from base' );
is( $urls->{'admin_order'}, '/path/to/order/admin', 'got nested URL inherited from base' );
is( $urls->{'admin_order'}, '/path/to/order/admin', 'got nested URL inherited from base' );

#print main->dump_data($urls);
