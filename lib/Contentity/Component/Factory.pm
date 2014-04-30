package Contentity::Component::Factory;

use Contentity::Factory;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    component => 'asset',
    import    => 'class',
    utils     => 'self_params plural split_to_list permute_fragments',
    accessors => 'type factory',
    constants => 'SLASH',
    constant  => {
        FACTORY_TYPE    => undef,
        FACTORY_ITEM    => undef,
        FACTORY_PATH    => undef,
        FACTORY_MODULE  => undef,
        FACTORY_DEFAULT => undef,
        BASE_FACTORY    => 'Contentity::Factory',
        SINGLETONS      => 0,
    };


sub init_asset {
    my ($self, $config) = @_;
    $self->debug_data( factory => $config ) if DEBUG;
    $self->init_factory($config);
    return $self;
}

sub init_factory {
    my ($self, $config) = @_;

    my $module  = $config->{ factory_module  } || $self->FACTORY_MODULE;
    my $item    = $config->{ factory_item    } || $self->FACTORY_ITEM;
    my $type    = $config->{ factory_type    } || $self->FACTORY_TYPE || plural($item);
    my $path    = $config->{ factory_path    } || $config->{ path    } || $self->FACTORY_PATH;
    my $default = $config->{ factory_default } || $config->{ default } || $self->FACTORY_DEFAULT;
    my $modules = $config->{ $type           } || { };
    my $factory;

    if ($module) {
        $self->debug("Loading $module") if DEBUG;
        class($module)->load;
        $factory = $module->new;
    }
    else {
        return $self->error_msg( missing => 'factory_item' )
            unless $item;

        return $self->error_msg( missing => 'factory_path' )
            unless $path;

        $self->debug("creating factory object for [$item/$type] in [$path]") if DEBUG;
        $path = split_to_list($path);
        $path = [ map { permute_fragments($_) } @$path ];

        $modules->{ default } ||= $default;

        $factory = $self->BASE_FACTORY->new(
            item    => $item,
            items   => $type,
            path    => $path,
            #default => $default,
            $type   => $modules,
        );
    }

    $self->{ type    } = $type;
    $self->{ factory } = $factory;

    return $self;
}

sub prepare_asset {
    my ($self, $params) = self_params(@_);

    $self->debug_data( prepare_asset => $params) if DEBUG;

    # In the usual case the type of asset object we want to create is the
    # same as the component name/config file, e.g. the 'content' app corresponds
    # to Contentity::App::Content and can be loaded and instantiated via the
    # Contentity::Component::Apps factory module.  The asset configuration can
    # contain an entry indicating that a different object type should be used
    # instead, e.g. app_type for an 'app' asset, 'form_type' for a form, etc.
    my $config = $self->instance_config($params);
    my $urn    = $config->{ urn };
    my $asset  = $self->{ asset };
    my $type   = $params->{"${asset}_type"} || $urn;

    $self->debug_data(
        "creating app [$urn] [${asset}_type:$type] [$config->{uri}]",
        $config
    ) if DEBUG;

    return $self->factory->item($type, $config);
}

sub instance_config {
    my ($self, $data) = @_;
    return {
        workspace => $self->workspace,
        component => $self->{ asset },
        urn       => $data->{ urn },
        uri       => $self->{ asset }.SLASH.$data->{ urn },
        config    => $data,
    #   schema    => $config->{ schema };
    };
}

1;

=head1 NAME

Contentity::Component::Factory - factory module for loading and instantiating assets

=head1 DESCRIPTION

This module defines a base class for factory components that load and
instantiate other object.

It combines the functionality of L<Badger::Factory> (loading and instantiating
modules) with that of L<Contentity::Component::Asset> (finding and reading
workspace configuration files).

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Contentity::Component::Asset>,
L<Contentity::Component>,
L<Badger::Factory>.

=cut
