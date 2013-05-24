#============================================================= -*-perl-*-
#
# t/utils.t
#
# Test functionality in the Contentity::Utils module
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib   => '../lib',
    Debug => [import => ':all'];

use Badger::Test
    tests => 8,
    debug => 'Contentity::Utils',
    args  => \@ARGV;

use Contentity::Utils 'list_each hash_each H';


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

