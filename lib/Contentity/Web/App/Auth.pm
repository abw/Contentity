package Contentity::Web::App::Auth;

use Contentity::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Contentity::Web::App',
    utils     => 'extend Now split_to_hash split_to_list URL',
    constants => ':status',
    messages  => {
        bad_user_pass  => 'Incorrect email address or password',
        not_logged_in  => 'You are not logged in',
        bad_email      => 'The email address was not recognised',
        bad_user       => 'It is not possible to complete your registration.  Please contact support.',
        email_added    => '<b>%s</b> has been added to your email addresses.',
        account_active => 'Your account is already active.',
        bad_login      => 'Unable to login user using credentials provided.',
        registered     => 'Welcome!',
        logged_in      => 'Welcome back!',
        reset_password => 'Your password has been reset.',
    };


# NOTE: we inherit the default $URLs in Contentity::Component::Web which map
# URL aliases like 'logged_in' to /auth/logged_in.html.  These URLs can be
# redefined in an application config file.

sub default_action {
    my $self = shift;
    $self->present('index');
}


#-----------------------------------------------------------------------
# login
#-----------------------------------------------------------------------

sub login_action {
    my $self   = shift;
    my $params = $self->params;
    my $user;

    $self->debug_data("login_action()", $params) if DEBUG;

    return $self->already_logged_in($user)
        if $self->user;

    # create a login form
    $self->debug("getting login form") if DEBUG;
    my $form = $self->form('login');

    $self->debug_data( session => $self->session->data ) if DEBUG;

    $self->debug("checking form") if DEBUG;

    if ($form->submitted && $form->validate) {
        $self->debug_data("validated form values: ", $form->values) if DEBUG;

        if ($user = $self->context->attempt_login($params)) {
            return $self->just_logged_in($user);
        }
        else {
            $form->invalid(
                $self->message('bad_user_pass')
            );
        }
    }

    return $self->present('login');
}


#-----------------------------------------------------------------------
# logout
#-----------------------------------------------------------------------


sub logout_action {
    my $self = shift;
    my $user = $self->user;
    $self->context->logout_user;
    return $self->just_logged_out;
}


#-----------------------------------------------------------------------------
# Internal handlers/hooks
#-----------------------------------------------------------------------------

sub already_logged_in {
    my $self = shift;
    my $url  = $self->pending_redirect_login_url
            || $self->config->{ login_redirect };
    return $url
        ? $self->redirect($url)
        : $self->present(
              logged_in => {
                  info => 'You are already logged in.'
              }
          );
}

sub just_logged_in {
    my $self = shift;
    my $url  = $self->param('goto')
            || $self->pending_redirect_login_url
            || $self->config->{ login_redirect };
    return $url
        ? $self->redirect($url)
        : $self->present('logged_in');
}

sub just_logged_out {
    my $self = shift;
    my $url  = $self->param('goto')
            || $self->config->{ logout_redirect };
    return $url
        ? $self->redirect($url)
        : $self->present('logged_out');
}


1;

__END__

=head1 NAME

Contentity::Web::App::Auth - authentication web app for login, registration, etc

=head1 DESCRIPTION

This is a web application providing handlers for logging in, logging out,
registration, password recovery and so on.

=head1 HANDLER METHODS

=head2 login_action()

URI: /auth/login

Params: email, password, remember_me, submit

Calls C<already_logged_in()> if the user is already logged in.

Fetches the C<login> form (defined in config/forms/auth/login.yaml).

If the form has been submitted (C<submit> parameter is any true value)
and passes validation then it attempts to log the user in with the
C<email> and C<password> request parameters provided.  Otherwise it
renders the C<login> template to render the login form.

On successful login it calls the C<just_logged_in()> method.  Otherwise
sets form error using the C<bad_user_pass> message format and
renders C<login> template.

=head2 logout_action()

URI: /auth/logout

No Params

Logs user out and calls C<just_logged_out()> method.

=head1 INTERNAL METHODS

=head2 just_logged_in()

Called when a user logs in.  There may be a pending redirect stored
in the session object.  For example, when a user goes to edit a
property and we tell them they have to login first.  We store the URL
they were going to in the session and once they login we redirect then
to that URL.

If they don't have a pending URL then we look for a C<login_redirect>
configuration option (in C<config/apps/auth.yaml).  If it exists
then the user is redirected to that URL.  Otherwise we render the
C<logged_in> webapp template.

=head2 just_logged_out()

Looks for a C<logout_redirect> configuration option
(in C<config/apps/auth.yaml).  If it exists then the user is redirected
to that URL.  Otherwise it render the C<logged_out> webapp template.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2016 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Web::App>

=cut
