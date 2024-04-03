#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
#gedutil.pl 
#
#warn "A utility to crunch or expand a GEDCOM file.";
my $input_file=$ARGV[0];
my $indiv_chosen=$ARGV[1];
my $anc_skip=$ARGV[2];
my $ged_special_tags=$ARGV[3];
my $title=$ARGV[4];
my $line="";
my $remainfname="";

# open file
open(INFO, '<', $input_file) or die("Could not open $input_file.");
if($input_file=~m{^(.*)\.}) {
  $remainfname = $1 . "_remains.ged";
}
#open a log file in the same folder as the input_file
warn  "Running perl script";
warn "Opening $input_file";
my $logdir="";
if($input_file=~m{(.*)\/(.*)}) {
  $logdir=$1;
}
# Another "remaining" file is also needed so opening for write here.
warn "Opening file for remaining GEDCOM to be written to: $remainfname";
open(REMAINS, '>', "$remainfname") or die("Could not open $remainfname.");
warn "Logs will be written into the same folder as the input file which must be writable";
warn "Creating log files...";
warn "Open log file for descendent trawls: $logdir/desclog.txt";
open(LOGD, '>', "$logdir/desclog.txt") or die("Could not open $logdir/desclog.txt.");
warn "Open log file for ancestor search: $logdir/anclog.txt";
open(LOGA, '>', "$logdir/anclog.txt") or die("Could not open $logdir/anclog.txt.");
warn "Open log for collected descendant individuals: $logdir/collind.txt";
open(CLOGD, '>', "$logdir/collindlog.txt") or die("Could not open $logdir/collindlog.txt.");
warn "Open log for collected descendant families: $logdir/collfamlog.txt";
open(CLOGF, '>', "$logdir/collfamlog.txt") or die("Could not open $logdir/collfamlog.txt.");
#
# 1. create hash of individuals to FAMS (married families)
# ie I1	F1|F2
my %ind_family_ids=();
;
# 2. create hash of famids to children born (1 to many)
# ie F1	I1|I2
my %fam_children_ids=();

# 3. create hash of famids to spouses (1 to 2)
# ie F1 I3|I90
my %fam_spouse_ids=();

# 4. create hash of individual to natural parents (1 to 2)
# ie F1 I76|I85
my %ind_parents_ids=();

# 5. Individuals and names
my %ind_id_names=();

# 6. Indiv to family as child id.
my %ind_to_famaschild=();

# 7. Special Gedcom tags derived from parameter 4
my %gtags=();
foreach my $gtag (split /¬/, $ged_special_tags) {
     $gtags{$gtag} = "Y";
}

# 8. Special Gedom tag data collected 
my %spe_tags=();

my $famids="";
my $famchildren="";
my $famspouses="";

# cycle file for hash content collection
while($line = <INFO>) {
        chomp($line);
	my $iid="";
	my $name="";
	my $specgedtag="";
	if($line=~m{^0 \@([^\@]*)\@ INDI\¬}) {
		$iid=$1;
	        if($line=~m{^0 \@([^\@]*)\@ INDI\¬1 NAME ([^¬]*)¬}) {
		  $name=$2;
		  if($name eq "") { $name="NO LISTED NAME"; }
		  $ind_id_names{$iid}=$name;
	        }
		else {
		  # no NAME
		  $ind_id_names{$iid}="BLANK NAME PRIVATE";
		}
		# Collect names
		# As a person can have more than one family, we need to make the family id an array split by a separator.
		# Look for 1 FAMS fields in the line and parse them out
	        if($line=~m{^0 \@([^\@]*)\@ INDI\¬.*1 FAMS \@([^\@]*)\@}) {
		  my @sublines = split /¬/, $line;
                  my @famids=();
	          foreach my $subline (@sublines) {
			if($subline=~m{^1 FAMS \@([^\@]*)\@}) {
			  push(@famids, $1);
			}
		  }	
		  $ind_family_ids{$iid} = join '|', @famids;
	        }
		# indiv to family as child id
		if($line=~m{^0 \@([^\@]*)\@ INDI\¬.*1 FAMC \@([^\@]*)\@}) {
                  $ind_to_famaschild{$1}=$2;
		}

	}
	elsif($line=~m{^0 \@([^\@]*)\@ FAM\¬}) {
                my $fid=$1;
                # As a person can have more than one family, we need to make the family id an array split by a separator.
                # a. look for 1 CHIL fields in the line and add to array
		# b. look for familyids and their spouses.
                my @subfamlines = split /¬/, $line;
                my @childids=();
		my @spouseids=();
		my $father="";
		my $mother="";
                foreach my $subfamline (@subfamlines) {
                        if($subfamline=~m{^1 CHIL \@([^\@]*)\@}) {
                          push(@childids, $1);
                        }
                        if($subfamline=~m{^1 (HUSB|WIFE) \@([^\@]*)\@}) {
			  my $spousetype=$1;
		          my $spousecurr=$2;
                          if($spousetype eq "HUSB") { 
				  $father=$spousecurr; 
			  } 
			  else { 
				  $mother=$spousecurr; 
			  }			  
                          push(@spouseids, $2);
                        }
                }
		# add parents of each child to hash
		foreach my $child_in_family (@childids) {
			$ind_parents_ids{$child_in_family} = "$father|$mother";
		}
                $fam_children_ids{$fid} = join '|', @childids;
                $fam_spouse_ids{$fid} = join '|', @spouseids;
        }
	else {
		#make hash of special tags using format <TAG><ID>=line
		# get the tag "0 @*@ <TAG> "
		if($line=~m{^0 \@([^\@]*)\@ ([^¬]*)¬}) {
			my $oid=$1;
			my $tg=$2;
	                if(exists($gtags{$tg})) {	
			  $specgedtag=$tg . " " . $oid;
			  $spe_tags{$specgedtag} = $line;
			  #warn $specgedtag;
		        }

		}
		#warn "Tag is $line";
		#exit;
	}

}
#
# set up hashes for individuals and families which will get extracted
my %indivs_to_extract=();
my %fams_to_extract=();

# start with individual chosen
#
$indivs_to_extract{$indiv_chosen}="Y";
#
#
# add their family - if any
#
warn "Primed with chosen individual $indiv_chosen";
my $chosen_indiv_famaschild=""; # empty as default
if(exists($ind_to_famaschild{$indiv_chosen})) {
	$chosen_indiv_famaschild=$ind_to_famaschild{$indiv_chosen};
	warn "The chosen individual has parents: $chosen_indiv_famaschild";
}

get_descs($indiv_chosen);

print LOGD "END OF INITIIAL DESCENDANT TRAWL>>>>>>>>>>>>>>\n";
warn "Collecting extra ancestors (if any)...";


my @rootpeople=(); # to hold extracted people who are at the root
my %rootpeoplehash=(); # to ensure we only collect root people once
my $indivs_to_extract_count = scalar keys %indivs_to_extract;
warn "There are $indivs_to_extract_count individuals already collected before we try to collect any linked families.";


# Collect root people from descendant list, and find their ancestors (recurse) until there are no more to find
expandancestrycandidates(\%indivs_to_extract);

lognames(\%indivs_to_extract, \%fams_to_extract);

# construct the new gedcom file
# go through each line  in input file.
# Filter on INDI or FAMS or "OTHER" special.
seek INFO, 0, 0;
$line="";
my %othertagshash=();
my %othertagshash_REMAINS=();
my @finallines=();
my @finallinesremains=();
warn "Constructing new gedcom files...";
while($line = <INFO>) {
	chomp $line;
	if($line=~m{^0 \@([^\@]*)\@ INDI\¬}) {
	   if(exists($indivs_to_extract{$1})) {
	    # remove FAMC of chosen individual as he has none in the new file
	    if($line=~m{^0 \@$indiv_chosen\@}) {
		    $line=~s/¬1 FAMC \@[^\@]*\@//;
	    }
	    push @finallines, $line;
	    getothertagrefs(\%gtags, $line, \%othertagshash);
           }
	   else {
	    push @finallinesremains, $line;
	    getothertagrefs(\%gtags, $line, \%othertagshash_REMAINS);
	   }   
	}
        elsif($line=~m{^0 \@([^\@]*)\@ FAM\¬}) {
          if(exists($fams_to_extract{$1})) {
	    push @finallines, $line;
            # collect OTHER tag refs
            getothertagrefs(\%gtags, $line, \%othertagshash);
           }
	   else {
	    push @finallinesremains, $line;
	    getothertagrefs(\%gtags, $line, \%othertagshash_REMAINS);
	   }   
        }
	elsif($line=~m{^0 HEAD|^0 TRLR|^0 .SUBM}) {
		    # amend HEAD by appending title
		    if($line=~m{^0 HEAD}) {
			    if($line=~m{¬1 FILE ([^¬]*)¬}) {
				    my $ttl=$1;				    
				    my $newttl=$ttl . " (SOURCE: " . $input_file . ")";
				    $line=~s/$ttl/$newttl/;
			    }
		    }
	            push @finallines, $line;
	            push @finallinesremains, $line;
	}
	else {
		# must be an OTHER tag so look for match in hash
		foreach (keys %gtags) {
			if($line=~m{^0 \@([^\@]*)\@ $_}) {
			   my $tagrefoth=$_ . " " . $1;			  
			   if(exists($othertagshash{$tagrefoth})) {
	                           push @finallines, $line;
			   }
			   if(exists($othertagshash_REMAINS{$tagrefoth})) {
	                           push @finallinesremains, $line;
			   }
			 }
		}	
	}
}

# print out the array to file amending the anc_skip line (if present) to remove superfluous family links.
my $ancINDI="";
foreach my $ln (@finallines) {
   if($ln=~m{\@$anc_skip\@ INDI}) {
	   warn "Amending line for ancestor skip $anc_skip";
	   # save anc_skip INDI line so it can be written to remains file
	   $ancINDI=$ln;
	   # always remove FAMC
           if($ln=~m{(1 FAMC \@[^\@]*\@¬)}) {
                # always remove family as child
		#warn "Removing $1";
                $ln=~s/$1//;
           }
	   if($ln=~m{1 FAMS \@([^\@]*)\@}) {
                if(exists($ind_family_ids{$anc_skip})) {
                  foreach my $famid (split /\|/, $ind_family_ids{$anc_skip}) {
                                  #  remove them unless in the families collected hash
                       if(!exists($fams_to_extract{$famid})) {
                           $ln=~s/1 FAMS \@$famid\@¬//;
			   my $othspouse=$fam_spouse_ids{$famid};
			   $othspouse=~s/\|?$anc_skip\|?//;
			   #warn "Removing FAMS $famid which includes the ancestors of spouse $othspouse - $ind_id_names{$othspouse}";
                       }
		       else {
			   #warn "Leaving FAMS $famid which is already linked in the file.";
		       }
                  }

                }
           }

	   # check families partners and remove any not collected
	   #warn ">>>>>>>End of amending line for ancestor skip $anc_skip >>>>>>";
	   
   }
   print "$ln\n";
}
my $first="N";
foreach my $ln (@finallinesremains) {
	# insert ancINDI line if it is set just before FAM starts, after the INDI lines.
	if($ancINDI ne "" && $ln=~m{^0 \@F} && $first eq "N") {
		print REMAINS "$ancINDI\n";
		$first="Y";
	}
	# if chosen indiv as CHIL under FAM, remove the ref
        if($ln=~m{(1 CHIL \@$indiv_chosen\@¬)}) {
		$ln=~s/$1//;
	}
	print REMAINS "$ln\n";
}

#>>>>>>>>>>>Functions from here>>>>>>>>>>>>>
#
#


sub getothertagrefs {
     # build othertagshash
     my ($gtags, $line, $othertagshash) = @_;
     my @othmatches=();
	 for (keys  %{$gtags}) {
			if($line=~m{$_}) {
				# can be multiple sources per line so need to extract them all.
				@othmatches = $line =~ m/($_ \@[^\@]*\@)/g;
				foreach my $om (@othmatches) {
				 if($om=~m{$_ \@([^\@]*)\@}) {
				   my $tagref=$_ . " " . $1;
				   if(!exists($othertagshash->{$tagref})) {
					 # add to othertagshash
					 $othertagshash->{$tagref} = "Y";
				   }
			         }
				}
			}
	}
}

sub expandancestrycandidates
{
my ($ivs_2_xtract) = @_;
my $start_count = scalar keys %{$ivs_2_xtract};
for (keys %{$ivs_2_xtract}) {
	if(!exists($ind_parents_ids{$_})) {
		#nothing to do
	}
	else {
		# Have we collected each parent already?
		foreach my $parent (split /\|/, $ind_parents_ids{$_} ) {
		  if(!exists($ivs_2_xtract->{$parent})) {
 	         if(!exists($rootpeoplehash{$parent})) {
		      # skip parents of chosen individual 
		      if($ind_parents_ids{$indiv_chosen}=~m{^$parent\||\|$parent$}) {
			    print LOGA "Skipping parent of chosen individual\n";
                            $rootpeoplehash{$parent}="Y";
			    next;
		      }	    
		      # or the anc_skip option
		      if($_ eq $anc_skip) { 
			    print LOGA "Skipping ancskip option $anc_skip\n";
                            $rootpeoplehash{$parent}="Y";
			    next; 
		      }
		      # or illegitimate line
		      if($parent eq "") { next; }
                    print LOGA "We need to collect parent of $_ : $parent\n";
                    push(@rootpeople, $parent);
                    $rootpeoplehash{$parent}="Y";
		    $indivs_to_extract{$parent}="Y";
		    # this will force more people to be considered for having ancestors to ensure a full crawl
		    print LOGA "Getting descs of $parent\n";
		    get_descs($parent);
	         }
	       }


	       }
	}
}
#my $end_count = scalar keys %indivs_to_extract;
my $end_count = scalar keys %{$ivs_2_xtract};
if($start_count != $end_count) {
   expandancestrycandidates(\%indivs_to_extract);	
}

}



sub lognames
{
#print collected individuals to file before ancestors trawled
	##BROKEN
my ($people, $families) = @_;

for (keys %{$people}) {
	my $name="";
	if(exists($ind_id_names{$_})) {
		$name=$ind_id_names{$_};
	}
	print CLOGD "$_\t$name\n";
}
#print collected family ids to file
print CLOGF "$_\n" for (keys %{$families});
}


sub get_descs {
        my ($personid) = @_;
        get_families($personid);
}


sub get_families {
  my ($ind_id) = @_;
  if(exists($ind_family_ids{$ind_id})) {
        foreach my $famid (split /\|/, $ind_family_ids{$ind_id}) {
          print LOGD "Family of $ind_id ($ind_id_names{$ind_id}) is $famid\n";
          # do not get family as child of individual chosen
          if($famid eq $chosen_indiv_famaschild) {
            print LOGD "Skipping family $famid of chosen individual $indiv_chosen\n";
            next;
          }
          if(!exists($fams_to_extract{$famid})) {
                   print LOGD "Adding $ind_id ($ind_id_names{$ind_id}) to family ID $famid hash\n";
                  $fams_to_extract{$famid}="Y";
                  get_spouses($famid, $ind_id);
          }
          else {
                  print LOGD "Must have added family before so skipping...\n";
          }
        }
  }
  else {
          print LOGD "No marriage family for $ind_id ($ind_id_names{$ind_id}) but adding as individual\n";
          $indivs_to_extract{$ind_id}="Y";
  }
}

sub get_spouses {
   my ($fam_id, $ind_id) = @_;
   if(exists($fam_spouse_ids{$fam_id})) {
        foreach my $famspouse (split /\|/, $fam_spouse_ids{$fam_id}) {
          # only take spouse not the individual themselves
          if($famspouse ne $ind_id) {
           print LOGD "Spouse(s)  of $fam_id include: $famspouse ($ind_id_names{$famspouse}) \n";
           if(!exists($indivs_to_extract{$famspouse})) {
                  print LOGD "Adding $famspouse ($ind_id_names{$famspouse}) the spouse of $ind_id ($ind_id_names{$ind_id}) to individuals hash\n";
                  $indivs_to_extract{$famspouse}="Y";
           }
           get_children($fam_id);
          }
          else {
           print LOGD "Adding $ind_id  ($ind_id_names{$ind_id}) themselves to individuals hash\n";
           $indivs_to_extract{$ind_id}="Y";
          }
        }
   }

}

sub get_children {
        my ($fam_id) = @_;
        print LOGD "Children of family $fam_id are:\n";
        if(exists($fam_children_ids{$fam_id})) {
                foreach my $child (split /\|/, $fam_children_ids{$fam_id}) {
                        print LOGD "Child of $fam_id is $child ($ind_id_names{$child})\n";
                        # recurse
                        get_families($child);

                }
        }

} 
sub sosaAncestors
{
	# not in use but may help someone needing a perl implementation of this
        my ($personid) = @_;
	#my $generations=-1;
        my $generations=4;
	#my %ancestors=();
	$::ancestors{1}= $personid;

	# Subtract one generation, as this algorithm includes parents.
        my $max = 2 ** ($generations - 1);

        for (my $i = 1; $i < $max; $i++) {
		#$::ancestors{$i * 2} =  "undef";
	        #$::ancestors{$i * 2 + 1} = "undef";
            my $person = $::ancestors{$i};
            if ($person) {
	          my $family="";
		  if(exists($ind_to_famaschild{$personid})) {
                    $family = $ind_to_famaschild{$personid};					  }
                  if ($family) {
		    if(getSpouse($family, "h") ne "") {
			 $::ancestors{$i * 2} = getSpouse($family, "h");
		    }
		    if(getSpouse($family, "w") ne "") {
			 $::ancestors{$i * 2 + 1} = getSpouse($family, "w");
		    }
                  }
            }
        }
}

sub getSpouse
{
   my ($famid, $spousetype) = @_;
   my $spouseid="";
   # get spouse id from family hash
   if(exists($fam_spouse_ids{$famid})) {
     # pipe delimited result always reports HUSB and then WIFE
	 if($spousetype eq "h") {
	   if($fam_spouse_ids{$famid}=~m{^([^\|]*)}) {
	    $spouseid=$1;
	   }
	 }
	 else {
	   if($fam_spouse_ids{$famid}=~m{^[^\|]*\|([^\|]*)}) {
	    $spouseid=$1;
	   }
	 }
   }
   return $spouseid;
}
