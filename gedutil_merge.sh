#!/bin/bash
# gedutil_merge.sh 20240225
# Merges a GEDCOM file
#
# ensure folder /myebs/scripts  exists and is writeable and place this script there
# execute with bash
in_dir="/tmp"
out_dir="/tmp"

echo "gedutil_merge.sh: Merges a GEDCOM file. 2 parameters:"
echo ""
echo "a: Input master file in /tmp (mandatory)"
echo "b: Input append file in /tmp (mandatory)"
echo ""


if [ -z  $1 ];
then
   echo "1st parameter must be full name of a GEDCOM master file existing in $in_dir."
   exit 1
fi

in_file=$(echo $in_dir/$1)
filestem=$(echo $1 | sed "s/\.ged//")

if [ -z  $2 ];
then
   echo "2nd parameter must be full name of a GEDCOM append file existing in $in_dir."
   exit 1
fi

append_file=$(echo $in_dir/$2)
appendfilestem=$(echo $2 | sed "s/\.ged//")

read -p "Running gedutil with master file $in_file, and append file $append_file to be merged into it. Do you wish to run the program? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo ""
#flatten both files
echo "Flattening input files."
cat $in_file | tr -d '\15\32' | sed "s/$/¬/g" | sed "s/^0\s/@@0 /g" | tr -d "\n" | sed "s/\@\@0 /\n0 /g" | sed '1d' >$out_dir/${filestem}_master_collapsed.ged
cat $append_file | tr -d '\15\32' | sed "s/$/¬/g" | sed "s/^0\s/@@0 /g" | tr -d "\n" | sed "s/\@\@0 /\n0 /g" | sed '1d' >$out_dir/${appendfilestem}_append_collapsed.ged
echo "Creating tagid hashes for both input files in $out_dir/${filestem}_idhash.txt and $out_dir/${appendfilestem}_idhash.txt"
# write tag ids to hash for master file
#grep '^0' $out_dir/${filestem}_master_collapsed.ged | sed "s/¬/\t/g" | cut -f1 | sed "s/^0 //g; s/\@//g; s/\s/\@/g" >$out_dir/${filestem}_idhash.txt
grep '^0' $out_dir/${filestem}_master_collapsed.ged | sed "s/¬/\t/g" | cut -f1 | sed "s/^0 //g; s/\@//g; s/\s.*//g" >$out_dir/${filestem}_idhash.txt
# write tag ids to hash for append file
#grep '^0' $out_dir/${appendfilestem}_append_collapsed.ged | sed "s/¬/\t/g" | cut -f1 | sed "s/^0 //g; s/\@//g; s/\s/\@/g" | grep -v '^HEAD' | grep -v '^TRLR' | grep -v '^SUBM' >$out_dir/${appendfilestem}_idhash.txt
grep '^0' $out_dir/${appendfilestem}_append_collapsed.ged | sed "s/¬/\t/g" | cut -f1 | sed "s/^0 //g; s/\@//g; s/\s.*//g" | grep -v '^HEAD' | grep -v '^TRLR' | grep -v '^SUBM' >$out_dir/${appendfilestem}_idhash.txt
# get uniq content tags and counts to dictate order of writing
grep '^0' $out_dir/${filestem}_master_collapsed.ged | sed "s/¬/\t/g" | cut -f1 |sed "s/^.* //g " | uniq >$out_dir/${filestem}_ufields.txt
grep '^0' $out_dir/${appendfilestem}_append_collapsed.ged | sed "s/¬/\t/g" | cut -f1 | sed "s/^.* //g " | uniq  | grep -v '^HEAD' | grep -v '^TRLR' | grep -v '^SUBM' >$out_dir/${appendfilestem}_ufields.txt
# id name hashes for reporting on duplicates
grep '^0.*INDI¬' $out_dir/${filestem}_master_collapsed.ged | sed "s/¬/\t/g" | cut -f1,2 | sed "s/^0 \@//g; s/\@.*NAME /\t/g; s/\@.*/\t/" >$out_dir/${filestem}_names.txt
grep '^0.*INDI¬' $out_dir/${appendfilestem}_append_collapsed.ged | sed "s/¬/\t/g" | cut -f1,2 | sed "s/^0 \@//g; s/\@.*NAME /\t/g; s/\@.*/\t/" >$out_dir/${appendfilestem}_names.txt

perl gedutil_merge.pl $out_dir/${filestem}_master_collapsed.ged $out_dir/${appendfilestem}_append_collapsed.ged >$out_dir/${filestem}_newmerge_collapsed.ged 

# convert to lines
cat $out_dir/${filestem}_newmerge_collapsed.ged | sed "s/¬/\n/g" | grep -v "^$" > $out_dir/${filestem}_newmerge.ged
echo "COMPLETE. The new gedcom file can be found at $out_dir/${filestem}_newmerge.ged "
echo ""
echo "Note: Check the $out_dir/mergedupslog.txt file to ensure you really wanted to merge any duplicates identified."
echo ""
echo "END"

else 
	echo "Quitting..."
	exit
fi

