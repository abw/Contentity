package Contentity::Component::Web;

use Badger::URL;
use Badger::Utils;
use Contentity::Class
    version   => 0.03,
    debug     => 0,
    base      => 'Contentity::Component Contentity::Plack::Component',
    constants => 'BLANK SLASH :status :http_status :content_types',
    accessors => 'env context',
    utils     => 'blessed extend join_uri resolve_uri strip_hash split_to_list split_to_hash is_object truelike xformat',
    codecs    => 'json',
    alias     => {
        _params => \&Contentity::Utils::params,
    },
    messages  => {
        not_found      => 'Resource not found: %s',
        redirect_login => 'Please login to access that page',
    },
    constant => {
        URL_CLASS => 'Badger::URL',
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
# Config methods
#-----------------------------------------------------------------------------

sub config_flag {
    my ($self, $name) = @_;
    return truelike $self->config($name);
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


#-----------------------------------------------------------------------------
# URIs, paths, etc
#-----------------------------------------------------------------------------

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

sub path {
    shift->context->path;
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

sub uploads {
    shift->request->uploads->as_hashref;
}

sub upload {
    shift->request->upload(@_);
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

sub unset {
    shift->context->unset(@_);
}

sub data {
    shift->context->data(@_);
}

sub json_data {
    my $self = shift;
    my $data = $self->data;
    my $json = { %$data };

    for my $key (keys %$json) {
        my $value = $json->{ $key };

        if (blessed $value) {
            my $method;

            # look for a json() or data() method
            for my $name (qw( json data )) {
                $method = $value->can($name);
                if ($method) {
                    $self->debug("Calling $name() method to expand $value") if DEBUG or 1;
                    $json->{ $key } = $value->$method;
                }
                last;
            }

            if (! $method) {
                if (textlike $value) {
                    # has stringification method
                    $self->debug("Stringifying blessed object '$key' ($value) in JSON data") if DEBUG or 1;
                    $json->{ $key } = "$value";
                }
                else {
                    # otherwise it must go
                    $self->debug("Deleting blessed object '$key' ($value) from JSON data - no json() or data() method to call");
                    delete $json->{ $key };
                }
            }
        }
    }

    return $json;
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
# URL generation
#-----------------------------------------------------------------------------

sub url {
    my $self = shift;
    my $url;

    if (@_) {
        my $name  = shift;
        $self->debug("url lookup: $name") if DEBUG;

        if ($url = $self->{ urls }->{ $name }) {
            $url = $self->URL_CLASS->new($url);
            $self->debug("pre-defined URL mapping: $name => ", $url || "<NOT FOUND>") if DEBUG;
        }
        elsif ($name =~ m[^(\w+:)?/]) {
            # if it's absolute (e.g. something like "/foo..." or "http://...")
            # then we return it as it is
            $url = $self->URL_CLASS->new($name);
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
    my $uri;

    if (@_) {
        # if an argument is specified then it's assumed to be an alternate
        # URL for the same app, e.g. the /search app might be handling a
        # /search/some/thing/or/other request, but calling this method with
        # a 'property' argument will generate the URL /search/property
        my $base = $self->uri;
        my $path = shift;
        $uri = resolve_uri($base, $path);
        $self->debug("resolved base [$base] [$path] as [$uri]") if DEBUG;
    }
    else {
        # otherwise we assume that the caller wants the current App URL
        # including the full part of the path consumed, e.g. /search/schemes
        $uri = $self->path->path_done;
        $self->debug("CURRENT URL: $uri") if DEBUG;
    }

    my $url = $self->URL_CLASS->new($uri);
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

sub request_uri {
    shift->request->uri;
}

sub expand_url {
    my $self = shift;
    my $url  = shift;

    # allow named URL mapping via config
    $url = $self->{ urls }->{ $url } || $url;

    return xformat($url, @_);
}

sub full_url {
    my $self = shift;
    my $uri  = $self->request_uri;
    my $url  = $self->url(@_);

    $url->scheme( $uri->scheme );
    $url->host( $uri->host );

    return $url;
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

sub set_response_headers {
    shift->context->set_response_headers(@_);
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
    my $self   = shift;
    my $error  = $self->json_error_message(shift);
    my $params = _params(@_);
    return $self->send_json(
        %$params,
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

sub send_json_success_msg {
    my $self = shift;
    my $data = pop if ref $_[-1];         # last argument assumed to be data hash...
    my @args = $self->message(@_);
    push(@args, $data) if $data;
    return $self->send_json_success(@args);
}

sub send_json_error_msg {
    my $self = shift;
    my $data = pop if ref $_[-1];         # last argument assumed to be data hash
    my @args = $self->message(@_);
    push(@args, $data) if $data;
    return $self->send_json_error(@args);
}

sub send_json_data {
    my $self = shift;
    $self->send_json( $self->json_data );
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
# Pending data on redirect - sometimes we want to redirect a user to a
# different page and flash a message to them when they get there.  We store
# pending data in the session and provide various methods of convenience to
# add pending data (typically status messages) before redirecting.
#-----------------------------------------------------------------------------

sub save_pending_data {
    my $self    = shift;
    my $session = $self->session;
    my $data    = $session->data;
    my $pending = $data->{ pending_data } ||= { };

    extend($pending, @_);
    $session->save;

    $self->debug_data("added pending_data to session: ", $pending) if DEBUG;
}

sub load_pending_data {
    my $self    = shift;
    my $data    = $self->session->data;
    my $pending = $data->{ pending_data };
    $self->set($pending) if $pending;
    return $pending;
}

sub take_pending_data {
    my $self    = shift;
    my $session = $self->session;
    my $data    = $session->data;
    my $pending = delete $data->{ pending_data };
    if ($pending) {
        $self->set($pending);
        $session->save;
    }
    return $pending;
}




#-----------------------------------------------------------------------------
# Methods for redirecting user
#-----------------------------------------------------------------------------

sub redirect {
    my $self = shift;
    return $self->send_redirect(
        $self->url(@_)
    );
}

sub redirect_pending_data {
    my $self = shift;
    my $url  = shift;
    my $data = Badger::Utils::params(@_);

    $self->save_pending_data($data);
    return $self->redirect($url);
}

sub redirect_status {
    my $self = shift;
    my $url  = shift;
    my $type = shift;
    my $text = join(' ', @_);

    if ($self->accept_json) {
        return $self->send_json(
            extend(
                { },
                $self->json_data,
                {
                    redirect => $url,
                    status   => $type,
                    $type    => $text,
                }
            )
        );
    }

    $self->save_pending_data(
        $type => $text
    );

    return $self->redirect($url);
}

sub redirect_status_msg {
    my $self = shift;
    my $url  = shift;
    my $type = shift;
    my $text = $self->message(@_);
    return $self->redirect_status($url, $type, $text);
}

sub redirect_success {
    return shift->redirect_status(shift, success => @_);
}

sub redirect_error {
    return shift->redirect_status(shift, error => @_);
}

sub redirect_success_msg {
    return shift->redirect_status_msg(shift, success => @_);
}

sub redirect_error_msg {
    return shift->redirect_status_msg(shift, error => @_);
}

sub redirect_login_url {
    my $self           = shift;
    my $login_url      = shift;
    my $pending_url    = shift;
    my $pending_params = shift;
    my $message        = @_ ? join('', @_) : $self->message('redirect_login');

    $self->debugf("redirect_login_url() sending user to $login_url instead of $pending_url") if DEBUG;

    # ensure URL is stringified
    $pending_url = "" . $pending_url;

    # save the final destination url/params that the user was trying to get to
    $self->session->data(
        redirect_login  => $pending_url,
        redirect_params => $pending_params,
        pending_data    => {
            info => $message
        }
    )->save;

    #$self->send_html("REDIRECT: [$login] -=> [$final]");
    $self->send_redirect($login_url);
}

sub pending_redirect_login_url {
    my $self    = shift;
    my $session = $self->session;
    my $data    = $session->data;
    my $url     = delete($data->{ redirect_login  }) || return;
    my $params  = delete($data->{ redirect_params });
    $session->save;
    $self->debug("pending_redirect_login_url() redirecting to $url") if DEBUG;
    return $url;
}


sub redirect_login {
    my $self = shift;
    my $uri = $self->request_uri;
    $self->debug("redirect_login() uri: $uri") if DEBUG;
    return $self->redirect_login_url(
        $self->login_url,
        $self->request_uri,
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

=head1 FRAMEWORK INTEGRATION METHODS

=head2 call(\%env)

External entry point for web components running under the Plack web
application framework.

=head run()

Internal internal entry point for web components.
Subclasses are expected to re-implement this method.  In this base
class it throws an error indicating that it is not implemented.

=head2 CONTEXT METHODS

=head2 new_context( env => \%env )

Creates a new context object to handle a web application request and
response.  Should be passed a named parameter that provides a reference
to the Plack environment.

=head2 call_in_context($context)

Runs this web app in the context of the object passed as an argument.

=head2 call_app($app)

Dispatches another web application or component in the same content as
the current component.

=head1 CONFIGURATION METHODS

=head2 config_flag($name)

Looks for the configuration item C<$name> and tests if it is truelike.

=head1 REQUEST METHODS

=head2 request()

Returns the C<Plack::Request> object

=head2 method()

Returns the HTTP request method, e.g. C<GET>, C<POST>, etc.

=head2 GET

Returns true if the request L<method()> is C<GET>.

=head2 POST

Returns true if the request L<method()> is C<POST>.

=head2 DELETE

Returns true if the request L<method()> is C<DELETE>.

=head2 accept($type)

Delegates to the context C<accept_type()> method to examine the
C<http-accept> header.  If an argument is passed then it becomes
a boolean test to match the specified type.

=head2 accept_json()

Returns a boolean value to indicate if the C<http-accept> header
indicates the client is expecting a JSON response.

=head2 forces_json()

Forces the L<accept_json()> method to always return true for the
lifetime of this request/response context.

=head1 REQUEST PATH METHODS

=head2 uri($path)

Returns the base URI for the current web component.  Typically this
will be the "mount point" specified in a C<locations.yaml> file or
hard-coded in an Apache configuration file.  If an additional URI path
is passed as an argument then it will be appended to the base path.

=head2 script_name($path)

Delegates to the method of the same name in the request to return the
full path to the script.  If a path is provided as an argument then it
will be appended to the base script path.

=head2 path()

Delegates to the context C<path()> method to return the path object.

=head2 REQUEST PARAMETER METHODS

=head2 params()

Returns a hashref of request parameters.

=head2 param($name)

Returns a single request parameter.

=head2 param_list($names)

Delegates to the C<Plack::Request> C<get_all()> method.

=head2 some_params($spec, $params)

Extracts a hash reference of parameters that are defined and have a
non-zero length.  The C<$spec> should be a reference to an array of
names or a whitespace delimited string of parameter names.  If C<$params>
isn't specified then it calls C<params()> to fetch the current params.

    my $subset = $self->some_params('username password');

=head1 CONTEXT DATA METHODS

Most of these methods simply delegate to the context object.

=head2 get($name)

Get the value of a context variable.

=head2 set($data)

Set one of more items of context data.

=head2 data($data)

Get or set the context data.

=head2 get_cookie($name)

=head2 set_cookie($name, $value)

=head2 session()

=head2 login()

=head2 user()

=head1 RESPONSE METHODS

=head2 response()

=head2 redirect_response($body)

=head2 not_found_response($body)

=head2 forbidden_response($body)

=head2 error_response($body)

=head2 type_content_response($type, $content)

=head2 send_text($text)

=head2 send_html($html)

=head2 send_xml($xml)

=head2 send_json($data)

If a C<callback> parameter is specified then it delegates to
L<send_jsonp()>.  Otherwise it sends a normal JSON response.

=head2 send_jsonp($data)

=head2 send_json_success($text)

=head2 send_json_error($error)

=head2 send_json_error_msg($format, @args)

Calls the C<message()> method to expand a pre-defined message format
with the additional arguments passed.  Then it passes the error message
generated to L<send_json_error()>.

=head2 json_error_message($error)

Called by L<send_json_error()> to ensure that the C<$error> is
plain text.  If C<$error> is an exception object (C<Badger::Exception>)
then is calls the C<$info> method on it to return a textual error message.

=head2 send_redirect($url)

Delegates to L<redirect_response()>.

=head2 send_not_found($body)

Delegates to L<not_found_response()>

=head2 send_not_found_msg($format, @args)

Wrapper around L<send_not_found()> using L<message()> to expand the
message format.

=head2 send_forbidden($error)

Calls L<send_json_error($error)> if L<wants_json()> otherwise calls
L<send_forbidden_html($error)>.

=head2 send_forbidden_html($error)

Calls C<error_response()>.  Subclasses can redefine this method to
embed the error in an HTML page.

=head2 send_error($error)

Calls L<send_json_error($error)> if L<wants_json()> otherwise calls
L<send_error_html($error)>.

=head2 send_error_msg($format, @args)

Wrapper around L<send_error()> using L<message()> to expand the
message format.

=head2 sub send_error_html($error)

Calls C<error_response()>.  Subclasses can redefine this method to
embed the error in an HTML page.

=head1 REDIRECT METHODS

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

=head2 pending_redirect_login_url()

If the session has a C<redirect_login> data item then this method
returns a redirect to that URL.  Any C<redirect_params> will also be
added the URL.  The C<redirect_login> and C<redirect_params> are
removed from the session data.

=head1 PENDING DATA METHODS

Sometimes we want to redirect a user to a different page and flash a
message to them when they get there.  We store pending data in the
session and provide various methods of convenience to add pending data
(typically status messages) before redirecting.

=head2 save_pending_data($data)

Saved pending data.

=head2 load_pending_data()

Loads pending data from the session does not delete it.

=head2 take_pending_data()

Loads and deletes pending data from the session.

=head1 URL GENERATION METHODS

=head2 url($path)

Generates a URL.  Named URLs can be defined in the app configuration
(e.g. 'login => /path/to/login').  Otherwise the L<app_url()> is used
as the base.  Any additional path passed as an argument is appended to
the URL.

=head2 app_url($path, $params)

Generates a URL using the application path plus any sections consumed
from the path (C<$self->path->done>) as the base.    The C<$path>
url is then appended along with any parameters passed by hash reference.

=head2 add_url_params($url, $params)

Adds parameters to the end of a URL object.

=head2 full_url()

Returns the full URL of the request, constructed from the L<app_url()>
plus the remaining path (C<$self->path->todo>).

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Component>, L<Contentity::Web::App>

=cut
