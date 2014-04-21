package Contentity::Web::App;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    component => 'web',
    constants => 'BLANK :http_status',
    utils     => 'extend join_uri',
    messages  => {
        not_found => 'Resource not found: %s',
    };


#-----------------------------------------------------------------------------
# initialisation methods
#-----------------------------------------------------------------------------

sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( app => $config ) if DEBUG;

    # copy messages into $self so Badger::Base can find them
    $self->{ messages } = $config->{ messages };

    $self->init_app($config);

    return $self;
}

sub init_app {
    my ($self, $config) = @_;
    # stub for subclasses
    $self->debug_data( app => $config ) if DEBUG or 1;
    return $self;
}


#-----------------------------------------------------------------------------
# Run methods
#-----------------------------------------------------------------------------

sub run {
    # This is a do-nothing hook for subclasses that want to replace
    shift->dispatch;
}

sub dispatch {
    shift->default_action;
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
