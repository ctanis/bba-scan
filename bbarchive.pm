package bbarchive;

use strict;
use XML::Simple;
use Data::Dumper;


use constant {
    GRADEBOOK_TYPE => 'course/x-bb-gradebook',
    USER_TYPE => 'course/x-bb-user',
    ATTEMPT_TYPE => 'course/x-bb-attemptfiles',
    COURSEMEMBER_TYPE => 'membership/x-bb-coursemembership',
    MANIFEST_FILE => 'imsmanifest.xml'
};




## a blessed reference
sub new {
    return bless {}, @_;
}



## configure self to load archive at $path
sub load {
    my ($self, $path) = @_;
    $self->{'path'} = $path . '/';

    # process manifest file
    my $xml_parser = XML::Simple->new();

    my $manifest = $xml_parser->XMLin($self->{'path'} . MANIFEST_FILE)
	or die;

    
    ## extract manifest resources
    my @resources = @{ $manifest->{'resources'}->{'resource'} };

    foreach my $resource (@resources)
    {
	my $type = $resource->{'type'};

	if ($type eq GRADEBOOK_TYPE)
	{
	    $self->{'gradebook.xml'} = $resource->{'bb:file'};
	}

	if ($type eq USER_TYPE)
	{
	    $self->{'user.xml'} = $resource->{'bb:file'};
	}

	if ($type eq ATTEMPT_TYPE)
	{
	    ## multiple course/x-bb-attemptfiles elements can be expected
	    push @{$self->{'attempt.xml'}}, $resource->{'xml:base'};
	}

	if ($type eq COURSEMEMBER_TYPE)
	{
	    $self->{'coursemember.xml'} = $resource->{'bb:file'};
	}
    }



}
