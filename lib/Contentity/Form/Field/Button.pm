package Contentity::Form::Field::Button;

use Contentity::Class::Form::Field
    version   => 0.03,
    display   => 'button',
    layout    => 'button',
    mutators  => 'link';



sub validate {
    return 1;
}

sub value {
    my $self = shift;

    $self->{ value } = shift
        if @_;

    return defined $self->{ value }
         ? $self->{ value }
         : $self->{ default };
}

sub reset {
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Button - base class button for web forms

=head1 SYNOPSIS

    use Contentity::Form::Field::Button;
    my $submit = Contentity::Form::Field::Button->new({ });

=head1 DESCRIPTION

This module defines a base class button for web forms.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module started out life as C<WebKit::Form::Field::Button> in 2001,
became C<Badger::Web::Form::Field::Button> in 2004 and was moved into the
C<Contentity> module set in April 2014.


=cut
