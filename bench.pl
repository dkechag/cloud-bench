#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;

use Benchmark::DKbench;
use Getopt::Long;
use List::Util qw(min max sum);
use Time::HiRes qw(CLOCK_MONOTONIC);

my %opt = (iter => 5);

GetOptions(
    \%opt,
    'geekbench|g',
    'include=s',
    'iter|i=i'
);

my ($stats, $stats_multi, $scal) = suite_calc({
        iter    => $opt{iter},
        include => $opt{include}
});

open OUT, '>/root/bench.csv';

my $arch = `uname -m`;
chomp($arch);
$arch = 'amd64' if $arch eq 'x86_64';
$arch = 'arm64' if $arch eq 'aarch64';
my $ncpu   = $stats_multi->{_opt}->{threads};
my $single = "DKbench Single Core\n";
my $multi  = "DKbench Multi Core\n";

foreach my $key (sort keys $stats->%*) {
    next if $key =~ /^_/;
    my $arr = $stats->{$key}->{scores};
    next unless $arr && @$arr;
    my $avg = sum(@$arr)/scalar(@$arr);
    $single .= "$key,$avg\n";
    $arr = $stats_multi->{$key}->{scores};
    $avg = sum(@$arr)/scalar(@$arr);
    $multi .= "$key,$avg\n";
}

print OUT $single;
my @key = qw /avg min diff max/;
my @val = _calc($stats->{_total}->{scores});
print OUT "Total $key[$_],$val[$_]\n" for 0..$#key;
print OUT $multi;
@val = _calc($stats_multi->{_total}->{scores});
print OUT "Total $key[$_],$val[$_]\n" for 0..$#key;
print OUT "Threads,$ncpu\n"; 
print OUT "Scalability,$scal->{_total}\n"; 

my $t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
system qq{
  bash -c '
    set -e
    source /root/perl5/perlbrew/etc/bashrc
    perlbrew install perl-5.36.0 -n -j$ncpu'
};
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC)-$t;

system qq{
  bash -c '
    set -e
    source /root/perl5/perlbrew/etc/bashrc
    perlbrew uninstall perl-5.36.0
};

my $out = `phoronix-test-suite batch-benchmark compress-7zip`;
my @avg = ($out =~ /Average:\s+(\d+)\s+MIPS/g);
print OUT "7Zip Compress,$avg[0]\n7Zip Decompress,$avg[1]\n";
$out = `echo 1|phoronix-test-suite batch-benchmark openssl`;
@avg = ($out =~ /Average:\s+(\S+)\s+sign/g);
print OUT "OpenSSL RSA4096 sign/s,$avg[0]\n";

$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
system "ffmpeg -i /root/big_buck_bunny_720p_h264.mov -c:v libx264 -threads 1 out264a.mp4";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC)-$t;
print OUT "FFmpeg Single,$t\n";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
system "ffmpeg -i /root/big_buck_bunny_720p_h264.mov -c:v libx264 -threads $ncpu out264b.mp4";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC)-$t;
print OUT "FFmpeg Multi,$t\n";

close OUT;

system $arch eq 'arm64' ? "Geekbench-5.4.0-LinuxARMPreview/geekbench5" : "Geekbench-5.4.4-Linux/geekbench5"
    if $opt{geekbench};

sub _calc {
    my $arr = shift;
    return (0, 0, 0, 0) unless @$arr;
    return sum(@$arr)/scalar(@$arr), min(@$arr), (max(@$arr)-min(@$arr)), max(@$arr);
}
