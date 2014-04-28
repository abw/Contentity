package Contentity::Prompter;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    import    => 'class',
    config    => 'verbose=0 quiet=0 nothing=0 yes=0 colour|color=1',
    utils     => 'params extend xprintf split_to_list trim numlike floor
                  red green blue cyan magenta yellow black white bold dark',
    mutators  => 'verbose quiet nothing yes colour',
    constants => 'CODE',
    alias     => {
        color => 'colour',
    },
    messages  => {
        mandatory_option => "You must enter a value for this configuration option.",
        invalid_option   => "That is not a valid value for this configuration option.",
        quitting         => "Exiting program at user request.",
        swearing         => "You are a filthy-mouthed %s-bag.  I'm telling on you!",
        no_help          => "There isn't any help.  Sorry, but you're on your own.",
    };


our $COLOURS = {
    info       => \&cyan,
    about      => \&cyan,
    action     => sub { bold cyan @_ },
    prompt     => sub { bold cyan @_ },
    entry      => sub { bold green @_ },
    quotes     => sub { dark blue @_ },
    message    => sub { bold blue @_ },
    success    => sub { bold green @_ },
    comment    => \&magenta,
    title      => sub { bold yellow @_ },
    title_bar  => sub { dark yellow @_ },
    option     => \&green,
    default    => sub { bold green @_ },
    error      => \&red,
    error_arg  => sub { bold red @_ },
    select_arg => \&yellow,
    select_opt => sub { green @_ },
    unselect   => sub { dark red @_ },
    selected   => sub { bold cyan @_ },
    bracket    => sub { bold blue @_ },
    brackless  => sub { bold black @_ },
    dry_run    => sub { bold red @_ },
    cmd_dash   => sub { green @_ },
    cmd_arg    => sub { bold green @_ },
    cmd_alt    => sub { bold blue @_ },
    cmd_title  => sub { bold cyan @_ },
    cmd_line   => sub { bold green @_ },
    cmd_prompt => sub { bold blue @_ },
};

our $CHECKERS = {
};


#-----------------------------------------------------------------------
# init methods
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    $self->debug_data("prompter config", $config) if DEBUG;

    # process the basic configurations: verbose, quiet, etc.
    $self->configure($config);

    # call the reporter-specific init method
    $self->init_prompter($config);

    return $self;
}

sub init_prompter {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->{ colours } = $class->hash_vars(
        COLOURS => $config->{ colours }
    );

    $self->{ checkers } = $class->hash_vars(
        CHECKERS => $config->{ checkers }
    );

    return $self;
}

sub prompt {
    my $self    = shift;
    my $message = shift;
    my $default = shift;
    my $params  = params(@_);
    my $comment = $params->{ comment };
    my $options = $params->{ options };
    my $answer  = '';

    if ($self->yes || $params->{ yes }) {
        unless ($self->quiet) {
            $self->prompt_prompt($message);
            $self->prompt_accept_default($default);
        }
        $answer = $default;
        return $answer
            if $self->prompt_check($answer, $params);
    }

    # read user input
    if ($comment) {
        $self->prompt_comment($comment);
    }

    if ($options) {
        $self->prompt_options($options);
    }

    local $self->{ attempt } = 0;

    while (1) {
        $self->prompt_prompt($message);
        $self->prompt_cursor($default);
        $answer = $self->read_input;

        if (lc $answer eq 'quit') {
            $self->prompt_error($self->message('quitting'));
            exit;
        }
        elsif ($answer eq '-') {
            $answer  = '';
            $default = '';
        }
        elsif ($answer =~ /\b(help|wtf|huh)\b/) {
            $self->prompt_instructions();
            $answer = '';
            redo;
        }
        elsif ($answer =~ /\b(shit|piss|fuck|cunt|arse|wank)\b/) {
            $self->prompt_error( $self->message( swearing => $1 ) );
            $answer = '';
            redo;
        }
        elsif (! length($answer)) {
            $answer = $default || '';
        }

        last if $self->prompt_check($answer, $params);
    }

    return length($answer)
        ? $answer
        : $default;
}

sub prompt_list {
    my $self    = shift;
    my $type    = shift;
    my $list    = shift;
    my $params  = params(@_);
    my $about   = $params->{ about   };
    my $comment = $params->{ comment };
    my $an      = ($type =~ /^[aeiou]/) ? 'an' : 'a';
    my (@items, $item);

    unless ($self->quiet) {
        $self->prompt_about($about) if $about;
        $self->prompt_comment($comment) if $comment;
        $self->prompt_comment($comment) if $comment;
    }

    if ($list) {
        foreach $item (@$list) {
            if ($self->confirm("Keep existing $type '$item'? ", 'y')) {
                push(@items, $item);
            }
            $an = 'another';
        }
    }

    return \@items
        if $self->yes;

    $self->prompt_list_instructions($type);

    while ($item = $self->prompt("Enter $an $type")) {
        push(@items, $item);
        $an = 'another';
    }

    $self->prompt_newline;

    return \@items;
}


sub prompt_check {
    my $self    = shift;
    my $answer  = shift // '';
    my $params  = params(@_);
    my $checker = $params->{ checker   };
    my $mandate = $params->{ mandatory };
    my $options = $params->{ options   };
    my $opthash = $options ? { map { $_ => 1 } @$options } : { };

    if ($mandate && ! $answer) {
        my $message = numlike($mandate)
            ? $self->message('mandatory_option')
            : $mandate;

        $self->random_insult_error;
        $self->prompt_error($message);
        return 0;
    }
    elsif ($options) {
        if ($opthash->{ $answer }) {
            return 1;
        }
        else {
            $self->random_insult_error;
            $self->prompt_error( $self->message('invalid_option') );
            $self->prompt_options($options);
            return 0;
        }
    }
    elsif ($checker) {
        return $self->checker($checker)->($answer, $self, $params);
    }

    return 1;
}


sub checker {
    my ($self, $name) = @_;
    return $name if ref $name eq CODE;
    my $checkers = $self->{ checkers } || { };
    return $checkers->{ $name }
        || return $self->error_msg( invalid => checker => $name );
}

sub col {
    my $self = shift;
    my $type = shift;
    my $col  = $self->{ colours }->{ $type };
    my $text = join('', @_);
    return $col ? $col->($text) : $text;
}

sub col_expr {
    my $self = shift;
    my $expr = shift;
    my @out;
    foreach my $item (@$expr) {
        push(@out, $self->col(@$item));
    }
    return join('', @out);
}

sub prompt_expr {
    my $self = shift;
    print $self->col_expr(@_);
}

sub prompt_about {
    my $self = shift;
    print $self->col( about => @_ ),  "\n";
}

sub prompt_action {
    my $self = shift;
    print $self->col( action => @_ ),  "\n";
}

sub prompt_prompt {
    my $self = shift;
    print $self->col( prompt => @_ ),  " ";
}

sub prompt_comment {
    my $self = shift;
    print $self->col( comment => @_ ),  "\n";
}

sub prompt_error {
    my $self = shift;
    print $self->col( error => @_ ), "\n";
}

sub prompt_entry {
    my $self = shift;
    print $self->col( entry => @_ );
}


sub prompt_newline {
    my $self = shift;
    my $n    = shift || 1;
    print "\n" while $n-- > 0;
}

sub prompt_accept_default {
    my ($self, $default) = @_;
    print " ", $self->default_prompt($default), "\n";
}

sub prompt_options {
    my ($self, $options) = @_;

    $options = split_to_list($options);

    print $self->col( comment => 'Valid options are: '),
        join(', ', map { $self->col( option => $_) } @$options),
        "\n";
}

sub prompt_cursor {
    my ($self, $default) = @_;
    print $self->default_prompt($default),
          $self->col( cmd_prompt => " > " );
}

sub prompt_cmd {
    my $self = shift;
    print $self->col( cmd_prompt => '$ ' ),
          $self->col( cmd_line   => join(' ', @_) ), "\n";
}

sub default_prompt {
    my ($self, $default) = @_;
    if (defined $default and length $default) {
        return  $self->col( bracket => "[" )
            .   $self->col( default => $default )
            .   $self->col( bracket => "]" );
    }
    else {
        return '';
    }
}

sub prompt_dry_run {
    my $self = shift;
    print $self->col( dry_run => "DRY RUN: "),
          $self->col( action  => @_ ), "\n";
}

sub prompt_dry_run_cmd {
    my $self = shift;
    print $self->col( dry_run    => "DRY RUN: "),
          $self->col( cmd_prompt => '$ '),
          $self->col( cmd_line   => @_ ), "\n";
}


sub prompt_title {
    my $self  = shift;
    my $title = join(' ', @_);
    my $char  = '-';
    my $bar   = $char x length $title;
    print $self->col( title     => $title ), "\n",
          $self->col( title_bar => $bar   ), "\n";
}


sub read_input {
    my $self  = shift;
    my $input = <STDIN> // '';
    chomp($input);
    return trim($input);
}

sub confirm {
    my $self     = shift;
    my $response = $self->prompt(@_);
    return $response && ($response =~ /^y(es)?$/i);
}

sub prompt_instructions {
    my $self = shift;

    $self->prompt_about(@_)
        if @_;

    $self->prompt_expr([
        [action  => 'Press the '],
        [entry   => 'RETURN'],
        [action  => ' key to accept the '],
        [bracket => '['],
        [default => 'default value'],
        [bracket => ']'],
        [action  => ".\nEnter a single dash "],
        [quotes  => '"'],
        [entry   => '-'],
        [quotes  => '"'],
        [action  => " to clear any current value.\n"],
        [action  => 'Press '],
        [entry   => 'Ctrl + c'],
        [action  => " or enter "],
        [quotes  => '"'],
        [entry   => 'quit'],
        [quotes  => '"'],
        [action  => " to quit.\nEnter "],
        [quotes  => '"'],
        [entry   => 'help'],
        [quotes  => '"'],
        [action  => " for these instructions.\n\n"],
    ]);
}

sub prompt_list_instructions {
    my $self = shift;
    my $type = shift || 'item';

    $self->prompt_about(@_)
        if @_;

    $self->prompt_expr([
        [action  => "\nEnter a new $type and press "],
        [entry   => 'RETURN'],
        [action  => ".  Leave it blank and press "],
        [entry   => 'RETURN'],
        [action  => " when you're done adding them.\n\n"],
    ]);
}


our $INSULTS = [
    # insults get progressively more insulting with increased failures
    [
        'Please try again.',
        'Oops, you made a mistake!',
        "Oh dear, I'm afraid that's not good enough.",
        "I fear you may have erred"
    ],
    [
        'You are clearly a fool.',
        'You muppet!',
        'Are you on drugs?',
        'Do you have trouble typing or did someone cut your fingers off?',
        'Do you need to have a lie down for a while?'
    ],
    [
        'Are you taking the piss?',
        "I'm getting rather annoyed with you.",
        "I'm tutting quietly under my breath.",
        "Haven't you got better things to be doing with your time?",
        "Ha ha, very funny.  Keep giving the dumb computer the wrong answer.",
    ],
    [
        "Look, I may be a dumb computer but I've got better things to be doing with my time.",
        "Now I know you're just doing this to see all the silly error messages.",
        "Your mother was a hamster and your father smelled of elderberries.",
        "I blow my nose at you and all your silly ker-nig-herts.",
        "You are doing a good job.  Badly.",
    ],
    [
        "Stop it!",
        "Bugger off!",
        "I pity the fool who can't answer a simple question.",
        "Mornington Crescent!",
        "Wanna take a bath?",
    ],
    [
        "Seriously, stop messing!",
        "Get lost!",
        "I am calling the police right now.",
        "This incident has been reported.",
        "I can feel one of my turns coming on.",
    ],
    [
        "I'm not playing any more.",
        "I'm sorry Dave, I'm afraid I can't let you do that.",
        "Life, don't talk to me about life.",
    ],
    [
        "ERROR BETWEEN KEYBOARD AND CHAIR",
    ]
];


sub random_insult {
    my ($self, $level) = @_;
    $level = floor($level / 6);
    my $set = $INSULTS->[$level] || $INSULTS->[-1];
    return $set->[rand @$set];
}

sub random_insult_error {
    my $self    = shift;
    my $attempt = $self->{ attempt } ||= 0;
    $self->{ attempt }++;
    $self->prompt_error(
        $self->random_insult($attempt)
    );
}


1;

__END__

=head1 NAME
