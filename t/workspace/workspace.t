#============================================================= -*-perl-*-
#
# t/workspace/workspace.t
#
# Test the Contentity::Workspace module.
#
# Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib    => '../../lib ../lib lib',
    Utils  => 'Bin',
    Debug  => [import => ':all'];

use Badger::Test 
    tests => 33,
    debug => 'Contentity::Workspace Contentity::Cache Contentity::Metadata Contentity::Metadata::Filesystem',
    args  => \@ARGV;

use Contentity::Workspace;
my $pkg  = 'Contentity::Workspace';
my $dir1 = Bin->dir('test_files/workspace/space1');
my $dir2 = Bin->dir('test_files/workspace/space2');
my $web1 = $dir1->dir('web');
my $web2 = $dir2->dir('web');

#-----------------------------------------------------------------------------
# Top level workspace
#-----------------------------------------------------------------------------

my $wspace = $pkg->new( directory => $dir1 );
ok( $wspace, "Created $wspace object" );
is( $wspace->uri, 'workspace:space1', 'workspace uri' );

my $webdir = $wspace->dir('web');
ok( $webdir, "Got webdir" );
is( $webdir, $web1, "webdir is $webdir" );

my $pages = $wspace->metadata->get('pages');
ok( $pages, "Got pages config data" );
main->debug(
    "Pages: ",
    main->dump_data($pages)
) if DEBUG;

my $wibble = $wspace->metadata('wibble');
ok( $wibble, "fetched wibble data" );

my $pouch = $wspace->metadata('wibble.item');
my $style = $wspace->metadata('wibble.wibbled');
is( $pouch, 'frusset pouch', "fetched wibble.item frusset pouch" );
is( $style, 'pleasantly', "You have pleasantly wibbled my frusset pouch" );

my $data = $wspace->metadata->data;
main->debug("config data: ", main->dump_data($data)) if DEBUG;

#-----------------------------------------------------------------------------
# Subspace
#-----------------------------------------------------------------------------

my $subspace = $wspace->subspace( directory => $dir2 );
ok( $subspace, "Created $subspace object" );
is( $subspace->uri, 'workspace:space2', 'subspace uri' );
is( $subspace->dir('web'), $web2, "subspace webdir is $web2" );

my $swibble = $subspace->metadata('wibble');
ok( $swibble, "subspace fetched wibble data" );

is( $swibble->{ item    }, 'frusset pouch', "subspace fetched wibble.item frusset pouch" );
is( $swibble->{ wibbled }, 'pleasantly', "subspace pleasantly wibbled my frusset pouch" );

my $again = $subspace->metadata('wibble');
ok( $again, "subspace fetched wibble data again" );

main->debug("config data: ", main->dump_data($subspace->metadata->data)) if DEBUG;


#-----------------------------------------------------------------------------
# components
#-----------------------------------------------------------------------------

my $comp_cfg = $subspace->metadata('components');
main->debug(
    "components config: ",
    main->dump_data($comp_cfg)
) if DEBUG;

is( $comp_cfg->{ flibble }, 'My::Flibble', 'flibble component config' );
is( $comp_cfg->{ wibble }, 'My::Wibble', 'wibble component config' );
is( $comp_cfg->{ tribble }, 'My::Tribble', 'tribble component config' );
is( $comp_cfg->{ flobble }->{ module }, 'My::Flobble', 'flobble component config' );
is( $comp_cfg->{ wobble }->{ module }, 'My::Wobble', 'wobble component config' );

# trouble component is excluded by inherit/exclude rule in workspace.yaml
ok( ! $comp_cfg->{ trouble }, 'no trouble' );


my $wobble = $subspace->component('wobble');
ok( $wobble, 'got a wobble component' );
is( $wobble->name, 'WOBBLE', 'wobble name' );

my $w2 = $subspace->wobble;
ok( $w2, 'got a wobble component via AUTOLOAD method' );
is( $w2->name, 'WOBBLE', 'AUTOLOAD wobble name' );

#-----------------------------------------------------------------------------
# resources
#-----------------------------------------------------------------------------

my $login = $subspace->resource( form => 'login' );
ok( $login, 'got login form' );
is( $login->{ name }, 'login_form', 'got form name' );

my $l2 = $subspace->form('login');
ok( $l2, 'got login form via AUTOLOAD method' );
is( $l2->{ name }, 'login_form', 'AUTOLOAD login form name' );

my $l3 = $subspace->form('login');
ok( $l3, 'got login form via AUTOLOAD method' );
is( $l3->{ name }, 'login_form', 'AUTOLOAD login form name' );

my $fcfg = $subspace->metadata('forms');
main->debug(
    "forms metadata: ",
    main->dump_data($fcfg)
) if DEBUG;

#-----------------------------------------------------------------------------
# auto-generated method to access metadata
#-----------------------------------------------------------------------------

is( $subspace->name, 'Workspace Example 2', 'got name via autogenerated method' );

eval {
    $subspace->no_such_name;
};
if ($@) {
    ok( $@ =~ /Invalid method 'no_such_name' called on Contentity::Workspace/, 'got no_such_name() error' );
}
else {
    fail("should have failed on no_such_name() method")
}
