#============================================================= -*-perl-*-
#
# t/apps/record.t
#
# Test Contentity::Web::App::Record
#
# Written by Andy Wardley August 2016
#
#========================================================================

use Badger
    lib        => 'lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 1,
    debug => 'Contentity::Web::App::Record',
    args  => \@ARGV;

use My::Widget;
pass( "Loaded My::Widget" );
