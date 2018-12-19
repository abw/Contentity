package Contentity::Record::Invite;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Record',
    utils     => 'Now Timestamp self_params extend',
    import    => 'class',
    constants => 'PENDING ACTIVE ACCEPTED CANCELLED EXPIRED FAILED NULL_TIME',
    accessors => 'reason params_json',
    codec     => 'json',
    throws    => 'Contentity.invite',
    constant  => {
        SENDER_FORMAT => '%s <%s>',
    },
    messages  => {
        cannot => 'Cannot %s invitation (%s)',
        not    => 'Invite is not %s',
    };

# method aliases
*sent = \&active;
*activated = \&active;


sub init {
    my ($self, $config) = @_;

    # decode parameters
    my $params = $config->{ params };
    $config->{ params_json } = $params;
    $config->{ params } = decode($params)
        if $params && ! ref $params;

    return $self->SUPER::init($config);
}


sub send {
    my ($self, $params) = self_params(@_);
    my $space = $self->workspace;

    return $self->error_msg( cannot => send => $self->{ status } )
        unless $self->pending;

    # We fetch the config for the invite type from the workspace which
    # loads it from config/invite_types.yaml
    my $config  = $space->invite_type->{ $self->{ type } };
    my $inviter = $self->inviter;

    # merge any params defined when the invite was created with those
    # passed as arguments
    $params = extend({ }, $self->params, $params);

    $self->debug_data("invite type [$self->{ type }]", $config) if DEBUG;

    # set defaults for subject and/or template parameters
    $params->{ subject  } ||= $config->{ subject  };
    $params->{ template } ||= $config->{ template };

    my $format = $config->{ sender } || SENDER_FORMAT;

    $params->{ to      } = $self->{ email };
    $params->{ from    } = sprintf($format, $inviter->name, $inviter->email);
    $params->{ inviter } = $inviter->name;
    $params->{ invite  } = $self;

    $self->debug("testing mode")
        if DEBUG && $params->{ testing };

    eval {
        $self->debug_data( email_send => $params ) if DEBUG;
        my $mailer = $self->workspace->project->mailer;
        $mailer->send($params);
    };
    if ($@) {
        my $error = $@;
        $self->debug("invite send failed: $@");
        $self->update(
            status   => FAILED,
            reason   => $error,
            modified => Now->timestamp,
        );
        die $error;
    }

    $self->update(
        status   => ACTIVE,
        modified => Now->timestamp,
    );
}

sub resend {
    my $self = shift;

    # we can only re-send an invitation if it has been sent
    return $self->error_msg( cannot => resend => $self->{ status } )
        unless $self->{ status } eq ACTIVE;

    # then we fake the internal object value (but not the DB value) back
    # to pending so we can slip past the guard in the send() method that
    # reject all invites that aren't pending.

    local $self->{ status } = PENDING;

    $self->send(@_);
}

#-----------------------------------------------------------------------------
# Methods for creating a scheduling jobs to send/resent invite in background
#-----------------------------------------------------------------------------

sub send_soon {
    my ($self, $params) = self_params(@_);

    return $self->error_msg( cannot => send => $self->{ status } )
        unless $self->pending;

    my $job = $self->send_job($params);

    # TODO: should we save the invite job_id in the invite table
    # or in an invite_job link table

    $job->schedule;

    return $job;
}

sub resend_soon {
    my ($self, $params) = self_params(@_);

    return $self->error_msg( cannot => resend => $self->{ status } )
        unless $self->active;

    my $job = $self->resend_job($params);

    # TODO: should we save the invite job_id in the invite table
    # or in an invite_job link table

    $job->schedule;

    return $job;
}

sub send_job {
    my ($self, $params) = self_params(@_);
    $params->{ invite_id } = $self->id;

    return $self->model->jobs->insert(
        type   => 'send_invite',
        params => $params,
    );
}

sub resend_job {
    my ($self, $params) = self_params(@_);
    $params->{ invite_id } = $self->id;

    return $self->model->jobs->insert(
        type   => 'resend_invite',
        params => $params,
    );
}


#-----------------------------------------------------------------------------
# accept / cancel
#-----------------------------------------------------------------------------

sub accept {
    my ($self, $params) = self_params(@_);

    return $self->error_msg( cannot => accept => $self->{ status } )
        unless $self->{ status } eq ACTIVE;

    my $result = $self->accept_action($params);
    my $update = {
        status   => ACCEPTED,
        modified => Now->timestamp,
    };

    $update->{ user_id } = $params->{ user_id }
        if $params->{ user_id };

    $self->update($update);

    return $result;
}

sub accept_action {
    # stub for subclasses to implement any action when the invite is
    # accepted
    shift->not_implemented('in base class');
}

sub cancel {
    my ($self, $params) = self_params(@_);

    return $self->error_msg( cannot => cancel => $self->{ status } )
        unless $self->{ status } eq ACTIVE;

    $self->update(
        status   => CANCELLED,
        modified => Now->timestamp,
        reason   => $params->{ reason },
    );
}

sub expire {
    my ($self, $params) = self_params(@_);

    $self->update(
        status   => EXPIRED,
        modified => Now->timestamp,
        reason   => $params->{ reason } || 'Expired',
    );
}

sub active {
    my $self = shift;
    return $self->{ status } eq ACTIVE
         ? $self->modified
         : $self->decline('Invite has not been sent');
}

sub created {
    my $self = shift;
    return $self->{ created_ts }
        ||= Timestamp($self->{ created });
}

sub modified {
    my $self = shift;
    if ($self->{ modified } && $self->{ modified } ne NULL_TIME) {
        return $self->{ modified_ts }
            ||= Timestamp($self->{ modified });
    }
    else {
        return $self->decline("Invite has not been modified");
    }
}

sub expires {
    my $self = shift;
    return $self->{ expires_ts }
        ||= Timestamp($self->{ expires });
}

sub pending {
    my $self = shift;
    return $self->{ status } eq PENDING
        || $self->decline_msg( not => 'pending' );
}

sub accepted {
    my $self = shift;
    return $self->{ status } eq ACCEPTED
         ? $self->modified
         : $self->decline_msg( not => 'accepted' );
}

sub cancelled {
    my $self = shift;
    return $self->{ status } eq CANCELLED
         ? $self->modified
         : $self->decline_msg( not => 'cancelled' );
}

sub responded {
    my $self = shift;
    return $self->{ status } eq ACCEPTED
        || $self->{ status } eq CANCELLED
         ? $self->modified
         : $self->decline_msg( not => 'accepted or rejected' );
}

sub failed {
    my $self = shift;
    return $self->{ status } eq FAILED
         ? $self->modified
         : $self->decline_msg( not => 'failed' );
}

sub expired {
    my $self = shift;

    # Make the invite expire right now if it's gone past its best before date.
    # Only applies to invites that have been sent (and pending?)
    if ($self->{ status } ne EXPIRED && $self->expires->before(Now)) {
        $self->expire;
    }

    return $self->{ status } eq EXPIRED
         ? $self->expires
         : $self->decline_msg( not => 'expired' );
}


sub user {
    my $self = shift;
    my $uid  = $self->{ user_id }
        || return $self->decline("No user associated with this invite");
    return $self->model->users->fetch( id => $uid )
        || return $self->error("Failed to fetch invite user: $uid");
}



1;


__END__

=head1 NAME

Contentity::Record::Invite - a record from the C<invite> table

=head1 SYNOPSIS

    use Contentity;

    my $invite = Contentity->invite( id => $invite_id );

=head1 DESCRIPTION

This module defines an object to represent records in the C<invite> database
table. It is a subclass of the L<Contentity::Database::Record> module which is itself
a thin wrapper around the L<Badger::Database::Record> module.

Database records are returned by the L<Contentity::Table::Invites> object which
manages the C<invites> database table.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Contentity::Database::Record>, L<Badger::Database::Record> and L<Badger::Base>
base classes.

# NONE DOCUMENTED YET

=head1 TODO

Add C<send_later()> method which schedules it to be sent via job server.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2018 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Table::Invites>, L<Contentity::Database>, L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
