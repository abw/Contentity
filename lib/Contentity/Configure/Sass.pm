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

    if ($config->{ sass }) {
        $self->prompt_expr([
            [ selected => "Skipping pre-processing (-s/--sass option specified)\n" ],
        ]);
    }
    else {
        # do the pre-sass build
        $self->prompt_expr([
            [ selected => "Pre-building SASS (use -s/--sass option to skip this step):\n" ],
        ]);
        $site->builder( renderer => 'sassprep' )->build;
    }

    $self->prompt_expr([
        [ selected => "Building SASS:\n" ],
    ]);

    $self->debug("site:$site") if DEBUG;
    $self->debug("project:$project") if DEBUG;

    $site->component('builder.sass', $config)->build;
}


1;

__END__
