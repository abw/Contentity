#============================================================= -*-perl-*-
#
# t/misc/template.t
#
# Test Contentity::Tempalte module.
#
# Written by Andy Wardley, March 2014
#
#========================================================================

use Badger
    lib      => '../../lib';

use Badger::Test
    tests    => 7,
    debug    => 'Contentity::Template',
    args     => \@ARGV;

use constant
    TEMPLATE => 'Contentity::Template';

use Contentity::Template;

my $ct = TEMPLATE->new;
ok( $ct, "created a template object: $ct" );

ct_expr($ct, "foo.lc",      { foo => 'HELLO' }, "hello");
ct_expr($ct, "foo.lower",   { foo => 'HELLO' }, "hello");
ct_expr($ct, "foo.lcfirst", { foo => 'HELLO' }, "hELLO");
ct_expr($ct, "foo.upper",   { foo => 'hello' }, "HELLO");
ct_expr($ct, "foo.uc",      { foo => 'hello' }, "HELLO");
ct_expr($ct, "foo.ucfirst", { foo => 'hello' }, "Hello");


sub ct_expr {
    my ($ct, $expr, $vars, $expect, $message) = @_;
    my $result = $ct->render(\"[% $expr %]", $vars);
    is( $result, $expect, $message || $expr);
}
