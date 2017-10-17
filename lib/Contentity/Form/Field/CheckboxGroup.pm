package Contentity::Form::Field::CheckboxGroup;

use Contentity::Class::Form::Field
    version   => 0.02,
    debug     => 0,
    words     => 'ARRAY OPTIONS DELIMITER',
    config    => 'disabled=0';


sub init {
    my ($self, $config) = @_;
    $self = $self->SUPER::init($config);
    $self->options(
        $self->bclass->list_vars(OPTIONS, $config->{ options })
    );
    return $self;
}

sub options {
    my $self = shift;

    if (@_) {
        my $options = $self->{ options } =
            (@_ == 1 && ref $_[0] eq ARRAY) # if we get a single array ref
            ? [ @{ $_[0] } ]                # then we clone it,
            : [ @_ ];                       # otherwise construct list ref from args

        # construct an index mapping values to options
        $self->{ value_index } = {
            map { $_->{ value } => $_ }
            @$options
        };
    }

    return $self->{ options };
}

sub validate {
    my $self      = shift;
    my $count     = $self->value(shift);
    my $mandatory = $self->{ mandatory };

    if ($mandatory && ! $count) {
        if ($mandatory eq '1') {
            return $self->invalid_msg( mandatory => $self->{ label } );
        }
        else {
            return $self->invalid($mandatory);
        }
    }

    return ($self->{ valid } = $count);
}

sub value {
    my $self  = shift;
    my $count = 0;

    if (@_) {
        # if arguments are passed then it's a whitespace-delimited string
        # or reference to a list of one or more option values
        my $value = shift || '';

        $self->debug("value: $value") if DEBUG;

        $value = [ split(DELIMITER, $value) ]
            unless ref $value eq ARRAY;

        # we turn it into a hash so we know which values are set
        $value = { map { $_ => 1 } @$value };

        # then go through each option checking them on or off
        foreach my $option (@{ $self->{ options } }) {
            $count++
                if ($option->{ checked } = $value->{ $option->{ value } });
        }
        return $count;
    }
    else {
        # otherwise go the other way, creating a list of all values that
        # are checked
        return [
            map  { $_->{ value   } }
            grep { $_->{ checked } }
            @{ $self->{ options } }
        ],
    }
}


sub disable {
    my $self = shift;
    if (@_) {
        $self->todo;
    }
    else {
        $self->{ disabled } = 1;
    }
}

sub enable {
    my $self = shift;
    if (@_) {
        $self->todo;
    }
    else {
        $self->{ disabled } = 0;
    }
}

sub check {
    shift->todo;
}

sub uncheck {
    shift->todo;
}


1;

__END__

=head1 NAME

Contentity::Form::Field::CheckboxGroup - checkbox group form field

=head1 SYNOPSIS

    use Contentity::Form::Field::CheckboxGroup;

    my $field = Contentity::Form::Field::CheckboxGroup->new(
        name     => 'forages_for',
        options  => [
          {
            label  => 'Nuts',
            value  => 'nuts',
          },
          {
            label   => 'Berries',
            value   => 'berries',
            checked => 1,
          },
          {
            label   => 'Mushrooms',
            value   => 'mushrooms',
          },
          {
            label    => 'Magic Mushrooms',
            value    => 'magic_mushrooms',
            disabled => 1,                  # drugs are bad M'kay
          },
        ],
    );

=head1 DESCRIPTION

This module defines a C<checkbox> group form field for choosing one or more
of a number of items.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2009-2015 Andy Wardley.  All Rights Reserved.

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
