package Contentity::Component::Builder;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    import      => 'class',
    utils       => 'Now self_params yellow',
    accessors   => 'renderer reporter prompter',
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

    if ($self->nothing) {
        $self->skip_templates($data);
    }
    else {
        $self->process_templates($data);
    }
}

#-----------------------------------------------------------------------------
# templates
#-----------------------------------------------------------------------------

sub skip_templates {
    my $self  = shift;
    my $data  = $self->template_data(@_);
    my $files = $self->source_files;

    #$self->debugf("Skipping %s templates", scalar @$templates);
    $self->info("Dry run...");

    foreach my $file (@$files) {
        $self->template_skip($file);
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

    foreach my $file (@$files) {
        my $path = $file->absolute;
        $path =~ s[^/][];

        # process($src_file, $data, $out_file) - we read files from one places 
        # (sources_dirs) and write them to a file of the same name in another
        # place (output_dir).  So in this case, $src_file and $out_file are the
        # same $path reference

        if ($renderer->try->process($path, $data, $path)) {
            # Wow!  Much success.
            $self->template_pass($path);
        }
        else {
            # Oh noes!
            $self->template_fail($path, $renderer->error);
        }

        # output file should have the same file permissions as the source file
        # to ensure that executable scripts remain executable, for example.
        $outdir->file($path)->chmod(
            $file->perms
        );
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
    $data = { %$data };
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
    $self->reporter->info($info, yellow($dir));
}

sub verbose {
    shift->reporter->verbose(@_);
}

sub quiet {
    shift->reporter->quiet(@_);
}

sub nothing {
    shift->reporter->nothing(@_);
}


1;
