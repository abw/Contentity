package Contentity::Component::Scaffold;

use Contentity::Builder;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    utils       => 'self_params',
    constant    => {
        SCAFFOLD_DIR   => 'scaffold',
        LIBRARY_DIR    => 'library',
        BUILDER_MODULE => 'Contentity::Builder',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Scaffold component init_component(): ", 
        $self->dump_data($config)
    ) if DEBUG;

    return $self;
}

sub build {
    shift->builder->build;
}

sub builder {
    my $self = shift;
    return  $self->{ builder } 
        ||= $self->BUILDER_MODULE->new(
                $self->builder_config
            );
}

sub builder_config {
    my $self     = shift;
    my $config   = $self->config;
    my $src_dirs = $config->{ source_dirs  } ||= [ ];
    my $lib_dirs = $config->{ library_dirs } ||= [ ];
    my $data     = $config->{ data         } ||= { };

    # Add the source directories onto the source_dirs list in $params and 
    # the same for library directories.  
    push(@$src_dirs, @{ $self->source_dirs  });
    push(@$lib_dirs, @{ $self->library_dirs });

    # If an output_dir has already been set in $params then it should take
    # precedence, otherwise we default it to be the workspace root directory
    # via output_dir() method in case a subclass need to change the behaviour
    $config->{ output_dir } ||= $self->output_dir;

    if (DEBUG) {
        $self->debug("sources:\n - ",   join("\n - ", @$src_dirs));
        $self->debug("libraries:\n - ", join("\n - ", @$lib_dirs));
        $self->debug("output:\n - $config->{ output_dir }");
    }

    # Merge in the extra data references
    $data = $config->{ data } = $self->builder_data($data);

    $data->{ source_dir  } = $src_dirs->[0];
    $data->{ library_dir } = $lib_dirs->[0];
    $data->{ output_dir  } = $config->{ output_dir };

    $self->debug_data("builder config: ", $config) if DEBUG;
    
    return $config;
}

sub builder_data {
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

sub templates_dir {
    my $self = shift;
    return $self->config->{ scaffold_dir } || $self->SCAFFOLD_DIR;
}


sub source_dirs {
    my $self = shift;
    return  $self->{ source_dirs }
        ||= $self->ancestral_dirs(
                $self->templates_dir,
                $self->workspace->type      #      => scaffold/project
            );
}

sub library_dirs {
    my $self = shift;
    return  $self->{ library_dirs }
        ||= $self->ancestral_dirs(
                $self->templates_dir,
                $self->config->{ library_dir  } || $self->LIBRARY_DIR
            );
}

sub output_dir {
    shift->workspace->dir;
}

1;
