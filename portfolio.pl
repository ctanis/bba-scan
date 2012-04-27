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
  print OUT '<div class="outcome">';


  print OUT '<div class="outcome_name"><a href="#" onClick=toggleContent("'. $outcome->{'id'} .'")>' . $outcome->{'title'} . "</a></div>\n";

  ## for each student/outcome combo..
  print OUT '<div class="students" id="' . $outcome->{'id'} .'">';

  foreach my $student_outcome ($outcome->student_outcomes()) {

    print OUT '<div class="student">';

    print OUT '<div class="student_name">Student: ' . $student_outcome->{'student'}->{'name'}, "</div>\n";
    if (defined $student_outcome->{'override'})
      {
	print OUT '<div class="grade_override">Official Grade: ' . $student_outcome->{'override'}, "</div>\n";
      }

    print OUT '<div class="attempts">';

    ## for each attempt at getting a grade.. (usually just 1)
    my $i=1;
    my $attempt_count = @{$student_outcome->{'attempts'}};

    foreach my $attempt (@{$student_outcome->{'attempts'}}) {
      print OUT '<div class="attempt">';

      ## for each file involved in this one
      if ($attempt_count > 1) {
	print OUT "Attempt $i<br />";
      }

      if (defined $attempt->{'grade'}) {
	print OUT "Grade: ", $attempt->{'grade'},"<br />\n";
      }

      if (defined $attempt->{'rubric'}) {
#	print STDERR Dumper ($attempt->{'rubric'});

	print OUT "Rubric Breakdown:<br />\n";
	print OUT $attempt->{'rubric'}->{'comment'}
	  if defined $attempt->{'rubric'}->{'comment'};
	  

	print OUT '<div class="rubric">';
	

	for my $c (@{$attempt->{'rubric'}->{'cells'}})
	  {
	    print OUT '<div class="rubricrow">';

	    print OUT '<div class="rubrowcat">' . $c->{'cell'}->{'title'} ;
	    print OUT '<div class="rubrowdesc">' . $c->{'cell'}->{'desc'}. '</div></div>';
	    print OUT '<div class="rubrowcomm">' . $c->{'comment'} . '</div>';

	    print OUT '</div>'
	  }

	print OUT '</div>';
      }



      if (defined $attempt->{'submission'} && ! ref $attempt->{'submission'}) {
	print OUT '<div class="submission">Submission: ' . $attempt->{'submission'} . "</div>\n";
      }



      if (defined $attempt->{'instructor_comments'} && ! ref $attempt->{'instructor_comments'}) {
	print OUT '<div class="instcomm">Instructor Comments: ' . $attempt->{'instructor_comments'} . "</div>\n";
      }



      
      if (defined $attempt->{'files'})
	{
	  print OUT '<div class="files">';
	  print OUT "Files:<br/>";

	  foreach my $f (sort { $b->{'type'} cmp $a->{'type'}} @{$attempt->{'files'}}) {
	    my $file = $f->{'path'};

	    print OUT "<a href=\"$file\">", `basename '$file'`, '</a> (',$f->{'type'},')<br />'

	      #	print OUT "<a href='" .$f->{'path'},.'">'. `basename '$f->{'path'}'` .  "</a> -- " , $f->{'type'}, "<br/>\n";


	  }

	  print OUT '</div>';
	}

      print OUT "</div>\n";	# attempt
    }



    print OUT "</div>\n";		# attempts


    print OUT "</div>\n";		# student
  }



  print OUT "</div>\n";		# students


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



  print OUT "</div>\n";		# end outcome
}

print OUT <<EOF
</body>
</html>
EOF
  ;





