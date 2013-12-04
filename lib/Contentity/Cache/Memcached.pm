package Contentity::Cache::Memcached;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Cache::Memcached Contentity::Base',
    utils   => 'Timestamp';


sub index_keys {
    my $self  = shift;
    my $index = $self->index;
    my @keys  = keys %$index;
    return wantarray
        ?  @keys
        : \@keys;
}

sub index {
    my $self  = shift;
    my @slabs = $self->slabs;
    my $index = { };

    foreach my $slab (@slabs) {
        $self->slab_index($slab, $index);
    }
    $self->debug("INDEX: ", $self->dump_data($index));

    return $index;
}

sub slabs {
    my $self  = shift;
    my $stats = $self->stats('items');
    my $hosts = $stats->{ hosts };
    my $slabs = { };

    while (my ($k, $v) = each %$hosts) {
        my $items = $v->{ items };
        my @items = grep { defined $_ && length $_ } split(/[\n\r]+/, $items);
        foreach my $item (@items) {
            next unless $item =~ /items:(\d+):/;
            $slabs->{ $1 } = $1;
        }
    }

    my @slabs = keys %$slabs;

    $self->debug("SLABS: ", join(', ', @slabs));

    return wantarray
        ?  @slabs
        : \@slabs;
}

sub slab_index {
    my $self  = shift;
    my $slab  = shift;
    my $index = shift || { };
    my $stats = $self->stats("cachedump $slab 0");
    my $hosts = $stats->{ hosts };

    while (my ($k, $v) = each %$hosts) {
        foreach my $stat (values %$v) {
            my @items = grep { defined $_ && length $_ } split(/[\n\r]+/, $stat);
            foreach my $item (@items) {
                next unless $item =~ /ITEM\s+(\S+)\s\[(\d+) b; (\d+) s\]/;
                my ($key, $bytes, $secs) = ($1, $2, $3);
                $self->debug("$key: $bytes bytes  $secs seconds");
                $index->{ $key } = {
                    bytes   => $bytes,
                    seconds => $secs,
                    expires => Timestamp($secs),
                };
            }
        }
    }

    return $index;
}

1;
