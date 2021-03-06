package Contentity::Component::Mailer::Smtp;

use Mail::Sender;
use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Contentity::Component::Mailer',
    utils      => 'extend self_params',
    accessors  => 'mailhost',
    constants  => 'DEFAULT',
    constant   => {
        SENDER   => 'Mail::Sender',
        AUTHTYPE => 'LOGIN',
    },
    messages  => {
        missing_param => 'No %s specified for email message',
    };

our $DEFAULTS = {
    encoding => 'quoted-printable',
};

# Stop Mail::Sender from adding its own X-Mailer
*Mail::Sender::SITE_HEADERS = \"X-Sender: Completely Group Mail Server";
$Mail::Sender::NO_X_MAILER = 1;


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
            ? sub { ( auth => $auth, authid => $user, authpwd => $pass) }
            : sub { ( ) };
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
        my $sender = SENDER->new({
            smtp      => $self->{ mailhost },
            on_errors => 'die'
        });

        my @auths = $self->{ _authenticator }->();
        $self->debug("auths: ", join(', ', @auths)) if DEBUG;

        $sender->Open({
            %$args,
            $self->{ _authenticator }->(),
        });
        $sender->SendEnc($args->{ message });
        $sender->Close;
    };

    return $@
        ? $self->error_msg( mail_fail => $args->{ to }, $@ )
        : "Mail sent to $args->{ to }";
}

sub _send_multipart {
    my ($self, $args) = self_params(@_);
    my $parts = $args->{ multipart }
        || return $self->error_msg( missing => 'multipart' );

    $self->prepare_params($args);

    if ($args->{ testing }) {
        $self->debug("NOT sending email (testing mode)  ", $self->dump_data($args));
        return "Mail NOT sent to $args->{ to } (testing mode)";
    }

    $self->debug_data( send => $args ) if DEBUG;

    eval {
        my $sender = SENDER->new({
            smtp      => $self->{ mailhost },
            on_errors => 'die'
        });

        $sender->OpenMultipart({
            %$args,
            multipart   => 'mixed',
            $self->{ _authenticator }->(),
        });

        $sender->Part({
            ctype => 'multipart/alternative'
        });
        for my $part (@$parts) {
            $self->prepare_params($part);
            $part->{ disposition } = 'NONE';
            $self->debug_data( Part => $part ) if DEBUG or 1;
            $sender->Part($part)->SendEnc( $part->{ message } );
;
        }
        $sender->EndPart('multipart/alternative');
        $sender->Close();
    };

    return $@
        ? $self->error_msg( mail_fail => $args->{ to }, $@ )
        : "Mail sent to $args->{ to }";
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

Contentity::Component::Mailer::Smtp - component for sending email via SMTP

=head1 DESCRIPTION

This module is a component for sending email via SMTP.  It has been
superceded by L<Contentity::Component::Mailer::Smtp2>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2005-2022 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Component::Mailer>,
L<Contentity::Component::Mailer::Smtp2>

=cut
