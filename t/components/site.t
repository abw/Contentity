#============================================================= -*-perl-*-
#
# t/components/site.t
#
# Test the Contentity::Component::Site flyweight module.
#
# Written by Andy Wardley March 2014
#
#========================================================================

use lib '/Users/abw/projects/badger/lib';
use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 7,
    debug => 'Contentity::Workspace Contentity::Component::Site 
              Contentity::Component::Flyweight Badger::Config::Filesystem',
    args  => \@ARGV;

use Contentity::Workspace;

#-----------------------------------------------------------------------------
# Instantiate workspace object
#-----------------------------------------------------------------------------

my $root1  = Bin->dir( test_files => 'comps1' );
my $comps1 = Contentity::Workspace->new( 
    root => $root1,
);
ok( $comps1, "created contentity workspace: $comps1" );

#-----------------------------------------------------------------------------
# Fetch the site component
#-----------------------------------------------------------------------------

my $site1 = $comps1->site;
ok( $site1, "Fetched first site component: $site1" );

is( $site1->name,      'My Test Site', 'got site.name' );
is( $site1->version,   123, 'got site.version' );
is( $site1->copyright, '2014 My Company', 'got site.copyright' );

my $humans1 = $site1->humans;
ok( $humans1, 'got some humans' );
is( scalar(@$humans1), 2, 'got two humans' );


#-----------------------------------------------------------------------------
# Instantiate sub-workspace object
#-----------------------------------------------------------------------------

my $root2  = Bin->dir( test_files => 'comps2' );
my $comps2 = Contentity::Workspace->new( 
    root   => $root2,
    parent => $comps1,
);
ok( $comps2, "created contentity sub-workspace: $comps2" );

#-----------------------------------------------------------------------------
# Fetch the site component
#-----------------------------------------------------------------------------

my $site2 = $comps2->site;
ok( $site2, "Fetched second site component: $site2" );

is( $site2->name,      'My Other Site', 'got second site.name' );
is( $site2->version,   456, 'got second site.version' );
is( $site2->copyright, '2014 My Company', 'got second site.copyright inherited from first' );
is( $site2->less,      'Is More', 'got second site.less is more' );

my $humans2 = $site2->humans;
ok( $humans2, 'got some humans' );
is( scalar(@$humans2), 3, 'got three humans' );

my $pages2 = $comps2->pages;
print "pages: ", $comps2->dump_data($pages2), "\n";
