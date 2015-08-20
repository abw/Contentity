package Contentity::Timestamp;

use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Badger::Timestamp',
    codec      => 'html',
    constant   => {
        TS        => __PACKAGE__,
        TIMESTAMP => __PACKAGE__,
    },
    exports   => {
        any   => 'TS TIMESTAMP Timestamp Now',
    };

# Contentity::Timestamp is used by Contentity::Utils which is used by
# Contentity::Class leading to a circular dependency.  So we can't use
# the 'utils' import hook in Contentity::Class above and must instead
# load and alias these manually.
use Contentity::Utils;
*inflect   = \&Contentity::Utils::inflect;
*datestamp = \&Contentity::Utils::datestamp;
*today     = \&Contentity::Utils::today;


sub Timestamp {
    return @_
        ? TS->new(@_)
        : TS
}

sub Now {
    TS->now;
}

sub html {
    encode(shift->timestamp);
}

sub ymd {
    my $self = shift;
    return @$self{qw( year month day )};
}

sub yesterday {
    shift->adjust( days => -1 );
}

sub tomorrow {
    shift->adjust( days => +1 );
}

sub relative {
    my $self   = shift;
    my $now    = Now;
    my $diff   = Now->epoch_time - $self->epoch_time;
    my $suffix = $diff > 0 ? ' ago' : ' from now';

    if ($diff == 0) {
        return "Just now";
    }

    if ($diff < 60) {
        return inflect($diff, 'second') . $suffix;
    }

    $diff = int $diff / 60;

    if ($diff < 60) {
        return inflect($diff, 'minute') . $suffix;
    }

    $diff = int $diff / 60;

    if ($diff < 24) {
        return inflect($diff, 'hour') . $suffix;
    }

    $diff = int $diff / 24;

    if ($diff < 30) {
        return inflect($diff, 'day') . $suffix;
    }

    $diff = int $diff / 7;

    if ($diff < 10) {
        return inflect($diff, 'weeks') . $suffix;
    }

    $diff = int $diff * 7 / 30;

    if ($diff == 12) {
        return '1 year' . $suffix;
    }
    if ($diff < 24) {
        return inflect($diff, 'month') . $suffix;
    }

    $diff = int $diff / 12;
    return inflect($diff, 'year') . $suffix;
}


sub relative_days {
    my $self     = shift;
    my $days_ago = $self->days_before(today());
    my $past     = $days_ago > 0;
    my $days     = abs $days_ago;
    my $weeks    = int $days / 7;
    my $months   = int $days / 30;
    my $years    = int $days / 365;
    my $prefix   = $past ? 'Last' : 'Next';
    my $suffix   = $past ? ' ago' : ' from now';

    return 'Today'                              if $days   == 0;
    return $past ? 'Yesterday' : 'Tomorrow'     if $days   == 1;
    return inflect($days,   'day'  ) . $suffix  if $weeks  == 0;
    return inflect($weeks,  'week' ) . $suffix  if $months == 0;
    return "$prefix month"                      if $months == 1;
    return inflect($months, 'month') . $suffix  if $years  == 0;
    return "$prefix year"                       if $years  == 1;
    return inflect($years,  'year' ) . $suffix;
}

sub days_before {
    my ($self, $cmp) = @_;
    return undef unless $cmp;
    my $date1 = datestamp($self->date);
    my $date2 = datestamp($cmp);
    my $time1 = $date1->epoch_time;
    my $time2 = $date2->epoch_time;
    my $diff  = $time2 - $time1;
    $self->debug("compare [$date1/$time1] [$date2/$time2] = $diff") if DEBUG;
    return $diff / (60 * 60 * 24);
}

sub days_after {
    return 0 - shift->days_before(@_);
}

sub days_before_today {
    shift->days_before(today());
}

sub days_after_today {
    shift->days_after(today());
}


1;

=head1 NAME

Contentity::Timestamp - subclass of Badger::Timestamp with some extra methods

=head1 SYNOPSIS

    use Contentity::Utils 'Timestamp';

    my $ts = Timestamp('2015-04-20');

    print $ts->relative_days;

=head1 DESCRIPTION

This module is a subclass of the L<Badger::Timestamp> module which adds
some extra methods.  They may eventually get pushed upstream into
Badger::Timestamp.

=head1 ADDITIONAL METHODS

=head2 html()

Return an HTML safe version of the timestamp.

=head2 ymd()

Return the year, month and day.

=head2 yesterday()

Move the date forward one day.

=head2 tomorrow()

Move the date backward one day.

=head2 relative()

Returns a string representing the time relative to now.  e.g.
"4 hours 20 minutes ago".

=head2 relative_days()

Returns a string representing the date relative to today.  e.g.
"3 days ago", "3 months from now".

=head2 days_before($date)

Returns the number of days that the timestamp object's date is before
the date passed as an argument.

=head2 days_after($date)

Returns the number of days that the timestamp object's date is after
the date passed as an argument.

=head2 days_before_today()

Returns the number of days that the timestamp object's date is before
today.

=head2 days_after_today()

Returns the number of days that the timestamp object's date is after
today.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
