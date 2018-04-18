package Contentity::Form::Field::Select;

use Contentity::Class::Form::Field
    version  => 0.04,
    debug    => 0,
    import   => 'bclass',
    words    => 'HASH ARRAY OPTIONS';

sub init {
    my ($self, $config) = @_;
    my $list = $config->{ list };

    if ($list) {
        $self->debug("found a list specification: $list") if DEBUG;
        my $factory = $config->{ factory } || return $self->error("No form field factory reference provided to expand '$list' list");
        my $space   = $factory->workspace;
        $config->{ options } = $space->list($list)
            || return $self->error_msg( invalid => list => $list );
    }

    $self = $self->SUPER::init($config);

    $self->{ options } = $self->prepare_options($self->{ options })
        if $self->{ options };

    return $self;
}

sub options {
    my $self = shift;

    if (@_) {
        $self->debug_data( options => \@_ ) if DEBUG;
        $self->{ options } = $self->prepare_options(@_);
    }
    else {
        $self->{ options } ||= $self->prepare_options(
            $self->bclass->var(OPTIONS)
        );
    }

    return $self->{ options };
}


sub prepare_options {
    my $self = shift;
    my @opts = (@_ == 1 && ref $_[0] eq ARRAY)  # if we get a single array
             ? @{ $_[0] }                       # ref then clone it
             : @_;

    return [
        map {
            ref $_ eq HASH
                ? $_
                : { value => $_ }
        }
        @opts
    ];
}

sub size {
    my $self = shift;
    return $self->{ size } || 0;
}


1;

__END__

=head1 NAME

Contentity::Form::Field::Select - pull-down selection field

=head1 SYNOPSIS

    use Contentity::Form::Field::Select;

    my $field = Contentity::Form::Field::Select->new({
        name     => 'fave_number',
        label    => 'Your favourite number',
        value    => 42,
        options  => [
            { name => 'Pi', value => 3.14159 }
            { name => 'Forty-Two', value => 42 }
            { name => 'Sixty-Nine', value => 69 }
        ]
    });

=head1 DESCRIPTION

This module defines a C<select> form field for choosing an item
from a pull-down list.

This module was previously known as C<Badger::Web::Form::Field::Select>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
