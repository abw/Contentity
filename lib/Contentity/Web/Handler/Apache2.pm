package Contentity::Web::Handler::Apache2;

use URI;
use URI::Escape;
use Contentity::Class
    version   => 0.5,
    debug     => 0,
    base      => 'Contentity::Web::Handler Plack::Handler::Apache2',
    constants => ':http_status :html TRUE FALSE ARRAY CODE',
    accessors => 'apache';


#-----------------------------------------------------------------------------
# Handler hook method
#-----------------------------------------------------------------------------

sub handler : method {
    my ($class, $apache) = @_;
    my $self = bless { apache => $apache }, $class;
    my $response = eval {
        $self->handle;
    };
    if ($@) {
        return $self->handle_error($@);
    }
    else {
        return $response;
    }
}

sub handle_app {
    my ($self, $app) = @_;
    $self->call_app($self->apache, $app);
}

sub handle_error {
    my $self = shift;
    my $apache = $self->apache;
    $apache->content_type(TEXT_HTML . '; ' . CHARSET_UTF8);
    $apache->status(SERVER_ERROR);
    $apache->print(
      '<html><head><title>Application Error</title></head><body>',
      "An uncaught error occurred: <pre>", @_, "</pre>",
      '</body></html>',
    );
    return;
}

# default handle() method

sub handle {
    my $self = shift;
    $self->handle_app(
        $self->app
    );
}

#-----------------------------------------------------------------------------
# Methods to fetch configuration values from Apache directory/location config
#-----------------------------------------------------------------------------

sub config {
    my ($self, $item) = @_;
    return $self->apache->dir_config($item)
        || $self->SUPER::config($item);
}

#-----------------------------------------------------------------------------
# Copied and mangled from Plack::Handler::Apache2
#-----------------------------------------------------------------------------

sub call_app {
    my ($self, $req, $app) = @_;
    $self->debug("call_app") if DEBUG;
    my $env = $self->prepare_env($req, $app);
    my $res = $app->($env);
    $self->debug_data("handle_response", $res) if DEBUG;
    return $self->handle_response($req, $app, $env, $res);
}

sub prepare_env {
    my ($self, $r, $app) = @_;

    $r->subprocess_env; # let Apache create %ENV for us :)

    my $env = {
        %ENV,
        'psgi.version'           => [ 1, 1 ],
        'psgi.url_scheme'        => ($ENV{HTTPS}||'off') =~ /^(?:on|1)$/i ? 'https' : 'http',
        'psgi.input'             => $r,
        'psgi.errors'            => *STDERR,
        'psgi.multithread'       => FALSE,
        'psgi.multiprocess'      => TRUE,
        'psgi.run_once'          => FALSE,
        'psgi.streaming'         => TRUE,
        'psgi.nonblocking'       => FALSE,
        'psgix.harakiri'         => TRUE,
        'psgix.cleanup'          => TRUE,
        'psgix.cleanup.handlers' => [],
    };

    if (defined(my $HTTP_AUTHORIZATION = $r->headers_in->{Authorization})) {
        $env->{HTTP_AUTHORIZATION} = $HTTP_AUTHORIZATION;
    }

    # If you supply more than one Content-Length header Apache will
    # happily concat the values with ", ", e.g. "72, 72". This
    # violates the PSGI spec so fix this up and just take the first
    # one.
    if (exists $env->{CONTENT_LENGTH} && $env->{CONTENT_LENGTH} =~ /,/) {
        no warnings qw(numeric);
        $env->{CONTENT_LENGTH} = int $env->{CONTENT_LENGTH};
    }

    # Actually, we can not trust PATH_INFO from mod_perl because mod_perl squeezes multiple slashes into one slash.
    my $uri = URI->new("http://".$r->hostname.$r->unparsed_uri);

    $env->{PATH_INFO} = uri_unescape($uri->path);

    $self->fixup_path($r, $env);

    return $env;
}


sub handle_response {
    my ($self, $req, $app, $env, $res) = @_;

    $self->debug("Apache2 handle_response") if DEBUG;

    if (ref $res eq ARRAY) {
        Plack::Handler::Apache2::_handle_response($req, $res);
    }
    elsif (ref $res eq CODE) {
        $res->(sub {
            Plack::Handler::Apache2::_handle_response($req, $_[0]);
        });
    }
    else {
        die "Bad response $res";

        # Nope, instead we're going to assume it's an Apache response code so we
        # can have simple Auth handlers that don't result in the code below trying
        # to send output before the response phase has begun
        # return $res;
    }

    if (@{ $env->{'psgix.cleanup.handlers'} }) {
        $req->push_handlers(
            PerlCleanupHandler => sub {
                for my $cleanup_handler (@{ $env->{'psgix.cleanup.handlers'} }) {
                    $cleanup_handler->($env);
                }

                if ($env->{'psgix.harakiri.commit'}) {
                    $req->child_terminate;
                }
            },
        );
    } else {
        if ($env->{'psgix.harakiri.commit'}) {
            $req->child_terminate;
        }
    }

    return Apache2::Const::OK;
}

1;

__END__
