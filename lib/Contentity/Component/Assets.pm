package Contentity::Component::Assets;

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

    # if the directory doesn't exists then this workspace doesn't have any assets
    return $self->null_config unless $dir->exists;

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
    return $config unless @_;
    return $config->get($uri);
}

1;
