#! /usr/bin/perl -w

use strict;
use bbarchive;

my ($archpath, $output) = @ARGV;
die "usage error" unless $archpath;

if ($output)
  {
    open OUT, ">$output" or die "cannot open $output for writing: $!";
  }
else
  {
    open OUT, ">&STDOUT" or die "cannot dup stdout: $!";
  }


# parse archive
my $bba = new bbarchive;
$bba->load($archpath);

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


# for each outcome (aka course grade element)
foreach my $outcome ($bba->outcomes()) {

  print '<div class="outcome">', "\n";
  print '<div class="outcome_title">' . $outcome->{'title'} . "</div>\n";
  


  ## for each student
  foreach my $student ($outcome->students()) {

    ### print name
    ### print grade

    ### for each attempt

    #### print name
    #### print file link
    #### print student comments
    #### print instructor comments
    #### print grade
  }
}
