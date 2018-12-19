package Contentity::Component::Worker;

use Time::HiRes qw( gettimeofday tv_interval );
use Contentity::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Contentity::Component::Reporter',
    constant     => {
        NAME     => 'worker',
    };


sub init {
    my ($self, $config) = @_;
    $self->{ output } = [ ];
    $self->configure($config);
    $self->init_reporter($config);
    $self->start_time;
    return $self;
}

sub work {
    shift->not_implemented('in base class');
}

sub database {
    shift->workspace->database;
}

sub model {
    shift->workspace->model;
}

sub say {
    my $self = shift;
    my $text = join('', @_);
    push( @{ $self->{ output } }, $text );
    if ($self->{ verbose }) {
        print $text, "\n"
    }
}

sub report {
    my $self = shift;
    return join("\n", @{ $self->{ output } });
}

sub send_report {
    my ($self, $params) = self_params(@_);
    my $config = $self->{ config };
    my $report = $self->report;

    $params = {
        %$config,
        %$params,
        report => $self->report,
    };

    $self->project->mailer->send($params);
}


#sub log {
#    shift->hub->log;
#}
#
#sub log_report {
#    my $self = shift;
#
#    $self->log->alert(
#        type    => 'report',
#        level   => 'info',
#        source  => $self->NAME,
#        message => $self->report || "No report",
#        params  => $self->{ log_params },
#    );
#}


sub start_time {
    my $self = shift;
    return $self->{ start_time } ||= [gettimeofday];
}


sub current_time {
    return [gettimeofday];
}


sub elapsed_time {
    my $self     = shift;
    my $interval = tv_interval(shift || $self->{ start_time }, [gettimeofday]);
    my $elapsed  = [ $interval =~ /(\d+)\.(\d+)/ ];
    my $seconds  = $elapsed->[0];
    my $micros   = $elapsed->[1];
    my $minutes  = int($seconds / 60);
    my $output   = '';

    if ($minutes) {
        $seconds %= 60;
        if ($minutes > 60) {
            my $hours = int($minutes / 60);
            $minutes %= 60;
            $output = $hours . ' hour' . $hours > 1 ? 's ' : ' ';
        }
        $output = $minutes . ' minute' . $minutes > 1 ? 's ' : ' ';
    }

    $output .= sprintf('%d.%06d seconds', $seconds, $micros);

    return $output;
}


1;
