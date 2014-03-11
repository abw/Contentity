package Contentity::Component::Templates;

use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Contentity::Component',
    import     => 'class',
    utils      => 'extend',
    accessors  => '',
    constants  => 'ARRAY',
    constant   => {
        TEMPLATES_DIR => 'templates',
    },
    messages   => {
        infinite_loop => "Infinite loop detected in templates base '%s'",
    };


sub init_component {
    my ($self, $config) = @_;

    $self->{ renderers } = { };
    $self->{ configs   } = { };

    $self->debug_data("templates config", $config) if DEBUG or 1;

    return $self;
}

sub renderer {
    my $self = shift;
    my $name = shift || return $self->no_renderer;

    return  $self->{ renderers }->{ $name }
        ||= $self->new_renderer($name);
}

sub new_renderer {
    my $self     = shift;
    my $name     = shift                         || return $self->no_renderer;
    my $config   = $self->renderer_config($name) || return $self->bad_renderer($name);
    my $path     = $config->{ path   }           ||= [ ];

    # upgrade path to a list reference if it isn't already one
    $path = $config->{ path } = [ $path ]
        if $path && ref $path ne ARRAY;

    # expand any paths relative to workspace(s) and add them to the list
    push(
        @$path,
        $self->prepare_path( source  => $config ),
        $self->prepare_path( library => $config )
    );

    $self->prepare_dir( output  => $config );

    $self->debug_data("start $name renderer", $config ) if DEBUG;

    return $self->workspace->component(
        renderer => $config
    );
}

sub renderer_config {
    my $self    = shift;
    my $name    = shift || return $self->no_renderer;

    # Prepared renderer configurations are stored in $self->{ configs }.  We 
    # can return any cached values therein without further ado, otherwise we 
    # need to go and prepare it.  Note that this can silently return an 
    # undefined value if there is no configuration for the named renderer.

    return  $self->{ configs }->{ $name }
        ||= $self->prepare_renderer_config($name);
}

sub prepare_renderer_config {
    my $self   = shift;
    my $name   = shift                        || return $self->no_renderer;
    my $config = $self->{ config }->{ $name } || return $self->decline;   # no error
    my $base   = $config->{ base };
    my $base_config;

    $self->debug_data("main config for $name: ", $config) if DEBUG;

    # We found a $config specification for $name in the main $self->{ config }
    # (note singular) hash array.  There may also be a 'base' configuration
    # specific which we should merge in.

    # To detect infinite loops between base definitions, we use a temporary 
    # $self->{ PREPARING } hash array in which each call to this method (up
    # through a potentially long base..base..base... chain) marks the fact
    # that it's being prepared.  If a method is invoked twice for the same 
    # renderer config then we have an inifinite loop.
    return $self->error_msg( infinite_loop => $name )
        if $self->{ PREPARING }->{ $name };
    local  $self->{ PREPARING }->{ $name } = 1;

    if ($base) {
        # Go fetch the configuration for the base, throwing an error if there
        # isn't a definition for it.  
        $base_config = $self->renderer_config($base)
            || return $self->bad_base_renderer($base);

        $self->debug_data("base config for $name^$base: ", $base_config) if DEBUG;

        # Merged configuration is a new hash containing base configuration
        # option with renderer-specific options over-riding them (applied after)
        $config = extend({ }, $base_config, $config);

        $self->debug_data("merged config for $base + $name: ", $config) if DEBUG;
    }
    else {
        # No base, in which case we just clone the master config to avoid 
        # polluting it with any changes we might make 
        $config = { %$config };
    }

    return $config;
}

sub prepare_path {
    my ($self, $path, $config) = @_;
    my $tdir  = $config->{ templates_dir  } ||  $self->TEMPLATES_DIR;
    my $pdir  = $config->{ "${path}_dir"  } ||  return;   # e.g. source_dir, library_dir (relative)
    my $dirs  = $config->{ "${path}_dirs" } ||= [ ];      # e.g. source_dirs (fixed)
    my $up    = $config->{ "${path}_up"   };              # e.g. source_up,  library_up
    my $space = $self->workspace;

    if ($pdir eq '<workspace_type>') {
        $self->debug("HOLY SHIT: a gruesome $pdir hack");
        $pdir = $space->type;
    }
    $self->debug("pdir: $pdir");

    # Add on the resolved directories for all workspace up the parent chain
    # if $up is set all the way up, or just the current one if not
    push(
        @$dirs,
        $up ? map { $_->absolute } $space->dirs_up($tdir, $pdir)
            : $space->dir($tdir, $pdir)->absolute
    );
    $self->debug_data("prepared path $path: ", $config->{"${path}_dirs"}) if DEBUG;

    return wantarray
        ? @$dirs
        :  $dirs;
}

sub prepare_dir {
    my ($self, $path, $config) = @_;
    my $name  = "${path}_dir";
    my $dir   = $config->{ $name } || return;   # e.g. output_dir
    my $wsdir = $config->{ $name } = $self->workspace->dir($dir);
    $self->debug_data("prepared dir $path: ", $wsdir) if DEBUG;
    return $wsdir;
}



#-----------------------------------------------------------------------------
# Error methods for the sake of cleanliness
#-----------------------------------------------------------------------------

sub no_renderer {
    shift->error_msg( missing => 'template renderer name' );
}

sub bad_renderer {
    shift->error_msg( invalid => 'template renderer', @_ );
}

sub bad_base_renderer {
    shift->error_msg( invalid => 'base template renderer', @_ );
}


#-----------------------------------------------------------------------------
# Cleanup methods.  We aggressively cache template renderers and they 
# aggressively cache compiled templates for the sake of efficiency.  
# We may also have circular references between the templates component,
# the template engines, the current workspace and parent project (both of 
# which are provides as variable references to the templates).  For this 
# reason, we explicitly call the destroy() method on each template renderer
# when the component is destroyed.
#-----------------------------------------------------------------------------

sub destroy_renderers {
    my $self      = shift;
    my $renderers = delete $self->{ renderers };
    foreach my $renderer (values %$renderers) {
        $renderer->destroy if $renderer;
    }
    %$renderers = ( );
}

sub destroy {
    my $self = shift;
    $self->destroy_renderers;
    $self->SUPER::destroy;
}

1;

__END__
==


sub init_renderer {
    my ($self, $config) = @_;
    my $renderer = $config->{ renderer } 
        || $self->RENDERER;

    class($renderer)->load;

    $self->{ renderer } = $renderer->new($config);
}

sub render {
    shift->renderer->render(@_);
}


sub template_file {
    shift->vfs->file(@_);
}

1;
