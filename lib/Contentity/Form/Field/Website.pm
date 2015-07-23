package Contentity::Form::Field::Website;

use Contentity::Class::Form::Field
    version  => 0.02,
    display  => 'text',
    messages => {
        invalid => 'The website address is not in the correct format.',
    };

our $FORMAT = qr{ ^https?:// [\w\.\-\?\&\=\+\ \/]+ }x;

sub validate {
    my $self   = shift;
    my $value  = $self->prepare(shift);

    # we use the default value of 'http://' as a hint to the user, but
    # we must remember to remove this if the user doesn't type anything
    # else
    $value = $self->{ value } = ''
        if defined $self->{ default } && $value eq $self->{ default };

    if (length $value) {
        return $self->invalid_msg( invalid => lc $self->{ label } )
            unless $value =~ $FORMAT;
    }
    elsif ($self->{ mandatory }) {
        return $self->invalid_msg( mandatory => $self->{ label } );
    }

    return ($self->{ valid } = 1);
}

1;
