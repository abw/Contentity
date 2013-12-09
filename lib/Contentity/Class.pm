package Contentity::Class;

use Carp;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    uber      => 'Badger::Class',
    hooks     => 'constructor component resource resources autolook',
    utils     => 'is_object split_to_list camel_case',
    constants => 'CODE',
    constant  => {
        UTILS            => 'Contentity::Utils',
        CONSTANTS        => 'Contentity::Constants',
        COMPONENT_FORMAT => 'Contentity::Component::%s',
    };

#use Contentity::Utils 'camel_case';

sub constructor {
    my ($self, $name) = @_;
    my $type = $self->name;

    $self->method(
        $name => sub {
            if (@_ == 1 && is_object($type, $_[0])) {
                return $_[0];
            }
            elsif (@_) {
                return $type->new(@_);
            }
            else {
                return $type;
            }
        }
    );
    $self->exports(
        any => $name
    );
}

sub component {
    my ($self, $name) = @_;

    # If a module declares itself to be a component then we make it a subclass 
    # of Contentity::Component, e.g. , e.g. C<component => "resource"> creates
    # a base class of Contentity::Component::Resource
    $self->base(
        sprintf($self->COMPONENT_FORMAT, camel_case($name))
    );

    return $self;
}


sub resource {
    my ($self, $name) = @_;
    $self->constant( RESOURCE => $name );
    return $self;
}


sub resources {
    my ($self, $name) = @_;
    $self->constant( RESOURCES => $name );
    return $self;
}


#-----------------------------------------------------------------------------
# autolook()
#
# Given a list of methods it will call each in turn to see if they can 
# return a defined value.
#-----------------------------------------------------------------------------

our $AUTOLOAD;
our $CALLUP = 1;

sub autolook {
    my ($self, $methods) = @_;

    # split text string into list ref of method names
    $methods = split_to_list($methods);

    $self->import_symbol(
        AUTOLOAD => sub {
            my ($this, @args) = @_;
            my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
            return if $name eq 'DESTROY';
            my $value;

            foreach my $method (@$methods) {
                $value = $this->$method($name, @args);
                #print STDERR "tried $method got ", $value // '<undef>', "\n";
                return $value if defined $value;
            }
            my @caller = caller($CALLUP) || caller(0);
            return $this->error_msg( 
                bad_method => $name, ref($this) || $this, 
                (@caller)[1,2] 
            );
        }
    );

    return $self;
}


1;
