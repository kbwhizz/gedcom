README

gedutil - split or merge GEDCOM files

Rationale: I was unable to find any software sophisticated enough to split branches and ancillary parts from a GEDCOM file and leave
a remainder in tact.

gedutil_split:

Takes a GEDCOM file and extracts descendants of an individual ID (as entered). Also looks for ancestors (and the descendants of those ancestors)
of all the people extracted. Optionally, an ID of an individual whose ancestors are not to be sought can be provided. The objective is to provide
a "crawl" of connected people but with the option not to include circular references where a person is related twice to the same branch through 
a cousin marriage or similar.

gedutil_merge:

Takes two GEDCOM files (a master and append). The files are compared and duplicate ids are made unique in the append file by prepending 9 to the 
value. The files are then merged. A log file of duplicate ids (and their names) are given as a check that no duplicate names (branches) are being
merged into the new file.

 


