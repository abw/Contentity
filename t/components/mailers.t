#============================================================= -*-perl-*-
#
# t/components/mailers.t
#
# Test the Contentity::Component::Mailers module.
#
# Written by Andy Wardley, March 2016
#
#========================================================================

use Badger
    lib   => '../../lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 5,
    debug => 'Contentity::Component::Mailers Badger::Factory',
    args  => \@ARGV;

use Contentity::Project;
use warnings FATAL => 'all';

my $root    = Bin->dir( test_files => 'comps1' );
my $project = Contentity::Project->new(
    root => $root,
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch a mailers factory object
#-----------------------------------------------------------------------------
my $mailers = $project->component('mailers');
ok( $mailers, "got a mailers factor: $mailers" );


#-----------------------------------------------------------------------------
# fetch the regular SMTP mailer
#-----------------------------------------------------------------------------
my $smtp = $mailers->mailer('smtp');
ok( $smtp, "got smtp mailer" );
is( ref $smtp, 'Contentity::Component::Mailer::Smtp', "SMTP mailer is $smtp" );
is( $smtp->mailhost, 'testing1.wardley.org', 'got correct mailhost' );
