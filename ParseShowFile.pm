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
  $self->{usegroups} = 0;
  $self->{record} = undef;
  $self->{data} = {
    Title => "Show File",
    ParamType => {},
    ParamNameToType => {},
    Personality => {},
    ColorPalette => {},
    FocusPalette => {},
    BeamPalette => {},
    Patch => {},
    Group => {},
    Sub => {},
    Preset => {},
    ChannelToGroups => {}
  };
}

sub closerecord {
  my $self = shift;
  if ($self->{record}) {
    if ($self->{record}->{type}) {
      if ($self->{record}->{type} =~ /^(?:(?:Color|Beam|Focus)Palette|Preset|Sub)$/) {
        $self->{record}->{parameters} = [ sort { $a <=> $b } keys %{$self->{record}->{parameters}} ];
      }
      if ($self->{record}->{type} eq "Group") {
        $self->{record}->{channels} = [ sort { $a <=> $b } keys %{$self->{record}->{channels}} ];
        foreach my $chan (@{$self->{record}->{channels}}) {
          $self->{data}->{ChannelToGroups}->{$chan}->{$self->{record}->{index}} = 1; 
        }
      }
      if ($self->{record}->{type} eq "Personality") {
        my $numaddr = 0;
	foreach my $c (keys %{$self->{record}->{params}}) {
	    $numaddr += 0+$self->{record}->{params}->{$c}->{size};
	}
	$self->{record}->{numaddr}=$numaddr;
	$self->{data}->{Personality}->{$self->{record}->{model}} = $self->{record};
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
    s/[\r\n]+$//g;
    if (/^\$\$Title\s+(.+)/) {
      $self->{data}->{Title}= $1;
      next;
    }
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
    if (/^Group\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Preset", title=>$1, parameters => {}, channels => {} };
      next;
    }
    if (/^Sub\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Sub", title=>$1, parameters => {}, channels => {}, effectSub => 0 };
      next;
    }
    if (/^\$Group\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Group", title=>$1, channels => {} };
      next;
    }
    if (/^\$Personality\s+(\d+)/) {
      $self->closerecord();
      $self->{record} = { index => $1, type => "Personality", model=>"", manufacturer=>"", dcid=>"", params => {} };
      next;
    }
    if (/^Patch\s+.*/) {
      $self->closerecord();
      next;
    }
    if (/^\$Patch\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
      $self->closerecord();
      my $univ = "";
      my $lcldmx = "";
      if ($3>0) { $univ = (($3 >> 9)+1); $lcldmx = ($3%512); }

      $self->{record} = { index => $1, type => "Patch", title=>$1, personalityidx => $2, universe => $univ, localdmx => $lcldmx, dmx => $3, mode => $4, part => $5, personality => $2 };
      next;
    }
    if (/^\!/) {
      #comment
      next;
    }
    if (/^EndData/) {
      #comment
      next;
    }
    if (/^((?!\$)\S+)/) {
      print $1,"\n";
      $self->closerecord();
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
	next;
      }
    }
    if ($self->{record} && ($self->{record}->{type} =~ /^Sub$/)) {
      if (/^\s+\$\$EffectSub\s*$/) {
        $self->{record}->{effectSub} = 1;
	next;
      }
    }
    if ($self->{record} && ($self->{record}->{type} =~ /^Personality$/)) {
      if (/^\s+\$\$Manuf\s+(.+)$/) { $self->{record}->{manufacturer} = $1; next; }
      if (/^\s+\$\$Model\s+(.+)$/) { $self->{record}->{model} = $1;        next; }
      if (/^\s+\$\$Dcid\s+(.+)$/ ) { $self->{record}->{dcid} = $1;         next; }
      if (/^\s+\$\$Model\s+(.+)$/) { $self->{record}->{model} = $1;        next; }
      if (/^\s+\$\$PersChan\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $self->{record}->{params}->{$1} = { paramtype => $1, size => $2, offset1 => $3, offset2 => $4, home => $5 };
        next;
      }
    }
    if ($self->{record} && ($self->{record}->{type} =~ /^(?:(?:Beam|Color|Focus)Palette|Preset|Sub)$/)) {
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

sub htmlize {
  my $self;
  if (ref($_[0]) eq "ParseShowFile") { $self = shift; }
  my $val = shift;
  $val =~ s/\>/&gt;/g;
  $val =~ s/\</&lt;/g;
  return $val;
}

sub friendly_channels {
  my $self;
  if (ref($_[0]) eq "ParseShowFile") { $self = shift; }
  my @chantoks = @_;
  my @chanlist;
  my @chantoks2;
  while (@chantoks) {
    my $firstkey = shift(@chantoks);
    my $lastkey = $firstkey;
    for(my $i = $firstkey; $chantoks[0] == $i+1; $i++) { $lastkey = $i+1; shift(@chantoks); }
    if ($firstkey == $lastkey) {
      push @chantoks2, $firstkey;
    } else {
      push @chanlist, $firstkey.">".$lastkey;
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
    } elsif ($lastkey == $firstkey+2) {
      push @chanlist, $firstkey, $lastkey;
    } else {
      push @chanlist, (($firstkey%2)?"odd(":"even(").$firstkey.">".$lastkey.")";
    }
  }
  return join(",", @chanlist);
}

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
    my $list = htmlize(friendly_channels(@{$lines{$line}}));
    if ($line =~ /\@CHAN\@/) {
      $line =~ s/\@CHAN\@/$list/g;
      push @chansmerged, $line;
    } else {
      push @chansmerged, "<td>$list</td>".$line;
    }
  }
  \@chansmerged;
} 

sub get_styles {
  my $ret = <<EOM;
    <style type='text/css'>table { width: 100%; } th { text-align: center; } td { text-align: right; } table,tr,th,td { border-collapse: collapse; border: 1px solid black; }</style>
    <script type="text/javascript" src="prototype.js"></script>
EOM
}

sub page_start {
  my $self = shift;
  my $q = shift || new CGI;

  $q->print("<html><head><title>".$self->{data}->{Title}."</title>".$self->get_styles()."</head></body>");
}

sub generate_page {
  my $self = shift;
  my $q = shift || new CGI;

  my $anchors = "";
  $anchors .= "&nbsp;<a href='\#beampalette'>Beam Palettes</a>";
  $anchors .= "&nbsp;<a href='\#colorpalette'>Color Palettes</a>";
  $anchors .= "&nbsp;<a href='\#focuspalette'>Focus Palettes</a>";
  $anchors .= "&nbsp;<a href='\#preset'>Presets</a>";
  $anchors .= "&nbsp;<a href='\#submaster'>Submasters</a>";
  $anchors .= "&nbsp;<a href='\#groups'>Groups</a>";
  $anchors .= "&nbsp;<a href='\#patch'>Patch List</a>";
  $anchors .= <<EOM;
&nbsp;<a href="javascript:\$\$('.inactive').each(function(el) { if (el.visible()) { el.hide(); } else {el.show(); } });">Toggle Inactive</a>
EOM
  $anchors .= "<br/><br/>\n";
  $q->print("<a name='colorpalette'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{ColorPalette}}) {
    my $rec = $self->{data}->{ColorPalette}->{$key};
    $q->print("<h2>Color Palette ".$rec->{index}.": ".$rec->{title}."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>&nbsp;</th><th>Channel(s)</th><th>Fixture</th>");
    if ($self->{usegroups}) { $q->print("<th>Groups</th>"); }
    $q->print(join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my $patch = $self->{data}->{Patch}->{$chan};
      my $persidx = $patch->{personalityidx};
      my $pers = $self->{data}->{Personality}->{$persidx};
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $rgb = join(",", map { $rec->{channels}->{$chan}->{$_} } ( map { $self->{data}->{ParamNameToType}->{$_} } ('Red','Green','Blue') ));
      my $colval = "&nbsp;";
      my $colstyle = "";
      my $sel = $rec->{channels}->{$chan}->{$self->{data}->{ParamNameToType}->{Color_Select}};
      if ($rgb) { $colstyle = "background-color: rgb($rgb);"; }
      if ($sel) { $colval = "0x".uc(unpack("H*", pack("C2", $sel/256, $sel%256))); }
      my $line = "";
      $line .= "<td style='width:30px; $colstyle'>$colval</td>";
      $line .= "<td>\@CHAN\@</td>";
      $line .= "<td>".$pers->{model}."</td>";
      if ($self->{usegroups}) { $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>"; }
      foreach my $paramidx (@{$rec->{parameters}}) {
        my $val = $rec->{channels}->{$chan}->{$paramidx};
        my $perschan = $pers->{params}->{$paramidx};
        my $size = $perschan->{size};
        my $s="";
	if ($val =~ /^(CP)(\d+)$/) {
	   my $pal = $self->{data}->{ColorPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^FP(\d+)$/) {
	   my $pal = $self->{data}->{FocusPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^BP(\d+)$/) {
	   my $pal = $self->{data}->{BeamPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^([A-Za-z]+)(\d+)$/) {
        } elsif ($size==1) {
	  $val = uc(unpack("H*", pack("C*", $val%256)));
	  if ($self->{data}->{ParamNameToType}->{Red} == $paramidx) {
	    $s = " style='font-weight: bold; color: #".$val."0000;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Green} == $paramidx) {
	    $s = " style='font-weight: bold; color: #00".$val."00;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Blue} == $paramidx) {
	    $s = " style='font-weight: bold; color: #0000".$val.";'";
          }
          $val = "0x".$val;
        } elsif ($size==2) {
	  $val = uc(unpack("H*", pack("C*", $val/256, $val%256)));
          $val = "0x".$val;
	} else { 
	  $val = "";
        }
        $line .= "<td".$s.">".$val."</td>";
      }
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
    $q->print("  <tr><th>Channel(s)</th><th>Fixture</th>");
    if ($self->{usegroups}) { $q->print("<th>Groups</th>"); }
    $q->print(join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my $patch = $self->{data}->{Patch}->{$chan};
      my $persidx = $patch->{personalityidx};
      my $pers = $self->{data}->{Personality}->{$persidx};
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "";
      $line .= "<td>".$pers->{model}."</td>";
      if ($self->{usegroups}) { $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>"; }
      foreach my $paramidx (@{$rec->{parameters}}) {
        my $val = $rec->{channels}->{$chan}->{$paramidx};
        my $perschan = $pers->{params}->{$paramidx};
        my $size = $perschan->{size};
        my $s="";
	if ($val =~ /^(CP)(\d+)$/) {
	   my $pal = $self->{data}->{ColorPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^FP(\d+)$/) {
	   my $pal = $self->{data}->{FocusPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^BP(\d+)$/) {
	   my $pal = $self->{data}->{BeamPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^([A-Za-z]+)(\d+)$/) {
        } elsif ($size==1) {
	  $val = uc(unpack("H*", pack("C*", $val%256)));
	  if ($self->{data}->{ParamNameToType}->{Red} == $paramidx) {
	    $s = " style='font-weight: bold; color: #".$val."0000;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Green} == $paramidx) {
	    $s = " style='font-weight: bold; color: #00".$val."00;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Blue} == $paramidx) {
	    $s = " style='font-weight: bold; color: #0000".$val.";'";
          }
          $val = "0x".$val;
        } elsif ($size==2) {
	  $val = uc(unpack("H*", pack("C*", $val/256, $val%256)));
          $val = "0x".$val;
	} else { 
	  $val = "";
        }
        $line .= "<td".$s.">".$val."</td>";
      }
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
    $q->print("  <tr><th>Channel(s)</th><th>Fixture</th>");
    if ($self->{usegroups}) { $q->print("<th>Groups</th>"); }
    $q->print(join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my $patch = $self->{data}->{Patch}->{$chan};
      my $persidx = $patch->{personalityidx};
      my $pers = $self->{data}->{Personality}->{$persidx};
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "";
      $line .= "<td>".$pers->{model}."</td>";
      if ($self->{usegroups}) { $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>"; }
      foreach my $paramidx (@{$rec->{parameters}}) {
        my $val = $rec->{channels}->{$chan}->{$paramidx};
        my $perschan = $pers->{params}->{$paramidx};
        my $size = $perschan->{size};
        my $s="";
	if ($val =~ /^(CP)(\d+)$/) {
	   my $pal = $self->{data}->{ColorPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^FP(\d+)$/) {
	   my $pal = $self->{data}->{FocusPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^BP(\d+)$/) {
	   my $pal = $self->{data}->{BeamPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^([A-Za-z]+)(\d+)$/) {
        } elsif ($size==1) {
	  $val = uc(unpack("H*", pack("C*", $val%256)));
	  if ($self->{data}->{ParamNameToType}->{Red} == $paramidx) {
	    $s = " style='font-weight: bold; color: #".$val."0000;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Green} == $paramidx) {
	    $s = " style='font-weight: bold; color: #00".$val."00;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Blue} == $paramidx) {
	    $s = " style='font-weight: bold; color: #0000".$val.";'";
          }
          $val = "0x".$val;
        } elsif ($size==2) {
	  $val = uc(unpack("H*", pack("C*", $val/256, $val%256)));
          $val = "0x".$val;
	} else { 
	  $val = "";
        }
        $line .= "<td".$s.">".$val."</td>";
      }
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='preset'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{Preset}}) {
    my $rec = $self->{data}->{Preset}->{$key};
    $q->print("<h2>Preset ".$rec->{index}.": ".$rec->{title}."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>Channel(s)</th><th>Fixture</th>");
    if ($self->{usegroups}) { $q->print("<th>Groups</th>"); }
    $q->print(join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my $patch = $self->{data}->{Patch}->{$chan};
      my $persidx = $patch->{personalityidx};
      my $pers = $self->{data}->{Personality}->{$persidx};
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "";
      $line .= "<td>".$pers->{model}."</td>";
      if ($self->{usegroups}) { $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>"; }
      foreach my $paramidx (@{$rec->{parameters}}) {
        my $val = $rec->{channels}->{$chan}->{$paramidx};
        my $perschan = $pers->{params}->{$paramidx};
        my $size = $perschan->{size};
        my $s="";
	if ($val =~ /^(CP)(\d+)$/) {
	   my $pal = $self->{data}->{ColorPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^FP(\d+)$/) {
	   my $pal = $self->{data}->{FocusPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^BP(\d+)$/) {
	   my $pal = $self->{data}->{BeamPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^([A-Za-z]+)(\d+)$/) {
        } elsif ($size==1) {
	  $val = uc(unpack("H*", pack("C*", $val%256)));
	  if ($self->{data}->{ParamNameToType}->{Red} == $paramidx) {
	    $s = " style='font-weight: bold; color: #".$val."0000;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Green} == $paramidx) {
	    $s = " style='font-weight: bold; color: #00".$val."00;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Blue} == $paramidx) {
	    $s = " style='font-weight: bold; color: #0000".$val.";'";
          }
          $val = "0x".$val;
        } elsif ($size==2) {
	  $val = uc(unpack("H*", pack("C*", $val/256, $val%256)));
          $val = "0x".$val;
	} else { 
	  $val = "";
        }
        $line .= "<td".$s.">".$val."</td>";
      }
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='submaster'/>$anchors");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{Sub}}) {
    my $rec = $self->{data}->{Sub}->{$key};
    $q->print("<h2>Submaster ".$rec->{index}.": ".$rec->{title}.($rec->{effectSub}?" EFFECTSUB":"")."</h2>\n");
    $q->print("<table>\n");
    $q->print("  <tr><th>Channel(s)</th><th>Fixture</th>");
    if ($self->{usegroups}) { $q->print("<th>Groups</th>"); }
    $q->print(join("", map { "<th>".$self->{data}->{ParamType}->{$_}."</th>" } @{$rec->{parameters}}),"</tr>\n");
    my %chans;
    foreach my $chan (sort { $a <=> $b } keys %{$rec->{channels}}) {
      my $patch = $self->{data}->{Patch}->{$chan};
      my $persidx = $patch->{personalityidx};
      my $pers = $self->{data}->{Personality}->{$persidx};
      my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$chan}};
      my $line = "";
      $line .= "<td>".$pers->{model}."</td>";
      if ($self->{usegroups}) { $line .= "<td>".join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups)."</td>"; }
      foreach my $paramidx (@{$rec->{parameters}}) {
        my $val = $rec->{channels}->{$chan}->{$paramidx};
        my $perschan = $pers->{params}->{$paramidx};
        my $size = $perschan->{size};
        my $s="";
	if ($val =~ /^(CP)(\d+)$/) {
	   my $pal = $self->{data}->{ColorPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^FP(\d+)$/) {
	   my $pal = $self->{data}->{FocusPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^BP(\d+)$/) {
	   my $pal = $self->{data}->{BeamPalette}->{$2};
	   if ($pal) { $val .= " [".$pal->{title}."]"; }
	} elsif ($val =~ /^([A-Za-z]+)(\d+)$/) {
        } elsif ($size==1) {
	  $val = uc(unpack("H*", pack("C*", $val%256)));
	  if ($self->{data}->{ParamNameToType}->{Red} == $paramidx) {
	    $s = " style='font-weight: bold; color: #".$val."0000;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Green} == $paramidx) {
	    $s = " style='font-weight: bold; color: #00".$val."00;'";
	  } elsif ($self->{data}->{ParamNameToType}->{Blue} == $paramidx) {
	    $s = " style='font-weight: bold; color: #0000".$val.";'";
          }
          $val = "0x".$val;
        } elsif ($size==2) {
	  $val = uc(unpack("H*", pack("C*", $val/256, $val%256)));
          $val = "0x".$val;
	} else { 
	  $val = "";
        }
        $line .= "<td".$s.">".$val."</td>";
      }
      $chans{$chan} = $line;
    }
    my $output = consolidate_lines(\%chans);
    foreach my $line (@$output) {
      $q->print("  <tr>$line</tr>\n");
    }
    $q->print("</table>\n");
  }
  $q->print("<a name='groups'/>$anchors");
  $q->print("<h2>Groups</h2><br/>");
  $q->print("<table>\n");
  $q->print("  <tr><th>Group</th><th>Channels</th></tr>\n");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{Group}}) {
    my $rec = $self->{data}->{Group}->{$key};
    $q->print("  <tr>".join("", map { "<td>$_</td>" } ($rec->{title}."[".$key."]", htmlize(friendly_channels(@{$rec->{channels}}))) )."</tr>\n");
  }
  $q->print( "</table>\n");
  $q->print("<a name='patch'/>$anchors");
  $q->print("<h2>Patch List</h2><br/>");
  $q->print("<table>\n");
  $q->print("  <tr><th>Channel</th><th>Type</th><th>Address</th><th>Univ</th><th>lcl</th><th>Addr</th><th>AddrHex</th><th>Group(s)</th></tr>\n");
  foreach my $key (sort { $a <=> $b } keys %{$self->{data}->{Patch}}) {
    my @groups = sort { $a <=> $b } keys %{$self->{data}->{ChannelToGroups}->{$key}};
    my $grptxt = join(",", map { $self->{data}->{Group}->{$_}->{title}."[".$_."]" } @groups);
    my $rec = $self->{data}->{Patch}->{$key};
    my $pers = $self->{data}->{Personality}->{$rec->{personality}};
    my $numaddr = defined($pers)?$pers->{numaddr}:1;
    $q->print("  <tr ".($rec->{dmx}>0?"class='active'":"class='inactive' style='display:none'").">");
    $q->print("<td>".$rec->{index}."</td><td style='text-align:left;'>".$rec->{personality}."</td>");
    $q->print(join("", map { "<td>$_</td>" } ( $numaddr, $rec->{universe}, $rec->{localdmx}, $rec->{dmx}, "0x".uc(unpack("H*", pack("C*", $rec->{dmx}/256, $rec->{dmx}%256)))), $grptxt)."</tr>\n");
  }
  $q->print( "</table>\n");
}

sub page_end {
  my $self = shift;
  my $q = shift || new CGI;

  $q->print( "</body></html>\n");
}
1;
