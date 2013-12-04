package Contentity::Sitemap;
die __PACKAGE__, " is deprecated\n";

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Workspace',
    constant    => {
        CONFIG_FILE    => 'sitemap',
        WORKSPACE_TYPE => 'site',
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workspace($config);
    $self->init_sitemap($config);
    return $self;
}

sub init_sitemap {
    my ($self, $config) = @_;
}

1;
