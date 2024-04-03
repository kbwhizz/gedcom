#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
#gedutil_merge.pl 
#
#warn "A utility to merge 2 GEDCOM files.";
my $input_file=$ARGV[0];
my $append_file=$ARGV[1];
my $input_fhash_file=$input_file;
$input_fhash_file=~s/master_collapsed/idhash/;
$input_fhash_file=~s/.ged/.txt/;
my $append_fhash_file=$append_file;
$append_fhash_file=~s/append_collapsed/idhash/;
$append_fhash_file=~s/.ged/.txt/;
my $input_utags_file=$input_file;
$input_utags_file=~s/master_collapsed/ufields/;
$input_utags_file=~s/.ged/.txt/;
my $append_utags_file=$append_file;
$append_utags_file=~s/append_collapsed/ufields/;
$append_utags_file=~s/.ged/.txt/;
my $input_names_file=$input_file;
$input_names_file=~s/master_collapsed/names/;
$input_names_file=~s/.ged/.txt/;
my $append_names_file=$append_file;
$append_names_file=~s/append_collapsed/names/;
$append_names_file=~s/.ged/.txt/;

# open master file
open(INFO, '<', $input_file) or die("Could not open master $input_file.");

# open append file
open(INFOAPPEND, '<', $append_file) or die("Could not open append $append_file.");

warn "Opening $input_file and $append_file for read";

# read append file to array for later manipulation if need be on id duplicates
my @appendrecords=();
while(<INFOAPPEND>) {
	chomp $_;
	push @appendrecords, $_;
}

# open a log for duplicates to be recorded in 
my $logdir="";
if($input_file=~m{(.*)\/(.*)}) {
  $logdir=$1;
}
open(LOGD, '>', "$logdir/mergedupslog.txt") or die("Could not open $logdir/mergedupslog.txt.");

# 1. open hash of IDs from master file
# ie I1	Y
my %ids_master_file=();
open(INFOHASH, '<', $input_fhash_file) or die("Could not open master $input_fhash_file.");
while(<INFOHASH>) {
	chomp $_;
	$ids_master_file{$_}="Y";
}

# names translator
my %names_master=();
open(INFONAMES, '<', $input_names_file) or die("Could not open master $input_names_file.");
while(<INFONAMES>) {
	chomp $_;
	if($_=~m{^([^\t]*)\t(.*)}) {
		$names_master{$1} = $2;
	}
}

my %names_append=();
open(INFONAMESAPPEND, '<', $append_names_file) or die("Could not open master $append_names_file.");
while(<INFONAMESAPPEND>) {
	chomp $_;
	if($_=~m{^([^\t]*)\t(.*)}) {
		$names_append{$1} = $2;
	}
}

# 2. create hash of IDs from append file
# ie I1	Y
my %ids_append_file=();
open(INFOAPPENDHASH, '<', $append_fhash_file) or die("Could not open master $append_fhash_file.");
while(<INFOAPPENDHASH>) {
	chomp $_;
	$ids_append_file{$_}="Y";
}
my %dupids=();
# add duplicates to a hash for new ids to make them new in the append file
my $dupm="";
my $dupa="";
foreach (keys %ids_append_file) {
	if(exists($ids_master_file{$_})) {
		my $dupv=$_;
		until (!exists($ids_master_file{$_})) {
			my $cfirst = substr $_, 0,1;
			my $crest = substr $_, 1;
			$_ = $cfirst . "9" . $crest;
			$_=~s/\@.*//;
		}
		$dupids{$dupv}=$_;
		if(exists($names_master{$_})) { $dupm=$names_master{$_} } else { $dupm="NO NAME SUPPLIED"; }
		if(exists($names_append{$_})) { $dupa=$names_append{$_} } else { $dupa="NO NAME SUPPLIED"; }
		print LOGD "Found Duplicate ID $dupv which is renumbered $dupids{$dupv} on records: MASTER $dupm and APPEND $dupa\n";
	}
}

# 3. open two hashes of CONTENTTAG count to allow us to know which tags need writing from each file.
# Master includes HEAD, SUBM and TRLR but append does not
my @tags_master=();
open(INFOTAGS, '<', $input_utags_file) or die("Could not open master $input_utags_file.");
while(<INFOTAGS>) {
	chomp $_;
	push @tags_master, $_;
}

my %tags_append=();
open(INFOAPPENDTAGS, '<', $append_utags_file) or die("Could not open append $append_utags_file.");
while(<INFOAPPENDTAGS>) {
	chomp $_;
	$tags_append{$_}="Y";
}


# update any duplicate ids in the appendrecords array.
foreach (keys %dupids) {
        foreach my $ar (@appendrecords) {
		#if($ar=~m{\@I551\@}) { warn $ar; }
		if($ar=~m{\@$_\@}) {
			$ar=~s/\@$_\@/\@$dupids{$_}\@/g;
		}
	}
}


my $tag="";
foreach my $mtag (@tags_master) {
 # cycle file master
 seek INFO, 0, 0;
 warn "Processing $mtag";
 while(my $line = <INFO>) {
        chomp($line);
	$tag="";

        # write the particular tag. HEAD/TRLR and SUBM are slightly different in format and should only be written from the master file	
	if($line=~m{^0 HEAD} && $mtag eq "HEAD") {
		 print "$line\n";
		 last;
	}
	elsif($line=~m{^0 TRLR} && $mtag eq "TRLR") {
		 print "$line\n";
		 last;
	}
	elsif($line=~m{^0 .SUBM} && $mtag eq "SUBM") {
		 # write any remaining tags in the append hash (if any)
		 foreach (keys %tags_append) {
                   writeappendfiletag($_);                       
		 } 
		 print "$line\n";
		 last;
	}
	elsif($line=~m{^0 \@([^\@]*)\@ ([^\¬]*)\¬}) {
		$tag=$2;
                if($mtag eq $tag) {
		   print "$line\n";
	        }
	}
	else {
		#warn "Non match $line with tag $mtag. Investigate";
	}

   }
   if(exists($tags_append{$mtag})) {
	warn "Appending file with tag $mtag";
        writeappendfiletag($mtag);
	#remove from hash
	delete($tags_append{$mtag});
   }
}


sub writeappendfiletag {
	my ($tg) = @_;
	my $t="";
	my $id="";
	my $i=0;
	for(my $a=0; $a < scalar(@appendrecords); $a++) {
	   if($appendrecords[$a]=~m{^0 \@([^\@]*)\@ ([^\¬]*)\¬}) { 
	      $id=$1;
	      $t=$2;
	      # take the record and array and change all occurences of old id to new foreach line
	      if($t eq $tg) {
 	        print "$appendrecords[$a]\n";
		$i++;
              }
	   }
	}
        warn "Appended $i lines for $tg";
}
