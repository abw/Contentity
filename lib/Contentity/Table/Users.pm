package Contentity::Table::Users;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Table',
    utils     => 'self_params self_key md5_hex Now',
    constants => ':user_types',
    constant  => {
        PASSWORD_LENGTH => 32,
        SALT_LENGTH     => 32,
        SALT_FORMAT     => 'SALT_%s_PEPPER_%s',
        WILDCARD        => '%',
        AT              => '@',
    };



#-----------------------------------------------------------------------------
# insert() must check the email address is unique and encrypt password
#-----------------------------------------------------------------------------

sub insert {
    my ($self, $params) = self_params(@_);

    # must have an email address
    my $email = $params->{ email }
        || return $self->error( missing => 'email address' );

    # encrypt the password
    my $password = $params->{ password };

    if (defined $password && length $password) {
        $params->{ password } = $self->encode_password($password);
        $self->debug("encoded password: $params->{ password }") if DEBUG;
    }
    else {
        $params->{ password } = '';
        $self->debug("no password") if DEBUG;
    }

    # check we don't have an existing user or email record
    $self->can_insert($params)
        || return $self->error( $self->reason );

    # insert the user
    my $user = $self->SUPER::insert($params);

    $self->debug("inserted user for $email: ", $user->id) if DEBUG;

    $self->model->user_emails->insert(
        user_id => $user->id,
        address => $email,
    );

    return $user;
}


sub can_insert {
    my ($self, $params) = self_params(@_);
    my $model = $self->model;
    my $addrs = $model->user_emails;
    my $email = $params->{ email }
        || return $self->error( missing => 'email address' );

    return $self->decline_msg( user_exists => $email )
        if $self->fetch( email => $email );

    return $self->decline_msg( email_exists => $email )
        if $addrs->fetch( address => $email );

    return 1;
}


#-----------------------------------------------------------------------------
# User login
#-----------------------------------------------------------------------------

sub login_user {
    my ($self, $params) = self_params(@_);

    # email address and password must be provided
    my $email    = $params->{ email }
        || return $self->decline_msg( missing => 'email address' );

    my $password = $params->{ password }
        || return $self->decline_msg( missing => 'password' );

    # fetch the user from the database by email address
    my $user     = $self->fetch( email => $email )
        || return $self->decline_msg( invalid => 'user' );

    # check user is active or pending
    return $self->decline('user is ', $user->status)
        unless $user->active || $user->pending;

    # check user type is 'login'
    #return $self->decline('not a login user: ', $user->type)
    #    unless $user->type eq LOGIN_USER_TYPE;

    $self->debug("checking password for $email") if DEBUG;

    $user->check_password($password)
        || return $self->decline('password incorrect');

    return $user;
}


#-----------------------------------------------------------------------------
# Utility methods
#-----------------------------------------------------------------------------

sub encode_password {
    my ($self, $password, $salt) = @_;
    $salt ||= $self->random_salt;

    my $salted  = sprintf(SALT_FORMAT, $salt, $password);
    my $encrypt = substr(md5_hex($salted), 0, PASSWORD_LENGTH);
    my $encoded = $salt.$encrypt;

    $self->debug(
        "Encoding password:\n",
        "[salt:$salt]\n",
        "[pepper:$password]\n",
        "[salted:$salted]\n",
        "[encrypted:$encrypt]\n",
        "[encoded:$encoded]\n"
    ) if DEBUG;

    return $encoded;
}

sub decode_password {
    my ($self, $encoded, $password) = @_;
    my $salt    = substr($encoded, 0, SALT_LENGTH);
    my $encrypt = substr($encoded, SALT_LENGTH, PASSWORD_LENGTH);
    my $compare = $self->encode_password($password, $salt);

    $self->debug(
        "Decoding password:\n",
        "[encoded:$encoded]\n",
        "[password:$password]\n",
        "[salt:$salt]\n",
        "[encrypted:$encrypt]\n",
        "[compare:$compare]\n",
    ) if DEBUG;

    return $encoded eq $compare
        ? 1         # it's a match
        : 0;        # big plate of fail
}

sub random_salt {
    my $self = shift;
    return substr(
        md5_hex(rand() . time() . { }),       # some random stuff
        0, SALT_LENGTH
    );
}


#-----------------------------------------------------------------------------
# Other selection methods
#-----------------------------------------------------------------------------

sub valid_user {
    my $self = shift;
    my $user = $self->find_user(@_) || return;
    return $user->valid
         ? $user
         : $self->decline( $user->reason );
}

sub find_user {
    my ($self, $params) = self_params(@_);
    my $param;

    if ($param = $params->{ id }) {
        return $self->fetch( id => $param )
            || $self->decline_msg( invalid => id => $param );
    }
    elsif ($param = $params->{ email }) {
        return $self->row_record( fetch_by_email => $param )
            || $self->decline_msg( invalid => email => $param );
    }
    elsif ($param = $params->{ session_id }) {
        return $self->row_record( fetch_by_session_id => $param )
            || $self->decline_msg( invalid => session_id => $param );
    }
    elsif ($param = $params->{ session_cookie }) {
        return $self->row_record( fetch_by_session_cookie => $param )
            || $self->decline_msg( invalid => session_cookie => $param );
    }
    else {
        return $self->error("No valid parameters specifed to find user");
    }
}

sub fetch_by_email {
    my ($self, $email) = self_key( email => @_ );
    return $self->row_record( fetch_by_email => $email );
}


#-----------------------------------------------------------------------------
# update() - must re-encode a new password if one is specified
#-----------------------------------------------------------------------------

sub update {
    my ($self, $params) = self_params(@_);
    my $password = $params->{ password };

    if (defined $password && length $password) {
        $params->{ password } = $self->encode_password($password);
    }

    return $self->SUPER::update($params);
}


1;

__END__

=head1 NAME

Contentity::Table::Users - interface to the user database table

=head1 SYNOPSIS

    use Contentity;

    my $users = Contentity->users;
    my $user  = $users->fetch( id => 42 );

    print "Name: ", $user->name, "\n";

=head1 DESCRIPTION

This module implements an interface to the C<user> database table.  It is
a subclass of the L<Contentity::Database::Table> which is itself a thin wrapper
around the L<Badger::Database::Table> module.

Database records are returned as L<Contentity::Record::User> objects.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Contentity::Database::Table>, L<Badger::Database::Table>,
L<Badger::Database::Queries>, L<Badger::Database::Base> and L<Badger::Base>
base classes.

=head2 can_insert(%params)

Method to test if a user record can be inserted.  It checks for an existing
user or email address record that matches the new user's email address.

    $users->can_insert( email => 'abw@wardley.org' )
        || die "Cannot insert this email record: ", $users->reason;

=head2 insert(%params)

A wrapper around the L<Badger::Database::Table>
L<insert()|Badger::Database::Table/insert()> method which performs some
additional processing.

It first checks that the email address specified is unique (i.e. there is
no existing record in the C<user_email> table) and throws an error if it isn't.
It then encodes the user's password using the L<encode_password()> method.
After inserting the C<user> record it additionally creates a corresponding
record in the C<user_email> table.

=head2 update(%params)

A wrapper around the L<Badger::Database::Table>
L<update()|Badger::Database::Table/update()> method which encodes the
user's password (if defined) using the L<encode_password()> method.

=head2 system_user()

Returns the first user in the database that has a status of C<system>.
We use the system user to own things that nobody else owns, and to be
the sender of email messages, for example.

=head1 INTERNAL METHODS

These methods are intended for internal use by other methods.  However, there's
nothing to stop them from being called externally.

=head2 encode_password($password,$salt)

We store the passwords encrypted in the database to prevent exposing them in
the case of the database being compromised or a backup falling into the wrong
hands. We encrypt the password into an MD5 hex string which is effectively a
one-way algorithm. It's easy to encrypt, but takes too long to decrypt to make
it worthwhile. To authenticate a user, we re-encode the password they enter to
login and compare it to the version in the database.

However, this method is still susceptible to a rainbow table attack. This is
where one of the Bad Guys pre-encrypts all dictionary words and other common
password sequences into MD5 (or more likely, downloads a copy of pre-encrypted
words from the interwebz). They can then recover any of our users' passwords
that are based on dictionary words or are easily guessed (which, let's face
it, is likely to be the majority). They simply compare our MD5 encrypted
passwords with their MD5 passwords and look up the original password that
generated the encrypted version in their rainbow table.  In no time at all
they can expose all weak passwords in our database.

To scupper their plans, we add a random string (known as a 'salt') to the
original password before encoding it. We then store the salt along with the
password in the database. To make things slightly more tricky for them, we use
a salt that is itself an MD5 hash and append it to the password so that it
looks like a longer MD5 sequence. Even if they figure it out and expose the
salt, they still have to generate a rainbow table for the entire dictionary
using this salt.  This takes time (hours, days, weeks) and at best they'll
only be able to crack a single user's password using this rainbow table (and
that's assuming that the user has a dictionary word for a password).
The next user has a different salt so they would have to generate a rainbow
table all over again. This increases the complexity of the operation from
linear to exponential time, making it unfeasible for all practical purposes.

=head2 decode_password($encoded,$password)

The name is slightly misleading because the method doesn't actually de-encrypt
the encrypted password. However, given an C<$encoded> password (such as that
generated by L<encode_password()> and stored in the database), and a
C<$password> that a user has just typed in, the method will encode the
password and check that it matches the encoded version.

=head2 random_salt()

Returns an obscured random text string suitable for L<encode_password()>
to use as a salt.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Record::User>, L<Contentity::Database>, L<Contentity::Database::Table>,
L<Badger::Database::Table>, L<Badger::Database::Queries>,
L<Badger::Database::Base> and L<Badger::Base>.

=cut
