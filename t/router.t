#============================================================= -*-perl-*-
#
# t/router.t
#
# Test Contentity::Router
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 26,
    debug => 'Contentity::Router',
    args  => \@ARGV;

use Contentity::Router;
use constant ROUTER => 'Contentity::Router';


#-----------------------------------------------------------------------------
# Instantiate router object
#-----------------------------------------------------------------------------

my $router = ROUTER->new;
ok( $router, "created contentity router: $router" );

$router->add_routes(
	'foo' 								=> 'test1',
	'/foo/bar'							=> 'test2',
	'/foo/baz//*'						=> 'test3',
	'/foo/bam?wiz=bang&x=int#wibble' 	=> 'test4',
	'/product/:id'                      => 'product.info',
	'/product/*'                        => 'product.index',
	'/user/:id::integer'                => 'user.info_id',
	'/user/:email::email'               => 'user.info_email',
	'/user/add'                         => 'user.add',
	'/user/?!add'                        => 'user.add',
);

main->debug(
	"routes: ", 
	main->dump_data($router->routes)
);