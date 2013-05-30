package Contentity::Template;

use Template;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Base',
    utils     => 'params',
    accessors => 'tt2',
    messages  => {
        tt_init   => 'Failed to initialise TT: %s',
        tt_render => 'Failed to render %s: %s',
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

    $self->debug("Template config: ", $self->dump_data($ttcfg));

    $self->{ tt2 } = Template->new($ttcfg)
        || return $self->error_msg( tt_init => Template->error );

    return $self;
}

sub render {
    my $self   = shift;
    my $name   = shift;
    my $params = params(@_);
    my $tt2    = $self->tt2;
    my $output;

    $tt2->process($name, $params, \$output)
        || return $self->error_msg( tt_render => $name, $tt2->error );

    return $output;
}


1;
