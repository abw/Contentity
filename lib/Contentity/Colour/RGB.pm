package Contentity::Colour::RGB;

use POSIX 'floor';
use Contentity::Class
    version   => 2.10,
    debug     => 0,
    base      => 'Contentity::Colour',
    constants => 'ARRAY HASH :colour_slots',
    utils     => 'is_object floor',
    as_text   => 'HTML',
    is_true   => 1,
    throws    => 'Colour.RGB';


sub new {
    my ($proto, @args) = @_;
    my ($class, $self);

    if ($class = ref $proto) {
        $self = bless [@$proto], $class;
    }
    else {
        $self = bless [0, 0, 0], $proto;
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
    $self->new($args);
}

sub rgb {
    my $self = shift;
    my $col;
    
    if (@_ == 1) {
        # single argument is a list or hash ref, or RGB value
        $col = shift;
    }
    elsif (@_ == 3) {
        # three arguments provide red, green, blue components
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
        $col = [  map {
            defined $col->{ $_ } 
            ? $col->{ $_ } 
            : return $self->error_msg( no_param => rgb => $_ );
        } qw( red green blue ) ];
    }
    elsif (UNIVERSAL::isa($col, ARRAY)) {
        # $col list is ok as it is
    }
    elsif (ref $col) {
        # anything other kind of reference is Not Allowed
        return $self->error_msg( bad_param => rgb => $col );
    }
    else {
        $self->hex($col);
        return $self;
    }

    # ensure all rgb component values are in range 0-255
    for (@$col) {
        $_ =   0 if $_ < 0;
        $_ = 255 if $_ > 255;
    }

    # update self with new colour, also deletes any cached HSV
    @$self = @$col;

    return $self;
}

sub hex {
    my $self = shift;

    if (@_) {
        my $hex = shift;
        $hex = '' unless defined $hex;
        if ($hex =~ / ^ 
           \#?            # short form of hex triplet: #abc
           ([0-9a-f])     # red 
           ([0-9a-f])     # green
           ([0-9a-f])     # blue
           $
           /ix) {
            @$self = map { hex } ("$1$1", "$2$2", "$3$3");
        }
        elsif ($hex =~ / ^ 
           \#?            # long form of hex triple: #aabbcc
           ([0-9a-f]{2})  # red 
           ([0-9a-f]{2})  # green
           ([0-9a-f]{2})  # blue
           $
           /ix) {
            @$self = map { hex } ($1, $2, $3);
        }
        else {
            return $self->error_msg( bad_param => hex => $hex );
        }
    }
    return sprintf("%02x%02x%02x", @$self);
}

sub HEX {
    my $self = shift;
    return uc $self->hex(@_);
}

sub html {
    my $self = shift;
    return '#' . $self->hex();
}

sub HTML {
    my $self = shift;
    return '#' . uc $self->hex();
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
    my $alpha = shift;
    return sprintf(
        "rgba(%i,%i,%i,%f)", 
        $self->[RED_SLOT],
        $self->[GREEN_SLOT],
        $self->[BLUE_SLOT],
        $alpha
    );
}

sub red { 
    my $self = shift;
    if (@_) {
        $self->[RED_SLOT]  = shift;
        $self->[RED_SLOT]  = 0   if $self->[RED_SLOT] < 0;
        $self->[RED_SLOT]  = 255 if $self->[RED_SLOT] > 255;
        delete $self->[SCHEME_SLOT];
    }
    $self->[RED_SLOT];
}

sub green { 
    my $self = shift;
    if (@_) {
        $self->[GREEN_SLOT]  = shift;
        $self->[GREEN_SLOT]  = 0   if $self->[GREEN_SLOT] < 0;
        $self->[GREEN_SLOT]  = 255 if $self->[GREEN_SLOT] > 255;
        delete $self->[SCHEME_SLOT];
    }
    $self->[GREEN_SLOT];
}

sub blue { 
    my $self = shift;
    if (@_) {
        $self->[BLUE_SLOT]  = shift;
        $self->[BLUE_SLOT]  = 0   if $self->[BLUE_SLOT] < 0;
        $self->[BLUE_SLOT]  = 255 if $self->[BLUE_SLOT] > 255;
        delete $self->[SCHEME_SLOT];
    }
    $self->[BLUE_SLOT];
}

sub grey  { 
    my $self = shift;

    if (@_) {
        delete $self->[SCHEME_SLOT];
        return ($self->[RED_SLOT] = $self->[GREEN_SLOT] = $self->[BLUE_SLOT] = shift);
    }
    else {
        return floor( $self->[RED_SLOT]  * 0.222 
                    + $self->[GREEN_SLOT]* 0.707 
                    + $self->[BLUE_SLOT] * 0.071 
                    + 0.5 );
    }
}

sub update {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $value;
    if (defined ($value = $args->{ red })) {
        $self->[RED_SLOT]  = $value;
        $self->[RED_SLOT]  = 0   if $self->[RED_SLOT] < 0;
        $self->[RED_SLOT]  = 255 if $self->[RED_SLOT] > 255;
    }
    if (defined ($value = $args->{ green })) {
        $self->[GREEN_SLOT]  = $value;
        $self->[GREEN_SLOT]  = 0   if $self->[GREEN_SLOT] < 0;
        $self->[GREEN_SLOT]  = 255 if $self->[GREEN_SLOT] > 255;
    }
    if (defined ($value = $args->{ blue })) {
        $self->[BLUE_SLOT]  = $value;
        $self->[BLUE_SLOT]  = 0   if $self->[BLUE_SLOT] < 0;
        $self->[BLUE_SLOT]  = 255 if $self->[BLUE_SLOT] > 255;
    }
    delete $self->[SCHEME_SLOT];
    return $self;
}

sub adjust {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $delta;
    if (defined ($delta = $args->{ red })) {
        $self->[RED_SLOT] += $delta;
        $self->[RED_SLOT]  = 0   if $self->[RED_SLOT] < 0;
        $self->[RED_SLOT]  = 255 if $self->[RED_SLOT] > 255;
    }
    if (defined ($delta = $args->{ green })) {
        $self->[GREEN_SLOT] += $delta;
        $self->[GREEN_SLOT]  = 0   if $self->[GREEN_SLOT] < 0;
        $self->[GREEN_SLOT]  = 255 if $self->[GREEN_SLOT] > 255;
    }
    if (defined ($delta = $args->{ blue })) {
        $self->[BLUE_SLOT] += $delta;
        $self->[BLUE_SLOT]  = 0   if $self->[BLUE_SLOT] < 0;
        $self->[BLUE_SLOT]  = 255 if $self->[BLUE_SLOT] > 255;
    }
    delete $self->[SCHEME_SLOT];
    return $self;
}

sub range {
    my $self   = shift;
    my $steps  = shift;
    my $target = $self->SUPER::new(@_)->rgb();
    my $dred   = ($target->[RED_SLOT]   - $self->[RED_SLOT])   / $steps;
    my $dgreen = ($target->[GREEN_SLOT] - $self->[GREEN_SLOT]) / $steps;
    my $dblue  = ($target->[BLUE_SLOT]  - $self->[BLUE_SLOT])  / $steps;
    my ($n, @range);
    
    for ($n = 0; $n <= $steps; $n++) {
        push(@range, $self->copy->adjust({
            red   => $dred   * $n,
            green => $dgreen * $n,
            blue  => $dblue  * $n,
        }));
    }
    return wantarray ? @range : \@range;
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
            $h = floor($h + 0.5); # smooth out rounding errors
            $s = floor($s * 255);   # expand saturation to 0-255
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

