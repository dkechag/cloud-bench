#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;

use Benchmark::DKbench;
use Capture::Tiny 'tee_stdout';
use Getopt::Long;
use List::Util qw(min max sum);
use LWP::Simple;
use System::CPU;
use Time::HiRes qw(CLOCK_MONOTONIC);

my %opt = (iter => 5, out => '/root/bench.csv');

GetOptions(
    \%opt,
    'geekbench|g',
    'include=s',
    'out=s',
    'iter|i=i'
);

my ($stats, $stats_multi, $scal) = suite_calc({
        iter    => $opt{iter},
        include => $opt{include}
});

open OUT, ">$opt{out}";

my $arch = `uname -m`;
chomp($arch);
$arch = 'amd64' if $arch eq 'x86_64';
$arch = 'arm64' if $arch eq 'aarch64';
my $ncpu   = $stats_multi->{_opt}->{threads};
my $single = "DKbench Single Core\n";
my $multi  = "DKbench Multi Core\n";
my $name   = System::CPU::get_name();
say "Benchmarking $name - $ncpu threads";

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

say "Perlbrew compilation...";
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
    perlbrew uninstall perl-5.36.0'
};

say "Phoronix 7zip...";
my $out = tee_stdout { system "phoronix-test-suite batch-benchmark compress-7zip" };
my @avg = ($out =~ /Average:\s+(\d+)\s+MIPS/g);
print OUT "7Zip Compress,$avg[0]\n7Zip Decompress,$avg[1]\n";
say "Phoronix OpenSSL...";
$out = tee_stdout { system "echo 1|phoronix-test-suite batch-benchmark openssl" };
@avg = ($out =~ /Average:\s+(\S+)\s+sign/g);
print OUT "OpenSSL RSA4096 sign/s,$avg[0]\n";

say "FFmpeg bench...";
my $vid = "/root/big_buck_bunny_720p_h264.mov";
system "wget https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_720p_h264.mov -O $vid"
    unless -f $vid;

$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
system "ffmpeg -i $vid -c:v libx264 -threads 1 out264a.mp4";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC)-$t;
print OUT "FFmpeg Single,$t\n";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
system "ffmpeg -i $vid -c:v libx264 -threads $ncpu out264b.mp4";
$t = Time::HiRes::clock_gettime(CLOCK_MONOTONIC)-$t;
print OUT "FFmpeg Multi,$t\n";

if ($opt{geekbench}) {
    my $folder = $arch eq 'arm64' ? 'Geekbench-5.4.0-LinuxARMPreview' : 'Geekbench-5.4.4-Linux';
    $out = tee_stdout {system "/root/$folder/geekbench5"};
    if ($out =~ m#(https://browser.geekbench.com/v5/cpu/\d+)#) {
        my $url  = $1;
        my $html = get($url) || '';
        my ($single) = $html =~ m#Single-Core Score\s*</th>\s*<th class='score'>\s*(\d+)#si;
        my ($multi)  = $html =~ m#Multi-Core Score\s*</th>\s*<th class='score'>\s*(\d+)#si;
        print OUT "Geekbench 5 Single,$single\nGeekbench 5 Multi,$multi\n"
            if $single && $multi;
        if ($out =~ /Base Frequency\s+(\S+)\s*GHz/) {
            print OUT "Geekbench 5 GHz,$1\n"
        }
        print OUT "Geekbench5,$url\n";
    }
}
print OUT "CPU,$name\n";

say "Results:";
system "cat $opt{out}";
say "\nSaved in $opt{out}";

close OUT;

sub _calc {
    my $arr = shift;
    return (0, 0, 0, 0) unless @$arr;
    return sum(@$arr)/scalar(@$arr), min(@$arr), (max(@$arr)-min(@$arr)), max(@$arr);
}
