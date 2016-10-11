package Contentity::Component::Git;

use Git::Wrapper;
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Contentity::Component',
    utils     => 'self_params',
    constant  => {
        GIT_WRAPPER => 'Git::Wrapper',
    };

my $GIT_STATUS = {
    ' ' => 'unmodified',
    'M' => 'modified',
    'A' => 'added',
    'D' => 'deleted',
    'R' => 'renamed',
    'C' => 'copied',
    'U' => 'updated',
};

#-----------------------------------------------------------------------------
# General purpose methods
#-----------------------------------------------------------------------------

sub pull {
    shift->wrapper->pull(@_);
}

sub push {
    shift->wrapper->push(@_);
}

sub add {
    shift->wrapper->add(@_);
}

sub commit {
    my ($self, $params) = self_params(@_);
    $self->wrapper->commit($params);
}


#-----------------------------------------------------------------------------
# Status methods
#-----------------------------------------------------------------------------

sub is_clean {
    ! shift->is_dirty;
}

sub is_dirty {
    shift->status->is_dirty;
}

sub status_files {
    my $self = shift;
    return {
        indexed  => $self->indexed_files,
        changed  => $self->changed_files,
        unknown  => $self->unknown_files,
        conflict => $self->conflict_files,
    };
}

sub status_group {
    my $self = shift;

    return [
        map {
            my $mode = $_->{ mode };
            $_->{ status } = $GIT_STATUS->{ $mode } if defined $mode;
            $_;
        }
        $self->status->get(@_)
    ];
}

sub indexed_files {
    shift->status_group( indexed => @_ );
}

sub changed_files {
    shift->status_group( changed => @_ );
}

sub unknown_files {
    shift->status_group( unknown => @_ );
}

sub conflict_files {
    shift->status_group( conflict => @_ );
}

#-----------------------------------------------------------------------------
# Methods to create/cache the Git::Wrapper delegate object
#-----------------------------------------------------------------------------

sub wrapper {
    my $self = shift;
    return $self->{ wrapper }
        ||= $self->git_wrapper;
}

sub git_wrapper {
    my $self = shift;
    return $self->GIT_WRAPPER->new(
        $self->workspace->root->absolute
    );
}

sub status {
    my $self = shift;
    return  $self->{ status }
        ||= $self->wrapper->status;
}

sub uncache {
    my $self = shift;
    delete $self->{ wrapper };
    delete $self->{ status  };
    return $self;
}

1;

__END__

=head1 NAME

Contentity::Component::Git - workspace component for interacting with Git

=head1 DESCRIPTION

This component can be used to interact with the Git source control
system for a workspace.

It uses the L<Git::Wrapper> CPAN module to do all the hard work.
The C<Contentity::Component::Git> module is little more than a thin component
interface to it for integration into the Contentity framework.

=head1 GIT COMMAND METHODS

=head2 pull()

=head2 push()

=head2 add()

=head2 commit()

=head1 STATUS METHODS

=head2 is_dirty()

Returns a boolean value to indicate if the Git repository is dirty,
i.e. has modified, indexed or conflicted files.

=head2 is_clean()

Returns a boolean value to indicate if the Git repository is clean,
i.e. does NOT have any modified, indexed or conflicted files.

=head1 INTERNAL METHODS

=head2 wrapper()

Returns a reference to a L<Git::Wrapper> object, pre-configured to work
with the Git repository for the component's workspace (i.e. the root
directory for the workspace has been automatically provided).

The object will be created by calling the L<git_wrapper()> method and
then cached for subsequent use.

=head2 git_wrapper()

This is used to create a L<Git::Wrapper> object.  It always creates a
new object and does not cache it.

=head2 status()

Returns a L<Git::Wrapper::Statuses> object for the Git repository.
See the documentation for L<Git::Wrapper> for further details.

This object is cached internally.  The cache can be cleared by calling
the L<uncache()> method.

=head2 uncache()

This can be called to delete any internally cached data.  This includes
the internal cache to the L<Git::Wrapper> object, as used by the
L<wrapper()> method, and the status object used by the L<status()> method.

It returns a reference to the C<$self> object allowing you to chain
it in a call to L<wrapper()> if you want to force a new object to be
created:

    $self->uncache->wrapper;

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2016 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Contentity::Component>, L<Git::Wrapper>

=cut
