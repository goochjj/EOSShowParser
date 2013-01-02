#!/usr/bin/perl

use CGI;
use strict;

package ParseShowFile;

sub new {
  my $class = shift;
  my $self = {};

  bless $self, $class;
  $self->reset();
  return $self;
}

sub reset {
  my $self = shift;
  $self->{record} = undef;
  $self->{data} = {
    ParamType => {},
    ParamNameToType => {},
    ColorPalette => {},
    FocusPalette => {},
    BeamPalette => {},
    Patch => {},
    Group => {},
    ChannelToGroups => {}
  };
}

sub closerecord {
  my $self = shift;
  if ($self->{record}) {
    if ($self->{record}->{type}) {
      if ($self->{record}->{type} =~ /^(?:Color|Beam|Focus)Palette$/) {
        $self->{record}->{parameters} = [ sort { $a <=> $b } keys %{$self->{record}->{parameters}} ];
      }
      if ($self->{record}->{type} eq "Group") {
        $self->{record}->{channels} = [ sort { $a <=> $b } keys %{$self->{record}->{channels}} ];
        foreach my $chan (@{$self->{record}->{channels}}) {
          $self->{data}->{ChannelToGroups}->{$chan}->{$self->{record}->{index}} = 1; 
        }
      }
      $self->{data}->{$self->{record}->{type}}->{$self->{record}->{index}} = $self->{record};
      $self->{record} = undef;
    }
  }
}

sub parse_file {
  my $self = shift;
  my $fh = shift;
  $self->reset();
  while(<$fh>) {
    chomp;
    if (/^\$ParamType\s+(\d+)\s+(\d+)\s+(\S+)/) {
      $self->{data}->{ParamType}->{$1} = $3;
      $self->{data}->{ParamNameToType}->{$3} = $1;
      next;
    }
    if (/^\$((?:Beam|Color|Focus)Palette)\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $2, type => $1, title=>$2, parameters => {}, channels => {} };
      next;
    }
    if (/^\$Group\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Group", title=>$1, channels => {} };
      next;
    }
    if (/^\$Patch\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Patch", title=>$1, personalityidx => $2, dmx => $3, mode => $4, part => $5, personality => $2 };
      next;
    }
    if (/^\$((?!\$)\S+)/) {
      print $1,"\n";
      $self->closerecord();
      next;
    }
    if ($self->{record}) {
      if (/^\s+Text\s+(.+)$/) {
        $self->{record}->{title} = $1;
        next;
      }
    }
    if ($self->{record} && ($self->{record}->{type} =~ /^Patch$/)) {
      if (/^\s+\$\$Pers\s+(.+)$/) {
        $self->{record}->{personality} = $1;
      }
    }
    if ($self->{record} && ($self->{record}->{type} =~ /^(?:Beam|Color|Focus)Palette$/)) {
      if (/^\s+\$\$Param\s+(\d+)\s+(.+)$/) {
        my $chan = $1;
        if (!defined($self->{record}->{channels}->{$1})) {
          $self->{record}->{channels}->{$chan} = {};
        }
        foreach my $tok (split(/\s+/, $2)) {
          my ($param,$val) = split(/\@/, $tok);
          $self->{record}->{channels}->{$chan}->{$param} = $val;
          $self->{record}->{parameters}->{$param} = 1;
        }
      }
      next;
    }
    if ($self->{record} && $self->{record}->{type} eq "Group") {
      if (/^\s+\$\$ChanList\s+(.+)$/) {
        foreach my $chan (split(/\s+/,$1)) {
          $self->{record}->{channels}->{$chan} = 1;
        }
      }
      next;
    }
  }
  $self->{data};
}

sub data { my $self = shift; $self->{data}; }

sub consolidate_lines {
  my $self = shift @_;
  my $p;
  if (ref($self) eq "ParseShowFile") {
    $p = shift @_;
  } else {
    $p = $self;
  }
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
    my @chantoks2;
    while (@chantoks) {
      my $firstkey = shift(@chantoks);
      my $lastkey = $firstkey;
      for(my $i = $firstkey; $chantoks[0] == $i+1; $i++) { $lastkey = $i+1; shift(@chantoks); }
      if ($firstkey == $lastkey) {
        push @chantoks2, $firstkey;
      } else {
        push @chanlist, $firstkey."&gt;".$lastkey;
      }
    }
    @chantoks = @chantoks2;
    # even/odd
    while (@chantoks) {
      my $firstkey = shift(@chantoks);
      my $lastkey = $firstkey;
      for(my $i = $firstkey; $chantoks[0] == $i+2; $i+=2) { $lastkey = $i+2; shift(@chantoks); }
      if ($firstkey == $lastkey) {
        push @chanlist, $firstkey;
      } else {
        push @chanlist, (($firstkey%2)?"odd(":"even(").$firstkey."&gt;".$lastkey.")";
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

sub generate_page {
  my $self = shift;
  my $q = shift || new CGI;

  $q->print("<html>\n");
  $q->print("<head><title>Show File</title><style type='text/css'>th { text-align: center; } td { text-align: right; } table,tr,th,td { border-collapse: collapse; border: 1px solid black; }</style></head>\n");
  $q->print("<body>\n");
  my $anchors = "";
  $anchors .= "&nbsp;<a href='\#beampalette'>Beam Palettes</a>";
  $anchors .= "&nbsp;<a href='\#colorpalette'>Color Palettes</a>";
  $anchors .= "&nbsp;<a href='\#focuspalette'>Focus Palettes</a>";
  $anchors .= "&nbsp;<a href='\#patch'>Patch List</a>";
  $anchors .= "<br/><br/>\n";
  $q->print("<a name='colorpalette'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{ColorPalette}}) {
    my $rec = $self->{data}->{ColorPalette}->{$key};
    $q->print("<h2>Color Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>&nbsp;</th><th>Channel(s)</th><th>Groups</th>".join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $rgb = join(",", map { $rec->{channels}->{$chan}->{$_} } ( map { $self->{data}->{ParamNameToType}->{$_} } ('Red','Green','Blue') ));
      my $colval = "&nbsp;";
      my $colstyle = "";
      my $sel = $rec->{channels}->{$chan}->{$self->{data}->{ParamNameToType}->{Color_Select}};
      if ($rgb) { $colstyle = "background-color: rgb($rgb);"; }
      if ($sel) { $colval = unpack("H*", pack("C2", $sel/256, $sel%256)); }
      my $line = "";
      $line .= "<td style='width:30px; $colstyle'>$colval</td>";
      $line .= "<td>\@CHAN\@</td>";
      $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
      $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='beampalette'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{BeamPalette}}) {
    my $rec = $self->{data}->{BeamPalette}->{$key};
    $q->print("<h2>Beam Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>Channel</th><th>Groups</th>".join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
      $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='focuspalette'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{FocusPalette}}) {
    my $rec = $self->{data}->{FocusPalette}->{$key};
    $q->print("<h2>Focus Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>Channel</th><th>Groups</th>".join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>";
      $line .= join("", map { "<td>".$rec->{channels}->{$chan}->{$_}."</td>" } @{$rec->{parameters}});
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='patch'/>$anchors");
  $q->print("<h2>Patch List</h2><br/>");
  $q->print("<table>\n");
  $q->print("  <tr><th>Channel</th><th>Type</th><th>Address</th></tr>\n");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{Patch}}) {
    my $rec = $self->{data}->{Patch}->{$key};
    $q->print("  <tr>".join("", map { "<td>$_</td>" } ($rec->{index}, $rec->{personality}, $rec->{dmx}))."</tr>\n");
  }
  $q->print( "</table>\n");
  $q->print( "</body></html>\n");
}

1;
