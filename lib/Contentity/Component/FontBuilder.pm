package Contentity::Component::FontBuilder;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Component',
    utils     => 'cmd green cyan yellow',
    constant  => {
        FA4_SOURCE => 'fa4',
    };


sub build {
    shift->ugly_all_in_one_hack;
}

# This is little more than a cut-and-paste of the script this module
# is supposed to replace.

sub ugly_all_in_one_hack {
    my $self    = shift;
    my $space   = $self->workspace;
    my $project = $space->project;
    my $config  = $self->config;
    my $uri     = $project->uri;

    $self->debug_data("building font: ", $config) if DEBUG;

    #-------------------------------------------------------------------
    # configuration
    #-------------------------------------------------------------------
    my $fa4_source    = $config->{ fa4_source    } || $self->FA4_SOURCE;
    my $font_name     = $config->{ font_name     } || $uri;
    my $custom_source = $config->{ custom_source } || $uri;

    # Directories
    my $icons_dir     = $project->dir('icons');
    my $icons_bin     = $project->dir('bin','icons');
    my $config_dir    = $project->config->root;
    my $icon_map      = $project->config('icon_map');
    my $src_dir       = $icons_dir->dir('source');
    my $glyph_dir     = $icons_dir->dir('glyphs');
    my $custom_dir    = $icons_dir->dir('custom');
    my $work_dir      = $icons_dir->dir('work');
    my $dest_dir      = $icons_dir->dir('dest');

    # Font awesome4 source font
    my $fa_dir        = $src_dir->dir('font-awesome-latest');
    my $fa_css        = $fa_dir->file('css/font-awesome.css');
    my $fa_svg        = $fa_dir->file('fonts/fontawesome-webfont.svg');

    # Temporary working copies for extracting glyphs
    my $svg_work      = $work_dir->file('fontawesome.svg');
    my $svg_flip      = $work_dir->file('fontawesome-flipped.svg');

    # Generated icons SVG font and inverted version
    my $icon_file     = $work_dir->file("${font_name}_icons.svg");
    my $icon_flip     = $work_dir->file("${font_name}_icons-flipped.svg");
    my $icon_cent     = $work_dir->file("${font_name}_icons-centred.svg");
    my $icon_base     = "${font_name}_icons";

    # Icon metadata file for CSS templates, etc.
    my $icons_yaml    = $config_dir->file('icons.yaml', { codec => 'yaml' });

    # Other scripts we use
    my $flip          = $icons_bin->file('flip.pe');
    my $blurt         = $icons_bin->file('blurt.pe');
    my $centre        = $icons_bin->file('centre.pe');

    # Contentity component
    my $iconfont   = $project->component(
        iconfont => {
            verbose => $config->{ verbose },
            font_id => "${font_name}_icons",
        }
    );

    #-------------------------------------------------------------------
    # Parse Font Awesome CSS to extract name => Unicode point mappings
    #-------------------------------------------------------------------
    $self->info_message("Parsing CSS:", $fa_css);
    $iconfont->parse_css($fa_css);

    #-------------------------------------------------------------------
    # Copy source SVG font to our working directory
    #-------------------------------------------------------------------
    $self->info_message("Copying SVG:", $svg_work);
    $fa_svg->copy_to($svg_work);

    #-------------------------------------------------------------------
    # Call bin/icons/flip.pe to flip the font
    #-------------------------------------------------------------------
    $self->info_message("Flipping SVG:", $svg_flip);
    cmd($flip->absolute, $svg_work->absolute);

    #-------------------------------------------------------------------
    # Parse inverted SVG font to extract glyphs
    #-------------------------------------------------------------------
    $self->info_message("Extracting glyphs:", $glyph_dir);
    $iconfont->extract_glyphs($svg_flip, $glyph_dir, $fa4_source);

    #-------------------------------------------------------------------
    # Import additional cog icons
    #-------------------------------------------------------------------
    $self->info_message("Importing custom icons:", $custom_dir);
    $iconfont->import_glyph_dir($custom_dir, $glyph_dir, $custom_source);

    #-------------------------------------------------------------------
    # Filter
    #-------------------------------------------------------------------
    $iconfont->select_glyphs($icon_map);

    #-------------------------------------------------------------------
    # Write YAML config file
    #-------------------------------------------------------------------
    $self->info_message("Writing YAML file:", $icons_yaml);
    $iconfont->generate_yaml_file($icons_yaml);

    #-------------------------------------------------------------------
    # Write new icon font
    #-------------------------------------------------------------------
    $self->info_message("Writing icon font:", $icon_file);
    $iconfont->generate_svg_font($icon_file);

    #-------------------------------------------------------------------
    # Invert font
    #----------------------------------------------------------------------------
    $self->info_message("Inverting font:", $icon_flip);
    cmd($flip->absolute, $icon_file->absolute);
    $icon_flip->move_to($icon_file);

    #-------------------------------------------------------------------
    # Centre glyphs
    #----------------------------------------------------------------------------
    $self->info_message("Centering font:", $icon_file);
    cmd($centre->absolute, $icon_file->absolute);
    $icon_cent->move_to($icon_file);

    #-------------------------------------------------------------------
    # Generate .ttf, .woff and .svgz from .svg font
    #-------------------------------------------------------------------
    $self->info_message("Blurting font:", $icon_file);
    cmd($blurt->absolute, $icon_file->absolute);


    #-------------------------------------------------------------------
    # Copy generated files to their final destination
    #-------------------------------------------------------------------
    $self->info_message("Copying files:", $dest_dir);

    foreach my $file ($work_dir->files) {
        next unless $file->basename eq $icon_base;
        my $dest_file = $dest_dir->file($file->name);
        $file->copy_to($dest_file);
        $self->file_message($dest_file);
    }
}


#-----------------------------------------------------------------------------
# Helper subroutines
#-----------------------------------------------------------------------------

sub info_message {
    my ($self, $message, $item) = @_;
    print
        sprintf(cyan("%20s "), $message),
        yellow($item),
        "\n";
}

sub file_message {
    my ($message, $file) = @_;
    print green "  + $file\n";
}

1;
