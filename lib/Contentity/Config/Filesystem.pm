# NOTE: moved upstream to Badger::Config::Files

package Contentity::Config::Filesystem;

use Badger::Filesystem 'Dir VFS';
use Contentity::Class
    version     => 0.01,
    debug       => 0,
    import      => 'class',
    base        => 'Contentity::Base',
    utils       => 'resolve_uri split_to_list params',
    accessors   => 'root extensions codecs schemas',
    constants   => 'UTF8 YAML JSON DOT',
    constructor => 'ConfigFS',
    messages    => {
        load_fail => 'Failed to load data from %s: %s',
    };

our $EXTENSIONS = [YAML, JSON];
our $ENCODING   = UTF8;
our $CODECS     = { };

sub init {
    shift->init_filesystem(@_);
}

sub init_filesystem {
    my ($self, $config) = @_;
    my $class = $self->class;

    # create hash of options for file objects created by directory object
    my $encoding = $config->{ encoding }
        || $class->any_var('ENCODING');

    my $filespec = {
        encoding => $encoding,
    };

    # we must have a root directory
    my $dir = $config->{ directory } || $config->{ dir }
        || return $self->error_msg( missing => 'directory' );

    my $root = Dir($dir, $filespec);

    unless ($root->exists) {
        return $self->error_msg( invalid => directory => $dir );
    }

    # a list of file extensions to try in order
    my $exts = $class->list_vars( 
        EXTENSIONS => $config->{ extensions } 
    );
    $exts = [
        map { @{ split_to_list($_) } }
        @$exts
    ];

    # construct a regex to match any of the above
    my $qm_ext = join('|', map { quotemeta $_ } @$exts);
    my $ext_re = qr/.($qm_ext)$/i;

    $self->debug("extensions: ", $self->dump_data($exts)) if DEBUG;
    $self->debug("extension regex: $ext_re") if DEBUG;

    # a mapping of file extensions to codecs, for any that Badger::Codecs 
    # can't grok automagically
    my $codecs = $class->hash_vars( 
        CODECS => $config->{ extensions } 
    );

    $self->{ root       } = $root;
    $self->{ uri        } = $config->{ uri } || $root->name;
    $self->{ extensions } = $exts;
    $self->{ match_ext  } = $ext_re;
    $self->{ codecs     } = $codecs;
    $self->{ encoding   } = $encoding;
    $self->{ filespec   } = $filespec;
    $self->{ uri_paths  } = $config->{ uri_paths };

    return $self;
}


#-----------------------------------------------------------------------------
# Public fetch/store methods
#-----------------------------------------------------------------------------

sub fetch_file {
    my ($self, $uri) = @_;

    my $file = $self->config_file($uri) || return;
    my $data = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;
 
    $self->debug(
        "loaded metadata for $uri from file: ", 
        $self->dump_data($data)
    ) if DEBUG;

    return $data;
}

sub fetch_tree {
    shift->config_tree(shift, undef, @_);
}

sub fetch_uri_tree {
    shift->config_uri_tree(@_);
}

sub fetch_under_tree {
    shift->config_under_tree(@_);
}


#-----------------------------------------------------------------------------
# Internal methods
#-----------------------------------------------------------------------------

sub OLD_uri {
    my $self = shift;
    return @_
        ? resolve_uri($self->{ uri }, @_)
        : $self->{ uri };
}

sub dir {
    my $self = shift;

    return @_
        ? $self->root->dir(@_)
        : $self->root;
}

sub file {
    my $self = shift;
    return $self->root->file(@_);
}

sub config_file {
    my ($self, $name) = @_;

    return  $self->{ config_file }->{ $name } 
        ||= $self->find_config_file($name);
}

sub config_filespec {
    my $self     = shift;
    my $defaults = $self->{ filespec };

    return @_ 
        ? extend({ }, $defaults, @_)
        : { %$defaults };
}

sub find_config_file {
    my ($self, $name) = @_;
    my $root = $self->root;
    my $exts = $self->extensions;

    foreach my $ext (@$exts) {
        my $path = $name.DOT.$ext;
        my $file = $self->file($path);
        if ($file->exists) {
            $file->codec($self->codec($ext));
            return $file;
        }
    }
    return $self->decline_msg(
        not_found => file => $name
    );
}

sub codec {
    my ($self, $name) = @_;
    return $self->codecs->{ $name } || $name;
}


#-----------------------------------------------------------------------------
# Tree walking
#-----------------------------------------------------------------------------

sub config_tree {
    my ($self, $name, $binder, @opts) = @_;
    my $root = $self->root;
    my $file = $self->config_file($name);
    my $dir  = $root->dir($name);
    my $data = { };

    $self->debug(
        "Config tree options: ", 
        $self->dump_data(\@opts)
    ) if DEBUG;

    unless ($file && $file->exists || $dir->exists) {
        return $self->decline_msg( not_found => 'file or directory' => $name );
    }

    if ($file->exists) {
        # read data from file
        my $more = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        $self->debug("Read metadata from file '$file':", $self->dump_data($more)) if DEBUG;
        @$data{ keys %$more } = values %$more;
    }

    if ($dir->exists) {
        # create a virtual file system rooted on the metadata directory
        # so that all file paths are resolved relative to it

        # TODO: add in multiple roots where project has a parent project
        my $vfs = VFS->new( root => $dir );
        $self->debug("Reading metadata from dir: ", $dir->name) if DEBUG;
        $self->scan_config_dir($vfs->root, $data, $binder, @opts);
    }

    $self->debug("$name config: ", $self->dump_data($data)) if DEBUG;

    return $data;
}

sub scan_config_dir {
    my ($self, $dir, $data, $binder, @opts) = @_;
    my $files  = $dir->files;
    my $dirs   = $dir->dirs;

    $data ||= { };

    foreach my $file (@$files) {
        next unless $file->name =~ $self->{ match_ext };
        $self->debug("found file: ", $file->name, ' at ', $file->path) if DEBUG;
        $self->scan_config_file($file, $data, $binder, @opts);
    }
    foreach my $dir (@$dirs) {
        $self->debug("found dir: ", $dir->name, ' at ', $dir->path) if DEBUG;
        $self->scan_config_dir($dir, $data, $binder, @opts);
    }
}

sub scan_config_file {
    my ($self, $file, $data, $binder, @opts) = @_;
    my $base = $file->basename;
    my $ext  = $file->extension;

    $self->debug(
        "scan_config_file($file, $data, $binder,", join(', ', @opts), ")"
    ) if DEBUG;

    # set the codec to match the extension (or any additional mapping)
    # and set the data encoding
    $file->codec($self->codec($ext));
    $file->encoding( $self->{ encoding } );

    my $meta = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;

    if ($binder) {
        $binder->($self, $data, $base, $meta, @opts);
    }
    else {
        $base =~ s[^/][];
        $data->{ $base } = $meta;
    }
}


#-----------------------------------------------------------------------------
# Special cases that bind data defined in sub-directories into the parent
#-----------------------------------------------------------------------------

sub config_uri_tree {
    my ($self, $name, @opts) = @_;
    return $self->config_tree(
        $name, $self->can('uri_binder'), @opts
    );
}

sub config_under_tree {
    my ($self, $name, @opts) = @_;
    return $self->config_tree(
        $name, $self->can('under_binder'), @opts
    );
}


sub uri_binder {
    my ($self, $data, $base, $meta, @opts) = @_;
    my $opts = params(@opts);
    my $opt  = $opts->{ uri_paths } || $self->{ uri_paths };

    $self->debug("uri_paths option: $opt") if DEBUG;

    # This resolves base items as URIs relative to the parent
    # e.g. an entry "foo" in the site/bar.yaml file will be stored in the parent 
    # site as "bar/foo", but an entry "/bam" will be stored as "/bam" because 
    # it's an absolute URI rather than a relative one (relative to the $base)
    while (my ($key, $value) = each %$meta) {
        my $uri = resolve_uri($base, $key);
        if ($opt) {
            $uri = $self->fix_uri_path($uri, $opt);
        }
        $data->{ $uri } = $value;
        $self->debug(
            "loaded metadata for [$base] + [$key] = [$uri]"
        ) if DEBUG;
    }
}

sub fix_uri_path {
    my ($self, $uri, $option) = @_;

    $option ||= $self->{ uri_paths } || return $uri;

    if ($option eq 'absolute') {
        $uri = "/$uri" unless $uri =~ /^\//;
    }
    elsif ($option eq 'relative') {
        $uri =~ s/^\///;
    }
    else {
        return $self->error_msg( invalid => 'uri_paths option' => $option );
    }

    return $uri;
}

sub under_binder {
    my ($self, $data, $base, $meta) = @_;

    # Similar to the above but this joins items with underscores
    # e.g. an entry "foo" in site/bar.yaml will become "bar_foo"
    while (my ($key, $value) = each %$meta) {
        my $uri = resolve_uri($base, $key);
        for ($uri) {
            s[^/+][]g;
            s[/+$][]g;
            s[/+][_]g;
        }
        $data->{ $uri } = $value;
    }
}

1;

