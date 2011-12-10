 #! /opt/local/bin/perl -w
use strict;
use XML::Simple;
use Data::Dumper;

use constant {
    GRADEBOOK_TYPE => 'course/x-bb-gradebook',
    USER_TYPE => 'course/x-bb-user',
    ATTEMPT_TYPE => 'course/x-bb-attemptfiles',
    COURSEMEMBER_TYPE => 'membership/x-bb-coursemembership'
};

# set to one to dump all parsed xml
my $debug=1;


my $dir = shift @ARGV || '.';
my $outfile = shift @ARGV || "report.html";
my $xml_parser = XML::Simple->new();

my $manifest_file = "$dir/imsmanifest.xml";


print STDERR "processing $manifest_file\n";
my $manifest = $xml_parser->XMLin($manifest_file);

if ($debug)
{
    open MANIFESTDUMP, ">manifest_dump.txt" or die;
    print MANIFESTDUMP Dumper($manifest);
    close MANIFESTDUMP;
}


my @resources = @{ $manifest->{'resources'}->{'resource'} };

my ($gradebook_xml, $users_xml, @attemptfile_base, $coursemem_xml);


foreach my $resource (@resources)
{
    my $type = $resource->{'type'};
			      
#    print $resource->{'type'}, ":", $resource->{'bb:title'}, "\n";

    if ($type eq GRADEBOOK_TYPE)
    {
    	$gradebook_xml = $resource->{'bb:file'};
    }

    if ($type eq USER_TYPE)
    {
	$users_xml = $resource->{'bb:file'};
    }

    if ($type eq ATTEMPT_TYPE)
    {
	push @attemptfile_base, $resource->{'xml:base'};
    }

    if ($type eq COURSEMEMBER_TYPE)
    {
	$coursemem_xml = $resource->{'bb:file'};
    }
}


print STDERR "User file: $dir/$users_xml\n";
print STDERR "Gradebook file: $dir/$gradebook_xml\n";
print STDERR "Course membership: $dir/$coursemem_xml\n";
print STDERR "Attempts: @attemptfile_base\n";


my (%user_lookup, %attempt_lookup, %item_report, %membermap, %outcome_name);


## build user hash
my $users = $xml_parser->XMLin("$dir/$users_xml");


## debug
if ($debug)
{
    open USERDUMP, ">user_dump.txt" or die;
    print USERDUMP Dumper($users);
    close USERDUMP;
}


for my $bb_id (keys %{$users->{'USER'}})
{
    my $student = $users->{'USER'}->{$bb_id};

    my $name = $student->{'NAMES'}->{'GIVEN'}->{'value'} . " " .
	$student->{'NAMES'}->{'FAMILY'}->{'value'};
    my $uid = $student->{'BATCHUID'}->{'value'};

#    print "$bb_id**$name**$uid\n";

    $user_lookup{$bb_id} = { name => $name, id => $uid };
}


## build course membership map
my $coursemem = $xml_parser->XMLin("$dir/$coursemem_xml");

if ($debug)
{
    open CMDUMP, ">membership_dump.txt" or die;
    print CMDUMP Dumper($coursemem);
    close CMDUMP;
}


foreach my $memberid (%{ $coursemem->{'COURSEMEMBERSHIP'} })
{
    $membermap{$memberid}=$coursemem->{'COURSEMEMBERSHIP'}->{$memberid}->{'USERID'}->{'value'};

}





## build attemptfile hash
## debug
if ($debug)
{
    open ATTEMPTDUMP, ">attempt_dump.txt" or die;
}

foreach my $attempt_base (@attemptfile_base)
{
    my $attempt = $xml_parser->XMLin("$dir/$attempt_base.dat");

    if ($debug)
    {
	print ATTEMPTDUMP "\n\n***$attempt_base***\n\n";
	print ATTEMPTDUMP Dumper($attempt);
    }



    foreach my $file_xml (keys %{$attempt->{'ATTEMPTFILE'}})
    {
	my $file_entry = $attempt->{'ATTEMPTFILE'}->{$file_xml};


	my $filename =  $file_entry->{'FILE'}->{'NAME'};
	my $attempt_id = $file_entry->{'ATTEMPTID'}->{'value'};

	my $full_path = "$dir/$attempt_base/$file_xml/$filename";


	## find the files that were renamed by blackboard
	unless (-e $full_path)
	{
#	    invalid filename in archive: $full_path\n";
	    my @actual_files = glob("$dir/$attempt_base/$file_xml/!*");

	    # hack?
	    $full_path = $actual_files[0];
	}


	$attempt_lookup{$attempt_id} = $full_path;
    }
}

if ($debug)
{
    close ATTEMPTDUMP;
}



## build grade hash
my $gradebook_entries = $xml_parser->XMLin("$dir/$gradebook_xml");

if ($debug)
{
    open GRADEDUMP, ">grade_dump.txt" or die;
    print GRADEDUMP Dumper($gradebook_entries);
    close GRADEDUMP;
}



my $outcomes = $gradebook_entries->{'OUTCOMEDEFINITIONS'}->{'OUTCOMEDEFINITION'};
foreach my $outcome_id (keys %$outcomes)
{
    my $outcome = $outcomes->{$outcome_id};

#    print Dumper($outcome);

    my $outcome_title = $outcome->{'TITLE'}->{'value'};
    $outcome_name{$outcome_id}=$outcome_title;
    my $maxpoints = $outcome->{'POINTSPOSSIBLE'}->{'value'};



#    print "**$outcome_title**\n";
    my $outcome_attempts = $outcome->{'OUTCOMES'}->{'OUTCOME'};

    next if defined $outcome_attempts->{'ATTEMPTS'};

    foreach my $att (keys %$outcome_attempts)
    {
	my $memberid = $outcome_attempts->{$att}->{'COURSEMEMBERSHIPID'}->{'value'};
	my $override = $outcome_attempts->{$att}->{'OVERRIDE_GRADE'};
#	my $grade = $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'};

	my @grades;

	if (defined $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}->{'GRADE'})
	{
	    # single attempt
	    push @grades, $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'};
	}
	else
	{
	    # multiple attempts

	    foreach my $k (keys %{$outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}})
	    {
		print "pushing $k\n";

		# store key as grade id
		my $tmp = $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}->{$k};
		$tmp->{'id'} = $k;

		push @grades, $tmp;
	    }


	}


	# if (ref  $outcome_attempts->{$att}->{'ATTEMPTS'}{'ATTEMPT'} eq 'ARRAY')
	# {
	#     @grades = @{ $outcome_attempts->{$att}->{'ATTEMPTS'} };
	# }
	# else
	# {
	#     push @grades, $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'};
	# }
	

	foreach my $grade (@grades)
	{

#	print $grade->{'INSTRUCTORCOMMENTS'}, ":", $grade->{'SCORE'}->{'value'}, "/", $maxpoints, ":", $attempt_lookup{$grade->{'id'}}, "\n";

#	    my $comments = $grade->{'INSTRUCTORCOMMENTS'}->{'TEXT'};
	    my $comments = Dumper($grade->{'INSTRUCTORCOMMENTS'});

	    # if (ref $grade->{'INSTRUCTORCOMMENTS'})
	    # {
	    #     $comments="";
	    # }
	    # else
	    # {
	    #     $comments=$grade->{'INSTRUCTORCOMMENTS'};
	    # }



	    no warnings;
##	if (defined $grade->{'GRADE'}->{'value'} or $override)
	    if (defined $attempt_lookup{$grade->{'id'}})
	    {
		my $g;
		if ($override)
		{
		    $g = $override;
		}
		else
		{
		    $g = $grade->{'GRADE'}->{'value'};
		}

		my $score = "$g/$maxpoints";
		push @{ $item_report{$outcome_id} }, { 

		    user => $user_lookup{$membermap{$memberid}}->{'name'},
		    comments => $comments,
		    score => $score,
		    file => $attempt_lookup{$grade->{'id'}} };

	    }
	}



    }
}


## print out the contents of %item_report really nice



## this sorts outcome names in a way that makes sense to me!
## alphabetic sort unless numbers show up

sub outcome_sorter($$)
{
    my ($n1, $n2) = @_;
    my @s1 = split /\s+/, $n1;
    my @s2 = split /\s+/, $n2;

    while (@s1 && @s2)
    {
	my $r;
	my $w1 = shift @s1;
	my $w2 = shift @s2;

	no warnings;
	$r = $w1 <=> $w2;
	return $r if $r;

	$r = $w1 cmp $w2;
	return $r if $r;
    }

    return $n1 cmp $n2;
}





open OUT, ">$outfile" or die;

print OUT '<html><head ><link rel="stylesheet" href="gradereport.css" type="text/css" />';

print OUT <<EOF
<script type="text/javascript">
function toggleContent(id) {
  // Get the DOM reference
  var contentId = document.getElementById(id);
  // Toggle 
  contentId.style.display == "block" ? contentId.style.display = "none" : 
contentId.style.display = "block"; 
}
</script>
EOF
    ;


print OUT '<title>Graded Student Work</title></head><body>';



foreach my $outcome_id (sort { outcome_sorter($outcome_name{$a}, $outcome_name{$b}) }
		       keys %item_report)
{
    print OUT '<div class="outcome">';

    print OUT "<div  class=\"outcome_name\"><a href=\"#\" onClick=toggleContent(\"$outcome_id\")> $outcome_name{$outcome_id}</div>\n";
    my @items = @{ $item_report{$outcome_id} };

    print OUT "<div id=\"$outcome_id\" class=\"students\">";
    foreach my $item (@items)
    {
	print OUT '<div class="student">';

	print OUT "<div class=\"file\">Assignment File:<br><a href=\"$item->{'file'}\">$item->{'file'}</a></div>\n";
	print OUT "<div class=\"student_name\">Student: $item->{'user'}</div>\n";
	print OUT "<div class=\"score\">Grade: $item->{'score'}</div>\n";
	print OUT "<div class=\"comment\">Comments: $item->{'comments'}</div>\n";


	print OUT '</div>';	# /student
    }

    print OUT '</div></div>';		# /students /outcome
}


print OUT "</body></html>\n";
close OUT;
