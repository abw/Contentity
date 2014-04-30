package Contentity::Component::Renderer;

use utf8;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'class',
    utils     => 'VFS Dir split_to_list extend params self_params',
    accessors => 'source_dirs library_dirs output_dir extensions templates_used',
    constants => 'DOT',
    constant  => {
        ENGINE  => 'Contentity::Template',
    },
    messages  => {
        engine_init   => 'Failed to initialise %s template engine: %s',
        engine_render => 'Failed to render %s (%s): %s',
        no_workspace  => 'Cannot provide template_data - renderer has become detached from the workspace',
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
    my $exts = $config->{ extensions   } || '';
    my $outd = $config->{ output_dir   };

    # some massaging to make them directory objects (or lists thereof)
    $self->{ source_dirs  } = $self->prepare_dirs($srcs);
    $self->{ library_dirs } = $self->prepare_dirs($libs);
    $self->{ extensions   } = $self->prepare_exts($exts);
    $self->{ output_dir   } = Dir($outd) if $outd;
    $self->{ data         } = $config->{ data } || { };
    $self->{ path_cache   } = { };

    $self->debug("renderer config: [$config] self config [$self->{ config }") if DEBUG;
    $self->debug_data( extensions => $self->{ extensions } ) if DEBUG;

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

sub prepare_exts {
    my $self  = shift;
    my $exts  = shift || return [ ];
    my $space = $self->workspace;

    $exts = split_to_list($exts);
    $self->debug_data( extensions => $exts ) if DEBUG;

    # we also upgrade each file extension to an array reference containing
    # the extension and content type metadata, e.g. [ html, { ... } ]
    return [
        map {
            [ $_ => $space->content_type($_)
                 || return $self->error_msg(
                        invalid => 'file extension/content type' => $_
                    )
            ]
        }
        @$exts
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

sub source_file {
    my $self = shift;
    return $self->source_vfs->file(@_);
}

sub output_file {
    my $self = shift;
    return $self->output_dir->file(@_);
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

sub template_path {
    my $self  = shift;
    my $name  = shift;
    my $cache = $self->{ path_cache };
    my $path  = $cache->{ $name };        # TODO: might be previously not found

    if (DEBUG) {
        if ($path) {
            $self->debug("found cached location of path: $name => $path");
        }
        else {
            $self->debug("no cached location of path for $name");
        }
    }

    return $path
        if $path;

    $path = $self->source_file($name);

    if (DEBUG) {
        if ($path->exists) {
            $self->debug("template exists as specified: $name => $path");
        }
        else {
            $self->debug("template does NOT exist as specified: $name => $path");
        }
    }

    return ($cache->{ $name } = $path)
        if $path->exists;

    if ($path->extension) {
        # TODO: The template requested already had an extension specified so
        # I don't *think* we should try adding any other extensions onto it.
        # But I may want to revisit this, e.g. index.html => index.html.tt3
        return undef;
    }

    my $exts = $self->extensions;
    my ($pair, $ext, $type);

    foreach $pair (@$exts) {
        ($ext, $type) = @$pair;
        $path = $self->source_file($name.DOT.$ext);
        $self->debug("+ext:$ext looking to see if $path exists") if DEBUG;
        if ($path->exists) {
            # TODO: we want to pass the $type info back up somehow
            return ($cache->{ $name } = $path);
        }
    }
    return undef;
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

    $self->debug("ENCODING: $config->{ encoding }") if DEBUG;
    $ttcfg->{ ENCODING     } = $config->{ encoding } || 'utf8';
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
    my $engine = $self->engine;
    my $path   = $self->template_path($name) || return $self->template_not_found($name);
    my $params = $self->template_data(@_);
    my $file   = $path->absolute;  # absolute relative to VFS
    my $output;

    # remove leading slash otherwise TT thinks you're trying to access an
    # absolute filesystem path, when it's actually a virtual file system path
    # rooted in the template source directories.
    $file =~ s[^/][];

    $self->debug("rendering [$name] as [$path] ($file)") if DEBUG;

    $engine->process($file, $params, \$output)
        || return $self->error_msg( engine_render => $name, $file, $engine->error );

    $self->debug("rendered: $name: $output") if DEBUG && $name =~ /.html/;

    return $output;
}

sub process {
    my $self   = shift;
    my $name   = shift;
    my $params = $self->template_data(shift);
    my $engine = $self->engine;

    $engine->watch_templates_used;

    my $result = $engine->process($name, $params, @_);
    my $used   = $self->{ templates_used } = $engine->templates_used;

    $self->debug_data( templates_used => $used ) if DEBUG;

    return $result
        || $self->error_msg( engine_render => $name, $engine->error );
}

sub template_data {
    my $self  = shift;
    my $space = $self->workspace
        || return $self->error_msg('no_workspace');

    return extend(
        {
            Renderer  => $self,
            Project   => $space->project || undef,
            Workspace => $space,
            Space     => $space,
            Site      => $space,
        },
        @_
    );
}

sub template_not_found {
    my ($self, $name) = @_;
    my $srcs = join(', ', @{ $self->source_dirs });
    return $self->error_msg( invalid => template => "$name ($srcs)" );

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
