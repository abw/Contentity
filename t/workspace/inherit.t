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

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Debug ':all';
use Badger::Test 
    tests => 6,
    debug => 'Contentity::Metadata Contentity::Metadata::Filesystem',
    args  => \@ARGV;

use Badger::Utils 'Bin';
use Contentity::Workspace;
use Contentity::Cache;          # TODO: skip if not found...

my $cache  = Contentity::Cache->new;
my $pkg    = 'Contentity::Workspace';
my $dir1   = Bin->dir('test_files/wspace1');
my $dir2   = Bin->dir('test_files/wspace2');
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

my $wibble = $child->config('wibble');
ok( $wibble, 'got wibble' );

my $two = $child->config('two');
ok( ! $two, 'did NOT get two (correctly)' );

my $pages = $child->config('pages');
ok( $pages, 'got pages' );

main->debug(
    main->dump_data($pages)
) if DEBUG;
