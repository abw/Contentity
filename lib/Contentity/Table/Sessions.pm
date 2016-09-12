package Contentity::Table::Sessions;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Table',
    codec     => 'json',
    utils     => 'self_key self_params generate_id';


sub insert {
    my ($self, $params) = self_params(@_);
    my $data = $params->{ data };

    $params->{ data } = encode($data)
        if $data && ref $data;

    $params->{ cookie } ||= generate_id;

    $self->SUPER::insert($params);
}

sub update {
    my ($self, $params) = self_params(@_);
    my $data = $params->{ data };

    $params->{ data } = encode($data)
        if $data && ref $data;

    $self->SUPER::update($params);
}

sub session_login_user {
    my ($self, $cookie) = self_key( cookie => @_ );
    my $row   = $self->row( session_login_user => $cookie ) || return;
    my $data  = $self->demux( 'user login' => $row );
    my $login = $data->{ login };
    my $user  = $data->{ user  };

    if ($login && $user) {
        my $model = $self->model;

        # Pass the session_id and login_id to the user constructor in case we
        # need to determine if the user is logged in and/or has a session
        $user->{ session_id } = $self->id;
        $user->{ login_id   } = $data->{ login }->{ id };

        # Create record objects for the user and login.  The user record is
        # passed as an option to the login record constructor.  The login record
        # returned is then added as an option to the session record constructor.
        $row->{ login_record }  = $model->logins->record($login);
        $login->{ user_record } = $model->users->record($user);

        # The demux() calls moves login_id into the login-specific data.  That's
        # correct, but we also need a copy in the session data as login_id
        $row->{ login_id } ||= $data->{ login }->{ id };
    }

    return $self->record($row);
}

sub clear_all_user_logins {
    my ($self, $user_id) = self_key( user_id => @_ );
    $self->execute( clear_all_user_logins => $user_id );
}


1;

__END__

=head1 NAME

Contentity::Table::Sessions - interface to the C<session> database table

=head1 SYNOPSIS

    use Contentity;

    # fetch sessions table
    my $sessions = Contentity->sessions;

    # insert realm
    my $session = $sessions->fetch(
        id => $some_hex_string,
    );

=head1 DESCRIPTION

This module implements an interface to the C<session> database table.


Database records are returned as L<Contentity::Record::Session> objects.

=head1 METHODS

The following methods are provided in addition to those inherited from the
L<Contentity::Database::Table>,
L<Badger::Database::Table>,
L<Badger::Database::Queries>,
L<Badger::Database::Base> and
L<Badger::Base>
base classes.

=head2 insert(\%params)

Custom insert method with encodes any data and sets an id if none is defined.

=head2 update(\%params)

Custom insert method with re-encodes any data.

=head2 session_login_user($cookie)

This method runs a query which fetches the session record for a particular
cookie (if it exists), joined with any login and user data corresponding to
a currently active login (i.e. the C<logged_out> field is NULL).  In other
words, it fetches the session, login and user data in a single query instead
of 3.

It returns a C<Contentity::Record::Session> object.  The C<login()> method returns
a pre-populated C<Contentity::Record::Login> object and C<user()> (called against
either the session or login objects) returns a C<Contentity::Record::User> object.

=head2 clear_all_user_logins($user_id)

Sets the C<login_id> to NULL for all session records that have a C<login_id>
referencing a C<login> record for the user specified as an argument.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Record::Session>, L<Contentity::Database>, L<Contentity::Database::Table>,
L<Badger::Database::Table>, L<Badger::Database::Queries>,
L<Badger::Database::Base> and L<Badger::Base>.

=cut
