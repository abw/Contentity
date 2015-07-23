package Contentity::Form::Field::Telephone;

use Contentity::Class::Form::Field
    version  => 0.02,
    debug    => 0,
    display  => 'text',
    config   => [
        'min_length|min|class:MIN_LENGTH=5',
        'max_length|max|class:MAX_LENGTH=20',
        'msisdn=0',
    ],
    messages => {
        bad_number => 'The %s must contain only digits, spaces or "x" for an extension.',
        too_small  => 'The %s you entered was too short (minimum: %s digits)',
        too_big    => 'The %s you entered was too long (maximum: %s digits)',
        not_msisdn => 'The telephone number must be 12 digits long and should start with: 447',
    };

our $PREPARE = {
    strip_tags      => 1,
    strip_entities  => 1,
    trim_wspace     => 1,
    collapse_wspace => 1,
    remove_wspace   => 0,       # don't think so
};


sub validate {
    my $self  = shift;
    my $value = shift;
    my $min   = $self->{ min_length };
    my $max   = $self->{ max_length };

    if (length $value) {

        if ($self->{ msisdn }) {
            return $self->validate_msidn($value, @_);
        }
        else {
            $self->{ value } = $value;
            $self->debug("doing telephone validation\n") if DEBUG;

            return $self->invalid_msg( bad_number => lc $self->{ label } )
                unless $value =~ /^[\d\s\+x]+$/;

            return $self->invalid_msg( too_small => lc $self->{ label }, $min)
                if ($min && length $value < $min);

            return $self->invalid_msg( too_big => lc $self->{ label }, $max)
                if ($max && length $value > $max);
        }
    }
    elsif ($self->{ mandatory }) {
        return $self->invalid_msg( mandatory => $self->{ label } );
    }

    return ($self->{ valid } = 1);
}

sub validate_msisdn {
    my ($self, $value) = @_;
    $self->debug("doing MSISDN validation\n") if DEBUG;

    $value =~ s/^0/44/;    # change 0 prefix to 44
    $value =~ s/\D//g;     # remove any non-digits

    $self->{ value } = $value;

    return $self->invalid_msg( not_msisdn => $self->{ label })
        unless length($value) == 12;

    return ($self->{ valid } = 1);
}

1;

__END__

=head1 NAME

Contentity::Form::Field::Telephone - web form field for telephone numbers

=head1 DESCRIPTION

This module defines a telephone number field object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
