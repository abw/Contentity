package Contentity::Hub;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Hub Contentity::Base',
    utils     => 'blessed params',
    constants => 'HASH';


# This is a replacement for the construct() method in the Badger::Hub base 
# class.  It calls the new config() method to fetch the configuration data 
# for a component.
#
# At some point it should be pushed back upstream into Badger::Hub.

sub construct {
    my $self   = shift;
    my $name   = shift;
    my $config = $self->config($name, @_);

    $self->debug("$name module config: ", $self->dump_data($config)) if DEBUG;
    
    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $config->{ module }
        || return $self->error_msg( no_module => $name );

    # load the module
    class($module)->load;

    return $module->new($config);
}


# This replaces the config() method in Badger::Hub.  It's backwardly compatible
# in the sense that it returns the master config object or hash when called
# without any arguments. It provides additional functionality to resolve the
# configuration data for a named item with optional per-instance configuration
# parameters, e.g. $hub->config( widget => { name => 'example' } )

sub config {
    my $self   = shift->prototype;
    my $config = $self->{ config };     return $config unless @_;
    my $name   = shift;
    my $params = params(@_);
    my $defaults;
    my $method;

    if ($config && ref $config eq HASH) {
        # $self->{ config } can be a hash ref with a $name item
        $defaults = $config->{ $name };
    }
    elsif (blessed $config && ($method = $config->can($name))) {
        # $self->{ config } can be an object with a $name method which we call
        $defaults = $method->($config);
    }
    else {
        # no defaults
        $defaults = $self->project_config($name) || { };
    }

    return {
        %$defaults,
        %$params
    };
}

sub project_config {
    my $self = shift->prototype;
    my $name = shift;

    # avoid an infinite loop to fetch project config from the project
    return if $name eq 'project';

    # see if there's a project we can ask for configuration data
    my $project = $self->project || return;

    return $project->config($name);
}


1;
