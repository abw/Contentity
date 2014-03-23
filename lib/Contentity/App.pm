package Contentity::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    component => 'web',
    accessors => 'context env',
    constants => 'BLANK :http_status',
    utils     => 'is_object';


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( app => $config ) if DEBUG;
    $self->init_app($config);
    return $self;
}

sub init_app {
    my ($self, $config) = @_;
    # stub for subclasses
    return $self;
}

#-----------------------------------------------------------------------------
# Interface to Plack
#-----------------------------------------------------------------------------

sub call {
    my $self    = shift;
    my $env     = shift;
    my $context = $self->new_context( env => $env );
    $self->dispatch($context);
    return $context->response->finalize;
}

sub dispatch {
    my ($self, $context) = @_;
    local $self->{ context } = $context;
    local $self->{ env     } = $context->env;
    $self->run;
}

sub run {
    shift->not_implemented('in base class');
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

sub dispatch_app {
    my $self = shift;
    my $app  = is_object(CLASS, $_[0])
        ? shift
        : $self->workspace->app(@_);

    $self->debug("dispatching app: $app") if DEBUG or 1;

    return $app->dispatch(
        $self->context
    );
}

#-----------------------------------------------------------------------
# Response
#-----------------------------------------------------------------------

sub request {
    shift->context->request;
}

sub response {
    shift->context->response(@_);
}

sub send_text {
    shift->response(
        type    => 'text/plain',
        content => join(BLANK, @_)
    );
}

sub send_html {
    shift->response(
        content => join(BLANK, @_)
    );
}

sub send_not_found {
    shift->response(
        status  => NOT_FOUND,
        content => join(BLANK, @_)
    );
}

sub send_forbidden {
    shift->response(
        status  => FORBIDDEN,
        content => join(BLANK, @_)
    );
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


1;
