#!/usr/bin/perl -w 

use strict;

if($#ARGV != 2){
	die "Usage: ./roh_overlap.pl <lanc bed file> <chr:pos query start> <chr:pos query end>\n";
}

my $lancbedfile = $ARGV[0];
my $querysitestart = $ARGV[1];
my $querysiteend = $ARGV[2];
my $qchrstart = "";
my $qposstart = "";

my $qchrend = "";
my $qposend = "";

if($querysitestart =~ m/((chr)?\d+):(\d+)/){
	if(! defined $2){
		$qchrstart = "chr";
	}
	$qchrstart .= $1;
	$qposstart = $3;
}
else{
	print STDERR "ERROR: Did not recognize query start. Please provide a genomic location formatted chr:pos, e.g. chr1:12345\n";
}

if($querysiteend =~ m/((chr)?\d+):(\d+)/){
    if(! defined $2){
        $qchrend = "chr";
    }
    $qchrend .= $1;
    $qposend = $3;
}
else{
    print STDERR "ERROR: Did not recognize query start. Please provide a genomic location formatted chr:pos, e.g. chr1:12345\n";
}


if($qchrstart ne $qchrend){
    print STDERR "ERROR: Must choose an interval on a single chromosome.\n";
}

my $qchr = $qchrstart;
my $qpos = int(($qposend - $qposstart)/2.0 + 0.5) + $qposstart;

print STDERR "$qchr:$qpos\n";

my @indlist;
#my %output;

#open(FIN,"<",$rohbedfile) or die $!;
my $ind;
my $pop;
my $n = -1;

#my $mstart = $qchrstart;
#my $mend = $qchrend;
#while(defined(my $line = <FIN>)){
#	chomp $line;
#	if ( $line =~ m/^track .+Ind: (.+) Pop:(.+) ROH.+/ ) {
#        if($n == 0){
#        	$output{$ind} = "$ind\t$pop\tNA\tNA\tNA\tNA";
#        }
#        $ind = $1;
#        push(@indlist, $ind);
#        $pop = $2;
#        $n = 0;
#    }
#    else {
#        my ( $chr, $start, $end, $class, $size, $anc, $junk ) = split( /\s+/, $line, 7 );
#        if($chr ne $qchr){
#        	next;
#        }
#        if($qpos >= $start and $qpos <= $end){
#        	$output{$ind} = "$ind\t$pop\t$chr\t$start\t$end\t$class";
#
#        	if($start >= $mstart){
#        		$mstart = $start;
#        	}
#        	if($mend >= $end){
#        		$mend = $end;
#        	}
#
#        	$n++;
#        }
#    }
#}

#if($n == 0){
#	$output{$ind} = "$ind\t$pop\tNA\tNA\tNA\tNA";
#}

open( LANC, "<", $lancbedfile ) or die $!;

$n = -1;

my $nind = 0;
my %lancoutput;
my $bpoverlap = "NA";
my $ancoverlap = "NA";
my $overlap;

my %ind2pop;
#for $ind (@indlist){
#	$lancoutput{$ind} = "$mstart\t$mend";
#}

while ( my $line = <LANC> ) {
    chomp $line;

    if ( $line =~ m/^track .+Ind: (.+) Pop:(.+) Admixture.+/ ) {
        if($nind > 0){
        	$lancoutput{$ind} .= "\t$bpoverlap\t$ancoverlap"; 
        }

        $ind = $1;
        $pop = $2;

        push(@indlist, $ind);
        $ind2pop{$ind} = $pop;

        $nind++;
        $n = 0;
        $bpoverlap = "NA";
        $ancoverlap = "NA";
        $overlap = 0;
    }
    else {
        my ( $chr, $start, $end, $anc, $size, $junk ) = split( /\s+/, $line, 6 );
        if($chr ne $qchr){
        	next;
        }
        $anc =~ tr/123/EAN/;
        if($qpos >= $start and $qpos <= $end){
        	
        		my $eur = 0;
        		my $afr = 0;
        		my $nam = 0;

        		if($anc eq "EE"){
        			$eur = 2;
        		}
        		elsif($anc eq "AA"){
        			$afr = 2;
        		}
        		elsif($anc eq "NN"){
        			$nam = 2;
        		}
        		elsif($anc eq "EN"){
        			$eur = 1;
        			$nam = 1;
        		}
        		elsif($anc eq "EA"){
        			$eur = 1;
        			$afr = 1;
        		}
        		elsif($anc eq "AN"){
        			$afr = 1;
        			$nam = 1;
        		}

        		$lancoutput{$ind} = "$qchr\t$anc\t$eur\t$afr\t$nam\t$qposstart\t$qposend";
        		$n++;
        }

        $overlap = getOverlap($start,$end,$qposstart,$qposend);

        if($overlap > 0 and $bpoverlap eq "NA"){
        	$bpoverlap = $overlap;
        	$ancoverlap = $anc;
        }
        elsif($overlap > 0){
        	$bpoverlap .= ",$overlap";
        	$ancoverlap .= ",$anc";
        }
    }
}

if($nind > 0){
	$lancoutput{$ind} .= "\t$bpoverlap\t$ancoverlap"; 
}

close(LANC);

print "pop\tchr\tqueryAnc\tqueryEurAlleles\tqueryAfrAlleles\tqueryNamAlleles\tstart\tend\tancOverlap\tancTypes\n";

for $ind (@indlist){
	print $ind, "\t", $ind2pop{$ind}, "\t", $lancoutput{$ind}, "\n";
}


sub getOverlap{
	my $start = $_[0];
	my $end = $_[1];
	my $qstart = $_[2];
	my $qend = $_[3];

	if ( $qstart >= $start and $qstart <= $end ) {
    	if($qend >= $end){
    		return ($end-$qstart)+1;
    	}
    	else{
    		return ($qend-$qstart)+1;
    	}
    }
    elsif ( $qend >= $start and $qend <= $end ) {
        return ($qend-$start)+1;
    }
    elsif ( $qstart <= $start and $qend >= $end ) {
        return ($start-$end)+1;
    }

    return 0;

}
