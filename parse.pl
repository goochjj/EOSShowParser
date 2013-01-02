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

open(HTML, ">dump.html") or die "dump.html $@ $!";
print HTML "<html>\n";
print HTML "<head><title>Show File</title><style type='text/css'>th { text-align: center; } td { text-align: right; } table,tr,th,td { border-collapse: collapse; border: 1px solid black; }</style></head>\n";
print HTML "<body>\n";
my $anchors = "";
$anchors .= "&nbsp;<a href='\#beampalette'>Beam Palettes</a>";
$anchors .= "&nbsp;<a href='\#colorpalette'>Color Palettes</a>";
$anchors .= "&nbsp;<a href='\#focuspalette'>Focus Palettes</a>";
$anchors .= "&nbsp;<a href='\#patch'>Patch List</a>";
$anchors .= "<br/><br/>\n";
print HTML "<a name='colorpalette'/>$anchors";
foreach my $key (sort { $a <=> $b } keys %{$data->{ColorPalette}}) {
  my $rec = $data->{ColorPalette}->{$key};
  print HTML "<h2>Color Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n";
  print HTML "<table>\n";
  print HTML "  <tr><th>&nbsp;</th><th>Channel(s)</th><th>Groups</th>".join("", map { "<th>".$data->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n";
  my %chans;
  foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
    my @groups = sort { $a <=> $b } keys %{$data->{ChannelToGroups}->{$chan}};
    my $rgb = join(",", map { $rec->{channels}->{$chan}->{$_} } ( map { $data->{ParamNameToType}->{$_} } ('Red','Green','Blue') ));
    my $colval = "&nbsp;";
    my $colstyle = "";
    my $sel = $rec->{channels}->{$chan}->{$data->{ParamNameToType}->{Color_Select}};
    if ($rgb) { $colstyle = "background-color: rgb($rgb);"; }
    if ($sel) { $colval = unpack("H*", pack("C2", $sel/256, $sel%256)); }
    my $line = "";
    $line .= "<td style='width:30px; $colstyle'>$colval</td>";
    $line .= "<td>\@CHAN\@</td>";
    $line .= "<td>".join(",", map { $data->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
    $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
    $chans{$chan} = $line;
  }
  my $output = $p->consolidate_lines(\%chans);
  foreach my $line (@$output) {
    print HTML "  <tr>$line</tr>\n";
  }
  print HTML "</table>\n";
}
print HTML "<a name='beampalette'/>$anchors";
foreach my $key (sort { $a <=> $b } keys %{$data->{BeamPalette}}) {
  my $rec = $data->{BeamPalette}->{$key};
  print HTML "<h2>Beam Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n";
  print HTML "<table>\n";
  print HTML "  <tr><th>Channel</th><th>Groups</th>".join("", map { "<th>".$data->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n";
  my %chans;
  foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
    my @groups = sort { $a <=> $b } keys %{$data->{ChannelToGroups}->{$chan}};
    my $line = "<td>".join(",", map { $data->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
    $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
    $chans{$chan} = $line;
  }
  my $output = $p->consolidate_lines(\%chans);
  foreach my $line (@$output) {
    print HTML "  <tr>$line</tr>\n";
  }
  print HTML "</table>\n";
}
print HTML "<a name='focuspalette'/>$anchors";
foreach my $key (sort { $a <=> $b } keys %{$data->{FocusPalette}}) {
  my $rec = $data->{FocusPalette}->{$key};
  print HTML "<h2>Focus Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n";
  print HTML "<table>\n";
  print HTML "  <tr><th>Channel</th><th>Groups</th>".join("", map { "<th>".$data->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n";
  my %chans;
  foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
    my @groups = sort { $a <=> $b } keys %{$data->{ChannelToGroups}->{$chan}};
    my $line = "<td>".join(",", map { $data->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
    $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
    $chans{$chan} = $line;
  }
  my $output = $p->consolidate_lines(\%chans);
  foreach my $line (@$output) {
    print HTML "  <tr>$line</tr>\n";
  }
  print HTML "</table>\n";
}
print HTML "<a name='patch'/>$anchors";
print HTML "<h2>Patch List</h2><br/>";
print HTML "<table>\n";
print HTML "  <tr><th>Channel</th><th>Type</th><th>Address</th></tr>\n";
foreach my $key (sort { $a <=> $b } keys %{$data->{Patch}}) {
  my $rec = $data->{Patch}->{$key};
  print HTML "  <tr>".join("", map { "<td>$_</td>" } ($rec->{index}, $rec->{personality}, $rec->{dmx}))."</tr>\n";
}
print HTML "</table>\n";
print HTML "</body></html>\n";
close(HTML);
