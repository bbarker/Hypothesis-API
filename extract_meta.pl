#!/usr/bin/perl
use lib './lib';
use Hypothesis::API;
use File::Copy;

my $V = $Hypothesis::API::VERSION;

system('tar', '--extract', "--file=Hypothesis-API-$V.tar.gz", 
       "Hypothesis-API-$V/META.json", "Hypothesis-API-$V/META.yml");

copy("Hypothesis-API-$V/META.json", 'META.json');
copy("Hypothesis-API-$V/META.yml", 'META.yml');

system('rm', '-fr', "Hypothesis-API-$V");
