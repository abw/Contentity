package Contentity::Component::Templates;

use Contentity::Template;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'class',
    utils     => 'split_to_list VFS',
    accessors => 'vfs engine',
    constant  => {
        TEMPLATES_PATH  => 'templates',
        TEMPLATE_ENGINE => 'Contentity::Template',
    };


sub init_component {
    my ($self, $config) = @_;
    my $project = $self->project;
    my ($path, $dir, $engine);

    $self->debugf(
        'templates init_component(%s)',
        $self->dump_data($config)
    );

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
    );

    # keep this as much for debugging/testing as anything else
    $self->{ vfs } = VFS->new(
        root => $path
    );

    $config->{ path } = $path;

    $self->init_engine($config);

    return $self;
}


sub init_engine {
    my ($self, $config) = @_;
    my $engine = $config->{ engine } 
        || $self->TEMPLATE_ENGINE;

    class($engine)->load;

    $self->{ engine } = $engine->new($config);
}

sub render {
    shift->engine->render(@_);
}


sub template_file {
    shift->vfs->file(@_);
}

1;