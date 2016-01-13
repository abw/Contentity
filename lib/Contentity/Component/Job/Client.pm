package Contentity::Component::Job::Client;

use Contentity::Class
    version  => 0.03,
    debug    => 0,
    base     => 'Contentity::Component',
    import   => 'class',
    messages => {
        connect      => 'Cannot connect to job scheduling server (%s port %s).',
        request      => 'Failed to send request: %s.',
        no_job       => 'No job ticket specified to %s.',
        no_response  => 'No response received from job server.',
        bad_response => 'Invalid response from job server: %s',
        schedule     => 'Job server rejected job ticket: %s.',
    };

use IO::Socket;

sub init_component {
    my ($self, $config) = @_;
    $self->{ host } = $config->{ host };
    $self->{ port } = $config->{ port };
    $self->debug("created job client for $self->{host}:$self->{port}") if DEBUG;
    return $self;
}

sub request {
    my ($self, $request) = @_;
    $self = $self->prototype() unless ref $self;

    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->{ host },
        PeerPort => $self->{ port },
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
        Timeout  => 5,
    ) || return $self->error_msg( connect => @$self{ qw( host port )}, $@ );

    $request =~ s/\s+$//g;
    $socket->print($request, "\n")
        || return $self->error_msg( request => $! );

    my ($response, $line);
    while (defined($line = <$socket>)) {
        $response .= $line;
    }
    $socket->close();
    return $response || $self->error_msg('no_response');
}

sub schedule {
    my $self = shift;
    my $job  = shift || return $self->error_msg( no_job => 'schedule' );

    # submit a job scheduling request
    my $response = $self->request("run:$job");

    # check the response code
    if ($response =~ /^OK\b/) {
        return $response;
    }
    elsif ($response =~ s/^ERROR - //) {
        return $self->error_msg( schedule => $response );
    }
    else {
        return $self->error_msg( bad_response => $response );
    }
}

sub port {
    my $self = shift;
    $self = $self->prototype;
    return @_ ? ($self->{ port } = shift) : $self->{ port };
}

sub host {
    my $self = shift;
    $self = $self->prototype;
    return @_ ? ($self->{ host } = shift) : $self->{ host };
}

1;

=head1 NAME

Contentity::Component::Job::Client - client for talking to backend jobs server

=head1 SYNOPSIS

    use Cog;

    my $client = Cog->job_client;
    print $client->request('status');

=head1 DESCRIPTION

This module implements a client for talking to the backend job scheduling
server via a socket.

=head1 CONFIGURATION OPTIONS

The job client is usually instantiated via the job server which will
pass it the correct values for the host and port.

=head2 host

The host to connect to.  Defaults to localhost.

=head2 port

The port on to connect to.  Defaults to port 4242.

=head1 METHODS

=head2 request($request)

Submit a request to the jobs server.  Returns the response received.

=head2 host()

Method to get or set the host to connect to. Can be called as an object
or class method.

=head2 port()

Method to get or set the port number to connect to. Can be called as an object
or class method.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

July 2006, updated for Tiberius Decmber 2007, Completely Retail
in January 2009, Completely Group in 2016

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
