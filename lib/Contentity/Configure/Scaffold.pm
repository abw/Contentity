package Contentity::Configure::Scaffold;

use Badger::Rainbow 
    ANSI => 'red green yellow cyan blue white grey';

use Contentity::Template;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    accessors => 'root data tdir tlib tsrc dest',
    utils     => 'Dir VFS Now',
    constant  => {
        PROJECT_TYPE    => 'project',
        TEMPLATES_DIR   => 'skeleton',
        TEMPLATES_LIB   => 'library',
        TEMPLATE_ENGINE => 'Contentity::Template',
    };


sub init {
    my ($self, $config) = @_;
    $self->init_scaffold($config);
    return $self;
}

sub init_scaffold {
    my ($self, $config) = @_;

    $self->debug("init scaffold: ", $self->dump_data($config)) if DEBUG;

    # we must have a root directory
    my $dir  = $config->{ directory     } || return $self->error_msg( missing => 'directory' );
    my $root = Dir($dir);
    my $type = $config->{ project_type  } || $self->PROJECT_TYPE;
    my $tdir = $config->{ templates_dir } || $self->TEMPLATES_DIR;
    my $tlib = $config->{ templates_lib } || $self->TEMPLATES_LIB;
    my $tsrc = $config->{ templates_src } || $type;
    my $dest = $config->{ output_dir    } || $root;
    my $data = $config->{ data };

    $self->debug("data: ", $self->dump_data($self->data)) if DEBUG;

    $self->{ root } = $root;
    $self->{ tdir } = $tdir = $root->dir($tdir)->must_exist;
    $self->{ tlib } = $tlib = $tdir->dir($tlib)->must_exist;
    $self->{ tsrc } = $tsrc = $tdir->dir($tsrc)->must_exist;
    $self->{ dest } = $root->dir($dest);
    $self->{ data } = $data;

    $self->{ quiet   } = $data->{ quiet   } || 0;
    $self->{ verbose } = $data->{ verbose } || 0;
    $self->{ nothing } = $data->{ nothing } || 0;

    $self->debug(
        map { "$_: $self->{ $_ }\n" }
        qw( root tdir tsrc tlib )
    ) if DEBUG;
}

sub scaffold {
    my $self    = shift;
    my $root    = $self->root;
    my $data    = $self->data;
    my $teng    = $self->template_engine;
    my $files   = $self->source_files;
    my $tsrc    = $self->tsrc;
    my $dest    = $self->dest;
    my $nothing = $data->{ nothing };
    my $verbose = $data->{ verbose };
    my $quiet   = $data->{ quiet };
    #$data->{ production  } = $data->{ deployment } eq 'production';
    #$data->{ development } = $data->{ deployment } eq 'development';

    $data->{ date } ||= Now->date;
    $data->{ time } ||= Now->time;
    $data->{ when } ||= Now;
    $data->{ dir  } ||= {
        src  => $self->{ tsrc },
        dest => $self->{ dest },
    };

    $self->debug("quiet: $quiet   verbose: $verbose  nothing: $nothing") if DEBUG;

    if ($nothing) {
        $self->info("Dry run...");

        foreach my $file (@$files) {
            $self->skip($file);
        }
    }
    else {
        $self->info("Processing skeleton templates...");
        $self->info("From: $self->{ tsrc }");
        $self->info("  To: $self->{ dest }");

        foreach my $file (@$files) {
            my $path = $file->absolute;
            $path =~ s[^/][];

            if ($teng->process($path, $data, $path)) {
                $self->pass($file);
            }
            else {
                $self->fail($file, $teng->error);
            }
            $dest->file($path)->chmod(
                $file->perms
            );
        }
    }
}

sub info {
    my $self = shift;
    return if $self->{ quiet };
    print STDERR cyan(@_), "\n";
}

sub skip {
    my $self = shift;
    return if $self->{ quiet } || ! $self->{ verbose };
    print STDERR yellow('    - ', @_), "\n";
}

sub pass {
    my $self = shift;
    return if $self->{ quiet } || ! $self->{ verbose };
    print STDERR green('    + ', @_), "\n";
}

sub fail {
    my $self = shift;
    return if $self->{ quiet };
    print STDERR red('    ! ', shift, ':', @_), "\n";
}

sub template_engine {
    my $self = shift;
    $self->debug("vars: ", $self->dump_data($self->data)) if DEBUG;
    $self->debug("output path: ", $self->dest) if DEBUG;
    return $self->TEMPLATE_ENGINE->new({
        path         => [$self->tsrc, $self->tlib],
        OUTPUT_PATH  => $self->dest,
        VARIABLES    => $self->data,
    })  || return $self->error( "Failed to create Template engine: ", Template->error );
}

sub source_files {
    my $self = shift;
    my $tsrc = $self->tsrc;
    my $vfs  = $self->VFS->new(
        root => $tsrc,
    );
    my $spec = {
        files   => 1,
        dirs    => 0,
        in_dirs => 1,
    };
    my $files = $vfs->visit($spec)->collect;
    $self->debug("scaffold files:\n - ", join("\n - ", @$files)) if DEBUG;

    return wantarray
        ? @$files
        :  $files;
}


1;
__END__

if ($nothing) {
    print STDERR cyan "Dry run...\n";

    foreach my $file (@files) {
        print STDERR yellow "  - $file\n";
    }
}
else {
    print STDERR cyan "Processing skeleton templates...\n";

    foreach my $file (@files) {
        print STDERR green(" + $file\n") if $verbose;

        $tt->process($file, undef, $file)
            || die red("TT error processing $file: " . $tt->error());

        my $infile  = $source->file($file);
        my $outfile = $rootdir->file($file);
        chmod( (stat $infile)[2] & 07777, $outfile )
            || warn red("chmod($outfile): $!\n");
   }
}
