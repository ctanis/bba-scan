use bbarchive;
use Data::Dumper;



my $bba = bbarchive->new();


$bba->load("/Users/ctanis/Desktop/bb/1110");

print Dumper($bba);
