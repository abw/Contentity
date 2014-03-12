package Contentity::Component::Renderer;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    import      => 'class',
    utils       => 'VFS Dir split_to_list extend params self_params',
    accessors   => 'source_dirs library_dirs output_dir config',
    constant    => {
        ENGINE  => 'Contentity::Template',
    },
    messages    => {
        engine_init   => 'Failed to initialise %s template engine: %s',
        engine_render => 'Failed to render %s: %s',
    };

sub init_component {
    my ($self, $config) = @_;
    $self->init_renderer($config);
    return $self;
}

sub init_renderer {
    my ($self, $config) = @_;

    $self->debug_data("init_renderer(): ", $config) if DEBUG;

    # source and output directories are mandatory, library dirs are optional
    my $srcs = $config->{ source_dirs  } || return $self->error_msg( missing => 'source_dirs' );
    my $libs = $config->{ library_dirs } || '';
    my $outd = $config->{ output_dir   };

    # some massaging to make them directory objects (or lists thereof)
    $self->{ source_dirs  } = $self->prepare_dirs($srcs);
    $self->{ library_dirs } = $self->prepare_dirs($libs);
    $self->{ output_dir   } = Dir($outd) if $outd;
    $self->{ data         } = $config->{ data } || { };

    return $self;
}

sub prepare_dirs {
    my $self = shift;
    my $dirs = shift || return [ ];

    # if $dirs isn't already a list reference then we assume it's a string
    # containing one or more directories separated by whitespace and split it
    # into a list
    $dirs = split_to_list($dirs);

    # we also upgrade all strings to directory objects
    return [
        map { Dir($_) }
        @$dirs
    ];
}

sub source_vfs {
    my $self = shift;
    return  $self->{ source_vfs }
        ||= VFS->new( root => $self->source_dirs );
}

sub source_files {
    my $self = shift;
    my $spec = {
        files   => 1,
        dirs    => 0,
        in_dirs => 1,
    };
    my $files = $self->source_vfs->visit($spec)->collect;

    $self->debug("template source files:\n - ", join("\n - ", @$files)) if DEBUG;

    return $files;
}

sub include_path {
    my $self = shift;
    return  $self->{ include_path }
        ||= [ 
            # Template engine INCLUDE_PATH expects absolute directory strings
            map { $_->absolute } 
            @{ $self->source_dirs  },
            @{ $self->library_dirs }
        ];
}

#-----------------------------------------------------------------------------
# The underlying template engine
#-----------------------------------------------------------------------------

sub engine {
    my $self = shift;
    return  $self->{ engine }
        ||= $self->start_engine;
}

sub start_engine {
    my $self   = shift;
    my $engine = $self->config->{ engine } || $self->ENGINE;
    my $config = $self->engine_config;

    # load the module if necessary
    class($engine)->load;

    $self->debug_data("Creating new $engine", $config) if DEBUG;

    # create an engine object
    return $engine->new($config)
        || $self->error_msg( engine_init => $engine, $engine->error );
}

sub engine_config {
    my $self   = shift;
    my $config = $self->config;
    my $ttcfg  = { %$config };
    my $outdir = $self->{ output_dir };
    my (@pre, @post, $item);

    $self->debug_data("templates config ", $config) if DEBUG;

    $ttcfg->{ INCLUDE_PATH } = $self->include_path;
 
    for (qw( config before header )) {
        push(@pre, $config->{ $_ })
            if $config->{ $_ };
    }

    for (qw( footer after )) {
        push(@post, $config->{ $_ })
            if $config->{ $_ };
    }

    $ttcfg->{ ENCODING     } = $config->{ encoding };
    $ttcfg->{ WRAPPER      } = $config->{ wrapper  };
    $ttcfg->{ PRE_PROCESS  } = \@pre  if @pre;
    $ttcfg->{ POST_PROCESS } = \@post if @post;
    $ttcfg->{ OUTPUT_PATH  } = $outdir->absolute if $outdir;

    # what about VARIABLES?

    return $ttcfg;
}


sub data {
    my $self = shift;
    my $data = $self->{ data };

    if (@_ > 1) {
        return extend($data, @_);
    }
    elsif (@_ == 1) {
        return $data->{ $_[0] };
    }
    else {
        return $data;
    }
}


sub render {
    my $self   = shift;
    my $name   = shift;
    # what about merging in our own data, e.g. workspace and Project refs
    my $params = params(@_);
    my $engine = $self->engine;
    my $output;

    $engine->process($name, $params, \$output)
        || return $self->error_msg( engine_render => $name, $engine->error );

    return $output;
}

sub process {
    my $self   = shift;
    my $name   = shift;
    my $engine = $self->engine;
    return $engine->process($name, @_)
        || $self->error_msg( engine_render => $name, $engine->error );
}


1;

__END__

=head1 NAME

Contentity::Component::Renderer - a component for rendering templates

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 CONFIGURATION OPTIONS

=head2 source_dirs

One or more source directories.  This can be a single string containing 
a directory path:

    my $builder = Contentity::Builder->new(
        source_dirs  => '/path/to/source/one',
        ...
    );

Or a string containing multiple whitespace-delimited directories:

    my $builder = Contentity::Builder->new(
        source_dirs  => '/path/to/source/one /path/to/source/two',
        ...
    );

It can also be a L<Badger::Filesystem::Directory> object.

    use Badger::Utils 'Dir';

    my $builder = Contentity::Builder->new(
        source_dirs => Dir('/path/to/source/one'),
        ...
    );

Or a reference to a list of one or more directory paths or objects:

    my $builder = Contentity::Builder->new(
        source_dirs => [ '/path/to/source/one', '/path/to/source/two' ],
        ...
    );

When multiple paths are specified, those specified earlier in the list will
take precedence over those specified later.  In the previous example, a file 
name F<foo> that exists as both C</path/to/source/one/foo> and 
C</path/to/source/two/foo> will be read from C</path/to/source/one/foo>, 
effectively masking C</path/to/source/two/foo>.

=head2 library_dirs

This can be used to specify any additional template directories that should
be added to the C<INCLUDE_PATH>.  Directories can be specified as per
L<source_dirs>.

=head2 output_dir

Defines the directory where the output files should be written.  Source 
templates in sub-directories will be written to corresponding sub-directories
under the C<output_dir>.  File permissions for the output file will be set to 
the same permissions that the source file has.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut
