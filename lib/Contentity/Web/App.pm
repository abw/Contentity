package Contentity::Web::App;

use Contentity::Router;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    component => 'web',
    constants => 'BLANK SLASH :http_status :content_types',
    utils     => 'extend join_uri resolve_uri Logic self_params',
    accessors => 'max_path_length action_format route_format realm',
    config    => [
        'max_path_length|method:MAX_PATH_LENGTH',
        'action_format|method:ACTION_FORMAT',
        'route_format|method:ROUTE_FORMAT',
    ],
    messages  => {
        not_found   => 'Resource not found: %s',
        bad_handler => 'Invalid handler "%s" specified for "%s" route (no %s() method)',
        bad_method  => 'Invalid method "%s" specified for "%s"',
    },
    constant  => {
        MAX_PATH_LENGTH => 8,
        ACTION_FORMAT   => '%s_action',
        ROUTE_FORMAT    => '%s_route',
        ROUTER          => 'Contentity::Router',
        MATCHED_ROUTE   => 'Route',
        # extra debugging flags for various parts of the code
        DEBUG_ROUTER    => 0,
        DEBUG_ACCESS    => 0,
    },
    alias => {
        _params => \&Contentity::Utils::params,
    };


#our @HASH_ARGS = qw( options filters templates webapps forms urls );
our @HASH_ARGS = qw( templates forms urls );

#-----------------------------------------------------------------------------
# initialisation methods
#-----------------------------------------------------------------------------

sub init_component {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $space = $self->workspace;
    my $access;

    $self->debug_data( app => $config ) if DEBUG;

    # have the auto-configuration method provide default values into $config
    $self->configure($config);

    # copy messages into $self so Badger::Base can find them
    $self->{ messages } = $config->{ messages };

    # merge all templates forms, url, etc., in config and package vars
    foreach my $arg (@HASH_ARGS) {
        $self->{ $arg } = $class->hash_vars( uc $arg, $config->{ $arg } );
        $self->debug("merged $arg: ", $self->dump_data($self->{ $arg })) if DEBUG;
    }

    # TODO: also template_path, urls, etc.

    $self->debug_data( max_path_length => $self->{ max_path_length } ) if DEBUG;
    $self->debug_data( action_format => $self->{ action_format } ) if DEBUG;

    $self->init_access($config);
    $self->init_app($config);

    return $self;
}

sub init_access {
    my ($self, $config) = @_;
    my $space = $self->workspace;
    # Hmmm.... why did I previously put this inside the access condition?
    #my $realm = $self->{ realm } = $self->workspace->realm;
    my $access;

    # Save any access login as a Badger::Logic object.
    # Access defined by application config takes precedence over any site-wide
    # access rule (allowing the default for a site to be restricted but leaving
    # one or more apps open for acccess, e.g. /auth to allow login).
    if ($access = $config->{ access } || $space->config('access')) {
        $self->{ access } = Logic( $access );
        $self->debug(
            $self->urn,
            " APP: access: $self->{ access }"
        ) if DEBUG;
    }
    else {
        $self->debug(
            "No access rules for app: ",
            $self->urn
        ) if DEBUG;
    }
}

sub init_app {
    my ($self, $config) = @_;
    # stub for subclasses
    $self->debug_data( app => $config ) if DEBUG;
    return $self;
}


#-----------------------------------------------------------------------------
# Run methods
#-----------------------------------------------------------------------------

sub run {
    my $self   = shift;
    my $result;

    eval {
        # We allow routes to be defined to handle the routing of URLs to
        # methods, otherwise we fall back to the base class dispatch() method
        $result = $self->route
               || $self->dispatch;
    };

    if ($result) {
        return $result;
    }
    else {
        my $error = $@ || $self->reason || "No further information available.";
        $self->debug($error);
        return $self->wants_json
            ? $self->send_json_error($error)
            : $self->send_app_error_page( error => $error );
    }
}

sub route {
    my $self     = shift;
    my $routes   = $self->config('routes') || return;
    my $router   = $self->ROUTER->new( routes => $routes );
    my $matched  = $router->match($self->path) || return;
    my $match    = $matched->{ data };
    my $method   = $match->{ method   };
    my $handler  = $match->{ handler  };
    my $template = $match->{ template };

    if (DEBUG or DEBUG_ROUTER) {
        $self->debug_data( routes => $routes );
        $self->debug_data( matched_route => $match );
    }

    # copy the route that was matched into the Route data
    $self->set_matched_route($matched);

    if ($handler) {
        # there was a handler defined in the route configuration so we call the
        # corresponding XXX_handler() method
        $method = sprintf($self->route_format, $handler);
    }

    if ($method) {
        my $code = $self->can($method);

        if ($code) {
            $self->debug("routing to ${method}() method") if DEBUG or DEBUG_ROUTER;
            return $self->$code($match);
        }
        return $handler
            ? $self->error_msg( bad_handler => $handler, $match->{ route }, $method )
            : $self->error_msg( bad_method => $method, $match->{ route } );
    }
    elsif ($template) {
        # there was a template defined in the route configuration, and possibly
        # some optional template data
        return $self->present( $template, $match->{ template_data } );
    }

    return undef;
}

sub set_matched_route {
    my ($self, $matched) = @_;
    my $match = $matched->{ data };
    my $path  = $matched->{ path };
    my $done  = $path->done;

    $self->debug_data("set_matched_route()", $matched) if DEBUG;

    # copy the route that was matched into the Route data
    if (@$done) {
        $match->{ route } = SLASH . $done->text;
    }
    $self->set( $self->MATCHED_ROUTE, $match );

    # update the app path to reflect what the router matched
    $self->path->take_path( $done );
}

sub matched_route {
    my $self = shift;
    $self->get( $self->MATCHED_ROUTE );
}

sub dispatch {
    my $self   = shift;
    my $path   = $self->path;
    my $done   = $path->done;
    my $todo   = $path->todo;
    my $format = $self->action_format;
    my (@copy, $name, $value, $action, $method);

    # ignore anything after the first $max path elements
    if (@$todo > $self->max_path_length) {
        splice(@$todo, $self->max_path_length);
    }

    # walk backwards along the length of the path looking for the longest action available
    @copy = @$todo;
    $self->debug("resolved path: ", join('/', @$done), "\n") if DEBUG;
    $self->debug("resolving path: ", join('/', @copy), "\n") if DEBUG;

    while (@copy) {
        # join the remaining path components, ignoring any word following a dot,
        # e.g. foo/bar/baz.html => foo_bar_baz
        $name   = join('_', map { s/\.\w+//g; $_ } @copy);
        $method = sprintf($format, $name);
        $self->debug(" - trying $name: $method()")  if DEBUG;
        last if ($action = $self->can($method));
        pop @copy;
    }

    if ($action) {
        $self->debug("resolved action: $name => $action") if DEBUG;
        # consume the bits of the path that we've eaten up with this action
        splice(@$todo, 0, @copy);  # Here @copy is scalar - number of @copy bits to remove from @todo
        push(@$done, @copy);       # Here @copy is the list of path elements consumed by this action
    }

    return $self->dispatch_method(
        $action
    );
}

sub dispatch_method {
    my $self   = shift;
    my $method = shift || $self->can('default_action');
    my $route  = _params(@_);
    my $roles  = $self->access_roles;

    $self->debug_data( roles => $roles ) if DEBUG;

    if ($self->{ access }) {

        $self->debug(
            "access for ", $self->uri, " is: $self->{ access }"
        ) if DEBUG or DEBUG_ACCESS;

        $self->debug_data(
            "user roles for $self->{ realm } realm: ",
            $roles,
        ) if DEBUG or DEBUG_ACCESS;

        if ($self->{ access }->evaluate($roles)) {
            $self->debug("this user can access this page") if DEBUG or DEBUG_ACCESS;
        }
        else {
            $self->debug("this user CANNOT access this page") if DEBUG or DEBUG_ACCESS;
            if ($self->login) {
                return $self->send_forbidden("You cannot access that page.");
            }
            else {
                return $self->redirect_login;
            }
        }
    }
    else {
        $self->debug("No access rules for app") if DEBUG or DEBUG_ACCESS;
    }

    return $self->$method;
}

sub access_roles {
    return { };
}


sub default_action {
    shift->not_implemented('in base class');
}



#-----------------------------------------------------------------------------
# Template rendering
#-----------------------------------------------------------------------------

sub renderer {
    my $self = shift;
    return  $self->{ renderer }
        ||= $self->workspace->renderer(
                $self->config('renderer')
             || $self->RENDERER
            );
}

sub render {
    my $self = shift;
    my $name = shift;
    my $data = $self->template_data(@_);
    my $path = $self->template_path($name);
    $self->debug_data( "rendering $name as $path with" => $data ) if DEBUG;
    return $self->renderer->render($path, $data);
}


sub present {
    my $self = shift;
    my $name = shift;

    # TODO:
    #  - send appropriate content type for file extension (not always HTML)?

    return $self->send_html(
        $self->render($name, @_)
    );
}


sub template_path {
    my $self = shift;
    my $uri  = join_uri(@_);
    my $path = $self->{ templates }->{ $uri };
    if ($path) {
        $self->debug("found match for template [uri:$uri] => [path:$path]") if DEBUG;
        return $path;
    }
    return $self->resource_path(
        template => $uri
    );
}


sub template_data {
    my $self  = shift;
    return $self->context->template_data(
        {
            App       => $self,
            Session   => $self->session     || undef,  # explicit "|| undef"
            Login     => $self->login       || undef,  # in case any of these
            User      => $self->user        || undef,  # methods return
            Params    => $self->params      || undef,  # empty lists
            #Realm     => $self->realm       || undef,
            #Roles    => $self->realm_roles || undef,
            #Authority => $self->authority   || undef,
        },
        @_
    );
}


#-----------------------------------------------------------------------------
# Resources
#-----------------------------------------------------------------------------

sub form {
    # default is to return a form that has been pre-populated with values
    # from the request params.
    shift->prepared_form(@_);
}

sub blank_form {
    my $self = shift;
    my $uri  = $self->form_path(@_);
    my $form = $self->workspace->form($uri);

    # save the form in the context for templates to access
    $self->set( form => $form );

    return $form;
}

sub prepared_form {
    my $self = shift;
    my $uri  = $self->form_path(@_);
    my $form = $self->blank_form(@_);

    # prime the form with the application request parameters
    $form->params($self->params);

    # default the action to be the form URI relative to current app
    $form->default_action( $self->url($uri) );

    return $form;
}

sub form_path {
    shift->resource_path( form => @_ );
}

sub resource_path {
    my $self = shift;
    my $type = shift;
    my $path = $self->config->{"${type}_path"};  # e.g. form_path, template_path

    # resolve resource name to an explicit path...
    if ($path) {
        $self->debug("resolving path [$path] [@_]") if DEBUG;
        return @_
            ? resolve_uri($path, @_)
            : $path;
    }
    # ...or to the application base uri (typically its location URI)
    $self->debug_data("resolving url(): ", \@_) if DEBUG;
    return $self->uri(@_);
}


#-----------------------------------------------------------------------------
# Content negotiation
#-----------------------------------------------------------------------------

sub wants_json {
    my $self = shift;
    return $self->accept_json
        || $self->url_file_extension_is(JSON);
}

sub url_file_extension_is {
    my ($self, $want) = @_;
    my $ext = $self->url_file_extension || return;
    return $ext eq $want;
}

sub url_file_extension {
    my $self = shift;
    my $path = $self->request->path_info;
    return ($path =~ /\.(\w+)$/) && lc $1;
}



#-----------------------------------------------------------------------------
# Error handling
#-----------------------------------------------------------------------------

sub send_error_html {
    shift->send_error_page(@_);
}

sub send_error_page {
    my $self  = shift;
    my $error = join('', @_);

    return $self->error_response(
        $self->render(
            error => {
                error => $error
            }
        )
    );
}

sub send_app_error_page {
    my ($self, $params) = self_params(@_);
    $self->debug_data( error_page => $params ) if DEBUG;
    return $self->present(
        error => $params
    );
}

sub send_forbidden_html {
    shift->send_forbidden_page(@_);
}

sub send_forbidden_page {
    my $self  = shift;
    my $error = join('', @_);

    return $self->forbidden_response(
        $self->render(
            forbidden => {
                error => $error
            }
        )
    );
}

#-----------------------------------------------------------------------------
# Misc methods
#-----------------------------------------------------------------------------

sub version {
    shift->VERSION;
}







1;

__END__

==

sub site {
    shift->context->site;
}

sub page {
    shift->context->page;
}
