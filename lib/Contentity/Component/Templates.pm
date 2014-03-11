package Contentity::Component::Templates;

use Contentity::Template;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'class',
    utils     => 'split_to_list VFS',
    accessors => 'vfs renderer',
    constant  => {
        TEMPLATES_PATH => 'templates',
        RENDERER       => 'Contentity::Template',
    };


sub init_component {
    my ($self, $config) = @_;
    my ($path, $dir, $engine);
    my $space = $self->workspace;

    $self->debug_data("templates config", $config);

}

1;

__END__
==

    $path = $config->{ path } || $self->TEMPLATES_PATH;
    $path = split_to_list($path);
    $path = [
        # resolve template paths relative to site or base site directory
        map { $project->resolve_dir($_)->must_exist } 
        @$path 
    ];

    $self->debug(
        'templates path: ',
        $self->dump_data($path)
    ) if DEBUG;

    # keep this as much for debugging/testing as anything else
    $self->{ vfs } = VFS->new(
        root => $path
    );

    $config->{ path } = $path;

    $self->init_renderer($config);

    return $self;
}


sub init_renderer {
    my ($self, $config) = @_;
    my $renderer = $config->{ renderer } 
        || $self->RENDERER;

    class($renderer)->load;

    $self->{ renderer } = $renderer->new($config);
}

sub render {
    shift->renderer->render(@_);
}


sub template_file {
    shift->vfs->file(@_);
}

1;
