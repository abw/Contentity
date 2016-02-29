package Contentity::Form::Field::Checkbox;

use Contentity::Class::Form::Field
    version   => 0.03,
    debug     => 0,
    accessors => 'disabled checked',
    config    => 'disabled=0 checked=0';


sub validate {
    my ($self, $value, $params) = @_;
    $value ||= '';
    my $mandatory = $self->{ mandatory };

    $self->{ checked } = $value ? 1 : 0;

    if ($mandatory && ! $self->{ checked }) {
        if ($mandatory eq '1') {
            return $self->invalid_msg( mandatory => $self->{ label } );
        }
        else {
            return $self->invalid($self->{ mandatory });
        }
    }

    return ($self->{ valid } = 1);
}

sub value {
    my $self = shift;

    if (@_) {
        my $value = shift || 0;
        $self->{ checked } = $value ? 1 : 0;
    }
    return $self->{ checked };
}

sub disable {
    shift->{ disabled } = 1;
}

sub enable {
    shift->{ disabled } = 0;
}

sub check {
    shift->{ checked } = 1;
}

sub uncheck {
    shift->{ checked } = 0;
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Checkbox - checkbox field for web forms

=head1 DESCRIPTION

This module defines a checkbox field for a web form.

=head1 AUTHOR

Andy Wardley L<htt://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2016 Andy Wardley.  All Rights Reserved.

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
