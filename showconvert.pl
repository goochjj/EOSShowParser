#!/usr/bin/perl -T

use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;
use FileHandle;
use strict;

BEGIN {
  my $src = dirname(__FILE__);
  require "$src/ParseShowFile.pm";
}

$CGI::POST_MAX = 1024 * 5000;

my $q = new CGI;
my $p = new ParseShowFile();

print $q->header("text/html");
print $q->start_html();
print $q->start_head();
print $q->title("Show Parsing");
print $p->get_styles();
print $q->end_head();
print $q->start_body();
print '<form method="post" enctype="multipart/form-data"><p>ASCII File: <input type="file" name="showfile" /></p><p>Use Groups: <input type="checkbox" name="usegroups" value="1" /></p><input type="submit" value="Go" /></form><br/>'."\n";
if ($q->param("showfile")) {
  my $fh = $q->upload("showfile");
  $p->{usegroups} = $q->param("usegroups")||0;
  my $data = $p->parse_file($fh);
  print "<br/><br/>\n";
  print $p->generate_page($q);
}

print $q->end_body();
print $q->end_html();
