package Contentity::Template;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    import    => 'class',
    utils     => 'params',
    accessors => 'engine',
    constant  => {
        ENGINE => 'Template',
    },
    messages  => {
        engine_init   => 'Failed to initialise TT: %s',
        engine_render => 'Failed to render %s: %s',
    };


sub init {
    my ($self, $config) = @_;
    my $ttcfg = { };
    my (@pre, @post);

    $ttcfg->{ INCLUDE_PATH } = $config->{ path }
        || return $self->error_msg( missing => 'path' );

    for (qw( config before header )) {
        push(@pre, $config->{ $_ })
            if $config->{ $_ };
    }

    for (qw( footer after )) {
        push(@post, $config->{ $_ })
            if $config->{ $_ };
    }

    $ttcfg->{ ENCODING     } = $config->{ encoding };
    $ttcfg->{ WRAPPER      } = $config->{ wrapper  };
    $ttcfg->{ PRE_PROCESS  } = \@pre  if @pre;
    $ttcfg->{ POST_PROCESS } = \@post if @post;

    $self->debug("Template config: ", $self->dump_data($ttcfg)) if DEBUG;

    $ttcfg->{ engine } = $config->{ engine };   # ick
    $self->init_engine($ttcfg);

    return $self;
}

sub init_engine {
    my ($self, $config) = @_;
    my $engine = delete $config->{ engine } 
        || $self->ENGINE;

    class($engine)->load;

    $self->{ engine } = $engine->new($config)
        || return $self->error_msg( engine_init => $engine->error );
}

sub render {
    my $self   = shift;
    my $name   = shift;
    my $params = params(@_);
    my $engine = $self->engine;
    my $output;

    $engine->process($name, $params, \$output)
        || return $self->error_msg( engine_render => $name, $engine->error );

    return $output;
}

sub process {
    my $self   = shift;
    my $name   = shift;
    my $engine = $self->engine;
    $self->debug("PROCESS $name") if DEBUG;
    return $engine->process($name, @_)
        || $self->error_msg( engine_render => $name, $engine->error );
}


1;
