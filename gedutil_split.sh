#!/bin/bash
# gedutil_split.sh 20240225
# Splits a GEDCOM file
#
# ensure folder /myebs/scripts  exists and is writeable and place this script there
# execute with bash
in_dir="/tmp"
out_dir="/tmp"

echo "gedutil_split.sh: Splits a GEDCOM file. 3 parameters:"
echo ""
echo "a: Full path to input file (mandatory)"
echo "b: GEDOM individual ID to split off descendants of (eg I2) (mandatory)"
echo "c: GEDCOM ancestors of the individual to skip ID (optional)"
echo ""


if [ -z  $1 ];
then
   echo "1st parameter must be full name of a GEDCOM file existing in $in_dir."
   exit 1
fi

in_file=$(echo $in_dir/$1)
filestem=$(echo $1 | sed "s/\.ged//")

if [ -z  $2 ];
then
   echo "2nd parameter must be Individual Id of a person in the input GEDCOM file $1."
   exit 1
fi

if [ -z  $3 ];
then
   ancskip="N"	
   echo "Running without skipping an ancestor branch"
else
   ancskip=$3	
   echo "Skipping ancestors of $ancskip"
fi

read -p "Running gedutil with incoming file $in_file, to split out individual ID $2 and skip ancestor set to $ancskip. Do you wish to run the program? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo ""
# get ancillary tags which may differ from file to file
TAGS=$(grep '^0' $in_file | sed "s/^0 \@[^\@]*\@ //g"  | sort | uniq | grep -v 'HEAD' | grep -v 'TRLR' | grep -v 'INDI' | grep -v 'FAM' | grep -v 'SUBM' |  sed "s/\r$/¬/g" | tr -d "\n")
cat $in_file | tr -d '\15\32' | sed "s/$/¬/g" | sed "s/^0\s/@@0 /g" | tr -d "\n" | sed "s/\@\@0 /\n0 /g" | sed '1d' >$out_dir/${filestem}_collapsed.ged
perl gedutil.pl $out_dir/${filestem}_collapsed.ged $2 $ancskip $TAGS $filestem >$out_dir/${filestem}_new_collapsed.ged 
# convert to lines
cat $out_dir/${filestem}_new_collapsed.ged | sed "s/¬/\n/g" | grep -v "^$" > $out_dir/${filestem}_new.ged
cat $out_dir/${filestem}_collapsed_remains.ged | sed "s/¬/\n/g" | grep -v "^$" > $out_dir/${filestem}_remains.ged
echo "COMPLETE. The new gedcom file can be found at $out_dir/${filestem}_new.ged and the remaining data from the old one is in $out_dir/${filestem}_remains.ged"
echo ""
echo "Notes:"
echo "a. The chosen individual $2 will not be in the \"remains\" file and you may wish to add that back manually after importing it to your software."
echo "b. If you used the ancestor skip option, this will exclude that person's marriage partner(s) and their ancestors too. If you want them included, take the skip ancestor one generation higher up."
echo "c. If you used the ancestor skip option, that person will also be left in the \"remains\" file, but note that the family as partner reference may now point to an unlinked reference as those people were split off. You are advised to check this person manually and make any required amendments."
echo ""
echo "END"

else 
	echo "Quitting..."
	exit
fi

