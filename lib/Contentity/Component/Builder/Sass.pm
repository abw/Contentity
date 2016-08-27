package Contentity::Component::Builder::Sass;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component::Builder',
    import      => 'class',
    utils       => 'self_params yellow cmd',
    accessors   => 'renderer',
    constant    => {
        RENDERER => 'sass',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data(
        "SASS Builder component init_component(): ",
        $config
    ) if DEBUG;

    $self->init_renderer($config);
    $self->init_reporter($config);

    return $self;
}

sub init_renderer {
    my ($self, $config) = @_;

    # fetch a renderer component of the appropriate type (e.g. static)
    my $renderer = $config->{ renderer } || $self->RENDERER;
    $self->{ renderer } = $self->workspace->renderer($renderer);
    $self->debug("created $renderer renderer: $self->{ renderer }") if DEBUG;
}

sub init_reporter {
    my ($self, $config) = @_;

    # create a reporter to handle message output
    my $reporter = $config->{ reporter } || $self->REPORTER;
    class($reporter)->load;
    $self->{ reporter } = $reporter->new($config);
    $self->debug("created reporter: $self->{ reporter }") if DEBUG;
}


#-----------------------------------------------------------------------------
# building
#-----------------------------------------------------------------------------

sub build {
    my ($self, $data) = self_params(@_);
    my $renderer = $self->renderer;
    my $srcdirs  = $renderer->source_dirs;
    my $outdir   = $renderer->output_dir;
    my $libdirs  = $renderer->library_dirs;
    my $verbose  = $self->verbose;
    my $program  = $self->sass;
    my $watch    = $self->watch;

    #$self->info("Building scaffolding templates...");
    $self->template_dirs_info("From: ", $srcdirs);
    $self->template_dirs_info("With: ", $libdirs);
    $self->template_dir_info( "  To: ", $outdir);
    $self->reporter->info(" Via: " . yellow($program));

    # sass --load-path DIR --load-path DIR SRC_DIR:DEST_DIR
    my @libopts = map { ('--load-path' => $_) } @$libdirs;
    my $srcdest = join(':', $srcdirs->[0], $outdir);
    my @opts;

    if ($self->watch) {
        push(@opts, '--watch');
    }
    elsif ($self->force) {
        push(@opts, '--force', '--update');
    }
    else {
        push(@opts, '--update');
    }

    if ($self->min) {
        push(@opts, '--style', 'compressed');
    }

    push(@opts, '--sourcemap=none');

    my @cmd = ($program, @libopts, @opts, $srcdest);
    $self->debug("SASS COMMAND: ", join(' ', @cmd)) if DEBUG;

    cmd(@cmd);
}

sub verbose {
    shift->config->{ verbose };
}

sub quiet {
    shift->config->{ quiet };
}

sub force {
    shift->config->{ force };
}

sub min {
    shift->config->{ min };
}

sub sass {
    my $self = shift;
    return $self->workspace->config('server.program.sass');
}


1;
