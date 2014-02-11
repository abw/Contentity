#============================================================= -*-perl-*-
#
# t/core/configure.t
#
# Test the Contentity::Configure module
#
# Copyright (C) 2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

#use lib '/home/abw/projects/badger/lib';

use Badger
    lib    => '../../lib',
    Utils  => 'Bin',
    Debug  => [import => ':all'];

use Badger::Test 
    tests => 2,
    debug => 'Contentity::Configure',
    args  => \@ARGV;

use Contentity::Configure;

my $script = Contentity::Configure->new(
    directory => Bin,
    args      => \@ARGV,
    prompt    => 0,
);

ok( $script, 'created configure script' );

my $data = $script->data;

is( $data->{ database }->{ hostname }, 'localhost', 'got database.hostname' );

main->debug(
    "data: ",
    main->dump_data($data)
) if DEBUG;
