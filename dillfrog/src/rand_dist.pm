package rand_dist;
use strict;

sub new {
  # ($priority, $value) pairs
  my $proto = shift;

  if(!@_ || @_ % 2) { return undef; }

  my $total;
  # find total priority
  for (my $i=0; $i<@_; $i+=2) { $total += $_[$i]; }
  my ($dist, $marker) = ([]);
  for (my $i=0; $i<@_; $i+=2) {
      push( @$dist, [ $marker += $_[$i]/$total, $_[$i+1] ] );
      print "$_[$i+1]: $marker\n";
  }
  bless($dist, $proto);
  return $dist;
}

sub choose {
  my $dist = shift;
  my ($max, $rand, $min, $ele, $done) = (scalar @{$dist}, rand(1));
  while (!$done) {
    $ele = int (($min + $max) / 2);
    $done = ($ele == 0 || $ele == @{$dist} || ( $rand > $dist->[$ele-1]->[0] && $rand < $dist->[$ele]->[0] ) );
    if(!$done) { 
          if ($rand < $dist->[$ele]->[0]) { $max = $ele-1; }
          else { $min = $ele + 1; }
    } 

  }
  if(wantarray) { return ($rand, @{$dist->[$ele]}) }
  else { return $dist->[$ele]->[1]; }
}

1;
