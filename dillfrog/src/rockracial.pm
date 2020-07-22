package rockobj;
use strict;

sub web_spin {
    my ($self) = shift;
    if (!$self->{'GIFT'}->{'WEBSPIN'} && !$self->skill_has(10)) { $self->log_append("{1}You have no idea how to spin a web.\n"); return; }
    if ($main::map->[$self->{'ROOM'}]->{'SAFE'}) { $self->log_append("{3}This room is protected from your race's webs.\n"); return; }
    if (!$self->{'WEBS'}) { $self->log_append("{1}Your mystical essence is far too drained to spin webs.\n"); return; }
    if (!$self->can_do(0, 0, 25)) { return; }

    $self->log_append("You spin the web.\n");
    $self->room_sighttell("$self->{'NAME'} spins an intricate web in $main::map->[$self->{'ROOM'}]->{'NAME'}.\n"); 

    my $web = web->new('NAME', 'web of '.lc($self->{'NAME'}), 'CATCHFUZ', .0075*($self->{'GIFT'}->{'WEBSPIN'} || 60), 'CATCHFUZ', .0095*($self->{'GIFT'}->{'WEBSPIN'}||60), 'CROBJID', $self->{'OBJID'}, 'RACE', $self->{'RACE'}, 'ROT', int(  time+30+($self->{'GIFT'}->{'WEBSPIN'}||60)+75*$self->skill_has(27) ) );

    # alter stickyfuz
    if ($self->skill_has(28) && (rand(1) < $self->fuzz_pct_skill(6, 70))) { $web->{'STICKYFUZ'}+=.2; if($web->{'STICKYFUZ'} > .95) { $web->{'STICKYFUZ'}=.95; } }

    # make invis 
    if ($self->skill_has(29) && (rand(1) < $self->fuzz_pct_skill(6, 100))) { $web->{'INVIS'}=1; }

    # add web to room
    $main::map->[$self->{'ROOM'}]->inv_add($web);
 
    # affect web-spinning gift.
    $self->gifts_affect('WEBSPIN');
    $self->{'WEBS'}--;
     return;
}

sub fly {
    my ($self) = shift;
    if (!$self->{'GIFT'}->{'FLITE'} && !$self->skill_has(9)) { 
        $self->room_sighttell("{13}$self->{'NAME'} frantically flaps $self->{'PPOS'} appendages in the air, as if $self->{'PRO'} were to take off into flight.\n");
        $self->log_error('You have no idea how to fly.');
        return 0;
    }

    return 0 if(!$self->can_do(0, 0, 20));
    
    if (defined($self->{'FX'}->{'7'})) {
        $self->log_error('You are already flying!');
        return 0;
    }

    $self->room_sighttell("{14}$self->{'NAME'}'s wings guide $self->{'PPRO'} into flight.\n"); 

    if ($self->{'VIGOR'} < 0.5) {
        $self->{'VIGOR'} += 0.1;
        $self->{'VIGOR'} = 0.5 if($self->{'VIGOR'} > 0.5);
    }

    $self->effect_add(7);
    $self->{'FX'}->{'7'} += int (($self->{'GIFT'}->{'FLITE'} || 60)/2);

    # affect flying gift.
    $self->gifts_affect('FLITE');
    return 1;
}

sub roar {
    my ($self) = shift;
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
     
     if ( ( (rand(100)<($self->{'GIFT'}->{'ROAR'} || 70)) && (rand(1)<$self->fuzz_pct_skill(2)) && !(defined($o->{'FX'}->{'25'})) ) || $self->got_lucky(20) ) {
       if( (rand(1)<.5) && ($o->{'TYPE'}==1) ) { $o->room_sighttell("{3}$o->{'NAME'} {4}stiffens into a paralyzed state.\n"); $o->effect_add(6); $o->{'FX'}->{'6'}=time + 10; $o->effects_register(); }
       else {  
        $o->{'ENTMSG'}='flees in';
        $o->{'LEAMSG'}='flees out';
        for(my $n=int rand(2)+1; $n<4; $n++) {

           $o->ai_move( &rockobj::ai_suggest_move_random(undef, $main::map->[$o->{'ROOM'}]->exits_hash) );
        }
        delete $o->{'ENTMSG'};
        delete $o->{'LEAMSG'};
       }
     } else {
       $o->log_append("{4}You are unaffected.\n");
     }
   }
 }
 return;
}
sub spectrite_teleport (to user) {
    my ($self, $uid) = @_;
    $uid = lc($uid);
    
    if(!$self->{'GIFT'}->{'TELEPORT'} && !$self->skill_has(12) ) {
        $self->log_append("{2}Teleport? Me?\n");
        return 0;
    }
    
    if(!$uid) {
        $self->log_append("{2}Format: {7}teleport {17}<user> {4}(teleports to that user)\n");
        return 0;
    }

    #mich - it was checking for turns twice, moved msg
    #if($self->{'T'} < 80) { $self->log_append("{2}You haven't enough turns to even consider doing so.\n"); return; }
    #end mich

    if((time - $self->{'LASTTPORT'}) < 200) {
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

    if($o->{'LEV'} > $self->{'LEV'}) {
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

    return 0 if(!$self->can_do(0,int $self->{'MAXH'} * (.7 - (rand($self->{'GIFT'}->{'TELEPORT'}/100)) + rand(.3)), int rand(30)+50));
    $self->teleport($o);
    $self->{'LASTTPORT'}=time;
    $self->gifts_affect('TELEPORT');
    return 1;
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
  
  # stop them from changing multiple times
  if($self->quest_has(1)) { $self->log_error("{17}Ahh, but you already changed your race!"); return; }
  
  my %valid_race = ('vrean', 1, 'spectrite', 2, 'dryne', 3, 'taer', 4, 'shi-kul', 5);
  
  $race = lc($race);

  # No turn-changing while in the arena!
  if ($self->{'GAME'}) {
      $self->log_error("You cannot change your race while in the arena.");
      return;
  }

  if(!defined($valid_race{$race})) { $self->log_append("{17}Sorry, you can't change to that race. The only valid races are {2}".join(', ', keys(%valid_race))."{17}.\n"); return; }
  elsif($valid_race{$race}==$self->{'RACE'}) { $self->log_append("{1}But you're already that race!\n"); return; }
  elsif($self->{'GENERAL'}) { $self->log_append("{1}Sorry, but we don't want generals to change races. If you're still set on changing your race, write rocksupport and we'll see what we can do.\n"); return; }
  else {
      $race = $valid_race{$race};
      &main::rock_shout(undef, "{17}$self->{'NAME'} {2}has changed $self->{'PPOS'} biology from $main::races[$self->{'RACE'}] to $main::races[$race].\n");
      $self->{'RACE'}=$race;
      $self->skills_racial_fix();
      $self->quest_add(1);
  }
  return;
}
1;
