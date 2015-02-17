#!/usr/bin/perl
use Cwd 'abs_path';
use File::Basename;
use Data::Dumper;
use FileHandle;
use strict;

BEGIN {
  my $src = dirname(__FILE__);
  require "$src/ParseShowFile.pm";
}

my $file = shift;
my $p = new ParseShowFile();
my $fh = FileHandle->new;
$fh->open("<".$file) or die "$@ $!";
my $data = $p->parse_file($fh);
$fh->close();

open(DMP, ">dump.pm") or die "dump.pm $@ $!";
print DMP Data::Dumper->Dump([\$data]),"\n";
close(DMP);

my $fh2 = FileHandle->new;
my $fh3 = FileHandle->new;
my $fh4 = FileHandle->new;
$fh2->open(">dump.html") or die "dump.html $@ $!";
$fh3->open(">dump_nogrp.html") or die "dump_nogrp.html $@ $!";
$fh4->open(">dump.txt") or die "dump.txt $@ $!";
$p->page_start($fh2);
$p->page_start($fh3);
$p->{usegroups} = 0;
$p->generate_page($fh3);
$p->{usegroups} = 1;
$p->generate_page($fh2);
$p->page_end($fh2);
$p->page_end($fh3);
$fh2->close();
$fh3->close();
$p->palette_statements($fh4);
$fh4->close();

