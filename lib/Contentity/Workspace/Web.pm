package Contentity::Workspace::Web;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Workspace',
    utils     => 'join_uri resolve_uri split_to_list',
    constants => ':components :deployment SLASH HASH STATIC DYNAMIC VHOST_FILE';


#------------------------------------------------------------------------
# assets are things like forms, lists, etc., that get loaded on demand
#------------------------------------------------------------------------

sub asset_config {
    shift->config(
        join_uri(@_)
    );
}


#------------------------------------------------------------------------
# apps are web applications
#------------------------------------------------------------------------

sub apps {
    shift->component(APPS, @_);
}

sub app {
    shift->apps->app(@_);
}

#-----------------------------------------------------------------------------
# middlewares wrap around apps, e.g. for serving resources, error pages, etc
#-----------------------------------------------------------------------------

sub middlewares {
    shift->component(MIDDLEWARES, @_);
}

sub middleware {
    shift->middlewares->middleware(@_);
}


#-----------------------------------------------------------------------------
# context provides a temporary worker for request/response handling
#-----------------------------------------------------------------------------

sub context {
    shift->component(CONTEXT, @_);
}

sub request {
    shift->component(REQUEST, @_);
}

sub response {
    shift->component(RESPONSE, @_);
}


#-----------------------------------------------------------------------------
# content types for requests and responses
#-----------------------------------------------------------------------------

sub content_types {
    shift->component(CONTENT_TYPES, @_);
}

sub content_type {
    shift->content_types->content_type(@_);
}

sub file_content_type {
    shift->content_types->file_content_type(@_);
}


#-----------------------------------------------------------------------------
# databases
#-----------------------------------------------------------------------------

sub databases {
    shift->component(DATABASES, @_);
}

sub database {
    my $self = shift;
    my $name = shift
        || $self->config('database')
        || return $self->error_msg( missing => 'database' );
    $self->debug_data( database => $name ) if DEBUG;
    $self->databases->database($name);
}

sub model {
    shift->database->model;
}

sub table {
    shift->database->model->table(@_);
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
# forms
#-----------------------------------------------------------------------------

sub forms {
    shift->component(FORMS, @_);
}

sub form {
    shift->forms->form(@_);
}



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
# creator component creates the initial workspace
#-----------------------------------------------------------------------------

sub creator {
    shift->component(CREATOR, @_);
}

sub create {
    shift->creator(@_)->build;
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
    my $puri      = $self->uri;
    my $devmode   = $self->development;
    my $devapps   = { };

    $self->debug_data("local resources: ", $resources) if DEBUG;

    while (my ($key, $resource) = each %$resources) {
        $self->debug("RESOURCE: $purn $key") if DEBUG;
        my  $urn    = $resource->{ urn       } ||= $key;
        my  $uri    = $resource->{ uri       } ||= $urn;
        my  $type   = $resource->{ type      } ||= STATIC;
        my  $file   = $resource->{ file      };
        my  $dir    = $resource->{ directory };
        my  $devapp = $resource->{ dev_app   };
        my  $purn   = resolve_uri($purn, $urn);
        my  $url    = resolve_uri(SLASH, $uri);
            $url   .= SLASH
                unless $file
                    || $url =~ /\/$/;

        # Ugh!  Big fat mess!  Must add local (e.g. /css/) and also explicit
        # name (e.g. /cog/css/) for sites to inherit.  Needs cleaning up.
        my  $purl = resolve_uri(SLASH, $purn);
            $purl.= SLASH
                unless $file
                    || $purl =~ /\/$/;

        if ($file) {
            my $f = $resource->{ file } = $self->file($file);
            next unless $f->exists;
        }
        elsif ($dir) {
            my $d = $resource->{ directory } = $self->dir($dir);
            $self->debug("set for $urn, $dir => $resource->{ directory }") if DEBUG;
            next unless $d->exists;
        }
        else {
            my $d = $resource->{ directory } = $self->dir( resources => $urn );
            $self->debug("no directory for $urn, defaulting to $resource->{ directory }") if DEBUG;
            next unless $d->exists;
        }

        my $loc = $resource->{ file } || ($resource->{ directory } . SLASH);

        $self->dbg("$key: [purn:$purn] + [urn:$urn] => [uri:$uri]") if DEBUG;

        my $rel = {
            %$resource,
            uri      => $uri,
            url      => $url,
            type     => $type,
            space    => $puri,
            prefix   => $purn,
            location => $loc,
        };

        my $abs = {
            %$rel,
            url      => $purl,
        };

        # if we're in development mode then we can attach any specified dev_app
        # to handle this resource

        if ($devmode && $devapp) {
            my $base = SLASH . $urn;
            #$rel->{ app } = $devapps->{"$devapp-$base"} ||= $self->app($devapp, { uri_prefix => $base });
            #$abs->{ app } = $devapps->{"$devapp-$purn"} ||= $self->app($devapp, { uri_prefix => $base });
            $rel->{ app } = $abs->{ app } = $self->app($devapp, { uri_prefix => $base });
            #$abs->{ app } = $self->app($devapp, { uri_prefix => $base });

            if (DEBUG) {
                $self->debug("Created $devapp-$base application for $url via $base in developer mode: $rel->{ app }");
                $self->debug("Created $devapp-$purn application for $url via $base in developer mode: $abs->{ app }");
            }
        }

        #$self->debug("+++ [$urn => $url] + [$purn => $purl]");

        $fixed->{ $urn  } = $rel;
        $fixed->{ $purn } = $abs;
    }

    $self->debug_data("combined fixed resources: ", $fixed) if DEBUG;

    return $fixed;
}

sub inherit_resource_list {
    my $self      = shift;
    my $resources = $self->inherit_resources;
    my %seen;

    # Schwartzian transform to sort resources, see resource_sort_sig() below
    my $list = [
        map     { $_->[1] }
        sort    { $a->[0] cmp $b->[0] }
#        grep    { ! $seen{ $_->[1]->{ url } }++ }
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
# A skin is comprised of a set of RGB colours (e.g. red => #f00), mappings
# from UI components to colours (e.g. button.backgroud => red) and other
# style parameters.
#-----------------------------------------------------------------------------

sub skin {
    shift->component(SKIN);
}

sub rgb {
    shift->skin->rgb;
}

sub colours {
    shift->skin->colours;
}

sub styles {
    shift->skin->styles;
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

#sub plack {
#    shift->component(PLACK, @_);
#}

#sub plack_app {
#    shift->plack->app;
#}

#-----------------------------------------------------------------------------
# Other aliases
#-----------------------------------------------------------------------------

sub cog_server {
    shift->config('cog_js')->{ server };
}


#-----------------------------------------------------------------------------
# Deployment mode can be set to 'development' or 'production'.  In development
# mode we enable certain extra features, such as generating CSS dynamically,
# exposing directory indexes and so on.
#-----------------------------------------------------------------------------

sub deployment {
    my $self   = shift;
    my $deploy = $self->{ deployment }
             ||= $self->config('deployment')
             ||  $self->project->config('server.deployment')
             ||  PRODUCTION;
    return @_
        ? $deploy eq $_[0]
        : $deploy;
}

sub development {
    shift->deployment(DEVELOPMENT);
}

sub production {
    shift->deployment(PRODUCTION);
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
