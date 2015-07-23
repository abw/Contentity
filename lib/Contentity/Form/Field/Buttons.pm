package Contentity::Form::Field::Buttons;

use Contentity::Class::Form::Field
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Form::Field::Set',
    constants => 'BLANK DELIMITER ARRAY',
    config   => 'buttons|class:BUTTONS!',
    layout   => 'buttons',
    display  => 'none';

#our $LAYOUT  = 'buttons';
#our $DISPLAY = 'none';
our $BUTTONS = 'cancel submit';
our $METHODF = '%s_button';

sub init {
    my ($self, $config) = @_;

#    $self->debug("config: ", $self->dump_data($config));

    $config->{ fields }
        ||= $self->init_buttons($config);

    $self = $self->SUPER::init($config);

    # we don't want the buttons set to create any values in params
    delete $self->{ name };
    return $self;
}


sub init_buttons {
    my ($self, $config) = @_;
    my $buttons = $config->{ buttons } || $BUTTONS;

    # reference to an array of field definitions
    return $buttons
        if ref $buttons eq ARRAY;

    # otherwise we expect a string of whitespace delimited button names,
    # e.g. 'cancel submit'
    return $self->buttons(
        $buttons,
        $config
    )
}


sub buttons {
    my ($self, $names, $config) = @_;

    # split the list of button names
    $names = [ split(DELIMITER, $names) ]
        unless ref $names eq ARRAY;

    # call $self->button() for each
    return [
        map { $self->button($_, $config) }
        @$names
    ];
}


sub button {
    my ($self, $name, $config) = @_;
    my $method = sprintf($METHODF, $name);
    my $code   = $self->can($method)
        || return $self->error_msg( invalid => button => $name );

    # call the XXX_button($config) method
    return $self->$code($config);
}



sub cancel_button {
    my ($self, $config) = @_;
    return {
        type     => 'button',
        name     => 'cancel',
        layout   => $config->{ cancel_layout } || 'none',
        value    => $config->{ cancel_text   } || 'Cancel',
        link     => $config->{ cancel_link   } || '/index.html',
        class    => $config->{ cancel_class  } || 'cancel',
        tabindex => $config->{ cancel_tab_index },
        $self->button_icon_left($config, cancel => 'arrow-left'),
    };
}


sub reset_button {
    my ($self, $config) = @_;
    return {
        type     => 'button',
        name     => 'reset',
        display  => 'reset',
        layout   => $config->{ reset_layout } || 'none',
        value    => $config->{ reset_text   } || 'Reset',
        class    => $config->{ reset_class  } || 'reset',
        tabindex => $config->{ reset_tab_index },
        $self->button_icon_left($config, reset => 'undo'),
    };
}


sub submit_button {
    my ($self, $config) = @_;
    return {
        type     => 'submit',
        name     => 'submit',
        layout   => $config->{ submit_layout } || 'none',
        value    => $config->{ submit_text   } || 'Submit',
        class    => $config->{ submit_class  } || 'submit button-primary',
        tabindex => $config->{ submit_tab_index },
        $self->button_icon_right($config, submit => 'arrow-right'),
    };
}


sub button_icon {
    my ($self, $config, $name, $default, $right) = @_;
    my $n = $config->{"${name}_icon"}       || BLANK;
    my $l = $config->{"${name}_icon_left"}  || BLANK;
    my $r = $config->{"${name}_icon_right"} || BLANK;

    $self->debug("button icon for $name [${name}_icon:$n] [${name}_icon_left:$l] [${name}_icon_right:$r]") if DEBUG;

    if ($right) {
        # If the default icon is placed on the right then we look for a regular
        # leftward icon first.  We accept either XXX_icon or XXX_icon_left
        return $l
            ?  (icon       => $l)
            :  (icon_right => $r || $n || $default);
    }
    else {
        # otherwise a XXX_icon_right can over-ride the default XXX_icon
        return $r
            ?  (icon_right => $r)
            :  (icon       => $l || $n || $default);
    }
}


sub button_icon_left {
    shift->button_icon(@_, 0);
}

sub button_icon_right {
    shift->button_icon(@_, 1);
}

sub submit_field {
    shift->field('submit');
}

sub reset_field {
    shift->field('reset');
}


sub validate {
    return 1;
}

1;
