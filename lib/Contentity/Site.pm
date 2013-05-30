package Contentity::Site;

use Contentity::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Contentity::Project',
    constant    => {
        CONFIG_FILE => 'site',
    };

#sub init {
#    my ($self, $config) = @_;
#    $self->init_project($config);
#    $self->debug("site init");
#    return $self;
#}


sub urls {
    my $self = shift;
    return  $self->{ urls }
        ||= $self->config_underscore_tree('urls');
}

sub url {
    my $self = shift;
    my $urls = $self->urls;
    return $urls unless @_;
    $self->todo("URL lookup");
}

1;
