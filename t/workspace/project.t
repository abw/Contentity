#============================================================= -*-perl-*-
#
# t/workspace/project.t
#
# Test project loading functionality.
#
# Written by Andy Wardley, October 2012, May 2013
#
#========================================================================

use Badger
    lib        => '../../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 7,
    debug => 'Contentity::Project',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->dir( test_files => projects => 'alpha' );
my $project = Contentity::Project->new( 
    root           => $root,
    component_path => 'Wibble::Component',
);
ok( $project, "created contentity project: $project" );


#-----------------------------------------------------------------------------
# URIs
#-----------------------------------------------------------------------------

my $uri = $project->uri;
is( $project->urn, 'alpha', 'project urn is alpha' );
is( $project->uri, 'alpha', 'project uri is alpha' );
is( $project->uri('wibble'), 'alpha/wibble', 'project relative uri is project:alpha/wibble' );
is( $project->uri('/wobble'), 'alpha/wobble', 'project absolute uri is project:alpha/wobble' );


#-----------------------------------------------------------------------------
# Directories
#-----------------------------------------------------------------------------

my $dir = $project->dir;
is( $dir, $root, 'project root directory is ' . $root );

my $ptmp = $project->dir('tmp');
my $rtmp = $root->dir('tmp');
is( $ptmp, $rtmp, 'project tmp directory is ' . $rtmp );


#-----------------------------------------------------------------------------
# Sitemap
#-----------------------------------------------------------------------------

__END__

TODO: fix the rest of this

#-----------------------------------------------------------------------------
# Config files
#-----------------------------------------------------------------------------

my $master = $project->config_file;
is( $master, 'project', 'got master config file: ' . $master );

my $filename = $project->config_filename('urls');
is( $filename, 'urls.yaml', 'got config filename: ' . $filename );

my $file = $project->config_file($filename);
ok( $file->exists, 'got config file: ' . $file->name );

my $urls = $project->config_data('urls');
ok( $urls, 'got config urls' );
is( $urls->{ foo }, '/path/to/foo', 'got foo url: ' . $urls->{ foo });
is( $urls->{ bar }, '/path/to/bar', 'got bar url: ' . $urls->{ bar });
ok( ! $urls->{ baz }, 'no baz url');
ok( ! $urls->{'admin/user' }, 'no admin/user url');
#print "urls: ", main->dump_data($urls), "\n";

my $tree = $project->config_tree('urls');
ok( $tree, 'got config urls tree' );
is( $tree->{ foo }, '/path/to/foo', 'got foo url in tree: ' . $tree->{ foo });
is( $tree->{ bar }, '/path/to/bar', 'got bar url in tree: ' . $tree->{ bar });
is( $tree->{ admin }->{'/baz'}, '/path/to/baz', 'got admin/baz url in tree: ' . $tree->{ admin }->{'/baz'});
is( $tree->{ admin }->{ user }, '/path/to/user/admin', 'got admin/user url in tree: ' . $tree->{ admin }->{ user });
#print "urls: ", main->dump_data($tree), "\n";

$tree = $project->config_uri_tree('urls');
ok( $tree, 'got config urls uri tree' );
is( $tree->{ foo }, '/path/to/foo', 'got foo url in uri tree: ' . $tree->{ foo });
is( $tree->{ bar }, '/path/to/bar', 'got bar url in uri tree: ' . $tree->{ bar });
is( $tree->{'/baz'}, '/path/to/baz', 'got /baz url in tree: ' . $tree->{'/baz'});
is( $tree->{'/admin/user'}, '/path/to/user/admin', 'got admin/user url in tree: ' . $tree->{'/admin/user'});
#print "urls: ", main->dump_data($tree), "\n";


#-----------------------------------------------------------------------------
# General config data
#-----------------------------------------------------------------------------

is( $project->greeting, "hello world!", 'Project config greeting' );


#-----------------------------------------------------------------------------
# Components
#-----------------------------------------------------------------------------

#my $wibble1 = $project->component('wibble');
my $frusset = $project->frusset;
ok( $frusset, 'You have pleasantly wibbled my frusset pouch' );
#my $frusset = $project->component('frusset');
#print "frusset: $frusset\n";


__END__
my $form = $project->resource_data( 
    forms => 'wibble.yaml' 
);
ok( $form, "fetched form data: $form" );

pass("calling wibble");
wibble();
pass("returned from wibble");

sub wibble {
    my $project = Contentity::Project->new( root => $root );
    my $db1     = $project->module( database => { wibble => 'frusset pouch' } );
    my $db2     = $project->module( database => { wibble => 'another pouch' } );
    ok( $db1, 'got database module' );
    ok( $db2, 'got database module again' );
    ok( $db1 == $db2, "same database returned: $db1" );
}
