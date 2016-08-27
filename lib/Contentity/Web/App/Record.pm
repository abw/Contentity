package Contentity::Web::App::Record;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Web::App',
    utils     => 'plural';

# default redirect locations
our $URLS = {
    no_record  => 'index',
    bad_record => 'index',
};

#-----------------------------------------------------------------------------
# The RECORD constant method should be re-defined by subclasses, typically
# via the 'record' option for Contentity::Class.  TABLE default to plural of
# RECORD or can be set via the 'table' option in Contentity::Class
#-----------------------------------------------------------------------------

sub RECORD {
    shift->not_implemented;
}

sub RECORD_ID {
    shift->RECORD . '_id';
}

sub RECORD_URI {
    shift->RECORD . '_uri';
}

sub TABLE {
    plural( shift->RECORD );
}

#-----------------------------------------------------------------------------
# Methods for parameter handling
#-----------------------------------------------------------------------------

sub record_name {
    shift->RECORD;
}

sub record_id_param {
    my $self = shift;
    return $self->param($self->RECORD_ID);
}

sub record_uri_param {
    my $self = shift;
    return $self->param($self->RECORD_URI);
}


#-----------------------------------------------------------------------------
# Methods to get and set record in request/response context
#-----------------------------------------------------------------------------

sub record {
    my $self = shift;
    return @_
        ? $self->set_record(@_)
        : $self->get_record;
}

sub get_record {
    my $self = shift;
    return $self->get( $self->RECORD );
}

sub set_record {
    my ($self, $record) = @_;
    $self->set( $self->RECORD, $record );
}

sub unset_record {
    my $self = shift;
    $self->set( $self->RECORD, undef );
}

#-----------------------------------------------------------------------------
# Database methods
#-----------------------------------------------------------------------------

sub load_record {
    my $self   = shift;
    my $record = $self->table->fetch(
        $self->load_params(@_)
    ) || return;
    $self->set_record($record);
    return $record;
}

sub load_one_record {
    my $self   = shift;
    my $record = $self->table->fetch_one(
        $self->load_params(@_)
    );
    $self->set_record($record);
    return $record;
}

sub load_params {
    my $self = shift;
    return @_ if @_;

    my $id = $self->record_id_param || return $self->error_msg( missing => $self->RECORD );
    return { id => $id };
}

sub table {
    my $self = shift;
    return $self->model->table($self->TABLE);
}

#-----------------------------------------------------------------------------
# Post-action redirect on success/error
#-----------------------------------------------------------------------------

sub success_redirect_url {
    my $self = shift;
    return $self->param('success_redirect')
        || $self->param('redirect')
        || $self->redirect_url;
}

sub error_redirect_url {
    my $self = shift;
    return $self->param('error_redirect')
        || $self->param('redirect')
        || $self->redirect_url;
}

sub redirect_url {
    my ($self, $params) = self_params(@_);
    return  $self->record
        ?   $self->info_url
        :   $self->index_url;
}

sub index_url {
    shift->url('index');
}

sub info_url {
    my $self   = shift;
    my $record = $self->record || return $self->index_url;
    my $key    = $self->RECORD_ID;
    my $params = { $key => $record->id };
    return $self->url( info => $params );
}

sub success_json_data {
    shift->json_data;
}

sub error_json_data {
    shift->json_data;
}

sub success_redirect {
    my $self = shift;
    my $text = $self->message(@_);

    return $self->wants_json
        ? $self->send_json_success($text, $self->success_json_data)
        : $self->redirect_success($self->success_redirect_url, $text);
}

sub error_redirect {
    my $self = shift;
    my $text = $self->message(@_);

    return $self->wants_json
        ? $self->send_json_error($text, $self->error_json_data)
        : $self->redirect_error($self->error_redirect_url, $text);
}


#-----------------------------------------------------------------------------
# Error reporting methods
#-----------------------------------------------------------------------------

sub no_record {
    my $self = shift;
    return $self->redirect_status_msg(
        no_record => warning => missing => $self->RECORD
    );
}

sub bad_record {
    my $self = shift;
    return $self->redirect_status_msg(
        bad_record => warning => invalid => $self->RECORD => @_
    );
}



1;


=head1 NAME

Contentity::Web::App::Record - base class webapp for displaying a database record

=head1 SYNOPSIS

    package Your::Web::App::Widget;

    use Contentity::Class
        version   => 0.01,
        debug     => 0,
        base      => 'Contentity::Web::App::Record',
        record    => 'widget';

    1;

=head1 DESCRIPTION

This module implements a base class for web applications that provides
a number of methods for dealing with records in a particular database
table.

Subclasses must define the C<RECORD> constant method indicating the name of
the record type that the subclass deals with.  The easiest way to do this is
via the C<record> option of C<Contentity::Class>.

For example L<Your::Web::App::Widget> could define the C<record> to be
C<widget> like so:

    package Your::Web::App::Widget;

    use Contentity::Class
        version   => 0.03,
        debug     => 0,
        base      => 'Contentity::Web::App::Record',
        record    => 'widget';

The module implements a custom C<dispatch()> method.

=head2 METHODS

=head2 RECORD

The RECORD constant method should be re-defined by subclasses, typically
by using the C<record> import option for Contentity::Class.

=head2 RECORD_ID

This returns the C<RECORD> name with C<_id> appended, e.g. C<widget_id>.

=head2 RECORD_URI

This returns the C<RECORD> name with C<_uri> appended, e.g. C<widget_uri>.

=head2 TABLE

This returns the plural form of C<RECORD> as the default internal name
for the table.  Note that we use the plural form for tables, e.g.
C<users> and singular for records, e.g. C<user>.  However the actual
name of the database table is defined in the table configuration file
and can be something entirely different, e.g. C<user>, C<users>,
C<people>, etc.

If the automatically generated plural form of the record is incorrect
(e.g. C<persons> as the plural of C<person> when you want C<people>)
then you can redefine this method in your class.

The C<table> import option of C<Contentity::Class> can be used for
this purpose.

    package Your::Web::App::Person;

    use Contentity::Class
        version   => 0.03,
        debug     => 0,
        base      => 'Contentity::Web::App::Record',
        record    => 'person',
        table     => 'people';

=head2 record_name()

Returns the same thing as L<RECORD>.  This is considered to be a more
user-friendly external method whereas L<RECORD> is more for internal
use.

=head2 record_id_param()

Returns any request parameter matching the C<RECORD_ID> name, e.g.
C<widget_id>.

=head2 record_uri_param()

Returns any request parameter matching the C<RECORD_URI> name, e.g.
C<widget_uri>.

=head2 record()

General purpose get/set method to get (when called without arguments)
or set (when called with an argument) a selected record.

Delegates to L<set_record()> or L<get_record()> accordingly.

=head2 get_record()

Returns the C<RECORD> (e.g. widget) which has previously been saved
in the variable stash (i.e. by L<set_record()>).

=head2 set_record($record)

Sets the C<RECORD> (e.g. widget) in the variable stash to the value
passed as an argument.

=head2 unset_record()

Deletes any C<RECORD> (e.g. widget) stored in the variable stash.

=head2 load_record()

Loads one (or none) record from the database table.

The L<table()> method is called to fetch the correct table reference.

The C<fetch()> method is called on the table, passing the arguments
returned by the L<load_params()> method.

If a record is returned then L<set_record()> is called to store it
in the variable stash and the record is returned.  Otherwise the
method silently returns C<undef>.

=head2 load_one_record()

Like L<load_record()> but expects to load exactly one record. An
error will be thrown if a record cannot be loaded.

=head2 load_params()

This method calls C<record_id_param()> to fetch a record identifier
specified as a request parameter.  An error is throw (e.g.
"No widget specified") if the parameter is not specified.

It returns a hash reference containing a single C<id> key mapped to
the above identifier.  In the usual case this is sufficient to load
the correct database record.

Subclasses may want to redefine this method if a different set of
selection parameters are required.

NOTE: If any arguments are passed to this method then it short-circuits
and returns only those arguments.


=head2 no_record()

An error reporting method used when a record identifier is not specified.

=head2 bad_record()

An error reporting method used when an invalid record identifier is
specified.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2016 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Web::App>
L<Contentity::Class>

=cut
