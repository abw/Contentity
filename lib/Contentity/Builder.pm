package Contentity::Builder;

use Template;
use Contentity::Reporter;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    utils     => 'VFS Dir split_to_list extend self_params Now yellow',
    accessors => 'source_dirs library_dirs output_dir reporter',
    constant  => {
        TEMPLATE_ENGINE => 'Template',
        REPORTER_MODULE => 'Contentity::Reporter',
    };


sub init {
    my ($self, $config) = @_;
    $self->init_builder($config);
    return $self;
}

sub init_builder {
    my ($self, $config) = @_;

    $self->debug_data("init_builder(): ", $config) if DEBUG;

    # source and output directories are mandatory, library dirs are optional
    my $srcs = $config->{ source_dirs  } || return $self->error_msg( missing => 'source_dirs' );
    my $outd = $config->{ output_dir   } || return $self->error_msg( missing => 'output_dir' );
    my $libs = $config->{ library_dirs } || '';

    # some massaging to make them directory objects (or lists thereof)
    $self->{ source_dirs  } = $self->prepare_dirs($srcs);
    $self->{ library_dirs } = $self->prepare_dirs($libs);
    $self->{ output_dir   } = Dir($outd);
    $self->{ data         } = $config->{ data } || { };

    # template_prefix can be specified for reporting purposes.  It's added to
    # the front of template names which is displayed in progress messages
    $self->{ path_prefix  } = $config->{ path_prefix };

    # create a reporter to handle message output
    $self->{ reporter     } = $self->REPORTER_MODULE->new($config);

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

    return $dirs;
}

#-----------------------------------------------------------------------------
# building
#-----------------------------------------------------------------------------

sub build {
    my ($self, $data) = self_params(@_);

    #$data->{ production  } = $data->{ deployment } eq 'production';
    #$data->{ development } = $data->{ deployment } eq 'development';

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
    my $self      = shift;
    my $data      = $self->template_data(@_);
    my $templates = $self->source_templates;

    #$self->debugf("Skipping %s templates", scalar @$templates);
    $self->info("Dry run...");

    foreach my $template (@$templates) {
        $self->template_skip($template);
    }
}

sub process_templates {
    my $self        = shift;
    my $data        = $self->template_data(@_);
    my $engine      = $self->template_engine;
    my $templates   = $self->source_templates;
    my $outdir      = $self->output_dir;
    my $srcdirs     = $self->source_dirs;
    my $libdirs     = $self->library_dirs;

    $data->{ date } ||= Now->date;
    $data->{ time } ||= Now->time;
    $data->{ when } ||= Now;
    $data->{ dirs } ||= { };

    $data->{ dirs }->{ src  } ||= $self->source_dirs->[0];
    $data->{ dirs }->{ dest } ||= $self->output_dir;

    $self->debug_data("DATA: ", $data) if DEBUG;

    $self->debug(
        sprintf(
            "%s templates found in %s", 
            scalar(@$templates), 
            $self->dump_data($self->source_dirs)
        )
    ) if DEBUG;

    $self->info("Building scaffolding templates...");
    $self->info_dirs("From: ", $srcdirs);
    $self->info_dirs("With: ", $libdirs);
    $self->info_dir( "  To: ", $outdir);

    foreach my $template (@$templates) {
        my $path = $template->absolute;
        $path =~ s[^/][];

        # process($src_file, $data, $out_file) - we read files from one places 
        # (sources_dirs) and write them to a file of the same name in another
        # place (output_dir).  So in this case, $src_file and $out_file are the
        # same $path reference

        if ($engine->process($path, $data, $path)) {
            # Wow!  Much success.
            $self->template_pass($path);
        }
        else {
            # Oh noes!
            $self->template_fail($path, $engine->error);
        }

        # output file should have the same file permissions as the source file
        # to ensure that executable scripts remain executable, for example.
        $outdir->file($path)->chmod(
            $template->perms
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

sub source_templates {
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

sub pass {
    shift->reporter->pass(@_);
}

sub fail {
    shift->reporter->fail(@_);
}

sub skip {
    shift->reporter->skip(@_);
}

sub info {
    shift->reporter->info(@_);
}

sub info_dir {
    my ($self, $info, $dir) = @_;
    $self->info($info, yellow($dir));
}

sub info_dirs {
    my ($self, $info, $dirs) = @_;
    my $text = $info;
    my $tlen = length $text;
    my $tpad = (' ' x ($tlen - 2)) . '+ ';

    foreach my $dir (@$dirs) {
        $self->info_dir($text, $dir);
        $text = $tpad;
    }
}

sub template_pass {
    my $self = shift;
    my $file = $self->template_filename(@_);
    $self->pass("    + $file");
}

sub template_fail {
    my $self = shift;
    my $file = $self->template_filename(shift);
    $self->fail("    ! $file");
}

sub template_skip {
    my $self = shift;
    my $file = $self->template_filename(shift);
    $self->skip("    - $file");
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

sub template_data {
    my $self = shift;
    return extend({ }, $self->data, @_);
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

__END__

=head1 NAME

Contentity::Builder - template-based scaffolding for project/site configuration files

=head1 SYNOPSIS

    use Contentity::Builder;

    my $builder = Contentity::Builder->new(
        source_dirs  => [ '/path/to/source/one', '/path/to/source/two'   ],
        library_dirs => [ '/path/to/library/one', '/path/to/library/two' ],
        output_dir   => '/path/to/output/dir',
        data         => {
            # any template variable data goes here
            foo => 'Hello World',
            bar => 'Swiss Cheese',
        }
    );

    $builder->build;


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

=head2 verbose

Set this to any true value to have messages output to STDOUT displaying the 
progress of the module.

=head2 quiet

Set this to any true value to suppress error messages if you really don't care
about them (but don't blame me if you miss something important).

=head2 nothing

Set this to any true value to have the builder do a dry run instead of 
processing any templates.

=head1 METHODS

=head2 new()

Constructor method to create a new C<Contentity::Builder> object.  Any of the
L<configuration options|CONFIGURATION OPTIONS> specified above can be passed
as named parameters.

    my $builder = Contentity::Builder->new(
        source_dirs  => [ '/path/to/source/one', '/path/to/source/two'   ],
        library_dirs => [ '/path/to/library/one', '/path/to/library/two' ],
        output_dir   => '/path/to/output/dir',
    );

=head2 build($data)

This is the main entry point method.  It processes all the templates in the 
L<source_dirs> directories and writes the output to corresponding files in 
the L<output_dir>.

A reference to a hash array of template variables can be passed as an argument.

    $builder->process_templates({
        # template data variables    
        foo => 'Hello World',
        bar => 'Swiss Cheese',
    });

=head2 verbose()

Getter/setter for the L<verbose> option.

    $builder->verbose(1);      # set

    if ($builder->verbose) {   # get
        ...
    }

=head2 quiet()

Getter/setter for the L<quiet> option, usage as per L<verbose()>.

=head2 nothing()

Getter/setter for the L<nothing> option, usage as per L<verbose()>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

=cut
