package Contentity::Component::Form;

use Contentity::Class
    version   => 0.05,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'bclass',      # use Plan B so class() can be a CSS class
    accessors => 'fields',
    mutators  => 'encoding charset method action name title layout class style',
    utils     => 'self_params split_to_list',
    codec     => 'html',
    config    => [
        'encoding|class:ENCODING|method:ENCODING',
        'charset|class:CHARSET|method:CHARSET',
        'method|class:METHOD|method:METHOD',
        'action|class:ACTION',
        'name|class:NAME',
        'class|class:CLASS',
        'style|class:STYLE',
        'title|class:TITLE',
        'layout|class:LAYOUT|form',
        'fragment|class:FRAGMENT',
    ],
    constant => {
        ENCODING => 'application/x-www-form-urlencoded',
        CHARSET  => 'utf-8',
        METHOD   => 'POST',
    },
    messages  => {
        no_name       => 'Missing name in field specification',
        no_field      => 'Missing field specification after %s',
        bad_field     => 'Invalid field specification (not a hash ref): %s',
        no_such_field => 'Invalid field specified: %s',
    };


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( init_form => $config ) if DEBUG;
    $self->configure($config);
    $self->init_form($config);
    return $self;
}

sub init_form {
    my ($self, $config) = @_;
    $self->init_fields($config);
    $self->init_values($config);
}

sub init_fields {
    my ($self, $config) = @_;
    my $names  = $self->bclass->list_vars(
        FIELDS => $config->{ fields }
    );
    my $fields = $self->{ fields } = $self->form_fields->field_list($names);
    my $field  = $self->{ field  } = { };

    # Invite all fields (and field sets) to register their name with us
    foreach my $f (@$fields) {
        $f->register($field);
    }
}

sub init_values {
    my ($self, $config) = @_;

    $self->set($config->{ values })
        if $config->{ values };
}

#-----------------------------------------------------------------------------
# field methods
#-----------------------------------------------------------------------------

sub field {
    my $self = shift;
    return $self->{ field } unless @_;

    my $name = shift;
    return $self->{ field }->{ $name };
}

sub each_field_method {
    my ($self, $method, @args) = @_;
    foreach my $field (@{ $self->{ fields } }) {
        $field->$method(@args);
    }
}

sub set {
    my ($self, $params) = self_params(@_);
    $self->each_field_method( set => $params );
}

sub reset {
    my $self = shift;
    $self->each_field_method( reset => @_ );
}

sub values {
    my $self   = shift;
    my $params = shift || { };
    my $fields = $self->{ fields };
    my $values = { };

    $self->each_field_method( values => $values );

    my $extra = $self->{ extra_params } || return $values;

    $extra = split_to_list($extra);

    $self->debug("extra params for form: ", $self->dump_data($extra)) if DEBUG;

    foreach my $p (@$extra) {
        $values->{ $p } = $params->{ $p }
            if defined $params->{ $p }
            && length  $params->{ $p };
    }

    $self->debug_data( values => $values ) if DEBUG;

    return $values;
}

sub OLD_values {
    my $self = shift;
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my ($name, $value, $field);

    while (($name, $value) = each %$args) {
        $field = $self->field($name) || next;
        $field->value($value);
        $self->debug("set field $name value to $value\n") if $DEBUG;
    }
}

sub form_fields {
    shift->workspace->form_fields;
}


1;

__END__
package Badger::Web::Form;
use Badger::Class::Methods;
use Badger::Web::Form::Fields;
use Badger::Web::Class

sub fieldset {
    my $self = shift;
    my $name = shift || return $self->error('no fieldset name specified');
    return $self->pkghash( FIELDSET => $name );
}

sub validate {
    my $self   = shift;
    my $params = shift || { };
    my $good   = $self->{ valid_fields   } = [ ];
    my $bad    = $self->{ invalid_fields } = [ ];
    my $errors = $self->{ errors         } = [ ];
    my $nfail  = 0;
    my ($field, $name, $value);

    foreach my $field (@{ $self->{ fields } }) {
        # if the field has a name then we extract the
        # relevant parameter, otherwise we pass the whole
        # params over (e.g. for field sets to handle)
        if ($name = $field->{ name }) {
            $self->debug("setting value from $name\n") if $DEBUG;
            $value = $params->{ $name };
        }
        else {
            $self->debug("setting value to PARAMS (", join(', ', keys %$params), ")\n") if $DEBUG;
            $value = $params;
        }

        if ($field->validate($value, $params)) {
            push(@$good, $field->{ valid_fields } ? @{ $field->{ valid_fields } } : $field);
            $params->{ $name } = $field->value() if $name;
        }
        else {
            push(@$bad, $field->{ invalid_fields } ? @{ $field->{ invalid_fields } } : $field);
            push(@$errors, $field->{ errors } ? @{ $field->{ errors } } : $field->{ error });
            $nfail++;
        }
    }

    $self->{ errors } = 0 unless $nfail;
    return $nfail ? 0 : 1;
}

sub valid_fields {
    return $_[0]->{ valid_fields };
}

sub invalid_fields {
    return $_[0]->{ invalid_fields };
}

sub field_errors {
    my $self    = shift;
    my $invalid = $self->invalid_fields || [];
    return {
        map { ($_->{ name }, $_->{ error }) }
        @$invalid
    };
}

sub errors {
    my $self    = shift;
    my $invalid = $self->invalid_fields || [];
    my $errors  = [
        map { $_->{ error } }
        @$invalid
    ];
    return wantarray
        ? @$errors
        :  $errors;
}

sub valid {
    my $self = shift;
    return $self->{ errors }
        ? 0 : 1;
}

sub invalid {
    my $self = shift;

    if (@_) {
        my $error  = $self->{ invalid }   = join('', @_);
        my $errors = $self->{ errors  } ||= [ ];
        unshift(@$errors, $error);
    }
    return $self->{ invalid }; # || $self->{ errors };
}

sub invalidate_field {
    my $self  = shift;
    my $name  = shift;
    my $field = $self->field($name)
        || return $self->error_msg( no_such_field => $name );

    $field->invalid(@_);
    my $invalids = $self->{ invalid_fields } ||= [ ];
    push(@$invalids, $field);
#    my $error    = $field->error;
#    my $errors   = $self->{ errors         } ||= [ ];
#    push(@$errors, $field->error);
#    return ($self->{ invalid } = 1);
}

sub present {
    my ($self, $view) = @_;
    # reset internal tabindex counter
    $self->{ tab_index } = 1;
    $view->include('layout/' . $self->{ layout }, { form => $self });
}

sub content {
    my ($self, $view) = @_;
    my $output = '';
    my @fields = @{ $self->{ fields } };
    my $args   = { };

    # The 'first' (and 'last') args are like TT's loop.first and loop.last and
    # are used by form/layout/field to add the CSS classes for rounded corners
    # in the appropriate places.  However, the first field shouldn't have rounded
    # corners if there is a title or error message superceding it.
    $args->{ first } = 1 unless $self->{ invalid } || $self->{ title };

    # if title, error, etc.
    # first/last/etc.
    while (@fields) {
        my $field = shift @fields;
        $args->{ last } = @fields ? 0 : 1;
        $output .= $field->present($view, $args);
        $args->{ first } = 0;
    }
    return $output;
}

sub tab_index {
    my $self = shift;
    $self->{ tab_index } ||= 1;
    $self->{ tab_index } = shift if @_ && $_[0];
    return $self->{ tab_index }++;
}

sub last_tab_index {
    my $self = shift;
    $self->{ tab_index } ||= 1;
    return $self->{ tab_index };
}

sub tab {
    my $self = shift;
    return  'tabindex="' . $self->tab_index(@_) . '"';
}

sub css {
    my $self = shift;
    join(
        ' ',
        map {
            defined $self->{ $_ }
                ? $_ . '="' . encode($self->{ $_ }) . '"'
                : ()
        }
        qw( class style )
    );
}

sub focus {
    my $self  = shift;
    my ($field, $list);

    if ( (($list = $self->{ invalid_fields }) && @$list)
      || (($list = $self->{ fields }) && @$list) ) {
          my $n = 0;
          while ($n < @$list) {
              if ($list->[$n]->can_focus) {
                  $field = $list->[$n];
                  last;
              }
              $n++;
          }
    }
    return '' unless $field;
    my @nodes = ($self->{ name }, $field->name);
    return join('.', grep { defined $_ } @nodes);
}

1;
__END__

=head1 NAME

Badger::Web::Form - generate and validate web forms

=head1 SYNOPSIS

    package Badger::Web::Form::Example;
    use base 'Badger::Web::Form';

    our $FIELDS = [
        username => {
            label     => 'Username',
            mandatory => 1,
            validate  => 'username',
        },
        password => {
            label     => 'Password',
            type      => 'password',
            mandatory => 1,
            validate  => 'username',
        },
    ];

    package main;
    my $form = Badger::Web::Form::Example->new();
    my $params = {
        username => 'arthur',
        password => 'dent42',
    };
    if ($form->validate($params)) {
        # good
    }
    else {
        print "Bad form: ", $form->error();
    }

=head1 DESCRIPTION

This module implements a base class for creating forms.  It is still
in development and is subject to change.

NOTE: this module defines the class() method to get/set a CSS class.
The L<Badger::Class> class() method is aliased under bclass().

=head1 METHODS

=head1 new()

Constructor method used to create a new form object.

=head1 fieldset($name)

Fetch a set of fields defined in a C<$FIELDSET> package variable hash.

=head1 field($name)

Fetch a named field either from the pre-defined list of fields in the form
or from the $FIELDS package variable hash.

=head1 name()

Returns the form name.

=head1 action()

Returns the form action.

=head1 method()

Returns the form method.

=head1 encoding()

Returns the form encoding.

=head1 values(\%values)

Populate the form fields with the values passed as a hash reference.  Calls the
C<value()> method on each field object.

=head1 validate(\%values)

Calls the C<validate()> method for each field in the form, using the values passed as a
reference to a hash array.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form> in 2001,
became C<Badger::Web::Form> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut