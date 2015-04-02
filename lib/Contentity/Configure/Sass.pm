package Contentity::Configure::Sass;

use Contentity::Class
    version => 0.01,
    debug   => 1,
    base    => 'Contentity::Configure::App';

sub run {
    my $self = shift;
    $self->prompt_expr([
        [ selected => "Building SASS:\n" ],
    ]);
    my $project  = $self->config('project');
    my $config = $self->config;

    $project->sass_builder($config)->build;
}


1;

__END__
