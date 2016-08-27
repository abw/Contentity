package Contentity::Web::App::SLIM;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Web::App::Record',
    messages  => {
        loaded         => 'Loaded data for %s #%s',
        deleted        => 'Deleted %s #%s',
        deny_action_id => 'You cannot %s %s #%s',
    };


#-----------------------------------------------------------------------------
# action handlers
#-----------------------------------------------------------------------------

sub default_action {
    shift->search_action;
}

#-----------------------------------------------------------------------------
# Search / List
#-----------------------------------------------------------------------------

sub search_action {
    my $self   = shift;
    my $params = $self->params;
    my $form   = $self->search_form;

    # if any parameters have been specified perform the search and set the results in the stash
    if (%$params && $form->validate) {
        my $values = $form->field_values;
        $self->debug_data( params => $params ) if DEBUG or 1;
        $self->debug_data( form_values => $values ) if DEBUG or 1;
        $self->set(
            results => $self->search($form->values)
        );
    }

    return  $self->wants_json
        ?   $self->send_json_data
        :   $self->present('search');
}

sub search_form {
    # MAY be reimplemented by subclasses
    shift->form('search');
}

sub search {
    # MUST be reimplemented by subclasses
#    shift->not_implemented;
    shift->table->search(@_);
}


#-----------------------------------------------------------------------------
# Info
#-----------------------------------------------------------------------------

sub info_action {
    my $self   = shift;
    my $record = $self->load_one_record;

    return  $self->wants_json
        ?   $self->send_json_success(
                $self->message( loaded => $self->RECORD, $self->record_id ),
                $self->json_data,
            )
        :   $self->present('info');
}

#-----------------------------------------------------------------------------
# Edit
#-----------------------------------------------------------------------------

sub edit_action {
    my $self   = shift;
    my $record = $self->load_one_record;
    $self->todo;

}


#-----------------------------------------------------------------------------
# Delete
#-----------------------------------------------------------------------------

sub delete_action {
    my $self = shift;
    my $id   = $self->record_id_param
        || return $self->error_msg( missing => $self->RECORD );

    unless ($self->config('can_delete')) {
        $self->debug("The delete action is disabled.  Set the can_delete option to enable it");
        return $self->error_redirect( deny_action_id => delete => $self->RECORD, $id );
    }

    $self->table->delete( id => $id );

    return $self->success_redirect(
        deleted => $self->RECORD, $id
    );
}


1;


=head1 NAME

Contentity::Web::App::SLIM - a Search/List/Info/Manage base class web app

=head1 DESCRIPTION

This is a "SLIM" base class for admin web application functionality.
SLIM is an acronym for "Search, List, Info, Manage", reflecting the
main operations that we can perform on a particular record type.

=head1 ACTION HANDLING METHODS

The following methods are automagically mapped (by virtue of the
C<_action> suffix to URLs.

=head2 search_action()

Displays a search form.  On submission it calls

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Web::App::Record>,
L<Contentity::Web::App>,
L<Contentity::Database>,
L<Contentity::Database::Record>,
L<Badger::Database::Record> and
L<Badger::Base>.

=cut
