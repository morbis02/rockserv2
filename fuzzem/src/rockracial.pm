package rockobj;
use strict;

sub web_spin {
    my ($self) = shift;
    if (!$self->{'GIFT'}->{'WEBSPIN'} && !$self->skill_has(10)) { $self->log_append("{1}You have no idea how to spin a web.\n"); return; }
	if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if ($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}This room is protected from your race's webs.\n"); return; }
    if (!$self->{'WEBS'}) { $self->log_append("{1}Your mystical essence is far too drained to spin webs.\n"); return; }
    if (!$self->can_do(0, 0, 25)) { return; }

    $self->log_append("You spin the web.\n");
    $self->room_sighttell("$self->{'NAME'} spins an intricate web in $main::map->[$self->{'ROOM'}]->{'NAME'}.\n"); 

    my $web = web->new('NAME', 'web of '.lc($self->{'NAME'}), 'CATCHFUZ', .0075*($self->{'GIFT'}->{'WEBSPIN'} || 60), 'CATCHFUZ', .0095*($self->{'GIFT'}->{'WEBSPIN'}||60), 'CROBJID', $self->{'OBJID'}, 'RACE', $self->{'RACE'}, 'ROT', int(  time+30+($self->{'GIFT'}->{'WEBSPIN'}||60)+75*$self->skill_has(27) ) );

    # alter stickyfuz
    if ($self->skill_has(28) && (rand(1) < $self->fuzz_pct_skill(6, 70))) { $web->{'STICKYFUZ'}+=.3; if($web->{'STICKYFUZ'} > .95) { $web->{'STICKYFUZ'}=.95; } }

    # make invis 
    if ($self->skill_has(29) && (rand(1) < $self->fuzz_pct_skill(6, 100))) { $web->{'INVIS'}=1; }

    # add web to room
    $main::map->[$self->{'ROOM'}]->inv_add($web);
 
    # affect web-spinning gift.
    $self->gifts_affect('WEBSPIN');
    $self->{'WEBS'}--;
     return;
}

sub web_spin_player {
	my ($self, $vname) = @_;
	my $who;
	if($vname) {
        my ($success, $item) = $self->inv_cgetobj($vname, 0, $main::map->[$self->{'ROOM'}]->inv_pobjs, $self->inv_objs);
        if($success == 1) {
            $who = $item
        }
        elsif($success == 0) {
            $self->log_error("You don't see any $vname to sping your web upon.");
            return 0;
        }
        elsif($success == -1) {
            $self->log_append($item);
            return 0;
        }
    }
	
	
    
    if(!$who){return;}
	
	if (!$self->{'GIFT'}->{'WEBSPIN'} && !$self->skill_has(10)) { $self->log_append("{1}You have no idea how to spin a web.\n"); return; }
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
	if ($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}This room is protected from your race's webs.\n"); return; }
    if (!$self->{'WEBS'}) { $self->log_append("{1}Your mystical essence is far too drained to spin webs.\n"); return; }
    if (!$self->can_do(0, 0, 25)) { return; }
	
	
    if($self->{'ROOM'} == $who->{'ROOM'}){
		
	  	$who->{'TANGLED'}=$self->{'OBJID'};
	  	if($who->{'TANGLED'}){
		  	$who->log_append("{3}$self->{'NAME'} quickly spins a web around you.\n");
		  	$who->log_append("{3}You become tangled up within the $self->{'NAME'}.\n");
		  	$self->log_append("You quickly spin a web around $who->{'NAME'}.\n");
  			
  			# affect web-spinning gift.
   			 $self->gifts_affect('WEBSPIN');
   			 $self->{'WEBS'}--;
		}
	}
	
	
     return;
}

sub vrean_bite {
	my $self = shift;
 	if($self->{'BITES'} > 320){
		$self->{'BITES'} = 320;
	}
	# if i dont have the blinding skill, tell me and exit
    if(!$self->{'RACE'}==1) {
        $self->log_error('You have no idea how to bite others.');
        return 0;
    }
	if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
	foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
   		if ($o eq $self) { next; }
	   		if ( ($o->{'TYPE'}==1) || ($o->{'TYPE'}==2) ) {
     			next if $self->log_cant_aggress_against($o);
     			$self->note_attack_against($o); 
     		    if($self->{'RACE'} > 1){
	    			$self->log_append("You bite at $o->{'NAME'}, but they just look at you funny.\n"); 
	    			$o->log_append("$self->{'NAME'} tries to bite you, but just doesn\'t have the teeth to do any damage.\n");
    			}	
    			elsif( ($self->{'ROOM'} == $o->{'ROOM'}) && 
    				($self != $o) &&
					
					
					
    				($self->can_do(0,0,320-$self->{'BITES'}) )&&
    				(!$self->log_cant_aggress_against($o, 1)) ) {
			    	
						$self->log_append("You bite $o->{'NAME'} injecting them with a deadly poison.\n");
	   					$o->log_append("$self->{'NAME'} bites you injecting you with a deadly poison.\n");
    					if(!$o->{'NOSICK'}){
	    					$o->effect_add(71);
    						$o->{'FX'}->{71} = time + 15 + $self->{'BITES'}; # 4x as painful
    						$self->{'BITES'}++;
						}
				}
 			}
	
	
}
return;
}

sub intervention {
		my $self = shift;
	if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
	if($self->{'RACE'} != 5){ $self->log_error("You dont know how to call for Ker\'el."); return;}
	if(!$self->{'INTERVENE'}){	$self->log_error("Ker\'el refuses to answer your call again today."); return;}
	return 0 if(!$self->can_do(15, 0, 30));
	$self->room_sighttell("{13}Ker\'el appears from his throne as $self->{'NAME'} calls for him.\n");
	$self->log_append("{13}Ker\'el appears from his throne as you call for him.\n");
	foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
		if($o->{'SENT'}){next;}
		if($o->{'MONOLITH'}){next;}
		if($o->{'NOSICK'}){next;}
		if($o->{'TYPE'}!=2){next;}
		if($o->{'IMMORTAL'}){next;}
		$o->{'HP'} = -1;
		if($o->is_dead()) { $o->die($self); }
		
	}
	$self->{'INTERVENE'}--;
	$self->room_sighttell("{13}Ker\'el returns to his throne.\n");
	$self->log_append("{13}Ker\'el returns to his throne.\n");
return;
}

sub fly {
    my ($self) = shift;
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if (!$self->{'GIFT'}->{'FLITE'} && !$self->skill_has(9)) { 
        $self->room_sighttell("{13}$self->{'NAME'} frantically flaps $self->{'PPOS'} appendages in the air, as if $self->{'PRO'} were to take off into flight.\n");
        $self->log_error('You have no idea how to fly.');
        return 0;
    }

    if($self->{'RACE'}!=5){
    return 0 if(!$self->can_do(0, 0, 1));
	}
    
    if (defined($self->{'FX'}->{'7'})) {
        $self->log_error('You are already flying!');
        return 0;
    }

    $self->room_sighttell("{14}$self->{'NAME'}'s wings guide $self->{'PPRO'} into flight.\n"); 

    if($self->{'RACE'}==5){
    	if ($self->{'VIGOR'} <= 0.5) {
        	$self->{'VIGOR'} += 0.2;
    	}

    }

    $self->effect_add(7);
    $self->{'FX'}->{'7'} += int (($self->{'GIFT'}->{'FLITE'} || 60)/2);

    # affect flying gift.
    $self->gifts_affect('FLITE');
    return 1;
}

sub ventrilo {
	my ($self) = shift;
	if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if(!$self->{'GIFT'}->{'ROAR'}) { 
       $self->room_talktell("{13}$self->{'NAME'} roars with all $self->{'PPOS'} might.\n");
       $self->log_append("{1}Roar? You? Ha! Maybe at a circus!\n");
       return;
    }
    if(!$self->skill_has(88)) { 
       $self->room_talktell("{13}$self->{'NAME'} roars with all $self->{'PPOS'} might.\n");
       $self->log_append("{1}Throw your voice? You? Ha! Maybe at comedy hour!\n");
       return;
    }
    if($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}Your elders would be disgusted to find out you roared in here!\n"); return; }
    if(!$self->{'ROARS'}) { $self->log_error("You have a sore throat."); $self->log_hint("Try waiting until the next turn-gifting before roaring again."); return; }
    if($self->is_tired) { $self->log_append("{3}You are out of breath!\n"); return; }
    if(!$self->can_do(0, 0, 80)) { return; }
    
   ###DO IT HERE
   
    my @a = $main::map->[$self->{'ROOM'}]->rooms_adj();
	$self->log_append("{2}You fill the surrounding rooms with an {3}ear-piercing{2} roar.\n"); 
    foreach my $o (@a){
		if ($o->{'SAFE'}){next;}
    	$o->room_tell("{2}$self->{'NAME'} fills the room with an {3}ear-piercing{2} roar.\n");
    	
    	foreach my $p ($o->inv_objs) {
	    if ( ($p->{'TYPE'}==1) || ($p->{'TYPE'}==2) ) {
     	next if $self->cant_aggress_against($p, 1); # only affects players in range, unsafe rooms, etc 
	 
	 		# Log attack for pvp info
	 		$self->note_attack_against($p); 
     
     		#if ( ( (rand(100)<($self->{'GIFT'}->{'ROAR'} || 80)) && (rand(1)<$self->fuzz_pct_skill(0)) && !(defined($p->{'FX'}->{'25'})) ) || $self->got_lucky(20) ) 
     		if ( (rand($self->{'STAT'}->[0]) >rand($p->{'STAT'}->[0])) && !(defined($p->{'FX'}->{'25'})) )
     		{
       			if( (rand(1)<.8) && $p->aprl_rec_scan(803))
       			{
       				$p->log_append("{4}Your ears rumble with a dull sound.\n");
       			}
	   		elsif( (rand(1)<.8) && ($o->{'TYPE'}>=1 && !(defined($o->{'onDeath_RESPAWN'})) ))  
       		{ 
	       		; $p->effect_add(6); $p->{'FX'}->{'6'}=time + 10; $p->effects_register(); 
       		}
       		else 
       		{  
        		$p->{'ENTMSG'}='flees in';
        		$p->{'LEAMSG'}='flees out';
        		$p->ai_move( &rockobj::ai_suggest_move_random(undef, $main::map->[$p->{'ROOM'}]->exits_hash) );
        		delete $p->{'ENTMSG'};
        		delete $p->{'LEAMSG'};
       		}
     		} 
     		else 
     		{
       			$p->log_append("{4}You are unaffected.\n");
     		}
   		}
	}
    
	# don't reek havoc (har har) if i landed in a safe room
	
	}

    # affect gift info.
    $self->{'ROARS'}--;
    $self->gifts_affect('ROAR');
    $self->make_tired();
    return;
	
}

sub roar {
    my ($self) = shift;
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if(!$self->{'GIFT'}->{'ROAR'} && !$self->skill_has(11)) { 
       $self->room_talktell("{13}$self->{'NAME'} roars with all $self->{'PPOS'} might.\n");
       $self->log_append("{1}Roar? You? Ha! Maybe at a circus!\n");
       return;
    }
    if($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}Your elders would be disgusted to find out you roared in here!\n"); return; }
    if(!$self->{'ROARS'}) { $self->log_error("You have a sore throat."); $self->log_hint("Try waiting until the next turn-gifting before roaring again."); return; }
    if($self->is_tired) { $self->log_append("{3}You are out of breath!\n"); return; }
    if(!$self->can_do(0, 0, 80)) { return; }
    $self->log_append("{2}You fill the room with an {3}ear-piercing{2} roar.\n"); 
    $self->room_tell("{2}$self->{'NAME'} fills the room with an {3}ear-piercing{2} roar.\n"); 
    $self->spell_hfear();

    # affect gift info.
    $self->{'ROARS'}--;
    $self->gifts_affect('ROAR');
    $self->make_tired();
    return;
}

sub spell_hfear {
 my $self = shift;
 
 foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
   if ($o eq $self) { next; }
   if ( ($o->{'TYPE'}==1) || ($o->{'TYPE'}==2) ) {
     next if $self->log_cant_aggress_against($o);
	 
	 # Log attack for pvp info
	 $self->note_attack_against($o); 
     
     #if ( ( (rand(100)<($self->{'GIFT'}->{'ROAR'} || 80)) && (rand(1)<$self->fuzz_pct_skill(0)) && !(defined($o->{'FX'}->{'25'})) ) || $self->got_lucky(20) ) 
     if ( (rand($self->{'STAT'}->[0]) >rand($o->{'STAT'}->[0])) && !(defined($o->{'FX'}->{'25'})) )
     {
       if( (rand(1)<.8) && $o->aprl_rec_scan(803))
       {
       	$o->log_append("{4}Your ears rumble with a dull sound.\n");
       }
	   elsif( (rand(1)<.8) && ($o->{'TYPE'}>=1 && !(defined($o->{'onDeath_RESPAWN'})) )) 
       { 
	       ; $o->effect_add(6); $o->{'FX'}->{'6'}=time + 10; $o->effects_register(); 
       }
       else 
       {  

        $o->{'ENTMSG'}='flees in';
        $o->{'LEAMSG'}='flees out';
        for(my $n=int rand(2)+1; $n<4; $n++) 
        {


           $o->ai_move( &rockobj::ai_suggest_move_random(undef, $main::map->[$o->{'ROOM'}]->exits_hash) );
        }
        delete $o->{'ENTMSG'};
        delete $o->{'LEAMSG'};
       }
     } 
     else 
     {
       $o->log_append("{4}You are unaffected.\n");
     }
   }
 }
 return;
}

sub spectrite_teleport (to user) {
    my ($self, $uid) = @_;
    $uid = lc($uid);
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }

    if(!$self->{'GIFT'}->{'TELEPORT'} && !$self->skill_has(12) ) {
        $self->log_append("{2}Teleport? Me?\n");
        return 0;
    }
    
    if(!$uid) {
        $self->log_append("{2}Format: {7}teleport {17}<user> {4}(teleports to that user)\n");
        return 0;
    }





    if((time - $self->{'LASTTPORT'} < 200 ) && !$self->skill_has(74) )  {
        $self->log_error('You are too worn out to teleport again.');
        return 0;
    }

    if($self->{'HP'} != $self->{'MAXH'}) {
        $self->log_error("You aren't healthy enough to even consider doing so.");
        return 0;
    }
    
    my $o = $self->uid_resolve($uid) or return 0;

    #if($main::map->[$o->{'ROOM'}]->{'M'} != $main::map->[$self->{'ROOM'}]->{'M'}) { $self->log_append("{7}$uid\'s {14}frequency fluctuates at a different plane.\n"); return; }

    if($o->{'RACE'} != $self->{'RACE'}) {
        $self->log_error("$uid\'s race is not a $main::races[$self->{'RACE'}].");
        return 0;
    }

    if($o eq $self) {
        $self->log_error('Teleport to yourself? Interesting concept.');
        return 0;
    }

    if($o->{'LEV'} >= $self->{'LEV'}) {
        $self->log_error('You can only teleport to beings of the same level or lower than yours.');
        return;
    }

    #if($o->{'LEV'} < 45) { $self->log_append("{3}$o->{'NAME'} is not powerful enough to for you to pinpoint a location.\n"); return; }

    if($o->is_developer() && !$self->{'ADMIN'}) {
        $self->log_error("A certain creative force prevents you from teleporting to $o->{'NAME'}.");
        return;
    }

    if($main::map->[$self->{'ROOM'}]->{'!TPORT'} || $main::map->[$self->{'ROOM'}]->inv_has_rec(306)) {
        $self->log_error('A peculiar force prevents you from teleporting from this room.');
        return 0;
    }

    if($main::map->[$o->{'ROOM'}]->{'!TPORT'} || $main::map->[$o->{'ROOM'}]->inv_has_rec(306)) {
        $self->log_append("A peculiar force prevents you from teleporting to that room.\n");
        return 0;
    }

    my $hplost = int $self->{'MAXH'} * (.7 - (rand($self->{'GIFT'}->{'TELEPORT'}/100)) + rand(.3));
    my $turnlost = int rand(30)+50;
    if($self->skill_has(74)){ $hplost = 0;  }
    if($self->skill_has(74)){ $turnlost = $turnlost/2;}
    return 0 if(!$self->can_do(0,$hplost, $turnlost));
    $self->teleport($o);
    $self->{'LASTTPORT'}=time;
    $self->gifts_affect('TELEPORT');
    return 1;
}
sub spectrite_relocate_dir {
  # returns array of adjacent room objects
  my $self = shift;
  my $relocatedir = shift;
  if($self->skill_has(74) ){
	 
	if($self->{'HP'} < $self->{'MAXH'}){
		$self->log_error("You do not have enough health to shift in that direction.");
		return;}
	if($self->{'MA'} < $self->{'MAXM'}){
		$self->log_error("You do not have enough mana to shift in that direction.");
		return;}
	
	if($main::map->[$self->{'ROOM'}]->{'!TPORT'} || $main::map->[$self->{'ROOM'}]->inv_has_rec(306)) {
        $self->log_error('A peculiar force prevents you from teleporting from this room.');
        return 0;
    }

    $relocatedir = uc($relocatedir);
  
  	if (length($relocatedir)>2){
	  	$self->log_error("Please use the short form of directions\nsyntax << shift ne >>");
	  	return;}
  	if (length($relocatedir) == 0){
	  	$self->log_error("Please include a direction.\n syntax << shift ne >>");
	  	return;
	  	}
	  
  	my $dir;
	  
  	$dir = $relocatedir;
	  
  	if($main::map->[$self->{'ROOM'}]->{'EXITS'}) { 
	  	
		my $room = $main::map->[$self->{'ROOM'}]->{'ROOM'};
		
    	if( ($main::map->[$self->{'ROOM'}]->{$dir}->[0] > 0) && !$main::map->[$self->{'ROOM'}]->{$dir}->[1])
        	{ 
	        	
	     		   	$room = $main::map->[$self->{'ROOM'}]->{$dir}->[0];
	     		   	
	     		   	#if($main::map->[$room]->{'ITEMSPAWN'}){
		     		#   	$self->log_error("You can not shift into this room");
		     		#333   	return;}
	     	
		     		my $manalost = int($self->{'MAXM'});
	     		   	my $hplost = int $self->{'MAXH'} * (.7 - (rand($self->{'GIFT'}->{'TELEPORT'}/100)) + rand(.3));
    				my $turnlost = int rand(30)+100;
    				if($self->skill_has(74)){ $hplost = 0;  }
    				if($self->skill_has(74)){ $turnlost = $turnlost/2;}
    				return 0 if(!$self->can_do($manalost,$hplost, $turnlost));
	     		   	$self->teleport($room);
  					return;
        	
	        }
		}
  
	}
	else {$self->log_error("You do not yet know how to shift your body matter like that.");}
}
sub spectrite_relocate (to user) {
    my ($self, $place) = @_;
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if($self->{'RACE'} != 2) {
	   $self->room_talktell("{13}$self->{'NAME'} try's to relocate their body, but all they can do is walk to a new room.\n");
       $self->log_append("{1}You relocate yourself? Maybe if you walk there.\n");
	    return;
	    }
   
    if(!$self->{'GIFT'}->{'TELEPORT'} && !$self->skill_has(12) ) {
        $self->log_append("{2}Relocate? Me?\n");
        return 0;
    }
    
		if($self->{'MA'} < 1){
		$self->log_error("You do not have enough mana to relocate, must have at least 1 mana.");
		return;}
	
	
    if($main::map->[$self->{'ROOM'}]->{'!TPORT'} || $main::map->[$self->{'ROOM'}]->inv_has_rec(306)) {
        $self->log_error('A peculiar force prevents you from teleporting from this room.');
        return 0;
    }

    if(!$place) {
        $self->log_append("\n{2}Format: {7}relocate {17}1 - 8 {4}(relocates to room of choosing)\n");
        $self->log_append("{7}1(nexus) - {17}Nexus\n");
        $self->log_append("{7}2(westland) - {17}Westland\n");
        if($self->{'LEV'} <= 30) {$self->log_append("{7}3 - {17}?????\n");} else {$self->log_append("{7}3(vexia) - {17}Vexian Dock\n");}
        if($self->{'LEV'} <= 30) {$self->log_append("{7}4 - {17}?????\n");} else {$self->log_append("{7}4(tundra) - {17}Troitian Base\n");}
        if($self->{'LEV'} <= 50) {$self->log_append("{7}5 - {17}?????\n");} else {$self->log_append("{7}5(crater) - {17}Deep Crater, Hole\n");}
        if($self->{'LEV'} <= 30) {$self->log_append("{7}6 - {17}?????\n");} else {$self->log_append("{7}6(hell) - {17}Hell, Blood Panel\n");}
        if($self->{'LEV'} <= 30) {$self->log_append("{7}7 - {17}?????\n");} else {$self->log_append("{7}7(grumbar) - {17}Mount Grumbar\n");}
        if($self->{'LEV'} <= 100) {$self->log_append("{7}8 - {17}?????\n");} else {$self->log_append("{7}8(azrals) - {17}Travelled Path, Before a Large Bone-White Wall\n");}
        
        return 0;
    }

    if((time - $self->{'LASTTPORT'} < 200 ) && !$self->skill_has(74) )  {
        $self->log_error('You are too worn out to teleport again.');
        return 0;
    }

    if($self->{'HP'} != $self->{'MAXH'}) {
        $self->log_error("You aren't healthy enough to even consider doing so.");
        return 0;
    }

    my $hplost = int $self->{'MAXH'} * (.7 - (rand($self->{'GIFT'}->{'TELEPORT'}/100)) + rand(.3));
    my $turnlost = int rand(30)+50;
    if($self->skill_has(74)){ $hplost = 0;  }
    if($self->skill_has(74)){ $turnlost = $turnlost/2;}
    return 0 if(!$self->can_do(0,$hplost, $turnlost));
    $self->{'LASTTPORT'}=time;
    $self->gifts_affect('TELEPORT');
     
   if(($place == 1) || ($place eq "nexus") ) {$self->teleport($main::roomaliases{'managath'}); return;}
   if(($place == 2) || ($place eq "westland")) {$self->teleport($main::roomaliases{'westland-stone-monument'}); $self->effect_add(6); return;} # westland
   if((($place == 3) || ($place eq "vexia")) && $self->{'LEV'} > 30 ) {$self->teleport($main::roomaliases{'vexia_near_a_dock'}); $self->effect_add(6);  return;} # southland
   if((($place == 4) || ($place eq "tundra"))&& $self->{'LEV'} > 30 ) {$self->teleport($main::roomaliases{'escape_hatch'}); $self->effect_add(6); return;} # tundrabase
   if((($place == 5)|| ($place eq "crater"))&& $self->{'LEV'} > 50 ) {$self->teleport($main::roomaliases{'deep_crater_hole'}); $self->effect_add(6); return;} # crater
   if((($place == 6) || ($place eq "hell"))&& $self->{'LEV'} > 30 ) {$self->teleport($main::roomaliases{'blood_panel'}); $self->effect_add(6); return;} # hell
   if((($place == 7) || ($place eq "grumbar"))&& $self->{'LEV'} > 30 ) {$self->teleport($main::roomaliases{'grumbar'}); $self->effect_add(6); return;} # grumbar
   if((($place == 8) || ($place eq "azrals"))&& $self->{'LEV'} > 100 ) {$self->teleport($main::roomaliases{'western_wall'}); $self->effect_add(6); return;} # azral wall
   
   #elsif($place == 'nexus') {$self->teleport($main::roomaliases{'managath'}); return;}
	#$self->teleport($main::roomaliases{$place});
}

sub teleport (to room/obj) {
    my ($self, $to, $quiet) = @_;
    if(!ref($to)) { $to = $main::map->[$to]; if(!$to) { $self->log_append("{6}Invalid {16}to {6}argument.\n"); return(0); } }
    if(!$self->is_invis() && !$quiet) { 
        $self->room_sighttell('{6}'.($self->{'NICK'} || $self->{'NAME'})."'s {16}shadow warps into a fiery yellow sphere and disappears, taking {6}$self->{'NAME'} {16}with it.\n");
    }
    if(!$quiet) { 
        $self->log_append("{6}Your {16}shadow warps into a fiery yellow sphere and disappears, taking {6}you {16}with it.\n");
    }
    delete $self->{'FRM'};
    $self->realm_hmove($self->{'ROOM'}, $to->{'ROOM'}, undef, 0);
    if(!$self->is_invis() && !$quiet) {
        $self->room_sighttell('{6}A fiery yellow sphere disperses into a fine mist, only to reveal {16}'.($self->{'NICK'} || $self->{'NAME'}).".\n");
    }
    return;
}


sub user_change_race {
  my ($self, $race) = @_;
  if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }

  # stop them from changing multiple times
  if($self->{'LEV'} > 45){ $self->log_error("{17}Ahh, but your level is to high to change your race! (LEVEL 45)"); return; }
  #if($self->quest_has(1)) { $self->log_error("{17}Ahh, but you already changed your race!"); return; }
  
  my %valid_race = ('vrean', 1, 'spectrite', 2, 'dryne', 3, 'taer', 4, 'shi-kul', 5, 'kelion', 6);
  
  $race = lc($race);

  # No turn-changing while in the arena!
  if ($self->{'GAME'}) {
      $self->log_error("You cannot change your race while in the arena.");
      return;
  }

  if(!defined($valid_race{$race})) { $self->log_append("{17}Sorry, you can't change to that race. The only valid races are {2}".join(', ', keys(%valid_race))."{17}.\n"); return; }
  elsif($valid_race{$race}==$self->{'RACE'}) { $self->log_append("{1}But you're already that race!\n"); return; }
  #elsif($self->{'GENERAL'}) { $self->log_append("{1}Sorry, but we don't want generals to change races. If you're still set on changing your race, write rocksupport and we'll see what we can do.\n"); return; }
  else {
	  $_[0]->delete_all_votes_for_general($self);
      $race = $valid_race{$race};
      &main::rock_shout(undef, "{17}$self->{'NAME'} {2}has changed $self->{'PPOS'} biology from $main::races[$self->{'RACE'}] to $main::races[$race].\n");
      $self->{'RACE'}=$race;
      $self->skills_racial_fix();
      $self->quest_add(1);
	  $self->stats_allto(10);
	  $self->{'SOLDIER'} = 0;
	  delete $self->{'QUEST'};
	  delete $self->{'NEWTURNS'};
	  delete $self->{'CHIST'};
	  delete $self->{'KILLREC'};
	  delete $self->{'@SKIL'};
	  $self->log_append("Re-log for new turns.\n");
	  
	  
  }
  return;
}

sub plague_make_room {
    my ($self) = shift;
    if ($self->{'GAME'}){$self->log_error("You can not use racial skills in an arena."); return; }
    if(!$self->{'RACE'}==4){$self->log_append("You hack and cough but nothing happens.\n"); return;}
    if($self->{'PLAGUE'}< 1){$self->log_append("Your not feeling sick enough to spread the plague.\n"); return;}
    if($self->{'SALP'}<100){$self->log_append("Your not feeling sick enough to spread the plague.\n"); return;}
    if ($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}This room is protected from your race's disease.\n"); return; }
    if (!$self->can_do(0, 0, 25)) { return; }
    $self->log_append("You spread the plague into the room.\n");
    $self->room_sighttell("$self->{'NAME'} spreads the plague in $main::map->[$self->{'ROOM'}]->{'NAME'}.\n"); 
	$self->{'PLAGUED'}++;
    my $plague = plague->new('NAME', 'plague of '.lc($self->{'NAME'}), 'CATCHFUZ', ({'PLAGUED'}*.5), 'CROBJID', $self->{'OBJID'}, 'RACE', $self->{'RACE'}, 'PLAGUED', $self->{'PLAGUED'}, 'ROT', int(  time+30+$self->{'PLAGUED'} ) );

    # alter stickyfuz
    #if ($self->skill_has(28) && (rand(1) < $self->fuzz_pct_skill(6, 70))) { $web->{'STICKYFUZ'}+=.3; if($web->{'STICKYFUZ'} > .95) { $web->{'STICKYFUZ'}=.95; } }

    # make invis 
    #if ($self->skill_has(29) && (rand(1) < $self->fuzz_pct_skill(6, 100))) { $web->{'INVIS'}=1; }

    # add web to room
    $main::map->[$self->{'ROOM'}]->inv_add($plague);
 	$self->{'SALP'}=0;
 	$self->{'PLAGUE'}--;
    
    # affect web-spinning gift.
     return;
}
1;
