package Contentity::Table::Invites;

use Contentity::Class
    version   => 0.03,
    debug     => 0,
    base      => 'Contentity::Database::Table',
    throws    => 'Contentity.Invites',
    utils     => 'self_params self_key params md5_hex Now',
    constants => 'ACTIVE :invites',
    codec     => 'json';

our $GEN_ID_ATTEMPTS    = 5;

sub init_table {
    my ($self, $config) = @_;
    $self->{ delete_old_invites_after } = $config->{ delete_old_invites_after }
        || DELETE_OLD_INVITES;
}


sub create {
    my ($self, $params) = self_params(@_);
    my $email = $params->{ email   } || return $self->error_msg( missing => 'email' );
    my $type  = $params->{ type    } || return $self->error_msg( missing => 'invite type' );
    #my $uid   = $params->{ user_id } || return $self->error_msg( missing => 'invite user id' );
    my $space = $self->workspace;

    $self->debug_data("Creating invite: ", $params) if DEBUG;

    # We look in the config/invite_types.yaml for an entry matching
    # the invite type
    my $config = $space->invite_type($type)
        || return $self->error_msg( invalid => 'invite type' => $type );

    # look for an expiry parameter either in the params or the config
    my $expires = $params->{ expires } || $config->{ expires } || INVITE_EXPIRY;

    # add the expiry time onto current time to get expiry timestamp
    $params->{ expires } = Now->adjust( $expires )->timestamp;

    $self->debug("expires in $expires : $params->{ expires }") if DEBUG;

    # generate a unique id as a hex MD5 hash
    $params->{ id         }   = $self->generate_id($params);
    $params->{ invited_by } ||= $space->system_user_id;

    # encode any parameters
    $params->{ params } = encode($params->{ params })
        if $params->{ params } && ref $params->{ params };

    $self->debug_data("Inserting invite record: ", $params) if DEBUG;

    my $row = $self->insert($params);

    $self->debug("Inserted invite row, now fetching back out") if DEBUG;

    return $self->fetch( id => $row->{ id } )
        || $self->error("Cannot fetch inserted invite record: $row->{ id }");
}


sub generate_id {
    my ($self, @args) = @_;

    foreach (1..$GEN_ID_ATTEMPTS) {
        my $id = md5_hex(@args, $$, time(), rand(1));
        $self->debug("checking to see if MD5 hash is in use: $id") if DEBUG;
        return $id unless $self->fetch($id);
        $self->debug("failed to generate a unique MD5 id (attempt #$_/$GEN_ID_ATTEMPTS)\n")
            if DEBUG;
    }
    return $self->error("failed to generate a unique MD5 id after $GEN_ID_ATTEMPTS attempts");
}


sub active_type {
    my ($self, $type, @args) = @_;
    my $params = params(@args);
    my $email  = $params->{ email } || $params->{ address }
        || return $self->error_msg( missing => 'email' );

    my $invite = $self->fetch(
        email  => $email,
        type   => $type,
        status => ACTIVE,
    ) || return $self->decline('no registration invite');

    if ($invite->expired) {
        return $self->decline("registration invite has expired");
    }

    return $invite;
}

sub active_registration {
    shift->active_type( registration => @_ );
}

sub active_validation {
    shift->active_type( validation => @_ );
}


# When we create a record we use the Contentity::Record::Invite::XXX class
# where XXX is defined by the type field
sub record {
    shift->subclass_record( type => @_ );
}

sub delete_old_invites {
    my $self = shift;
    my $when = $self->{ delete_old_invites_after };
    # we must negate the time difference so we count BACK in time
    my $time = Now->adjust("-$when");
    $self->debug("deleting old invites where $when old, i.e. time < $time") if DEBUG;
    $self->execute( delete_old_invites => $time );
}

sub delete_all_user_invites {
    my ($self, $uid) = self_key( user_id => @_ );
    $self->execute( delete_all_user_invites => $uid, $uid );
}


1;

__END__

=head1 NAME

Contentity::Table::Invites - interface to the invite database table for validating email addresses

=head1 DESCRIPTION

This module implements an interface to the C<invite> database table.
An invite record is create when a user registers, is invited to join by another
user (perhaps as part of a mailing list upload), requests a password recovery,
or any other action that requires a round-trip email validation.

A new invite record is created with a hard-to-guess identifier and an email
is sent to the user asking them to click on a link containing the invite ID
as a parameter.

The module is implemented as a subclass of the L<Contentity::Database::Table> which
is itself a thin wrapper around the L<Badger::Database::Table> module.

Database records are returned as L<Contentity::Record::Invite> objects.

=head1 METHODS

The following methods are implemented in addition to those inherited from the
L<Contentity::Database::Table>, L<Badger::Database::Table>,
L<Badger::Database::Queries>, L<Badger::Database::Base> and L<Badger::Base>
base classes.

=head2

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2018 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Record::Invite>,  L<Contentity::Database>,
L<Contentity::Database::Table>, L<Badger::Database::Table>,
L<Badger::Database::Queries>,
L<Badger::Database::Base> and L<Badger::Base>.

=cut
