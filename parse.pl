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
$fh2->open(">dump.html") or die "dump.html $@ $!";
$p->page_start($fh2);
$p->generate_page($fh2);
$p->page_end($fh2);
$fh2->close();
