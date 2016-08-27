package Contentity::Class;

use Carp;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    uber      => 'Badger::Class',
    hooks     => 'constructor component asset assets status record table autolook',
    utils     => 'is_object split_to_list camel_case blessed',
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


sub asset {
    my ($self, $name) = @_;
    $self->constant( ASSET => $name );
    $self->alias( $name => 'asset' );   # e.g. form() => asset()
    return $self;
}


sub assets {
    my ($self, $name) = @_;
    $self->constant( ASSETS => $name );
    return $self;
}

#-----------------------------------------------------------------------------
# Hook for generating status methods, e.g. active(), pending(), etc.
#-----------------------------------------------------------------------------

sub status {
    shift->option_methods( status => @_ );
}


sub option_methods {
    my ($self, $option, $values) = @_;

    $values = split_to_list($values);

    $self->methods(
        # add generic method to read/compare an option,
        # e.g. status(), progress(), etc.
        $option    => sub {
            my $self = shift;
            return @_
                ? $self->{ $option } eq $_[0]
                : $self->{ $option };
        },

        # another method to set option and update DB record,
        # e.g. set_status(), set_progress(), etc.
        "set_$option" => sub {
            my ($self, $value) = @_;
            $self->update( $option => $value );
        },

        # and specific methods for each value specified in $values which
        # calls the above generic method to compare
        # e.g. sub active { shift->status('active') }
        map {
            my $value = $_;
            $value => sub {
                shift->$option($value)
            }
        }
        @$values
    );

    return $self;
}

#-----------------------------------------------------------------------------
# hooks to set RECORD and TABLE constants
#-----------------------------------------------------------------------------

sub record {
    shift->constant( RECORD => shift );
}

sub table {
    shift->constant( TABLE => shift );
}

#-----------------------------------------------------------------------------
# autolook()
#
# Given a list of methods it will call each in turn to see if they can
# return a defined value.
#-----------------------------------------------------------------------------

our $AUTOLOAD;
our $CALLUP = 0;

sub autolook {
    my ($self, $methods) = @_;

    # split text string into list ref of method names
    $methods = split_to_list($methods);

    $self->import_symbol(
        AUTOLOAD => sub {
            my ($this, @args) = @_;
            my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
            my $value;

            return if $name eq 'DESTROY';

            # Hmmm - we want to be able to call class methods, e.g. Cog->database
            #confess "AUTOLOAD $name() called on unblessed value '$this'"
            #    unless blessed $this;

            foreach my $method (@$methods) {
                $value = $this->$method($name, @args);
                #print STDERR "tried $method got ", $value // '<undef>', "\n";
                return $value if defined $value;
            }
            my @caller = caller($CALLUP);
            return $this->error_msg(
                bad_method => $name, ref($this) || $this,
                (@caller)[1,2]
            );
        }
    );

    return $self;
}


1;

__END__

=head1 NAME

Contentity::Class - Contentity metaclass construction module

=head1 DESCRIPTION

This module is a subclass of L<Badger::Class>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2013-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
