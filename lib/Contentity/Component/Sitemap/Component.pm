package Contentity::Component::Sitemap::Component;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Component',
    utils       => 'weaken',
    accessors   => 'sitemap',
    auto_can    => 'auto_can';


sub init_component {
    my ($self, $config) = @_;
    my $name = $self->component;

    $self->debug(
        "$name component config: ", 
        $self->dump_data($config)
    ) if DEBUG;

    # store data specified to this component, either indexed by the component
    # name (e.g. 'site', 'page', etc) or using the generic 'data' key
    my $data = delete($config->{ $name })
            || delete($config->{ data  })
            || return $self->error_msg( missing => "$name data" );

    # store a (weakened) reference to the parent sitemap
    my $smap = delete($config->{ sitemap }) 
            || return $self->error_msg( missing => 'sitemap' );

    $self->{ data    } = $data;
    $self->{ sitemap } = $smap;

    weaken $self->{ sitemap };

    return $self;
}

#-----------------------------------------------------------------------------
# Various useful accessor methods
#-----------------------------------------------------------------------------

sub page {
    shift->sitemap->page(@_);
}

sub site {
    shift->sitemap->site;
}


#-----------------------------------------------------------------------------
# auto_can() method auto-generates methods to access site data items
#-----------------------------------------------------------------------------

# Hmm... I'm not sure if a regular AUTOLOAD method wouldn't serve better

sub auto_can {
    my ($self, $name) = @_;
    my $data = $self->{ data };

    # auto-generate a method to access any existing item in the data
    if (exists $data->{ $name }) {
        return sub {
            shift->{ data }->{ $name };
        }
    }

    return undef;
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    # This cleanup isn't strictly necessary thanks to the weakened sitemap 
    # reference, but it doesn't hurt to be overly cautious where circular 
    # references are concerned
    delete $self->{ data    };
    delete $self->{ sitemap };
    $self->debug($self->component, " is destroyed") if DEBUG;
}

sub DESTROY {
    shift->destroy;
}

1;

