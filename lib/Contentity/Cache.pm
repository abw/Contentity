package Contentity::Cache;

use Badger::Codecs;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    import    => 'class',
    utils     => 'resolve_uri Duration numlike',
    constants => 'SLASH',
    constant  => {
        CODEC        => 'storable',
        CODECS       => 'Badger::Codecs',
        CACHE_MODULE => 'Contentity::Cache::Memory',
        URI_FORMAT   => '%s:%s',
    };


sub init {
    my ($self, $config) = @_;
    my $class   =  $self->class;
    my $uri     =  delete $config->{ uri   };
    my $codec   =  delete $config->{ codec }
               ||  $class->any_var('CODEC')
               ||  $self->CODEC;
    my $module   = delete $config->{ module }
               ||  $class->any_var('CACHE_MODULE')
               ||  $self->CACHE_MODULE;
    my $expires  = $config->{ default_expires }
               ||= delete $config->{ expires };

    $self->debug("uri: $uri\ncodec: $codec\nmodule: $module") if DEBUG;

    class($module)->load;

    # we're lazy when it comes to long option names
    $config->{ default_expires } ||= $config->{ expires }
        if $config->{ expires };

    if ($expires) {
        $self->{ expires } = Duration($expires)->seconds;
    }

    $self->{ uri   } = $uri;
    $self->{ codec } = $self->CODECS->codec($codec);
    $self->{ cache } = $module->new($config);

    $self->debug("created new $module cache backend: $self->{ cache }") if DEBUG;

    return $self;
}


sub get {
    my ($self, $urn) = @_;
    my $uri  = $self->uri($urn);
    my $text = $self->{ cache }->get($uri) || return;
    $self->debug("$urn ($uri) fetched from cache") if DEBUG;
    return $self->{ codec }->decode($text);
}


sub set {
    my ($self, $urn, $data, $expires) = @_;
    my $uri  = $self->uri($urn);
    my $text = $self->{ codec }->encode($data);
    if ($expires) {
        $expires = Duration($expires)->seconds
            unless numlike $expires;
        $self->debug("expires in $expires seconds") if DEBUG;
    }
    else {
        $expires = $self->{ expires };
    }
    return $self->{ cache }->set($uri, $text, $expires);
}


sub uri {
    my $self = shift;
    my $path = resolve_uri(SLASH, @_);
    my $base = $self->{ uri } || return $path;
    return sprintf($self->URI_FORMAT, $base, $path);
}


1;

__END__

=head1 NAME

Contentity::Cache - wrapper around Cache::* modules with data encoding

=head1 SYNOPSIS

    use Contentity::Cache;
    
    my $cache = Contentity::Cache->new(
        # options for Contentity::Cache
        uri    => 'my:namespace',
        codec  => 'json',
        module => 'Cache::Memcached',

        # any other options for back-end cache module
        servers => [ ... ],
    );

    $cache->set(
        complex_data => {
            foo => 'bar',
            baz => [10, 20, 30],
        }
    );

    my $complex = $cache->get('complex_data');

=head1 DESCRIPTION

This module provides a simple wrapper around a C<Cache::*> compatible 
cache module.  

It uses L<Badger::Codecs> to automatically encode and decode data using a 
codec of your choice.  This allows data to be encoded using an open format
(e.g. JSON) that can be shared across servers using different programming
languages or versions of Perl.  The L<Storable> module which is hard-coded
into the L<Cache::Entry> module's C<freeze()> and C<thaw()> methods is not
suitable for either of these purposes.

It also reinstates the equivalent of the 'namespace' concept (originally in 
L<Cache::Cache> but removed in the more recent L<Cache> interface) via the 
L<uri> option.  This allows you to have multiple C<Contentity::Cache> objects
caching different sets of data via the same back-end cache (e.g. a 
L<Cache::Memcached> instance).

=head1 CONFIGURATION OPTIONS

The following configuration options can be specified when a 
C<Contentity::Cache> object is created.

=head2 codec

This can be used to specify the data codec that should be used to serialise
and deserialise data when storing and fetching from the back-end cache.  It
should be set to any valid coded recognised by L<Badger::Codecs>.  It defaults
to C<json>.

=head2 uri

If specified, this value will be added to all keys stored in and fetched from
the cache.  This can be useful when using shared memory caches (e.g. memcached).

The L<URI_FORMAT> defines an C<sprintf()> format that is used to combine the
base C<uri> and cache C<$key>.  The default value is C<%s:/%s>.  For example:

    my $cache = Contentity::Cache->new(
        uri => 'foo',
    );

The following method calls using C<bar> as a key will result in items named 
C<foo:/bar> being stored in and fetch from the back-end cache:

    $cache->store( bar => [10,20,30] );
    $cache->fetch('bar');

=head2 expires

This can be used to specify a default expiry time for items stored in the 
cache.  The C<$expires> parameter can be passed to L<store()> to over-ride it.

It should be specified as a number of seconds or a duration recognised by 
L<Badger::Duration>.

=head2 module

This should be used to specify the name of the backend C<Cache::*> module
that C<Contentity::Cache> should delegate to.  If unspecified it defaults 
to L<Contenty::Cache::Memory> which implements a simple memory cache.

Any other configuration options specified (exluding those listed here) will
be passed to the module constructor when the back-end object is created.

=head1 METHODS

The module inherits all methods from L<Contentity::Base> and L<Badger::Base>.
The following methods are also defined.

=head2 init($config)

Internal method handling the initialisation and configuration of the cache 
object(s).  This method is called automatically when a C<Contentity::Cache>
object is created via C<new()>.

=head2 get($key)

Fetch the data associated with L<$key>.  Returns a reference to the data or
C<undef> is the item is not in the cache. 

=head2 set($key, $data, $expires)

Store the C<$data> associated with L<$key>.  The optional C<$expires> argument
can be provided to set the expiry time.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
