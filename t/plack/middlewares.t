#============================================================= -*-perl-*-
#
# t/plack/middlewares.t
#
# Test Contentity::Middlewares module for loading middleware components.
#
# Written by Andy Wardley, January 2014
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    skip     => 'not currently working',
    tests    => 1,
    debug    => 'Contentity::Middlewares',
    args     => \@ARGV;

use Contentity;

my $mids = Contentity->middlewares;
ok( $mids, "fetched middlewares: $mids");
