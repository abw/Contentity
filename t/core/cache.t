#============================================================= -*-perl-*-
#
# t/config/cache.t
#
# Test the Contentity::Cache module
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
    debug => 'Contentity::Cache',
    args  => \@ARGV;

use Contentity::Cache;

my $cache  = Contentity::Cache->new;

ok( $cache, 'created cache' );
$cache->set( 
    foo => {
        a => 10,
        b => [20,30,40],
    }
);

my $foo = $cache->get('foo');
ok( $foo, 'got foo' );
is( $foo->{ a }, 10, 'foo.a is 10' );
is( $foo->{ b }->[1], 30, 'foo.b.1 is 30' );

main->debug(
    "foo: ",
    main->dump_data($foo)
) if DEBUG;


my $memory = Contentity::Cache->new(
    module => 'Contentity::Cache::Memory'
);
ok( $memory, 'created memory cache' );

