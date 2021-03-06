package Contentity::Component::Context;

use Badger::Debug 'debug_callers';
use Contentity::Web::Request;
use Contentity::Class
    version     => 0.1,
    debug       => 0,
    import      => 'class',
    base        => 'Contentity::Component',
    accessors   => 'request base path url status headers',
    mutators    => 'content_type',
    utils       => 'self_params is_object weaken extend Path URL blessed Now',
    constants   => 'HASH ARRAY BLANK SLASH :http_accept',
    alias       => {
        output  => \&content,
    },
    constant    => {
        REQUEST_MODULE => 'Contentity::Web::Request',
        SINGLETON      => 0,
    };

sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( context => $config ) if DEBUG;
    $self->init_context($config);
    return $self;
}

sub init_context {
    my ($self, $config) = @_;
    my $space   = $self->workspace;
    my $env     = $config->{ env } || return $self->error_msg( missing => 'env' );
    my $request = $self->new_request($env);
    my $base    = $request->script_name || BLANK;
    my $path    = Path($request->path_info);
    #my $uri     = $request->request_uri;

    # Our path knows the different between what's been done and what's left todo
    # We just need to prime it so that the Location part (which Plack puts in
    # SCRIPT_NAME, apparently) is put into the part that's already been done.
    $path->relative_to($base);

    $self->debug_data( env => $env ) if DEBUG;

    #$self->debug("uri: $uri") if DEBUG or 1;

    $self->{ env } = $env;
    weaken $self->{ env };


    $self->{ base         } = $base;
    $self->{ url          } = URL($base);    # not sure we need this now - see C::C::Web url()
    $self->{ path         } = $path;
    $self->{ request      } = $request;
    $self->{ data         } = $config->{ data } || { };

    $self->{ apps         } = [ ];
    $self->{ options      } = { };
    $self->{ headers      } = { };
    $self->{ content      } = [ ];
    # TODO: just set type?
    $self->{ content_type } = 'text/html; charset="utf-8"';
    $self->{ status       } = 200;

#   $self->{ apache  } = $config->{ apache };       # not sure if we need this

    return $self;
}


#-----------------------------------------------------------------------
# Context data
#-----------------------------------------------------------------------

sub data {
    my $self = shift;
    my $data = $self->{ data };

    if (@_ == 1) {
        return $self->get(@_);
    }

    if (@_ > 1) {
        $self->set(@_);
    }

    return $data;
}

sub get {
    my ($self, $name) = @_;
    return $self->{ data } ->{ $name };
}


sub set {
    my $self = shift;
    extend($self->{ data }, @_);
    return $self;
}

sub unset {
    shift->delete_data(@_);
}

sub delete_data {
    my ($self, $name) = @_;
    return delete $self->{ data }->{ $name };
}

sub template_data {
    my $self   = shift;
    my $space  = $self->workspace;
    my $uctype = ucfirst $space->type;
    my $data   = extend({ }, $self->{ data }, @_);

    $data->{ Session } = $self->session;
    $data->{ Project } = $space->project;
    $data->{ Site    } = $space;
    $data->{ $uctype } = $space;

    return $data;
}


#-----------------------------------------------------------------------------
# Request
#-----------------------------------------------------------------------------

sub new_request {
    my $self = shift;
    return $self->REQUEST_MODULE->new(@_);
}


#-----------------------------------------------------------------------------
# Response
#-----------------------------------------------------------------------------

sub response {
    my $self     = shift;
    my $response = $self->{ response } ||= $self->new_response;

    if (@_) {
        # update existing response with new params
        my $params = Badger::Utils::params(@_);
        my ($key, $value);

        foreach $key (qw{ status redirect }) {
            if ($value = delete $params->{ $key }) {
                $response->$key($value);
            }
        }
        if ($value = delete $params->{ body } || delete $params->{ content }) {
            $response->body($value);
        }
        if ($value = delete $params->{ type }) {
            # The content type can be an alias for a definition in content_types.yaml
            my $ctype   = $self->workspace->content_type($value) || $value;
            #    || return $self->error_msg( invalid => 'content type' => $value );
            $self->debug("got content type: $value => $ctype") if DEBUG;

            $response->content_type($ctype);
        }
        if (%$params) {
            $self->error("Invalid response parameters: ", $self->dump_data($params));
        }
    }

    return $response;
}

sub new_response {
    my $self     = shift;
    my $request  = $self->request;
    my $response = $request->new_response;
    my $content  = $self->content;

    $response->status( $self->status );
    $response->headers( $self->headers );
    $response->content_type( $self->content_type );
    $response->body( $content ) if $content && @$content;

    return $response;
}

sub content {
    my $self    = shift;
    my $content = $self->{ content };
    push(@$content, @_);
    return $content;
}

sub set_response_headers {
    my ($self, $headers) = self_params(@_);
    # if we've already created a response we must add the headers to it
    if ($self->{ response }) {
        $self->debug_data( "adding headers to existing response ($self->{ response })" => $headers ) if DEBUG;
        $self->{ response }->headers($headers);
    }
    extend($self->headers, $headers);
}

#-----------------------------------------------------------------------------
# Cookies and Sessions
#-----------------------------------------------------------------------------


sub get_cookie {
    my ($self, $name) = @_;
    return $self->request->cookies->{ $name };
}

sub set_cookie {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;
    my ($cookie, $expires);

    if (@_ == 1 && ! ref $_[0]) {
        # old usage: pass optional expires argument
        $expires = shift;
        $cookie  = { value => $value };
    }
    else {
        # new usage: pass a hash reference or multiple named params
        # $cookie can contain keys such as domain, expires, path,
        # httponly, secure, max-age.
        $cookie  = Badger::Utils::params(@_);
        $expires = $cookie->{ expires };
    };
    $cookie->{ value } = $value;
    $cookie->{ path  } ||= SLASH;

    my $response = $self->response;

    if ($expires) {
        # $expires can bet set to a value like '30 hours' which we need
        # to convert to an epoch time
        $cookie->{ expires } = Now->adjust($expires);
        $self->debug("setting cookie to expire: $expires") if DEBUG;
    }
    $self->debug_data("setting cookie on response", $cookie) if DEBUG;
    return $response->cookies->{ $name } = $cookie;
}

sub session_cookie {
    my $self = shift;
    return $self->workspace->config( session => 'cookie' )
        || $self->error_msg( missing => 'session cookie' );
}

sub session_cookie_config {
    my $self = shift;
    return $self->workspace->config( session => 'cookie_config' );
    # can return nothing
}

sub get_session_key {
    my $self = shift;
    return $self->get_cookie(
        $self->session_cookie
    );
}

sub set_session_key {
    my $self = shift;
    return $self->set_cookie(
        $self->session_cookie,
        @_
    );
}

sub session {
    my $self = shift;
    return  $self->{ session }
        ||= $self->load_session;
}

sub load_session {
    my $self     = shift;
    my $sessions = $self->model->sessions;
    my $skey     = $self->get_session_key;
    my $session;

    # TODO: We want to create new temporary session in memcached and only commit
    # them to the database on a return visit.  Otherwise we end up creating a
    # session for every visit by every search bot.

    if ($skey && ($session = $sessions->session_login_user( cookie => $skey ))) {
        $self->debug("loaded existing session: #$session->{ id }:$skey\n") if DEBUG;
    }
    else {
        $session = $sessions->insert( $self->session_params );
        $skey    = $session->cookie;
        $self->set_session_key($skey, $self->session_cookie_config);
        $self->debug("created new session: #$session->{ id }:$skey") if DEBUG;
    }

    return $session;
}

sub session_params {
    my $self = shift;
    return {
        ip_address => $self->request->address,
    };
}


#-----------------------------------------------------------------------------
# Authentication
#-----------------------------------------------------------------------------

sub attempt_login {
    my $self = shift;
    my $user = $self->login_user(@_);

    if ($user) {
        return $user;
    }
    else {
        $self->debug("failed login attempt: ", $self->reason) if DEBUG;
        $self->session->failed_login_attempt;
        return undef;
    }
}

sub login_user {
    my $self   = shift;
    my $params = shift || $self->params;
    my $user   = blessed($params)
        ? $params           # we can acept a user object for masquerading
        : $self->model->users->login_user($params)
            || return $self->decline($self->model->users->reason);

    my $login = $self->session->new_login($user, $params) || return;

    # if the user is pending we can activate their account
    $user->activate
        if $user->pending;

    $self->{ user  } = $user;
    $self->{ login } = $login;

    if (DEBUG) {
        $self->debug("login_user() set user to #", $user->id);
        $self->debug("login_user() set login to #", $login->id);
    }

    #if ($params->{ remember_me }) {
    #    $self->debug("remembering....") if DEBUG or 1;
    #    $self->set_session_key_expiry($self->remember_me_time)
    #}

    return $user;
}

sub logout_user {
    my $self = shift;
    my $data = $self->data;

    # Delete any user-related data in the context object...
    delete $self->{ user  };
    delete $self->{ login };

    # and in the context variable stash for templates/response
    delete $data->{ User  };
    delete $data->{ Login };

    $self->debug("deleted User/Login from context data ") if DEBUG;

    # Delete the user_id and any identifying data from session
    $self->session->logout;

    $self->debug("deleted login credentials from session\n") if DEBUG;

    return $self;
}

sub xauth_user {
    my $self    = shift;
    my $user    = shift;
    my $session = $self->session;
    # TODO: read expires from user login
    my $login   = $session->new_login($user)
        || return $self->decline_msg( invalid => key => $session->reason );
    $self->{ user  } = $user;
    $self->{ login } = $login;
    return $user;
}

sub login {
    my $self = shift;

    # return any cached value existing in $self, even if it's undefined
    # (indicating that this context definitely doesn't have a login because
    # we've looked for one before but not found one)

    return $self->{ login }
        if exists $self->{ login };

    return ($self->{ login } = $self->session->login);
}

sub user {
    my $self = shift;

    # return any cached value existing in $self, as per login()
    return $self->{ user }
        if exists $self->{ user };

    # set user either from object passed as parameter or from the
    # session/login user
    return ($self->{ user } = shift || $self->session->user);
}




#-----------------------------------------------------------------------------
# Content negotiation
#
# The 'accept' header, stored in the HTTP_ACCEPT environment variable,
# looks something like this:
#
#   text/xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5,not/this;q=0
#
# The HTTP_ACCEPT_ENCODING and HTTP_ACCEPT_LANGUAGE headers use a similar
# formar.
#
# The parse_accept() method parses such a header and returns a hash array
# listing types against order of preference level, ignoring any set with a
# preference of 0
#
# e.g.
#   {
#       1   => ['text/json'],
#       0.5 => ['text/x-json', 'application/json'],
#   }
#
# The parse_accept_list() returns a list of all acceptable types (a merged
# list of the values in the above).  The parse_accept_hash() method returns
# a lookup hash for quickly checking those values that are defined.
#
# The accept_types(), accept_encodings() and accept_languages() methods
# call parse_accept_hash() with the appropriate HTTP_ACCEPT* value to create
# lookup hashes and cache them for subsequent use.
#
# The accept_type(), accept_encoding() and accept_language() methods check
# that a value passed as an argument is defined in the corresponding lookup
# hash.
#
# In addition, the content types defined in HTTP_ACCEPT are mapped through
# the content_types component (Contentity::Component::ContentTypes) which
# allows multiple content types like 'application/json', 'text/json', etc.,
# to be identified by short aliases like 'json'.
#
# NOTE: this is incomplete.  HTTP_ACCEPT can also contain other parameters
# in addition to 'q'.  We ignore them for now.
#-----------------------------------------------------------------------------

sub accept_type {
    my $self  = shift;
    my $types = $self->accept_types;
    $self->debug_data( accept_type => $types ) if DEBUG;
    return $types unless @_;
    my $type = shift;
    return $types->{ $type };
}

sub accept_encoding {
    my $self = shift;
    my $encs = $self->accept_encodings;
    $self->debug_data( accept_encoding => $encs ) if DEBUG;
    return @_
        ? $encs->{ $_[0] }
        : $encs;
}

sub accept_language {
    my $self  = shift;
    my $langs = $self->accept_languages;
    $self->debug_data( accept_language => $langs ) if DEBUG;
    return @_
        ? $langs->{ $_[0] }
        : $langs;
}

sub accept_types {
    my $self = shift;
    return  $self->{ accept_types }
        ||= $self->workspace->content_types->accept_types(
                $self->parse_accept_hash(
                    $self->env(HTTP_ACCEPT)
                )
            );
}

sub accept_encodings {
    my $self = shift;
    return  $self->{ accept_encodings }
        ||= $self->parse_accept_hash(
                $self->env(HTTP_ACCEPT_ENCODING)
            );
}

sub accept_languages {
    my $self = shift;
    return  $self->{ accept_languages }
        ||= $self->parse_accept_hash(
                $self->env(HTTP_ACCEPT_LANGUAGE)
            );
}

sub parse_accept_hash {
    my $self = shift;
    my $list = $self->parse_accept_list(@_);

    return {
        # pair each list value with itself, e.g. 'text/json' => 'text/json'
        map { $_ => $_ }
        @$list
    };
}

sub parse_accept_list {
    my $self  = shift;
    my $prefs = $self->parse_accept(@_);

    # We want a list of all content types in order of rank

    return [
        # expand the content types in the list corresponding to...
        map  { @{ $prefs->{ $_ } } }
        # ...each of the sorted (numerically descending) hash keys
        sort { $b <=> $a }
        keys %$prefs
    ];
}

sub parse_accept {
    my ($self, $accept) = @_;
    my $prefs  = { };
    my ($pref, $list);

    return { }
        unless $accept;

    # generate hash where keys are preference level (0 < n <= 1)
    # and values are list refs containing items at that level
    foreach my $type (split(/,\s*/s, $accept)) {
        next unless length $type;

        if ($type =~ s/(;.+)//) {
            my $attr = $1;
            $pref = ($attr =~ s/;q=([\d\.]+)//) ? $1 : 1;
        }
        else {
            $pref = 1;
        }
        next if $pref == 0;
        $list = $prefs->{ $pref } ||= [ ];
        push(@$list, $type);
    }

    return $prefs;
}


#-----------------------------------------------------------------------------
# Environment
#-----------------------------------------------------------------------------

sub env {
    return @_ > 1
        ? $_[0]->{ env }->{ $_[1] }
        : $_[0]->{ env };
}

sub model {
    shift->workspace->model;
}


1;
__END__
=head1 NAME

Contentity::Component::Context - web context component

=head1 DESCRIPTION

This module defines a context for a web application.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2014-2022 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Component>

=cut

1;
