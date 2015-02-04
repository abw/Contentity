package Contentity::Component::Web;

use Badger::URL;
use Contentity::Class
    version   => 0.03,
    debug     => 0,
    base      => 'Contentity::Component Contentity::Plack::Component',
    constants => 'BLANK :status :http_status :content_types',
    accessors => 'env context',
    utils     => 'join_uri resolve_uri strip_hash extend split_to_list is_object',
    codecs    => 'json',
    alias     => {
        _params => \&Contentity::Utils::params,
    },
    messages  => {
        not_found      => 'Resource not found: %s',
        redirect_login => 'Please login to access that page',
    },
    constant => {
        URL       => 'Badger::URL',
        EXCEPTION => 'Badger::Exception',
        LOGIN_URL => 'login',
    };


# Default URLs to ensure that we've always got something to fall back on.
# Applications can define their own 'urls' in the config file, or they can
# be defined as site-wide urls.

our $URLS = {
    login      => '/auth/login',
    logged_in  => '/auth/logged_in',
    logged_out => '/auth/logged_out',
};

our $TEMPLATES = {
    error      => '/error/error.html',
    forbidden  => '/error/forbidden.html',
    not_found  => '/error/not_found.html',
};


#-----------------------------------------------------------------------------
# Interface to Plack: call(\%env)
#-----------------------------------------------------------------------------

sub call {
    my $self    = shift;
    my $env     = shift;
    my $context = $self->new_context( env => $env );
    $self->call_in_context($context);
    return $context->response->finalize;
}


#-----------------------------------------------------------------------------
# Internal calling methods
#-----------------------------------------------------------------------------

sub new_context {
    my $self = shift;
    return $self->workspace->context(@_);
}

sub call_in_context {
    my ($self, $context) = @_;
    local $self->{ context } = $context;
    local $self->{ env     } = $context->env;
    $self->run;
}

sub run {
    shift->not_in_base_class;
}


#-----------------------------------------------------------------------------
# Dispatch another app in the same context
#-----------------------------------------------------------------------------

sub call_app {
    my $self = shift;
    my $app  = shift;

    $self->debug("calling app: $app") if DEBUG;

    # TODO: this isn't right - it assume a Plack app
    return $app->(
        $self->context->env
    );
}


#-----------------------------------------------------------------------------
# Request
#-----------------------------------------------------------------------------

sub request {
    shift->context->request;
}

sub method {
    shift->request->method;
}

sub GET {
    shift->method eq 'GET';
}

sub POST {
    shift->method eq 'POST';
}

sub DELETE {
    shift->method eq 'DELETE';
}

sub accept {
    shift->context->accept_type(@_);
}

sub accept_json {
    shift->accept(JSON);
}

sub force_json {
    shift->context->accept_types->{ json } = 1;
}

sub uri {
    my $self = shift;
    my $base = $self->context->base;
    return @_
      ? resolve_uri($base, @_)
      : $base;
}

sub script_name {
    my $self = shift;
    my $base = $self->request->script_name;
    return @_
        ? join_uri($base, @_)
        : $base;
}

sub url {
    my $self = shift;
    my $url;

    if (@_) {
        my $name  = shift;
        $self->debug("url lookup: $name") if DEBUG;

        if ($url = $self->{ urls }->{ $name }) {
            $url = $self->URL->new($url);
            $self->debug("pre-defined URL mapping: $name => ", $url || "<NOT FOUND>") if DEBUG;
        }
        elsif ($name =~ m[^(\w+:)?/]) {
            # if it's absolute (e.g. something like "/foo..." or "http://...")
            # then we return it as it is
            $url = $self->URL->new($name);
            $self->debug("absolute URL: $name => $url\n") if DEBUG;
        }
        # TODO: elsif $site->url(...)     # site-wide URL
        else {
            # if it's not absolute then make it relative to the part of the
            # current URL that the app has consumed
            $url = $self->app_url($name);
            $self->debug("app-relative URL: $name => $url\n") if DEBUG;
        }
        # add any parameters to URL or cache URLs without params for next time
        $self->add_url_params($url, @_)
            if @_;
    }
    else {
        $url = $self->app_url;
    }
    $self->debug("URL => $url") if DEBUG;
    return $url;
}

sub app_url {
    my $self = shift;
    my $done = $self->path->path_done;
    $done = resolve_uri($done, shift) if @_;
    $self->debug("app_url path done: $done") if DEBUG;
    my $url  = $self->URL->new($done);
    $self->add_url_params($url, @_) if @_;
    $self->debug("app_url: $url") if DEBUG;
    return $url;
}

sub add_url_params {
    my $self = shift;
    my $url  = shift;
    if (@_) {
        my $params = Badger::Utils::params(@_);
        strip_hash($params);
        $self->debug_data( adding => $params ) if DEBUG;
        $url->params($params);
    }
    return $url;
}

sub full_url {
    my $self = shift;

    return $self->app_url(
        $self->path->todo
    );
}

sub url_with_params {
    my $self = shift;
    my $url  = $self->app_url;
    $self->add_url_params($url, $self->params);
    return $url;
}

sub OLD_full_url {
    my $self   = shift;
    my $url    = $self->url(@_);
    my $apache = $self->hub->config->apache;

    # make this nicer
    $url->scheme('http');
    $url->host($apache->{ hostname });
    $url->port($apache->{ port })
        if $apache->{ port } &&  $apache->{ port } != 80;

    return $url;
}


#-----------------------------------------------------------------------
# Path
#-----------------------------------------------------------------------

sub path {
    shift->context->path;
}

sub XXclear_path_done {
    my $done = shift->path_done;
    @$done = ();
}

sub XXshift_path_todo {
    my $self = shift;
    my $todo = $self->path->todo;
    return shift @$todo;
}


#-----------------------------------------------------------------------------
# Params
#-----------------------------------------------------------------------------

sub params {
    shift->request->parameters->as_hashref;
}

sub param {
    shift->request->param(@_);
}

sub param_list {
    shift->request->parameters->get_all(@_);
}

sub some_params {
    my $self  = shift;
    my $spec  = shift;
    my $dirty = shift || $self->params;
    my $clean = { };

    $spec = split_to_list($spec);

    for my $k (@$spec) {
        my $v = $dirty->{$k};
        $clean->{$k} = $v
            if defined $v
            && length  $v;
    }

    return $clean;
}


#-----------------------------------------------------------------------------
# Context data
#-----------------------------------------------------------------------------

sub get {
    shift->context->get(@_);
}

sub set {
    shift->context->set(@_);
}

sub data {
    shift->context->data(@_);
}

#-----------------------------------------------------------------------------
# Cookies
#-----------------------------------------------------------------------------

sub get_cookie {
    shift->context->get_cookie(@_);
}

sub set_cookie {
    shift->context->set_cookie(@_);
}

#-----------------------------------------------------------------------------
# Session, Login and User
#-----------------------------------------------------------------------------

sub session {
    shift->context->session;
}

sub login {
    shift->context->login;
}

sub user {
    shift->context->user;
}


#-----------------------------------------------------------------------------
# authorisation roles
#-----------------------------------------------------------------------------

sub roles_for_user {
    my $self = shift;
    return  $self->{ roles_for_user }
        ||= $self->roles_hash('roles.user');
}

sub roles_for_guest {
    my $self = shift;
    return  $self->{ roles_for_guest }
        ||= $self->roles_hash('roles.guest');
}

sub roles_hash {
    my ($self, $key) = @_;
    return {
        map { $_ => 1 }
        @{ split_to_list( $self->workspace->config($key) ) }
    };
}

sub realm_roles {
    my $self  = shift;
    my $login = $self->login;
    my $roles = { };

    if ($login) {
        # merge in the roles explicitly granted to them as realm roles,
        # and any global roles for users defined in config/roles.yaml
        extend(
            $roles,
            $login->realm_roles_hash(
                $self->{ realm } ||= $self->workspace->realm,
            ),
            $self->roles_for_user
        );
        $self->debug_data( merged_roles => $roles ) if DEBUG;
    }
    else {
        $self->debug("no login") if DEBUG;
        extend(
            $roles,
            $self->roles_for_guest,
        );
    }

    return $roles;
}



#-----------------------------------------------------------------------
# Response
#-----------------------------------------------------------------------

sub response {
    shift->context->response(@_);
}

sub redirect_response {
    shift->response(
        redirect => join(BLANK, @_)
    );
}

sub not_found_response {
    shift->response(
        type    => HTML,
        status  => NOT_FOUND,
        content => join(BLANK, @_),
    );
}

sub forbidden_response {
    shift->response(
        type    => HTML,
        status  => FORBIDDEN,
        content => join(BLANK, @_),
    );
}

sub error_response {
    shift->response(
        type    => HTML,
        status  => SERVER_ERROR,
        content => join(BLANK, @_),
    );
}

sub type_content_response {
    my $self    = shift;
    my $type    = shift;
    my $content = join(BLANK, @_);
    return $self->response(
        type    => $type,
        content => $content
    );
}

#-----------------------------------------------------------------------------
# Slightly higher level wrappers which account for the client wanting HTML or
# JSON where appropriate.
#-----------------------------------------------------------------------------

sub send_text {
    shift->type_content_response(TEXT, @_);
}

sub send_html {
    shift->type_content_response(HTML, @_);
}

sub send_xml {
    shift->type_content_response(XML, @_);
}

sub send_json {
    my $self = shift;
    my $data = @_ > 1 ? { @_ } : shift;
    my $jpcb = $self->param('callback');

    if ($jpcb) {
        $self->debug("called as JSONP with callback: $jpcb") if DEBUG;
        return $self->send_jsonp($jpcb, $data);
    }

    #if ($self->option('textarea')) {
    #    return $self->send_json_textarea($data);
    #}

    $self->response(
        type    => 'json',
        content => encode_json($data),
    );
}

sub send_jsonp {
    my $self     = shift;
    my $callback = shift;
    my $data     = @_ > 1 ? { @_ } : shift;
    my $json     = encode_json($data);

    $self->response(
        type    => 'js',
        content => $callback . '(' . $json . ')',
    );
}


sub send_json_error {
    my $self  = shift;
    my $error = $self->json_error_message(@_);
    return $self->send_json(
        status => ERROR,
        error  => $error,
    );
}

sub json_error_message {
    my $self = shift;
    if (@_ == 1 && is_object($self->EXCEPTION, $_[0])) {
        $self->debug("got exception object") if DEBUG;
        return $_[0]->info;
    }
    else {
        return join('', @_);
    }
}

sub send_json_success {
    my $self    = shift;
    my $message = shift;
    my $params  = _params(@_);
    return $self->send_json(
        %$params,
        status  => SUCCESS,
        success => $message,
    );
}

sub send_json_error_msg {
    my $self = shift;
    return $self->send_json_error(
        $self->message(@_)
    );
}


sub send_redirect {
    shift->redirect_response(@_);
}

sub send_not_found {
    shift->not_found_response(@_);
}

sub send_forbidden {
    my $self  = shift;
    my $error = @_ ? join('', @_) : ($@ || $self->reason || 'No reason given');

    if ($self->accept_json) {
        return $self->send_json_error($error);
    }
    else {
        return $self->send_forbidden_html($error);
    }
}

sub send_forbidden_html {
    my $self  = shift;
    my $error = join('', @_);

    # subclasses (e.g. Contentity::Web::App) can redefine this method to embed
    # the error message in a page.

    return $self->error_response(
        "Forbidden: ", $error
    );
}

sub send_error {
    my $self  = shift;
    my $error = @_ ? join('', @_) : ($@ || $self->reason || 'No reason given');

    if ($self->accept_json) {
        return $self->send_json_error($error);
    }
    else {
        return $self->send_error_html($error);
    }
}

sub send_error_html {
    my $self  = shift;
    my $error = join('', @_);

    # subclasses (e.g. Contentity::Web::App) can redefine this method to embed
    # the error message in a page.

    return $self->error_response(
        "Error: ", $error
    );
}



#-----------------------------------------------------------------------------
# Additional wrappers with messages
#-----------------------------------------------------------------------------

sub send_not_found_msg {
    my $self = shift;
    return $self->send_not_found(
        $self->message( not_found => @_ )
    );
}

sub send_error_msg {
    my $self = shift;
    return $self->send_error(
        $self->message(@_)
    );
}

#-----------------------------------------------------------------------------
# Methods for redirecting user to login to access a page
#-----------------------------------------------------------------------------

sub redirect {
    my $self = shift;
    return $self->send_redirect(
        $self->url(@_)
    );
}

sub redirect_login_url {
    my $self   = shift;
    my $login  = shift;
    my $final  = shift;
    my $params = shift;
    my $msg    = @_ ? join('', @_) : $self->message('redirect_login');

    $self->debugf("user was going to: $final") if DEBUG or 1;

    # ensure URL is stringified
    $final = "$final";

    # save the final destination url/params that the user was trying to get to
    $self->session->data(
        redirect_login  => $final,
        redirect_params => $params,
        pending_data    => {
            info => $msg
        }
    )->save;

    #$self->send_html("REDIRECT: [$login] -=> [$final]");
    $self->send_redirect($login);
}

sub pending_redirect_login_url {
    my $self    = shift;
    my $session = $self->session;
    my $data    = $session->data;
    my $url     = delete($data->{ redirect_login  }) || return;
    my $params  = delete($data->{ redirect_params });
    $session->save;
    my $redirect = $self->url($url, $params);
    $self->debug("pending_redirect_login_url: $redirect") if DEBUG;
    return $redirect;
}


sub redirect_login {
    my $self = shift;
    # TODO: might also need domain if we're authenticating across domains
    return $self->redirect_login_url(
        $self->login_url,
        $self->full_url,
        $self->params,
        @_,
    );
}

sub redirect_login_msg {
    my $self = shift;
    return $self->redirect_login(
        $self->message(@_)
    );
}

sub login_url {
    shift->url(LOGIN_URL);
}

#-----------------------------------------------------------------------------
# Other workspace resources
#-----------------------------------------------------------------------------

sub database {
    shift->workspace->database;
}

sub model {
    shift->workspace->model;
}

1;

__END__

=head1 METHODS

=head2 redirect_login_url($login_url, $final_url, $final_params, $msg)

Redirects the user to a login page denoted by C<$login_url>.  On successful
login they will be redirected to C<$final_url> with any C<$final_params> as
query parameters.  The optional C<$msg> parameter can be used to provide
a message to display to the user, e.g. "Please login to access that page".
Otherwise the C<redirect_login> message format is used.

=head2 redirect_login($msg)

Wrapper around L<redirect_login_url> which redirects the user to the standard
login url (via L<login_url()>), with a redirect back to the current page
(via L<url()>) with the current request parameters (via L<params()>).  An
optional message can be provided as an argument, otherwise the default is used.

=head2 redirect_login_msg($format, @args)

Wrapper around L<redirect_login_msg()> that expects a message format name and
arguments.

    # in app/XXX.yaml:
    messages:
      login_to_edit: Please login to edit your %s.

    # in Cog::Web::App::XXX.pm
    return $self->redirect_login_msg( login_to_edit => 'properties' );

    # message displayed:
    Please login to edit your properties.

=head2 login_url()

Returns the C<login> URL which can be defined in the application configuration.
Defaults to C</auth/login>.

    # in app/XXX.yaml
    urls:
      login: /path/to/login.html
