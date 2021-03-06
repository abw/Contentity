package Contentity::Utils;

use Carp;
use warnings            qw( FATAL utf8 );
use open                qw< :std :utf8 >;
use Badger::Rainbow     ANSI => 'all';
use Carp;
use POSIX               'floor';
use Badger::Debug       'debug_caller';
use Badger::Utils       'params numlike is_object plural permute_fragments
                         xprintf split_to_list md5_hex inflect';
use Contentity::Timestamp 'TS TIMESTAMP Timestamp Now';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Utils',
    constants => 'ARRAY PKG HASH DELIMITER BLANK SPACE
                  :timestamp :date_formats',
    codecs    => 'html json',
    exports   => {
        any => q{
            Colour Path
            debug_caller strip_hash strip_hash_undef split_to_hash
            module_name
            integer random
            uri_safe id_safe
            self_key self_keys
            H html_elem html_attrs data_attrs
            datestamp today format_date date_range
            parse_time canonical_time format_time
            ordinal ordinate commas trim ucwords
            snake_up snake_down xformat tprintf
            find_program prompt confirm floor
            red green blue cyan magenta yellow black white grey dark bold
            cmd generate_id
            error_html_to_ansi
            TS TIMESTAMP Timestamp Now
            encode_html decode_html
            encode_json decode_json

        }
    };
use Contentity::Colour  'Colour';
use Contentity::Path    'Path';
use Contentity::Template;

our $TPRINTF_MODULE = 'Contentity::Template';
our $TPRINTF_ENGINE;


#-----------------------------------------------------------------------------
# Number utility functions
#-----------------------------------------------------------------------------

sub integer {
    floor(shift(@_) + 0.0001);
}

sub random {
    my $n = shift || 99999;
    return int rand $n;
}


#-----------------------------------------------------------------------------
# Hash utilities
#-----------------------------------------------------------------------------


sub strip_hash {
    my $hash = shift;
    foreach (keys %$hash) {
        delete $hash->{ $_ }
            unless defined $hash->{ $_ }
               and length  $hash->{ $_ };
    }
    return $hash;
}

sub strip_hash_undef {
    my $hash = shift;
    foreach (keys %$hash) {
        delete $hash->{ $_ }
            unless defined $hash->{ $_ };
    }
    return $hash;
}

sub split_to_hash {
    my $list = shift;
    return { } unless $list;
    return $list if ref $list eq HASH;
    return {
        map  { $_ => $_ || 1 }
        grep { defined and length }
        @{ split_to_list($list) }
    };
}


#-----------------------------------------------------------------------------
# Modules
#-----------------------------------------------------------------------------

sub module_name(@) {
    # map {  } works backwards, so read this from bottom to top...
    join(
        PKG,# join into a module path, e.g. User::SendInvite
        grep {
            # ignore any empty items
            defined $_ && length $_
        }
        map {
            # underscores indicate word breaks that we capitalise
            # e.g. send_invite becomes SendInvite
            join('',  map { s/(.)/\U$1/; $_ } split '_' )
        }
        map {
            # split on slashes in the URI
            # e.g. 'user/send_invite' => 'user', 'send_invite'
            split qr</>
        }
        @_  # feed in arguments
    );
}

#-----------------------------------------------------------------------------
# URI utilities
#-----------------------------------------------------------------------------


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

sub id_safe {
    my $text = join('', @_);
    for ($text) {
        s/\W+/_/g;          # change all non-word characters to underscores
        s/^_+//g;           # remove leading underscores
        s/_+$//g;           # remove trailing underscores
        s/_+/_/g;           # collapse multiple underscores into one
    }
    return lc $text;
}


#-----------------------------------------------------------------------------
# Parameter handling functions
#-----------------------------------------------------------------------------

sub key_args {
    my $self = shift;
    my $key  = shift;
    my $args;

    if (@_ == 1) {
        # single argument can be the $key named or a reference to a hash
        # of named parameters
        $args = ref $_[0] eq HASH
            ? shift
            : { $key => shift };
    }
    else {
        # multiple arguments are named parameters
        $args = { @_ };
    }

    return defined $args->{ $key }
        ? $args
        : $self->error_msg( missing => $key );
}

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

    #Contentity->debug_data( ATTRS => \@attrs ) if DEBUG or 1;

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

sub date_range {
    my $params  = shift;
    my $target  = shift || $params;
    my $days    = $params->{ days  };
    my $from    = $params->{ from  };
    my $to      = $params->{ to    };
    my $month   = $params->{ month };
    my $year    = $params->{ year  };
    my $now     = Now;
    my $defdays = 28;
    my ($start, $end);

    # Allow month to be specified as year-month, e.g. '2013-11'
    # Note we also allow month ranges, e.g. '01-03', which we assume are
    # always less than 4 digits.  In theory, we can also have year-m1-m2,
    # e.g. 2012-01-03 for Jan (01) to March (03), 2013
    if (! $year && $month && $month =~ s/^(\d{4})-(\d+)/$2/) {
        $year = $1;
    }

    if ($from && $to) {
        $start = datestamp($from);
        $end   = datestamp($to);

        if ($end->before($start)) {
            ($start, $end) = ($end, $start);
        }
    }
    elsif ($from) {
        $days ||= $defdays;
        $start  = datestamp($from);
        $end    = $start->copy->adjust( days => $days );
    }
    elsif ($to) {
        $days ||= $defdays;
        $end   = datestamp($to);
        $start = $end->copy->adjust( days => -$days );
    }
    elsif ($days) {
        $start = Now->adjust( days => -$days );
        $end   = Now->adjust( days =>  $days );
    }
    elsif ($year) {
        if ($month) {
            my ($m1, $m2) = split('-', $month);
            $start = datestamp("$year-$m1-01");
            if ($m2) {
                $end = datestamp("$year-$m2-01");
                $end->day( $end->days_in_month );
            }
            else {
                $end = $start->copy->day( $start->days_in_month );
            }
        }
        else {
            $start = datestamp("$year-01-01");
            $end   = datestamp("$year-12-31");
        }
    }
    else {
        $start = Now;
        $end   = Now->copy->adjust( days => 28 );
    }

    $target->{ from } = $start->date;
    $target->{ to   } = $end->date;

    return $target;
}

#-----------------------------------------------------------------------------
# times
#-----------------------------------------------------------------------------

sub parse_time {
    my $time = shift;

    # examples:
    #  4pm
    #  4.20pm
    #  4.20 p.m.
    #  1620
    #  16:20:42    <- canonical form we return
    #
    for ($time) {
        # strip leading and trailing whitespace
        s/^\s+//;
        s/\s*$//;
    }
    my $src = $time;

    # look for sequences of digits separated by one or non-digits
    $time =~ s/^(\d+(\D+\d+)*)\s*// || return;
    my $nums = $1;
    my $sufx = $time;
    my @nums = split(/\D/, $nums);
    my ($h, $m, $s) = (0) x 3;

    if (@nums == 3) {
        ($h, $m, $s) = @nums;
    }
    elsif (@nums == 2) {
        ($h, $m) = @nums;
    }
    elsif (@nums == 1) {
        my $digits = length $nums;
        if ($digits <= 2) {
            # e.g. 7, 18, etc.
            $h = $nums;
        }
        elsif ($digits <= 4) {
            # e.g. 715, 825, 1230 - take 2 from RHS
            $nums =~ s/(\d\d)$//;
            $m = $1;
            $h = $nums;
        }
        elsif ($digits <= 6) {
            # e.g. 71500, 123030 - take 2 from RHS, then 2 more
            $nums =~ s/(\d\d)(\d\d)$//;
            ($m, $s) = ($1, $2);
            $h = $nums;
        }
        else {
            return;
        }
    }
    else {
        return;
    }

    if (length $sufx) {
        $sufx =~ s/\W//g;
        $sufx = lc $sufx;
        if ($sufx eq 'pm')  {
            $h += 12 unless $h > 11;   # 1pm => 13.  NOTE: 12pm => 12:00
        }
        elsif ($sufx eq 'am') {
            $h = 0 if $h == 12;     # 12am = 00:00
        }
        elsif ($sufx eq 'noon' || $sufx =~ /midd?ay/) {   # sic
            return unless $h == 12;
        }
        else {
            return;
        }
    }

    return { h => $h, m => $m, s => $s };

}

sub canonical_time {
    format_time(@_);
}

sub format_time {
    my $time = parse_time(shift);
    my $fmt  = shift || '<hh>:<mm>:<ss>';
    $time->{ hh } = sprintf('%02d', $time->{ h });
    $time->{ mm } = sprintf('%02d', $time->{ m });
    $time->{ ss } = sprintf('%02d', $time->{ s });
    $fmt =~ s/<(\w+)>/$time->{ lc $1 } || die "Invalid time format: <$1>"/ge;
    return $fmt;
}

#-----------------------------------------------------------------------------
# Generate ID, e.g. for session ID cookie
#-----------------------------------------------------------------------------

sub generate_id {
    my $length = (@_ && numlike($_[0])) ? shift : 32;
    my $text   = join('', grep { defined } @_) . time() . md5_hex(
        time() . rand() . $$ . { }
    );
    return substr( md5_hex($text), 0, $length );
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


sub trim {
    my $text = shift;
    for ($text) {
        s/^\s+//;
        s/\s+$//;
    }
    return $text;
}

sub ucwords(@) {
    my $text = join('', @_);
    my $caps = join(
        ' ',
        map { /^(a|an|and|at|for|from|in|of|on|the|to)$/ ? $1 : ucfirst $_ }
        split(/[\s_]+/, $text)
    );
    # first letter is always capitalised even if one of the above stop words
    # that aren't usually capitalised
    return ucfirst $caps;
}

sub snake_up {
    my $text = shift;
    $text =~ s/_+/-/g;
    return lc $text;
}

sub snake_down {
    my $text = shift;
    $text =~ s/-+/_/g;
    return lc $text;
}

sub xformat {
    my $format = shift;
    my $params = params(@_);
    $format =~ s[<(\w+)>][$params->{$1}//"<$1>"]ge;
    return $format;
};

sub tprintf {
    my $template = shift;
    my $params   = params(@_);
    my $engine   = $TPRINTF_ENGINE ||= $TPRINTF_MODULE->new( INTERPOLATE => 1 );
    return $engine->render(\$template, $params);
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
    my ($msg, $def, $yes, $params) = @_;
    my $ans = '';
    $def = '' unless defined $def;
    my $defprompt = $def
        ? yellow("[") . green($def) . yellow("]") . ' '
        : "";

    my $comment = $params->{ comment };
    my $options = $params->{ options };
#    print cyan($msg) . $defprompt . "\n";
    print cyan($msg) . " ";

    if ($yes) {    # accept default
        print " ", $defprompt, "\n";
    }
    else {           # read user input
        if ($comment) {
            print "\n", yellow($comment) . "\n";
        }

        if ($options) {
            $options = split_to_list($options);
            print "\n", yellow('Valid options: '),
                join(', ', map { green($_) } @$options),
                "\n";
        }

        print "$defprompt> ";
        #if ($def) {
        #    print "Enter a new value or press RETURN to accept default\n> ",
        #}
        #else {
        #    print "Enter a new value:\n> ",
        #}
        chomp($ans = <STDIN>);
        $ans = trim($ans);
        if ($ans eq '-') {
            $ans = '';
            $def = '';
        }
    }

    return length($ans) ? $ans : $def;
}

sub confirm {
    my $reply = prompt(@_);
    return $reply =~ /^y(es)?$/i;
}


sub cmd {
    my $err = system(@_);

    if ($err != 0) {
        # more robust analysis of failures, as and when we want it.
        if ($? == -1) {
            die "\n",
                red("Failed to execute command "),
                cyan("'$_[0]'"),
                red(": "),
                yellow($!),
                "\n";
        }
        elsif ($? & 127) {
            die "\n",
                red("Command "),
                cyan("'$_[0]'"),
                red(" died with signal ", ($? & 127)),
#                yellow($!),
                "\n";
        }
        else {
            die "\n",
                red("Command "),
                cyan("'$_[0]'"),
                red(" exited with value: ", $? >> 8),
                "\n";
        }
    };

    return 1;
}

#use IPC::Run 'run';
#sub filter_cmd {
#    my ($input, @cmd) = @_;
#    my ($output, $error);
#    run(\@cmd, \$input, \$output, \$error);
#    die $error if $error;
#    return $output;
#}


#-----------------------------------------------------------------------------
# Error message cleanup
#-----------------------------------------------------------------------------

sub error_html_to_ansi {
    my $error = shift;

    my $type  = bold red($error->type) . yellow(" error:\n");
    my $info  = bold cyan $error->info . "\n";
    my $trace = $error->stack_trace;

    for ($trace) {
        s{<span class="(?:method|module)">(.*?)</span>}{cyan($1)}eg;
        s{<span class="(?:file|line)">(.*?)</span>}{yellow($1)}eg;
        #s{<.*?>}{}g;
    }
    return $type . $info . $trace;
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


=head1 URI UTILITY METHODS

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
