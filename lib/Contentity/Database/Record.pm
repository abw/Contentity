package Contentity::Database::Record;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Badger::Database::Record Contentity::Base',
    utils     => 'extend';


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_record($config);
    return $self;
}

sub init_record {
    my ($self, $config) = @_;
    extend($self, $config);
}


#-----------------------------------------------------------------------------
# Methods for returning the raw data for the record, possibly augmented
# with related data.  The field_data() method returns a hash reference of
# those fields defined as columns in the database.  The data() method is
# a wrapper around that which subclasses will typically modify to augment
# the field_data() with other data (e.g. a property adding the address data).
# The more_data() method can be used to add additional data according to an
# access policy.  A subclass can define $MORE_DATA_ITEMS
#-----------------------------------------------------------------------------

sub data {
    shift->core_data;
}

sub core_data {
    # subclasses can redefine this method to add/remove data
    shift->field_data;
}

sub field_data {
    my $self   = shift;
    my $fields = $self->table->fields;
    return {
        map { $_ => $self->{ $_ } }
        @$fields
    };
}

#-----------------------------------------------------------------------------
# Methods for returning the parameter which identifies a subject in various
# combinations, e.g. user_id, user_id => $n, for a user record.
#-----------------------------------------------------------------------------

sub id_pair {
    my $self = shift;
    return ($self->id_param_name, $self->{ id });
}

sub id_param_name {
    my $self   = shift;
    my $record = $self->RECORD || return $self->error_msg( missing => 'RECORD' );
    return $record . '_id';
}

sub add_id_param {
    my ($self, $params) = @_;
    $params->{ $self->id_param } = $self->{ id };
    return $params;
}

#-----------------------------------------------------------------------------
# Constant methods which subclasses are expected to redefine, usually via
# the Cog::Class record/table hooks
#-----------------------------------------------------------------------------

sub TABLE {
    shift->not_implemented;
}

sub RECORD {
    shift->SUBJECT_TYPE;
}

sub SUBJECT_TYPE {
    shift->table->name;
}

sub SUBJECT_ID {
    shift->id;
}

sub subject_type_id_pair {
    my $self = shift;
    return ($self->SUBJECT_TYPE, $self->SUBJECT_ID);
}


#-----------------------------------------------------------------------------
# Misc methods
#-----------------------------------------------------------------------------


sub workspace {
    shift->table->workspace;
}

sub reload {
    my $self = shift;
    my $key  = $self->key;
    my $data = $self->table->fetch_one_row( $key => $self->{ $key } );
    $self->debug_data( reload => $data ) if DEBUG;
    extend($self, $data);
    return $self;
}

1;



=head1 NAME

Cog::Database::Record - database component

=head1 DESCRIPTION

This is a subclass of L<Badger::Database::Record> with some additional functionality
for integration into the L<Contentity> framework.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2022 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database::Record>

=cut
