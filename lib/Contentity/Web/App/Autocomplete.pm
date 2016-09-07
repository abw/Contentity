package Contentity::Web::App::Autocomplete;

use Contentity::Class
    version   => 0.02,
    debug     => 0,
    base      => 'Contentity::Web::App',
    utils     => 'split_to_hash',
    accessors => 'tables';


#-----------------------------------------------------------------------------
# Initialisation
#-----------------------------------------------------------------------------

sub init_app {
    my ($self, $config) = @_;
    $self->{ tables  } = split_to_hash( $config->{ tables  } );
    $self->{ mapping } = split_to_hash( $config->{ mapping } );
    return $self;
}


#-----------------------------------------------------------------------------
# Default handler takes next path element, checks that it's a valid table type
# and then calls the autocomplete() method on the corresponding table object.
# e.g.
#   /autocomplete/place?starting=Kings
#-----------------------------------------------------------------------------

sub default_action {
    my $self    = shift;
    my $type    = $self->path->next             || return $self->error_msg( missing => 'data type' );
    my $table   = $self->{ tables }->{ $type }  || return $self->error_msg( invalid => 'data type' => $type );
    my $mapping = $self->{ mapping }->{ $type } || { };
    my $tname   = $mapping->{ table  } || $table;
    my $method  = $mapping->{ method } || 'autocomplete';
    my $results = $self->model->table($tname)->$method($self->params);
    return $self->send_json($results);
}

#-----------------------------------------------------------------------------
# Handler for testing autocomplete
# See templates/webapp/autocomplete/test.html
#-----------------------------------------------------------------------------

sub test_action {
    shift->present('test');
}


#-----------------------------------------------------------------------------
# Misc methods
#-----------------------------------------------------------------------------

sub table_names {
    my $self   = shift;
    my $tables = $self->tables;
    return [ sort keys %$tables ];
}

1;

=head1 NAME

Contentity::Web::App::Autocomplete - web application for serving autocomplete data

=head1 DESCRIPTION

This module implements a web application for serving data to an autocomplete
widget.

=head1 DEPLOYMENT

The web application can be added to a web site by defining a location (URL base)
for it in the C<config/locations.yaml> file for a web site.  For example, to
bind it to the C</autocomplete> URL, add the following entry to the
C<config/locations.yaml> file:

    /autocomplete:
        app: autocomplete

The internal Contentity URI for this application (i.e. the value specified for C<app>)
in the C<config/locations.yaml> file) is C<autocomplete>.  This is automatically
mapped to the C<Contentity::Web::App::Autocomplete> module by the web application framework.

Then point your browser at C</autocomplete/test>.

=head1 CONFIGURATION

The app can be configured via a F<config/apps/autocomplete.yaml> file.

    tables:
      - activities
      - markets
      - places
      - realms
      - schemes
      - agents
      - owners

    mapping:
      agents:
        table:  companies
        method: autocomplete_agents

      owners:
        table:  companies
        method: autocomplete_owners

=head2 CONFIGURATION OPTIONS

The following configuration options can be defined.

=head3 tables

The C<tables> section is a simple list of all the tables (using their plural
collective names, e.g. C<markets> rather than C<market>) that the app is
permitted to autocomplete from.  These are mapped to URLs that the application
will serve.  For example, if the app is running at the C</autocomplete> location
then it will provide URLs of C</autocomplete/activities>,
C</autocomplete/markets>, C</autocomplete/places> and so on.

Each database table object defines a simple C<autocomplete()> method.  In most
cases this in inherited from the L<Contentity::Database::Table> base class module. Note
that this default method will only Do The Right Thing for tables that have a
C<name> field for it to match against.  A more specific autocomplete method may
need to be written (or adapted) for tables that don't have a C<name> field or
want to autocomplete against a composite field (e.g. matching a scheme by name
or town).

=head3 mapping

In some cases there isn't a simple mapping to an C<autocomplete()> method.  For
examples, the autocomplete for agents and owners requires the C<autocomplete_agents()>
and <Cautocomplete_owners()> methods to be called on the C<companies> table
(C<Contentity::Database::Table::Companies>), respectively.  The C<mapping> section
allows you to specify these exceptions.

=head1 API SERVICES

Each table specified in the C<tables> configuration will have an autocomplete
URL of the form C</autocomplete/&lt;tablename&gt> (assuming that the base
location for the application is C</autocomplete>).

The following are some examples of typical API services provided, but obviously
it all depends on what C<tables> you have specified in your site configuration.

=head2 /autocomplete/places

=head2 /autocomplete/schemes

=head2 /autocomplete/agents

=head2 /autocomplete/owners

=head1 API REQUEST

The service is invoked via HTTP request and returns the data as a JSON response.
The requests should contain one (and only one) of the following parameters:

=head2 name

An exact name to match.

=head2 starting

Match all names starting with this string.

=head2 containing

Match all names containing this string.

=head1 ACTION METHODS

The following methods are action handlers for the above services.

=head2 default_action()

This is the default request handler.  It looks at the next item in the URL
path and attempts to map it to a table.  It then calls the C<autocomplete()>
method on that table (or whatever alternate mapping rules are defined in the
C<mapping> configuration section).

=head2 test_action()

This renders the C<templates/webapp/autocomplete/test.html> page (which can
be inherited or copied from the C<cog> site).  This displays a working
autocomplete widget for each table defined in the C<tables> configuration.

=head1 INTERNAL METHODS

=head2 init_app()

This method is called once the first time the application is used.  It parses
the C<tables> and C<mapping> configuration items and stores them internally.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Web::App>

=cut
