package Contentity::Class::Form::Field;

use Contentity::Class
    version  => 0.03,
    debug    => 0,
    uber     => 'Contentity::Class',
    constant => {
        BASE => 'Contentity::Form::Field',
    },
    hooks    => {
        type    => \&type,
        display => \&display,
        layout  => \&layout,
        label   => \&label,
        default => \&default,
    };

sub export {
    my $class  = shift;
    my $target = shift;
    my $klass  = class($target);
    my @args   = @_;
    my $config = { @args };

    if ($config->{ base }) {
        $class->debug("class $klass defines explicit base class") if DEBUG;
    }
    else {
        $class->debug("adding default base class to $klass: ", $class->BASE) if DEBUG;
        unshift(@args, base => $class->BASE);
    }

    $class->debug("starting export for target: $target") if DEBUG;
    $class->SUPER::export($target, @args);
}


class->methods(
    map {
        my $name = $_;              # lexical copy for closure
        $name => sub {
            $_[0]->var( uc($name) => $_[1] );
            return $_[0];
        }
    }
    qw( type display layout label default )
);

1;
