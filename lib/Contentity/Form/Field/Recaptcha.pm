package Contentity::Form::Field::Recaptcha;

use Contentity::Class::Form::Field
    version  => 0.02,
    debug    => 0,
    display  => 'recaptcha',
    config   => 'validate_url|class:VALIDATE_URL!',
    utils    => 'self_params',
    codec    => 'json',
    messages => {
        mandatory => 'Please prove that you are human.',
        recaptcha => 'You did not prove you were human.',
    };

use LWP::UserAgent;

our $LABEL        = 'Confirm you are human',
our $NAME         = 'recaptcha_challenge_field';
our $RESPONSE     = 'recaptcha_response_field';
our $GRESPONSE    = 'g-recaptcha-response';
our $REMOTE_IP    = 'remote_addr';
our $VALIDATE_URL = 'https://www.google.com/recaptcha/api/siteverify';
our $MANDATORY    = 1;


sub validate {
    my $self      = shift;
    my $ignore    = $self->prepare(shift);
    my $params    = shift;
    my $response  = $ignore || $params->{ $RESPONSE } || $params->{ $GRESPONSE };
    my $remote_ip = $params->{ $REMOTE_IP } || $ENV{ uc $REMOTE_IP };

    if (DEBUG) {
        $self->debug_data( recaptcha_prepared => $ignore );
        $self->debug_data( recaptcha_params => $params );
        $self->debug_data( remote_ip => $remote_ip );
        $self->debug_data( response => $response );
        #$self->debug("workspace: ", $self->workspace ) if DEBUG;
    }

    #$self->debug("challenge: $challenge    response: $response") if DEBUG;

    if ($response) {
        my $ok = $self->validate_request(
            remote_addr => $remote_ip,
            response    => $response,
        );

        $self->debug(
            "reCAPTCHA\n",
            "    remote_ip: $remote_ip\n",
            "    response: $response\n",
            "    is valid: $ok\n"
        ) if DEBUG;

        if ($ok) {
            return ($self->{ valid } = 1);      # OK - validated
        }
        else {
            return $self->invalid_msg( recaptcha => $self->reason );
        }
    }
    elsif ($self->{ mandatory }) {
        $self->debug("No response (no '$RESPONSE' or '$GRESPONSE' parameter)") if DEBUG;
        return $self->invalid_msg( mandatory => $self->{ label } );
    }

    return ($self->{ valid } = 1);              # OK - not mandatory
}


sub validate_request {
    my ($self, $params) = self_params(@_);
    my $ip      = $params->{ remote_addr };
    my $input   = $params->{ response };
    my $url     = $self->{ validate_url };
    my $privkey = $self->{ private_key } || $self->workspace->config('recaptcha.private_key')
        || return $self->error_msg( missing => 'recaptcha.private_key' );
    my $ua      = $self->user_agent;
    my $uaresp  = $ua->post(
        $url,
        {
            secret   => $privkey,
            response => $input,
            remoteip => $ip
        }
    );

    if ($uaresp->is_success) {
        my $content = $uaresp->decoded_content;
        my $data    = decode($content);
        $self->debug_data("captcha response" => $data ) if DEBUG;
        return $data->{ success };
    }
    else {
        $self->debug("captcha request failed: ", $uaresp->status_line) if DEBUG;
        $self->decline( "Request failed: " . $uaresp->status_line );
        return 0;
    }
}

sub user_agent {
    LWP::UserAgent->new;
}

1;

__END__

=head1 NAME

Contentity::Web::Form::Field::ReCaptcha - web form field for CAPTCHA via http://recaptcha.net/

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This module defines a web form field object implementing a CAPTCHA (Completely
Automated Procedure for Telling Computers and Humans Apart) using the
service provided by L<http://recaptcha.net/>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
