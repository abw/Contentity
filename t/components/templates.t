#============================================================= -*-perl-*-
#
# t/components/templates.t
#
# Test templates component.
#
# Written by Andy Wardley, May 2013, March 2014
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 2,
    debug => 'Contentity::Project Contentity::Component::Templates',
    args  => \@ARGV;

use Contentity::Project;


#-----------------------------------------------------------------------------
# Fetch hotel site
#-----------------------------------------------------------------------------

my $root  = Bin->parent->dir( workspace => test_files => projects => 'alpha' );
my $hotel = Contentity::Project->new(
    root => $root,
);
ok( $hotel, "created hotel site: $hotel" );


#-----------------------------------------------------------------------------
# Fetch templates component
#-----------------------------------------------------------------------------

my $templates = $hotel->templates;
ok( $templates, "got site templates: $templates" );
