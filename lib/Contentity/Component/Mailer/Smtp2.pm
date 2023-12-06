# this is a replacement for C::Component::Mailer::Smtp
# which uses Email::Sender instead of Mail::Sender
package Contentity::Component::Mailer::Smtp2;

use utf8;
use Encode;
use Email::Sender::Simple qw( sendmail );
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::MIME;
use Contentity::Class
    version    => 0.02,
    debug      => 0,
    base       => 'Contentity::Component::Mailer',
    utils      => 'extend self_params',
    accessors  => 'mailhost',
    constants  => 'DEFAULT',
    constant   => {
        SENDER    => 'Email::Sender',
        TRANSPORT => 'Email::Sender::Transport::SMTP',
        MESSAGE   => 'Email::Simple',
        MULTIPART => 'Email::MIME',
        AUTHTYPE  => 'LOGIN',
    },
    messages  => {
        missing_param => 'No %s specified for email message',
    };

our $DEFAULTS = {
    encoding => 'quoted-printable',
};


#-----------------------------------------------------------------------------
# Initialisation
#-----------------------------------------------------------------------------

sub init_mailer {
    my ($self, $config) = @_;

    # must have a mailhost to connect to
    $self->{ mailhost } = $config->{ mailhost }
        || return $self->error_msg( missing => 'mailhost' );

    $self->{ encoding } = $config->{ encoding }
        || $DEFAULTS->{ encoding };

    $self->{ _authenticator } = $self->generate_authenticator($config);

    $self->debug(
        "init mailhost: $self->{ mailhost }  auth: ",
        join(', ', $self->{ _authenticator }->())
    ) if DEBUG;

    return $self;
}

sub generate_authenticator {
    my ($self, $config) = @_;

    my $auth = delete($config->{ authtype }) || AUTHTYPE;
    my $user = delete $config->{ username };
    my $pass = delete $config->{ password };

    $self->debug(
        "user: $user  pass: $pass",
    ) if DEBUG;

    # Generate a closure that returns the authentication credentials in
    # the format that Mail::Sender wants or an empty list if there aren't any.
    # This prevents trivial exposure of credentials, e.g. via Data::Dumper
    return
        defined $user && defined $pass
            ? sub { ( sasl_username => $user, sasl_password => $pass) }
            : sub { ( ) };
}

sub transport {
    my $self = shift;
    return $self->{ transport }
        ||= $self->new_transport;
}

sub new_transport {
    my $self = shift;
    my $args = { host => $self->mailhost };
    my $port = $self->config('port');
    if ($port) {
        $args->{ port } = $port;
    }
    $self->debug_data( smtp2_transport => $args ) if DEBUG;
    return $self->TRANSPORT->new({
        %$args,
        $self->{ _authenticator }->(),
    });
}

#-----------------------------------------------------------------------------
# Mailing
#-----------------------------------------------------------------------------

sub _send_email {
    my ($self, $args) = self_params(@_);

    $self->prepare_params($args);

    # check incoming args have got what we need
    $self->check_params($args);

    if ($args->{ testing }) {
        $self->debug("NOT sending email (testing mode)  ", $self->dump_data($args))
            unless $args->{ test_quietly };
        return "Mail NOT sent to $args->{ to } (testing mode)";
    }

    $self->debug_data( send => $args ) if DEBUG;

    eval {
        my $email = $self->generate_email($args);
        $self->debug_data( message => $email ) if DEBUG;
        sendmail($email, { transport => $self->transport });
    };

    return $@
        ? $self->error_msg( mail_fail => $args->{ to }, $@ )
        : "Mail sent to $args->{ to }";
}

sub generate_email {
    my ($self, $args) = self_params(@_);
    my $header = $self->generate_header(
        $args,
        "Content-Type" => $args->{ ctype } || "text/plain; charset=UTF-8",
    );
    $self->debug_data( header => $header ) if DEBUG;

    return $self->MESSAGE->create(
        header => $header,
        body => $args->{ message },
    );
}

sub _send_multipart {
    my ($self, $args) = self_params(@_);

    $self->debug_data("sending multipart", $args) if DEBUG;

    my $parts = $args->{ multipart }
        || return $self->error_msg( missing => 'multipart' );

    $self->prepare_params($args);

    if ($args->{ testing }) {
        $self->debug("NOT sending email (testing mode)  ", $self->dump_data($args));
        return "Mail NOT sent to $args->{ to } (testing mode)";
    }

    $self->debug_data( send => $args ) if DEBUG;

    my $header = $self->generate_header($args);
    my $html   = encode('utf8', $args->{ html_message });
    my $text   = encode('utf8', $args->{ text_message });

    eval {
        my @parts = (
            Email::MIME->create(
                attributes => {
                    content_type => "text/html",
                    encoding     => "quoted-printable",
                    charset      => "UTF-8",
                },
                body => $html,
            ),
            Email::MIME->create(
                attributes => {
                    content_type => "text/plain",
                    encoding     => "quoted-printable",
                    charset      => "UTF-8",
                },
                body => $text,
            ),
        );
        my $email = Email::MIME->create(
            header_str => $header,
            attributes => {
                content_type => 'multipart/alternative'
            },
            parts      => [ @parts ],
        );
        $self->debug("EMAIL: $email") if DEBUG;

        sendmail($email, { transport => $self->transport });
    };

    return $@
        ? $self->error_msg( mail_fail => $args->{ to }, $@ )
        : "Mail sent to $args->{ to }";
}

sub generate_header {
    my ($self, $args, @more) = @_;
    $self->debug_data( generate_header => $args ) if DEBUG;
    my $cfg = $self->{ config }->{ headers } || { };
    $self->debug_data( config_headers => $cfg ) if DEBUG;
    my $header = [
        To      => $args->{ to },
        From    => $args->{ from },
        Subject => $args->{ subject },
        @more,
        %$headers,
    ];

    if ($args->{ reply_to }) {
        push(@$header, "Reply-to", $args->{ reply_to });
    }
    $self->debug_data( header => $header ) if DEBUG || $self->{ config }->{ debug };
    return $header;
}

sub prepare_params {
    my ($self, $params) = @_;
    my $format = $params->{ format } || DEFAULT;

    # add defaults parameter to args
    $params->{ smtp       }   = $self->{ mailhost };
    $params->{ from       } ||= $self->{ from };
    $params->{ encoding   } ||= $self->{ encoding };

    # add extra params for HTML email
    my $ctype = $self->content_type($format);
    if ($ctype) {
        $self->debug("adding content-type ($ctype) for $format ($format)") if DEBUG;
        $params->{ ctype } = $ctype;
    }

    $self->debug(
        "Sending email via $self->{ mailhost } : ",
        $self->dump_data_inline($params)
    ) if DEBUG;

    return $params;
}

sub check_params {
    my ($self, $params) = @_;
    for (qw(from to subject message)) {
        return $self->error_msg( missing_param => $_ )
            unless $params->{ $_ };
    }
}

1;


=head1 NAME

Contentity::Component::Mailer::Smtp2 - component for sending email via SMTP

=head1 DESCRIPTION

This module is a component for sending email via SMTP.  It uses L<Email::Sender>
and is a replacement for L<Contentity::Component::Mailer::Smtp> which used L<Mail::Sender>
which has now been deprecated.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2005-2022 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Component::Mailer>,
L<Contentity::Component::Mailer::Smtp>

=cut
