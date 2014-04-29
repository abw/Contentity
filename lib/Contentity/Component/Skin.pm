package Contentity::Component::Skin;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    utils     => 'Colour self_params merge extend split_to_list',
    constants => ':components HASH',
    constant  => {
        SKIN_LOC    => 'skin/%s',
        SKINS_CFG   => 'skins',
    },
    messages => {
        bad_col_rgb => 'Invalid RGB colour name specified for %s: %s',
        bad_col_dot => 'Invalid colour method for %s: .%s',
        bad_col_val => 'Invalid colour value for %s: %s',
    };



#-----------------------------------------------------------------------------
# Methods for loading site and page metadata from project config directory
#-----------------------------------------------------------------------------

sub rgb {
    shift->skin->{ rgb };
}

sub colours {
    shift->skin->{ colours };
}

sub styles {
    shift->skin->{ styles };
}

sub fonts {
    shift->skin->{ fonts };
}

sub font {
    my $self = shift;
    my $font = $self->styles->{ font };
    return @_
        ? $font->{ $_[0] }
        : $font;
}


#-----------------------------------------------------------------------------
# Skin - load the base skin and then apply any site.skins over the top
#-----------------------------------------------------------------------------

sub skin {
    my $self = shift;
    return  $self->{ skin }
        ||= $self->prepare_skin;
}

sub prepare_skin {
    my $self  = shift;
    my $base  = $self->base_skin;
    my $skins = $self->workspace->config($self->SKINS_CFG);
    return $base unless $skins;

    $skins = split_to_list($skins);

    foreach my $name (@$skins) {
        my $skin = $self->load_skin($name);

        $self->debug_data( $name, $skin) if DEBUG;

        if ($skin->{ rgb }) {
            # add in new RGB colours
            extend(
                $base->{ rgb },
                $self->prepare_rgb($skin->{ rgb })
            );
        }
        if ($skin->{ fonts }) {
            # add in new fonts
            extend(
                $base->{ fonts },
                $skin->{ fonts }
            );
        }
        if ($skin->{ colours }) {
            # deep merge in colours resolved to RGB colours
            merge(
                $base->{ colours },
                $self->prepare_colours($skin->{ colours }, $base->{ rgb })
            );
        }

        if ($skin->{ styles }) {
            # merge in additional style data with fonts resolved
            merge(
                $base->{ styles },
                $self->prepare_styles($skin->{ styles }, $base->{ fonts })
            );
        }
    }
    $self->debug_data( skin => $base ) if DEBUG;
    return $base;
}


#-----------------------------------------------------------------------------
# Base skin
#-----------------------------------------------------------------------------

sub base_skin {
    my $self = shift;
    return  $self->{ base_skin }
        ||= $self->load_base_skin;
}

sub load_base_skin {
    my $self  = shift;
    my $rgb   = $self->load_rgb;
    my $fonts = $self->load_fonts;
    return {
        rgb     => $rgb,
        fonts   => $fonts,
        colours => $self->load_colours($rgb),
        styles  => $self->load_styles($fonts),
    };
}

sub load_skin {
    my ($self, $name) = @_;
    my $path = sprintf($self->SKIN_LOC, $name);
    return $self->workspace->config($path)
        || $self->error_msg( invalid => skin => $name );
}

#-----------------------------------------------------------------------------
# RGB - loaded from rgb.yaml and converted to colour objects
#-----------------------------------------------------------------------------

sub load_rgb {
    my $self = shift;
    my $rgb  = $self->workspace->config(RGB) || return;
    return $self->prepare_rgb($rgb);
}

sub prepare_rgb {
    my $self = shift;
    my $rgb  = shift || $self->workspace->config(RGB) || return;
    foreach my $key (keys %$rgb) {
        $rgb->{ $key } = Colour($rgb->{ $key });
    }
    return $rgb;
}

#-----------------------------------------------------------------------------
# Colours - loaded from colours.yaml and mapped to RGB colours
#-----------------------------------------------------------------------------

sub load_colours {
    my $self = shift;
    my $rgb  = shift || $self->rgb;
    my $cols = $self->workspace->config(COLOURS) || return;
    return $self->prepare_colours($cols, $rgb);
}

sub prepare_colours {
    my $self = shift;
    my $cols = shift || $self->workspace->config(COLOURS) || return;
    my $rgb  = shift || $self->rgb;
    my ($key, $value, $name, $ref, $dots, $col, $bit, @bits);

    foreach $key (keys %$cols) {
        $value = $cols->{ $key };
        $ref   = ref $value;

        $self->debug("$key => $value") if DEBUG;

        if ($ref && $ref eq HASH) {
            # colours can have nested hash arrays, e.g. col.button.error
            $col = $self->prepare_colours($value, $rgb);
        }
        elsif ($value =~ /^(\w+)(?:\.(.*))?$/) {
            # colours can have names that refer to RGB entries, they may also
            # have a dotted part after the name, e.g. red.lighter
            $self->debug("colour ref: [$1] [$2]") if DEBUG;
            $name = $1;
            $dots = $2;
            $col  = $rgb->{ $name }
                || return $self->error_msg( bad_col_rgb => $key => $name  );

            if (length $dots) {
                @bits = split(/\./, $dots);
                $self->debug("dots: [$dots] => [", join('] [', @bits), ']') if DEBUG;
                while (@bits) {
                    $bit = shift (@bits);
                    $col = $col->try->$bit
                        || return $self->error_msg( bad_col_dot => $key => $name => $bit );
                    $self->debug(".$bit => $col") if DEBUG;
                }
            }
        }
        else {
            # otherwise we assume they're new colour definitions
            $self->debug("colour val $key => $value") if DEBUG;
            $col = Colour->try->new($value)
                || return $self->error_msg( bad_col_val => $key => $value );
        }

        $self->debug(" => $col") if DEBUG;
        $cols->{ $key } = $col;
    }

    return $cols;
}


#-----------------------------------------------------------------------------
# Fonts - simply loaded from fonts.yaml
#-----------------------------------------------------------------------------

sub load_fonts {
    shift->workspace->config(FONTS);
}

#-----------------------------------------------------------------------------
# Styles - loaded from styles.yaml, resolve any font definitions
#-----------------------------------------------------------------------------

sub load_styles {
    my $self   = shift;
    my $fonts  = shift;
    my $styles = $self->workspace->config(STYLES) || return;
    return $self->prepare_styles($styles, $fonts);
}

sub prepare_styles {
    my $self   = shift;
    my $styles = shift;
    my $fonts  = shift;
    my $font   = $styles->{ font } || return $styles;

    if ($font && ref $font eq HASH) {
        for my $key (keys %$font) {
            my $val = $font->{ $key };
            $font->{ $key } = $fonts->{ $val }
                || return $self->error_msg( invalid => "font for '$key'" => $val );
        }
    }

    return $styles;
}

1;
