package Contentity::Component::Web;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Component Contentity::Plack::Component',
    constants => 'BLANK :http_status',
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

sub path {
    shift->context->path;
}

sub params {
    shift->request->parameters;
}

sub param {
    shift->request->param(@_);
}

sub param_list {
    shift->params->get_all(@_);
}

sub script_name {
    my $self = shift;
    my $base = $self->request->script_name;
    return @_
        ? join_uri($base, @_)
        : $base;
}


#-----------------------------------------------------------------------
# Response
#-----------------------------------------------------------------------

sub response {
    shift->context->response(@_);
}

sub response_type {
    my $self    = shift;
    my $type    = shift;
    my $params  = _params(@_);
    my $ctype   = $self->workspace->content_type($type)
        || return $self->error_msg( invalid => 'content type' => $type );

    $params->{ type } = $ctype;
    $self->debug_data("$type content type: $ctype", $params) if DEBUG;

    return $self->response($params);
}

sub response_type_content {
    my $self    = shift;
    my $type    = shift;
    my $content = join(BLANK, @_);
    return $self->response_type(
        $type, content => $content
    );
}

sub send_text {
    shift->response_type_content( text => @_ );
}

sub send_html {
    shift->response_type_content( html => @_ );
}

sub send_xml {
    shift->response_type_content( xtml => @_ );
}

sub send_json {
    shift->response_type_content( json => @_ );
}

sub send_redirect {
    shift->response(
        redirect => join(BLANK, @_)
    );
}

sub send_not_found {
    shift->response_type(
        html => {
            status  => NOT_FOUND,
            content => join(BLANK, @_),
        }
    );
}

sub send_forbidden {
    shift->response_type(
        html => {
            status  => FORBIDDEN,
            content => join(BLANK, @_),
        }
    );
}

sub send_not_found_msg {
    my $self = shift;
    return $self->send_not_found(
        $self->message( not_found => @_ )
    );
}


#-----------------------------------------------------------------------------
# data
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


1;

__END__
