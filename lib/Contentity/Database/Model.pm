package Contentity::Database::Model;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Database::Model Contentity::Database::Component',
    utils     => 'join_uri',
    accessors => 'ident',
    constants => 'PKG DOT',
    import    => 'class',
    constant  => {
        TABLE_BASE => 'Contentity::Database::Table',
        AUTOGEN    => '_autogen',
    };

# This is designed to be used as a mixin base class for the
# Contentity::Component::Database module.  The component is effectively
# the connector to a workspace.


sub init {
    my ($self, $config) = @_;

    # Replaces the init() method in Badger::Database::Model - we don't want
    # to pre-define tables and records, instead we want to load them from
    # the config/databases directory

    $self->{ hub } = $config->{ hub }
        || return $self->error_msg( missing => 'hub' );

    $self->{ engine } = $config->{ engine }
        || return $self->error_msg( missing => 'engine' );

    $self->{ ident } = $config->{ ident }
        || return $self->error_msg( missing => 'ident' );

    $self->{ table_base } = $config->{ table_base } || $self->TABLE_BASE;

    $self->debug("model connected to hub: $self->{ hub }") if DEBUG;
    $self->debug("model connected to engine: $self->{ engine }") if DEBUG;

    return $self;
}

#-----------------------------------------------------------------------------
# Tables are defined in YAML configuration files
#-----------------------------------------------------------------------------

sub table {
    my ($self, $name) = @_;
    return $self->{ table }->{ $name }
      ||=  $self->load_table($name);
}

sub load_table {
    my ($self, $name) = @_;
    my $config = $self->table_config($name);
    my $module = $config->{ table_module };
    my $throws = $self->table_throws($name);

    if ($module) {
        # if we've got the name of a module then we just need to load it
        $self->debug("Loading $name table module: $module") if DEBUG;
        class($module)->load->throws($throws);
    }
    else {
        # otherwise we create a subclass of the table_base class
        $module = $self->table_subclass($name);
        $self->debug("Creating table subclass for $name: $module") if DEBUG;
        class($module)
            ->base( $self->table_base )
            ->throws($throws);
    }

    local $config->{ engine } = $self->engine;
    local $config->{ model  } = $self;
    local $config->{ name } ||= $name;

    $self->debug_data("creating $module with config: ", $config) if DEBUG;

    return $module->new($config);
}

sub table_config {
    my ($self, $name) = @_;
    my $uri = $self->table_path($name);
    return $self->workspace->config($uri)
        || $self->error_msg( invalid => table => "$name ($uri)" );
}

sub table_names {
    my $self = shift;
    return [
        map { $_->basename }
        $self->workspace->config->dir( $self->table_path )->files
    ];
}

sub table_path {
    my $self = shift;
    return join_uri( databases => $self->ident => tables => @_ );
}

sub table_base {
    my $self = shift;
    return $self->{ table_base }
        || $self->TABLE_BASE;
}

sub table_throws {
    my $self = shift;
    return join( DOT, $self->ident, @_ );
}

sub table_subclass {
    my ($self, $name) = @_;

    # If the config doesn't specify an table_module then we generate a unique
    # subclass name from the table_base class with a unique
    # name based on the names of the database and table,
    #   e.g. Contentity::Database::Table::_autogen::cog::users
    return join(
        PKG,
        $self->table_base,
        AUTOGEN,
        $self->ident,
        $name
    );
}

sub has_table {
    my ($self, $name) = @_;
    my $table = $self->{ table }->{ $name };
    return $table if $table;
    # Bah! All this to avoid the error thrown by the table() method. We could
    # call it as $self->try->table($name) but then it discards any errors thrown
    # by syntax errors, etc., in the code.
    if ($self->workspace->config($self->table_path($name))) {
        return $self->table($name);
    }
}




1;
