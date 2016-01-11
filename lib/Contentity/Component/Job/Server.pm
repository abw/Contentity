package Contentity::Component::Job::Server;

use Contentity::Class
    version   => 0.03,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'class',
    codec     => 'json',
    accessors =>  'pidfile',
    constant  => {
        LOGFILE => 'Badger::Log::File',
        LOGFMT  => '[<time>] [<level>] <message>',
    },
    messages => {
        no_job  => 'No job found with id: %s',
        bad_job => 'Failed to fetch job %s: %s',
        old_job => 'Job has expired: %s',
        ran_job => 'Job cannot be run with a status of %s: %s',
    };

use POSIX qw( :sys_wait_h :signal_h );
use IO::Socket;
use Errno;
use Badger::Log::File;

sub init_component {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->{ host        } = $config->{ host    };
    $self->{ port        } = $config->{ port    };
    $self->{ max_workers } = $config->{ workers };
    $self->{ max_pending } = $config->{ pending };
    $self->{ facade      } = $config->{ facade  };
    $self->{ workers     } = { };
    $self->{ pending     } = [ ];
    $self->{ handler     } = {
        stop => sub {
            $self->log( info => 'caught interrupt signal, stopping server' );
            $self->stop();
            exit(0);
        },
        restart => sub {
            $self->log( info => 'caught hangup signal, reconnecting server' );
            $self->reconnect();
        },
        reaper => sub {
            # localise $! or waitpid() will trample on it
            local $!;
            $self->debug("caught child signal, reaping children") if DEBUG;
            while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
                # make sure this really is one of our processes and check
                # that it really is dead and not just stopped for some reason
                if (WIFEXITED($?) && delete $self->{ workers }->{ $pid }) {
                    $self->debug("reaped worker process $pid") if DEBUG;
                    # start the next job
                    $self->work();
                }
            }
            $SIG{CHLD} = $self->{ handler }->{ reaper };
        }
    };

    if (my $logfile = $config->{ logfile }) {
        my $path = $self->workspace->file($logfile);
        $self->debug("opening logfile ($logfile) at $path") if DEBUG;
        $self->{ log } = $self->LOGFILE->new({
            filename  => $path->absolute,
            keep_open => 1,
            format    => $self->LOGFMT,
            debug     => $DEBUG,
            %$config,
        });
    }

    if (my $pidfile = $config->{ pidfile }) {
        $self->{ pidfile } = $self->workspace->file($pidfile);
    }

    return $self;
}

sub start {
    my $self   = shift;
    my $server = $self->connect();
    my ($client, $request);

    $SIG{CHLD} = $self->{ handler }->{ reaper  };
    $SIG{TERM} = $self->{ handler }->{ stop };
    $SIG{INT}  = $self->{ handler }->{ stop };
    # $SIG{HUP}  = $self->{ handler }->{ restart };

    $self->log( info => 'ready...' );

    $self->{ jobs } = $self->{ facade }->jobs;

    while (1) {
        $client = $server->accept() || do {
            # accept() can "fail" in Perl 5.7.3 and later thanks
            # to "safe signals" which can interrupt an accept()
            # so we detect this and ignore it
            next if $!{EINTR};
            last;
        };
        if (defined ($request = <$client>)) {
            eval { $self->request($client, $request); };
            $self->log( error => "request failed: $@" ) if $@;
        }
        else {
            $client->close();
        }
    }

    $self->log( error => "**** stopped accepting requests: $!" );
}

sub stop {
    my $self = shift;

    $self->debug(
        "terminating ",
        scalar(keys %{$self->{ workers }}),
        " worker processes\n"
    ) if DEBUG;

    local ($SIG{CHLD}) = 'IGNORE';
    kill 'INT' => keys %{ $self->{ workers } };

    $self->disconnect() if $self->{ socket };
}

sub connect {
    my $self    = shift;

    if ($self->{ socket }) {
        $self->log( warn => 'job server is already connected.' );
        return $self;
    }
    $self->log( info => "[PID:$$] connecting the job server to port $self->{ port }." );

    # open local socket to listen for job requests
    return ($self->{ socket } = IO::Socket::INET->new(
		LocalPort 	=> $self->{ port },
        Type        => SOCK_STREAM,
        Proto       => 'tcp',
		Listen 		=> 10,
	    Reuse       => 1,
    )) || $self->error("failed to establish local listening socket: $@");
}

sub disconnect {
    my $self = shift;

    if (my $socket = delete $self->{ socket }) {
        $self->log( info => "disconnecting the job server." );
        eval { $socket->shutdown(2) };
        if ($@) {
            $self->log( error => "failed to shutdown listening socket: $@" );
        }
        else {
            $self->log( info => "job server successfully disconnected." );
        }
    }
    else {
        $self->log( warn => "job server is not connected." );
    }

    return $self;
}

sub reconnect {
    my $self = shift;
    $self->disconnect();
    $self->connect();
}

sub read_pidfile {
    my $self = shift;
    my $file = $self->pidfile || return;
    return unless $file->exists;
    my $pid = $file->read;
    chomp $pid;
    return $pid;
}

sub write_pidfile {
    my $self = shift;
    my $file = $self->pidfile || return;
    $file->write(shift);
}

sub request {
    my ($self, $client, $request) = @_;
    my $pending = $self->{ pending };

    chomp($request);

    if ($request =~ /^run:(\w+)\s*$/) {
        my $job  = $1;
        if (@$pending < $self->{ max_pending }) {
            push(@$pending, $job);
            $client->print("OK - job ticket accepted for scheduling\n");
            $self->log( info => "accepted job request: [$job]" );
        }
        else {
            $client->print("ERROR - server busy\n");
            $self->log( warn => 'ignored job request - too busy' );
        }
    }
    elsif ($request eq 'status' ) {
        $client->print(
            'STATUS - ',
            scalar(keys %{ $self->{ workers } }), '/', $self->{ max_workers },
            ' working ',
            scalar(@$pending), '/', $self->{ max_pending },
            " pending\n"
        );
    }
    elsif ($request eq 'json_status' ) {
        $client->print(
            encode {
                host        => $self->{ host        },
                port        => $self->{ port        },
                max_workers => $self->{ max_workers },
                max_pending => $self->{ max_pending },
                pending     => $self->{ pending     },
                workers     => $self->{ workers     }
            }
        );
    }
    else {
        $client->print("ERROR - invalid request\n");
        $self->log( warn => 'rejected job request: $request' );
    }

    # we're done with the client socket now
    $client->close();

    # start the next job running
    $self->work() if @$pending;
}

sub work {
    my $self = shift;

    # return if we've already got the maximum number of workers working
    return unless keys %{ $self->{ workers } } < $self->{ max_workers };

    # take the next job ticket, return if there aren't any pending
    my $ticket = shift @{ $self->{ pending } } || return;

    # disable interrupts while forking
    my $signals = POSIX::SigSet->new(SIGINT);
    sigprocmask(SIG_BLOCK, $signals) || do {
        unshift @{ $self->{ pending } }, $ticket;
        return $self->error("failed to block SIGINT before fork: $!");
    };

    # cleave the process in twain with the mighty sword of fork()
    my $pid = fork();

    # unblock signals
    sigprocmask(SIG_UNBLOCK, $signals)
        || return $self->error("failed to unblock SIGINT after fork: $!");

    if (! defined $pid) {
        # fork failed
        unshift @{ $self->{ pending } }, $ticket;
        $self->log( error => "failed to fork worker process: $!" );
    }
    elsif ($pid) {
        # parent process adds child to worker pool
        $self->{ workers }->{ $pid } = $ticket;
    }
    else {
        # child fetches the job, runs it, then exits
        $SIG{INT} = 'DEFAULT';
        $self->{ socket }->close();
        delete $self->{ socket };

        # TODO: get timeout from job or use default, set alarm
        my $job;
        if ($job = $self->job($ticket)) {
            $self->log( info => "worker process $$ starting job $ticket");
            $job->dispatch($self);
            $self->log( info => "worker process $$ finished job $ticket" );
        }
        else {
            $self->log( warn => $self->error() );
        }

        exit();
    }
}

sub job {
    my ($self, $id) = @_;
    my ($mod, $job, $msg);

    $self->debug("creating new $self->{ facade } facade object to fetch jobs\n") if DEBUG;

    eval {
        # create a new CR object (to ensure we get a new database
        # connection in the child process)
        $mod = $self->{ facade }->new()
            || return $self->error($self->{ facade }->error());

        # have it fetch the job
        $job = $mod->model->jobs->fetch( id => $id );
    };
    if ($@) {
        # something went wrong
        return $self->decline_msg( bad_job => $id, $@ );
    }
    elsif (! $job) {
        # job not found, no big deal
        return $self->decline_msg( no_job => $id );
    }

    # check the job hasn't expired
    if ($job->expired()) {
        return $self->decline_msg( old_job => $id );
    }

    # make sure the job isn't running or has been run
    unless ($job->pending()) {
        return $self->decline_msg( ran_job => $job->status(), $id );
    }

    return $job;
}

sub port {
    my $self = shift;
    return @_ ? ($self->{ port } = shift) : $self->{ port };
}

sub workers {
    my $self = shift;
    return @_ ? ($self->{ max_workers } = shift) : $self->{ max_workers };
}

sub pending {
    my $self = shift;
    return @_ ? ($self->{ max_pending } = shift) : $self->{ max_pending };
}

sub facade {
    my $self = shift;
    return @_ ? ($self->{ facade } = shift) : $self->{ facade };
}

sub client {
    my $self = shift;
    $self->debug("creating new job client to connect to $self->{ host }:$self->{ port }") if DEBUG;
    return $self->workspace->job_client(
        host => $self->{ host },
        port => $self->{ port },
    );
}

sub log {
    my $self = shift;
    my $type = shift;
    if (my $log = $self->{ log }) {
        $log->log( $type => join('', @_) );
    }
    else {
        print STDERR "[$type] ", @_, "\n";
    }
}

sub DESTROY {
    my $self = shift;
    $self->disconnect if $self->{ socket };
}

no warnings 'redefine';

sub debug {
    my $self = shift;
    $self->log( debug => @_ );
}


1;


=head1 NAME

Contentity::Component::Job::Server - backend server for scheduling jobs

=head1 DESCRIPTION

This module implements a server which listens on a local port for
job scheduling requests.  It maintains a pool of child workers which
run pending jobs in the order they are scheduled.

It was written a long, long time ago and has been pulled into service
on numerous project since because it "just works".  But I'd really like
to replace it with Gearman at some point...

=head1 METHODS

=head2 new()

Constructor method to create a new server.

    my $server = CR::Job::Server->new();

It accepts the following parameters.

=head3 port

The port on which to listen.  Defaults to port 4242.

=head3 workers

The maximum number of child worker processes to maintain.  Defaults to 10.

=head3 pending

The maximum number of pending requests that will be queued when all worker
processes are busy.  Defaults to 50.

=head3 facade

The name of a delegate module which can be used to fetch live job objects.
This defaults to C<CR>.

To fetch a live job object, the server first creates a new object of the class
specified in the C<facade> configuration item or C<$CONFIG-E<gt>{ facade }>)
package variable if undefined. It is important that a new object is created to
ensure that we have a fresh database connection for each child process.
Otherwise we see "database has gone away" errors from MySQL.

The C<job()> method is then called against this object, passing the job id as
an argument. This should return a C<CR::Record::Job> object (or
subclass) or decline (i.e. return undef, usually by calling the C<decline()>
or C<decline_msg()> method) if it can't be found. Errors should be thrown as
exceptions using the C<error()> or C<error_msg()> method.

So if our C<facade> is set to C<CR> then the L<job()> method does the
equivalent of this:

    my $facade = CR->new();
    return $facade->job($id)
        || $self->decline("ticket $id not found");

=head3 logfile

The name of a logfile to write logging messages to.  Defaults to write messages
to C<stderr>.

NOTE: logging is temporarily Not Implemented until I decide if it's better
to plug in the existing logfile module I've got or use Log4Perl...

=head2 port()

Method to get or set the port number on which the server should listen.

    $server->port(314159);
    print "server will run on port ", $server->port(), "\n";

=head2 workers

Method to get or set the maximum number of worker processes that the server
will spawn. It can be called as an object or class method as per L<port()>.

=head2 pending

Method to get or set the maximum number of job requests than can be queued
when all work processes are busy.  It can be called as an object or class method
as per L<port()>.

=head2 facade

Method to get or set the name of the facade module which will be used to
fetch live job objects to run. It can be called as an object or class method
as per L<port()>.

=head2 start()

Start the server running.

    $server->start();

This method doesn't return unless the process receives a terminating
signal.

=head2 stop()

Stop the server.  This is usually called by a signal handler catching
an interrupt signal.

=head1 INTERNAL METHODS

=head2 connect()

Connect the server socket.

=head2 disconnect()

Disconnect the server socket.

=head2 reconnect()

Disconnect then reconnect the server socket. Implemented via calls to
L<disconnect()> and L<connect()>.

=head2 request($client,$request)

Called by L<start()> to handle each request as it is received.  Adds it to the
pending queue and schedules a worker by calling the C<work()> method.

=head2 work()

Unless the server is already running the maximum number of worker processes
(in which case it returns silently), this method takes the first job ticket in
the pending queue and spawns a new worker process to run it.

The worker process calls C<job()> to fetch a live job object and then calls
C<run()> on it.

=head2 job($id)

Creates a new object of the class specified in the C<facade> configuration
argument (using the value in the C<$FACADE> package variable by default) and
then calls its C<job()> method to fetch a job. It expects the job ticket id as
a single argument.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

July 2006, updated for Tiberius in December 2007, Completely Retail in
January 2009 and Contentity/Cog in 2016.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
