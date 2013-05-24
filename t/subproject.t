#============================================================= -*-perl-*-
#
# t/subproject.t
#
# Test sub-projects loaded by a master project.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 16,
    debug => 'Contentity::Project',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Instantiate master project object
#-----------------------------------------------------------------------------

my $root    = Bin->parent->dir( t => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root        => $root,
    component_path => 'Wibble::Component',
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch sub-project
#-----------------------------------------------------------------------------

my $sub = $project->project('bravo');

ok( $sub, 'got sub-project' );
is( $sub->name, 'The Bravo Project', 'got project name' );
is( $sub->mastermsg, 'The master message', 'got master project message' );


#-----------------------------------------------------------------------------
# Check that a config tree merge includes both slave and master project
#-----------------------------------------------------------------------------

my $tree = $sub->config_uri_tree('urls');
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

my $chas = $sub->project('charlie');
ok( $chas, 'got charlie project' );
is( $chas->greeting, 'Charlie greeting' );

my $harry = $chas->entity('harry');
ok( $harry, 'got harry entity' );

my $barry = $chas->entity('barry');
ok( $barry, 'got barry entity' );

