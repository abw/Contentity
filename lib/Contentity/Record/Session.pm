package Contentity::Record::Session;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Record',
    codec     => 'json',
    utils     => 'params self_params extend Now',
    alias     => {
        get   => \&fetch,
        set   => \&set,
    };

use Badger::Timestamp 'Timestamp';


#-----------------------------------------------------------------------------
# Init method
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    my $data = $config->{ data };

    if ($data) {
        $config->{ data } = decode($data)
            unless ref $data;
    }
    else {
        $config->{ data } = { };
    }

    $config->{ time } = Timestamp($config->{ time } || time);
    $config->{ warm } = 0;

    $self->debug("loading session: ", $self->dump_data($config->{ data }))
        if DEBUG;

    return $self->SUPER::init($config);
}


#-----------------------------------------------------------------------------
# Data methods
#-----------------------------------------------------------------------------

sub data {
    my $self = shift;
    if (@_ > 1) { return $self->store(@_) }
    elsif (@_)  { return $self->fetch(@_) }
    else        { return $self->{ data } }
}

sub data_encoded {
    encode( shift->{ data } );
}

sub fetch {
    my ($self, $item) = @_;
    return $self->{ data }->{ $item };
}

sub store {
    my $self = shift;
    my ($name, $value);
    while (@_) {
        ($name, $value) = splice(@_, 0, 2);
        $self->{ data }->{ $name } = $value;
        $self->debug("Session stored $name => $value\n") if DEBUG;
    }
    $self->{ warm } = 1;
    return $self;
}

sub delete {
    my $self = shift;
    my $data = $self->{ data };
    my $name = shift;
    $self->{ warm } = 1;
    $self->debug("Deleted $name from session\n") if DEBUG;
    return delete $self->{ data }->{ $name };
}


#-----------------------------------------------------------------------------
# Authentication methods
#-----------------------------------------------------------------------------

sub new_login {
    my $self    = shift;
    my $user    = shift || return $self->error_msg( missing => 'user' );
    my $params  = params(@_);
    my $timeout = $params->{ timeout } || 0;
    my $logins  = $self->model->logins;

    # logout any previous login for this session
    $logins->logout_all_session_logins(
        session_id => $self->id,
    );

    # fetch the hash array of user realm roles
    #my $roles = $user->realm_roles_hash;
    #$self->debug_data( realm_roles => $roles ) if DEBUG;

    # create a new login record
    my $login = $logins->insert(
        %$params,
        user_id    => $user->id,
        session_id => $self->id,
        logged_in  => Now->timestamp,
        data       => {
            message => 'Hello World!',
            #roles  => $roles,
        },
    );

    $self->debug("Created new login: ", $login, " => ", $login->id) if DEBUG;

    # add the login data to the session data as the 'login' item
    $self->data(
        timeout => $timeout,            # not used at present
    );

    # set the the login_id (and save the session data as a side-effect)
    $self->save(
        login_id => $login->id,
    );

    $self->debug("saved login id: ", $self->login_id) if DEBUG;
    $self->debug("session bound to user #", $user->id) if DEBUG;

    # The auto-generated login() method caches the login record in login_record.
    # If there is one, we can replace it, otherwise we can set it here to save
    # the login() method to trouble of going to fetch it again
    $self->{ login_record } = $login;

    # Also set the user record - Hmmm.... why?  Do we actually use it?
    $self->{ user_record } = $user;

    return $login;
}

sub failed_login_attempt {
    my $self = shift;
    my $n    = $self->login_attempts || 0;
    $n++;
    $self->update(
        login_attempts => $n,
    );
    return $n;
}

sub logout {
    my $self  = shift;
    my $login = $self->login || return $self->decline("No login to logout");
    my $data  = $self->data;
    my $uid   = $login->user_id;

    # Set the login record to be logged_out
    $login->logout_now;

    # Delete anything cached in the session object that identifies the user
    delete @$self{ qw( login_record user_record ) };

    # Also delete anything from the session data that identifies the user
    delete @$data{ qw( login_id login_attempts login user timeout ) };

    return 1;
}

sub user {
    my $self  = shift;
    # The user_record can be pre-set by the Contentity::Table::Session
    # session_login_user() method or loaded above in
    $self->debug("session user()  (self: $self->{ user_record })") if DEBUG;
    return $self->{ user_record }
        || $self->login_user_record;
}

sub login_user_record {
    my $self  = shift;
    my $login = $self->login || return;
    return $login->user;
}


#-----------------------------------------------------------------------------
# Persistence methods
#-----------------------------------------------------------------------------

sub save {
    my ($self, $params) = self_params(@_);
    $self->debug("saving session $self->{ id }: ", $self->dump_data($self->{ data }), "\n") if DEBUG;
    $self->table->update(
        %$params,
        id   => $self->{ id   },
        data => $self->{ data },
    );
    # copy any updates in $params into $self
    extend($self, $params);
    $self->{ warm } = 0;
    return 1;
}

sub touch {
    my $self = shift;
    $self->{ warm } = 1;
}

sub warm {
    my $self = shift;
    return @_ ? ($self->{ warm } = shift) : $self->{ warm };
}

sub DESTROY {
    my $self = shift;
    $self->debug("saving warm session on DESTROY\n") if DEBUG && $self->{ warm };
    $self->save if $self->{ warm };
}

1;


__END__

=head1 NAME

Contentity::Record::Session - a record from the C<session> table

=head1 SYNOPSIS

    use Contentity;

    my $session = Contentity->sessions->fetch( id => $some_hex_id );

=head1 DESCRIPTION

This module defines an object to represent records in the C<session> database
table.

Database records are returned by the L<Contentity::Table::Sessions> object which
manages the C<session> database table.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>
base classes.

TODO: some of this has changed.  We no longer store user_id, but login_id

=head2 id()

The unique hexadecimal identifier for the session.

=head2 user_id()

The numerical identifier of a user who is currently logged in via this session.

=head2 user()

A reference to a L<Contentity::Record::User> object representing the user who is
currently logged in.

=head2 last_user_id()

The numerical identifier of a user who was previously (but is no longer)
logged in via this session.

=head2 last_user()

A reference to a L<Contentity::Record::User> object representing the user who was
previously logged in via this session.

=head2 data()

Returns a hash reference containing session data.  If you update this hash
array manually then you must also call the C<touch()> method to mark the
session as dirty (requiring automatic save) or call C<save()> to manually save
the session.

Can also be called with a single argument to fetch a data item:

    print $session->data('roles');

Or with multiple arguments to set data items

    print $session->data(
        roles => { admin => 1 },
    );

=head2 data_encoded()

Returns the session data encoded as JSON.

=head2 fetch($name) / get($name)

Method to explicitly fetch a data item.

=head2 store($name, $value) / set($name, $value)

Method to explicitly store a data item.

=head2 delete($name)

Method to delete a data item.

=head2 save()

Method to explicitly save the session.  This is not normally required as any
calls to L<store()> or L<data()> with more than one argument, will automatically
mark the session as "warm", thus triggering the automatic saving mechanism.

=head2 touch()

Method to explicitly mark the session as warm in order to trigger the automatic
saving mecanism when the session object goes out of scope.

=head2 warm()

Returns a boolean flag to indicate if the session has been modified and requires
saving.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2015 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Table::Sessions>, L<Contentity::Database>, L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>.

=cut
