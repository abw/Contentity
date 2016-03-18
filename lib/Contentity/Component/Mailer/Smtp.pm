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


#-----------------------------------------------------------------------------
# Initialisation
#-----------------------------------------------------------------------------

sub init_mailer {
    my ($self, $config) = @_;

    # must have a mailhost to connect to
    $self->{ mailhost } = $config->{ mailhost }
        || return $self->error_msg( missing => 'mailhost' );

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


sub send {
    my ($self, $args) = self_params(@_);
    my $format = $args->{ format } || DEFAULT;

    # add defaults parameter to args
    $args->{ smtp       }   = $self->{ mailhost };
    $args->{ from       } ||= $self->{ from };
    $args->{ encoding   } ||= $self->{ encoding };

    # check incoming args have got what we need
    $self->check_params($args);

    # add extra params for HTML email
    my $ctype = $self->content_type($format);
    if ($ctype) {
        $self->debug("adding content-type ($ctype) for $format ($format)") if DEBUG;
        $args->{ ctype } = $ctype;
    }

    $self->debug(
        "Sending email via $self->{ mailhost } : ",
        $self->dump_data_inline($args)
    ) if DEBUG;

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


sub check_params {
    my ($self, $params) = @_;
    for (qw(from to subject message)) {
        return $self->error_msg( missing_param => $_ )
            unless $params->{ $_ };
    }
}

1;
