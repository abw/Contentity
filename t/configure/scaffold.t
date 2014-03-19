#============================================================= -*-perl-*-
#
# t/configure/scaffold.t
#
# Test the Contentity::Scaffold module
#
# Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.
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
    debug => 'Contentity::Scaffold',
    args  => \@ARGV;

use Contentity::Scaffold;

my $test_dir = Bin->dir('test_files', 'scaffold1');
my $scaffold = Contentity::Scaffold->new(
    source_dirs  => [ $test_dir->dir('source1'),  $test_dir->dir('source2')  ],
    library_dirs => [ $test_dir->dir('library1'), $test_dir->dir('library2') ],
    output_dir   => $test_dir->dir('output'),
);

ok( $scaffold, 'created scaffold' );

# test the verbose() method
ok( ! $scaffold->verbose, 'Not verbose' );
$scaffold->verbose(1);
ok(   $scaffold->verbose, 'Now verbose' );

# test the quiet() method
ok( ! $scaffold->quiet, 'Not quiet' );
$scaffold->quiet(1);
ok(   $scaffold->quiet, 'Now quiet' );
