package Contentity::Record::User;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Record',
    status    => 'pending active locked expired system',
    accessors => 'session_id login_id',
    utils     => 'params self_params self_key split_to_list split_to_hash Timestamp Now md5_hex',
    constants => 'HASH MATCH_EMAIL EMAIL_ADDRESS_LINE_FORMAT :status :user_types',
    messages  => {
        email_not_validated => 'This email address has not been validated: %s',
        user_not_active     => 'The user account is not active: #%s %s',
        bad_status          => 'You cannot change a user status from %s to %s',
    };


#-----------------------------------------------------------------------------
# General accessor and data methods
#-----------------------------------------------------------------------------

sub name {
    my $self = shift;
    return join(
        ' ',
        grep { defined $_ && length $_ }
        @$self{ qw( forename surname ) }
    );
}

sub registered {
    my $self = shift;
    return Timestamp( $self->{ registered } );
}

sub md5_email {
    # Hashed version of the email for getting gravatars
    my $self = shift;
    return md5_hex( $self->{ email } );
}

#-----------------------------------------------------------------------------
# Password
#-----------------------------------------------------------------------------

sub check_password {
    my ($self, $guess) = @_;
    $self->table->decode_password(
        $self->{ password },
        $guess
    );
}

sub set_password {
    my ($self, $password) = @_;

    # we don't perform any stringent password checking here, but we do
    # assert than a non-zero length password is provided.
    return $self->error_msg( invalid => password => 'none provided' )
        unless defined $password && length $password;

    # update database record - the table handles password encryption
    return $self->update( password => $password );
}

#-----------------------------------------------------------------------------
# Status
#-----------------------------------------------------------------------------

our $VALID_STATUS_FROM_TO = {
    pending => { pending => 0, active => 1, locked => 1, expired => 1 },
    active  => { pending => 1, active => 0, locked => 1, expired => 1 },
    locked  => { pending => 1, active => 1, locked => 0, expired => 1 },
    expired => { pending => 0, active => 0, locked => 1, expired => 0 },
};

# The 'status' import hook passed to Contentity::Class above auto-creates the
# set_status() method.  But we want a custom one.  Temporarily turn
# off the 'redefine' warning so Perl knows we know what we're doing and
# doesn't bug us with a warning.

no warnings 'redefine';

sub set_status {
    my ($self, $to) = @_;
    my $from = $self->status;
    my $ok   = $VALID_STATUS_FROM_TO->{ $from }->{ $to };

    if ($ok) {
        $self->update( status => $to );
        return 1;
    }
    else {
        return $self->decline_msg( bad_status => $from, $to );
    }
}

use warnings 'redefine';

sub activate {
    shift->set_status(ACTIVE);
}

sub lock {
    shift->set_status(LOCKED);
}

sub expire {
    shift->set_status(EXPIRED);
}


#-----------------------------------------------------------------------
# Email addresses
#-----------------------------------------------------------------------

# email_addresses() is defined as a relation

sub email_address {
    my $self = shift;
    my $args;

    if (@_ == 1) {
        # single argument can be an email address, e.g. 'abw@wardley.org'
        # or reference to a hash of named parameters
        $args = ref $_[0] eq HASH ? shift : { address => shift };
    }
    else {
        # multiple arguments are named parameters
        $args = { @_ };
    }

    # add user id to parameters and default address to user's login email
    $args->{ user_id }   = $self->{ id };
    $args->{ address } ||= $self->{ email };

    # now fetch it from the email_addresses table
    $self->model->user_emails->fetch($args)
        || return $self->decline("Invalid email address: ", $args->{ address });
}

sub validated_email_addresses {
    my $self  = shift;
    my $addrs = $self->email_addresses;
    return [
        grep { $_->validated }
        @$addrs
    ];
}

sub unvalidated_email_addresses {
    my $self  = shift;
    my $addrs = $self->email_addresses;
    return [
        grep { ! $_->validated }
        @$addrs
    ];
}

sub sort_email_addresses {
    my ($self, $addrs) = @_;
    my @sortable = @$addrs;
    my (@validated, @unvalidated, $primary);

    foreach my $addr (@$addrs) {
        # add the primary email address to the start of the list, all
        # other addresses to the end
        if (! $primary && $addr->address eq $self->{ email }) {
            $primary = $addr;
        }
        elsif ($addr->validated) {
            push(@validated, $addr);
        }
        else {
            push(@unvalidated, $addr);
        }
    }

    @validated   = sort { $a->address cmp $b->address } @validated;
    @unvalidated = sort { $a->address cmp $b->address } @unvalidated;

    return [
        grep { defined }
        ($primary, @validated, @unvalidated)
    ];
}

sub sorted_email_addresses {
    my $self = shift;
    return $self->sort_email_addresses(
        $self->email_addresses
    );
}

sub sorted_validated_email_addresses {
    my $self = shift;

    return $self->sort_email_addresses(
        $self->validated_email_addresses
    );
}

sub sorted_unvalidated_email_addresses {
    my $self = shift;

    return $self->sort_email_addresses(
        $self->unvalidated_email_addresses
    );
}

sub add_email_addresses {
    my ($self, $addrs) = @_;

    $addrs = split_to_list($addrs);

    foreach my $addr (@$addrs) {
        $self->add_email_address($addr);
    }
}

sub add_email_address {
    my $self = shift;
    my $args;

    if (@_ == 1) {
        # single argument can be an email address, e.g. 'abw@wardley.org'
        # or reference to a hash of named parameters
        $args = ref $_[0] eq HASH ? shift : { address => shift };
    }
    else {
        # multiple arguments are named parameters
        $args = { @_ };
    }

    # add user id to parameters
    $args->{ user_id } = $self->{ id };

    # strip of any leading/trailing whitespace
    for ($args->{ address }) {
        s/^\s+//;
        s/\s+$//;
    }

    # check it's a valid email address (for our definition of "valid")
    return $self->error_msg( invalid => 'email address' => $args->{ address } )
        unless $args->{ address } =~ MATCH_EMAIL;

    # now add it to the email_addresses table
    my $email = $self->model->user_emails->insert($args);

    # send the user a notification
    #$self->notify(
    #    user_email_added => { address => $email->address }
    #);

    return $email;
}

sub add_validated_email_address {
    my ($self, $addr) = @_;

    return $self->add_email_address({
        address   => $addr,
        validated => Now->timestamp,
    });
}

sub select_email_address {
    my $self = shift;

    # first fetch the email address to check that we own it
    my $email = $self->email_address(@_)
        || return $self->error($self->reason);

    return $self->error_msg( email_not_validated => $email->address )
        unless $email->validated;

    # now update user record to reflect new address
    my $result = $self->update( email => $email->address );

    # send the user a notification
    # $self->notify( user_email_selected => { address => $email->address } );

    return $result;
}

sub delete_email_address {
    my $self = shift;

    # first fetch the email address (because we're lazy and it's the easiest
    # way to validate that the user can delete this email address)
    my $email = $self->email_address(@_)
        || return $self->error($self->reason);

    # now delete it from the email_addresses table
    my $result = $self->model->user_emails->delete($email->id);

    # send the user a notification
    #$self->notify( user_email_deleted => { address => $email->address } );

    return $result;
}

sub delete_all_email_addresses {
    my $self = shift;
    $self->model->user_emails->user_delete_all($self->{ id });
}

sub email_address_line {
    my $self = shift;
    return sprintf(
        EMAIL_ADDRESS_LINE_FORMAT,
        $self->name,
        $self->email
    );
}

sub valid {
    my $self = shift;

    # user record must be active
    return $self->decline_msg( user_not_active => $self->id, $self->name )
        unless $self->active;

    return 1;
}

sub is_login_user {
    shift->type eq LOGIN_USER_TYPE;
}

#-----------------------------------------------------------------------------
# Sessions and logins
#-----------------------------------------------------------------------------

sub session {
    my $self = shift;
    return  $self->{ session_record }
        ||= $self->load_session;
}

sub load_session {
    my $self = shift;
    my $sid  = $self->session_id || return $self->decline( missing => 'session_id' );
    return $self->model->sessions->fetch( id => $sid );
}

sub login {
    my $self = shift;
    return  $self->{ login_record }
        ||= $self->load_login;
}

sub load_login {
    my $self = shift;
    my $lid  = $self->login_id || return $self->decline( missing => 'login_id' );
    return $self->model->logins->fetch( id => $lid );
}


#-----------------------------------------------------------------------------
# Data methods
#-----------------------------------------------------------------------------

1;

__END__

=head1 NAME

Contentity::Record::User - object representing user records

=head1 DESCRIPTION

This module implements a record class for users.  When a user record is read
from the database via L<Contentity::Table::Users> is it returned as a
C<Contentity::Record::User> object instance.

    use Contentity;
    my $user = Contentity->user( id => 12345 );

=head1 DATA METHODS

Methods are automatically generated to return all database fields for the
user.  See the F<config/databases/cog/users.yaml> specification for full
details.   The following additional data methods are defined.

=head2 name()

Returns a string containing the concatenated values for forename, middle
and surname fields.

=head2 registered()

Returns a L<Contentity::Timestamp> object indicating the date/time at which
the user registered and the user record was inserted into the database.

=head1 RELATION METHODS

Methods are automatically generated to return various relations for the
user.  See the F<config/databases/cog/users.yaml> specification for full
details.

=head1 EMAIL ADDRESS METHODS

=head2 email_addresses()

This method is auto-generated to return a reference to a list of
L<Contentity::Record::EmailAddress> records representing each email address assigned
to the user.

=head2 email_address($email)

Fetches the L<user_email> record for this user's email address if it exists.
It is an effective way of testing if the user really does have a particular
email address.

=head2 validated_email_addresses()

Return a reference to a list of all email addresses that have been validated
by us sending an email to the address with a validation link to click.

=head2 unvalidated_email_addresses()

Return a reference to a list of all email addresses that haven't been validated.

=head2 sorted_email_addresses()

Returns a sorted list of all of the user's email addresses.  Their primary
email address (stored in the user database record) is always returned first.

=head2 sorted_validated_email_addresses()

Returns a sorted list of all validated email addresses.  The primary
email address is always returned first if it appears in the list.

=head2 sorted_unvalidated_email_addresses()

Returns a sorted list of all unvalidated email addresses.  The primary
email address is always returned first if it appears in the list.

=head2 add_email_addresses($emails)

Add multiple email addresses to a user, specified as either a reference to a
list or a string of whitespace and/or comma delimited addresses.

    $user->add_email_addresses([
        'one@example.com',
        'two@example.com',
    ]);

    $user->add_email_addresses(
        'one@example.com two@example.com',
    );

    $user->add_email_addresses(
        'one@example.com, two@example.com',
    );

=head2 add_email_address($email)

Add a new email address for a user.  The address should usually be specified
as a single argument:

    $user->add_email_address('tom@example.com');

However, the method also accepts named parameters to support other methods
such as L<add_validated_email_address()>.

    $user->add_email_address(
        address   => 'tom@example.com',
        validated => '2014-04-20 16:20:00',
    );

=head2 add_validated_email_address($email)

Add a new email address and marks it as being validated now.

    $user->add_validated_email_address('tom@example.com');

=head2 select_email_address($email)

Selects the specified email address as the user's primary (login) address.
The email address must already in the C<user_email> table and validated.
The C<user.email> field is then updated to store this email address.

    $user->select_email_address('tom@example.com');

=head2 delete_email_address($email)

Deletes an email address belonging to the user.

=head2 delete_all_email_addresses();

Deletes all email addresses belonging to the user.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2016 Andy Wardley.  All Rights Reserved.

=cut
