#============================================================= -*-perl-*-
#
# t/metadata/metadata.t
#
# Test the Contentity::Metadata module.
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
    tests => 4,
    debug => 'Contentity::Metadata',
    args  => \@ARGV;

use Contentity::Metadata;
my $pkg  = 'Contentity::Metadata';

my $meta = $pkg->new(
    foo     => 10,
    bar     => [20, 30, 40],
    baz     => { wam => 'bam' },
    message => 'Hello World',
    author  => {
        name => 'Mr Badger'
    }
);

ok( $meta, "Created $meta object" );
is( $meta->get('foo'), '10', 'foo matches' );
is( $meta->get('bar.0'), '20', 'bar.0 matches' );
is( $meta->get('baz.wam'), 'bam', 'baz.wam matches' );


