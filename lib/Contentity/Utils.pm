package Contentity::Utils;

use warnings            qw( FATAL utf8 );
use open                qw< :std :utf8 >;
use Carp;
use Badger::Rainbow     ANSI => 'cyan yellow';
use Badger::Debug       'debug_caller';
use Badger::Filesystem  'File Dir VFS';
use Badger::Timestamp   'TIMESTAMP Timestamp Now';
use Badger::URL         'URL';
use Badger::Utils       'params numlike is_object plural permute_fragments xprintf';
use Badger::Logic       'Logic';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Utils',
    constants => 'ARRAY HASH DELIMITER BLANK SPACE :timestamp :date_formats',
    codecs    => 'html',
    exports   => {
        any => q{
            Timestamp Now URL File Dir VFS Logic
            debug_caller 
            list_each split_to_list 
            hash_each extend
            join_uri resolve_uri uri_safe
            self_key self_keys
            H html_elem html_attrs data_attrs
            datestamp today format_date
            ordinal ordinate plurality inflect commas
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

# Assume HTML5 by default
our $HTML_TAG_END = '>';

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
            : $HTML_TAG_END);
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
# Word munging: pluralisation, inflection, etc.
#-----------------------------------------------------------------------------

our $ORDINALS = {
    ( map { $_ => 'st' } qw( 1 21 31 ) ),
    ( map { $_ => 'nd' } qw( 2 22 ) ),
    ( map { $_ => 'rd' } qw( 3 23 ) ),
};

sub ordinal {
    my $n = shift;
    die "Invalid number for ordinal(): $n"
        unless numlike $n;
    $n = 0+$n;
    return $ORDINALS->{ $n }
        || 'th';
}

sub ordinate {
    my $n = shift;
    $n = 0+$n;
    return $n . ordinal($n);
}

sub plurality {
    my $n     = shift || 0;
    my @items = map { permute_fragments($_) } 
                (@_ == 1 && ref $_[0] eq ARRAY)
                ? @{ $_[0] }
                : @_;

    # if the user specifies a single word then we pluralise it for them,
    # assuming that 0 items are plural, 1 is singular, and > 1 is plural
    if (@items == 1) {
        my $plural = plural($items[0]);
        unshift(@items, $plural);       # 0 whatevers
        push(@items, $plural);          # n whatevers (where n > 1)
    }

    die "$n is not a number\n" unless numlike $n;
    my $i     = $n > $#items ? $#items : $n;
    $i        = 0 if $i < 0;

    return $items[$i];
}


sub inflect {
    my $n = shift || 0;
    my $i = shift;
    my $f = shift || '%s %s';
    return xprintf(
        $f, ($n or 'No'), plurality($n, $i)
    );
}

sub commas {
    my $number = shift // '';
    my ($before, $after, @list);

    if ($number =~ / ^([\d,]+) (\. \d+ )? $/x ) {
        my ($before, $after) = ($1, $2);

        # sexeger!  It's faster to reverse the string, search
        # it from the front and then reverse the output than to
        # search it from the end, believe it nor not!
        $before = reverse $before;
        unshift(@list, scalar reverse $1)
        while ($before =~ /((.{3})|(.+))/g);

        $number = join(',', @list);
        $number .= $after 
            if defined $after;
    }
    return $number;
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
    my $defprompt = $def ? " [$def]" : "";

    print cyan($msg) . yellow($defprompt) . ' ';

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

The following utility functions are defined in addition to those inherited
from L<Badger::Utils>.

=head1 CONSTRUCTOR FUNCTIONS

These function serve to create instances of various utility objects, e.g.
files, timestamps, URLs, etc.

=head2 File

Function for creating a file object, imported from L<Badger::Filesystem>.

=head2 Logic

Function for returning a L<Badger::Logic> object for representing simple
logical assertions.

=head2 Now

Function for returning a L<Badger::Timestamp> object representing the 
current date and time.  Imported from L<Badger::Timestamp>.

=head2 Timestamp

Function for creating a L<Badger::Timestamp> object. Imported from
L<Badger::Timestamp>.

=head2 URL

Function for creating a L<Badger::URL> object for representing and
manipulating a URL.  Imported from L<Badger::URL>.

=head1 LIST UTILITY FUNCTIONS

These functions are provided for working with lists.

=head2 list_each($listref, $coderef)

Iterates over the items in the list reference passed as the first argument,
calling the code reference passed as the second for each.  The arguments
passed to C<$coderef> are C<($listref, $index, $item)>, where C<$listref> is
the reference to the list, C<$index> is the iteration index (starting at 0 
for the first item) and C<$item> is the item at that position in the list.

    list_each(
        $listref,
        sub {
            my ($listref, $index, $item) = @_;
            print "List item $index is $item\n";
        }
    );

=head2 split_to_list($text_or_list)

Splits a text string into a list of comma and/or whitespace delimited values.

    split_to_list('foo bar');   # returns ['foo', 'bar']

If the argument passed is already a reference to a list then it is returned
unmodified.

=head1 HASH UTILITY FUNCTIONS

These functions are provided for working with hash arrays.

=head2 hash_each($hashref, $coderef)

Iterates over the items in the hash array reference passed as the first 
argument, calling the code reference passed as the second for each.  The 
arguments passed to C<$coderef> are C<($hashref, $key, $value)>.

    hash_each(
        $hashref,
        sub {
            my ($hashref, $key, $value) = @_;
            print "Hash key $key is $value\n";
        }
    );

=head2 extend($target, $source1, $source2, key1 => value1, ...)

This function can be used to extend a hash array with the contents of one
or more hash arrays, or loose C<key =E<gt> value> pairs passed as arguments.

    my $target  = { foo => 10 };
    my $source1 = { bar => 20 };
    my $source2 = { baz => 30 };

    extend(
        $target,        # this gets extended...
        $source1,       #   ...with this
        $source2,       #   ...and this
        wam => 40,      #   ...and these
        bam => 50
    );

=head1 URI UTILITY METHODS

=head2 join_uri(frag1, frag2, etc)

Joins the elements of a URI passed as arguments into a single URI.

    use Contentity::Utils 'join_uri';
    print join_uri('/foo', 'bar');     # /foo/bar

=head2 resolve_uri(base, frag1, frag2, etc)

The first argument is a base URI.  The remaining argument(s) are joined 
(via L<join_uri()>) to construct a relative URI.  If the relative URI begins
with C</> then it is considered absolute and is returned unchanged.  Otherwise
it is appended to the base URI.

    use Contentity::Utils 'resolve_uri';
    print resolve_uri('/foo', 'bar/baz');     # /foo/bar/baz
    print resolve_uri('/foo', '/bar/baz');    # /bar/baz

=head2 uri_safe(text)

Converts C<$text> to a format safe to be used in a URI.

=head1 PARAMETER HANDLING UTILITY METHODS

=head2 self_key( key => @args )

Can be used in a method to extract the C<$self> reference and a mandatory
key parameter from the argument list.

    sub some_method_expecting_user_id {
        my ($self, $user_id) = self_key( user_id => @_ );
        $self->debug("Got user id: $user_id");
    }

Here the method can be called passing either a single C<user_id> argument,
a named parameter or a hash reference containing C<user_id>.

    $object->some_method_expecting_user_id(
        $uid                # single argument
    );
    $object->some_method_expecting_user_id(
        user_id => $uid     # named parameter
    );
    $object->some_method_expecting_user_id({
        user_id => $uid     # hash reference paramter
    });

An exception will be thrown if the expected key parameter is not provided.

=head2 self_keys( keys => @args )

Similar to L<self_key()> but for multiple keys.

    sub some_other_method {
        my ($self, $user_id, $order_id) = self_key( 
            'user_id order_id' => @_ 
        );
        $self->debug("Got user id: $user_id");
        $self->debug("Got order id: $order_id");
    }

=head1 HTML GENERATION FUNCTIONS

=head2 html_elem($name,$attrs,@content)

Generates an HTML element of C<$name> type with optional attributes provided
as a reference to a hash array as the second argument.  Any further arguments
are considered to be content for the element.  Otherwise an empty element is
created.

    use Contentity::Utils 'html_element';

    # empty element
    html_element('br');             # <br>

    # empty element with attributes
    html_element(                   # <img src="foo.gif">
        img => {
            src => 'foo.gif'
        }
    );

    # element with content
    html_element(
        i => 'Some italic text'
    );

    # element with attributes and content
    html_element(
        i => { class="important' }, 
        'Some italic text'
    );

    # element with attributes and lots of content
    html_element(
        i => { class="important' }, 
        'Some italic text. ',
        'Some more italic text. ',
        ('Lorem Ipsum... ') x 100
    );

The function supports various shortcuts via L<html_name()>.  e.g.

    html_element('br.clear');           # <br class="clear">
    html_element('h1#title', 'Hello');  # <h1 id="title">Hello</h1>

For generating nested elements, content elements can be specified by reference
to a list.

    html_element(
        'ul.menu',
        [ li => 'One'   ],
        [ li => 'Two'   ],
        [ li => 'Three' ],
    );

This function is also available via the C<H> alias for the sake of brevity.

    use Contentity::Utils 'H';

    H(
        'ul.menu',
        [ li => 'One'   ],
        [ li => 'Two'   ],
        [ li => 'Three' ],
    );

=head2 html_name($name, $attrs)

This function looks for any HTML element shortcuts included in C<$name>, 
removes them and sets the appropriate attributes in the C<$attrs> hash 
reference.

=head3 foo.bar

C<foo.bar> is equivalent toC<E<lt>foo class="bar"E<gt>>

=head3 foo#bar

C<foo#bar> is equivalent to C<E<lt>foo id="bar"E<gt>>.

=head3 foo[bar=baz]

C<foo[bar=baz]> is equivalent to C<E<lt>foo bar="baz"E<gt>>.

=head2 html_attrs(\%attrs)

Generates HTML attributes from a reference to a hash array or a list of 
named parameters.
    
    # hash reference
    my $attrs = {
        id    => 'foo',
        class => 'wibble',
    };
    html_attrs($attrs);

    # named parameters
    html_attrs(
        id    => 'foo',
        class => 'wibble'
    );

=head2 data_attrs(\%attrs)

This generates HTML C<data-> attributes for the items in the hash array 
or named parameters passed as a argument.

    data_attrs( foo => 10 );        # data-foo="10"

=head1 TIME AND DATE FUNCTIONS

=head2 datestamp($date)

Returns a L<Badger::Timestamp> object for a date, specified as C<YYYY-MM-DD>.

    my $stamp = datestamp('2013-05-24');

=head2 today

Returns a L<Badger::Timestamp> object for today's date.

    my $stamp = today;

=head2 format_date($date,$format)

Formats a date.

=head1 TEXT MANIPULATION FUNCTIONS

=head2 ordinal(n)

Returns the ordinal suffix (e.g. 'st', 'nd', 'rd') for a number passed as an
argument.

    use Contentity::Utils 'ordinal';
    print ordinal(21);      # st

=head2 ordinate(n)

Returns the number with the ordinal suffix appended.

    use Contentity::Utils 'ordinate';
    print ordinate(21);     # 21st

=head2 plurality(n, nouns)

This method expect a number as a first argument, followed by a string or list
of strings specifying different group nouns for 0, 1 or more items.  The
function returns the appropriate nouns for the number passed.

    use Contentity::Utils 'plurality';

    my $words = ['men', 'man', 'men']
    print plurality(0, $words);     # men
    print plurality(1, $words);     # man
    print plurality(2, $words);     # men
    print plurality(3, $words);     # men
    ...etc...

The nouns may be specified using a single string with alternates enclosing
in parenthesis, separated by vertical bars.  Like so:

    print plurality(0, '(women|woman|women)');     # women

Any common part can be shared:

    print plurality(1, 'wom(en|an|en)');           # woman

=head2 inflect(n, nouns)

Uses the L<plurality()> function to append the appropriate noun to the number
passed as the first argument.  If C<n> is C<0> then the word C<no> is
substituted.

    use Contentity::Utils 'plurality';

    print inflect(0, 'pe(ople|rson|eople)');     # no people
    print inflect(1, 'pe(ople|rson|eople)');     # 1 person
    print inflect(2, 'pe(ople|rson|eople)');     # 2 people

=head2 commas($number)

Adds commas to a number to separate thousands.

    commas(1234567);        # 1,234,567

=head1 FUNCTIONS FOR INTERACTING WITH THE OUTSIDE WORLD

=head2 find_program($program, $path)

Looks for a program named C<$program> in the list of one or more directories
specified as C<$path>, or in the default system search path if unspecified.

The C<$program> can be specified as a reference to a list to find a program
that may have more than one named.

    my $apc = find_program(['apachectl', 'apache2ctl']);

=head2 prompt($message, $default, $yes)

Prompts the user by printing C<$message> and waiting for a response.  A 
default response value can be provided as the second argument.  If the 
third argument, C<$yes>, is set to any true value then the message will
be printed but the function will immediately return as if the user had 
accepted the default value.

    my $name = prompt('Your name', 'anon');

=head2 confirm($question, ...)

Calls L<prompt> with the arguments passed and returns true if and only if
the return value is C<y> or C<yes> (case insensitive).

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.
