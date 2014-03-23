package Contentity::Constants;

our (@components, @status, @mutate, @deployment);

BEGIN {
    # all these upper case words are defined as constants for their lower
    # case eqivalent, e.g. ACTIVE => 'active'
    @components = qw(
        APPS ASSETS BUILDER COLOURS CONTEXT CONTENT_TYPES DOMAINS EXTENSIONS
        FONTS FORMS MIDDLEWARES PLACK RGB ROUTES REQUEST RESPONSE RESOURCES
        SCAFFOLD SITEMAP TEMPLATES URLS
    );
    @status = qw(
        ACTIVE INACTIVE
    );
    @mutate = qw(
        STATIC DYNAMIC
    );
    @deployment = qw(
        DEVELOPMENT PRODUCTION
    );
}

use utf8;
use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Constants',
    import   => 'class',
    words    => 'HTTP_ACCEPT HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE',
    constant => {
        COMPONENT           => 'component',
        MIDDLEWARE          => 'middleware',

        # misc constants relating to directory/file handling
        INDEX_HTML          => 'index.html',
        DOT_HTML            => '.html',
        TEXT_HTML           => 'text/html',
        TEXT_PLAIN          => 'text/plain',

        # virtual host files
        VHOST_FILE          => 'vhost.conf',
        VHOST_EXTENSION     => 'conf',

        # Timestamp handling
        NULL_DATE           => '0000-00-00',
        NULL_TIME           => '00:00:00',
        NULL_STAMP          => '0000-00-00 00:00:00',
        LAST_TIME           => '23:59:59',

        # Date formats
        SHORT_DATE          => '%d-%b-%Y',
        MEDIUM_DATE         => '<ord> %B %Y',
        LONG_DATE           => '%A <ord> %B %Y',

        # Colour values
        RED_SLOT            => 0,
        GREEN_SLOT          => 1,
        BLUE_SLOT           => 2,
        HUE_SLOT            => 0,
        SAT_SLOT            => 1,
        VAL_SLOT            => 2,
        SCHEME_SLOT         => 3,
        BLACK               => '#000000',
        WHITE               => '#FFFFFF',

        # response codes
        OK                  => 200,
        FORBIDDEN           => 403,
        NOT_FOUND           => 404,

        # map the various constants defined above to lower case equivalents
        map { $_ => lc $_ }
        @components,
        @status,
        @mutate,
        @deployment,
    },
    exports  => {
        any  => 'COMPONENT MIDDLEWARE',
        tags => {
            status          => \@status,
            components      => \@components,
            mutate          => \@mutate,
            deployment      => \@deployment,
            timestamp       => 'NULL_DATE NULL_TIME NULL_STAMP LAST_TIME',
            date_formats    => 'SHORT_DATE MEDIUM_DATE LONG_DATE',
            colour_slots    => 'RED_SLOT GREEN_SLOT BLUE_SLOT HUE_SLOT SAT_SLOT VAL_SLOT SCHEME_SLOT',
            colours         => 'BLACK WHITE',
            html            => 'INDEX_HTML DOT_HTML TEXT_HTML TEXT_PLAIN',
            vhost           => 'VHOST_FILE VHOST_EXTENSION',
            http_accept     => 'HTTP_ACCEPT HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE',
            http_status     => 'OK FORBIDDEN NOT_FOUND',
        },
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

=head1 CONFIGURATION CONSTANTS

=head2 CONFIG_MODULE

The name of the default configuration module: C<Contentity::Config>.

=head2 CONFIG_DIR

The name of the default directory containing configuration files: C<config>.

=head2 CONFIG_FILE

The name of the default configuration file relative to the configuration
directory: C<contentity.yaml>.

=head2 CONFIG_CODEC

The default data encoding for configuration files: C<yaml>.

=head1 TIMESTAMP CONSTANTS

=head2 NULL_DATE

The NULL date: C<0000-00-00>

=head2 NULL_TIME

The NULL date: C<00:00:00>

=head2 NULL_STAMP

The NULL timestamp: C<0000-00-00 00:00:00>

=head2 LAST_TIME

The last second of the last hour of the day: C<23:59:59>

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
