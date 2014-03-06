package Contentity::Scaffold;

use Template;
use Contentity::Reporter;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    utils     => 'VFS Dir red green split_to_list',
    accessors => 'source_dirs library_dirs output_dir reporter',
    #mutators  => 'quiet verbose',
    constant  => {
        TEMPLATE_ENGINE => 'Template',
        REPORTER_MODULE => 'Contentity::Reporter',
    };


sub init {
    my ($self, $config) = @_;

    # source and output directories are mandatory, library dirs are optional
    my $srcs = $config->{ source_dirs  } || return $self->error_msg( missing => 'source_dirs' );
    my $outd = $config->{ output_dir   } || return $self->error_msg( missing => 'output_dir' );
    my $libs = $config->{ library_dirs } || '';

    # some massaging to make them directory objects (or lists thereof)
    $self->{ source_dirs     } = $self->init_dirs($srcs);
    $self->{ library_dirs    } = $self->init_dirs($libs);
    $self->{ output_dir      } = Dir($outd);

    # template_prefix can be specified for reporting purposes.  It's added to
    # the front of template names which is displayed in progress messages
    $self->{ template_prefix } = $config->{ template_prefix };

    # create a reporter to handle message output
    $self->{ reporter        } = $self->REPORTER_MODULE->new($config);

    #$self->{ quiet           } = $config->{ quiet };
    #$self->{ verbose         } = $config->{ verbose };

    return $self;
}

sub init_dirs {
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

    return $dirs;
}

#-----------------------------------------------------------------------------
# templates
#-----------------------------------------------------------------------------

sub process_templates {
    my ($self, $data) = @_;
    my $engine = $self->template_engine;
    my $paths  = $self->collect_templates;
    my $outdir = $self->output_dir;

    $self->debug(
        sprintf(
            "%s templates found in %s", 
            scalar(@$paths), 
            $self->dump_data($self->source_dirs)
        )
    ) if DEBUG;

    foreach my $file (@$paths) {
        # this is a virtual file system so "absolute" paths are actually 
        # relative to the root directories of the VFS.
        my $path = $file->absolute;
        $path =~ s[^/][];

        # process($src_file, $data, $out_file) - we read files from one places 
        # (sources_dirs) and write them to a file of the same name in another
        # place (output_dir).  So in this case, $src_file and $out_file are the
        # same $path reference

        if ($engine->process($path, $data, $path)) {
            # Wow!  Much success.
            $self->template_pass($file);
        }
        else {
            # Oh noes!
            $self->template_fail($file, $engine->error);
        }

        # output file should have the same file permissions as the source file
        # to ensure that executable scripts remain executable, for example.
        $outdir->file($path)->chmod(
            $file->perms
        );
    }
}

sub template_engine {
    my $self = shift;
    my $incs = [ 
        # Template engine expects absolute directory strings
        map { $_->absolute } 
        @{ $self->source_dirs  },
        @{ $self->library_dirs }
    ];
    
    return $self->TEMPLATE_ENGINE->new({
        INCLUDE_PATH => $incs,
        OUTPUT_PATH  => $self->output_dir->absolute,
    })  || $self->error( "Failed to create Template engine: ", Template->error );
}

sub collect_templates {
    my $self = shift;
    my $dirs = shift || $self->source_dirs;
    my $vfs  = VFS->new( root => $dirs );
    my $spec = {
        files   => 1,
        dirs    => 0,
        in_dirs => 1,
    };
    my $files = $vfs->visit($spec)->collect;
    $self->debug("template files:\n - ", join("\n - ", @$files)) if DEBUG;
    return $files;
}

sub template_pass {
    my $self = shift;
    my $file = $self->template_filename(@_);
    $self->reporter->pass(" + $file");
}

sub template_fail {
    my $self = shift;
    my $file = $self->template_filename(shift);
    $self->reporter->fail(" + $file");
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

sub verbose {
    shift->reporter->verbose(@_);
}

sub quiet {
    shift->reporter->quiet(@_);
}



1;

__END__

=head1 NAME

Contentity::Scaffold - template-based scaffolding for project/site configuration files

=head1 SYNOPSIS

    use Contentity::Scaffold;

    my $scaffold = Contentity::Scaffold->new(
        source_dirs  => [ '/path/to/source/one', '/path/to/source/two'   ],
        library_dirs => [ '/path/to/library/one', '/path/to/library/two' ],
        output_dir   => '/path/to/output/dir',
    );

    $scaffold->process_templates({
        # template data variables    
        foo => 'Hello World',
        bar => 'Swiss Cheese',
    });


=head1 DESCRIPTION

This module can be used to generate "scaffolding" for a web site or other 
project.  It can be used as an initial "bootstrap" to create some default
starter files that the end user is then expected to edit.  Or it can be used
as a day-to-day tool for generating (and re-generating as necessary) 
scripts, data files, configuration files, and so on that have system-specific
values embedded in them.  For example, Apache configuration files typically
have filesystem paths embedded in them that will vary from system to system,
or user to user.

The system is template-based (using TT2) and intentionally quite simple.
All of the files in one or more source directories are processed and written
to corresponding files in an output directory.  One or more library directories
may also be specified.  The templates in these directories are not processed
to generate output files but are available (in the TT2 C<INCLUDE_PATH>) so 
that they can be loaded into other templates using C<INCLUDE>, C<PROCESS>, 
C<WRAPPER>, etc.

=head1 CONFIGURATION OPTIONS

=head2 source_dirs

One or more source directories.  This can be a single string containing 
a directory path:

    my $scaffold = Contentity::Scaffold->new(
        source_dirs  => '/path/to/source/one',
        ...
    );

Or a string containing multiple whitespace-delimited directories:

    my $scaffold = Contentity::Scaffold->new(
        source_dirs  => '/path/to/source/one /path/to/source/two',
        ...
    );

It can also be a L<Badger::Filesystem::Directory> object.

    use Badger::Utils 'Dir';

    my $scaffold = Contentity::Scaffold->new(
        source_dirs => Dir('/path/to/source/one'),
        ...
    );

Or a reference to a list of one or more directory paths or objects:

    my $scaffold = Contentity::Scaffold->new(
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

=head2 verbose

Set this to any true value to have messages output to STDOUT displaying the 
progress of the module.

=head2 quiet

Set this to any true value to suppress error messages if you really don't care
about them (but don't blame me if you miss something important).

=head1 METHODS

=head2 new()

Constructor method to create a new C<Contentity::Scaffold> object.  Any of the
L<configuration options|CONFIGURATION OPTIONS> specified above can be passed
as named parameters.

    my $scaffold = Contentity::Scaffold->new(
        source_dirs  => [ '/path/to/source/one', '/path/to/source/two'   ],
        library_dirs => [ '/path/to/library/one', '/path/to/library/two' ],
        output_dir   => '/path/to/output/dir',
    );

=head2 process_templates($data)

This is the main entry point method.  It processes all the templates in the 
L<source_dirs> directories and writes the output to corresponding files in 
the L<output_dir>.

A reference to a hash array of template variables can be passed as an argument.

    $scaffold->process_templates({
        # template data variables    
        foo => 'Hello World',
        bar => 'Swiss Cheese',
    });

=head2 verbose()

Getter/setter for the L<verbose> option.

    $scaffold->verbose(1);      # set

    if ($scaffold->verbose) {   # get
        ...
    }

=head2 quiet()

Getter/setter for the L<quiet> option, usage as per L<verbose()>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut
