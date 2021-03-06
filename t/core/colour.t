#============================================================= -*-perl-*-
#
# t/core/colour.t
#
# Test the Contentity::Colour module.
#
# Written by Andy Wardley, October 2012, May 2013, April 2014
#
#========================================================================

use Badger
    lib        => '../../lib',
    Filesystem => 'Bin',
    Debug      => [import => ':all'];

use Badger::Test
    tests => 93,
    debug => 'Contentity::Colour',
    args  => \@ARGV;

use Contentity::Colour 'Colour Color';
use constant Col => 'Contentity::Colour';

my $orange;

#-----------------------------------------------------------------------
# test rgb constructor
#-----------------------------------------------------------------------

$orange = Col->new('#ff7f00');
ok( $orange, 'got orange colour from hex triplet' );
is( $orange->red(), 255, 'orange red 255' );
is( $orange->green(), 127, 'orange green 127' );
is( $orange->blue(), 0, 'orange blue 0' );

$orange = Col->new( rgb => '#fe7e01' );
ok( $orange, 'got orange colour from hex triplet named param' );
is( $orange->red(), 254, 'orange red 254' );
is( $orange->green(), 126, 'orange green 126' );
is( $orange->blue(), 1, 'orange blue 1' );

$orange = Col->new( rgb => [253, 125, 2] );
ok( $orange, 'got orange colour RGB named param' );
is( $orange->red(), 253, 'orange red 253' );
is( $orange->green(), 125, 'orange green 125' );
is( $orange->blue(), 2, 'orange blue 2' );

$orange = Col->new({ rgb => [252, 124, 3] });
ok( $orange, 'got orange colour RGB param hash' );
is( $orange->red(), 252, 'orange red 252' );
is( $orange->green(), 124, 'orange green 124' );
is( $orange->blue(), 3, 'orange blue 3' );

$orange = Col->new( red => 251, green => 123, blue => 4 );
ok( $orange, 'got orange colour RGB named red, green, blue params' );
is( $orange->red(), 251, 'orange red 251' );
is( $orange->green(), 123, 'orange green 123' );
is( $orange->blue(), 4, 'orange blue 4' );

$orange = Col->RGB( 250, 122, 5 );
ok( $orange, 'got orange from RGB method' );
is( $orange->red(), 250, 'orange red 250' );
is( $orange->green(), 122, 'orange green 122' );
is( $orange->blue(), 5, 'orange blue 5' );

#-----------------------------------------------------------------------
# test HSV constructor
#-----------------------------------------------------------------------

$orange = Col->new('#FF7F00')->hsv;
is( $orange->hue, 30, 'orange hue is 30' );
is( $orange->percent, '30/100%/100%', 'orange H/S/V percent' );

$orange = Col->new( hsv => [24, 255, 255] );
ok( $orange, 'got orange from hsv' );
is( $orange->hue(), 24, 'orange hue 24' );
is( $orange->sat(), 255, 'orange sat 255' );
is( $orange->val(), 255, 'orange val 255' );

$orange = Col->new( hue => 25, sat => 254, val => 253 );
ok( $orange, 'got orange from hue, etc' );
is( $orange->hue(), 25, 'orange hue 25' );
is( $orange->sat(), 254, 'orange sat 254' );
is( $orange->val(), 253, 'orange val 253' );



#-----------------------------------------------------------------------
# test copy constructor
#-----------------------------------------------------------------------

my $copy = Col->new($orange);
ok( $orange, 'got orange from copy constructor' );
is( $orange->hue(), 25, 'orange copy hue 25' );
is( $orange->sat(), 254, 'orange copy sat 254' );
is( $orange->val(), 253, 'orange copy val 253' );
$orange->hue(30);
is( $orange->hue(), 30, 'set orange hue to 30' );
is( $copy->hue(), 25, 'copy still has hue set to 25' );

$orange = Col->RGB( 249, 121, 6 );
$copy = Col->new($orange);
ok( $orange, 'got orange from RGB copy constructor' );
is( $orange->red(), 249, 'orange copy red 249' );
is( $orange->green(), 121, 'orange copy green sat 121' );
is( $orange->blue(), 6, 'orange copy blue 6' );
$orange->red(220);
is( $orange->red(), 220, 'set orange red to 220' );
is( $copy->red(), 249, 'copy still has red set to 249' );

isnt( $copy, $orange, 'different objects again' );


#-----------------------------------------------------------------------------
# Test contructor function
#-----------------------------------------------------------------------------

$orange = Colour('#ff7f00');
ok( $orange, 'got colour via Colour() function');

$orange = Color('#ff7f00');
ok( $orange, 'got colour via Color() function');


#-----------------------------------------------------------------------------
# test ability to parse rgb() and rgba() formats
#-----------------------------------------------------------------------------


$orange = Color('rgb(255,127,0)');
ok( $orange, 'got colour via Color(rgb(255,127,0)) function');
is( $orange->red, 255, 'rgb() red is 255' );
is( $orange->green, 127, 'rgb() green is 127' );
is( $orange->blue, 0, 'rgb() blue is 0' );

$orange = Color('rgb(100%,50%,0)');
ok( $orange, 'got colour via Color(rgb(100%,50%,0)) function');
is( $orange->red, 255, 'rgb(%) red is 255' );
is( $orange->green, 127, 'rgb(%) green is 127' );
is( $orange->blue, 0, 'rgb(%) blue is 0' );

$orange = Color('rgba(100%,50%,0,0.25)');
ok( $orange, 'got colour via Color(rgba(100%,50%,0,0.5)) function');
is( $orange->red, 255, 'rgba() red is 255' );
is( $orange->green, 127, 'rgba() green is 127' );
is( $orange->blue, 0, 'rgba() blue is 0' );
is( $orange->alpha, 0.25, 'rgba() alpha is 0.25' );


#-----------------------------------------------------------------------
# test colour range
#-----------------------------------------------------------------------

$orange = Col->RGB('#ff8800');
my $range = $orange->range(7, '#8811EE');
is( $range->[0]->HTML, '#FF8800', 'range 0' );
is( $range->[1]->HTML, '#EE7722', 'range 1' );
is( $range->[2]->HTML, '#DD6644', 'range 2' );
is( $range->[3]->HTML, '#CC5566', 'range 3' );
is( $range->[4]->HTML, '#BB4488', 'range 4' );
is( $range->[5]->HTML, '#AA33AA', 'range 5' );
is( $range->[6]->HTML, '#9922CC', 'range 6' );
is( $range->[7]->HTML, '#8811EE', 'range 7' );

#-----------------------------------------------------------------------
# test colour scheme
#-----------------------------------------------------------------------

$orange = Col->RGB('#ff8800');
my $scheme = $orange->scheme();
is( $scheme->{ black    }, '#000000', 'black is black'  );
is( $scheme->{ darkest  }, '#331b00', 'darkest orange'  );
is( $scheme->{ darker   }, '#663600', 'darker orange'   );
is( $scheme->{ dark     }, '#995100', 'dark orange'     );
is( $scheme->{ darkish  }, '#cc6c00', 'darkish orange'  );
is( $scheme->{ mid      }, $orange, 'mid is orange'     );
is( $scheme->{ lightish }, '#ff9f33', 'lightish orange' );
is( $scheme->{ light    }, '#ffb766', 'light orange'    );
is( $scheme->{ lighter  }, '#ffcf99', 'lighter orange'  );
is( $scheme->{ lightest }, '#ffe7cc', 'lightest orange' );
is( $scheme->{ white    }, '#ffffff', 'white is white'  );


#-----------------------------------------------------------------------------
# test colour mix
#-----------------------------------------------------------------------------

my $white = Colour('#fff');
my $black = Colour('#000');
my $grey  = $white->mix($black);
ok( $grey, "mixed white with black to get grey" );
is( $grey, '#7f7f7f', "grey is $grey" );

$grey  = $white->mix($black, 0.25);
is( $grey, '#bfbfbf', "white mixed with 0.25 black is $grey" );

$grey  = $white->mix($black, '75%');
is( $grey, '#3f3f3f', "white mixed with black at 75% is $grey" );


#-----------------------------------------------------------------------------
# test darken, lighten and trans
#-----------------------------------------------------------------------------

$orange = Col->RGB('ff8000');
my $orange1 = $orange->lighten('20%');
my $orange2 = $orange->lighten(20);
my $orange3 = $orange->lighten(0.2);
my $orange4 = $orange->lighten20;

is( $orange1, '#ff9933', 'lightened orange by 20%');
is( $orange2, '#ff9933', 'lightened orange by 20');
is( $orange3, '#ff9933', 'lightened orange by 0.2');
is( $orange4, '#ff9933', 'lightened orange by lighten20');

my $opaque1 = $orange->opaque(10);
is( $opaque1, 'rgba(255,128,0,0.1)', 'orange opaque(10)' );

my $opaque2 = $orange->opaque20;
is( $opaque2, 'rgba(255,128,0,0.2)', 'orange.opaque20' );

my $trans1 = $orange->transparent(10);
is( $trans1, 'rgba(255,128,0,0.9)', 'orange trans(10)' );

my $trans2 = $orange->transparent20;
is( $trans2, 'rgba(255,128,0,0.8)', 'orange.trans20' );
