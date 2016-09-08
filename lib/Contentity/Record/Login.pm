package Contentity::Record::Login;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Record',
    utils     => 'Now extend split_to_list',
    accessors => 'data',
    codec     => 'json';


sub user {
    my $self = shift;
    return  $self->{ user_record }
        ||= $self->load_user;
}

sub load_user {
    my $self  = shift;

    return $self->decline("User is logged out")
        if $self->logged_out;

    my $users = $self->model->users;
    my $row   = $users->fetch_row( id => $self->user_id )
        || return $self->error_msg( invalid => user_id => $self->user_id );

    return $users->record(
        # add in references to session and login in case we need to later
        # determine if the user if logged in
        extend(
            $row,
            {
                session_id   => $self->session_id,
                login_id     => $self->id,
                login_record => $self,
            }
        )
    );
}

sub logout_now {
    my $self = shift;

    return $self->logged_out
        ?  $self->decline("User already logged out: " . $self->logged_out)
        :  $self->update( logged_out => Now->timestamp );
}

sub XXXrealm_roles {
    my $self = shift;
    my $data = $self->data || return;
    return $data->{ roles };
}

sub XXXrealm_roles_hash {
    my $self   = shift;
    my $name   = shift;
    my $format = shift;
    my $roles = $self->realm_roles || return;

    if ($name) {
        # return just the one requested
        return $self->split_list_to_hash( $roles->{ $name }, $format );
    }
    return {
        # return a hash ref of them alljust the one requested
        map { $_ => $self->split_list_to_hash( $roles->{ $_ }, $format ) }
        keys %$roles
    }
}

sub split_list_to_hash {
    my $self   = shift;
    my $list   = shift || return { };
    my $format = shift || '%s';
    return {
        map { sprintf($format, $_) => 1 }
        @{ split_to_list( $list ) }
    };
}


1;


__END__

=head1 NAME

Contentity::Record::Login - a record from the C<login> table

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

This module defines an object to represent records in the C<login> database
table.

Database records are returned by the L<Contentity::Table::Logins> object which
manages the C<login> database table.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Contentity::Record::Base::Hierarchy>, L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>
base classes.

=head2 id()

The unique numerical login identifier for the record.

=head2 user_id()

The numerical identifier of the user who logged in.

=head2 user()

A L<Contentity::Record::User> object representing the user who logged in.

=head2 session_id()

The numerical identifier of the browser session used to log in.

=head2 session()

A L<Contentity::Record::Session> object representing the browser session used to log in.

=head2 logged_in()

A timestamp indicating the time at which they logged in.

=head2 logged_out()

A timestamp indicating the time at which they logged out.  Returns C<undef>
if the user hasn't logged out.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Table::Logins>, L<Contentity::Database>, L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>.

=cut
