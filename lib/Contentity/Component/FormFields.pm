package Contentity::Component::FormFields;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'factory',
    asset     => 'field',
    utils     => 'split_to_list',
    constant  => {
        FACTORY_ITEM    => 'field',
        FACTORY_TYPE    => 'fields',
        FACTORY_PATH    => 'Contentity::Form::Field',
        FACTORY_DEFAULT => 'Contentity::Form::Field::Text',
        SINGLETONS      => 0,
    };

sub instance_config {
    my ($self, $data) = @_;
    # In the usual case a factory component assumes that the things it creates
    # are full-blown components and require a nested configuration like so:
    #  {
    #      workspace => $self->workspace,
    #      config    => $data,   # instance config $data
    #      # ...other stuff...
    #  }
    # In this case we don't need or want that.  We just want to pass back the
    # main $data config.  Contained therein is a reference to the form that
    # these fields are being attached to.  If a field needs to access the
    # workspace then it can do so via the form reference.
    $self->debug_data( instance_config => $data ) if DEBUG;
    return $data;
}

sub field_list {
    my $self  = shift;
    my $specs = @_ == 1 ? shift : [ @_ ];
    my $n     = 1;

    $specs = split_to_list($specs);

    my @fields = map {
        # add 'n' as the field number
        $_->{ n } ||= $n++;
        local $_->{ factory } = $self;
        $self->debug_data( init_field => $_ ) if DEBUG;
        $self->field($_);
    } @$specs;

    $self->debug('returning field list: ', $self->dump_data_inline(\@fields))
        if DEBUG;

    return wantarray
        ?  @fields
        : \@fields;
}


1;

__END__

=head1 NAME

Contentity::Component::FormFields - factory module for creating fields

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This is a factory module for loading and instantiating form field modules. It
is a subclass of L<Badger::Factory> which provides most of the functionality.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Form::Field>.

=cut
