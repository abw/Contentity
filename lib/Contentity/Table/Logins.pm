package Contentity::Table::Logins;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Table',
    utils     => 'self_key self_params',
    codec     => 'json';


sub insert {
    my ($self, $params) = self_params(@_);
    my $data = $params->{ data };

    $params->{ data } = encode($data)
        if $data && ref $data;

    $self->SUPER::insert($params);
}

sub update {
    my ($self, $params) = self_params(@_);
    my $data = $params->{ data };

    $params->{ data } = encode($data)
        if $data && ref $data;

    $self->SUPER::update($params);
}

sub record {
    my ($self, $params) = self_params(@_);
    my $data = $params->{ data };

    $params->{ data } = decode($data)
        if $data && ! ref $data;

    $self->debug_data("login record data", $params) if DEBUG;
    #$self->debug_callers;

    $self->SUPER::record($params);
}

sub logout_all_session_logins {
    my ($self, $session_id) = self_key( session_id => @_ );
    $self->execute( logout_all_session_logins => $session_id );
}

sub logout_all_user_logins {
    my ($self, $user_id) = self_key( user_id => @_ );
    $self->execute( logout_all_user_logins => $user_id );
}

sub delete_all_user_logins {
    my ($self, $user_id) = self_key( user_id => @_ );

    # First make sure there aren't any sessions that have one of the login
    # records belonging to this user referenced as an active login (i.e.
    # session.login_id => login.id)
    $self->model->sessions->clear_all_user_logins( user_id => $user_id  );

    # Then we can delete any login records belonging to this user
    $self->execute( delete_all_user_logins => $user_id );
}


1;

__END__

=head1 NAME

Contentity::Table::Logins - interface to the C<login> database table

=head1 SYNOPSIS

    use Contentity;

    # fetch logins table
    my $table = Contentity->logins;

    # fetch all logins for a user
    my $records = $logins->fetch_all( user_id => $n );

    # print relevant detail
    foreach my $login (@$records) {
        print $login->user->name, ", ";
        print $login->logged_in,  ", ";
        print $login->logged_out, "\n";
    }

=head1 DESCRIPTION

This module implements an interface to the C<login> database table.

Database records are returned as L<Contentity::Record::Login> objects.

=head1 METHODS

The following methods are implementation in addtion to those inherited from the
L<Contentity::Database::Table>,
L<Contentity::Database::Table>,
L<Badger::Database::Table>,
L<Badger::Database::Queries>,
L<Badger::Database::Base> and
L<Badger::Base>
base classes.

=head2 insert(\%data)

Custom insert method which serialises any C<data> field as JSON.

=head2 update(\%data)

Custom update method which serialises any C<data> field as JSON.

=head2 logout_all_session_logins($session_id)

Sets the C<logged_out> field to the current timestamp for all login records
relating to a particular C<session_id>.

=head2 logout_all_user_logins($user_id)

Sets the C<logged_out> field to the current timestamp for all login records
relating to a particular C<user_id>.

=head2 delete_all_user_logins($user_id)

Deletes all login record related to a particular C<user_id>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Record::Login>, L<Contentity::Database>, L<Contentity::Database::Table>,
L<Badger::Database::Table>, L<Badger::Database::Queries>,
L<Badger::Database::Base> and L<Badger::Base>.

=cut
