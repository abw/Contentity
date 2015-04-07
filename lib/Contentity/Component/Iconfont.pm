package Contentity::Component::Iconfont;

use Contentity::Template;
use Contentity::Class
    version   => 0.04,
    debug     => 0,
    base      => 'Contentity::Component',
    utils     => 'green cyan red',
    accessors => 'verbose glyphs icons data',
    constant  => {
        ENGINE     => 'Contentity::Template',
        PROGRAM    => 'Contentity/Iconfont',
        AUTHOR     => 'Andy Wardley',
        DATE       => 'March 2012 - April 2014',
        WIDTH      => 2048,
        HEIGHT     => 2048,
        UNIBASE    => 0xf500,
        ADVANCE    => 512,
        GLYPH_SVG  => 'glyph.svg',
        FONT_SVG   => 'font.svg',
        ICONS_YAML => 'icons.yaml',
    };


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( iconfont => $config ) if DEBUG;
    $self->{ verbose } = $config->{ verbose };
    $self->{ unibase } = $self->UNIBASE;
    $self->{ data    } = $config;
    return $self;
}

#-----------------------------------------------------------------------------
# Methods to parse Font Awesome CSS file to extract mappings from name to code
# points.  We're looking for entries like this:
#
#  .fa-rotate-right:before,
#  .fa-repeat:before {
#    content: "\f01e";
#  }
#-----------------------------------------------------------------------------

sub parse_css {
    my ($self, $file) = @_;
    my $text = $file->text;
    my $name_to_point = { };
    my $point_to_name = { };
    my (@pairs, $pair);

    $self->debug("parsing CSS text: $text") if DEBUG;

    while ($text =~ /^(.fa-[^}]*?){\s*content:\s*"\\(.*?)";\s}/gms) {
        push(@pairs, [$1, $2]);
        next;
    }

    foreach $pair (@pairs) {
        my ($names, $point) = @$pair;

        foreach my $name ($self->parse_css_names($names)) {
            $name_to_point->{ $name  } = $point;
            $point_to_name->{ $point } = $name;
            print "  $name -> $point -> $name\n" if DEBUG;
        }
    }
    return $self->{ icons } = {
        names  => $name_to_point,
        points => $point_to_name,
    };
}

sub parse_css_names {
    my ($self, $text) = @_;
    my @names;

    while ($text =~ /fa-(.*?):/gms) {
        print "  + [$1]\n" if DEBUG;
        push(@names, $1);
    }
    return @names;
}


#-----------------------------------------------------------------------------
# Extract glyphs from SVG file
#-----------------------------------------------------------------------------

sub extract_glyphs {
    my ($self, $infile, $outdir, $source) = @_;
    my $glyphs = $self->{ glyphs } = $self->parse_svg_glyphs(
        $infile->text, $source
    );
    $self->generate_svg_glyphs($glyphs, $outdir);
}

sub parse_svg_glyphs {
    my ($self, $svg, $source) = @_;
    my (@glyphs, $glyph);

    while ($svg =~ /(<glyph.*?>)/gis) {
        push(@glyphs, $self->parse_svg_glyph($1, $source));
    }

    return \@glyphs;
}

#-----------------------------------------------------------------------------
# Subroutine for analysing the XML markup for a glyph to extract the data
# Examples:
#  <glyph unicode="&#xf001;" horiz-adv-x="1488" d="M0 213q0 ..etc... 104.5z" />
#  <glyph unicode="&#xf002;" horiz-adv-x="1597" d="M0 901q0 137 ...etc..." />
#-----------------------------------------------------------------------------

sub parse_svg_glyph {
    my ($self, $text, $source) = @_;
    my $map = $self->{ icons };
    my ($id, $hex, $dec, $path, $name, $adv);

    $self->debug_data( MAP => $map ) if DEBUG;

    if ($text =~ /\s+unicode="(.*?)"/is) {
        $id = $1;
        if ($id =~ s/&#x(.*);/$1/) {
            $dec = hex $id;
        }
        else {
            $dec = ord($id)
        }
        $hex = sprintf("%04x", $dec);
    }
    else {
        warn yellow("Missing unicode attribute for glyph: \n  "),
             cyan($text), "\n" if $self->verbose;
        return;
    }
    $name = $map->{ points }->{ $hex } || $hex;

    if ($text =~ /\s+d="(.*?)"/is) {
        $path = $1;
    }
    else {
        warn yellow("No path data in glyph: \n  "),
             cyan($text), "\n" if $self->verbose;
        return;
    }

    if ($text =~ /\s+horiz-adv-x="(.*?)"/is) {
        $adv = $1;
    }

    # SVG font glyphs have inverted co-ordinate system with origin at the
    # bottom left corner instead of top left as per SVG paths.
    #  visibility="hidden"
    #main->debug("[$hex] [$adv] [$path]\n");
    print "$name => $hex\n" if DEBUG;

    return {
        name    => $name,
        hex     => $hex,
        path    => $path,
        advance => $adv,
        source  => $source,
    };
}


#-----------------------------------------------------------------------------
# Method to import additional glyphs
#-----------------------------------------------------------------------------

sub import_glyph_dir {
    my ($self, $srcdir, $outdir, $source) = @_;
    my $files  = $srcdir->files;
    my $glyphs = $self->glyphs;

    foreach my $file (@$files) {
        next unless $file->extension eq 'svg';
        my $glyph = $self->parse_svg_glyph_file($file, $source);
        push(@$glyphs, $glyph);
        print green("  + $file\n") if $self->verbose;
    }
}

sub parse_svg_glyph_file {
    my ($self, $file, $source) = @_;
    my $map    = $self->icons;
    my $base   = $file->basename;
    my $text   = $file->text;
    my $hex    = $map->{ $base } || sprintf("%x", $self->{ unibase }++);
    my $unihex = "&#x$hex;";
    my $info   = {
        name   => $base,
        source => $source,
    };

    $info->{ unicode } = $unihex;
    $info->{ hex     } = $hex;

    if ($text =~ /<path[^>]*?d="(.*?)"[^\/>]*\/>/is) {
        my $path = $1;
        $path =~ s/\s+/ /gs;
        $info->{ path } = $path;
    }
    else {
        print red "No path defined in $base\n";
        print red "I'm going to ignore it.\n";
        print $text, "\n\n";
        return;
    }

    return $info;
}


#-----------------------------------------------------------------------------
# Filtering/mapping glyphs
#-----------------------------------------------------------------------------

sub select_glyphs {
    my ($self, $spec) = @_;
    my $map = $self->glyph_map;
    my @glyphs;

    while (my ($key, $value) = each %$spec) {
        my $glyph = $map->{ $value }
            || return $self->error_msg( invalid => icon_map => "$key => $value" );
        $glyph = { %$glyph, name => $key };
        push(@glyphs, $glyph);
    }
    $self->{ glyphs } = \@glyphs;
    return \@glyphs;
}

sub glyph_map {
    my $self   = shift;
    my $map    = { };
    my $glyphs = $self->glyphs;

    for my $glyph (@$glyphs) {
        my $canon = join('.', $glyph->{ source }, $glyph->{ name });
        $self->debug_data( "$canon glyph" => $glyph ) if DEBUG;
        $map->{ $canon } = $glyph;
    }

    return $map;
}

#=============================================================================
# OUTPUT
#=============================================================================
#-----------------------------------------------------------------------------
# Generate SVG files for each glyph
#-----------------------------------------------------------------------------

sub generate_svg_glyphs {
    my ($self, $glyphs, $outdir) = @_;

    foreach my $glyph (@$glyphs) {
        $self->generate_svg_glyph($glyph, $outdir);
    }

}

sub generate_svg_glyph {
    my ($self, $glyph, $dir) = @_;
    my $name  = $glyph->{ name };
    my $file  = $dir->file( $name . '.svg' );

    $self->process_template_to_file($self->GLYPH_SVG, $glyph, $file);

    print green "  + $name ($glyph->{hex}) => $file\n" if $self->verbose;
}

#-----------------------------------------------------------------------------
# Generate an SVG file containing all the glyphs as a font definition.
#  <glyph unicode="&#xf001;" horiz-adv-x="1488" d="M0 213q0 ..etc... 104.5z" />
#  <glyph unicode="&#xf002;" horiz-adv-x="1597" d="M0 901q0 137 ...etc..." />
#-----------------------------------------------------------------------------

sub generate_svg_font {
    my ($self, $file) = @_;

    $self->process_template_to_file(
        $self->FONT_SVG,
        { glyphs  => $self->glyphs },
        $file
    );
}

#-----------------------------------------------------------------------------
# Generate the config/icons.yaml file
#-----------------------------------------------------------------------------

sub generate_yaml_file {
    my ($self, $file) = @_;

    $self->process_template_to_file(
        $self->ICONS_YAML,
        { glyphs => $self->glyphs },
        $file
    );
}




#-----------------------------------------------------------------------------
# Template processing methods to generate new SVG/YAML files
#-----------------------------------------------------------------------------

sub process_template_to_file {
    my ($self, $input, $data, $file) = @_;
    $file->write(
        $self->process_template($input, $data)
    );
}

sub process_template {
    my ($self, $input, $data) = @_;
    my $engine = $self->template_engine;
    my $output;

    $engine->process($input, $data, \$output)
        || return $self->error("Template error in $input: ", $engine->error);

    return $output;
}

sub template_engine {
    my $self = shift;
    my $tdir = $self->workspace->dir( icons => 'templates' );
    return  $self->{ engine }
       ||=  $self->ENGINE->new(
                INCLUDE_PATH => $tdir->absolute,
                VARIABLES    => $self->template_variables,
            );
}

sub template_variables {
    my $self     = shift;
    my $width    = $self->WIDTH;
    my $height   = $self->HEIGHT;
    my $baseline = $height / 4 * 3;
    my $data     = $self->{ data };
    return {
        version  => $self->VERSION,
        program  => $self->PROGRAM,
        author   => $self->AUTHOR,
        date     => $self->DATE,
        width    => $width,
        height   => $height,
        baseline => $baseline,
        descent  => $baseline - $height,
        advance  => $width,
        %$data,
    };
}

1;
