package Contentity::Form::Field::Date;

use Contentity::Class::Form::Field
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Form::Field::Text',
    display   => 'date',
    messages  => {
        bad_date => 'Invalid %s specified.  Please specify as YYYY-MM-DD'
    };


sub validate {
    my $self  = shift;
    my $value = $self->prepare(shift);

    if (length $value) {
        $value =~ /^\d{4}\-\d{2}-\d{2}$/
        || return $self->invalid_msg( bad_date => lc $self->{ label } );

        $self->value($value);
    }
    elsif ($self->{ mandatory }) {
        return $self->invalid_msg( mandatory => $self->{ label } );
    }

    return ($self->{ valid } = 1);
}

1;

__END__
