package Contentity::Configure::Scaffold;

use Contentity::Template;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Builder',
    utils     => 'Dir',
    constant  => {
        PROJECT_TYPE    => 'project',
        TEMPLATES_DIR   => 'scaffold',
        TEMPLATES_LIB   => 'library',
#        TEMPLATE_ENGINE => 'Contentity::Template',
    };

sub init {
    my ($self, $config) = @_;
    $self->init_scaffold($config);
    $self->init_builder($config);
    return $self;
}

sub init_scaffold {
    my ($self, $config) = @_;

    my $dir  = $config->{ directory     } || return $self->error_msg( missing => 'directory' );
    my $type = $config->{ project_type  } || $self->PROJECT_TYPE;
    my $tdir = $config->{ templates_dir } || $self->TEMPLATES_DIR;
    my $tlib = $config->{ templates_lib } || $self->TEMPLATES_LIB;
    my $tsrc = $config->{ templates_src } || $type;
    my $root = Dir($dir);

    $tdir = $root->dir($tdir)->must_exist;
    $tsrc = $tdir->dir($tsrc)->must_exist;
    $tlib = $tdir->dir($tlib)->must_exist;

    $config->{ source_dirs  } ||= [ ];
    $config->{ library_dirs } ||= [ ];
    $config->{ output_dir   } ||= $root;

    push(@{ $config->{ source_dirs  } }, $tsrc);
    push(@{ $config->{ library_dirs } }, $tlib);

    $self->debug_data(
        "init_project_type() augmented config: ",
        $config
    ) if DEBUG;

    return $self;
}


1;
