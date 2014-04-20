package Contentity::Path;

use Contentity::Class
    version     => 0.2,
    debug       => 0,
    base        => 'Contentity::Base',
    import      => 'class',
    accessors   => 'path todo done abs dir',
    constructor => 'Path',
    as_text     => 'path',
    is_true     => 1,
    constant    => {
        SLASH   => '/',
        SEGMENT => 'Contentity::Path::Segment',
    },
    alias       => {
        text    => 'path',
    };


sub new {
    my $class = shift;
    my $path  = join(SLASH, grep { defined($_) && length($_) } @_);
    my $segm  = $class->SEGMENT;
    my $copy  = $path;
    my $abs   = 0;      # leading slash
    my $dir   = 0;      # trailing slash

    # strip any leading and/or trailing slashes
    for ($copy) {
        s[^/][] && $abs++;
        s[/$][] && $dir++;
    }

    return bless(
        {
            path => $path,
            todo => bless([ split('/', $copy) ], $segm),
            done => bless([ ], $segm),
            abs  => $abs,
            dir  => $dir,
        },
        $class
    );
}


sub next {
    $_[0]->{ todo }->[0];
}

sub more {
    scalar @{ $_[0]->{ todo } };
}


sub take_next {
    my $self = shift;
    my $done = $self->{ done };
    my $todo = $self->{ todo };

    if (@$todo) {
        my $item = shift @$todo;
        push(@$done, $item);
        return $item;
    }
    return undef;
}

sub take_all {
    my $self = shift;
    my $done = $self->{ done };
    my $todo = $self->{ todo };
    my @rest = @$todo;
    @$todo = ();
    push(@$done, @rest);
    my $path = join(SLASH, @rest);
    $path .= SLASH if $self->dir;
    return $path;
}


sub path_done {
    my $self = shift;
    my $path = $self->done->text;
    $path = SLASH.$path if $self->abs;
    $path .= SLASH if $self->dir && ! $self->more;
    return $path;
}

sub path_todo {
    my $self = shift;
    my $path = $self->todo->text;
    $path .= SLASH if length $path && $self->dir;
    return $path;
}

#-----------------------------------------------------------------------
# Lightweight class for autostringifying a list of path segments
#-----------------------------------------------------------------------

package Contentity::Path::Segment;

use Contentity::Class
    version     => 0.1,
    debug       => 0,
    base        => 'Contentity::Base',
    constants   => 'SLASH',
    as_text     => 'text',
    is_true     => 1;


sub text {
    join(SLASH, @{$_[0]});
}


1;
