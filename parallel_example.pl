# an example (rough) implementation for how to parallelize SIMBAL
# since grid implementations differ depending on workspace, and usually requires system-specific configuration
# this version is not expected to work as-written on non-JCVI systems
# this is instead supposed to serve as an example for how one might write their own wrapper script_name
# SIMBAL runs can be concatenated at the end - order doesn't matter
# different lengths can all be computed at the same time and combined at the end
# This can turn an 8 hour run into a 10 minute run
# The recommended way to parallelize is to do lots of runs where -M and -m are the same value
# Combine those at the end
# The heatmap and single-residue extrapolation can then be run like normal on the resulting file
# The plume-interpreter would require that the wrapper script modify the last two columns of the SIMBAL output files before they are concatenated - this example does not include that behavior
use strict;
use warnings;
use FileHandle;
use Data::Dump 'dump';
use Getopt::Long;
use Tie::File;
GetOptions('true=s' => \my$true_name, 'false=s' => \my$false_name, 'seq=s' => \my$single_seq, 
		   'help' => \my$help, 'jump' => \my$jump, 'walk' => \my$walk, 'low=i' => \my$min, 
		   'M=i' => \my$Max, 'name=s' => \my$file_name, 'xscratch=s'=> \my$x_scratch,
		   'prob=i' => \my$prob, 'zap' => \my$zap, 'E_val=i' => \my$e_val , 'del' => \my$del);  #option list
my $debug=1;

my $comm_string = "perl SIMBAL.pl -t $true_name -f $false_name -s $single_seq"; #string of basic--AKA required--options		   
	if ($debug) {print($comm_string);}  
	
if ($help)  {#if user includes -h flag, use system to show SIMBAL help menu
	$help='-h ';
	$comm_string = "perl SIMBAL.pl -t $true_name -f $false_name -s $single_seq -h";
	system($comm_string) && die;
}

if ($jump) {
	$comm_string = $comm_string." -j $jump";
}
if ($walk) {
	$comm_string = $comm_string." -w $walk";
}

if (!$file_name) { #if user doesn't specify file name
	$file_name="SIMBAL"; #give default name
}
else {
	$comm_string = $comm_string." -n $file_name";	
}

if ($x_scratch) {
	$comm_string = $comm_string." -x $x_scratch";
}

if ($prob) {
	$comm_string = $comm_string." -p $prob";
}

if ($zap) {
	$comm_string = $comm_string." -z $zap";
}

if ($e_val) {
	$comm_string = $comm_string." -E $e_val";
}

my$query_length=0;
if (!$Max) { #if user doesn't specify maximum
	open(SEQ, "$single_seq") || die "couldn't open $single_seq"; #open query file	
	my $concat_query="";
	while (my$line = <SEQ>) #go through query file line by line
	{
		if (my$_ !~ />/) { #if line in the query does not contain >--this is in the header
		$concat_query=$concat_query.$line; #then add it to concatenated query with no special characters and only residues
	}
	} 
	$query_length=length($concat_query); #set query length equal to what is is as counted above
}  
else{
	$query_length=$Max;
}



my@comm_array=();  
my$col=0;
for (my$count=$min; $count<=$query_length; $count++){ #for length of query
	my$mintemp=$count; #set minimum equal to counter variable
	$Max=$count; #set max equal to same thing; breaking into small SIMBAL chunks
	my$file_name_temp=$file_name."_$count"; #name output file for specific chunk
	my$comm_string_temp=$comm_string." -m $mintemp -M $Max"; #set same max and min for specific chunk
	$comm_array[$col][0]=$comm_string_temp." -n $file_name\_$count"; #put command into an array
	$col++;
}
#dump @comm_array;

mkdir("paraSIM") unless (-e "paraSIM"); #make a directory to store all of the results and stuff in
system("cp SIMBAL.pl paraSIM/SIMBAL.pl"); #copy SIMBAL file to this new directory
chdir("paraSIM"); #move to the new directory

my $tempout = 'tempout.txt';
open (my $fh, '>>', $tempout) or die "Cannot create output folder";
for (my$counter=0; $counter<=($query_length-$min); $counter++) { #put array into tab delimited file
	print $fh "$comm_array[$counter][0]\n";
}
close $fh;

system("source /usr/local/sge_current/jcvi/common/settings.sh");
system("/usr/local/devel/ANNOTATION/rrichter/local/scripts/qrun -P 0695 -c '{1}' tempout.txt"); #parallelizing command to grid using qrun

system("qstat > status.txt"); #print status of qrun job to txt file
tie my@status_array, 'Tie::File', 'status.txt' or die "Cannot print qrun status"; #tie txt file and @status_array

my$job_string=$status_array[2]; #take 2nd line of status--corresponds to first line with pid, user, status, etc 
my ($job_id)= $job_string =~/(\d{7})/; #job id is 7 digit number


system("/usr/local/devel/ANNOTATION/rrichter/local/bin/qwait $job_id"); #qwait will hold program until grid returns results of job with specified id

my$adder=$min; #set counting variable equal to minimum length
while ($adder<=$query_length){ #loop through minimum length to maximum length
		system("cat $file_name\_$adder\_REPORT >> $file_name\_complete"); #concatenate all of the qrun outputs into one file
		$adder++; 
}
system("rm SIMBAL.pl"); #remove SIMBAL that you copied earlier....feel like there is better way to do this?

if ($del){ #if user included the -del flag, then all of the output except concatenated file is deleted
	system("ls | grep -v $file_name\_complete | parallel rm");
}

chdir(".."); #go back to original directory
print('Done');

	
	
	
	
	
	
	
	
