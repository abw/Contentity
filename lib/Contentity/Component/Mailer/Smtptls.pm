package Contentity::Component::Mailer::Smtptls;

use Net::SMTP;
use Email::Sender::Transport::SMTP::TLS;
use Encode;
use utf8;
use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Contentity::Component::Mailer::Smtp2',
    utils      => 'self_params',
    constant   => {
        TRANSPORT => 'Email::Sender::Transport::SMTP::TLS',
    };

sub transport {
    my ($self, $args) = self_params(@_);
    my $config = $self->{ config };

    my @auth = $self->{ _authenticator }->();
    return  $self->{ _tls_transport }
        ||= $self->TRANSPORT->new({
            host     => $config->{ mailhost },
            port     => $config->{ port     },
            @auth,
        });
}

sub generate_authenticator {
    my ($self, $config) = @_;

    my $user = delete $config->{ username };
    my $pass = delete $config->{ password };

    return
        defined $user && defined $pass
            ? sub { ( username => $user, password => $pass) }
            : sub { ( ) };
}

1;
