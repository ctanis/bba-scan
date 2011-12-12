#! /usr/bin/perl

use strict;
use bbarchive;
use Data::Dumper;

my ($archpath, $output) = @ARGV;
die "usage error" unless $archpath;

if ($output) {
  open OUT, ">$output" or die "cannot open $output for writing: $!";
} else {
  open OUT, ">&STDOUT" or die "cannot dup stdout: $!";
}


# parse archive
my $bba = new bbarchive;
$bba->load($archpath);

#print Dumper($bba);

print OUT <<EOF
<html>
    <head>
    <link rel="stylesheet" href="gradereport.css" type="text/css" />
    <script type="text/javascript">
	function toggleContent(id) {
	    // Get the DOM reference
	   var contentId = document.getElementById(id);
	    // Toggle 
	    contentId.style.display == "block" ?
	        contentId.style.display = "none" : 
		contentId.style.display = "block"; 
	}
    </script>
<title>Graded Student Work</title>
    </head>
    <body>
EOF
  ;


# # for each outcome (aka course grade element)
foreach my $outcome ($bba->outcomes()) {
  print $outcome->{'title'}, "\n";


  ## for each student/outcome combo..
  foreach my $student_outcome ($outcome->student_outcomes()) {

    print "student: " . $student_outcome->{'student'}->{'name'}, "\n";
    print "override: " . $student_outcome->{'override'}, "\n";

    ## for each attempt at getting a grade.. (usually just 1)
    foreach my $attempt (@{$student_outcome->{'attempts'}}) {


      ## for each file involved in this one
      next unless defined $attempt->{'files'};
      foreach my $f (sort { $b->{'type'} cmp $a->{'type'}} @{$attempt->{'files'}}) {
	print $f->{'path'}, " -- " , $f->{'type'}, "\n";
      }
    }


  }

  #   print '<div class="outcome_title">' . $outcome->{'title'} . "</div>\n";
  


  #   ## for each student
  #   foreach my $student ($outcome->students()) {

  #     ### print name
  #     ### print grade

  #     ### for each attempt

  #     #### print name
  #     #### print file link
  #     #### print student comments
  #     #### print instructor comments
  #     #### print grade
  #   }

}

print OUT <<EOF
</body>
</html>
EOF
  ;





