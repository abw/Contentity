#============================================================= -*-perl-*-
#
# t/core/path.t
#
# Test the Contentity::Path module
#
# Written by Andy Wardley, April 2014
#
#========================================================================

use Badger
    lib   => '../../lib',
    Debug => [import => ':all'];

use Badger::Test
    tests => 34,
    debug => 'Contentity::Path',
    args  => \@ARGV;

use Contentity::Path 'Path';

#-----------------------------------------------------------------------------
# short path
#-----------------------------------------------------------------------------

my $p = Path('/hello/world');
ok( $p, 'got path' );
is( $p, '/hello/world','autostringification returns path' );
is( $p->path, '/hello/world','path() method returns path' );
ok( $p->abs, 'path is absolute' );
ok( ! $p->dir, 'path is not a directory' );
is( $p->more, 2, 'two more to come' );

my $h = $p->take_next;
is( $h, 'hello', 'first component is hello' );
is( $p->done, 'hello', 'hello is done' );
is( $p->todo, 'world', 'world is todo' );
is( $p->next, 'world', 'world is next' );
is( $p->path_done, '/hello', '/hello is path done' );
is( $p->path_todo, 'world', 'world is path todo' );
is( $p->more, 1, 'one more to come' );
$p->take_next;
is( $p->more, 0, 'none, none more to come' );


#-----------------------------------------------------------------------------
# longer path
#-----------------------------------------------------------------------------

$p = Path('hello/to/the/world/');
ok( $p, 'got longer path' );
is( $p, 'hello/to/the/world/','autostringification returns longer path' );
is( $p->path, 'hello/to/the/world/','path() method returns longer path' );
ok( ! $p->abs, 'path is not absolute' );
ok( $p->dir, 'path is a directory' );
is( $p->path_done, '', 'nothing in path done');
is( $p->path_todo, 'hello/to/the/world/', 'everything in path todo');

$h = $p->take_next;
is( $h, 'hello', 'first component is hello' );
$h = $p->take_next;
is( $h, 'to', 'next component is hello' );

is( $p->done, 'hello/to', 'hello/to is done' );
is( $p->todo, 'the/world', 'the/world is todo' );
is( $p->next, 'the', 'world is next' );
is( $p->path_done, 'hello/to', 'hello/to in path done');
is( $p->path_todo, 'the/world/', 'the/world/ in path todo');
is( $p->more, 2, 'two more to come' );

my $rest = $p->take_all;
is( $rest, 'the/world/', 'take_all got the/world/');
is( $p->done, 'hello/to/the/world', 'all done' );
is( $p->path_done, 'hello/to/the/world/', 'path done' );
is( $p->todo, '', 'nothing left todo');
is( $p->path_todo, '', 'nothing left in path todo');



1;
