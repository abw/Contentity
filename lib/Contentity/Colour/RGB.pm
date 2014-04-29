package Contentity::Colour::RGB;

use POSIX 'floor';
use Contentity::Colour 'Colour';
use Contentity::Class
    version   => 2.20,
    debug     => 0,
    base      => 'Contentity::Colour',
    constants => 'ARRAY HASH :colour_slots',
    utils     => 'is_object integer',
    as_text   => 'html',
    is_true   => 1,
    throws    => 'Colour.RGB';


sub new {
    my ($proto, @args) = @_;
    my ($class, $self);

    if ($class = ref $proto) {
        $self = bless [@$proto], $class;
    }
    else {
        $self = bless [0, 0, 0, 1], $proto;
    }
    $self->rgb(@args) if @args;
    return $self;
}

sub copy {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $args->{ red   } = $self->[RED_SLOT]   unless defined $args->{ red   };
    $args->{ green } = $self->[GREEN_SLOT] unless defined $args->{ green };
    $args->{ blue  } = $self->[BLUE_SLOT]  unless defined $args->{ blue  };
    $args->{ alpha } = $self->[ALPHA_SLOT] unless defined $args->{ alpha };
    $self->new($args);
}

sub rgb {
    my $self = shift;
    my $col;

    if (@_ == 1) {
        # single argument is a list or hash ref, or RGB value
        $col = shift;
    }
    elsif (@_ == 3 || @_ == 4) {
        # three or 4 arguments provide red, green, blue (and alpha) components
        $col = [ @_ ];
    }
    elsif (@_ == 6) {
        # list of six items is red => $r, green => $g, blue => $b
        $col = { @_ };
    }
    elsif (@_) {
        # any other number of arguments is an error
        return $self->error_msg( bad_param => rgb => join(', ', @_) );
    }
    else {
        # return $self when called with no arguments
        return $self;
    }

    # at this point $col is a reference to a list or hash, or a rgb value

    if (UNIVERSAL::isa($col, HASH)) {
        # convert hash ref to list
        my $alpha = $col->{ alpha };
        $col = [
            map {
                defined $col->{ $_ }
              ? $col->{ $_ }
              : return $self->error_msg( no_param => rgb => $_ );
            }
            qw( red green blue )
        ];
        push(@$col, $alpha)
            if defined $alpha;
    }
    elsif (UNIVERSAL::isa($col, ARRAY)) {
        # $col list is ok as it is
    }
    elsif (ref $col) {
        # anything other kind of reference is Not Allowed
        return $self->error_msg( bad_param => rgb => $col );
    }
    else {
        $self->debug("parsing [$col]") if DEBUG;
        $self->parse($col);
        return $self;
    }

    # ensure all rgb component values are in range 0-255
    for (@$col[RED_SLOT..BLUE_SLOT]) {
        $_ =   0 if $_ < 0;
        $_ = 255 if $_ > 255;
    }
    if (defined $col->[ALPHA_SLOT]) {
        # alpha is normalised 0-1
        $col->[ALPHA_SLOT] = $self->normalise_alpha($col->[ALPHA_SLOT]);
    }
    else {
        $col->[ALPHA_SLOT] = 1;
    }

    # update self with new colour
    @$self = @$col;

    return $self;
}

sub parse {
    my ($self, $string) = @_;

    $self->debug("parsing: [$string]") if DEBUG;
    if ($string =~ /
            ^
            \#?            # short form of hex triplet: #abc
            ([0-9a-f])     # red
            ([0-9a-f])     # green
            ([0-9a-f])     # blue
            $
          /ix) {
        @$self = map { CORE::hex } ("$1$1", "$2$2", "$3$3");
    }
    elsif ($string =~ /
            ^
            \#?            # long form of hex triple: #aabbcc
            ([0-9a-f]{2})  # red
            ([0-9a-f]{2})  # green
            ([0-9a-f]{2})  # blue
            $
          /ix) {
        @$self = map { CORE::hex } ($1, $2, $3);
    }
    elsif ($string =~ /
            ^
            rgb\(
              (\d+%?),\s*  # red
              (\d+%?),\s*  # green
              (\d+%?) \s*  # blue
            \)
            $
          /ix) {
        @$self = map { $self->parse_value($_) } ($1, $2, $3);
        $self->debug("found $string => rgb($self->[0], $self->[1], $self->[2])") if DEBUG;
    }
    elsif ($string =~ /
            ^
            rgba\(
              (\d+%?),\s*   # red
              (\d+%?),\s*   # green
              (\d+%?),\s*   # blue
              ([\d\.]+)\s*  # alpha
            \)
            $
          /ix) {
        @$self = map { $self->parse_value($_) } ($1, $2, $3);
        $self->[ALPHA_SLOT] = $self->normalise_alpha($4);
        $self->debug("found $string => rgba($self->[0], $self->[1], $self->[2], $self->[3])") if DEBUG;
    }
    else {
        return $self->error_msg(
            invalid => colour => $string
        );
    }

    return $self;
}

sub hex {
    my $self = shift;

    if (@_) {
        return $self->parse(@_)
            || $self->error_msg( bad_param => hex => $_[0] );
    }
    return sprintf("%02x%02x%02x", @$self);
}

sub HEX {
    my $self = shift;
    return uc $self->hex(@_);
}

sub parse_value {
    my $self  = shift;
    my $value = shift; # || 0;

    if ($value =~ /^(\d+)%/) {
        $self->debug("percentage: $1") if DEBUG;
        return integer(255 * $1 / 100);
    }
    else {
        $self->debug("value: $value") if DEBUG;
        return $value;
    }
}

sub html {
    my $self = shift;
    return $self->css_rgba
        if defined $self->[ALPHA_SLOT]
        && $self->[ALPHA_SLOT] != 1;
    return '#' . $self->hex();
}

sub HTML {
    return uc shift->html;
}

sub css_rgb {
    my $self = shift;
    return sprintf(
        "rgb(%i,%i,%i)",
        $self->[RED_SLOT],
        $self->[GREEN_SLOT],
        $self->[BLUE_SLOT],
    );
}

sub css_rgba {
    my $self  = shift;
    my $alpha = @_ ? shift : $self->[ALPHA_SLOT];
    return sprintf(
        "rgba(%i,%i,%i,%s)",
        $self->[RED_SLOT],
        $self->[GREEN_SLOT],
        $self->[BLUE_SLOT],
        $alpha,
    );
}

sub red {
    my $self = shift;
    if (@_) {
        $self->[RED_SLOT] = $self->normalise_channel(@_);
        delete $self->[SCHEME_SLOT];
    }
    $self->[RED_SLOT];
}

sub green {
    my $self = shift;
    if (@_) {
        $self->[GREEN_SLOT] = $self->normalise_channel(@_);
        delete $self->[SCHEME_SLOT];
    }
    $self->[GREEN_SLOT];
}

sub blue {
    my $self = shift;
    if (@_) {
        $self->[BLUE_SLOT] = $self->normalise_channel(@_);
        delete $self->[SCHEME_SLOT];
    }
    $self->[BLUE_SLOT];
}

sub alpha {
    my $self = shift;
    if (@_) {
        $self->[ALPHA_SLOT] = $self->normalise_alpha(@_);
        # Probably doesn't invalidate scheme?
        # delete $self->[SCHEME_SLOT];
    }
    $self->[ALPHA_SLOT];
}

sub grey  {
    my $self = shift;

    if (@_) {
        delete $self->[SCHEME_SLOT];
        return (
            $self->[RED_SLOT]
          = $self->[GREEN_SLOT]
          = $self->[BLUE_SLOT]
          = $self->normalise_channel(@_)
        );
    }
    else {
        return integer(
            $self->[RED_SLOT]  * 0.222
          + $self->[GREEN_SLOT]* 0.707
          + $self->[BLUE_SLOT] * 0.071
          + 0.5
        );
    }
}

sub update {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $value;
    if (defined ($value = $args->{ red })) {
        $self->[RED_SLOT]  = $self->normalise_channel($value);
    }
    if (defined ($value = $args->{ green })) {
        $self->[GREEN_SLOT]  = $self->normalise_channel($value);
    }
    if (defined ($value = $args->{ blue })) {
        $self->[BLUE_SLOT]  = $self->normalise_channel($value);
    }
    if (defined ($value = $args->{ alpha })) {
        $self->[ALPHA_SLOT]  = $self->normalise_alpha($value);
    }
    delete $self->[SCHEME_SLOT];
    return $self;
}

sub adjust {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $delta;
    if (defined ($delta = $args->{ red })) {
        $self->[RED_SLOT] = $self->normalise_channel(
            $self->[RED_SLOT] + $delta
        );
    }
    if (defined ($delta = $args->{ green })) {
        $self->[GREEN_SLOT] = $self->normalise_channel(
            $self->[GREEN_SLOT] + $delta
        );
    }
    if (defined ($delta = $args->{ blue })) {
        $self->[BLUE_SLOT] = $self->normalise_channel(
            $self->[BLUE_SLOT] + $delta
        );
    }
    if (defined ($delta = $args->{ alpha })) {
        $self->[ALPHA_SLOT] = $self->normalise_alpha(
            $self->[ALPHA_SLOT] + $delta
        );
    }

    delete $self->[SCHEME_SLOT];
    return $self;
}

sub range {
    my $self   = shift;
    my $steps  = shift;
    my $target = $self->SUPER::new(@_)->rgb;
    my $dred   = ($target->[RED_SLOT]   - $self->[RED_SLOT])   / $steps;
    my $dgreen = ($target->[GREEN_SLOT] - $self->[GREEN_SLOT]) / $steps;
    my $dblue  = ($target->[BLUE_SLOT]  - $self->[BLUE_SLOT])  / $steps;
    my ($n, @range);

    # TODO: alpha

    for ($n = 0; $n <= $steps; $n++) {
        push(@range, $self->copy->adjust({
            red   => $dred   * $n,
            green => $dgreen * $n,
            blue  => $dblue  * $n,
        }));
    }
    return wantarray ? @range : \@range;
}


sub blend {
    my $copy   = shift->copy;
    my $target = Colour(shift)->rgb;
    my $amount = $copy->normalise_alpha(@_ ? shift : 0.1);

    for my $c (RED_SLOT..BLUE_SLOT) {
        my $n = $copy->[$c];
        $copy->[$c] = $copy->normalise_channel(
            $copy->[$c] + integer(($target->[$c] - $copy->[$c]) * $amount)
        );
    }

    return $copy;
}

sub opaque {
    my $copy = shift->copy;
    $copy->alpha(@_);
    return $copy;
}

sub transparent {
    my $copy  = shift->copy;
    my $trans = $copy->normalise_alpha(@_);
    $copy->alpha( 1 - $trans );
    return $copy;
}


#------------------------------------------------------------------------
# hsv()
# hsv($h, $s, $v)
#
# Convert RGB to HSV, with optional $h, $s and/or $v arguments.
#------------------------------------------------------------------------

sub hsv {
    my ($self, @args) = @_;
    my $hsv;

    # generate HSV values from current RGB if no arguments provided
    unless (@args) {
        my ($r, $g, $b) = @$self;
        my ($h, $s, $v);
        my $min   = $self->min($r, $g, $b);
        my $max   = $self->max($r, $g, $b);
        my $delta = $max - $min;
        $v = $max;

        if($delta){
            $s = $delta / $max;
            if ($r == $max) {
                $h = 60 * ($g - $b) / $delta;
            }
            elsif ($g == $max) {
                $h = 120 + (60 * ($b - $r) / $delta);
            }
            else { # if $b == $max
                $h = 240 + (60 * ($r - $g) / $delta);
            }

            $h += 360 if $h < 0;  # hue is in the range 0-360
            $h = integer($h + 0.5); # smooth out rounding errors
            $s = integer($s * 255);   # expand saturation to 0-255
        }
        else {
            $h = $s = 0;
        }
        @args = ($h, $s, $v);
    }

    $self->HSV(@args);
}


1;

=head1 NAME

Contentity::Colour::RGB - module for RGB colour manipulation

=head1 SYNOPSIS

See L<Contentity::Colour>

=head1 DESCRIPTION

This module defines a colour object using the Red/Green/Blue (RGB)
colour space.

=head1 AUTHOR

Andy Wardley E<lt>abw@cpan.orgE<gt>, L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2006-2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Colour>, L<Contentity::Colour::HSV>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
