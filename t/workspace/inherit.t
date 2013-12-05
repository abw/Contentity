#============================================================= -*-perl-*-
#
# t/workspace/inherit.t
#
# Test the Contentity::Workspace module with a parent space.
#
# Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib    => '../../lib',
    Utils  => 'Bin',
    Debug  => [import => ':all'];

use Badger::Test 
    tests => 5,
    debug => 'Contentity::Metadata Contentity::Metadata::Filesystem',
    args  => \@ARGV;

use Contentity::Workspace;
use Contentity::Cache;          # TODO: skip if not found...

my $cache  = Contentity::Cache->new;
my $pkg    = 'Contentity::Workspace';
my $dir1   = Bin->dir('test_files/workspace/space1');
my $dir2   = Bin->dir('test_files/workspace/space2');
my $parent = $pkg->new( 
    cache     => $cache,
    directory => $dir1,
    file      => 'config',
    uri       => 'workspace:parent',
);
ok( $parent, "Created parent $pkg object" );

my $child = $pkg->new( 
    cache     => $cache,
    directory => $dir2,
    file      => 'config',
    uri       => 'workspace:child',
    parent    => $parent,
);
ok( $child, "Created child $pkg object" );

my $wibble = $child->metadata('wibble');
ok( $wibble, 'got wibble' );

my $two = $child->metadata('two');
ok( ! $two, 'did NOT get two (correctly)' );

my $pages = $child->metadata('pages');
ok( $pages, 'got pages' );

main->debug(
    main->dump_data($pages)
) if DEBUG;
