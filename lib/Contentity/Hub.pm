package Contentity::Hub;

use Badger;
die "Contentity::Hub requires Badger v0.091 or later"
    if $Badger::VERSION < 0.091;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Hub Contentity::Base',
    utils     => 'blessed params',
    constants => 'HASH';



sub no_config {
    my $self   = shift->prototype;
    my $name   = shift;
    my $params = shift;
    my $config;

    # avoid an infinite loop to fetch project config from the project
    return if $name eq 'project';

    # see if there's a project we can ask for configuration data
    my $project = $self->project;

    if ($project) {
        $config = $project->config($name);
    }

    if ($config) {
        return {
            %$config,
            %{$params||{}}
        };
    }

    return $self->SUPER::no_config($name, $params);
}

1;
