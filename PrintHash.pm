#!/usr/bin/perl
#
# Author:  mrwizard@k12system.com (Joseph Gooch)
#
# Print a hash hierarchically
#
# $Revision$
# $Id$
#

package PrintHash;

our (@ISA, @EXPORT, @EXPORT_OK) = ();
@ISA = qw(Exporter);
@EXPORT = qw(&print_hash &print_hashref);
@EXPORT_OK = @EXPORT;

require Exporter;
use strict qw(vars);


sub print_hash {
    my ($header, %hash)=@_;

    my (@delayed);   
    foreach (sort keys %hash) {
        if (ref($hash{$_}) eq "HASH") {
            push(@delayed, $_);
        } elsif (scalar(keys %{$hash{$_}}) == 0) {
            print $header, "$_: ", $hash{$_}, "\n";                  
        } else {
            push(@delayed, $_);
        }
    }                  
    foreach (sort @delayed) {
        print $header, "$_:\n";
        print_hash("$header   ", %{$hash{$_}});                 
    }          

}

sub print_hashref {
    my ($header, $hash)=@_;

    my (@delayed);
    foreach (sort keys %$hash) {
        if (ref($hash->{$_}) eq "HASH") {
            push(@delayed, $_);
        } elsif (scalar(keys %{$hash->{$_}}) == 0) {
            print $header, "$_: ", $hash->{$_}, "\n";                  
        } else {
            push(@delayed, $_);
        }
    }                  
    foreach (sort @delayed) {
        print $header, "$_:\n";
        print_hash("$header   ", %{$hash->{$_}});                 
    }          

}
    

1;

