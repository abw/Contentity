package Contentity::Form::Field::Number;

use Contentity::Class::Form::Field
    version  => 0.01,
    debug    => 0,
    base     => 'Contentity::Form::Field::Text',
    utils    => 'numlike',
    display  => 'number',
    config   => [
        'min',
        'max',
    ],
    messages => {
        bad_number => 'The %s must contain only digits.',
        too_small  => 'The %s you entered was too small (minimum: %s)',
        too_big    => 'The %s you entered was too long (maximum: %s)',
    };

our $PREPARE = {
    strip_tags      => 1,
    strip_entities  => 1,
    trim_wspace     => 1,
    collapse_wspace => 1,
    remove_wspace   => 1,
};


sub validate {
    my $self  = shift;
    my $value = shift;
    my $min   = $self->{ min };
    my $max   = $self->{ max };

    if (length $value) {
        return $self->invalid_msg( bad_number => lc $self->{ label } )
            unless numlike $value;

        return $self->invalid_msg( too_small => lc $self->{ label }, $min)
            if $min && $value < $min;

        return $self->invalid_msg( too_big => lc $self->{ label }, $max)
            if $max && $value > $max;
    }
    elsif ($self->{ mandatory }) {
        return $self->invalid_msg( mandatory => $self->{ label } );
    }

    return ($self->{ valid } = 1);
}

1;

__END__

=head1 NAME

Contentity::Form::Field::Number - web form field for numbers

=head1 DESCRIPTION

This module defines a number field object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2017 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
