use strict;

sub map_gencoords {
 # sets up map coords
 my ($room);
 undef(%{$main::exitmap});
 foreach $room (@{$main::map}) { $main::exitmap->{$room->{'M'}}->{$room->{'Z'}}->{$room->{'X'}}->{$room->{'Y'}}=$room->{'ROOM'}; }
 return;
}

sub brief_map_floor(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $text, @lines);
   #if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+1, $y+1, $x-1, $y-1); }
   #elsif ($sizetype <1) { 
   ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   #}
   #else {  ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y+$sizetype); }
   my ($cap, $roomid, $n, $m);
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'W'}->[0]) || 
            ($main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'E'}->[0])
          )
        { $cap .= '{2}-'; } else { $cap .= " "; }
       
       if (!defined($roomid)){ $cap .= " "; }
       else {
         if (($m == $x) && ($n == $y) && ($f == $z)){ $cap .= '{11}'; } else { $cap .= '{4}'; }
         if ($main::map->[$roomid]->{'U'}->[0]){ $cap .= 'U'; }
         elsif ($main::map->[$roomid]->{'D'}->[0]){ $cap .= 'D'; }
         else { $cap .= "O"; }
       }
     }

     push(@lines, $cap) unless &main::rm_whitespace($cap) eq '';
     $cap=''; ## hit return, reset the x read.
     
      for ($m=$minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'SW'}->[0]) ||
            ($main::exitmap->{$map}->{$f}->{$m-1}->{$n-1} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}]->{'NE'}->[0])
          ) {
          #print "$roomid:$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}: f: $f, x: $m, y: $n\n";
          $cap .= '{2}/'; 
       } 
       elsif ($main::exitmap->{$map}->{$f}->{$m-1}->{$n} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'SE'}->[0]){ $cap .= '{2}\\'; }
       else { $cap .= " "; }
       if ($roomid && $main::map->[$roomid]->{'S'}->[0]){ $cap .= '{2}|'; } else { $cap .= " "; }
      }
      
      push(@lines, $cap) unless &main::rm_whitespace($cap) eq '';
      $cap=''; ## hit return, reset the x read.
   }
   
   # Remove unnecessary text at the beginning of each line.
   my ($minpre, $minpost) = (1_000_000, 1_000_000);
   foreach my $line (@lines) {
       $line =~ /^( +)/;
       $minpre = length($1) if length($1)<$minpre;
       $line =~ /( +)$/;
       $minpost = length($1) if length($1)<$minpost;
   }
   for (@lines) {
       $_ = substr($_, $minpre, length($_) - $minpost - $minpre)."\n";
   }
   return('{40}'.join('', @lines).'{41}');
}

sub brief_map_floor_db(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $text);
   #if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+1, $y+1, $x-1, $y-1); }
   #elsif ($sizetype <1) { 
   ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   #}
   #else {  ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y+$sizetype); }
   my ($cap, $roomid, $n, $m);
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'W'}->[0]) || 
            ($main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'E'}->[0])
          )
        { $cap .= '{2}-'; } else { $cap .= " "; }
       
       if (!defined($roomid)){ $cap .= " "; }
       else {
         
         ## THE DB COLORING
         if($main::map->[$roomid]->{'DB'}) { $cap .= '{5}'; }
         else {  $cap .= '{4}'; }
         
         if ($main::map->[$roomid]->{'U'}->[0]){ $cap .= 'U'; }
         elsif ($main::map->[$roomid]->{'D'}->[0]){ $cap .= 'D'; }
         else { $cap .= "O"; }
       }
     }
     $cap .= "\n"; ## hit return, reset the x read.
     
      for ($m=$minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'SW'}->[0]) ||
            ($main::exitmap->{$map}->{$f}->{$m-1}->{$n-1} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}]->{'NE'}->[0])
          ) {
          #print "$roomid:$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}: f: $f, x: $m, y: $n\n";
          $cap .= '{2}/'; 
       } 
       elsif ($main::exitmap->{$map}->{$f}->{$m-1}->{$n} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'SE'}->[0]){ $cap .= '{2}\\'; }
       else { $cap .= " "; }
       if ($roomid && $main::map->[$roomid]->{'S'}->[0]){ $cap .= '{2}|'; } else { $cap .= " "; }
      }
      if(&main::rm_whitespace($cap) ne '') { $text .= $cap."\n"; }
      $cap=''; ## hit return, reset the x read.
   }
   return('{40}'.$text.'{41}');
}

sub lifeform_scan(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $obj, $succ, $objnum);
   if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+5, $y+5, $x-5, $y-5); }
   elsif ($sizetype <1) { 
     ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   } else { ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y-$sizetype); }
   if($maxx > $main::maxx) { $maxx = $main::maxx; } if($maxy > $main::maxy) { $maxy = $main::maxy; }
   if($miny < $main::miny) { $miny = $main::miny; } if($minx < $main::minx) { $minx = $main::minx; } 
   my ($cap, $roomid, $n, $m);
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       if (!$main::exitmap->{$map}->{$f}->{$m}->{$n} || $main::map->[$main::exitmap->{$map}->{$f}->{$m}->{$n}]->{'NOMAP'}){ $cap .= " "; }
       else { 
         $succ=0;
         foreach $objnum (keys(%{$main::activeusers})) {
           $obj = $main::map->[$main::objs->{$objnum}->{'ROOM'}];
           if (($obj->{'M'} == $map) && ($obj->{'X'} == $m) && ($obj->{'Y'} == $n) && ($obj->{'Z'} == $f)){ $succ=1; }
         }
         if($succ) {
           if (($x == $m) && ($y == $n) && ($z == $f)){ $cap .= '{11}'; }
           else { $cap .= '{13}'; }
         } else { $cap .= '{14}'; }
         $cap .= "O";
       }
     }
     $cap .= "\n"; ## hit return, reset the x read.
   }
   return('{40}'.$cap.'{41}');
}

sub lifeform_scan_terrain(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $obj, $objnum);
   if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+5, $y+5, $x-5, $y-5); }
   elsif ($sizetype <1) { 
     ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   } else { ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y-$sizetype); }
   if($maxx > $main::maxx) { $maxx = $main::maxx; } if($maxy > $main::maxy) { $maxy = $main::maxy; }
   if($miny < $main::miny) { $miny = $main::miny; } if($minx < $main::minx) { $minx = $main::minx; } 
   my ($cap, $n, $m);
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       my $scan_room = $main::map->[$main::exitmap->{$map}->{$f}->{$m}->{$n} || 0];
       if ($scan_room->{'ROOM'}==0 || $scan_room->{'NOMAP'}){ $cap .= " "; }
       else { 
         $cap .= '{'.$main::terrain_colors[$scan_room->{'TER'}].'}';
         
         if (($x == $m) && ($y == $n) && ($z == $f)){ $cap .= '*'; }
         else { $cap .= 'O'; }
         
       }
     }
     $cap .= "\n"; ## hit return, reset the x read.
   }
   return('{40}'.$cap.'{41}');
}

sub lifeform_scan_terrain_array(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $obj, $succ, $objnum);
   if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+5, $y+5, $x-5, $y-5); }
   elsif ($sizetype <1) { 
     ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   } else { ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y-$sizetype); }
   if($maxx > $main::maxx) { $maxx = $main::maxx; } if($maxy > $main::maxy) { $maxy = $main::maxy; }
   if($miny < $main::miny) { $miny = $main::miny; } if($minx < $main::minx) { $minx = $main::minx; } 
   my (@cap, $roomid, $n, $m);
   my $lineNum=0;
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       my $scan_room = $main::map->[$main::exitmap->{$map}->{$f}->{$m}->{$n} || 0];
       if ($scan_room->{'ROOM'}==0 || $scan_room->{'NOMAP'}){ $cap[$lineNum] .= " "; }
       else { 
         $cap[$lineNum] .= '{'.$main::terrain_colors[$scan_room->{'TER'}].'}';
         
         if (($x == $m) && ($y == $n) && ($z == $f)){ $cap[$lineNum] .= '*'; }
         else { $cap[$lineNum] .= 'O'; }
       }
     }
       $lineNum++;
   }
   return(\@cap);
}


sub lifeform_scan_array(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $obj, $succ, $objnum);
   if($sizetype == 0) {  ($maxx, $maxy, $minx, $miny) = ($x+5, $y+5, $x-5, $y-5); }
   elsif ($sizetype <1) { 
     ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   } else { ($maxx, $maxy, $minx, $miny) = ($x+$sizetype, $y+$sizetype, $x-$sizetype, $y-$sizetype); }
   if($maxx > $main::maxx) { $maxx = $main::maxx; } if($maxy > $main::maxy) { $maxy = $main::maxy; }
   if($miny < $main::miny) { $miny = $main::miny; } if($minx < $main::minx) { $minx = $main::minx; } 
   my (@cap, $roomid, $n, $m);
   my $lineNum=0;
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       if (!$main::exitmap->{$map}->{$f}->{$m}->{$n} || $main::map->[$main::exitmap->{$map}->{$f}->{$m}->{$n}]->{'NOMAP'}){ $cap[$lineNum] .= ' '; }
       else { 
         $succ=0;
         foreach $objnum (keys(%{$main::activeusers})) {
           $obj = $main::map->[$main::objs->{$objnum}->{'ROOM'}];
           if (($obj->{'M'} == $map) && ($obj->{'X'} == $m) && ($obj->{'Y'} == $n) && ($obj->{'Z'} == $f)){ $succ=1; }
         }
         if($succ) {
           $cap[$lineNum] .= (($x == $m) && ($y == $n) && ($z == $f))?'{11}':'{13}';
         } else { $cap[$lineNum] .= '{14}'; }
         $cap[$lineNum] .= "O";
       }
     }
       $lineNum++;
   }
   return(\@cap);
}

sub brief_map_floor_lifeform(){
   my ($map, $f, $x, $y, $z, $sizetype) = @_;
   my ($maxx, $maxy, $minx, $miny, $succ, $objnum, $obj, $text);
   ($maxx, $maxy, $minx, $miny) = ($main::maxx, $main::maxy, $main::minx, $main::miny);
   my ($cap, $roomid, $n, $m);
   for ($n=$maxy; $n>=$miny; $n--) {
     ## circulates through the ys
     
     for ($m = $minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'W'}->[0]) || 
            ($main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'E'}->[0])
          )
        { $cap .= '{2}-'; } else { $cap .= " "; }
       
       if (!defined($roomid)){ $cap .= " "; }
       else {
         $succ=0;
         foreach $objnum (keys(%{$main::activeusers})) {
           $obj = $main::map->[$main::objs->{$objnum}->{'ROOM'}];
           if (($obj->{'M'} == $map) && ($obj->{'X'} == $m) && ($obj->{'Y'} == $n) && ($obj->{'Z'} == $f)){ $succ=1; }
         }
         if($succ) {
           if (($x == $m) && ($y == $n) && ($z == $f)){ $cap .= '{11}'; }
           else { $cap .= '{13}'; }
         #} elsif ($main::map->[$roomid]->{'EXITS'} > 2) { $cap .= '{15}'; 
         } else { $cap .= '{14}'; }
         if ($main::map->[$roomid]->{'U'}->[0]){ $cap .= 'U'; }
         elsif ($main::map->[$roomid]->{'D'}->[0]){ $cap .= 'D'; }
         else { $cap .= "O"; }
       }
     }
     $cap .= "\n"; ## hit return, reset the x read.
     
      for ($m=$minx; $m<=$maxx; $m++) {
       ## circulates through the rooms on the x..
       $roomid = $main::exitmap->{$map}->{$f}->{$m}->{$n};
       if ( ($roomid && $main::map->[$roomid]->{'SW'}->[0]) ||
            ($main::exitmap->{$map}->{$f}->{$m-1}->{$n-1} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}]->{'NE'}->[0])
          ) {
          #print "$roomid:$main::exitmap->{$map}->{$f}->{$m-1}->{$n-1}: f: $f, x: $m, y: $n\n";
          $cap .= '{2}/'; 
       } 
       elsif ($main::exitmap->{$map}->{$f}->{$m-1}->{$n} && $main::map->[$main::exitmap->{$map}->{$f}->{$m-1}->{$n}]->{'SE'}->[0]){ $cap .= '{2}\\'; }
       else { $cap .= " "; }
       if ($roomid && $main::map->[$roomid]->{'S'}->[0]){ $cap .= '{2}|'; } else { $cap .= " "; }
      }
      if(&main::rm_whitespace($cap) ne '') { $text .= $cap."\n"; }
      $cap=''; ## hit return, reset the x read.
   }
  
   my ($minspace) = sort { $a <=> $b } map { length($_) } $text =~ m/^(\s+)/gm;
   if ($minspace) {
       $text =~ s/^\s{$minspace}(.+?)[ ]*$/\1/gm;
   }
   return('{40}'.$text.'{41}');
}
1;
