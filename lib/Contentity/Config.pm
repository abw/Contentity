# Work in progress,  Trying to figure out how to subclass Badger::Config so
# that it reads config from project config files.  But we have something of a
# chicken and egg problem.  The config needs a project which it gets from the
# hub which needs a config...

# Now moved into Contentity::Metadata and C::M::Filesystem

package Contentity::Config;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Config Contentity::Base';


sub can_configure {
    my ($self, $name) = @_;

    $self = $self->prototype unless ref $self;

    $self->debug("can_configure($name)") if DEBUG;

    return 
        unless $name && $self->{ item }->{ $name };

    return sub {
        $_[0]->debug("can_configure() auto_gen");
        return @_ > 1
            ? shift->set( $name => @_ )
            : shift->get( $name );
    };
}

1;
