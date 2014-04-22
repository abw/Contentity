package Contentity::Web::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    component => 'web',
    constants => 'BLANK :http_status',
    utils     => 'extend join_uri Logic',
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


#-----------------------------------------------------------------------------
# initialisation methods
#-----------------------------------------------------------------------------

sub init_component {
    my ($self, $config) = @_;

    $self->debug_data( app => $config ) if DEBUG;

    # have the auto-configuration method provide default values into $config
    $self->configure($config);

    # copy messages into $self so Badger::Base can find them
    $self->{ messages } = $config->{ messages };

    # TODO: also access, templates, template_path, urls, etc.

    $self->debug_data( max_path_length => $self->{ max_path_length } ) if DEBUG;
    $self->debug_data( action_format => $self->{ action_format } ) if DEBUG;

    $self->init_app($config);

    return $self;
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
    shift->dispatch;
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

    return $self->action_method(
        join_uri(@copy),
        $action
    );
}

sub action_method {
    my $self   = shift;
    my $uri    = shift,
    my $method = shift || $self->can('default_action');
    my $route  = _params(@_);

    $self->debug("TODO: proper action_method() (or dispatch_route()) for $uri") if DEBUG or 1;

    return $self->$method;
}


sub default_action {
    shift->not_implemented('in base class');
}



#-----------------------------------------------------------------------------
# Access control
#-----------------------------------------------------------------------------

sub access {
    my $self    = shift;
    my $action  = shift;
    my @args    = @_;

    if ($self->{ access }) {
        $self->debug("access for $self->{ uri } is: $self->{ access }") if DEBUG;

        my $user = $self->user
           || return $self->redirect_login;

        $self->debug(
            "user roles: ", $user->role_names,
            ' => ', $self->dump_data($user->role_hash)
        ) if DEBUG;

        if ($self->{ access }->evaluate($user->role_hash)) {
            $self->debug("this user can access this page") if DEBUG;
        }
        else {
            $self->debug("this user CANNOT access this page") if DEBUG;
            return $self->send_denied_page;
        }
    }

    # Not sure if this is the best thing, but I want a hook to do some
    # extra pre-processing (e.g. restoring any pending data) before the
    # action is invoked
    $self->pre_action($action, @args);

    return $action
        ? $self->$action(@args)
        : $self->default_action;
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
    my $data = extend(
        { App => $self },
        $self->context->data,
        @_
    );
    $self->debug_data( "rendering $name with" => $data ) if DEBUG;

    return $self->renderer->render($name, $data);
}


sub present {
    my ($self, $name, $params) = @_;

    # TODO:
    #  - lookup filename via template_path
    #  - send appropriate content type for file extension (not always HTML)

    return $self->send_html(
        $self->render($name, $params)
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
