#============================================================= -*-perl-*-
#
# t/config.t
#
# Test reading of configuration data.
#
# Written by Andy Wardley, June 2013
#
#========================================================================

use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 4,
    debug => 'Contentity::Project',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Fetch project
#-----------------------------------------------------------------------------

my $root    = Bin->parent->dir( t => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root => $root,
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# Fetch some config data defined in the main config file.
#-----------------------------------------------------------------------------

my $msg = $project->config("mastermsg");
ok( $msg, 'got mastermsg config value' );
is( $msg, 'The master message', "message is $msg" );

my $more = $project->config("more_stuff");
ok( $more, 'got more stuff from config' );
is( $more->{ foo }, 10, "got nested value foo" );
is( $more->{ bar }, "The bar value", "got nested value bar" );
is( $more->{ baz }->{ frusset }, "pouch", "got nested value baz.frusset" );

is( $project->config("more_stuff.foo"), 10, "got more_stuff.foo" );
is( $project->config("more_stuff.bar"), "The bar value", "got more_stuff.bar" );
is( $project->config("more_stuff.baz.frusset"), "pouch", "got more_stuff.baz.frusset" );

#-----------------------------------------------------------------------------
# Load config data from extra config file
#-----------------------------------------------------------------------------

my $prefs = $project->config('prefs');
ok( $prefs, 'got prefs' );
is( $prefs->{ beer }, 'Tangle Foot', 'A nice glass of beer' );
is( $project->config('prefs.transport'), 'Skateboard', 'Got my skateboard' );


#-----------------------------------------------------------------------------
# Fetch metadata
#-----------------------------------------------------------------------------

# Hmmm... no, this is right.  Everything is metadata, including config data.
# It's only when we get to sites that we want to store metadata about the
# site (suitable for using in templates) separately from the config data.
# Hmmm... on second thoughts, I'm not even sure about that any more.

#my $meta = $project->metadata;
#ok( $meta, 'got site metadata' );
