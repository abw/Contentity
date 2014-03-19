#============================================================= -*-perl-*-
#
# t/configure/item.t
#
# Test the Contentity::Configure::Item module
#
# Copyright (C) 2013 Andy Wardley.  All Rights Reserved.
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
    tests => 1,
    debug => 'Contentity::Configure::Item',
    args  => \@ARGV;

use Contentity::Configure::Item;
use constant ITEM => 'Contentity::Configure::Item';

my $item = ITEM->new(
    name   => 'foo',
    title  => 'The Foo Thing',
    prompt => 'Please enter the foo thing',
    about  => "This is the foo thing, it's really cool",
);

ok( $item, 'created item for the foo thing' );

if (DEBUG) {
    print "Help option:\n", $item->help, "\n";
    $item->prompt;
}
