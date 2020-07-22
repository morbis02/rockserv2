use strict;

package rockobj;
use strict;

sub ai_get_hostile_target {
    # Picks a random target whom will hit or is hitting the npc in
    # this current instance.
    #
    # Note: An old exploit was to have a tank/newbie enter the room,
    # causing the NPC to attack the newbie. With this function,
    # we only choose to attack those who are aggressive, or who
    # entered the room.
    #
	# Call like:
	#
	#     my $targ = $myobject->ai_get_random_target();
	#     if ($targ) { ... blah ... }

	my ($self, $victim) = @_;

	die "No \$victim passed to ai_get_hostile_target"
	    unless $victim;
		
	my @targets = grep {
    	!$self->cant_aggress_against($_) &&
        (($_->{'HOSTILE'} && $_->cant_aggress_against($victim))
        || $_->{'OBJID'} == $victim->{'OBJID'})
	} $main::map->[$self->{'ROOM'}]->inv_pobjs(); # These could be NPCs OR Players!!

#        &main::rock_shout(undef, "{17}Debug: $targets[0] \n", 1);
        return undef unless @targets;	
	return $targets[int rand @targets];
}

sub ai_get_random_target {
    # Picks a random target from those users in the game.
	# This was initially used in npc::attack_sing, but it seems
	# like we could use it in other places too. Can return undef. 
	#
	# Call like:
	#
	#     my $targ = $myobject->ai_get_random_target();
	#     if ($targ) { ... blah ... }
    #
	my $self = shift;

	my @targets = grep {
        !$self->cant_aggress_against($_)
	} $main::map->[$self->{'ROOM'}]->inv_pobjs();

	##my $targ = $self->ai_pvp_target_lowest('HP', 45) || $victim;
    return undef unless @targets;
	
	return $targets[int rand @targets];
}

sub ai_move_random {
 my $self = shift;
 my @a = $main::map->[$self->{'ROOM'}]->exits_adj();
 if(@a) {
    $self->realm_move($a[rand($#a+1)]);
    return 1;
 }
 return;
}

sub ai_suggest_move_random (hash of {'DIR'}=roomobj) {
  # executes a random direction
  my ($self, %array, $key) = @_;
  foreach $key (keys(%array)) {
     if( ref($array{$key}) ) { $array{$key} = rand(1); }
     else { $array{$key} = rand(1); }
  }
  return(%array);
}

sub ai_suggest_move_gore (hash of {'DIR'}=roomobj) {
 my ($self, %array) = @_;
 my ($dir, $highgore, $lowgore, $diff);
 # set up high values
 foreach $dir (keys(%array)) {
   $array{$dir} = $array{$dir}->{'GOR'}; # make the value a gore value instead.
   if ( ($array{$dir}>$highgore) || (!$highgore) ) { $highgore=$array{$dir}; }
   if ( ($array{$dir}<$lowgore) || (!$lowgore) ) { $lowgore=$array{$dir}; }
 }
 # calculate modifier
 $diff = ($highgore - $lowgore);
 if($diff) {
   # (otherwise diff is zero and you dont really want to divide by it :-))
   # we can just skip it then anyway since they're all zeroish
   foreach $dir (keys(%array)) {
     $array{$dir}=$array{$dir}/$diff; # could * 100 but won't so it works with fuzzy logic :)
   }
 }
 #my @r = %array; print "GORE Returning @r\n";
 return(%array);
}

sub attack_gen {
   # dam can be negative for additive hps
   my ($self, $victim, $dam) = @_;
   
   # don't even bother if he's already dead
   if($victim->is_dead()) { return; }

   # subtract hp
   $victim->{'HP'} -= int $dam;
   
   # if hp is over the max, cap it at max
   if($victim->{'HP'} > $victim->{'MAXH'}) { $victim->{'HP'} = $victim->{'MAXH'}; }
   
   # record damage so that exp can be divvied on a kill.
   $self->damAttack($victim, $dam);
   
   # kill'em if he's got neg hp
   if($victim->is_dead()) { $victim->die(); } 
   
   return;
}

sub ai_pvp_target_lowest {
    my ($self, $key, $min) = @_;
    
    $key = 'LEV' unless $key;
    $min = 1 unless $min;
    my $minObj;
    foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
        next if ( (($o->{'TYPE'} != 1)  && ($o->{'TYPE'} != 2)) ||
                  ($main::allyfriend[$self->{'RACE'}]->[$o->{'RACE'}]) ||
                  ($o->{'LEV'}<$min) ||
                  ($o->{'HP'}<=0) ||
                  $o->{'IMMORTAL'}
                );
        
        if(!$minObj || $minObj->{$key} > $o->{$key}) { $minObj = $o; }
    }
    return($minObj);
}

sub ai_pvp_target_highest {
    my ($self, $key, $max) = @_;
    
    $key = 'LEV' unless $key;
    $max = 100_000 unless $max;
    my $maxObj;
    foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
        next if ( (($o->{'TYPE'} != 1)  && ($o->{'TYPE'} != 2)) ||
                  ($main::allyfriend[$self->{'RACE'}]->[$o->{'RACE'}]) ||
                  ($o->{'LEV'}>$max)
                );
        
        if(!$maxObj || $maxObj->{$key} < $o->{$key}) { $maxObj = $o; }
    }
    
    return($maxObj);
}


sub ai_suggest_move_nogore (hash of {'DIR'}=roomobj) {
 my ($self, %array) = @_;
 %array = &rockobj::ai_suggest_move_gore(undef, %array);
 my ($dir); 
 # invert the array
 foreach $dir (keys(%array)) {  $array{$dir} = 1 - $array{$dir};  }
 #my @r = %array; print "NOGORE Returning @r\n";
 return(%array);
}

sub ai_suggest_norecurse (hash of {'DIR'}=boolean/fuzzy value) {
 my ($self, %array) = @_;
 my ($dir, @k);
 if( ( (scalar keys(%array)) - defined($array{''}) )<= 1) { return(%array); }
 if($self->{'FRM'} && $array{$self->{'FRM'}}) { delete $array{$self->{'FRM'}}; }
 return(%array);
}

sub ai_move (suggestion table of {'DIR'}=pct) {
 my $self = shift;
 my (%h, @dirs, $dirval, $dir);

 # compile suggestions
 while (@_) { 
   $h{$_[0]} += $_[1];
   shift; shift;
 }

 # find the best one
 foreach $dir (keys(%h)) { 
   if( ($h{$dir} > $dirval) || ($#dirs == -1) ) { @dirs = ($dir); $dirval = $h{$dir}; }
   elsif($h{$dir} == $dirval) { push(@dirs, $dir); }
 }

 # pick an exit, any exit
 $dir = $dirs[rand($#dirs+1)];

 # and move (if it's not a blank exit)!
 if ($dir) { $self->realm_move($dir); return 1; }

 return;
}



sub weapon_get {
   my $self = shift;
   if($self->{'WEAPON'}) { return ($main::objs->{$self->{'WEAPON'}}); }
   elsif($self->{'DWEAP'}) {  return (&main::obj_lookup($self->{'DWEAP'})); }
   return undef;
}

sub room_safe {
 my $self = shift;
 if($main::map->[$self->{'ROOM'}]->{'SAFE'}) { return(1); }
 elsif($main::map->[$self->{'ROOM'}]->safe_racially($self) > .8) { return(1); }
 else { return(0); }
}

sub packcall() {
 my ($self, $radius) = @_; # radius = rooms away (1 stays in original room, 2 is one room away)
 $radius = 2 unless $radius;
 $main::map->[$self->{'ROOM'}]->tell(14, 0, $radius, 1, $self, $radius);
}

sub on_packcall() {}  # my ($self, $caller, $type, $dir) = @_;

sub inv_rand_lose_unequipped() {
   my $self = shift;
   my $item = $self->inv_rand_item_unequipped();
   if (!$item || $self->{'TYPE'} != 1) { return 0; }
   else {
      $self->log_append("{2}A dimensional gremlin leaps from the shadows, grabs your $item->{'NAME'} and runs away cackling like a mad man.\n");
      $self->room_sighttell("{2}A dimensional gremlin leaps from the shadows, grabs $self->{'NAME'}\'s $item->{'NAME'} and runs away cackling like a mad man.\n");
      $item->dissolve_allsubs();
   }
}

sub inv_rand_item_unequipped {
   # returns random unequipped/unqorn item or undef
   my ($self) = @_;
   my ($item, %tempINV);
   %tempINV = %{$self->{'INV'}};
   
   while(!$item && %tempINV) {
     my @keys = keys %tempINV;
     $item = delete $tempINV{$keys[rand @keys]};
     if ($item->{'WORN'} || $self->{'WEAPON'} == $item->{'OBJID'}) { undef($item); }
   }
      
   return $item;
}

sub pick_something_up {
    my $self = shift;
    my ($i, @objs);

    # kinda hacky fix for the bug where secured fuzzems could pick up
    # cryl from their owner. Here we guarantee that they're contained by a room,
    # and that their Room record is accurate.
    return unless $main::map->[$self->{'ROOM'}]->inv_has($self);

    foreach $i ($main::map->[$self->{'ROOM'}]->inv_objs) {
        if(($i->{'TYPE'}==0) && (!$i->{'LASTDROP'} || ((time - $i->{'LASTDROP'})>80)) && $self->can_lift($i) && $i->can_be_lifted($self) && !$i->is_invis($self)) {
           push(@objs, $i);
        }
    }
    if ($#objs == -1) { 
      if($main::map->[$self->{'ROOM'}]->{'CRYL'}) { $self->cryl_get(); return(undef,1); }
      return(0);
    }
    $i = $objs[int rand($#objs+1)];
    $main::map->[$self->{'ROOM'}]->inv_del($i);
    $self->inv_add($i);
    $self->room_sighttell("{2}$self->{'NAME'} {12}snatches {5}$i->{'NAME'}.\n");
    return($i,1);
}

sub equip_best {
  my ($self, $quiet) = @_;
  my ($i, $weapon, %scores, %armour);
  if($self->{'WEAPON'}) { $weapon = $main::objs->{$self->{'WEAPON'}}; }
  elsif($self->{'DWEAP'}) { $weapon = $main::objs->{$self->{'DWEAP'}}; }
  foreach $i ($self->inv_objs) {
    if ( ($i->{'ATYPE'}) && (!$armour{$i->{'ATYPE'}} || ($i->{'AC'} > $armour{$i->{'ATYPE'}}->{'AC'})) ) { $armour{$i->{'ATYPE'}}=$i; }
    elsif ( !$i->{'INCORP'} && (!$weapon || ($i->{'WC'} > $weapon->{'WC'})) )  { $weapon=$i; }
  }
  foreach $i (values(%armour)) {
    if(!$i->{'WORN'}) { $self->item_hwear($i, $quiet); }
  }
  if($weapon && !$weapon->{'EQD'} && $weapon->{'OBJID'} != $self->{'DWEAP'}) { $self->item_hequip($weapon, $quiet); }
  return;
}
  # now wear'em if we can

sub ai_moves_to (objid/roomnum) {
 # returns minimum number of moves to get to a certain object/room.
 # returns -1 if it's impossible on that plane.
 my ($self, $data, $targroom) = @_;

 if(ref($data)) { $targroom = $data->{'ROOM'}; }
 else { $targroom = $data; }

 if ($main::map->[$self->{'ROOM'}]->{'M'} != $main::map->[$targroom]->{'M'}) { return (-1); }
 
 # if the room doesn't have a trail leading to the victim's room, make one.
 if(!$main::map->[$self->{'ROOM'}]->{'TRAILTO'}->{$targroom}) { $main::map->[$targroom]->room_trailto_make; }

 return($main::map->[$self->{'ROOM'}]->{'TRAILTO'}->{$targroom});
}

sub ai_troll_to {
   # walks toward victim, one second at a time.
   # $self->ai_troll_to($victim);
   
   my ($self, @args) = @_;
   
   delete $self->{'TRD'};
   
   if($self->ai_move_to(@args)) {
      $main::eventman->enqueue(1 + int rand 2, \&ai_troll_to, $self, @args);
   }
}

sub ai_move_to(obj/roomnum) {
 my ($self, $data, $targroom) = @_;
 
 if(ref($data)) { $targroom = $data->{'ROOM'}; }
 else { $targroom = $data; }
 
 if ($self->{'ROOM'} == $targroom) { $self->log_append("You are there.\n"); return 0; }
 elsif ($main::map->[$self->{'ROOM'}]->{'M'} != $main::map->[$targroom]->{'M'}) { $self->log_append("That room is on another plane.\n"); return 0; }
 
 
 my ($room, $lowval, $r, $dir, $targdir) = ($main::map->[$self->{'ROOM'}]);
  
 # if the room doesn't have a trail leading to the victim's room, make one.
 if(!$room->{'TRAILTO'}->{$targroom}) { $main::map->[$targroom]->room_trailto_make; }

 $lowval = $room->{'TRAILTO'}->{$targroom};
 # print "Lowval is $lowval.\n";
 
 foreach $dir (@main::dirlist) {
  if( (($r = $room->{$dir}->[0]) > 0) && ($main::map->[$r]->{'TRAILTO'}->{$targroom} < $lowval) ) { 
    # print "UPDATE $dir. (#$r)\n";
     $lowval = $main::map->[$r]->{'TRAILTO'}->{$targroom};
     $targdir=$dir;
  }
 }
 
 #print "Dir is $dir. targdir is $targdir. lowval is $lowval.\n";
 
 # thennn, move in that direction.
 if($targdir) {
   #if($data->{'NAME'}) { $self->log_append("$data->{'NAME'} is ".($lowval+1)." rooms away. Moving closer.\n"); }
   return $self->realm_move($targdir);
 #  print "$self->{'NAME'} chose $targdir (value of $lowval steps away).\n";
 } else {
   #$self->log_append("You are as close as you can get from here.\n"); 
   return 0;
 }
 return 1;
}

sub remove_nomobrooms_hash (rooms) {
 my (@rooms);
 while(@_) { if (!$_[1]->{'NOMOB'}) { push(@rooms,shift(@_),shift(@_)); } else { shift; shift; } }
 return(@rooms);
}

sub ai_roamtarg_maxobj {
  # returns success/failure
  my ($self, $n) = @_;
  $n = 10 unless $n;
  my ($r, @r);
  foreach $r (@{$main::map}) { 
    if ( ($r->{'M'} == $main::map->[$self->{'ROOM'}]->{'M'}) && ( (scalar keys(%{$r->{'INV'}})) >= $n ) ) { 
      $self->{'ROAMTARG'}=$r->{'ROOM'}; return(1);
    }
  }
  delete $self->{'ROAMTARG'}; # or just clear it if i couldnt do it..try again later :P
  return(0);
}

sub ai_roamtarg_garbage {
  # returns success/failure
  # to be a garbage room you have to have at least
  # 10 items in yourself
  my ($self, $n) = @_;
  $n = 10 unless $n;
  my ($r, @r);
  foreach $r (values (%{$main::garbage_rooms})) { 
    if ( ($r->{'M'} == $main::map->[$self->{'ROOM'}]->{'M'}) && ( (scalar keys(%{$r->{'INV'}})) >= $n ) ) { 
      $self->{'ROAMTARG'}=$r->{'ROOM'}; return(1);
    }
  }
  delete $self->{'ROAMTARG'}; # or just clear it if i couldnt do it..try again later :P
  return(0);
}

1;

