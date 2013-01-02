#!/usr/bin/perl
use Data::Dumper;
use strict;

my $data = {
  ParamType => {},
  ParamNameToType => {},
  ColorPalette => {},
  FocusPalette => {},
  BeamPalette => {},
  Patch => {},
  Group => {},
  ChannelToGroups => {}
};
my $record;

sub closerecord {
  if ($record) {
    if ($record->{type}) {
      if ($record->{type} =~ /^(?:Color|Beam|Focus)Palette$/) {
        $record->{parameters} = [ sort { $a <=> $b } keys %{$record->{parameters}} ];
      }
      if ($record->{type} eq "Group") {
        $record->{channels} = [ sort { $a <=> $b } keys %{$record->{channels}} ];
        foreach my $chan (@{$record->{channels}}) {
          $data->{ChannelToGroups}->{$chan}->{$record->{index}} = 1; 
        }
      }
      $data->{$record->{type}}->{$record->{index}} = $record;
      $record = undef;
    }
  }
}

while(<>) {
  chomp;
  if (/^\$ParamType\s+(\d+)\s+(\d+)\s+(\S+)/) {
    $data->{ParamType}->{$1} = $3;
    $data->{ParamNameToType}->{$3} = $1;
    next;
  }
  if (/^\$((?:Beam|Color|Focus)Palette)\s+(\d+)/) {
    closerecord();
    $record = { index => $2, type => $1, title=>$2, parameters => {}, channels => {} };
#   title
#   parameters => []
#   channels
#     channel =>
#       attrib => value
    next;
  }
  if (/^\$Group\s+(\d+)/) {
    closerecord();
    $record = { index => $1, type => "Group", title=>$1, channels => {} };
    next;
  }
  if (/^\$Patch\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
    closerecord();
    $record = { index => $1, type => "Patch", title=>$1, personalityidx => $2, dmx => $3, mode => $4, part => $5, personality => $2 };
    next;
  }
  if (/^\$((?!\$)\S+)/) {
    print $1,"\n";
    closerecord();
    next;
  }
  if ($record) {
    if (/^\s+Text\s+(.+)$/) {
      $record->{title} = $1;
      next;
    }
  }
  if ($record && ($record->{type} =~ /^Patch$/)) {
    if (/^\s+\$\$Pers\s+(.+)$/) {
      $record->{personality} = $1;
    }
  }
  if ($record && ($record->{type} =~ /^(?:Beam|Color|Focus)Palette$/)) {
    if (/^\s+\$\$Param\s+(\d+)\s+(.+)$/) {
      my $chan = $1;
      if (!defined($record->{channels}->{$1})) {
        $record->{channels}->{$chan} = {};
      }
      foreach my $tok (split(/\s+/, $2)) {
        my ($param,$val) = split(/\@/, $tok);
        $record->{channels}->{$chan}->{$param} = $val;
        $record->{parameters}->{$param} = 1;
      }
    }
    next;
  }
  if ($record && $record->{type} eq "Group") {
    if (/^\s+\$\$ChanList\s+(.+)$/) {
      foreach my $chan (split(/\s+/,$1)) {
        $record->{channels}->{$chan} = 1;
      }
    }
    next;
  }
}

open(DMP, ">dump.pm") or die "dump.pm $@ $!";
print DMP Data::Dumper->Dump([\$data]),"\n";
close(DMP);

#foreach my $key (sort { $a <=> $b } keys %{$data->{ParamType}}) {
#  print "$key\t=>\t".$data->{ParamType}->{$key}."\n";
#}

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
  my $output = consolidate_lines(\%chans);
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
  my $output = consolidate_lines(\%chans);
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
  my $output = consolidate_lines(\%chans);
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

sub consolidate_lines {
  my $p = shift @_;
  my %chans = %{$p};

  my %lines;
  for my $chan (sort { $a <=> $b } keys %chans) {
    if (!defined($lines{$chans{$chan}})) {
      $lines{$chans{$chan}} = []
    }
    push @{$lines{$chans{$chan}}}, $chan;
  }
  my @chansmerged;
  for my $line (sort { $lines{$a}->[0] <=> $lines{$b}->[0] } keys %lines) {
    my @chantoks = @{$lines{$line}};
    my @chanlist;
    while (@chantoks) {
      my $firstkey = shift(@chantoks);
      my $lastkey = $firstkey;
      for(my $i = $firstkey; $chantoks[0] == $i+1; $i++) { $lastkey = $i+1; shift(@chantoks); }
      if ($firstkey == $lastkey) {
        push @chanlist, $firstkey;
      } else {
        push @chanlist, $firstkey."&gt;".$lastkey;
      }
    }
    my $list = join(",", @chanlist);
    if ($line =~ /\@CHAN\@/) {
      $line =~ s/\@CHAN\@/$list/g;
      push @chansmerged, $line;
    } else {
      push @chansmerged, "<td>$list</td>".$line;
    }
  }
  \@chansmerged;
} 
