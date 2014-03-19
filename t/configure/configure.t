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
    tests => 1,
    debug => 'Contentity::Configure::App',
    args  => \@ARGV;

use Contentity::Configure::App;

my $app = Contentity::Configure::App->new(
    directory => Bin,
    args      => \@ARGV,
    prompt    => 0,
);

ok( $app, 'created app' );
