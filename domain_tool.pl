use FileHandle;
use Getopt::Long;
use List::Util qw[min max];
#use warnings;
my $junk = "extraction.tmp";
my $usage = "
This program requires the following flags:
-seqs <file path to the FASTA file>
-hmm <file path to the HMM>
-domain <domain score cutoff>
-protein <protein score cutoff>
-full <print full sequences (default is no)>
-extend <amount to extend domain match regions by>
Optional flag:
-tmp <override the default location for the HMM results>
";
my %domains = ();
GetOptions ( 'seqs=s' => \$seqs,
	     'hmm=s' => \$hmm,
             'domain=s' => \$domain_cutoff,
	     'protein=s' => \$protein_cutoff,
	     'tmp=s' => \$junk,
		'extend=i' => \$extend,
		'full' => \$full);

if (!$hmm || !$domain_cutoff || !$protein_cutoff) {die "$usage\n";}
if (!$seqs) {die "$usage\n";}
`hmmsearch -T $protein_cutoff --domtblout $junk  $hmm  $seqs`;
#`hmm3search -T $protein_cutoff --domtblout $junk  $hmm  $seqs`; #<- JCVI alias
read_domtblout($junk);
search_fasta($seqs);

#########################################################################################################################################################################
sub read_domtblout
{
	my $source = shift;
	open (TABLE, "$source") || die "cannot read domtblout file\n";
	while ($line = <TABLE>)
	{
		if (!($line =~ /^#/))                                                         	       # ignore the header line
		{

		        @split_line = split(/\s+/, $line);                                              # splits on tabs - some entries contain whitespace
			if ($split_line[13] >= $domain_cutoff)
			{
				push(@{$domains{$split_line[0]}[0]}, $split_line[19]);                    # adds "env from" coordinate to array
				push(@{$domains{$split_line[0]}[1]}, $split_line[20]);                    # adds "env to" coordinate to array
				# %domains is a hash, but $domains{identifier}[0] and $domains{$identifier}[1] are both arrays
				# this way, all domains from one sequence are stored with the same hash key, but can easily be processed iteratively
			}

		}
    
	}
	close TABLE;
}
##########################################################################################################################################################################
sub search_fasta
{
	my $fasta = shift;
	open (FASTA, "$fasta") || die "cannot read sequence file\n";
	my $tmp_seq = '';	
	while ($line = <FASTA>)
	{ 
	if ($next_one == 1)
	{
		$next_one = 0;
		$line = $skipped_line;
	}
		if ($line =~ /^>(.*?)\s/)
		{
			if ($domains{$1})
			{
				$identifier = $1;
				$tmp_seq = '';
				if ($line =~ /(.*?)\r?\n/)
				{
					$header = $1;	
				}
				else
				{
					$header = $line;
					chomp($header);
				}
				while ($seq_line = <FASTA>)
				{
					if (!($seq_line =~ />/))
		    			{
						local $/ = "\r\n";
						chomp($seq_line);
						local $/ = "\n";
						chomp($seq_line);						
						$tmp_seq = ($tmp_seq . $seq_line);
		    			}
		    			else 
					{
					$next_one = 1;
					$skipped_line = $seq_line;
					last;
					}

				}

				for ($i = 0; $i <= $#{$domains{$identifier}[0]}; $i++)
				{
					$from = ($domains{$identifier}[0][$i]-1);
					$from = max(0, $from-$extend);
					$to = ($domains{$identifier}[1][$i]-1);
					$to = min($to+$extend, length($tmp_seq));
					$length = ($to - $from + 1);
					$to_1 = ($to + 1);
					$from_1 = ($from + 1);
#					$tmp_seq =~ /.{$from}(.{$length})/;
					$sub_seq = substr $tmp_seq, $from, $length;
					$sub_seq =~ s/(.{1,80})/$1\n/gs;
					$tmp_seq =~ s/(.{1,80})/$1\n/gs;
					if ($tmp_seq && $full) {chomp($header); print("$header\n$tmp_seq\n\n");}
					elsif ($sub_seq && $length) {print("$header\/$from_1\-$to_1\n$sub_seq\n\n");}
					
				}
			}
			else
			{
				next;
			} 
		}
		
		
	}
} 
