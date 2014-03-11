package Contentity::Component::Builder;

use Contentity::Builder;
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component::Scaffold',
    utils       => 'self_params',
    constant    => {
        TEMPLATES_DIR  => 'templates',
        SOURCE_DIR     => 'static',
        LIBRARY_DIR    => 'library',
        OUTPUT_DIR     => 'static',
        BUILDER_MODULE => 'Contentity::Builder',
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data(
        "Builder component init_component(): ", 
        $config
    ) if DEBUG;

    return $self;
}

sub build {
    shift->builder->build;
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

sub templates_dir {
    my $self = shift;
    return $self->config->{ templates_dir } || $self->TEMPLATES_DIR;
}

sub source_dirs {
    my $self = shift;
    return  $self->{ source_dirs }
        ||=[$self->workspace->dir(
                $self->templates_dir,
                $self->config->{ source_dir } || $self->SOURCE_DIR,
            )];
# This variant includes all static templates in parent workspaces
#   return  $self->{ source_dirs }
#       ||= $self->ancestral_dirs(
#               $self->templates_dir,
#               $self->config->{ source_dir } || $self->SOURCE_DIR,
#           );
}

sub output_dir {
    my $self = shift;
    return  $self->{ output_dir }
        ||= $self->workspace->dir(
                $self->config->{ output_dir } || $self->OUTPUT_DIR,
            );
}

1;
