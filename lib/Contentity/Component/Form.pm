package Contentity::Component::Form;

use Contentity::Class
    version   => 0.05,
    debug     => 0,
    base      => 'Contentity::Component',
    import    => 'bclass',      # use Plan B so class() can be a CSS class
    accessors => 'fields',
  #  mutators  => 'encoding charset method action name class style title layout fragment',
    utils     => 'self_params split_to_list join_uri strip_hash strip_hash_undef',
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
        'layout|class:LAYOUT=form',
        'fragment|class:FRAGMENT',
        'extra_params',
        'widget',
        'params',
    ],
    constant => {
        ENCODING      => 'application/x-www-form-urlencoded',
        CHARSET       => 'utf-8',
        METHOD        => 'POST',
        LAYOUT_PREFIX => 'layout',
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

    # set all the configuration options into a style
    my $style = $self->{ style } = { };
    $self->configure($config, $style);
    $self->init_form($config);

    $self->debug_data("form style" => $self->{ style }) if DEBUG;
    return $self;
}

sub init_form {
    my ($self, $config) = @_;
    $self->{ extra_params } = $config->{ extra_params };
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

    $self->debug_data( form_fields => $field ) if DEBUG;
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
    my $params = shift || $self->params;
    my $fields = $self->{ fields };
    my @values;

    foreach my $field (@$fields) {
        push(@values, $field->values);
    }

    my $values = { @values };
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

sub field_values {
    my $self   = shift;
    my $params = shift || $self->params;
    my $fields = $self->{ field };
    my $extra  = $self->{ extra_params };
    my $values = {
        map  { $fields->{ $_ }->field_values($_) }
        grep { defined $fields->{ $_ } }
        keys %$fields
    };

    return $values unless $extra;

    $extra = split_to_list($extra);
    $self->debug("extra params for form: ", $self->dump_data($extra)) if DEBUG;

    foreach my $p (@$extra) {
        $values->{ $p } = $params->{ $p }
            if defined $params->{ $p }
            && length  $params->{ $p };
    }

    $self->debug("field_values: ", $self->dump_data($values)) if DEBUG;

    return $values;
}

sub stripped_field_values {
    strip_hash(
        shift->field_values
    );
}

sub defined_field_values {
    strip_hash_undef(
        shift->field_values
    );
}

sub set_values {
    my ($self, $params) = self_params(@_);
    my ($name, $value, $field);

    while (($name, $value) = each %$params) {
        $field = $self->field($name) || next;
        $field->value($value);
        $self->debug("set field $name value to $value\n") if $DEBUG;
    }
}

sub form_fields {
    shift->workspace->form_fields;
}


sub submitted {
    my $self   = shift;
    my $params = shift || $self->params;
    my $field  = $self->submit_field || return undef;
    if (DEBUG) {
        $self->debug("checking if ", $field->name, " is defined: ", $params->{ $field->name } || '' );
        $self->debug("params are: ", $self->dump_data($params) );
    }
    return $params->{ $field->name };
}


sub submit_field {
    my $self = shift;
    my ($fields, $field);

    return $self->{ submit_field }
        if exists $self->{ submit_field };

    $fields = $self->{ fields };

    $self->{ submit_field } = undef;

    foreach $field (@$fields) {
        $self->debug("field type: ", $field->type) if DEBUG;
        my $submitter = $field->submit_field;
        if ($submitter) {
            $self->{ submit_field } = $submitter;
            last;
        }
    }

    return $self->{ submit_field };
}

sub params {
    my $self = shift;
    if (@_) {
        $self->{ params } = shift;
    }
    return $self->{ params } ||= { };
}

#-----------------------------------------------------------------------------
# Presentation methods
#-----------------------------------------------------------------------------

sub present {
    my ($self, $view, $args) = @_;
#    my $with = $self->present_with($args);

    $self->debug("presenting form") if DEBUG;

    # reset internal tab_index counter
    $self->{ tab_index } = 1;

    my $uri = join_uri($self->LAYOUT_PREFIX, $self->layout);

    $self->debug("presenting form: $uri") if DEBUG;
    $view->include(
        $uri,
        { form => $self, args => $args }
    );
}

#sub merge_style {
#    my $self  = shift;
#    my $style = $self->style;
#
#}

sub content {
    my ($self, $view) = @_;
    my $output = '';
    my @fields = @{ $self->{ fields } };

    while (@fields) {
        my $field = shift @fields;
        $output .= $field->present($view);
    }

    return $output;
}

#-----------------------------------------------------------------------------
# Validation
#-----------------------------------------------------------------------------

sub validate {
    my $self   = shift;
    my $params = shift || $self->params;
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

sub validation {
    my $self  = shift;
    my $valid = $self->validate(@_);
    my $data  = {
        valid          => $valid,
        fields         => { },
        values         => { },
        valid_fields   => [ ],
        invalid_fields => [ ],
        errors         => [ ],
        field_errors   => { },
    };
    $self->field_list_validation_data($data, $self->{ valid_fields }),
    $self->field_list_validation_data($data, $self->{ invalid_fields }),
    return $data;
}

sub field_list_validation_data {
    my ($self, $data, $list) = @_;
    for my $field (@$list) {
        $field->validation_data($data);
    }
}

sub valid {
    my $self = shift;
    return $self->{ errors } ? 0 : 1;
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
        || return $self->error_msg( invalid => field => $name );

    $field->invalid(@_);
    my $invalids = $self->{ invalid_fields } ||= [ ];
    push(@$invalids, $field);
}

sub valid_fields {
    return $_[0]->{ valid_fields };
}

sub invalid_fields {
    return $_[0]->{ invalid_fields };
}

sub errors {
    my $self    = shift;
    my $invalid = $self->invalid_fields || [];
    my $errors  = [
        map { $_->{ error } }
        @$invalid
    ];
    # add in any general form invalid message
    unshift(@$errors, $self->{ invalid }) if $self->{ invalid };
    return wantarray
        ? @$errors
        :  $errors;
}

sub field_errors {
    my $self    = shift;
    my $invalid = $self->invalid_fields || [];
    return {
        map { ($_->{ name }, $_->{ error }) }
        @$invalid
    };
}


#-----------------------------------------------------------------------------
# Add methods to set/get the current style values
#-----------------------------------------------------------------------------

bclass->methods(
    map {
        my $item = $_;
        $item => sub {
            return @_ > 1
                ? ($_[0]->{ style }->{ $item } = $_[1])
                :  $_[0]->{ style }->{ $item }
        }
    }
    qw( encoding charset method action name class style title layout fragment widget )
);

sub default_action {
    my $self  = shift;
    my $style = $self->{ style };
    if (@_) {
        $style->{ action } ||= shift;
    }
    return $style->{ action };
}

1;

__END__

=head1 NAME

Contentity::Component::Form - generate and validate web forms

=head1 DESCRIPTION

This module implements an object to represent a web form.  Forms are
usually populated from a YAML configuration file in the C<config/forms>
directory.

=head1 ACCESSOR METHODS

The following methods can be used to get (or set when called with an
argument) various configuration values for the form.

=head2 action()

The C<action> URL.

=head2 class()

Any CSS classes to be added to the form element.

=head2 encoding()

The character encoding added as an C<enctype> attribute.  Defaults to C<application/x-www-form-urlencoded>

=head2 charset()

The character set added as an C<accept-charset> attribute.  Defaults to
C<utf-8>.

=head2 default_action($action)

This sets the L<action()> for the form if it's not already set.  This
is typically used by a web application loading the form that want to
provide a sensible default but not overwrite an explicit value set in
the form configuration.

=head2 fragment()

An additional C<#whatever> fragment to be added to the end of the
C<action> URL.

=head2 layout()

An alternate layout template to use (typically located somewhere
like C<templates/library/form/layout>) for the form.  Defaults to C<form>.

=head2 method()

The submission method added as the C<method> attribute.  Defaults to C<POST>.

=head2 name()

The form name.  Added as the C<name> attribute with a C<_form> suffix.

=head2 style()

Additional styling, added as the C<style> attribute.

=head2 title()

A title for the form.  Typically rendered by a C<form/layout/title> template
if defined.

=head2 widget()

The name of a widget to bind to the form element.

=head1 FIELD METHODS

=head2 fields()

Returns a list of all fields.

=head2 field($name)

Returns a field by name.  If no name is specified then it returns a
hash array indexing all fields by name.  The following lines of code
both do the same thing:

    $field = $form->field('foo');
    $field = $form->field->{ foo };

=head1 PARAMETER VALIDATION METHODS

=head2 params(\%params)

Use to set or get a reference to a hash array of request parameters.

=head2 values(\%values)

Populate the form fields with the values passed as a hash reference.  Calls the
C<value()> method on each field object.

=head2 validate(\%params)

Calls the C<validate()> method for each field in the form.  If a reference
to a hash of parameters is passed then those are used, otherwise the methods
calls its own L<params()> method to fetch any parameters that may have
been previously set via the same L<params()> method.

=head2 field_values()

Returns a hash reference to all the post-validation values for each field.

=head1 NOTE

This documentation is incomplete.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2015 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 HISTORY

This module started out life as C<WebKit::Form> in 2001,
became C<Badger::Web::Form> in 2004 and was moved into the
C<Contentity> module set in April 2014.

=cut
