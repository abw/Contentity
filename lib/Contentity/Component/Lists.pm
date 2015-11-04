package Contentity::Component::Lists;

use Contentity::Class
    version   => 0.03,
    debug     => 0,
    component => 'asset',
    asset     => 'list',
    utils     => 'extend id_safe Now',
    constant  => {
        SINGLETONS            => 0,
        PREPARE_METHOD_FORMAT => 'prepare_%s_list',
    };

our $CACHE = { };


#-----------------------------------------------------------------------------
# asset_config($name)
#
# Called by the base class asset component to load the data for a list.
#-----------------------------------------------------------------------------

sub asset_config {
    my ($self, $name) = @_;
    my $list;

    # have we got a cached copy?
    $list = $self->cache_fetch($name);
    return $list if $list;

    # look for a workspace configuration, e.g. in config/lists/XXX.yaml
    # or an internal method that prepares the list
    $list = $self->workspace->asset_config( $self->{ assets } => $name )
         || $self->prepare_method($name)
         || return;

    # save the list in the cache
    $self->cache_store($name, $list);

    $self->debug_data( "$name list config ($self->{ assets }/$name)" => $list ) if DEBUG;

    return $list;
}

sub prepare_method {
    my ($self, $name) = @_;
    my $method = sprintf($self->PREPARE_METHOD_FORMAT, id_safe($name));
    my $code   = $self->can($method) || return $self->decline_msg( invalid => "list prepare method", $method );
    return $self->$code($name);
}

sub prepare_asset {
    my ($self, $data) = @_;
    $self->debug_data( list => $data ) if DEBUG;
    return $data;
}


#-----------------------------------------------------------------------------
# Caching methods
#-----------------------------------------------------------------------------

sub cache_store {
    my ($self, $name, $list) = @_;
    my $ttl = $self->config('cache_ttl') || return $list;
    my $expiry = Now->adjust($ttl);
    $self->debug("$$ caching $name with expiry at $expiry") if DEBUG;
    $CACHE->{ $name } = [ $list, $expiry ];
    return $list;
}


sub cache_fetch {
    my ($self, $name) = @_;
    my $cached = $CACHE->{ $name } || return;
    my ($list, $expiry) = @$cached;

    if ($expiry->after(Now)) {
        $self->debug("$$ returning cached list for $name") if DEBUG;
    }
    else {
        $self->debug("$$ cached list for $name expired at $expiry") if DEBUG;
        delete $CACHE->{ $name };
        $list = undef;
    }

    return $list;
}



#-----------------------------------------------------------------------------
# internal methods of convenience
#-----------------------------------------------------------------------------

sub model {
    shift->workspace->model(@_);
}

sub table {
    shift->model->table(@_);
}

#-----------------------------------------------------------------------------
# Generic data loader method
#-----------------------------------------------------------------------------

sub load_table {
    my ($self, $table_name, $name_field, $id_field) = @_;

    return $self->table_records(
        $table_name,
        $self->table($table_name)->fetch_all,
        $name_field,
        $id_field,
    );
}

sub table_records {
    my $self       = shift;
    my $table_name = shift || return $self->error_msg( missing => 'table' );
    my $records    = shift || return $self->error_msg( missing => "$table_name records" );

    $self->debug("$$ constructing $table_name list") if DEBUG;

    return $self->records_data($records, @_);
}

sub records_field {
    my $self    = shift;
    my $records = shift || return; $self->error_msg( missing => 'records' );
    my $field   = shift || 'name';
    return [
        map { $_->$field }
        @$records
    ];
}

sub records_data {
    my $self        = shift;
    my $records     = shift || return $self->error_msg( missing => 'records' );
    my $name_field  = shift || 'name';
    my $value_field = shift || 'id';

    return [
        map {{
            name  => $_->$name_field,
            value => $_->$value_field,
        }}
        @$records
    ];
}

sub rows_data {
    my $self        = shift;
    my $records     = shift || return $self->error_msg( missing => 'records' );
    my $name_field  = shift || 'name';
    my $value_field = shift || 'id';

    return [
        map {{
            name  => $_->{ $name_field },
            value => $_->{ $value_field },
        }}
        @$records
    ];
}



1;
