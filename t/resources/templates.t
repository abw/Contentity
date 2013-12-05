#============================================================= -*-perl-*-
#
# t/templates.t
#
# Test templates component.
#
# Written by Andy Wardley, May 2013
#
#========================================================================

use lib '/home/abw/projects/badger/lib';
use Badger
    lib        => '../lib lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 6,
    debug => 'Contentity::Project Contentity::Component::Templates',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Fetch hotel site
#-----------------------------------------------------------------------------

my $root = Bin->parent->dir( t => projects => 'alpha' );
my $base = Contentity::Project->new( 
    root => $root,
);
ok( $base, "created contentity base site: $base" );

my $hotel = $base->site('hotel');
ok( $hotel, 'got hotel site' );


#-----------------------------------------------------------------------------
# Fetch templates component
#-----------------------------------------------------------------------------

my $templates = $hotel->templates;
ok( $templates, "got site templates: $templates" );

my $app_templates = $hotel->app_templates;
ok( $app_templates, "got site app templates: $app_templates" );

#-----------------------------------------------------------------------------
# Fetch a template or two
#-----------------------------------------------------------------------------

my $foo = $app_templates->template_file('foo');
ok( $foo->exists, 'foo template found');

my $bar = $app_templates->template_file('bar');
ok( $bar->exists, 'bar template found');

#print "FOO: ", $app_templates->render('foo');
#print "BAZ: ", $app_templates->render( baz  => { state => 'California' } );


#my $engine = $app_templates->engine;
#print "ENGINE: $engine\n";
#print "RENDER: ", 
#$engine->process("foo") || die $engine->error;
