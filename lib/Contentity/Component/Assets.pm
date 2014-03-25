package Contentity::Component::Assets;

# deprecated - moving assets configuration back under config directory for the
# sake of caching.
use Carp 'confess';
confess __PACKAGE__, " is deprecated - moved back into workspace";

use Contentity::Config;
use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'class',
    #accessors => 'config',
    constants => 'FALSE SLASH',
    constant  => {
        ASSETS        => 'assets',
        CONFIG_MODULE => 'Contentity::Config',
    };



sub init_component {
    my ($self, $config) = @_;

    $self->debug_data( assets => $config ) if DEBUG;

    $self->init_config($config);

    return $self;
}

sub init_config {
    my ($self, $config) = @_;
    my $space   = $self->workspace;
    my $parent  = $space->parent;
    my $dir     = $space->directory(ASSETS);
    my $cache   = $space->config->cache;

    $self->debug("assets found config cache: $cache") if DEBUG;

    # if the directory doesn't exists then this workspace doesn't have any assets

    # AH! - this could be a problem....  it's all very well putting a dummy
    # config object in but it doesn't honour inheritance or handle caching
    unless ($dir->exists) {
        $self->warn("WARNING: dummy config module installed because $dir doesn't exist");
        return $self->null_config;
    }

    my $module  = delete $config->{ config_module } ||  $self->CONFIG_MODULE;
    my $pconfig = $parent && $parent->assets->config;

    # load the configuration module
    class($module)->load;

    # config directory
    $self->{ config_dir } = $dir;

    # config directory manager
    $self->{ config } = $module->new(
        directory => $dir,
        parent    => $pconfig,
        dir_tree  => FALSE,
        cache     => ($cache || undef),
    #   schemas   => $schemas,
    );

    return $self;
}

sub null_config {
    my $self = shift;
    $self->{ config } = Badger::Config->new;
}

sub config {
    my $self   = shift;
    my $uri    = join(SLASH, @_);
    my $config = $self->{ config };
    $self->debug("looking for asset config: $uri via $config (cache: $config->{cache})") if DEBUG;
    return $config unless @_;
    return $config->get($uri);
}

1;
