package Contentity::Plack::Handler::Directory;

#use Carp 'confess';
#confess __PACKAGE__, " is deprecated";

use Plack::MIME;
use Plack::Util;
use HTTP::Date;
use URI::Escape;
use Badger::Filesystem 'Dir';
use Contentity::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Plack::App::Directory Contentity::Plack::Base';

my $dir_file = <<FILE;
  <tr>
    <td class="name"><a href="%s">%s</a></td>
    <td class="size">%s</td>
    <td class="type">%s</td>
    <td class="mtime">%s</td>
  </tr>
FILE

my $dir_page = <<PAGE;
<html><head>
  <title>%s</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <style type='text/css'>
body { padding: 1em; font-size: 12px }
table { width:100%%; }
td, th { padding: 3px 5px;  color: #444 }
a { color: #07f; text-decoration: none }
a:visited { color: #05a; text-decoration: none }
th { background-color: #ccc; font-size: 14px }
tr td { background-color: #f0f0f0; font-size: 12px;  }
tr:nth-child(odd) td { background-color: #e8e8e8 }
.name { text-align:left; }
.size, .mtime { text-align:right; }
.type { width:11em; text-align: right}
.mtime { width:15em; }
  </style>
</head><body>
<h1>%s</h1>
<a href="../">Parent Directory</a>
<table>
  <tr>
    <th class="name">Name</th>
    <th class="size">Size</th>
    <th class="type">Type</th>
    <th class="mtime">Last Modified</th>
  </tr>
%s
</table>
</body></html>
PAGE

sub serve_path {
    my($self, $env, $dir, $fullpath) = @_;

    if (-f $dir) {
        return $self->SUPER::serve_path($env, $dir, $fullpath);
    }
    elsif (! $self->{ index }) {
        $self->debug("$dir is a directory and indexes are disabled");
        return $self->return_403;
    }

    my $dir_url = $env->{SCRIPT_NAME} . $env->{PATH_INFO};

    if ($dir_url !~ m{/$}) {
        return $self->return_dir_redirect($env);
    }

    my @files = (); #([ "../", "Parent Directory", '', '', '' ]);
    my $kids  = Dir($dir)->children;

    #    next if $ent eq '.' or $ent eq '..';
    foreach my $child (@$kids) {
        my $base   = $child->name;
        my $file   = "$dir/$base";
        my $url    = $dir_url . $base;
        my $is_dir = $child->is_dir;
        my @stat   = stat _;

        $url = join '/', map {uri_escape($_)} split m{/}, $url;

        if ($is_dir) {
            $base .= "/";
            $url  .= "/";
        }

        my $mime_type = $is_dir ? 'directory' : ( Plack::MIME->mime_type($file) || 'text/plain' );
        push @files, [ $url, $base, $child->size, $mime_type, $child->modified ];
        #HTTP::Date::time2str($stat[9]) ];
    }

    my $path  = Plack::Util::encode_html("Index of $env->{PATH_INFO}");
    my $files = join "\n", map {
        my $f = $_;
        sprintf $dir_file, map Plack::Util::encode_html($_), @$f;
    } @files;
    my $page  = sprintf $dir_page, $path, $path, $files;

    return [ 200, ['Content-Type' => 'text/html; charset=utf-8'], [ $page ] ];
}

sub NOT_return_404 {
    my $self = shift;
    $self->debug("returning 404 as undef");
    return undef;
}


1;
