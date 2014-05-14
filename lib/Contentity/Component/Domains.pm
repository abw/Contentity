package Contentity::Component::Domains;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    accessors   => 'names',
    constants   => 'ARRAY DOT';
#    accessors   => 'domains sites';


sub init_component {
    my ($self, $config) = @_;

    $self->debug_data(
        "Domains component init_component(): ", 
        $config
    ) if DEBUG;

    $self->init_domains($config);

    return $self;
}

sub name {
    my $self = shift;
    my $doms = $self->names || return;
    # The first domain name is assumed to be the main domain name
    return $doms->[0];
}

sub aliases {
    my $self = shift;
    my $doms = $self->names || return;
    my @tail = @$doms;
    # All domains but the first are assumed to be domain name aliases
    shift @tail;
    return \@tail;
}


sub init_domains {
    my ($self, $config) = @_;
    my $domains = $config->{ domains } || [ ];
    my $space   = $self->workspace;
    my $sdoms   = $space->server_domains;
    my $names   = $space->names;
    
    return $self->error_msg( invalid => domains => "$domains (not a list)" )
        unless ref $domains eq ARRAY;

    $domains = [ @$domains ];

    if (DEBUG) {
        $self->debug_data("server domains", $sdoms);
        $self->debug_data("site names", $names);
    }

    # add in server wildcard domains
    foreach my $domain (@$sdoms) {
        # remove any '*.' prefix from the server wildcard domain
        $domain =~ s/^\*\.//;

        foreach my $name (@$names) {
            push(@$domains, $name.DOT.$domain);
        }
    }

    $self->debug_data("generated domains: ", $domains) if DEBUG;

    #$self->init_domains($config);
    $self->{ names } = $domains;
}


sub local_server_domain {
    my $self  = shift;
    my $space = $self->workspace;
    my $sdoms = $space->server_domains;
    my $names = $space->names;
    my $sdom  = $sdoms->[0];
    my $name  = $names->[0];

    # server domain can be *.something.com
    $sdom =~ s/^\*\.//;

    return $name.DOT.$sdom;
}


1;

__END__


==
    my $domains = { };
    my $sites   = { };

    while (my ($domain, $spec) = each %$config) {
        $self->debug("[$domain] => ", $self->dump_data($spec)) if DEBUG;
        my $site = $spec->{ site };
        my $akas = $spec->{ aliases } ||= [ ];
        my $doms = $sites->{ $site }  ||= [ ];

        $spec->{ domain } = $domain;
        $domains->{ $domain } = $spec;
        push(@$doms, $domain);

        foreach my $alias (@$akas) {
            $domains->{ $alias } = $spec;
            push(@$doms, $alias);
        }
    }

    $self->{ domains } = $domains;
    $self->{ sites   } = $sites;

    $self->debug("Domains table ", $self->dump_data($domains)) if DEBUG;

    return $self;
}

sub domain {
    my $self    = shift;
    my $name    = shift || return $self->error_msg( missing => 'domain name' );
    my $domains = $self->domains;

    $self->debug(
        "looking for domain [$name] in ", 
        $self->dump_data($domains)
    ) if DEBUG;

    return $domains->{ $name }
        || $self->decline_msg( invalid => domain => $name );
}

sub site_domains {
    my $self  = shift;
    my $name  = shift || return $self->error_msg( missing => 'site name' );
    my $sites = $self->sites;

    $self->debug(
        "looking for site [$name] in ", 
        $self->dump_data($sites)
    ) if DEBUG;

    return $sites->{ $name }
        || $self->decline_msg( invalid => site => $name );
}


1;
