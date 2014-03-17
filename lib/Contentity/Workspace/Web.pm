package Contentity::Workspace::Web;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Workspace',
    utils     => 'resolve_uri split_to_list Colour',
    constants => 'SLASH HASH VHOST_FILE',
    constant  => {
        BUILDER   => 'builder',
        COLOURS   => 'colours',
        DOMAINS   => 'domains',
        FONTS     => 'fonts',
        PLACK     => 'plack',
        RGB       => 'rgb',
        ROUTES    => 'routes',
        RESOURCES => 'resources',
        SCAFFOLD  => 'scafffold',
        SITEMAP   => 'sitemap',
        TEMPLATES => 'templates',
        URLS      => 'urls',
    },
    messages => {
        bad_col_rgb => 'Invalid RGB colour name specified for %s: %s',
        bad_col_dot => 'Invalid colour method for %s: .%s',
        bad_col_val => 'Invalid colour value for %s: %s',
    };


#-----------------------------------------------------------------------------
# templates
#-----------------------------------------------------------------------------

sub templates {
    shift->component(TEMPLATES, @_);
}

sub renderer {
    shift->templates->renderer(@_);
}


#-----------------------------------------------------------------------------
# scaffold component generates configuration files, etc.
#-----------------------------------------------------------------------------

sub scaffold {
    shift->component(SCAFFOLD, @_);
}


#-----------------------------------------------------------------------------
# builder component pre-renders static content for a production run
#-----------------------------------------------------------------------------

sub builder {
    shift->component(BUILDER, @_);
}


#------------------------------------------------------------------------
# domains
#------------------------------------------------------------------------

sub domains {
    shift->component(DOMAINS, @_);
}

sub domain_name {
    shift->domains->name;
}

sub domain_names {
    shift->domains->names;
}

sub domain_aliases {
    shift->domains->aliases;
}

sub server_domains {
    shift->config('server.domains') || [ ];
}



#-----------------------------------------------------------------------------
# resources are local directories containing images, etc., that are accessible
# directly via a web server URL.
#-----------------------------------------------------------------------------

sub resources {
    my $self = shift;
    return  $self->{ resources }
        ||= $self->inherit_resources;
}

sub resource_list {
    my $self = shift;
    return $self->{ resource_list }
        ||= $self->inherit_resource_list;
}

sub inherit_resources {
    my $self      = shift;
    my $parent    = $self->parent;
    my $resources = { };

    # parent resources first
    if ($parent) {
        my $inherit = $parent->resources;
        while (my ($urn, $resource) = each %$inherit) {
            $resources->{ $urn } = $resource;
        }
    }

    # then merge in any local resources
    return $self->fix_resources($resources);
}

sub fix_resources {
    my $self      = shift;
    my $fixed     = shift || { };
    my $resources = $self->config(RESOURCES) || return $fixed;
    my $purn      = $self->urn;

    $self->debug_data("local resources: ", $resources) if DEBUG;

    while (my ($key, $resource) = each %$resources) {
        my  $urn  = $resource->{ urn       } ||= $key;
        my  $uri  = $resource->{ uri       } ||= $urn;
        my  $file = $resource->{ file      };
        my  $dir  = $resource->{ directory };
        my  $purn = resolve_uri($purn, $urn);
        my  $url  = resolve_uri(SLASH, $uri);
            $url .= SLASH 
                unless $file 
                    || $url =~ /\/$/;

        # Ugh!  Big fat mess!  Must add local (e.g. /css/) and also explicit
        # name (e.g. /cog/css/) for sites to inherit.  Needs cleaning up.
        my  $purl = resolve_uri(SLASH, $purn);
            $purl.= SLASH 
                unless $file 
                    || $purl =~ /\/$/;

        if ($file) {
            $resource->{ file } = $self->file($file);
        }
        elsif ($dir) {
            $resource->{ directory } = $self->dir($dir);
            $self->debug("set for $urn, $dir => $resource->{ directory }") if DEBUG;
        }
        else {
            $resource->{ directory } = $self->dir( resources => $urn );
            $self->debug("no directory for $urn, defaulting to $resource->{ directory }") if DEBUG;
        }

        my $loc = $resource->{ file } || ($resource->{ directory } . SLASH);

        $self->dbg("$key: [$purn] + $urn => $uri") if DEBUG;

        $fixed->{ $urn } = {
            %$resource,
            url      => $url,
            location => $loc,
        };
        $fixed->{ $purn } = {
            %$resource,
            url      => $purl,
            location => $loc,
        }
    }

    $self->debug_data("combined fixed resources: ", $fixed) if DEBUG;

    return $fixed;
}

sub inherit_resource_list {
    my $self      = shift;
    my $resources = $self->resources;

    # Schwartzian transform to sort resources, see resource_sort_sig() below
    my $list = [
        map     { $_->[1] }
        sort    { $a->[0] cmp $b->[0] }
        map     { [ $self->resource_sort_sig($_), $_ ] }
        values  %$resources
    ];

    $self->debug_data("inherited resource list: ", $list) if DEBUG;

    return $list;
}

sub resource_sort_sig {
    my ($self, $resource) = @_;
    # We want to sort directories before files, and then those resources with 
    # longer paths (in terms of slash-separated elements) first, and then 
    # alphanumerically within resources of the same path length.  So we create
    # a comparison string that starts with 'file' or 'diry' (the latter sorts 
    # before the former), then has the number of path segments subtracted
    # from a suitably large number (e.g. 20) so that longer paths have lower
    # number (and thus sort first).  Finally, we append each path segment 
    # padded to a fixed width.  e.g "diry:18:cog         :images      "
    my $url  = $resource->{ url  };
    my $type = $resource->{ file } ? 'file' : 'diry';
    my @bits = grep { length $_ } split(SLASH, $url);
    my $n    = sprintf("%02d", 20 - scalar @bits);       # longest first, alphanumberical sort for rest
    my $sig  = join(':', $type, $n, map { sprintf("%-12s", $_) } @bits);
    $self->debug("$url => [", join('], [', @bits), "] => [$sig]") if DEBUG;
    return $sig;
}


#-----------------------------------------------------------------------------
# RGB colours
# TODO: make this a component
#-----------------------------------------------------------------------------

sub rgb {
    my $self = shift;
    return  $self->{ rgb }
        //= $self->load_rgb;
}

sub load_rgb {
    my $self = shift;
    my $rgb  = $self->config(RGB) || return;
    foreach my $key (keys %$rgb) {
        $rgb->{ $key } = Colour($rgb->{ $key });
    }
    return $rgb;
}

sub colours {
    my $self = shift;
    return  $self->{ colours }
        //= $self->load_colours;
}

sub load_colours {
    my $self = shift;
    my $cols = $self->config(COLOURS) || return;
    my $rgb  = $self->rgb;
    return $self->prepare_colours($cols, $rgb);
}

sub prepare_colours {
    my $self = shift;
    my $cols = shift || $self->config(COLOURS) || return;
    my $rgb  = shift || $self->rgb;
    my ($key, $value, $name, $ref, $dots, $col, $bit, @bits);

    foreach $key (keys %$cols) {
        $value = $cols->{ $key };
        $ref   = ref $value;

        $self->debug("$key => $value") if DEBUG;

        if ($ref && $ref eq HASH) {
            # colours can have nested hash arrays, e.g. col.button.error
            $col = $self->prepare_colours($value);
        }
        elsif ($value =~ /^(\w+)(?:\.(.*))?/) {
            # colours can have names that refer to RGB entries, they may also 
            # have a dotted part after the name, e.g. red.lighter
            $self->debug("colour ref: [$1] [$2]") if DEBUG;
            $name = $1;
            $dots = $2;
            $col  = $rgb->{ $name }
                || return $self->error_msg( bad_col_rgb => $key => $name  );

            if (length $dots) {
                @bits = split(/\./, $dots);
                $self->debug("dots: [$dots] => [", join('] [', @bits), ']') if DEBUG;
                while (@bits) {
                    $bit = shift (@bits);
                    $col = $col->try->$bit
                        || return $self->error_msg( bad_col_dot => $key => $name => $bit );
                    $self->debug(".$bit => $col") if DEBUG;
                }
            }
        }
        else {
            # otherwise we assume they're new colour definitions
            $self->debug("colour val: $value") if DEBUG;
            $col = Colour->try->new($value)
                || return $self->error_msg( bad_col_val => $key => $value );
        }

        $self->debug(" => $col") if DEBUG;
        $cols->{ $key } = $col;
    }

    return $cols;
}


#-----------------------------------------------------------------------------
# Font stacks
#-----------------------------------------------------------------------------

sub fonts {
    my $self = shift;
    return  $self->{ fonts }
        ||= $self->config(FONTS);
}

sub font {
    my $self  = shift;
    my $fonts = $self->fonts;
    my $name  = shift || return $fonts;
    return $fonts->{ $name }
        || $self->decline_msg( invalid => font => $name );
}


#-----------------------------------------------------------------------------
# URLs - mapping simple names to URLs, e.g. scheme_info => /scheme/:id/info
#-----------------------------------------------------------------------------

sub urls {
    my $self = shift;
    return  $self->{ urls }
        ||= $self->config(URLS);
}

sub url {
    my $self = shift;
    my $urls = $self->urls;
    my $name = shift || return $urls;
    return $urls->{ $name }
        || $self->decline_msg( invalid => url => $name );
}

#-----------------------------------------------------------------------------
# sitemap - page metadata
#-----------------------------------------------------------------------------

sub sitemap {
    shift->component(SITEMAP, @_);
}

sub page {
    shift->sitemap->page(@_);
}

sub menu {
    shift->sitemap->menu(@_);
}

#-----------------------------------------------------------------------------
# URL routing, e.g. from /scheme/:id/info to get the correct metadata
#-----------------------------------------------------------------------------

sub routes {
    shift->component(ROUTES, @_);
}

sub router {
    shift->routes->router;
}

sub match_route {
    shift->router->match(@_);
}

sub add_route {
    shift->router->add_route(@_);
}

#-----------------------------------------------------------------------------
# Plack
#-----------------------------------------------------------------------------

sub plack {
    shift->component(PLACK, @_);
}

sub plack_app {
    shift->plack->app;
}

#-----------------------------------------------------------------------------
# Other aliases
#-----------------------------------------------------------------------------

sub cog_server {
    shift->config('cog_js')->{ server };
}



#-----------------------------------------------------------------------------
# Sites are enable or disabled by creating or removing a symlink from the 
# project etc/vhosts directory to the site's etc/vhost.conf
#-----------------------------------------------------------------------------

sub enabled {
    shift->project_vhosts_file_exists
        ? 1 : 0;
}

sub disabled {
    my $self = shift;
    return $self->enabled
        ? 0 : 1;
}

sub enableable {
    my $self = shift;
    return $self->disabled 
        && $self->vhost_file_exists;
}


sub enable {
    my $self = shift;
    my $file = $self->vhost_file;
    my $link = $self->project_vhosts_file;
    $self->debug("enabling site with symlink from $link to $file") if DEBUG;
    # note seemingly backwards args: link(X,Y) is like copy(X,Y) but it 
    # copies a link of X instead of the actual file and puts it at Y.  
    # So we end up with the link pointing BACK from Y to X. 
    symlink($file->absolute, $link->absolute);
}

sub disable {
    my $self = shift;
    my $link = $self->project_vhosts_file;
    $self->debug("disabling site by removing $link") if DEBUG;
    $link->delete;
}

sub vhost_file {
    my $self = shift;
    $self->file( etc => $self->VHOST_FILE );
}

sub vhost_file_exists {
    shift->vhost_file->exists
        ? 1 : 0;
}

sub project_vhosts_file {
    my $self = shift;
    $self->project->vhosts_file( $self->uri );
}

sub project_vhosts_file_exists {
    shift->project_vhosts_file->exists;
}


1;

