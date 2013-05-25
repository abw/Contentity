#============================================================= -*-perl-*-
#
# t/sites.t
#
# Test sites loaded by a master project.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 21,
    debug => 'Contentity::Project Contentity::Site',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $root    = Bin->parent->dir( t => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root => $root,
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch echo site
#-----------------------------------------------------------------------------

my $echo = $project->site('echo');

ok( $echo, 'got echo site' );
is( $echo->name, 'The Echo Site', 'got echo site name' );
is( $echo->greeting, 'Hello from the echo site', 'got echo greeting' );
is( $echo->mastermsg, 'The master message', 'got echo master project message' );


#-----------------------------------------------------------------------------
# Fetch foxtrot site, based on echo site
#-----------------------------------------------------------------------------

my $fox = $project->site('foxtrot');

ok( $fox, 'got foxtrot site' );
is( $fox->name, 'The Foxtrot Site', 'got foxtrot site name' );
is( $fox->greeting, 'Hello from the foxtrot site', 'got foxtrot greeting' );
is( $fox->mastermsg, 'The master message', 'got foxtrot master project message' );
is( $fox->master->name, 'The Echo Site', 'foxtrot is a slave of echo' );


__END__
my $fox = $sub->config_uri_tree('urls');
ok( $tree, 'got config urls uri tree' );

# URLs defined by master project
is( $tree->{ foo }, '/path/to/foo', 'got foo url in uri tree: ' . $tree->{ foo });
is( $tree->{ bar }, '/path/to/bar', 'got bar url in uri tree: ' . $tree->{ bar });
is( $tree->{'/baz'}, '/path/to/baz', 'got /baz url in tree: ' . $tree->{'/baz'});
is( $tree->{'/admin/user'}, '/path/to/user/admin', 'got admin/user url in tree: ' . $tree->{'/admin/user'});

# URLs defined by slave project
is( $tree->{ bravo1 }, '/path/to/bravo1', 'got bravo1 url in uri tree: ' . $tree->{ bravo1 });
is( $tree->{'/bravo3'}, '/path/to/bravo3', 'got /bravo3 url in tree: ' . $tree->{'/bravo3'});
is( $tree->{'/admin/bravo2'}, '/path/to/admin/bravo2', 'got /admin/bravo2 url in tree: ' . $tree->{'/admin/bravo2'});

#print "urls: ", main->dump_data($tree), "\n";


#-----------------------------------------------------------------------------
# Fetch another sub-project
#-----------------------------------------------------------------------------

my $chas = $project->project('charlie');
ok( $chas, 'got charlie project' );
is( $chas->greeting, 'Charlie greeting', 'got charlie greeeting' );

my $harry = $chas->entity('harry');
ok( $harry, 'got harry entity' );

my $barry = $chas->entity('barry');
ok( $barry, 'got barry entity' );

is( $chas->mastermsg, 'The master message', 'chas got alpha message' );


#-----------------------------------------------------------------------------
# Fetch a sub-project that declares that it's based on another project
#-----------------------------------------------------------------------------

my $delta = $project->project('delta');
ok( $delta, 'got delta project' );
is( $delta->greeting, 'Delta greeting', 'got delta greeeting' );

is( $delta->mastermsg, 'The master message', 'delta got alpha message' );
is( $delta->charliemsg, 'Charlie says hi!', 'got charlie message' );


