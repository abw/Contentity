#============================================================= -*-perl-*-
#
# t/workspace/workspace.t
#
# Test the Contentity::Workspace module
#
# Written by Andy Wardley, November 2013
#
#========================================================================

use Badger 
    lib => '../../lib';
use Badger::Debug ':all';
use Badger::Filesystem 'Bin';
use Badger::Test
    tests => 26,
    debug => 'Contentity::Workspace',
    args  => \@ARGV;

use Contentity::Workspace;
use Contentity::Hub;

our $CSPACE = 'Contentity::Workspace';
our $HUB    = Contentity::Hub->new;
our $DIR1   = Bin->dir('test_files', 'workspace', 'space1');
our $DIR2   = Bin->dir('test_files', 'workspace', 'space2');

#-----------------------------------------------------------------------------
# Master workspace
#-----------------------------------------------------------------------------

my $cspace1 = $CSPACE->new(
    dir => $DIR1,
    hub => $HUB,
);
ok( $cspace1, "created $CSPACE object");
is( $cspace1->root, $DIR1, "workspace directory is $DIR1");


my $site1 = $cspace1->config('site');
ok( $site1, "fetched site config from space1");
is( $site1->{ name }, "Space1 Site", "site1.name is correct" );
is( $site1->{ version }, "23", "site1.version is correct" );

main->debug("site1 metadata: ", main->dump_data($site1)) if DEBUG;


#-----------------------------------------------------------------------------
# Slave workspace
#-----------------------------------------------------------------------------

my $cspace2 = $CSPACE->new(
    dir  => $DIR2,
    hub  => $HUB,
    base => $cspace1,
);
ok( $cspace2, "created $CSPACE object");

my $site2 = $cspace2->config('site');
ok( $site2, "fetched site config from space2");
is( $site2->{ name }, "Space2 Site", "site2.name is correct" );
is( $site2->{ version }, "23", "site2.version is inherited" );

my $css = $site2->{ css };
$css = join(', ', @$css);
is( $css, "one.css, two.css, three.css, four.css", "site2.css is a merged list" );

my $urls = $site2->{ urls };
is( $urls->{ foo }, "/foo", "site2.urls.foo is correct" );
is( $urls->{ one }, "/one", "site2.urls.one is correct" );

main->debug("site2 metadata: ", main->dump_data($site2)) if DEBUG;


#-----------------------------------------------------------------------------
# Load a form
#-----------------------------------------------------------------------------

my $schema = $cspace2->schemas;
main->debug("schemas: ", main->dump_data($schema)) if DEBUG;

my $form1 = $cspace2->config('forms/auth/login');
ok( $form1, "loaded form" );
main->debug("site2 forms/auth/login: ", main->dump_data($form1)) if DEBUG;

my $form2 = $cspace1->config('forms/search/example1');
ok( $form2, "loaded forms/search/example1 from site1" );
is( $form2->{ class }, 'blah', 'search form class' );

$form2 = $cspace2->config('forms/search/example1');
ok( $form2, "loaded forms/search/example1 from site2" );
is( $form2->{ form }, "Example Search Form", 'search form name');
ok( ! $form2->{ class }, 'search form class has been excluded');
ok( ! $form2->{ style }, 'search form style has been excluded');
main->debug("site2 forms/search/example1: ", main->dump_data($form2)) if DEBUG;

my $form3 = $cspace1->config('forms/admin/example1');
ok( $form3, "loaded forms/admin/example1 from site1" );
is( $form3->{ form }, "Admin Form", 'admin form name');
main->debug("site1 forms/admin/example1: ", main->dump_data($form3)) if DEBUG;

$form3 = $cspace2->config('forms/admin/example1');
ok( ! $form3, "prohibited from loading forms/admin/example1 from site2" );


#-----------------------------------------------------------------------------
# Deeply dotted config variables
#-----------------------------------------------------------------------------

is(
    $cspace2->config('forms/search/example1.nested.data.foo'), 
    'foo is 10', 'got dotted config data'
);

#-----------------------------------------------------------------------------
# Uris
#-----------------------------------------------------------------------------
is( $cspace2->uri, 'workspace:space2', 'uri()' );
is( $cspace2->uri('foo'), 'workspace:space2/foo', "uri('foo')" );
is( $cspace2->uri('/bar'), 'workspace:space2/bar', "uri('/bar')" );
