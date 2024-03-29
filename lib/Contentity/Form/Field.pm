package Contentity::Form::Field;

use Contentity::Class
    version   => 0.04,
    debug     => 0,
    base      => 'Contentity::Base',
    import    => 'bclass',   # use Plan B so class() can be a regular method
    utils     => 'xprintf weaken join_uri extend',
    accessors => 'form type disabled mandatory data factory append prepend',
    mutators  => 'name size label layout placeholder display default class style tabindex n',
    constants => 'ARRAY HASH SPACE',
    constant  => {
        DEFAULT      => 'text',
        FIELD_PREFIX => 'field',
        can_focus    => 1,
        submit_field => undef,
    },
    config    => [
        'type|class:TYPE|method:TYPE!',
        'name|class:NAME|target:type',
        'label|class:LABEL',
        'layout|class:LAYOUT=field!',
        'class|class:CLASS',
        'style|class:STYLE',
        'value|class:VALUE',
        'default|class:DEFAULT',
        'strict|class:STRICT=1',
        'display|class:DISPLAY|target:type',
        'prepend|class:PREPEND',
        'append|class:APPEND',
        'mandatory|class:MANDATORY',
        'ignored=0',
        'disabled=0',
        'n',
    ],
    messages  => {
        mandatory => "Please enter a value for '%s'.",
        too_short => '%s is too short.  It must be at least %s characters long.',
        too_long  => '%s is too long.  It must be no longer than %s characters.',
        format    => '%s is in the wrong format. It must match %s.',
    };

our $PREPARE  = {
    strip_tags      => 1,
    strip_entities  => 1,
    trim_wspace     => 1,
    collapse_wspace => 0,
    remove_wspace   => 0,
};


sub init {
    my ($self, $config) = @_;

    # update $config to set defaults from package vars
    $self->configure($config => $config);

    $self->debug_data( field_config => $config ) if DEBUG;

    # copy everything into object
    @$self{ keys %$config } = values %$config;

    # default display for a field is its type name
    $self->{ display } ||= $self->{ type };

    $self->{ label } = ucfirst $self->{ name }
        unless defined $self->{ label };

    $self->debug("type: $self->{ type }    name: $self->{ name }") if DEBUG;

    # allow either of 'mandatory' or 'optional' flag
    $self->{ mandatory } = $config->{ optional } ? 0 : 1
        if ! defined $config->{ mandatory }
          && defined $config->{ optional  };

    # weaken any reference to a form and/or factory to avoid circular references
    weaken $self->{ form }
        if $self->{ form };

    $self->debug("value: $self->{ value }") if DEBUG;

    return $self;
}

sub register {
    my ($self, $registry) = @_;
    my $name = $self->name || return;
    $registry->{ $name } = $self;
}

sub validate {
    my $self  = shift;
    my $value = $self->prepare(shift);

    return $self->invalid_msg( mandatory => $self->{ label } )
        if $self->{ mandatory } && ! length $value;

    if ($self->{ strict } || length $value) {
        # Only do min/max length checks if we're in strict more (which we are
        # by default) or if a value has been defined.  This allows fields to
        # be left blank if they're not mandatory without raising an error.
        return $self->invalid_msg( too_short => $self->{ label }, $self->{ min_length } )
            if $self->{ min_length } && length $value < $self->{ min_length };

        return $self->invalid_msg( too_long => $self->{ label }, $self->{ max_length } )
            if $self->{ max_length } && length $value > $self->{ max_length };
    }

    return ($self->{ valid } = 1);
}

sub prepare {
    my $self  = shift;
    my $value = shift; #join('', grep { defined $_ } @_);
    my $class = bclass($self);

    # look for any prepare actions defined
    my $prep = $self->{ prepare }
            || $class->any_var('PREPARE');

    # upgrade text string to hash of prepare actions
    $prep = $self->{ prepare } = { map { ($_, 1) } split(/\W+/, $prep) }
        unless ref $prep eq HASH;

    if (! defined $value) {
        $value = '';
        $self->{ undefined } = 1;
    }

    # remove any HTML elements that might be used for a Javscript
    # injection attack or other mischief
    # NOTE: this could be generalised to a set of facets
    for ($value) {
        s/<.*?>//sg if $prep->{ strip_tags     };
        s/&\w+;//sg if $prep->{ strip_entities };

        if ($prep->{ trim_wspace }) {
            s/^\s+//sg;
            s/\s+$//sg;
        }
        s/\s+/ /sg  if $prep->{ collapse_wspace };
        s/\s+//sg   if $prep->{ remove_wspace   };
    }

    return ($self->{ value } = $value);
}

sub invalid_msg {
    my $self = shift;
    my $type = $_[0];

    if (my $format = $self->{ messages }->{ $type }) {
        $self->invalid(xprintf($format, @_));
    }
    else {
        $self->invalid($self->message(@_));
    }
}

sub invalid {
    my $self = shift;
    if (@_) {
        $self->{ error } = join('', @_);
        return ($self->{ valid } = 0);
    }
    return $self->{ valid } ? 0 : 1;
}

sub valid {
    my $self = shift;
    return $self->{ valid } ? 1 : 0;
}

sub value {
    my $self = shift;
    return @_ ? ($self->{ value } = shift)
              : defined $self->{ value }
              ? $self->{ value }
              : $self->{ default };
}

sub values {
    my $self   = shift;
    my $name   = shift || $self->name;
    my $value  = $self->value;      # scalar context
    return ($name, $value);         # aways return 2 item list
}

sub field_values {
    my $self   = shift;
    my $name   = shift || $self->name;
    my $value  = $self->value;      # scalar context
    return ($name, $value);         # aways return 2 item list
}

sub validation_data {
    my $self  = shift;
    my $data  = shift;
    my $name  = $self->{ name };
    my $error = $self->{ error };
    my $value = $self->value;
    my $field = {
        name  => $self->{ name  },
        label => $self->{ label },
        valid => $self->{ valid },
    };
    if (defined $value) {
        $field->{ value } = $value
    }
    if ($error) {
        $field->{ message } = $error;
    }

    $data->{ fields }->{ $name } = $field;
    return $data if $self->{ ignored };


    if ($field->{ valid }) {
        push(@{ $data->{ valid_fields } }, $field);

        # ignore_undef will ignore undefined values, skipping the step
        # of transferring values to $data->{ values };
        # ignore_unset will do the same for undefined or unset values
        # (where length == 0)

        my $undef = $self->{ undefined } || ! defined $value;
        if ($undef) {
            return $data
                if $self->{ ignore_undef }
                || $self->{ ignore_unset };
        }
        elsif (! length $value) {
            return $data if $self->{ ignore_unset };
            # undef unset converts an unset value to undef, e.g. for nulling
            # out an existing database field
            if ($self->{ undef_unset }) {
                $data->{ values }->{ $self->name } = undef;
                $self->debug("set ", $self->name, " to undef (undef_unset)") if DEBUG;
                return $data;
            }
        }

        my @values = $self->field_values;
        if (@values) {
            extend($data->{ values }, { @values });
        }

    }
    else {
        push(@{ $data->{ invalid_fields } }, $field);
        if ($error) {
            push(@{ $data->{ errors } }, $error);
            $data->{ field_errors }->{ $name } = $error;
        }
    }

    return $data;
}

sub reset {
    my $self = shift;
    $self->{ value } = $self->{ default };  # may be undef, but that's OK
}

sub error {
    my $self = shift;
    return @_
        ? $self->SUPER::error(@_)
        : $self->{ error };
}

sub trim {
    my ($self, $value) = @_;
    $value = '' unless defined $value;
    for ($value) {
        s/^\s+//;
        s/\s+$//;
    }
    return $value;
}

sub present {
    my $self = shift;
    my $view = shift;
    $self->debug_data( args => \@_ ) if DEBUG;
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };

    $args->{ field } = $self;

    my $uri = join_uri($self->FIELD_PREFIX, $self->display);
    # render the field content using any pre-defined display value or the field name
    $self->debug("rendering field template: $uri") if DEBUG;
    $args->{ content } = $view->include($uri, $args);

    # now render the field in a layout template
    return $view->include('layout/' . $self->layout, $args);
}

sub disable {
    my $self = shift;
    $self->{ disabled } = 1;
}

sub enable {
    my $self = shift;
    $self->{ disabled } = 0;
}

sub TYPE {
    my $self  = shift;
    my $class = ref $self || $self;
    $class =~ s/^(.*?::)+//;
    lc $class;
}

sub workspace {
    shift->factory->workspace;
}

#-----------------------------------------------------------------------------
# Somewhat opinionated methods for generating HTML attrs.  These should be
# generalised so we're not hard-coding certain class names, e.g. mandatory,
# error, etc.
#-----------------------------------------------------------------------------

sub layout_classes {
    my $self    = shift;
    my @classes = qw(field);
    push(@classes, 'mandatory') if $self->mandatory;
    push(@classes, $self->{ layout_class }) if $self->{ layout_class };
    if ($self->error) {
        push(@classes, 'error invalid');
    }
    elsif ($self->valid) {
        push(@classes, 'valid');
    }
    return join(SPACE, @classes);
}

sub layout_id {
    my $self = shift;
    my $lid;

    if ($lid = $self->{ layout_id }) {
        return $lid;
    }
    elsif ($lid = $self->{ id }) {
        return "${lid}_field";
    }
    else {
        return undef;
    }
}

sub layout_attrs {
    my $self  = shift;
    my $attrs = {
        class => $self->layout_classes,
    };
    my $lid = $self->layout_id;
    $attrs->{ id } = $lid if $lid;
    $self->debug_data( layout_attrs => $attrs ) if DEBUG;
    return $attrs;
}

sub label_attrs {
    my $self  = shift;
    my $attrs = { };
    $attrs->{ for   } = $self->name;
    $attrs->{ class } = $self->{ label_class } if $self->{ label_class };
    return $attrs;
}

1;
__END__

=head1 NAME

Contentity::Form::Field - base class for form field

=head1 SYNOPSIS

    package Contentity::Form::Field::Example;
    use base 'Contentity::Form::Field';

    # define custom methods for example field
    sub validate {
        my ($self, $value = @_);

        if (...) {    # whatever
            # valid
            return ($self->{ valid } = 1);
        }
        else {
            return $self->invalid("bad value dude: $value");
        }
    }

=head1 DESCRIPTION

This module implements a base class object for representing fields in
web forms.  It is still in development and is subject to change.

NOTE: this module defines the class() method to get/set a CSS class.
The L<Badger::Class> class() method is aliased under bclass().

=head1 METHODS

=head1 new()

Constructor method used to create a new field object.  See the various
Contentity::Form::Field::* modules for information about the
parameter seach takes.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form::Field> in 2001,
became C<Badger::Web::Form::Field> in 2004 and was moved into the
C<Contentity> module set in April 2014.


=cut

# vim: expandtab shiftwidth=4:
