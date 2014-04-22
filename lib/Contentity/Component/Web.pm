package Contentity::Component::Web;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Component Contentity::Plack::Component',
    constants => 'BLANK :http_status :content_types',
    accessors => 'env context',
    utils     => 'join_uri',
    alias     => {
        _params => \&Contentity::Utils::params,
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

    $self->debug("calling app: $app") if DEBUG or 1;

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

sub uri {
    my $self = shift;
    my $base = $self->context->base;
    return @_
      ? resolve_uri($base, @_)
      : $base;
}

sub url {
    # TODO: more robust
    shift->context->url;
}

sub script_name {
    my $self = shift;
    my $base = $self->request->script_name;
    return @_
        ? join_uri($base, @_)
        : $base;
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
    shift->request->parameters;
}

sub param {
    shift->request->param(@_);
}

sub param_list {
    shift->params->get_all(@_);
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

#-----------------------------------------------------------------------
# Response
#-----------------------------------------------------------------------

sub response {
    shift->context->response(@_);
}

sub send_not_found {
    shift->response(
        type    => HTML,
        status  => NOT_FOUND,
        content => join(BLANK, @_),
    );
}

sub send_forbidden {
    shift->response_type(
        type    => HTML,
        status  => FORBIDDEN,
        content => join(BLANK, @_),
    );
}

sub send_type_content {
    my $self    = shift;
    my $type    = shift;
    my $content = join(BLANK, @_);
    return $self->response(
        type    => $type,
        content => $content
    );
}

sub send_text {
    shift->send_type_content(TEXT, @_);
}

sub send_html {
    shift->send_type_content(HTML, @_);
}

sub send_xml {
    shift->send_type_content(XML, @_);
}

sub send_json {
    shift->send_type_content(JSON, @_);
}

sub send_redirect {
    shift->response(
        redirect => join(BLANK, @_)
    );
}

1;

__END__
