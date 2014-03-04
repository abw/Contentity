#============================================================= -*-perl-*-
#
# t/workspace/workspace.t
#
# Test the Contentity::Workspace module.
#
# Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib    => '../../lib lib',
    Utils  => 'Bin',
    Debug  => [import => ':all'];

use Badger::Test 
    tests => 15,
    debug => 'Contentity::Workspace Contentity::Cache Contentity::Config',
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

my $space1 = $pkg->new( root => $dir1 );
ok( $space1, "Created $space1 object" );
is( $space1->uri, 'space1', 'workspace uri' );

my $webdir = $space1->dir('web');
ok( $webdir, "Got webdir" );
is( $webdir, $web1, "webdir is $webdir" );

my $pages = $space1->config('pages');
ok( $pages, "Got pages config data" );
main->debug(
    "Pages: ",
    main->dump_data($pages)
) if DEBUG;

my $wibble = $space1->config('wibble');
ok( $wibble, "fetched wibble data" );

my $pouch = $space1->config('wibble.item');
my $style = $space1->config('wibble.wibbled');
is( $pouch, 'frusset pouch', "fetched wibble.item frusset pouch" );
is( $style, 'pleasantly', "You have pleasantly wibbled my frusset pouch" );

my $data = $space1->config->data;
main->debug("config data: ", main->dump_data($data)) if DEBUG;


#-----------------------------------------------------------------------------
# Subspace
#-----------------------------------------------------------------------------

my $subspace = $space1->subspace( root => $dir2, uri => 'sub2' );
ok( $subspace, "Created $subspace object" );
is( $subspace->uri, 'sub2', 'subspace uri' );
is( $subspace->dir('web'), $web2, "subspace webdir is $web2" );

my $swibble = $subspace->config('wibble');
ok( $swibble, "subspace fetched wibble data" );

is( $swibble->{ item    }, 'frusset pouch', "subspace fetched wibble.item frusset pouch" );
is( $swibble->{ wibbled }, 'pleasantly', "subspace pleasantly wibbled my frusset pouch" );

my $again = $subspace->config('wibble');
ok( $again, "subspace fetched wibble data again" );

main->debug("config data: ", main->dump_data($subspace->config->data)) if DEBUG;

