package bbarchive;

#use strict;
use Carp qw(confess);
use XML::Simple;
use Data::Dumper;


use constant
  {
   GRADEBOOK_TYPE => 'course/x-bb-gradebook',
   USER_TYPE => 'course/x-bb-user',
   ATTEMPT_TYPE => 'course/x-bb-attemptfiles',
   COURSEMEMBER_TYPE => 'membership/x-bb-coursemembership',
   RUBRIC_DEF => 'course/x-bb-rubrics',
   RUBRIC_EVAL => 'course/x-bb-crsrubriceval',
   RUBRIC_ASSOC => 'course/x-bb-crsrubricassocation',
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

    if ($type eq RUBRIC_DEF) {
      $self->{'rubricdef.xml'} = $resource->{'bb:file'};
    }

    if ($type eq RUBRIC_ASSOC) {
      $self->{'rubricassoc.xml'} = $resource->{'bb:file'};
    }

    if ($type eq RUBRIC_EVAL) {
      $self->{'rubriceval.xml'} = $resource->{'bb:file'};
    }

  }


  ## load rubrics

  my $rubricdefs = $xml_parser->XMLin($self->{'path'} . $self->{'rubricdef.xml'})
    or confess;

  # my $rubricassoc = $xml_parser->XMLin($self->{'path'} . $self->{'rubricassoc.xml'})
  #   or confess;

  my $rubriceval = $xml_parser->XMLin($self->{'path'} . $self->{'rubriceval.xml'})
    or confess;


  ## build description of rubric cells

  for my $rubric_id (keys %{$rubricdefs->{'Rubric'}}) {
    
      my $rubx = $rubricdefs->{'Rubric'}->{$rubric_id};
      my $new_rubric = $self->{'rubrics'}->{$rubric_id} = {};

      $new_rubric->{'title'} = $rubx->{'Title'};
      $new_rubric->{'desc'} = $rubx->{'Description'};


      my $rowid;
      my $rowhash;

      while (($rowid,$rowhash) = each %{$rubx->{'RubricRows'}->{'Row'}}) {
	my $rowhdr = $rowhash->{'Header'}->{'value'};

	# print STDERR "$rowhdr\n";

	my $colarray;

	## make sure it's an array
	if ((ref $rowhash->{'RubricColumns'}->{'Column'}) eq 'ARRAY') {
	  $colarray = $rowhash->{'RubricColumns'}->{'Column'};
	}
	else {
	  $colarray = [ $rowhash->{'RubricColumns'}->{'Column'} ];
	}

	for my $col (@$colarray) {
	      
	  my $celldesc = $self->{'rubriccells'}->{$col->{'Cell'}->{'id'}} = {};

	  $celldesc->{'desc'} = $col->{'Cell'}->{'CellDescription'}->{'value'};
	  $celldesc->{'title'} = $rowhdr;
	}
      }


    }

  ## build mapping from attempts to rubric evaluations
  for my $rub_eval (values %{$rubriceval->{'RUBRIC_EVALUATION'}})
    {
#      print Dumper($rub_eval);

      my $attempt = $rub_eval->{'ATTEMPT_ID'}->{'value'};

      next unless $attempt;

      my $rubattempt = $self->{'attempt_rubric'}->{$attempt} = {};
      my $text = 
	$rub_eval->{'RUBRIC_EVAL'}->{'COMMENTS'}->{'COMMENTS_TEXT'};

      if (ref $text) {
	$rubattempt->{'comment'} = $text->{'value'};
      }
      else {
	$rubattempt->{'comment'} = $text;
      }


      for my $rubcell (values %{$rub_eval->{'RUBRIC_EVAL'}->{'RUBRIC_CELL_EVAL'}})
	{
	  my $fdbk = $rubcell->{'FEEDBACK'};

	  if (ref $fdbk)
	    {
	      $fdbk = $fdbk->{'FEEDBACK_TEXT'};
	    }

	  push @{$rubattempt->{'cells'}},
	    { cell => $rubcell->{'RUBRIC_CELL_ID'}->{'value'},
	      message => $fdbk };

	}
    }


  

  # create user hash
  my $users = $xml_parser->XMLin($self->{'path'} . $self->{'user.xml'})
    or confess;

  # print Dumper($users);

  for my $bb_id (keys %{$users->{'USER'}}) {
    my $student = $users->{'USER'}->{$bb_id};

    my $last = $student->{'NAMES'}->{'FAMILY'}->{'value'};
    my $first = $student->{'NAMES'}->{'GIVEN'}->{'value'};
    my $full = "$first $last";

    my $uid = $student->{'BATCHUID'}->{'value'};

    ## blackboard id --> name, school id and blackboard id
    $self->{'users'}->{$bb_id} = { name => $full,
				   first => $first,
				   last => $last,
				   id => $uid,
				   bb_id => $bb_id };
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
  my %attempt_files;

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


      push @{$attempt_files{$attempt_id}}, { path => $fullpath, type=> $filetype }

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

    ## skip calculated columns in gradebook
    next if $outcome->{'ISCALCULATED'}->{'value'} eq 'true';

    my $thisoutcome =
      $self->{'outcomes'}->{$outcome_id} = { id => $outcome_id,
					     title => $outcome_title,
					     points => $maxpoints };


    my $student_outcomes = $outcome->{'OUTCOMES'}->{'OUTCOME'};

    ## why was this here?
    ## next if defined $student_outcomes->{'ATTEMPTS'}

    ## for each student outcome id
    foreach my $soid (keys %$student_outcomes) {

      # get student and ultimate grade
      my $memberid = $student_outcomes->{$soid}->{'COURSEMEMBERSHIPID'}->{'value'};
      my $override = $student_outcomes->{$soid}->{'OVERRIDE_GRADE'};

      # skip invalid students
      next unless defined $self->{'membermap'}->{$memberid};

      my $this_student_outcome = { student => $self->{'users'}->{ $self->{'membermap'}->{$memberid} },
				   override => $override };

      my @attempts;
      if (defined $student_outcomes->{$soid}->{'ATTEMPTS'}->{'ATTEMPT'}->{'GRADE'})
	{
	  #single attempt
	  push @attempts, $student_outcomes->{$soid}->{'ATTEMPTS'}->{'ATTEMPT'};
	}
      else
	{
	  # multiple attempts
	  
	  foreach my $k (keys %{$student_outcomes->{$soid}->{'ATTEMPTS'}->{'ATTEMPT'}}) {
	    #store key as grade id
	    my $tmp = $student_outcomes->{$soid}->{'ATTEMPTS'}->{'ATTEMPT'}->{$k};
	    $tmp->{'id'} = $k;

	    push @attempts, $tmp;
	  }
	}

      ## collect and crossref actual grade info
      my $attempt_obj = [];


      foreach my $attempt (@attempts) {
	## each grade is an attempt for the current outcome
	## each grade's attempt_id should have some components in the attempt file hash
		

	# create a graded attempt object
	my $thisattempt = {};

        my $attempt_id = $attempt->{'id'};
	my $date_submitted = $attempt->{'DATEATTEMPTED'}->{'value'};
	my $student_submission = $attempt->{'STUDENTSUBMISSION'}->{'TEXT'};
	my $student_comments = $attempt->{'STUDENTCOMMENTS'};
	my $instructor_comments = $attempt->{'INSTRUCTORCOMMENTS'}->{'TEXT'};
	my $instructor_notes = $attempt->{'INSTRUCTORNOTES'}->{'TEXT'};
	my $attempt_grade;
	my $files = $attempt_files{$attempt->{'id'}};

	my $rubric=undef;

	if (exists $self->{'attempt_rubric'}->{$attempt->{'id'}}) {

	  my $rubattempt = $self->{'attempt_rubric'}->{$attempt->{'id'}};

	  $rubric->{'comment'} = $rubattempt->{'text'};
	  $rubric->{'cells'} = [];
#	  print STDERR $rubric->{'comment'}, "\n";

	  for my $note (@{$rubattempt->{'cells'}}) {

#	    print STDERR Dumper($note);

	    push @{$rubric->{'cells'}},
	      { cell => $self->{'rubriccells'}->{$note->{'cell'}},
		comment => $note->{'message'} };

	  }



	}


	# skip empty grades
	if (defined $attempt->{'GRADE'}->{'value'} and $attempt->{'GRADE'}->{'value'} ne "") {
	  $attempt_grade= $attempt->{'GRADE'}->{'value'};
	} else {
	  next;
	}




	{
	  no warnings;		# students may have been removed

          my $archive_dir = $self->{'path'};
          $instructor_comments =~ s/\@X\@EmbeddedFile\.cslocation\@X\@/$archive_dir\/csfiles\/privatedoc\/gradebook\/notesAndFeedback\/attempt\/$attempt_id\//g;
          

	  %$thisattempt=		(
					 attempt => $attempt_id,
                                         member => $memberid,
					 outcome => $outcome_id, 
					 date => $date_submitted,
					 submission => $student_submission,
					 comments => $student_comments,
					 instructor_comments => $instructor_comments,
					 instructor_notes => $instructor_notes,
					 grade => $attempt_grade,
					 files => $files,
					 rubric => $rubric
					);




          # if ($instructor_comments =~ /EmbeddedFile/) {
          #   print STDERR Dumper %$thisattempt;
          # }



	  push @$attempt_obj, $thisattempt;
	}
		
      }

      next unless @$attempt_obj;

      # finish building *this* student outcome object
      $this_student_outcome->{'attempts'}=$attempt_obj;


      # add reference to outcome
      push @{$thisoutcome->{'grades'}}, $this_student_outcome;


      # add reference to student
      {
	no warnings;		# students may have been removed
	my $student_bbid = $self->{'membermap'}->{$memberid};
	$self->{'users'}->{$student_bbid}->{'grades'}->{$outcome_id} = $this_student_outcome;
      }
    }
  }
}

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


    

sub outcome($) {
  my ($self, $title) = @_;

  foreach my $o (values %{ $self->{'outcomes'} })
    {
      if ($o->{'title'} eq $title)
	{
	  return bless $o;
	}
    }
  return undef;
}


sub outcomes() {
  my ($self) = @_;
  return
    map { bless $_ } sort { outcome_sorter $a->{'title'}, $b->{'title'} }
      values %{ $self->{'outcomes'} };
}
    

sub student_outcomes() {
  my ($self) = @_;
  return map { bless $_ }
    sort { $a->{'student'}->{'last'} cmp $b->{'student'}->{'last'} }
      @{ $self->{'grades'} };
}


sub grades() {
  my ($self) = @_;
  return map { bless $_ } @{ $self->{'grades'} };
}
	      



1;
