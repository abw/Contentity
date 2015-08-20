package Contentity::Component::Mailer;

#use Mail::Sender;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    #accessors => 'hub mailhost',
    #constants => 'HASH DOT DEFAULT',
    #utils     => 'self_params params extend',
    #config    => 'hub! templates!',
    codec     => 'utf8',
    constant  => {
        HTML_CONTENT_TYPE => 'text/html; charset="UTF-8"',
    },
    messages  => {
        mail_fail     => 'Failed to send email to %s: %s',
        template_fail => 'Failed to process email template %s: %s',
        no_templates  => 'No template engine defined for mailer',
    };

our $FORMATS = {
    default  => 'text',
    map { $_ => $_ }
    qw( text html3 html5 )
};

sub init_component {
    my ($self, $config) = @_;
    $self->{ templates } = $config->{ templates };
    return $self;
}

sub send_email {
    my ($self, $params) = self_params(@_);
    #my $type   = $params->{ type } || DEFAULT;
    #my $types  = $self->hub->config->mail_types;
    #my $config = extend({ }, $types->{ $type }, $params);
    #$self->send($config);
    $self->send($params);
}

sub send {
    shift->not_implemented('in base class');
}


sub process_template {
    my $self      = shift;
    my $template  = shift;
    my $params    = params(@_);
    my $templates = $self->templates;
    my $filename  = $self->template_filename($template, $params);
    my $output    = '';

    $templates->process($filename, $params, \$output)
        ||  return $self->error_msg(
                template_fail => $template, $templates->error->info
            );

    return $output;
}


sub template_filename {
    my $self      = shift;
    my $template  = shift;
    my $params    = params(@_);
    my $templates = $self->templates;
    my $format    = $params->{ format } || DEFAULT;
    my $filename  = $template;
    my $found;

    if ($format) {
        # check it's a valid format and apply any mapping (none currently)
        # NOTE: may be better to silently ignore in case of invalid format
        return $self->error_msg( invalid => format => $format )
            unless $format = $FORMATS->{ lc $format };

        $filename = join(DOT, $template, $format);

        # look for filename with extension and fall back if not found
        eval {
            $templates->template($filename)
        };
        if ($@) {
            my $error = $@;

            # If it's a "file not found error" then we fall back to the
            # template without the .format extension.  Otherwise we re-throw
            # the error.
            if (ref $error && $error->type eq 'file' && ! ref $error->info) {
                $self->debug("$filename not found: $@") if DEBUG;
                $filename = $template;
            }
            else {
                die $error;
            }
        }
    }

    return $filename;
}


sub templates {
    my $self = shift;
    return $self->{ templates }
        || $self->error_msg('no_templates');
}


1;

__END__

=head1 NAME

LFH::Mailer - base class messenger module for sending email

=head1 SYNOPSIS

    use LFH;

    LFH->mailer->send({
        to      => 'abw@badgerpower.com',
        from    => 'admin@badgerpower.com',
        subject => 'Yo Badger, whazzup',
        message => 'Hey there Mr Badger... etc...',
    });

=head1 DESCRIPTION

This module is a base class for other modules used to send Email.

See L<LFH::Messenger::SMTP> and L<LFH::Messenger::Sendmail> for examples.

=head1 METHODS

=head2 process_template($template,$vars)

Processes an email template named by the first argument.  The second
argument should be a reference to a hash array containing template
variables.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2013 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<LFH::Messenger::SMTP>,
L<LFH::Messenger::Sendmail>,
L<LFH>, L<LFH::Hub>, L<LFH::Base>, L<Badger::Base> and L<Mail::Sender>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
