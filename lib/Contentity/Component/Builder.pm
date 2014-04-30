package Contentity::Component::Builder;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    import      => 'class',
    utils       => 'Now Filter Dir self_params yellow grey extend inflect split_to_list',
    accessors   => 'renderer reporter prompter filter',
    constant    => {
        RENDERER => 'static',
        REPORTER => 'Contentity::Reporter',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data(
        "Builder component init_component(): ",
        $config
    ) if DEBUG;

    $self->init_renderer($config);
    $self->init_reporter($config);
    $self->init_filter($config);

    return $self;
}

sub init_renderer {
    my ($self, $config) = @_;

    # fetch a renderer component of the appropriate type (e.g. static)
    my $renderer = $config->{ renderer } || $self->RENDERER;
    $self->{ renderer } = $self->workspace->renderer($renderer);
    $self->debug("created $renderer renderer: $self->{ renderer }") if DEBUG;

}

sub init_filter {
    my ($self, $config) = @_;

    # the templates/static section (loaded by C::Component::Templates and
    # passed to C::Component::Renderer) can also contain include/exclude rules
    # that we can use
    my $rconfig = $self->renderer->config;
    my $fspec   = { };

    foreach my $key (qw( include exclude )) {
        $fspec->{ $key } = $rconfig->{ $key }
            if $rconfig->{ $key };
    }
    if (%$fspec) {
        $self->debug_data("renderer has filtering rules: ", $fspec);
        $self->{ filter } = Filter($fspec);
    }
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

    if ($self->nothing) {
        $self->skip_templates($data);
    }
    else {
        $self->process_templates($data);
    }

    $self->watch_templates($data)
        if $self->watch;
}

#-----------------------------------------------------------------------------
# templates
#-----------------------------------------------------------------------------

sub skip_templates {
    my $self     = shift;
    my $data     = $self->template_data(@_);
    my $renderer = $self->renderer;
    my $files    = $renderer->source_files;

    #$self->debugf("Skipping %s templates", scalar @$templates);
    $self->reporter->info("Dry run...");

    foreach my $file (@$files) {
        $self->template_skip($file, "Dry run");
    }
}

sub process_templates {
    my $self     = shift;
    my $data     = $self->template_data(@_);
    my $renderer = $self->renderer;
    my $files    = $renderer->source_files;
    my $outdir   = $renderer->output_dir;
    my $srcdirs  = $renderer->source_dirs;
    my $libdirs  = $renderer->library_dirs;
    my $filter   = $self->filter;
    my $verbose  = $self->verbose;
    my $watch    = $self->{ watch } = [ ];

    $data->{ date } ||= Now->date;
    $data->{ time } ||= Now->time;
    $data->{ when } ||= Now;
    $data->{ dirs } ||= { };

    $data->{ dirs }->{ src  } ||= $srcdirs->[0];
    $data->{ dirs }->{ dest } ||= $outdir;

    $self->debug_data("DATA: ", $data) if DEBUG;

    $self->debug(
        sprintf(
            "%s templates found in %s",
            scalar(@$files),
            $self->dump_data($self->source_dirs)
        )
    ) if DEBUG;

    #$self->info("Building scaffolding templates...");
    $self->template_dirs_info("From: ", $srcdirs);
    $self->template_dirs_info("With: ", $libdirs);
    $self->template_dir_info( "  To: ", $outdir);

    $self->reporter->init_progress( size => scalar @$files );

    foreach my $file (@$files) {
        my $path = $file->absolute;
        $path =~ s[^/][];

        # process($src_file, $data, $out_file) - we read files from one places
        # (sources_dirs) and write them to a file of the same name in another
        # place (output_dir).  So in this case, $src_file and $out_file are the
        # same $path reference
        if ($filter) {
            if ($filter->item_rejected($path)) {
                $self->template_skip($path, 'rejected by filter rule');
                next;
            }
        }
        if ($self->process_template($path, $data, $file)) {
        }
    }
}


sub process_template {
    my ($self, $path, $data, $file) = @_;
    my $renderer = $self->renderer;

    $self->debug("processing template: $path with ", $renderer) if DEBUG;

    if ($renderer->try->process($path, $data, $path)) {
        # Wow!  Much success.
        $self->template_pass($path);

        # output file should have the same file permissions as the source file
        # to ensure that executable scripts remain executable, for example.
        $renderer->output_file($path)->chmod(
            $file->perms
        );

        my $used = $renderer->templates_used;

        push(@{ $self->{ watch } }, [map { $_->[0] } @$used]);

        return 1;
    }
    else {
        # Oh noes!
        $self->template_fail($path, $renderer->error);
        return 0;
    }
}

sub watch_templates {
    my $self     = shift;
    my $data     = $self->template_data(@_);
    my $watch    = $self->{ watch };
    my $wdirs    = $self->config->{ watch_dirs } || [ ];
    my $reporter = $self->reporter;
    my $all      = {
        map {
            my $list = $_;
            map { $_ => 1 }
            @$list
        }
        @$watch
    };
    $all    = [sort keys %$all];
    $wdirs  = split_to_list($wdirs);
    my $n   = scalar @$all;

    $self->verbose(1);

    return unless $n;

    # watch all config directories for all workspaces
    my $ancestors = $self->workspace->heritage;
    foreach my $ancestor (@$ancestors) {
        $self->debug("ancestor: $ancestor") if DEBUG;
        push(@$wdirs, $ancestor->dir('config'));
    }
    push(@$wdirs, $self->workspace->project->dir('perl/lib'));


    $reporter->info("Watching for changes:");
    $reporter->info("  " . inflect($n, 'template'));

    foreach my $w (@$all) {
        $reporter->info('    - ' . yellow($w));
    }

    if ($wdirs) {
        my $wn  = scalar @$wdirs;
        my $wfs = $self->{ watch_dirs } = [
            map { Dir($_) } @$wdirs
        ];

        $reporter->info("  " . inflect($wn, 'additional directory'));
        foreach my $w (@$wdirs) {
            $reporter->info('    - ' . yellow($w));
        }
    }

    $self->debug_data( watch => $watch ) if DEBUG;

    while (1) {
        sleep(1);

        foreach my $w (@$watch) {
            $self->watch_template($w, $data);
        }
    }
}

sub watch_template {
    my ($self, $watch, $data) = @_;
    my $source     = $watch->[0];
    my $renderer   = $self->renderer;
    my $outfile    = $renderer->output_file($source);
    my $outmod     = $outfile->modified->epoch_time;
    my $watch_dirs = $self->{ watch_dirs };

    foreach my $path (@$watch) {
        my $template = $renderer->engine->context->template($path);
        my $modtime  = $template->modtime;
        my $name     = $path;
        $self->debug("template $source | $path => $modtime | $outmod") if DEBUG;

        # if the template hasn't been updated we might still have a modified
        # file in one of the directories we've been told to watch.
        if ($modtime <= $outmod && $watch_dirs) {
            FS: {
                foreach my $watch_dir (@$watch_dirs) {
                    my $files = $watch_dir->visit(
                        files   => 1,
                        dirs    => 1,
                        in_dirs => 1,
                    )->collect;

                    $self->debug_data( files => $$files ) if DEBUG;

                    foreach my $file (@$files) {
                        $modtime = $file->modified->epoch_time;
                        if ($modtime > $outmod) {
                            $name = $file->definitive;
                            # better attempt to reset workspace in case config files
                            # have changed
                            # Ah tits!  We can't do this.  If we empty the workspace
                            # component cache then this $self->workspace reference
                            # disappears.
                            $self->workspace->builder_reset;
                            last FS;
                        }
                    }
                }
            }
        }
        if ($modtime > $outmod) {
            $self->reporter->info(
                "  ! [" . Now . "]"
              . yellow(" $name ")
              . grey("has been modified  ")
            );
            $self->process_template($source, $data, $outfile);
            last;
        }
    }
}

sub template_data {
    my ($self, $data) = self_params(@_);
    my $space  = $self->workspace;
    my $uctype = ucfirst $space->type;

    # We add in references to the master "Project" and the current "Workspace"
    # (aka "Space" and "Site") with capitalised names to denote their
    # importance.  Note that when we're scaffolding the top-level project,
    # these will all reference the same project workspace.

    # "Workspace" and "Space" are defined for completeness, but in most cases
    # the scaffolding templates will reference Site.something because it's
    # more intuitively obvious (particularly for the casual reader) as to what
    # it signifies.  However, we also create a capitalised reference to the
    # workspace type.  In the case of "site" workspaces, we end up with a
    # reference to "Site" which we've already got.  But in the case of a
    # portfolio for example, it means there will be a "Portfolio" reference
    # as well.
#    $data = { %$data };
    $data = extend({ }, $self->config->{ data }, $data );
    $data->{ Project   } = $space->project;
    $data->{ Workspace } = $space;
    $data->{ Space     } = $space;
    $data->{ Site      } = $space;
    $data->{ $uctype   } = $space;

    $self->debug_data("builder data: ", $data) if DEBUG;

    return $data;
}

#-----------------------------------------------------------------------------
# Reporter delegate methods
#-----------------------------------------------------------------------------

sub template_pass {
    my $self = shift;
    my $file = $self->template_filename(@_);
    $self->reporter->pass("    + $file");
}

sub template_fail {
    my $self  = shift;
    my $file  = $self->template_filename(shift);
    my $error = shift;
    $self->reporter->fail("    ! $file\n      $error");
}

sub template_skip {
    my $self = shift;
    my $file = $self->template_filename(shift);
    $self->reporter->skip("    - $file");
    $self->reporter->info("      # ", @_)
        if @_ && $self->verbose;
}

sub template_filename {
    my $self = shift;
    my $name = shift;
    my $pref = $self->{ template_prefix };
    $name =~ s[^/][];
    return  $pref
        ?   $pref . $name
        :   $name;
}

sub template_dirs_info {
    my ($self, $info, $dirs) = @_;
    my $text = $info;
    my $tlen = length $text;
    my $tpad = (' ' x ($tlen - 2)) . '+ ';

    foreach my $dir (@$dirs) {
        $self->template_dir_info($text, $dir);
        $text = $tpad;
    }
}

sub template_dir_info {
    my ($self, $info, $dir) = @_;
    $self->reporter->info($info . yellow($dir));
}

sub verbose {
    shift->reporter->verbose(@_);
}

sub progress {
    shift->reporter->progress(@_);
}

sub quiet {
    shift->reporter->quiet(@_);
}

sub nothing {
    shift->reporter->nothing(@_);
}

sub watch {
    shift->config->{ watch };
}

1;
