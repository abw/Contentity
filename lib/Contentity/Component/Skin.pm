package Contentity::Component::Skin;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    utils     => 'Colour self_params merge extend',
    constants => ':components HASH',
    messages => {
        bad_col_rgb => 'Invalid RGB colour name specified for %s: %s',
        bad_col_dot => 'Invalid colour method for %s: .%s',
        bad_col_val => 'Invalid colour value for %s: %s',
    };



#-----------------------------------------------------------------------------
# Methods for loading site and page metadata from project config directory
#-----------------------------------------------------------------------------

sub styles {
    my $self = shift;
    return  $self->{ styles }
        //= $self->load_styles;
}

sub load_styles {
    shift->workspace->config(STYLES);
}

sub rgb {
    my $self = shift;
    return  $self->{ rgb }
        //= $self->load_rgb;
}

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

sub colours {
    my $self = shift;
    return  $self->{ colours }
        //= $self->load_colours;
}

sub load_colours {
    my $self = shift;
    my $cols = $self->workspace->config(COLOURS) || return;
    my $rgb  = $self->rgb;
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
            $col = $self->prepare_colours($value);
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

sub reskin {
    my ($self, $params) = self_params(@_);
    # TODO: we almost certainly need to deep copy colours and styles
    my $rgb     = $self->rgb;
    my $colours = $self->colours;
    my $styles  = $self->styles;

    if ($params->{ rgb }) {
        $rgb = extend({ }, $rgb, $self->prepare_rgb($params->{ rgb }));
    }
    if ($params->{ colours }) {
        $colours = merge({ }, $colours, $self->prepare_colours($params->{ colours }, $rgb));
    }
    my $skin    = {
        rgb     => $rgb,
        colours => $colours,
        styles  => $styles,
    };


    return merge({ }, $skin, $params);

    #return $skin;
}


1;
