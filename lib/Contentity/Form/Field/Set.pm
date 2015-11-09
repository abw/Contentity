package Contentity::Form::Field::Set;

#use Contentity::Form::Fields;
use Contentity::Class::Form::Field
    version   => 0.03,
    debug     => 0,
    accessors => 'fields factory',
    layout    => 'fieldset',
    utils     => 'self_params',
    config    => [
        'factory!',
    ];

sub init {
    my ($self, $config) = @_;

    $self->debug("field set config") if DEBUG;

    # update $config to set defaults from package vars
    $self->configure($config => $config);

    # copy everything into object
    @$self{ keys %$config } = values %$config;

    # call back to the Contentity::Form::Fields factory to make the fields
    my $factory = $self->factory;
    my $fields  = $self->factory->field_list($self->{ fields });

    $self->{ fields } = $fields;

    $self->{ field } = {
        map {
            $_->{ name } ? ($_->{ name }, $_) : ();
        } @$fields,
    };

    $self->debug_data( field_set_fields => $self->{ field } ) if DEBUG;

    return $self;
}

sub field {
    my $self = shift;
    return $self->{ field } unless @_;

    my $name = shift;
    return $self->{ field }->{ $name } ||= do {
        my $sets = $self->{ fieldsets } ||= [
            # look for all fields that have a field() method
            grep { $_->can('field') } @{ $self->{ fields } }
        ];
        my $field;
        foreach my $set (@$sets) {
            last if $field = $set->field($name);
        }
        $field;
    };

}

sub register {
    my ($self, $registry) = @_;
    my $name   = $self->name;
    my $fields = $self->fields;
    $registry->{ $name } = $self if $name;

    # Invite all fields (and field sets) to register their name
    foreach my $f (@$fields) {
        $f->register($registry);
    }
}


sub values {
    my ($self, $values) = self_params(@_);
    my ($name, $value, $field);

    $self->debug("setting form values: ", $self->dump_data($values))
        if DEBUG;

    while (($name, $value) = each %$values) {
        $field = $self->field($name) || next;
        $self->debug("setting field: $name => $value")
            if DEBUG;
        $field->value($value, $values);
    }
}


sub field_values {
    my $self   = shift;
    my $fields = $self->{ fields };
#   $self->debug("asking set for form values: ", $self->dump);
    return (
        map  { $_->field_values }
        @$fields
    );
}

sub validate {
    my $self   = shift;
    my $value  = shift;
    my $params = shift || $value || { };
    my $good   = $self->{ valid_fields   } = [ ];
    my $bad    = $self->{ invalid_fields } = [ ];
    my $errors = $self->{ errors         } = [ ];
    my $nfail  = 0;
    my ($field, $name);

    $self->debug("validating SET with params ", join(', ', keys %$params), "\n") if DEBUG;

    foreach my $field (@{ $self->{ fields } }) {
        if ($name = $field->{ name }) {
            $self->debug("validating [$field] $field->{ name } ($params->{ $name })\n") if DEBUG;
            if ($field->validate($params->{ $name }, $params)) {
                $self->debug("OK\n") if $DEBUG;
                push(@$good, $field);
                $params->{ $name } = $field->value();
            }
            else {
                $self->debug("NOT OK: $field->{ error }\n") if DEBUG;
                push(@$bad, $field);
                push(@$errors, $field->{ errors } ? @{ $field->{ errors } } : $field->{ error });
                $nfail++;
            }

        }
    }

    $self->{ errors } = 0 unless $nfail;
    return $nfail ? 0 : 1;
}

sub content {
    my ($self, $view) = @_;
    my $output = '';
    foreach my $field (@{ $self->{ fields } }) {
#        $self->debug("field: $field");
        $output .= $field->present($view);
    }
    return $output;
}

1;

__END__

=head1 NAME

Contentity::Form::Field::Set - form field set

=head1 SYNOPSIS

    use Contentity::Form::Field::Set;

=head1 DESCRIPTION

This module defines a field set for a web form.

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
