package Contentity::Configure::Sass;

use Contentity::Class
    version => 0.01,
    debug   => 0,
    base    => 'Contentity::Configure::App';

sub run {
    my $self    = shift;
    my $config  = $self->config;
    my $site    = $self->workspace;
    my $project = $site->project;

    $self->debug("RUN") if DEBUG;

    #$self->prompt_expr([
    #    [ selected => "Pre-building SASS:\n" ],
    #]);

    $self->prompt_expr([
        [ selected => "Building SASS:\n" ],
    ]);

    $self->debug("site:$site") if DEBUG;
    $self->debug("project:$project") if DEBUG;

    #$site->sass_builder($config)->build;
    $site->component('builder.sass')->build;
}


1;

__END__
