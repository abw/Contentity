package Contentity::Table::Jobs;

use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Database::Table',
    utils     => 'self_key self_params Now generate_id',
    codec     => 'json',
    constants => ':jobs';


#-----------------------------------------------------------------------------
# We create job records as subclasses of the Contentity::Record::Job base
# class using the type to differentiate, e.g. type of "do/something" maps to
# Contentity::Record::Job::Do::Something
#-----------------------------------------------------------------------------

sub record {
    shift->subclass_record( type => @_ );
}

#-----------------------------------------------------------------------------
# Intercept insert() and update() to encode parameters and data
#-----------------------------------------------------------------------------

sub insert {
    my ($self, $params) = self_params(@_);

    $params->{ uri } ||= $self->generate_uri
        if $params->{ generate_uri };

    $params->{ params } = encode($params->{ params })
        if $params->{ params } && ref $params->{ params };

    $params->{ data } = encode($params->{ data })
        if $params->{ data } && ref $params->{ data };

    # look for an expiry parameter
    my $expiry = $params->{ expiry } || JOB_EXPIRY;

    if ($expiry) {
        # add the expiry time onto current time to get expiry timestamp
        $params->{ expires } ||= Now->adjust( $expiry )->timestamp;
        $self->debug("expires in $expiry : $params->{ expires }") if DEBUG;
    }

    return $self->SUPER::insert($params);
}

sub update {
    my ($self, $params) = self_params(@_);

    $params->{ params } = encode($params->{ params })
        if $params->{ params } && ref $params->{ params };

    $params->{ data } = encode($params->{ data })
        if $params->{ data } && ref $params->{ data };

    return $self->SUPER::update($params);
}

sub generate_uri {
    generate_id(JOB_URI_LENGTH);
}

sub delete_all_user_jobs {
    my ($self, $uid) = self_key( user_id => @_ );
    $self->execute( delete_all_user_jobs => $uid );
}


1;
