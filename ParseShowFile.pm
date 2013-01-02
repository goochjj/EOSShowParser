#!/usr/bin/perl

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
  my $p = ref($self)?shift @_:$self;
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

1;
