package Contentity::Component::Plack;

use Plack::Request;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'env request',
    auto_can  => 'auto_can',
    constant  => {
        REQUEST => 'Plack::Request'
    };


sub init_component {
    my ($self, $config) = @_;

    $self->debug(
        "Plack init_component() => ",
        $self->dump_data($config)
    ) if DEBUG;

    return $self;
}


sub app {
    my $self    = shift;
    my $project = $self->project;

    return sub {
        my $env  = shift;
        my $req  = $self->REQUEST->new($env);
        my $host = $env->{ SERVER_NAME } || return $self->error_msg( missing => 'SERVER_NAME' );
        my $path = $req->path_info;
        my ($site, $meta, $res);

        CLASS->debug("env: ", CLASS->dump_data($env));

        eval {
            $site = $project->domain_site($host)
                || die "No site ", $project->error, "\n";

            $meta = $site->match_route($path);
            $self->debug(
                "routed path $path to meta: ", 
                $self->dump_data($meta)
            );
        };
        if ($@) {
            Cog->debug("BARF: $@");
            my $error = $@;
            $res = $req->new_response(500);
            $res->content_type('text/html');
            $res->body("ERROR: $error");
        }
        else {
            $res = $req->new_response(200);
            $res->content_type('text/html');
            $res->body("Hello World from " . $site->urn);
     #   $res->body("\n\nsite: ", $self->dump_data($site));
        }
        return $res->finalize;
    }
}

1;
