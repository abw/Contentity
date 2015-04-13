package Contentity::Form::Field::Time;

use Contentity::Class::Form::Field
    version => 0.05,
    debug   => 1,
    utils   => 'canonical_time',
    messages => {
        bad_time => 'Invalid %s specified.  Valid formats include HH:MM and HH:MM:SS'
    };


sub validate {
    my $self  = shift;
    my $value = $self->prepare(shift);

    return $self->invalid_msg( mandatory => $self->{ label } )
        if $self->{ mandatory } && ! length $value;

    $self->debug("validating time: $value") if DEBUG;

    my $time  = canonical_time($value)
        || return $self->invalid_msg( bad_time => lc $self->{ label } );

    $self->value($time);

    return ($self->{ valid } = 1);
}

1;

__END__

=head1 NAME

Contentity::Form::Field::Time - form field for entering a time of day

=head1 SYNOPSIS

    use Contentity::Form::Field::Time;

    my $field = Contentity::Form::Field::Time->new({
        name      => 'time',
        label     => 'Start Time',
    });

=head1 DESCRIPTION

This module defines a field object for entering time values.  It is a subclass
of L<Contentity::Form::Field>.  It defines a custom L<prepare()> method which
accepts a variety of time formats and converts them to a canonical HH:MM::SS
format.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
