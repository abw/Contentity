package Contentity::Component::Email;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    accessors => 'mailers',
    constants => 'DEFAULT',
    messages  => {
        missing_sender_type => 'The mailer config for "%s" (in config/email.yaml) does not define a "sender_type" (e.g. smtp)',
    };


sub init_component {
    my ($self, $config) = @_;
    $self->debug_data( email => $config ) if DEBUG;

    my $mailers = $self->{ mailers } = $config->{ mailers } || { };

    if (my $default = $config->{ default_mailer }) {
        my $defcon = $mailers->{ $default }
            || return $self->error_msg( invalid => default_mailer => $default );
        $mailers->{ default } ||= $defcon;
    }

    return $self;
}

sub mailer_config {
    my $self    = shift;
    my $type    = shift || DEFAULT;
    my $configs = $self->mailers;
    return $configs->{ $type };
}

sub mailer {
    my $self    = shift;
    my $name    = shift || DEFAULT;
    my $config  = $self->mailer_config($name)
        || return $self->error_msg( invalid => mailer => $name );

    $self->debug_data( "$name mailer config" => $config ) if DEBUG;

    my $type = $config->{ sender_type }
        || return $self->error_msg( missing_type => $name );

    return $self->workspace->project->mail_sender(
        $type => $config
    );
}

1;

=head1 NAME

Contentity::Component::Email - email handling

=head1 DESCRIPTION

This is a module providing overall responsibility for all things
related to sending email.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2018 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Component::Mailer>,
L<Contentity::Component::Factory>,
L<Contentity::Component::Asset>,
L<Badger::Factory>.

=cut
