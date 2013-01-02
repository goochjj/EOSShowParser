#!/usr/bin/perl

use CGI;
use strict;

my $q = new CGI;

print $q->header();

print $q->start_html();
print "Hi";
print $q->end_html();

