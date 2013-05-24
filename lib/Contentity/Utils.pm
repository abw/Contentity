package Contentity::Utils;

use warnings            qw( FATAL utf8 );
use open                qw< :std :utf8 >;
use Carp;
use Badger::Debug       'debug_caller';
use Badger::Filesystem  'File';
use Badger::Timestamp   'TIMESTAMP Timestamp Now';
use Badger::URL         'URL';
use Badger::Utils       'params';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Utils',
    constants => 'ARRAY HASH DELIMITER BLANK SPACE :timestamp :date_formats',
    codecs    => 'html',
    exports   => {
        any => q{
            Timestamp Now URL File 
            debug_caller 
            list_each split_to_list 
            hash_each extend
            join_uri resolve_uri uri_safe
            self_key self_keys
            H html_elem html_attrs data_attrs
            datestamp today format_date
            find_program prompt confirm 
        }
    };

#-----------------------------------------------------------------------------
# List utilities
#-----------------------------------------------------------------------------

sub list_each {
    my ($list, $fn) = @_;
    my $n = 0;

    for (@$list) {
        $fn->($list, $n++, $_);
    }

    return $list;
}

sub split_to_list {
    my $list = shift;
    $list = [ split(DELIMITER, $list) ]
        unless ref $list eq ARRAY;
    return $list;
}




#-----------------------------------------------------------------------------
# Hash utilities
#-----------------------------------------------------------------------------

sub hash_each {
    my ($hash, $fn) = @_;

    while (my ($key, $value) = each %$hash) {
        $fn->($hash, $key, $value);
    }

    return $hash;
}


sub extend {
    my $hash = shift;
    my $more;

    while (@_) {
        if (! $_[0]) {
            # ignore undefined/false values
            shift;
            next;
        }
        elsif (ref $_[0] eq HASH) {
            $more = shift;
        }
        else {
            $more = params(@_);
            @_    = ();
        }
        @$hash{ keys %$more } = values %$more;
    }
    
    return $hash;
}


#-----------------------------------------------------------------------------
# URI utilities
#-----------------------------------------------------------------------------

sub join_uri {
    my $uri = join('/', @_);
    $uri =~ s{/+}{/}g;
    return $uri;
}


sub resolve_uri {
    my $base = shift;
    my $rel  = join_uri(@_);
    return ($rel =~ m{^/})
        ? $rel
        : join_uri($base, $rel);
}

sub uri_safe {
    my $text = join('', @_);
    for ($text) {
        s/['"]//g;          # remove apostrophes, etc, so "Andy's Example" is "andys_example"
        s/\s*&\s*/ and /g;  # change '&' to 'and'
        s/^\W+//;           # remove leading non-word characters
        s/\W+$//;           # remove any trailing ones too
        s/[^\w\.]+/-/g;     # convert all other non-word (or dot) sequences to -
    }
    return $text;
}


#-----------------------------------------------------------------------------
# Parameter handling functions
#-----------------------------------------------------------------------------

sub self_key {
    my $key  = shift;
    my $self = shift;
    my $args = key_args($self, $key, @_);
    return ($self, $args->{ $key });
}


sub self_keys {
    my $names  = shift;
    my $self   = shift;
    my ($params, @values);
    
    $names = [ split(DELIMITER, $names) ]
        unless ref $names eq ARRAY;

    if (@_ == 1 && ref $_[0] eq HASH) {
        # got a single hash reference of named parameters
        $params = shift;
    }
    elsif (@_ == @$names) {
        # got exactly the right number of positional arguments
        $params = {
            map { $_ => shift }
            @$names
        };
    }
    else {
        # otherwise we got a list of named parameters
        $params = { @_ };
    }
        
    foreach my $name (@$names) {
        return $self->error_msg( missing => $name )
            unless defined $params->{ $name };
        push(@values, $params->{ $name });
    }

    return $self, @values;
}


#-----------------------------------------------------------------------------
# HTML generation
#-----------------------------------------------------------------------------

sub html_elem {
    my $name  = shift;
    my $attrs = @_ && ref $_[0] eq HASH ? shift : { };
    my $body  = ($name =~ s/:(.*)//)
              ? $1
              : join(
                    BLANK, 
                    map { ref $_ eq ARRAY ? html_elem(@$_) : $_ }
                    @_ 
                );

    $name  = html_name($name, $attrs);
    $attrs = %$attrs ? html_attrs($attrs) : BLANK;

    return qq{<$name$attrs}
        . ($body
            ? qq{>$body</$name>}
            : q{ />});
}

sub html_name {
    my ($name, $attrs) = @_;
    my @classes = ($attrs->{ class });
    while ($name =~ s/\.([\w\-]+)//) {
        push(@classes, $1);
    }
    if (@classes > 1) {
        $attrs->{ class } = join(
            SPACE,
            grep { defined $_ }
            @classes
        );
    }
    if ($name =~ s/\#([\w\-]+)//) {
        $attrs->{ id } = $1;
    }
    if ($name =~ s/\[(.*)?\]//) {
        my $mores = [split(DELIMITER, $1)];
        foreach my $more (@$mores) {
            my ($key, $value) = split('=', $more);
#            warn "[$more] => [$key] [$value]"
            $attrs->{ $key } = $value;
        }
    }

    return $name;
}

sub html_attrs {
    my $attrs = params(@_);
    my @attrs = (
        map { $_ . '="' . encode_html($attrs->{$_}) . '"' }
        sort keys %$attrs
    );

    return @attrs
        ? ' ' . join(' ', @attrs)
        : '';
}

sub data_attrs {
    my $attrs = params(@_);
    my @attrs = (
        map { 'data-' . $_ . '="' . encode_html($attrs->{$_}) . '"' }
        grep { defined $attrs->{ $_ } }
        sort keys %$attrs
    );
    return @attrs
        ? ' ' . join(' ', @attrs)
        : '';
}


#-----------------------------------------------------------------------------
# Time and date handling
#-----------------------------------------------------------------------------

sub datestamp {
    my $date  = shift || return;

    return $date 
        if is_object(TIMESTAMP, $date);

    $date = $date.SPACE.NULL_TIME
        unless $date =~ /(\s|T)/;

    return Timestamp($date);
}


sub today {
    datestamp(Now->date);
}


sub format_date {
    my $date   = shift || return;
    my $format = shift || SHORT_DATE;
    my $stamp  = datestamp($date);
    my $output = $stamp->format($format);
    my $ord    = ordinate($stamp->day);

    # special hack to insert ordinal for day, e.g. 1st, 3rd, etc.
    $output =~ s/<ord>/$ord/g;

    return $output;
}




#-----------------------------------------------------------------------------
# Utilities for command line scripts
#-----------------------------------------------------------------------------

#------------------------------------------------------------------------
# find_program($program, $path)
#
# Look for a program specified as the first argument in one of the
# directories specified in the second argument (defaulting to @PATH if
# unspecified).  Both arguments can be single values or references to
# lists of multiple values.
#------------------------------------------------------------------------

sub find_program {
    my $progs = shift;
    my $path  = shift || do {
        use Config;
        [ split($Config{path_sep}, $ENV{PATH}) ]
    };

    $progs = [ $progs ] unless ref $progs eq 'ARRAY';
    $path  = [ $path  ] unless ref $path  eq 'ARRAY';

    foreach my $program (@$progs) {
        foreach my $dir (@$path) {
            my $file = File::Spec->catfile($dir, $program);
            return $file if ( -x $file );
        }
    }
}


sub prompt {
    my ($msg, $def, $yes) = @_;
    my $ans = '';
    $def = '' unless defined $def;

    print "$msg [$def] ";

    if ($yes) {    # accept default
        print "$def\n";
    }
    else {           # read user input
        chomp($ans = <STDIN>);
    }

    return length($ans) ? $ans : $def;
}

sub confirm {
    my $reply = prompt(@_);
    return $reply =~ /^y(es)?$/i;
}



#-----------------------------------------------------------------------------
# Aliases done at the end to avoid conflicts
#-----------------------------------------------------------------------------

{
    no warnings 'redefine';
    *H = \&html_elem;
}




1;

=head1 NAME

Contentity::Utils - various utility functions for Contentity

=head1 SYNOPSIS

    use Contentity::Utils 'Now';
    print Now;      # prints timestamp for current date/time

=head1 DESCRIPTION

This module is a subclass of the L<Badger::Utils> module.  It defines some
additional utility function specific to the Contentity modules.

=head1 EXPORTABLE FUNCTIONS

The following utility functions are defined in addition to those inherited
from L<Badger::Utils>.

=head2 File

Function for creating a file object, imported from L<Badger::Filesystem>.

=head2 Now

Function for returning a L<Badger::Timestamp> object representing the 
current date and time.  Imported from L<Badger::Timestamp>.

=head2 Timestamp

Function for creating a L<Badger::Timestamp> object. Imported from
L<Badger::Timestamp>.

=head2 URL

Function for creating a L<Badger::URL> object for representing and
manipulating a URL.  Imported from L<Badger::URL>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

=cut
