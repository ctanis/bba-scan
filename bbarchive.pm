package bbarchive;

use strict;
use Carp qw(confess);
use XML::Simple;
use Data::Dumper;


use constant
  {
   GRADEBOOK_TYPE => 'course/x-bb-gradebook',
   USER_TYPE => 'course/x-bb-user',
   ATTEMPT_TYPE => 'course/x-bb-attemptfiles',
   COURSEMEMBER_TYPE => 'membership/x-bb-coursemembership',
   MANIFEST_FILE => 'imsmanifest.xml' 
  };




## a blessed reference
sub new {
  return bless {};
}



## configure self to load archive at $path
sub load {
  my ($self, $path) = @_;
  $self->{'path'} = $path . '/';

  # process manifest file
  my $xml_parser = XML::Simple->new();

  my $manifest = $xml_parser->XMLin($self->{'path'} . MANIFEST_FILE)
    or confess;


  ## extract manifest resources
  my @resources = @{ $manifest->{'resources'}->{'resource'} };

  foreach my $resource (@resources) {
    my $type = $resource->{'type'};

    if ($type eq GRADEBOOK_TYPE) {
      $self->{'gradebook.xml'} = $resource->{'bb:file'};
    }

    if ($type eq USER_TYPE) {
      $self->{'user.xml'} = $resource->{'bb:file'};
    }

    if ($type eq ATTEMPT_TYPE) {
      ## multiple course/x-bb-attemptfiles elements can be expected
      push @{$self->{'attempt.xml'}}, $resource->{'xml:base'};
    }

    if ($type eq COURSEMEMBER_TYPE) {
      $self->{'coursemember.xml'} = $resource->{'bb:file'};
    }
  }


  # create user hash
  my $users = $xml_parser->XMLin($self->{'path'} . $self->{'user.xml'})
    or confess;

  for my $bb_id (keys %{$users->{'USER'}}) {
    my $student = $users->{'USER'}->{$bb_id};

    my $name =
      $student->{'NAMES'}->{'GIVEN'}->{'value'} . " " .
	$student->{'NAMES'}->{'FAMILY'}->{'value'};

    my $uid = $student->{'BATCHUID'}->{'value'};

    ## blackboard id --> name, school id and blackboard id
    $self->{'users'}->{$bb_id} = { name => $name, id => $uid, bb_id => $bb_id };
  }


  # build course membership map
  my $coursemem = $xml_parser->XMLin($self->{'path'} . $self->{'coursemember.xml'})
    or confess;

  foreach my $memberid (keys %{$coursemem->{'COURSEMEMBERSHIP'}}) {
    ## apparently each user is assigned a class-specific userid
    ## value for associating grade artifacts
    my $uid = $coursemem->{'COURSEMEMBERSHIP'}->{$memberid}->{'USERID'}->{'value'};

    #	print "$memberid  -> $uid\n";
    $self->{'membermap'}->{$memberid} = $uid;
  }


  # process attempts
  foreach my $attempt_base (@{$self->{'attempt.xml'}}) {
    my $attempt = $xml_parser->XMLin($self->{'path'} . $attempt_base . '.dat')
      or confess;

    foreach my $file_xml (keys %{$attempt->{'ATTEMPTFILE'}}) {
      my $file_entry = $attempt->{'ATTEMPTFILE'}->{$file_xml};

      my $filetype = $file_entry->{'FILETYPE'}->{'value'};

      #	    print Dumper($file_entry) if ($attempt_base =~ /00064/ and $file_xml =~ /138186/);

      my $filename = $file_entry->{'FILE'}->{'NAME'};
      my $attempt_id = $file_entry->{'ATTEMPTID'}->{'value'};
      my $fullpath = $self->{'path'} . "$attempt_base/$file_xml/$filename";


      ## find the files that were renamed by blackboard
      unless (-e $fullpath)
	{
	  # invalid filename in archive: $full_path
	  my @actual_files = glob($self->{'path'} . "$attempt_base/$file_xml/!*");

	  #hack?
	  $fullpath  = $actual_files[0];
	}


      push @{ $self->{'attempts'}->{$attempt_id} }, { path => $fullpath, type=> $filetype };
    }
  }


  # build grade hash
  my $gradebook_entries = $xml_parser->XMLin($self->{'path'} . $self->{'gradebook.xml'})
    or confess;

  my $outcomes = $gradebook_entries->{'OUTCOMEDEFINITIONS'}->{'OUTCOMEDEFINITION'};

  foreach my $outcome_id (keys %$outcomes) {
    my $outcome = $outcomes->{$outcome_id};

    my $outcome_title = $outcome->{'TITLE'}->{'value'};
    my $maxpoints = $outcome->{'POINTSPOSSIBLE'}->{'value'};

    my $thisoutcome =
      $self->{'outcomes'}->{$outcome_id} = { id => $outcome_id,
					     title => $outcome_title,
					     points => $maxpoints };


    my $outcome_attempts = $outcome->{'OUTCOMES'}->{'OUTCOME'};

    ## why was this here?
    ## next if defined $outcome_attempts->{'ATTEMPTS'}

    foreach my $att (keys %$outcome_attempts) {
      my $memberid = $outcome_attempts->{$att}->{'COURSEMEMBERSHIPID'}->{'value'};
      my $override = $outcome_attempts->{$att}->{'OVERRIDE_GRADE'};

      my @grades;

      if (defined $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}->{'GRADE'})
	{
	  #single attempt
	  push @grades, $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'};
	}
      else
	{
	  # multiple attempts
	  
	  foreach my $k (keys %{$outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}}) {
	    #store key as grade id
	    my $tmp = $outcome_attempts->{$att}->{'ATTEMPTS'}->{'ATTEMPT'}->{$k};
	    $tmp->{'id'} = $k;

	    push @grades, $tmp;
	  }
	}

      ## collect and crossref actual grade info
      my $grade_obj = [];

      foreach my $grade (@grades) {
	## each grade is an attempt for the current outcome
	## each grade's attempt_id should have some components in the attempt file hash
		

	# create a graded attempt object
	my $thisgrade = {};

	my $date_submitted = $grade->{'DATEATTEMPTED'}->{'value'};
	my $student_submission = $grade->{'STUDENTSUBMISSION'}->{'TEXT'};
	my $student_comments = $grade->{'STUDENTCOMMENTS'};
	my $instructor_comments = $grade->{'INSTRUCTORCOMMENTS'}->{'TEXT'};
	my $instructor_notes = $grade->{'INSTRUCTORNOTES'}->{'TEXT'};
	my $attempt_grade = $grade->{'GRADE'}->{'value'};


	%$thisgrade =		(
				 member => $memberid,
				 outcome => $outcome_id, 
				 student => $self->{'users'}->{ $self->{'membermap'}->{$memberid} },
				 date => $date_submitted,
				 submission => $student_submission,
				 comments => $student_comments,
				 instructor_comments => $instructor_comments,
				 instructor_notes => $instructor_notes,
				 grade => $attempt_grade
				);

	push @$grade_obj, $thisgrade;
		
      }


      # add reference to outcome
      push @{$thisoutcome->{'grade'}}, $grade_obj;


      # add reference to student
      my $student_bbid = $self->{'membermap'}->{$memberid};
      $self->{'users'}->{$student_bbid}->{'grades'}->{$outcome_id} =
	$grade_obj;
    }
  }
}


sub outcomes() {
  my ($self) = @ARGV;
  #return map { bless $_ } @{ $self->{'outcomes'} };
  return @{ $self->{'outcomes'} };
}
    

sub students() {
  my ($self) = @ARGV;
  return map { bless $_ } @{ $self->{'outcomes'} };
}

1;
