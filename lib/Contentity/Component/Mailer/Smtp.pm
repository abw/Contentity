package Contentity::Component::Mailer::Smtp;

use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Contentity::Component::Mailer',
    utils      => 'extend self_params',
    accessors  => 'mailhost',
    constant   => {
        SENDER   => 'Mail::Sender',
        AUTHTYPE => 'LOGIN',
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
    my $html = $args->{ format } && $args->{ format } =~ /^html/i;

    # add defaults parameter to args
    $args->{ smtp       }   = $self->{ mailhost };
    $args->{ from       } ||= $self->{ from };
    $args->{ encoding   } ||= $self->{ encoding };

    # process any template to generate message
    $args->{ message } = $self->process_template($args->{ template }, $args)
        if $args->{ template };

    # check incoming args have got what we need
    $self->check_params( send => $args );

    # add extra params for HTML email
    if ($html) {
        $self->debug("sending as HTML\n---------------\n$args->{ message }") if DEBUG;
        $args->{ ctype } = $self->HTML_CONTENT_TYPE;
    }

    $self->debug(
        "Sending email via $self->{ mailhost } : ",
        $self->dump_data_inline($args)
    ) if DEBUG;

    if ($args->{ testing }) {
        $self->debug("NOT sending email (testing mode )  ", $self->dump_data($args));
        return $args;
    }

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

1;
