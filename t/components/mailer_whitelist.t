#============================================================= -*-perl-*-
#
# t/components/mailer_whitelist.t
#
# Test the Contentity::Component::Mailers module with the whitelist
# configuration option for overriding the force_send_to option.
#
# Written by Andy Wardley, October 2026
#
#========================================================================

use Badger
    lib   => '../../lib',
    Utils => 'Bin',
    Debug => [import => ':all'];

use Badger::Test
    tests => 8,
    debug => 'Contentity::Component::Mailers Badger::Factory',
    args  => \@ARGV;

use Contentity::Project;
use warnings FATAL => 'all';

my $root    = Bin->dir( test_files => 'comps1' );
my $project = Contentity::Project->new(
    root => $root,
    email => {
        mailers => {
            test1 => {
                sender_type => 'smtp2',
                mailhost    => 'smtp.ourshack.com',
                username    => 'abw-test',
                password    => 'expect-this-to-fail',
                encoding    => 'UTF-8',
                force_send_to => 'abw@wardley.org',
                force_send_subject => "%s (dev server redirect)",
                whitelist    => [
                    'tommy-tester@wardley.org',
                    '*@nowhere.com',
                ],
            }
        },
        default_mailer => 'test1'
    }
);
ok( $project, "created contentity project: $project" );


my $mailer = $project->mailer;
ok( $mailer, "Got mailer: $mailer" );

ok( $mailer->whitelisted_address('tommy-tester@wardley.org'), 'whitelisted address' );
ok( ! $mailer->whitelisted_address('bad-guy@wardley.org'), 'non-whitelisted address' );
ok( $mailer->whitelisted_address('anyone@nowhere.com'), 'whitelisted wildcard address' );
ok( ! $mailer->whitelisted_address('nowhere.com'), 'did not match wildcard address with no first part' );
ok( ! $mailer->whitelisted_address('abw@wardley.org'), 'did not match wildcard address' );
ok( ! $mailer->whitelisted_address('*@nowhere.com'), 'did not match literal wildcard address' );

#-----------------------------------------------------------------------------
# Fetch a mailers factory object
#-----------------------------------------------------------------------------
# my $mailers = $project->component('mailers');
# ok( $mailers, "got a mailers factor: $mailers" );
#
#
# #-----------------------------------------------------------------------------
# # fetch the regular SMTP mailer
# #-----------------------------------------------------------------------------
# my $test1 = $mailers->mailer('test1');
# ok( $smtp2, "got smtp2 mailer" );
# is( ref $smtp2, 'Contentity::Component::Mailer::Smtp', "SMTP mailer is $smtp2" );
# #is( $smtp->mailhost, 'testing1.wardley.org', 'got correct mailhost' );

