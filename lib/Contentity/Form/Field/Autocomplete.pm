package Contentity::Form::Field::Autocomplete;

use Cog::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Form::Field::Text';

sub validate {
    my $self    = shift;
    my $value   = $self->prepare(shift);
    my $params  = shift;
    my $idparam = $self->id_param;
    my $idvalue = $params->{ $idparam };
    my $idopt   = $self->{ id_optional };
    my $idfail  = ! ($idvalue || $idopt);

    $self->debugf(
        "autocomplete validation: [%s=%s] [%s=%s]",
        $self->name, $value,
        $idparam, $idvalue
    );

    $self->id_value($idvalue);

    # If the field is mandatory and we don't have a value then we would
    # normally declare the field to be invalid.  However, if we've got an
    # id instead then that's OK.  e.g. 'scheme' can be blank as long as
    # 'scheme_id' is defined
    return $self->invalid_msg( mandatory => $self->{ label } )
        if $self->{ mandatory } && ! length $value && ! $idvalue;

    return ($self->{ valid } = 1);
}


sub id_param {
    return shift->name . '_id';
}

sub id_value {
    my $self = shift;
    my $name = $self->id_param;
    return @_
        ? ($self->{ $name } = shift)
        :  $self->{ $name };
}

sub value {
    my $self = shift;
    if (@_) {
        $self->{ value } = shift;
        $self->debug("setting $self->{ name } to $self->{ value }") if DEBUG;
        my $params = shift;
        my $idprm  = $self->id_param;
        my $idval  = $params->{ $idprm };
        $self->debug("setting $idprm to $idval") if $idval && DEBUG;
        $self->id_value($idval) if $idval;
    }
    return $self->{ value };
}

sub values {
    my $self    = shift;
    my $name    = shift || $self->name;
    my $value   = $self->value;      # scalar context
    my $id_name = $self->id_param;
    my $id_val  = $self->id_value || undef;

    # if we have an ID then perhaps we shouldn't return the name?
    # However, we can't predict what happens if the user gets an ID via
    # the autocomplete and then changes the text

    $self->debug("returning field values: [$name => $value] [$id_name => $id_val]") if DEBUG or 1;

    return (
        $name    => $value,
        $id_name => $id_val,
    );         # aways return 4 item list
}

sub field_values {
    my $self    = shift;
    my $name    = shift || $self->name;
    my $value   = $self->value;      # scalar context
    my $id_name = $self->id_param;
    my $id_val  = $self->id_value || undef;

    # if we have an ID then perhaps we shouldn't return the name?
    # However, we can't predict what happens if the user gets an ID via
    # the autocomplete and then changes the text

    $self->debug("returning field values: [$name => $value] [$id_name => $id_val]") if DEBUG;

    return (
        $name    => $value,
        $id_name => $id_val,
    );         # aways return 4 item list
}



1;
