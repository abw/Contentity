package Contentity::Constants;

our (@status);

BEGIN {
    # all these upper case words are defined as constants for their lower
    # case eqivalent, e.g. ACTIVE => 'active'
    @status = qw( 
        ACTIVE INACTIVE
    );
}

use utf8;
use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Constants',
    import   => 'class',
    constant => {
        UTF8                => 'utf8',
        CONFIG_DIR          => 'config',
        CONFIG_FILE         => 'contentity',
        CONFIG_CODEC        => 'yaml',
        CONFIG_ENCODING     => 'utf8',
        CONFIG_EXTENSION    => undef,   # defaults to CONFIG_CODEC
        RESOURCES_DIR       => 'resources',
 
        # map the various constants defined above to lower case equivalents
        map { $_ => lc $_ }
        @status,
    },
    exports  => {
        tags => {
            status  => \@status,
            config  => 'CONFIG_DIR CONFIG_FILE CONFIG_CODEC 
                        CONFIG_EXTENSION CONFIG_ENCODING RESOURCES_DIR',
        },
        any         => 'UTF8',
    };

1;

=head1 NAME

Contentity::Constants - defines constants for Contentity

=head1 SYNOPSIS

    package Contentity::Constants 'CONFIG_FILE';
    
    print CONFIG_FILE;   # contentity.yaml

=head1 DESCRIPTION

This module is a subclass of the L<Badger::Constants> module.  It defines
various constants used in other Contentity module in addition to all
the constants inherited from the L<Badger::Constants> module.

=head1 CONSTANTS

=head2 CONFIG_MODULE

The name of the default configuration module: C<Contentity::Config>.

=head2 CONFIG_DIR

The name of the default directory containing configuration files: C<config>.

=head2 CONFIG_FILE

The name of the default configuration file relative to the configuration 
directory: C<contentity.yaml>.

=head2 CONFIG_CODEC

The default data encoding for configuration files: C<yaml>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

=cut
