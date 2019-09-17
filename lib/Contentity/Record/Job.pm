package Contentity::Record::Job;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Database::Record',
    throws    => 'Contentity.Job',
    utils     => 'self_params md5_hex Timestamp extend',
    codec     => 'json',
    accessors => 'params_json data_json params',
    constants => 'NULL_TIME :status',
    messages  => {
        cannot => "Cannot %s a job with status of '%s'",
        log    => 'log[%s] %s'
    };


*submit = \&schedule;

sub init {
    my ($self, $config) = @_;

    my $params = $config->{ params };
    $config->{ params_json } = $params;
    $config->{ params } = decode($params)
        if $params && ! ref $params;

    my $data = $config->{ data };
    $config->{ data_json } = $data;
    $config->{ data } = decode($data)
        if $data && ! ref $data;

    return $self->SUPER::init($config);
}


sub dispatch {
    my $self = shift;
    local $self->{ server } = shift;

    $self->debug("dispatch() job $self->{ id }\n") if DEBUG;

    my $result = eval {
        $self->start;
        $self->run($self->params);
    };

    $self->debug("got result: $result  (status: ", $self->status, "\n")  if DEBUG;

    # call either of failed() or success() methods unless it looks like the
    # run() method has already done so (i.e. the job is no longer active).
    if ($@) {
        $self->log( error => $@ );
        $self->failed($@) if $self->active;
        $self->debug("job failed: $@\n") if DEBUG;
    }
    else {
        $self->success($result) if $self->active;
        $self->debug("job succeeded: $@\n") if DEBUG;
    }

    return $result;
}


sub start {
    my $self = shift;

    $self->pending
        || return $self->error_msg( cannot => start => $self->{ status } );

    my $now = Timestamp->now;

    $self->log( info => "Starting job $self->{ id } at $now" );

    $self->update(
        status  => ACTIVE,
        started => $now->timestamp,
    );

    $self->log( info => "Set job $self->{ id } active" ) if DEBUG;
}


sub stop {
    my $self   = shift;
    my $status = shift || SUCCESS;
    my $result = join('', @_);

    $self->debug("stopping, data: ", $self->dump_data($self->{ data })) if DEBUG;

    $self->active
        || return $self->error_msg( cannot => stop => $self->{ status } );

    $self->debug("Updating job to [status:$status]  [result:$result]\n") if DEBUG;

    my $now = Timestamp->now;

    $self->log( info => "Stopping job $self->{ id } at $now => $status" );

    my $data   = $self->{ data } ||= { };
    my $update = {
        status  => $status,
        stopped => $now->timestamp,
        data    => $data,
    };

    $update->{ result } = $result
        if defined $result;

    $update->{ progress } = 100
        if $status eq SUCCESS;

    $data->{ $status } = $result;

    $self->update($update);
}


sub run {
    shift->not_implemented(' in base class');
}


sub log {
    my $self   = shift;
    $self->debug_msg( log => @_ ) if DEBUG;
    my $server = $self->{ server }
        || return $self->decline("No job server available to log messages to");
    $server->log(@_);
}

sub pending {
    shift->{ status } eq PENDING;
}

sub active {
    shift->{ status } eq ACTIVE;
}

sub success {
    my $self = shift;
    if (@_) {
        # set status to success when called with result argument
        $self->stop(SUCCESS, @_);
    }
    else {
        return $self->{ status } eq SUCCESS;
    }
}

sub failed {
    my $self = shift;
    if (@_) {
        # set status to failed when called with result argument
        $self->stop(FAILED, @_);
        my $result = $self->{ result } || 'No reason given';
        $self->log( fail => "Job $self->{ id } failed: $result" );
    }
    else {
        return $self->{ status } eq FAILED;
    }
}

sub finished {
    my $status = shift->{ status };
    return $status eq SUCCESS
        || $status eq FAILED;
}

sub expired {
    my $self = shift;
    return $self->{ status  } eq EXPIRED
        || $self->expires
        && Timestamp->now->after($self->{ expires })
        && $self->status(EXPIRED);
}

sub expire {
    shift->status(EXPIRED);
}

sub started {
    my $started = shift->{ started };
    return $started eq NULL_TIME
        ?  0
        :  Timestamp($started);
}

sub stopped {
    my $stopped = shift->{ stopped };
    return $stopped eq NULL_TIME
        ?  0
        :  Timestamp($stopped);
}

sub expires {
    my $expires = shift->{ expires };
    return $expires eq NULL_TIME ? 0 : Timestamp($expires);
}

sub schedule {
    my $self = shift;
    $self->workspace->project->job_server_client->schedule($self->id);
    return $self;
}


sub refresh {
    my $self = shift;
    my $copy = $self->table->fetch( id => $self->{ id } );
    @$self{ keys %$copy } = values %$copy;
    return $self;
}

sub todo {
    my $self = shift;

    if (@_) {
        $self->{ todo } = shift;
        $self->{ done } = 0;
        # set status and progress
        $self->debug("got $self->{ todo } items todo") if DEBUG;
        $self->update( progress => 0 );
    }
    elsif (defined $self->{ todo }) {
        return $self->{ todo };
    }
    else {
        return $self->decline('nothing to do');
    }
}

sub done {
    my $self = shift;

    $self->debug("DONE: ", join(', ', @_)) if DEBUG;

    if (@_) {
        my $n = shift;
        $self->{ done } += $n;

        # calculate current progress percentage
        my $args = {
            progress => int(100 * $self->{ done } / $self->{ todo }),
        };

        # append serialised data if specified as extra arguments
        if (@_) {
            # fetch current data
            my $data = $self->{ data } ||= [ ];

            push(@$data, @_);
            $self->debug("added data: ", join(', ', @_)) if DEBUG;
            $args->{ data } = $data;
        }
        $self->update($args);

        if ($args->{ data }) {
            # must decode data again as update() will have re-encoded it
            $self->{ data } = decode($self->{ data });
        }
    }
}


1;

=head1 NAME

Contentity::Record::Job - database record module for the job table

=head1 DESCRIPTION

This module is a subclass of L<Contentity::Database::Record> which acts as a
base class for objects representing records in the C<job> table.

The L<Contentity::Table::Jobs> module is responsible for instantiating these
objects when it fetches rows from the database.  It uses the job
C<type> to determine the correct subclass of L<Contentity::Record::Job>.
For example, a job record with a C<type> set to C<foo/bar> will
expect to have a corresponding C<Contentity::Record::Job::Foo::Bar> module.

Each subclass must implement the C<run()> to perform whatever actions
are appropriate for the job type.

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Contentity::Database::Record>, C<Badger::Database::Record> and L<Badger::Base>
base classes.

=head2 id()

Returns the alphanumerical record ID (a 64 character MD5 hash).

=head2 type()

Returns the job type. This corresponds to a L<Contentity::Record::Job> class,
e.g. a type of C<user/register> is mapped to the
L<Contentity::Record::Job::User::Register> module.

=head2 params()

The input parameters for the job.  These are stored as serialised JSON in
the database.  This method will automatically de-serialise them and return
then as a reference to a hash array.  The method caches the de-serialised
parameters internally for subsequent use.

=head2 params_text()

This returns the input parameters for the job in serialised form as stored in
the database.  Parameters are serialised as L<JSON|Badger::Codec::JSON>.

=head2 created()

Returns a timestamp of when the job was created.

=head2 status()

Returns the status of the job.  This can be one of the values:
C<pending>, C<active>, C<finished> C<failed> or C<expired>.

=head2 pending()

Returns true if the status of the job is C<pending>.

=head2 start()

Sets the status of the job to C<active> and records the C<started>
time.  This can only be called on C<pending> jobs.

=head2 started()

Returns the timestamp of when the job was started.

=head2 active()

Returns true if the status of the job is C<active>.

=head2 stop($status, $result)

Sets the status of the job to C<$status>, records the C<stopped> timestamp,
and optionally, the result to C<$result>. This can only be called on an
C<active> job.

=head2 stopped()

Returns the timestamp of when the job was stopped.

=head2 success()

When called without arguments, this method returns true if the status of the
job is C<success>.

    if ($job->success) {
        print "Yay!\n";
    }

This method can also be called with one or more arguments in order
to set the status to C<success>.  The arguments are joined together
and stored in the C<result> field.

    $job->success("Everything went to plan");

=head2 failed()

When called without arguments, this method returns true if the status of the
job is C<failed>.

    if ($job->failed) {
        print "Boo!\n";
    }

This method can also be called with one or more arguments in order
to set the status to C<failed>.  The arguments are joined together
and stored in the C<result> field.

    $job->success("Everything went tits up");

=head2 finished()

Returns true if the status of the job is C<success> or C<failed>.

=head2 expires()

Returns the timestamp of when the job expires.  Any attempt to run a job
after its expiry date will result in an error being raised.

=head2 expire()

Sets the status of the job to C<expired>.

=head2 expired()

Returns true if the status of the job is C<expired>, or if
the C<expires> value is defined and indicates a time that has
now passed.  In this case, the C<status> is set to C<expired>.

=head2 progress()

The current job progress.  Long running jobs can use this field to indicate
how far through the job they are.  This allows us the present this to the
users as a progress meter, for example.

=head2 result()

The result of running the job.  If the status of the job is C<error> then
this will contain the error message raised.

=head2 run()

Each job type implements its own C<run()> method.  This is where the
job-specific code goes.

=head2 dispatch()

This is the main entry point for a job being run by the job server.  The
job server calls this method, this method then calls run() and does the
right thing to store the result back in the database, check for errors and
so on.

=head2 schedule()

This method is called to schedule a job to run via the job server.  It
creates a L<CR::Job::Client> object which handles the communication with
the job server to schedule the job.

=head2 refresh()

This method reloads all the data from the database record.  If you're
monitoring the progress of a running job then you'll need to call this
periodically.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2008-2018 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Table::Jobs>, L<Contentity::Database>, L<Contentity::Database::Record>,
L<Badger::Database::Record> and L<Badger::Base>.

=cut
