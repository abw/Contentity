package Contentity::Site;

die __PACKAGE__, " is deprecated\n";

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Workspace',
    constant    => {
        CONFIG_FILE    => 'site',
        WORKSPACE_TYPE => 'site',
    };


1;


__END__

sub dispatch {
    my ($self, $context) = @_;
    my $path = $context->path;
    my $page = $self->match_route($path);
    my $appn = $page->{ app };

    $context->set( Site => $self );
    $context->set( Page => $page );

    $self->debug("site dispatching context: $path => ", $self->dump_data($page));

    if ($appn) {
        my $app = $self->app($appn);
        $self->debug("Got $appn app: $app");
        $context->set( App => $app );
        $app->dispatch($context);
    }
    else {
        $context->content(
            $self->message( no_app => $path )
        );
    }

    return $context->response;
}

#-----------------------------------------------------------------------------
# Mapping simple names to URLs, e.g. scheme_info => /scheme/:id/info
#-----------------------------------------------------------------------------

sub apps {
    shift->component('apps');
}

sub app {
    shift->apps->app(@_);
}

#-----------------------------------------------------------------------------
# File extensions
#-----------------------------------------------------------------------------

sub extensions {
    my $self = shift;
    return  $self->{ extensions } 
        ||= $self->config('extensions');
}

1;
