package Contentity::Template;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Template Contentity::Base',
    utils     => 'self_params params
                  commas falselike floor id_safe inflect integer
                  plural plurality random truelike uri_safe
                  H data_attrs',
    codecs    => 'html json',
    constants => 'ARRAY';

our $ITEM_VMETHODS = {
    commas        => \&commas,
    false         => \&falselike,
    floor         => \&floor,
    html          => \&encode_html,
    #html_syntax   => \&html_syntax,
    idsafe        => \&id_safe,
    id_safe       => \&id_safe,
    inflect       => \&inflect,
    integer       => \&integer,
    lc            => \&CORE::lc,
    lower         => \&CORE::lc,
    lcfirst       => \&CORE::lcfirst,
    plural        => \&plural,
    plurality     => \&plurality,
    random        => \&random,
    true          => \&truelike,
    uc            => \&CORE::uc,
    upper         => \&CORE::uc,
    ucfirst       => \&CORE::ucfirst,
    urisafe       => \&uri_safe,
    uri_safe      => \&uri_safe,
};

our $HASH_VMETHODS = {
    json          => \&encode_json,
    data_attrs    => \&data_attrs,
};

our $LIST_VMETHODS = {
    json          => \&encode_json,
    class_attr    => \&class_attr
};


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub new {
    my ($class, $config) = self_params(@_);

    $class->debug_data(
        "Contentity::Template engine params: ",
        $config
    ) if DEBUG;

    my $self = $class->SUPER::new($config);

    $self->init_vmethods($config);
    $self->init_template($config);

    return $self;
}

sub init_vmethods {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->define_vmethods(
        item => $class->hash_vars(
            ITEM_VMETHODS => $config->{ item_vmethods }
        )
    );
    $self->define_vmethods(
        hash => $class->hash_vars(
            HASH_VMETHODS => $config->{ hash_vmethods }
        )
    );
    $self->define_vmethods(
        list => $class->hash_vars(
            LIST_VMETHODS => $config->{ list_vmethods }
        )
    );
}

sub define_vmethods {
    my ($self, $type, $methods) = @_;
    my $context = $self->context;

    while (my ($k, $v) = each %$methods) {
        $self->debug("adding $type virtal method: $k") if DEBUG;
        $context->define_vmethod( item => $k => $v );
    }
}

sub init_template {
    # stub for subclasses
    my $self = shift;
}


#-----------------------------------------------------------------------------
# Rendering methods
#-----------------------------------------------------------------------------

sub render {
    my $self   = shift;
    my $name   = shift;
    my $params = params(@_);
    my $output;

    $self->process($name, $params, \$output)
        || die $self->error;

    return $output;
}


#-----------------------------------------------------------------------------
# Misc stuff
#-----------------------------------------------------------------------------


sub class_attr {
    my $item = shift;
    $item = '' unless defined $item;
    $item = join(' ', @$item) if ref $item eq ARRAY;
    $item = qq( class="$item") if length $item;
    return $item;
}


1;
