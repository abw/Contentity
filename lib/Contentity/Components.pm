package Contentity::Components;

use Badger::Factory::Class
    version => 0.01,
    debug   => 0,
    item    => 'component',
    path    => 'Contentity(X)::Component Contentity(X)',
    utils   => 'params';


sub type_args {
    my $self   = shift;
    my $type   = shift;
    my $params = params(@_);

    if ($params->{ component }) {
        $type = $params->{ component };
        $self->debug(
            $params->{ component },
            " component set type to '$type' from component configuration option"
        ) if DEBUG;
    }

    # convert slashed to dots to avoid problems with file systems AND
    # regular expressions (long story...)
    $type =~ s[/][.]g;
    $self->debug("TYPE: $type") if DEBUG;

    return ($type, $params);
}

1;

__END__

=head1 NAME

Contentity::Components - factory module for loading and instantiating component modules

=head1 DESCRIPTION

This is a factory module for loading and instantiating component modules. It
is a subclass of L<Badger::Factory> which provides most of the functionality.

=head1 METHODS

=head2 component($params)

Factory method for loading a component module (if necessary) and instantiating
an object.  This is used by L<Contentity::Workspace> to create components.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>.

=cut
