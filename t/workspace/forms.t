#============================================================= -*-perl-*-
#
# t/workspace/forms.t
#
# Test Contentity::Component::Forms
#
# Written by Andy Wardley March 2014
#
#========================================================================

use Badger
    lib        => 'lib ../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 7,
    debug => 'Contentity::Config',
    args  => \@ARGV;

use Contentity::Project;

#-----------------------------------------------------------------------------
# Instantiate project object
#-----------------------------------------------------------------------------

my $root    = Bin->dir( test_files => projects => 'alpha' );
my $project = Contentity::Project->new(
    root    => $root,
    schemas => {
        forms => {
            singleton => 1,
        }
    }
);
ok( $project, "created contentity project: $project" );

my $forms1 = $project->forms;
ok( $forms1, "got forms component: $forms1" );

my $forms2 = $project->forms;
ok( $forms2, "got forms component: $forms2" );

is( $forms1, $forms2, 'got same forms reference' );

my $form = $project->form( 'wibble', message => 'Frusset Pouch' );
ok( $form, "got wibble form: $form" );

#-----------------------------------------------------------------------------
# get fields
#-----------------------------------------------------------------------------

my $fields = $project->form_fields;
ok( $fields, "got form fields" );
my $field = $fields->field( date => { name => 'test' } );
ok( $field, "got date field: $field" );
