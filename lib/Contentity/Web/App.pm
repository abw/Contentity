package Contentity::Web::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    component => 'web',
    constants => 'BLANK :http_status',
    utils     => 'extend join_uri resolve_uri Logic',
    accessors => 'max_path_length action_format',
    config    => [
        'max_path_length|method:MAX_PATH_LENGTH',
        'action_format|method:ACTION_FORMAT',
    ],
    messages  => {
        not_found => 'Resource not found: %s',
    },
    constant  => {
        MAX_PATH_LENGTH => 8,
        ACTION_FORMAT   => '%s_action',
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
    my $access;

    # Save any access login as a Badger::Logic object.
    # Access defined by application config takes precedence over any site-wide
    # access rule (allowing the default for a site to be restricted but leaving
    # one or more apps open for acccess, e.g. /auth to allow login).
    if ($access = $config->{ access } || $space->config('access')) {
        $self->{ access } = Logic( $access );
        $self->{ realm  } = $space->realm;
        $self->debug(
            $self->urn,
            " APP: access: $self->{ access } in realm: $self->{ realm }"
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
    my $result = $self->try->dispatch;

    if ($result) {
        return $result;
    }
    else {
        return $self->send_html(
            qq{<h3 class="red">ERROR:</h3><pre>$@</pre>\n}
        );
    }
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

    if ($self->{ access }) {
        my $roles = $self->authorisation_roles;

        $self->debug(
            "access for ", $self->uri, " is: $self->{ access }"
        ) if DEBUG;

        $self->debug_data(
            "user roles for $self->{ realm } realm: ",
            $roles,
        ) if DEBUG;

        if ($self->{ access }->evaluate($roles)) {
            $self->debug("this user can access this page") if DEBUG;
        }
        else {
            $self->debug("this user CANNOT access this page") if DEBUG;
            if ($self->login) {
                return $self->send_forbidden("You cannot access that page.");
            }
            else {
                return $self->redirect_login;
            }
        }
    }
    else {
        $self->debug("No access rules for app") if DEBUG;
    }

    return $self->$method;
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
    my ($self, $name, $params) = @_;

    # TODO:
    #  - send appropriate content type for file extension (not always HTML)

    return $self->send_html(
        $self->render($name, $params)
    );
}


sub template_path {
    my $self = shift;
    my $uri  = join_uri(@_);
    my $path = $self->{ templates }->{ $uri };
    if ($path) {
        $self->debug("found match for template $uri => $path") if DEBUG or 1;
        return $path;
    }
    $self->debug("template_path($uri) -> resource_path") if DEBUG;
    return $self->resource_path(
        template => $uri
    );
}


sub template_data {
    my $self  = shift;
    return $self->context->template_data(
        { App     => $self          },
        { Session => $self->session || undef },  # in case they return empty lists
        { Login   => $self->login   || undef },
        { User    => $self->user    || undef },
        @_
    );
}


#-----------------------------------------------------------------------------
# Resources
#-----------------------------------------------------------------------------

sub form {
    my $self = shift;
    my $form = $self->workspace->form(
        $self->form_path(@_)
    );
    $self->set( form => $form );
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
        return @_
            ? resolve_uri($path, @_)
            : $path;
    }
    # ...or to the application base uri (typically its location URI)
    return $self->uri(@_);
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
