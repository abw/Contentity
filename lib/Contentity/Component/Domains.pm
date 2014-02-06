package Contentity::Component::Domains;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    accessors   => 'domains sites';


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Domains component init_component(): ", 
        $self->dump_data($config)
    ) if DEBUG;

    $self->init_domains($config);
}


sub init_domains {
    my ($self, $config) = @_;
    my $domains = { };
    my $sites   = { };

    while (my ($domain, $spec) = each %$config) {
        #$self->debug("[$domain] => ", $self->dump_data($spec)) if DEBUG;
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
