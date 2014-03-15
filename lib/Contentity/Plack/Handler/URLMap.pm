package Contentity::Plack::Handler::URLMap;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Plack::App::URLMap Contentity::Plack::Base';


sub map {
    my ($self, $uri, $app) = @_;
    my $maps = $self->{ mappings } ||= [ ];
    $uri =~ s{/$}{};
    push(
        @$maps, 
        [ $uri, qr/^\Q$uri\E/, $app ]
    );
}

sub call {
    my ($self, $env) = @_;
    my $maps   = $self->{ mappings };
    my $pinfo  = $env->{ PATH_INFO   };
    my $script = $env->{ SCRIPT_NAME };

    for my $map (@$maps) {
        my ($uri, $uri_re, $app) = @$map;
        my $path = $pinfo;

        no warnings 'uninitialized';

        $self->debug(
            "Matching request (Path=$path) and the map (Path=$uri)"
        ) if DEBUG;

        next unless $uri  eq '' or $path =~ s!$uri_re!!;
        next unless $path eq '' or $path =~ m!^/!;

        $self->debug("matched") if DEBUG;

        return $self->found($env, $app, $path, $script . $uri);
    }

    $self->debug("All matching failed.") if DEBUG;

    # Bah! We have to re-implement the whole method just to change this one line
    return $self->not_found($pinfo);
}

sub found {
    my ($self, $env, $app, $path_info, $script_name) = @_;
    my $orig_path_info   = $env->{ PATH_INFO   };
    my $orig_script_name = $env->{ SCRIPT_NAME };

    $env->{ PATH_INFO   }  = $path_info;
    $env->{ SCRIPT_NAME }  = $script_name;

    return $self->response_cb(
        $app->($env), 
        sub {
            $env->{ PATH_INFO   } = $orig_path_info;
            $env->{ SCRIPT_NAME } = $orig_script_name;
        }
    );
}

sub not_found {
    my $self = shift;
    $self->debug("returning 404 as undef");
    #return [404, [ 'Content-Type' => 'text/plain' ], [ "Not Found" ]];
    return undef;
}


1;
