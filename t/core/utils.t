#============================================================= -*-perl-*-
#
# t/core/utils.t
#
# Test functionality in the Contentity::Utils module
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib   => '../../lib',
    Debug => [import => ':all'];

use Badger::Test
    tests => 29,
    debug => 'Contentity::Utils',
    args  => \@ARGV;

use Contentity::Utils 'list_each hash_each H Timestamp';


#-----------------------------------------------------------------------------
# List functions
#-----------------------------------------------------------------------------

my $list = [ 'zero', 'one', 'two' ];

list_each(
    $list,
    sub {
        my ($list, $key, $value) = @_;
        $list->[$key] = "#$key:$value";
    }
);
is( join(',', @$list), '#0:zero,#1:one,#2:two', 'list_each()' );


#-----------------------------------------------------------------------------
# Hash functions
#-----------------------------------------------------------------------------

my $hash = { a => 'alpha', b => 'bravo', c => 'charlie' };

hash_each(
    $hash,
    sub {
        my ($hash, $key, $value) = @_;
        $hash->{$key} = "#$key:$value";
    }
);

is(
    join(',', map { $hash->{$_} } sort keys %$hash),
    '#a:alpha,#b:bravo,#c:charlie', 'hash_each()'
);

#-----------------------------------------------------------------------------
# Timestamps
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# HTML generation
#-----------------------------------------------------------------------------

is( H('br'), '<br>', 'empty element' );

is( H( img => { src => 'foo.gif' } ), '<img src="foo.gif">', 'img tag' );

my $html = H(
    h1 => 'Hello World'
);
is( $html, "<h1>Hello World</h1>", 'simple html generation' );

$html = H(
    ul => { class => 'menu' },
    [ li => 'One' ],
    [ li => 'Two' ],
    [ li => 'Three' ],
);
is(
    $html,
    q{<ul class="menu"><li>One</li><li>Two</li><li>Three</li></ul>},
    'html menu generation'
);

is (
    H('i.icon', 'foo'), '<i class="icon">foo</i>', 'HTML shortcut for .class'
);
is (
    H('i#icon', 'foo'), '<i id="icon">foo</i>', 'HTML shortcut for #id'
);

#-----------------------------------------------------------------------------
# Contentity::Colour
#-----------------------------------------------------------------------------

use Contentity::Utils 'Colour';

my $orange = Colour('#ff7f00');
ok( $orange, "got orange: $orange" );



#-----------------------------------------------------------------------------
# canonical_time
#-----------------------------------------------------------------------------

use Contentity::Utils 'canonical_time';

test_time('7',          '07:00:00');
test_time('730',        '07:30:00');
test_time('7.31',       '07:31:00');
test_time('7:32',       '07:32:00');
test_time('0733',       '07:33:00');
test_time('8am',        '08:00:00');
test_time('8.10am',     '08:10:00');
test_time('8 20am',     '08:20:00');
test_time('10',         '10:00:00');
test_time('10.30',      '10:30:00');
test_time('1030',       '10:30:00');
test_time('10.30.20',   '10:30:20');
test_time('10:30:1',    '10:30:01');
test_time('10am',       '10:00:00');
test_time('10 a.m.',    '10:00:00');
test_time('230pm',      '14:30:00');
test_time('10pm',       '22:00:00');
test_time('10PM',       '22:00:00');
test_time('23',         '23:00:00');
test_time('2330',       '23:30:00');

sub test_time {
    my ($input, $expect) = @_;
    my $output = canonical_time($input);
    is( $output, $expect, "parsed time: $input => $output" );
}


__END__
#-----------------------------------------------------------------------------
# cmd()
#-----------------------------------------------------------------------------

use Contentity::Utils 'cmd filter_cmd';

cmd( echo => 'hello world' );
my $output = filter_cmd(
    "some text\nmore text\nblah de blah", wc => '-l' );
print "output: $output\n";

my $input = <<EOF;
<html>
  <head>
    <title>Example</title>
  </head>
  <body>
    Hello World!
  </body>
</html>
EOF

my $styled = filter_cmd(
    $input, highlights => -s => 'source.html'
);

print "styled: $styled\n";
