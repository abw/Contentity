package Contentity::Template;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Template Contentity::Base',
    utils     => 'self_params params extend
                  commas falselike floor id_safe inflect integer
                  plural plurality random truelike uri_safe
                  ucwords snake_up snake_down
                  H html_attrs data_attrs',
    codecs    => 'html json',
    constants => 'ARRAY TRUE FALSE';

our $OPTIONS = {
    ANYCASE        => 1,
    OUTLINE_TAG    => '%%',
    RECURSION      => 1,
    # subclasses may add more here
};
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
    lc            => sub { lc(shift) },
    lines         => sub { [ split(/\n/, shift) ] },
    lower         => sub { lc(shift) },
    lcfirst       => sub { lcfirst(shift) },
    plural        => \&plural,
    plurality     => \&plurality,
    random        => \&random,
    snake_up      => \&snake_up,
    snake_down    => \&snake_down,
    true          => \&truelike,
    uc            => sub { uc(shift) },
    upper         => sub { uc(shift) },
    ucfirst       => sub { ucfirst(shift) },
    ucwords       => \&ucwords,
    urisafe       => \&uri_safe,
    uri_safe      => \&uri_safe,
};

our $HASH_VMETHODS = {
    json          => \&encode_json,
    data_attrs    => \&data_attrs,
    html_attrs    => \&html_attrs,
};

our $LIST_VMETHODS = {
    json          => \&encode_json,
    class_attr    => \&class_attr
};

our $VARIABLES = {
    True    => TRUE,
    true    => TRUE,
    'TRUE'  => TRUE,
    False   => FALSE,
    false   => FALSE,
    'FALSE' => FALSE,
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

    my $klass = class($class);

    $config = extend(
        { },
        $klass->hash_vars('OPTIONS'),
        $config
    );

    $config->{ VARIABLES } = $klass->hash_vars(
        VARIABLES => $config->{ VARIABLES }
    );

    $class->debug_data( tt_config => $config ) if DEBUG;

    my $self = $class->SUPER::new($config);

    $self->init_vmethods($config);
    $self->init_filters($config);
    $self->init_template($config);

    return $self;
}

sub init_vmethods {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->debug("looking for vmethods in $class") if DEBUG;

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
        $context->define_vmethod( $type => $k => $v );
    }
}

sub init_filters {
    my ($self, $config) = @_;
    my $class = $self->class;

    $self->debug("looking for filters in $class") if DEBUG;

    $self->define_filters(
        $class->hash_vars(
            FILTERS => $config->{ filters }
        )
    );
}

sub define_filters {
    my ($self, $filters) = @_;
    my $context = $self->context;

    while (my ($k, $v) = each %$filters) {
        $self->debug("adding filter: $k") if DEBUG;
        $context->define_filter( $k => $v );
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
