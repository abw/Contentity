package Contentity::Component::Mailer;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Contentity::Component',
    constants => 'DEFAULT DOT',
    utils     => 'self_params params extend split_to_list',
    codec     => 'utf8',
    accessors => 'formats content_types',
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
    text     => 'text',
    html     => 'html html5 html3',
    html3    => 'html3 html',
    html5    => 'html5 html3 html',
};

our $CONTENT_TYPES = {
    default  => 'text/plain; charset="UTF-8"',
    text     => 'text/plain; charset="UTF-8"',
    html     => 'text/html; charset="UTF-8"',
    html3    => 'text/html; charset="UTF-8"',
    html5    => 'text/html; charset="UTF-8"',
};


sub init_component {
    my ($self, $config) = @_;
    $self->init_mailer($config);
    $self->{ formats       } = class->hash_vars( FORMATS => $config->{ formats } );
    $self->{ content_types } = class->hash_vars( CONTENT_TYPES => $config->{ content_types } );
    return $self;
}

sub init_mailer {
    # stub for subclasses
}

sub send_email {
    my ($self, $params) = self_params(@_);

    # set the config items as defaults
    extend($params, $self->config);

    $self->debug_data( extended_config => $params ) if DEBUG;

    # the force_send_to option is used for testing to avoid sending mail
    # to real customer
    my $force = $self->config('force_send_to');
    if ($force) {
        $self->force_send_to($params, $force);
    }

    # process any template to generate message
    $params->{ message } = $self->process_template($params->{ template }, $params)
        if $params->{ template };

    return $self->send($params);
}

sub send {
    shift->not_implemented('in base class');
}

sub force_send_to {
    my ($self, $params, $force) = @_;
    my $title = $self->config('force_send_subject') || '%s (TEST)';

    # for test
    $self->debug("force_send_to: $force") if DEBUG;
    $params->{ to } = $force;
    $params->{ subject } = sprintf($title, $params->{ subject } || '(no subject)');

    return $params;
}

sub format {
    my $self   = shift;
    my $format = shift || DEFAULT;
    return $self->formats->{ $format };
}

sub content_type {
    my $self = shift;
    my $type = shift || DEFAULT;
    return $self->content_types->{ $type };
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
    my $flist     = $self->format($format);
    my $formats   = split_to_list($flist);
    my ($filename, $found);

    # try to find a template with each format as the file extension in
    # turn, failing that try no extension at all
    for $format (@$formats, '') {
        $self->debug("trying format '$format' for '$template' email template") if DEBUG;
        # check it's a valid format and apply any mapping (none currently)
        # NOTE: may be better to silently ignore in case of invalid format
        if ($format) {
            return $self->error_msg( invalid => format => $format )
                unless $format = $FORMATS->{ lc $format };
        }

        $filename = $format
            ? join(DOT, $template, $format)
            : $template;

        # look for filename with extension and fall back if not found
        eval {
            $found = $templates->template_path($filename);
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
        elsif ($found) {
            $params->{ format_used } = $format;
            return $filename;
        }
    }

    return $self->decline_msg("Template not found: $template");
}


sub templates {
    my $self = shift;
    return $self->{ templates }
        ||= $self->workspace->renderer('email')
        ||  $self->error_msg('no_templates');
}


1;

__END__

=head1 NAME

Contentity::Component::Mailer - base class messenger module for sending email

=head1 DESCRIPTION

This module is a base class for other modules used to send Email.

See L<Contentity::Component::Mailer::SMTP> for an example of a concrete
subclass.

=head1 METHODS

=head2 process_template($template,$vars)

Processes an email template named by the first argument.  The second
argument should be a reference to a hash array containing template
variables.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2009-2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Component::Mailer::SMTP>,
L<Contentity::Component>, L<Badger::Base>;

=cut
