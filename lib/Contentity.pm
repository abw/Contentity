package Contentity;

use Badger::Debug ':all';
use Contentity::Config;
use Contentity::Class
    version    => 0.01,
    debug      => 0,
    base       => 'Badger::Prototype Contentity::Base',
    import     => 'class',
    autolook   => 'autoload_hub';

our $HUB = 'Contentity::Hub' unless defined $HUB;


sub init {
    my ($self, $config) = @_;
    $self->{ config } = $config;
    return $self;
}


#-----------------------------------------------------------------------------
# Methods to access the central hub, database and other shared components
#-----------------------------------------------------------------------------

sub hub {
    my $self = shift->prototype;

    if (@_) {
        # got passed an argument (a new hub) which we connect $self to
        return ($self->{ hub } = shift);
    }
    else {
        # return the existing hub, or connect up to one
        return $self->{ hub } ||= do {
            my $module = $self->class->any_var('HUB');
            $self->debug("Connecting to hub: $module\n") if DEBUG;
            class($module)->load;
            $module->new($self->{ config });
        };
    }
}


#-----------------------------------------------------------------------------
# The auto_can method is called when an unknown method is called.  It looks
# to see if the method can be delegated to either the database model or the
# hub.
#-----------------------------------------------------------------------------

sub autoload_hub {
    my ($self, $name, @args) = @_;
    my $hub = $self->hub;

    return  $hub->can($name)
        ?   $hub->$name(@args)
        :   undef;
}


1;
