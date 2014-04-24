package Contentity::Context;

# DEPRECATED
# TODO - move to Contentity::Component::Context


use Badger::URL;
use Badger::Utils;
#use Badger::Web::Hub;
#use Badger::Web::Path;
use Badger::Debug 'debug_callers';

use Contentity::Request;
use Contentity::Class
    version     => 0.1,
    debug       => 0,
    import      => 'class',
    base        => 'Contentity::Base',
    accessors   => 'env hub site path request url',
    config      => 'hub!',

    mutators    => 'content_type',
    utils       => 'is_object weaken',
    constants   => 'HASH ARRAY',
    alias       => {
        output  => \&content,
    },
    constant    => {
        WEB_PATH        => 'Badger::Web::Path',
#       WEB_HUB         => 'Badger::Web::Hub',
        WEB_URL         => 'Badger::URL',
        REQUEST         => 'Contentity::Request',
        USER            => 'CR::Record::User',
        SESSION_COOKIE  => 'session_id',        # default over-ridden by config
    };

our $ACCEPT_TYPES  = {
    'text/plain'             => 'text',
    'text/html'              => 'html',
    'text/xml'               => 'xml',
    'text/json'              => 'json',
    'text/x-json'            => 'json',
    'application/xml'        => 'xml',
    'application/xhtml+xml'  => 'xhtml',
    'application/json'       => 'json',
    '*/*' => 'any',
    '*.*' => 'any',
    '*'   => 'any',
};


sub init {
    my ($self, $config) = @_;
    $self->debug("context init") if DEBUG;
    $self->configure($config);
    $self->init_context($config);
    #$self->{ apps } = [ ];
    #$self->{ data } = { };
    return $self;
}

sub init_context {
    my ($self, $config) = @_;
    $self->debug("context init") if DEBUG;

    my $env = delete $config->{ env }
        || return $self->error_msg( missing => 'env' );

    my $site = delete $config->{ site }
        || return $self->error_msg( missing => 'site' );

    my $request = $self->REQUEST->new($env);
    my $path    = $request->path_info;

    $self->{ env } = $env;
    weaken $self->{ env };

    $self->{ path         } = $self->WEB_PATH->new($path);
    $self->{ site         } = $site;
    $self->{ request      } = $request;
    $self->{ url          } = $self->WEB_URL->new($request->uri);
    $self->{ data         } = $config->{ data } || { };
    $self->{ apps         } = [ ];
    $self->{ options      } = { };
    $self->{ headers      } = { };
    $self->{ content      } = [ ];
    $self->{ content_type } = 'text/html';
    $self->{ status       } = 200;

#   $self->{ apache  } = $config->{ apache };       # not sure if we need this

    return $self;
}

sub response {
    my $self     = shift;
    my $response = $self->{ response } ||= $self->new_response;

    if (@_) {
        # update existing response with new params
        my $params = Badger::Utils::params(@_);
        my ($key, $value);

        foreach $key (qw{ status redirect }) {
            if ($value = delete $params->{ $key }) {
                $response->$key($value);
            }
        }
        if ($value = delete $params->{ content }) {
            $response->body($value);
        }
        if ($value = delete $params->{ type }) {
            $response->content_type($value);
        }
        if (%$params) {
            $self->error("Invalid response parameters: ", $self->dump_data($params));
        }
    }

    return $response;
}


sub new_response {
    my $self     = shift;
    my $request  = $self->request;
    my $response = $request->new_response(
        $self->{ status }
    );
    $response->headers(
        $self->{ headers }
    );
    $response->content_type(
        $self->{ content_type }
    );
    $response->body(
        $self->content
    );
    return $response;
}


sub content {
    my $self    = shift;
    my $content = $self->{ content };
    push(@$content, @_);
    return $content;
}

#sub env {
#    # TODO: set/get
#    shift->request->env;
#}



#-----------------------------------------------------------------------
# Request handling
#-----------------------------------------------------------------------

sub accept {
    my $self = shift;
    my $map  = $self->accept_map;
    return $map unless @_;
    my $type = shift;
    return $map->{ $type };
}

sub accept_map {
    my $self = shift;
    return $self->{ accept_map } ||= {
        map {
            my $x = $ACCEPT_TYPES->{ $_ };
            $x ? ($x => $_) : ()
        }
        @{ $self->request->accept }
    }
}



#-----------------------------------------------------------------------
# Context data
#-----------------------------------------------------------------------

sub data {
    my $self = shift;
    return  @_ >  1 ? $self->set(@_)
        :   @_ == 1 ? $self->get(@_)
        :             $self->{ data };
}

sub get {
    my ($self, $name) = @_;
    return $self->{ data } ->{ $name };
}


sub set {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $data = $self->{ data };

    while (my ($key, $value) = each %$args) {
        $data->{ $key } = $value;
    }

    return $self;
}

sub delete_data {
    my ($self, $name) = @_;
    return delete $self->{ data }->{ $name };
}


#-----------------------------------------------------------------------------
# Runtime processing options, e.g. 'debug', 'verbose', 'json', etc.
#-----------------------------------------------------------------------------

sub option {
    my $self = shift;
    return  @_ >  1 ? $self->set_option(@_)
        :   @_ == 1 ? $self->get_option(@_)
        :             $self->{ options };
}

sub get_option {
    my ($self, $name) = @_;
    return $self->{ options } ->{ $name };
}

sub set_option {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $opts = $self->{ options };

    while (my ($key, $value) = each %$args) {
        $opts->{ $key } = $value;
        $self->set($key, $value);       # also set template variable
    }

    return $self;
}


#-----------------------------------------------------------------------
# Session
#-----------------------------------------------------------------------

sub session {
    my $self = shift;

    if (DEBUG) {
        if ($self->{ session }) {
            $self->debug("using cached session");
        }
        else {
            $self->debug("creating new session for ", $self->url);
            $self->debug_callers;
        }
    }

    return  $self->{ session }
        ||= $self->new_session;
}

sub new_session {
    my $self     = shift;
    my $request  = $self->request;
    my $sessions = $self->hub->sessions;
    my $config   = $self->config->session;
    my $cookie   = $config->{ cookie } || $self->SESSION_COOKIE;
    my $sid      = $self->cookie($cookie);
    my ($session, $response);

    if ($sid && ($session = $sessions->fetch($sid->value))) {
        $self->debug("[SESSION] loaded existing session: $session->{ id }\n") if DEBUG;
    }
    else {
        $sid     = undef;
        $session = $sessions->create;
        $self->debug("[SESSION] created new session: $session->{ id }") if DEBUG;
    }

    if (! $sid) {
        $self->cookie(
            name  => $cookie,
            value => $session->id,
            %$config,
        );
    }

    return $session;
}


#-----------------------------------------------------------------------
# Access other resource
#-----------------------------------------------------------------------

sub config {
    shift->hub->config;
}

sub database {
    shift->hub->database;
}

sub model {
    shift->database->model;
}

sub cookie {
    shift->request->cookie(@_);
}

sub page {
    shift->data( Page => @_ );
}


#-----------------------------------------------------------------------
# Cleanup (probably not required, but helps me sleep at night)
#-----------------------------------------------------------------------

sub DESTROY {
    my $self = shift;
    $self->debug("DESTROY context $self") if DEBUG;
    delete $self->{ apache  };
    delete $self->{ request };
}


# do this at the end so that any references to 'delete' above are resolved
# to CORE::delete

*delete = \&delete_data;

1;
