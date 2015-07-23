package Contentity::Configure::Sass;

use Contentity::Class
    version => 0.01,
    debug   => 1,
    base    => 'Contentity::Configure::App';

sub run {
    my $self   = shift;
    my $config = $self->config;

    $self->prompt_expr([
        [ selected => "Pre-building SASS:\n" ],
    ]);

    # do the pre-sass build
    my $options = {
        renderer => 'sassprep'
    };
    my $spbuilder = $site->builder($options);
    $self->debug("got sassprep builder: $spbuilder") if DEBUG;
    $spbuilder->build;

    $self->prompt_expr([
        [ selected => "Building SASS:\n" ],
    ]);


    $project->sass_builder($config)->build;
}


1;

__END__
