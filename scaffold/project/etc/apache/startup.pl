#-----------------------------------------------------------------------------
# etc/apache/startup.pl
#
# This is the startup file for initialising the Perl modules that implement
# the Contentity web framework and applications.  It is called once when
# the Apache web server is started.  The call is invoked from the local
# httpd.conf which contains a line like this:
#
#   PerlPostConfigRequire [% Project.dir %]/etc/apache/startup.pl
#
%% process warning

use lib qw( [% Project.root %]/perl/lib );
use Badger
    Rainbow   => [ANSI  => 'cyan yellow'],
    Exception => [trace => 1, colour => 1];

use Contentity;

Contentity->debug(
    cyan("Loaded Contentity v", Contentity->VERSION)
);


1;

__END__
