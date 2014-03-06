#============================================================= -*-perl-*-
#
# t/misc/reporter.t
#
# Test Contentity::Reporter module.
#
# Written by Andy Wardley, March 2014
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests    => 2,
    debug    => 'Contentity::Reporter',
    args     => \@ARGV;

use constant
    REPORTER => 'Contentity::Reporter';

use Contentity::Reporter;

my $reporter = REPORTER->new;
ok( $reporter, 'created a reporter' );

if (DEBUG) {
    $reporter->verbose(1);
    $reporter->info("An information message");
    $reporter->pass("A pass message");
    $reporter->fail("A fail message");
    $reporter->skip("A skip message");
    $reporter->warn("A warn message");
    $reporter->summary;
}

pass("Run with -d option for additional debugging");
