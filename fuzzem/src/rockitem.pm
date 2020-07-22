use strict;


package item;
@item::ISA = qw( rockobj );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  return($self);
}

package item_portal_monitor;
@item_portal_monitor::ISA = qw (item);
use strict;

# evalll %main::roomaliases = (); map { $main::roomaliases{lc($_->{'RALIAS'})} = $_->{'ROOM'} } @$main::map;

sub desc_get {
	my ($self, $who) = @_;
    
    my $desc = "";
    $desc .= "{12}Through the portal monitor, you see:\n";
    
    foreach my $room (map { $main::map->[$main::roomaliases{$_}] } qw (war_pit_inside_green_portal war_pit_inside_red_portal war_pit_inside_blue_portal)) {
        my $peeps = join(', ', map { $_->{'NAME'} } $room->inv_pobjs()) || "nobody is there";
        $desc .= sprintf("{16}%23s: {6}%s.\n", $room->{'NAME'}, $peeps);
    }
    return $desc;
}


package cryl;
@cryl::ISA = qw( item );
use strict;

sub on_take {
  my ($self, $taker) = @_;
  $taker->{'CRYL'} += $self->{'CRYL'};
  delete $self->{'CRYL'};
  $self->obj_dissolve();
}

package treasure_chest;
@treasure_chest::ISA = qw( item );
use strict;
use rand_dist;

$treasure_chest::treasureDist[0] =
new rand_dist(2 => 389, 3 => 524, 5 => 535, 30 => 387, 8 => 390, 4 => 388, 1 => 135, 5 => 347, 10 => 395, 10 => 396, 10 => 394, 10 => 393, 6 => 392, 2 => 337, 1 => 287, 4 => 54, 5 => 2);

$treasure_chest::treasureDist[1] =
new rand_dist(4 => 547, 2 => 548, 2 => 545, 2 => 546);

$treasure_chest::treasureDist[2] =
new rand_dist(4 => 547, 2 => 564, 2 => 581, 2 => 685,  2 => 199);

$treasure_chest::treasureDist[3] =
new rand_dist(1 => 47, 2 => 55, 2 => 144, 2 => 145, 1 => 301, 5 => 302, 1 => 312, 2 => 337, 1 => 338, 3 => 347, 25 => 388, 5 => 392, 2 => 535, 10 => 579, 1 => 587, 1 => 585, 4 => 633, 5 => 634, 25 => 88, 10 => 898);

$treasure_chest::treasureDist[4] =
new rand_dist(1 => 587, 1 => 585, 1 => 381, 1 => 338, 1 => 148, 1 => 547, 1 => 135, 1 => 380, 1 => 146, 1 => 564, 1 => 540, 1 => 301);

$treasure_chest::treasureDist[5] =
new rand_dist(7 => 1111, 6 => 1110, 5 => 1109, 4 => 1108, 3 => 1107, 2 => 1106, 1 => 1105, 1 => 1104);

$treasure_chest::treasureDist[6] =
new rand_dist(1 => 381, 2 => 547, 2 => 146, 4 => 56, 4 => 579, 2 => 524);

$treasure_chest::treasureDist[7] = 
new rand_dist(1 => 1307, 1 =>  1308, 1 => 1311, 1 =>  1314, 1 =>  1317, 1 => 1320, 1 => 1323, 1 => 1326, 1 =>  1329, 1 => 1335, 1 => 1338, 1 => 1341, 1 => 1344, 1 => 1347, 1 => 1350);

sub on_open {
  my ($self, $opener) = @_;
  my $i = $main::objs->{$self->{'CONTAINEDBY'}}->item_spawn(scalar $treasure_chest::treasureDist[$self->{'TREASURE'}]->choose());
  #my $i = $main::objs->{$self->{'CONTAINEDBY'}}
  #my $i = $opener->item_spawn(scalar $treasure_chest::treasureDist[$self->{'TREASURE'}]->choose());
  $opener->room_sighttell("{14}$opener->{'NAME'} opens $self->{'NAME'}, which disintegrates to reveal $i->{'NAME'}.\n");
  $opener->log_append("{14}You open $self->{'NAME'}, which disintegrates to reveal $i->{'NAME'}.\n");
  $self->obj_dissolve();
  if($self->{'TREASURE'}==4){
	  $opener->{'TOTAL_TREASURES'}++;
	  #$i->{'REC'} = 933;
	  
	   my $c = sprintf("{17}$opener->{'NAME'} {2}found a {17}$self->{'NAME'} {2}for a total of {11}$opener->{'TOTAL_TREASURES'} $self->{'NAME'}.\n", $_[1]) ; 
	   &main::rock_shout(undef, $c);
  }
}

package spawn_mugg_raiders;
@spawn_mugg_raiders::ISA = qw( item );
use strict;
use rand_dist;


sub on_room_enter (objects: enterer; string: fromdir, observation) {
    my ($self, $who, $dir) = @_;
    
    return if $who->{'TYPE'} != 1;
    
    # mugg raiders
    my $room = $main::objs->{$self->{'CONTAINEDBY'}};
    my @npcs;
    
    
    if( .05 > rand 1 ) { push(@npcs, $room->item_spawn(461)); }  # gu-nug
    if( .5  > rand 1 ) { push(@npcs, $room->item_spawn(462)); }  # mugg shaman
    if( .5  > rand 1 ) { push(@npcs, $room->item_spawn(463)); }  # mugg chief
    
    my $r;   # raider count
    $r = 1 + int rand 3; for(my $i=0; $i<$r; $i++) { push(@npcs, $room->item_spawn(459)); }  # dire wolves
    $r = 2 + int rand 5; for(my $i=0; $i<$r; $i++) { push(@npcs, $room->item_spawn(460)); }  # raiders
    
    $self->room_sighttell("{2}A hoard of Muggs and their allies charge out from behind a nearby hill!\n");
    foreach my $obj (@npcs) {
	    next unless $obj; # we might have reached our limit
        $main::eventman->enqueue(3*60 + int rand(120), \&rockobj::wander_off, $obj); # die eventually
        if(rand(1) < .4) { $obj->{'STALKING'} = $who->{'OBJID'}; }
        $obj->attack_player($who, 1); # charge!
    }
    
    $self->obj_dissolve();
    return;
}


package exp_reducing_bottle;
@exp_reducing_bottle::ISA = qw( item );
use strict;

sub on_digest {
    my ($self, $who) = @_;
	$who->log_append("{3}<<  You feel smaller -- and no cake will save you!  >>\n");
	$who->delay_say(3, "What a curious feeling!");
	$who->delay_say(5, "I must be shutting up like a telescope!");
	while($who->{'LEV'} > 45) { $who->stats_update(); for (my $n=6; $n<=22; $n++) { $who->{'EXP'}->[$n] *= .98; } }
	$who->{'EXPPHY'} = 0;
	$who->{'EXPMEN'} = 0;
}


package ebon_wand;
@ebon_wand::ISA = qw( item );
use strict;

sub on_use_on {
    my ($self, $who, $on_what) = @_;

}

package fear_horn;
@fear_horn::ISA = qw( item );
use strict;

sub on_blow {
    my $self = shift;
    my $victim = shift;
    return unless $victim->can_do(0,0,0); # make sure they can even blow it
    if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
    $victim->room_talktell("{3}A blasting roar echoes from within $victim->{'NAME'}\'s $self->{'NAME'}!\n");
    $victim->log_append("{3}A blasting roar echoes from within the horn!\n");
    $victim->spell_hfear();
    $self->{'USES'}--;
    return;
}

sub on_use { &on_blow(@_); }

package skill_book;
@skill_book::ISA = qw( item );
@flesh_book::ISA = qw( skill_book );
use strict;

sub on_read {
    my $self = shift;
    my $reader = shift;
    if(ref($self) eq 'flesh_book') {
        $reader->log_append("{1}Error: outdated item. Try again.\n"); $reader->item_spawn($self->{'REC'}); $self->dissolve_allsubs();
    }
    
    unless ( $self->has_minstats($self->{'READ_MINSTATS'}) ) {
        $reader->log_append("{1}It looks like a bunch of complex, incomprehensible garble to you.\n");
    }

    my $skill_num = $self->{'READ_SKILL'};
    if(!defined $skill_num || $skill_num ne int(abs($skill_num))) {
       $reader->log_append("{13}Error: undefined or malformed bank/skillnum. Sending notice to support mailbox.\n");
       if(!$self->{'ERRORED'}++) {
           &main::mail_send($main::rock_admin_email, "R2: AutoBUG! (By: $self->{'NAME'}\. Reimburse: $reader->{'NAME'})", "I didn't have a valid skill number ('$self->{'READ_SKILL'}\') attached to me. My item creation record number is $self->{'REC'}. Please fix me ... and don't forget to reimburse $reader->{'NAME'} either! I love you!\n\n\n- ROCK\n");
       }
       return;
    } else {
       if($reader->skill_has($skill_num)) { $reader->log_append("{1}Hmm..it looks like a rerun to you!\n"); return; }
       $reader->room_sighttell("{3}$reader->{'NAME'} reads $self->{'NAME'}, which immediately decomposes!\n");
       $reader->log_append("{3}You read $self->{'NAME'}, which immediately decomposes!\n");
       $reader->log_append("{16}You have attained the skill, \"{6}$main::skillinfo[$skill_num]->[0]\{16}\"\n");
       $reader->skill_add($skill_num);
    }
    $self->obj_dissolve();
    return;
}

sub on_use { &on_read(@_); }

package item_touch_teleport;
@item_touch_teleport::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $by) = @_;
  if(!$self->{'TELEPORT_ROOM'}) { $self->say("Error: no TELEPORT_ROOM defined."); return; }
  $by->room_sighttell("{17}$by->{'NAME'} quickly moves over to...\n");
  $by->teleport($self->{'TELEPORT_ROOM'});
}

package flash_optics;
@flash_optics::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $by) = @_;
  if($main::map->[$by->{'ROOM'}]->{'SAFE'}) { $by->log_append("{17}In a safe room?!\n"); return; }
  if(!$by->can_do(0,0,15)) { return; }
  $by->log_append("{17}You touch $self->{'NAME'}\'s {2}activation pad{17}.\n");
  $self->optics_explode();
}

sub on_activate { &on_touch(@_); }
sub on_use { &on_touch(@_); }

sub optics_explode {
  my $self = shift;
  $self->room_sighttell("{14}$self->{'NAME'} {5}emits blinding ultraviolet radiation throughout the room.\n");
  foreach my $obj ($main::map->[$self->{'ROOM'}]->inv_objs()) {
      if( 
          ($obj->{'TYPE'}==2 && (rand(1) < .05)) ||
          ($obj->{'TYPE'}==1)
        ) {
        
          if(defined($obj->{'FX'}->{'22'})) { }
          elsif(my $i = $obj->aprl_rec_scan(349)) { $obj->log_append("{17}Your $i->{'NAME'} shield you from the burst.\n"); }
          else { $obj->effect_add(22); }
         
      }
  }
  $self->obj_dissolve();
}

package item_magnetic;
@item_magnetic::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $by) = @_;
  if(!$by->can_do(0,0,10)) { return; }
  $by->log_append("{17}You wrap your hands around $self->{'NAME'} and begin fiddling with it.\n");
  
  if(rand(1) < $by->fuzz_pct_skill(6, 300)) {
    $self->{'AI'}->{'LIFTABLE'} ^= 1;
    if(!$self->{'AI'}->{'LIFTABLE'}) { 
        $self->room_sighttell("{7}$self->{'NAME'} {17}begins radiating an {3}electromagnetic {13}light{17}, which rapidly decreases to a low, undetectable frequency.\n");  
    } else {
        $self->room_sighttell("{7}$self->{'NAME'}\'s {17}radiation frequency increases to a bright {5}violet light{17}, and suddenly {1}stops{17}.\n");  
    }
  } else {
    $self->user_shock($by);
  }
  return;
}
#sub on_use { &on_touch(@_); }
sub on_open {
  my ($self, $by) = @_;
  		if($self->{'USES'}){
  		#$self->room_sighttell("{2}$uid->{'NAME'} is wisked away.\n");
  		$self->room_sighttell("{16}$by->{'NAME'} uses the $self->{'NAME'} and vanishes out of sight.\n");
  		$by->teleport($main::roomaliases{'managath'});
  		$self->{'USES'}--;
  		return;
		}
  }
sub user_shock {
  my ($self, $victim) = @_;
  if($victim->is_dead()) { return; }
  
  $victim->room_sighttell("{17}$victim->{'NAME'}\'s body is {2}bolted to the ground {17}as {13}sparks {17}size of cryoworks {1}zip through $victim->{'PPRO'}\{17}.\n");
  $victim->log_append("{17}Your body becomes {2}bolted to the ground {17}as {13}sparks {17}the size of cryoworks {1}zip through you{17}.\n");
  $victim->{'HP'} -= int ( (1-$victim->fuzz_pct_skill(6, 300))*$victim->{'MAXH'} );
  if($victim->is_dead()) { $victim->die($self); }
  
  return;
}

sub can_be_lifted {
  my ($self, $who, $passive) = @_;
  if($self->{'AI'}->{'LIFTABLE'}) { return(1); }
  elsif($who->{'TYPE'} != 1) { return(0); }
  elsif(!$passive) { $self->user_shock($who); }
  return 0;
}

package pressure_pad;
@pressure_pad::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  # types 1-4 (PADSTR = 1..4) are 25, 50, 75, 100% damage, based on victim's hp
  if($obj->is_dead() || $main::allyfriend[$self->{'RACE'}]->[$obj->{'RACE'}] ||
     $obj->{'FX'}->{'32'} || $obj->{'FX'}->{'7'}
     ) { return; }
  
  my @elecType = ('A light', 'A considerable', 'An intense', 'A huge');
  $obj->log_append("{17}$elecType[$self->{'PADSTR'}-1] burst of electricity zooms throughout your body.\n");
  $obj->room_sighttell("{17}$elecType[$self->{'PADSTR'}-1] burst of electricity zooms throughout $obj->{'NAME'}\'s body.\n");
  
  $obj->{'HP'} -= int ( $self->{'PADSTR'}/4*$obj->{'MAXH'} );
  if($obj->is_dead()) { $obj->die($self); }
  return;
}

package mount_gram_room;
@mount_gram_room::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  if($obj->is_dead() || $main::allyfriend[$self->{'RACE'}]->[$obj->{'RACE'}]) { return; }
  
  if(!$self->{'AI'}->{'VIC'}) { $self->{'AI'}->{'VIC'} = {}; }
  $self->{'AI'}->{'VIC'}->{$obj->{'OBJID'}}=1;
  
  $main::events{$self->{'OBJID'}}=20 unless defined($main::events{$self->{'OBJID'}});

  return;
}

sub on_event {
  my $self = shift;
  $main::events{$self->{'OBJID'}}=20 unless defined($main::events{$self->{'OBJID'}});
  if($self->{'AI'}->{'MSG'}==0) { $self->room_talktell($self->noise_make('chittering', "{3}In the distance, a soft sound can be heard. A chittering of sorts, that resembles a thousand tiny voices all whispering at once. It comes from the shadows and deep crevices, with the actual source remaining out of view.\n", 1)); $self->{'AI'}->{'MSG'}++; }
  elsif($self->{'AI'}->{'MSG'}==1) { $self->room_talktell($self->noise_make('chittering', "{3}The chittering noise gets louder.. The source must be approaching.\n", 1)); $self->{'AI'}->{'MSG'}++; }
  elsif($self->{'AI'}->{'MSG'}==2) { $self->room_talktell($self->noise_make('chittering', "{3}The chittering noise is almost deafening. It's coming from all over!!\n", 1));  $self->{'AI'}->{'MSG'}++; }
  else {
     # don't call again unless prompted to
     delete $main::events{$self->{'OBJID'}};
     
     foreach my $objid (keys(%{$self->{'AI'}->{'VIC'}})) {
        next if(!defined($main::objs->{$objid}));
        for(my $i=1; $i<10; $i++) {
           
           my $victim = $main::objs->{$objid};
           my $o = $main::map->[$self->{'ROOM'}]->item_spawn(307);
           $o->sick_em($victim);
           $o->{'AI'}->{'GIVEUP'}=1; # giveup on interplanar moves
           $o->stats_allto(int($victim->{'LEV'}*3/4));
           $o->stats_update;
           $o->power_up;
        }
     }
     $self->{'AI'}->{'MSG'}=0;
  }
  
  
  return;
}

package item_incorp;
@item_incorp::ISA = qw( item );

sub item_incorp::dam_bonus { 
  if($_[1]->{'INCORP'}) { return(&rockobj::dam_bonus(@_)); }
  else { return(-1e10); }
}


package item_effecttouch;
@item_effecttouch::ISA = qw( item );

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 $victim->log_append($self->{'TOUCHMSG'});
 $victim->effect_add($self->{'TOUCHFX'});
 $self->{'USES'}--;
 return;
}


package item_turnadd;
@item_turnadd::ISA = qw( clock );
use strict;

sub on_use {
  my ($self, $user) = @_;
  if($self->{'+T'}) {
    $user->log_append("{17}Dimensional time seems to have been pushed back - you gain {16}$self->{'+T'} {17}turns.\n");
    $user->{'T'}+=$self->{'+T'};
  }
  $self->room_sighttell("{3}A miniature portal pops open to suck a $self->{'NAME'} - seconds later, never to be seen again.\n");
  $self->obj_dissolve();
}

package bloodlust;
@bloodlust::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  if($self->{'CONTAINEDBY'} && (my $cby = $main::objs->{$self->{'CONTAINEDBY'}})) {
    if($cby->inv_has($self)) { 
      my @a = $main::map->[$cby->{'ROOM'}]->inv_pobjs;
      if(@a) {
       my $a = $a[int rand($#a+1)];
       if($a ne $cby) { 
         $cby->log_append("{17}$self->{'NAME'} whispers, \"{1}Kill $a->{'NAME'}... Kill $a->{'PPRO'}! Chop off $a->{'PPOS'} arms and legs.. then kick $a->{'PPOS'} head around!{17}\"\n");
       } else {
         $cby->log_append("{17}$self->{'NAME'} whispers, \"{1}You have lived long enough! Feed me with your blood! Impale yourself.. HURRY!{17}\"\n");
       }
      }
    }
  }
}

sub can_unequip {
  my ($self, $who) = @_;
  if($who->{'DECAP_USED'} > 0){
  	$who->log_append("{17}$self->{'NAME'} whispers, \"{1}Hey! Why would you want to do something like that!?\"\n");
	  return(0);
	}
	else {
		$who->skill_del(2);
		$who->log_append("{17}$self->{'NAME'} whispers, \"{1}If you must, then it shall be done!\"\n");
		$who->{'DECAP_USED'}++;
		return (1);
	}
}

sub can_equip  {
	my ($self, $who) = @_;
	if(($who->{'DECAP_USED'} < 1) ||($who->{'DECAP_UNLIMITED'})){
		if(!$who->skill_has(2)){
			$who->log_append("{17}$self->{'NAME'} whispers, \"{1}I will serve you in whatever way i can!\"\n");
			$who->skill_add(2);
		}
		$who->{'DECAP_USED'}++;
		return (1);
	}
	else{ 
		$who->log_append("{17}$self->{'NAME'} whispers, \"{1}You are not worthy of my abilities!\"\n");
		return 0;}
}

sub on_touch {
  my ($self, $who) = @_;

 
 
  
}

package item_complimentary;
@item_complimentary::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  if($self->{'CONTAINEDBY'}) {
    my $cby = $main::objs->{$self->{'CONTAINEDBY'}};
    if($cby->inv_has($self) && $self->{'EQD'}) { 
       if($cby->{'REPU'}<200) { $cby->log_append("{16}You are not deserving of such compliments.\n"); $cby->item_hunequip(); }
       else {
           $cby->log_append('{12}'.$main::compli_coffee[int rand(scalar(@main::compli_coffee))]."\n");
       }
    }
  }
}

sub can_equip {
  my ($self, $who) = @_;
  if($who->{'REPU'}<200) { $who->log_append("{17}$self->{'NAME'} {7}whispers, {6}\"No way!\"\n"); return(0); }
  else { $who->log_append("{17}$self->{'NAME'} {7}whispers, {6}\"Thank you SO much for choosing to wield ME! You are soooo cool!\"\n"); $self->{'WC'}=int ($who->{'REPU'}*1.5); return(1); }
  return;
}

package tele_crown;
@tele_crown::ISA = qw( item );
use strict;

sub on_use {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 $victim->room_sighttell("{2}Tendrils of sapphire blue psionic energy leap from $victim->{'NAME'}\'s crown, snaking their way around $victim->{'PPOS'} psyche to create a near-impenetrable shield.\n");
 $victim->log_append("{2}Your crown leaps into action upon command, wrapping your psyche within a sapphire blue sphere of psionic energy!\n");
 $victim->effect_add(34);
 $self->{'USES'}--;
 return;
}

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 my @k = keys(%{$main::activeuids});
 my $p = &main::obj_lookup($main::activeuids->{$k[int rand($#k+1)]});
 $victim->log_append("{17}For a brief moment, psionic energy overwhelms your sensory nerves, as you see through the eyes of someone else:\n".$p->room_str());
 $self->{'USES'}--;
 return;
}

package element_crown;
@element_crown::ISA = qw( item );
use strict;

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 my @k = keys(%{$main::activeuids});
 my $p = &main::obj_lookup($main::activeuids->{$k[int rand($#k+1)]});
 my $safeval = $main::map->[$p->{'ROOM'}]->{'SAFE'};
 if($main::map->[$p->{'ROOM'}]->{'SAFE'}){
	$victim->log_append("{17}Nothing happend to $p->{'NAME'} they are in a safe room.\n");
 	 
 }
 	
 if(!$main::map->[$p->{'ROOM'}]->{'SAFE'}){
 	$victim->log_append("{17}For a brief moment, elemental energy overwhelms your body and the plane, as you cast down a bolt of lightning on $p->{'NAME'}\n");
 	$p->log_append("{13}A bolt of lightning strikes you out of nowhere\n");
	 $p->{'HP'} -= int($p->{'MAXH'}/2);
 
 	$self->{'USES'}--;
	}
 return;
}


package zap_rectrap;
@zap_rectrap::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  if ($self->{'ZAP_ABS'}) {
    if(!$obj->inv_has_rec($self->{'ZAP_ABS'})) { return; }
    if($self->{'ZAP_SAFE'} && $obj->inv_has_rec($self->{'ZAP_SAFE'})) { return; }
    $self->zap_dark($obj);
  } else {
    if($self->{'ZAP_SAFE'} && $obj->inv_has_rec($self->{'ZAP_SAFE'})) { return; }
    $self->zap_dark($obj);
  }
  return;
}


package item_pixie_dust;
@item_pixie_dust::ISA = qw( item );
use strict;

sub on_throw {
   my ($self, $targ, $by) = @_;
   $self->c_endust($targ, $by);
}

sub on_use {
   my ($self, $by, $targ) = @_;
   $self->c_endust($targ || $by, $by);
}

sub c_endust {
   # custom func, endusts someone
   my ($self, $targ, $by) = @_;

   if ($targ->{'NODUST'}) {
       $by->log_error("$targ->{'NAME'} is immune to your $self->{'NAME'}.");
       return;
   }
   
   $targ->{'HIDDEN'} = 1 unless ($targ->{'HIDDEN'}>1);
   $by->log_append("{15}Your {5}bag of pixie dust explodes, releasing its glittery contents upon {15}$targ->{'NAME'}\{5}!\n");
   $targ->room_tell("{15}$by->{'NAME'}\'s {5}bag of pixie dust explodes, releasing its glittery contents upon {15}$targ->{'NAME'}\{5}!\n", $by);
   $targ->log_append("{15}$by->{'NAME'}\'s {5}bag of pixie dust explodes, releasing its glittery contents upon {15}you{5}!\n");
   if(!$self->{'USES'}--) { $self->obj_dissolve(); }
}

package plagueball;
@plagueball::ISA = qw( item );
use strict;

sub on_throw {
	my ($self, $targ, $by) = @_;
	
	$self->room_sighttell("{3}$self->{'NAME'} spontaneously combusts before your very eyes.\n");
	if ($targ->{'NOSICK'}) {
       $by->log_error("The $self->{'NAME'} has no effect on $targ->{'NAME'}") if $by;
	} else {
       $targ->effect_add(27) unless $targ->{'NOSICK'};
	}
	$self->obj_dissolve;
}

package mana_leech;
@mana_leech::ISA = qw( item );
use strict;

sub on_throw {
	my ($self, $targ, $by) = @_;
	
    if (ref($targ) && $targ->{'TYPE'} >= 1) {
	    $self->room_sighttell("{3}$self->{'NAME'} attaches itself to {7}$targ->{'NAME'}\{3} and sucks the mana out.\n");
        $targ->{'MA'} = 0;
    }
	$self->obj_dissolve();
}

package monsterlure;
@monsterlure::ISA = qw( item );
use strict;


sub on_throw {
 my ($self, $targ, $by) = @_;
 $self->room_sighttell("{3}$self->{'NAME'}\'s surge of pressure causes it to fractalize and explode.\n");
 if( ($targ->{'TYPE'}>=1) && ($targ->{'RACE'}!=$by->{'RACE'}) && !$main::allyfriend[$targ->{'RACE'}]->[$by->{'RACE'}] && !$targ->{'IMMORTAL'} && !$main::map->[$targ->{'ROOM'}]->{'SAFE'}) {
   my $o = $main::map->[$targ->{'ROOM'}]->item_spawn(282);
   $o->sick_em($targ);
   if($targ->{'TYPE'}==1) { $o->stats_allto(int($targ->{'LEV'}*3/5)); }
   else { $o->stats_allto(int($targ->{'LEV'}*1/5)); }
   $o->{'RACE'}=$by->{'RACE'};
   $o->stats_update; $o->power_up;
 }
 $self->obj_dissolve;
}

package artifact_boomer;
@artifact_boomer::ISA = qw( item );
use strict;

sub on_throwdir {
    my ($self, $dir, $by) = @_;
    if(rand(1) > $by->fuzz_pct_skill(15, 20)) { return; } # nothing happens if kmec sucks
    # remove self from new room
    my $r = $main::map->[$self->{'ROOM'}];
    return if ($r->{'!BOOMER'});
    
    $r->inv_del($self);
    # get list of items in room
    my @a = grep { !$_->is_spiritually_glued($by) && $by->can_lift($_) && $_->can_be_lifted($by, 1) } $r->inv_objs();
    
    my $pick = $a[int rand scalar @a];
    $r->room_sighttell("{17}$self->{'NAME'} {2}glides out to $main::dirfrommap{$main::diroppmap{$dir}}".($pick?", carrying $pick->{'NAME'}.\n":".\n"));
    # add to thrower's inventory
    $by->inv_add($self);
    $by->item_hequip($self, 1);
    $main::map->[$self->{'ROOM'}]->room_sighttell("{17}$self->{'NAME'} {2}glides in from $main::dirfrommap{$dir}".($pick?", carrying $pick->{'NAME'}":undef).", to be caught by $by->{'NAME'}.\n");
    if ($pick) {
        # add pick to inventory if exists.
        $r->inv_del($pick);
        $by->inv_add($pick);
        
        # Finally, after the item is added, call the "on_take" event
        # (e.g. for piles of cryl or fuzzems)
        $pick->on_take($by);
    }
}

sub on_throw {
 my ($self, $targ, $by) = @_;
 # be careful if they throw it at an npc
}

package artifact_brexus;
@artifact_brexus::ISA = qw( item );
use strict;

sub dam_bonus {
    # self, victim, 
    if(!defined($_[2]->{'FX'}->{'47'}) && (.05 > rand 1)) { $_[2]->room_sighttell("{13}$_[2]->{'NAME'}\'s broad-spear glows brightly.\n"); $_[2]->effect_add(47); }
    return $_[0]->SUPER::dam_bonus(@_);
}

package item_logoff;
@item_logoff::ISA = qw( item );
use strict;

sub item_logoff::desc_get {
	my ($self, $who) = @_;
	if(!$who || !$who->inv_has($self) || $who->{'TYPE'} != 1) { return($self->desc_hard); }
	else { 
    	$self->room_talktell("{2}$self->{'NAME'} {7}piercingly disrupts space and time in a penetrating boom!\n");
    	if(!$self->telnet_kick($who->{'NAME'}, $who->{'EJPW'}, 1)) { $main::donow .= '$main::objs->{'.$who->{'OBJID'}.'}->logout;'; }

    	$self->obj_dissolve;
    	return($self->desc_hard);
	}
}




package trap_pain;
@trap_pain::ISA = qw( item );
use strict;

sub trap_pain::on_idle {
  my $self = shift;
  my $o;
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{6}A length of chain lashes out, but you dodge it just in time!\n");
         $o->room_sighttell("{6}A length of chain lashes out at $o->{'NAME'}, but $o->{'NAME'} dodges it just in time!\n");
      } else {
         $o->log_append("{3}A length of barbed chain suddenly leaps into motion and stabs into your body, causing horrible pain!\n");
         $o->room_sighttell("{3}A length of barbed chain suddenly leaps into motion and stabs into $o->{'NAME'}\'s body, causing horrible pain!\n");
         if($o->{'WEAPON'}) {
            my $weapon = $main::objs->{$o->{'WEAPON'}};
            $o->log_append("You lose grip on your $weapon->{'NAME'}!\n");
            delete $o->{'WEAPON'}; delete $weapon->{'EQD'};
            $o->item_hdrop($weapon);
            $weapon->{'WC'} = $weapon->{'WC'} - 1;
         }
         $o->{'HP'} -= int ( ($o->{'MAXH'}/3) + rand(30) );
         if($o->{'HP'}<=0) { $o->die(); }
      }
    }
  
  }
  return;
}

package trap_famine;
@trap_famine::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  my $o;
  $self->room_sighttell("{3}The walls begin to throb hungrily.\n");
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{3}You manage to avoid their adverse effects.\n");
      } else {
         $o->effect_add(28);
      }
    }
  
  }
  return;
}

sub on_room_enter (who, direction from) {
  $main::events{$_[0]->{'OBJID'}}=1 unless $main::events{$_[0]->{'OBJID'}};
  return;
}

sub on_event { $_[0]->on_idle; }


package trap_rot;
@trap_rot::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  my ($o);
  $self->room_sighttell("{3}A foul wind blows through the chamber.\n");
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
        SWITCH:
        for (int rand(5)) {
          /0/ && do { $o->log_append("{3}Your eyes begin to rot away!\n"); $o->effect_add(22); last SWITCH; };
          /1/ && do { $o->effect_add(23); last SWITCH; };
          /2/ && do { $o->effect_add(24); last SWITCH; };
          /3/ && do { $o->log_append("{3}Your ears begin to rot away!\n"); $o->effect_add(25); last SWITCH; };
          /4/ && do { $o->log_append("{3}Your tongue begins to rot away!\n"); $o->effect_add(26); last SWITCH; };
        };
    }
  
  }
  return;
}

sub on_room_enter (who, direction from) {
  $main::events{$_[0]->{'OBJID'}}=1 unless $main::events{$_[0]->{'OBJID'}};
  return;
}

sub on_event { $_[0]->on_idle; }

package trap_plague;
@trap_plague::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  my $o;
  $self->room_sighttell("{3}A swarm of plague-infested rats run through the room.\n");
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky || $o->{'NOSICK'}) { 
         $o->log_append("{2}Luckily, you manage to avoid contracting any diseases.\n");
      } else {
         $o->log_append("{3}You have become infected with the plague!\n");
         $o->effect_add(27);
      }
    }
  }
  return;
}

sub on_room_enter (who, direction from) {
  $main::events{$_[0]->{'OBJID'}}=1 unless $main::events{$_[0]->{'OBJID'}};
  return;
}

sub on_event { $_[0]->on_idle; }

package item_adminonly;
@item_adminonly::ISA = qw( item );
use strict;

sub can_be_lifted {
  if($_[1]->{'ADMIN'}) { return(1); }
  # check passive
  elsif(!$_[2]) { $_[1]->room_sighttell("{14}A strange force prevents $_[1]->{'NAME'} from picking up $_[0]->{'NAME'}.\n");  }
  return(0);
}

package fists;
@fists::ISA = qw( rockobj );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='fists' unless $self->{'NAME'};
  $self->{'FPAHD'}='punched';  $self->{'FPSHD'}='punch';
  $self->{'TPAHD'}='punched';  $self->{'TPSHD'}='punches';
  $self->{'VOL'}=.02; $self->{'MASS'}=.05;
  $self->{'WC'}=1;
  return($self);
}

package item_arena_team_splitter;
@item_arena_team_splitter::ISA = qw (rockobj);
use strict;

sub on_touch {
    my ($self, $by) = @_;
    
    return $self->on_use($by);
}

sub on_use {
    my ($self, $user) = @_;
	
    return 0 unless $user->can_do(0,0,0);
    
    unless ($user->{'GAME'}) {
        $user->log_error("You cannot use that item when you aren't in the arena. You shouldn't have it anyway!");
        return 0;
    }
    
    $user->log_append("{14}You sit down and place both of your hands on $self->{'NAME'}.\n");
    $user->room_sighttell("{14}$user->{'NAME'} sits down and place both of $user->{'PPOS'} hands on $self->{'NAME'}.\n");
    
    my %victims_by_room;
	map { $victims_by_room{$_->{'ROOM'}} ||= []; push @{$victims_by_room{$_->{'ROOM'}}}, $_; } grep { $_->{'RACE'} >= 6 && $_->{'RACE'} != $user->{'RACE'} && $_->{'GAME'} && $_->{'TYPE'} == 1 } map { $main::objs->{$_} } keys %$main::activeusers;

    my @victim_sets = sort { @$b <=> @$a } values %victims_by_room;
    my $victim_set = $victim_sets[0];
    
    if ($victim_set && @$victim_set > 1) {
        my @locs = map { $main::roomaliases{$_} } qw(assstart1 assstart2 arena_magicteleport1 arena_magicteleport2 arena_magicteleport3 arena_magicteleport4);
        
        my $rand_rot = int rand(@locs);
        for (my $i=0; $i<$rand_rot; ++$i) {
            push(@locs, shift(@locs));
        }
        
        # aha, displace them
        foreach my $victim (@$victim_set) {
            $victim->log_append("{14}### A powerful force guided by $user->{'NAME'} has split up your team's group. ###\n");
            $victim->teleport($locs[0]);
            $victim->effect_add(18) if rand(1) < 0.2;
            push(@locs, shift(@locs));
        }
        
        $user->log_append("{14}You have split up the group of: ".join(', ', map { $_->{'NAME'} } @$victim_set).".\n");

  &main::rock_shout(undef, "{3}$user->{'NAME'} used sphere to split up a group of: ".join(', ', map { $_->{'NAME'} } @$victim_set).".\n", 1);

        $self->room_sighttell("{3}$self->{'NAME'} disappears.\n");
        $self->dissolve_allsubs();

  	    return 1; # success - they did something worthwhile
    } else {
        $user->log_error("Nothing happens.");
        return 0;
    }
    
}


package gamecont_ass;
# controlls a game of CTF
@gamecont_ass::ISA = qw( rockobj );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='control panel' unless $self->{'NAME'};
  $self->{'FPAHD'}='controlled';  $self->{'FPSHD'}='control';
  $self->{'TPAHD'}='controlled';  $self->{'TPSHD'}='controls';
  $self->{'DESC'} = 'This control panel is covered in more buttons and flashy red lights than a night at the disco club.';
  $self->{'DLIFT'}=''; $self->{'CAN_LIFT'}='';
  $main::gameobjs{ ref($self) }=$self->{'OBJID'};
  return($self);
}


$main::arena_invite_only = "";
#$main::arena_invite_only = "Mindreader Icarus Fatman Nede Rawr Warmonger";

sub get_players_waiting_at_entrance {
    # Returns array of players waiting in the arena entrance.
    my $self = shift;

   my @players =  grep { $_->{'TYPE'}==1 && (time - $_->{'@LCTI'}) < 3*60  } $main::map->[$main::roomaliases{'arenahall'}]->inv_objs();

   if ($main::arena_invite_only) {
       @players = grep { $main::arena_invite_only =~ /\b$_->{'NAME'}\b/i } @players;
   }
   
   
   return @players;
}

sub on_wind {
  # later on event maybe?
  my $self = shift;
  my $winder = shift;
  my $prized = 'An unprized';
  my $wait_room = $main::roomaliases{'arenahall'};

  # Don't let them wind me up unless they fit the requirements.
  if (!$winder->is_developer() && !$winder->inv_has_rec(337) && !$winder->inv_has_rec(363)&& !$winder->inv_has_rec(580)&& !$winder->inv_has_rec(1158) ) {
      $self->say("Psst, $winder->{'NAME'}, only holders of plastic rulers can wind me up!");
      return;
  }
 
  # check for game in progress..
  if ($self->{'AI'}->{'GIP'}) { $self->say("Sorry! There is a game in progress right now."); return; }
    
  # get which players are waiting to play.
  my @players = $self->get_players_waiting_at_entrance();

  # if there's not enough people in the room to play..
  if (@players < 2   &&   !$winder->{'ADMIN'}) { 
      $self->say("You need ".(2-@players)." more active players in order to play.");
      return;
  }  
  
  # a game's already starting. don't bother thinking about it.
  if ($main::events{$self->{'OBJID'}}) {
      $self->say("A game will start soon, hold on.. :-)");
      return;
  }

  # Trigger callback (so we know when to start arena and stuff)
  $main::events{$self->{'OBJID'}}=25;
  $self->{'AI'}->{'STARTTIME'}=time + $main::arena_start_time*60;
  
  $self->{'AI'}->{'GAMETYPE'} = "slice-o-rama";
  
  if (my $obj = $winder->inv_rec_scan(363)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {13}prized';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  } elsif (my $obj = $winder->inv_rec_scan(337)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  } elsif (my $obj = $winder->inv_rec_scan(580)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {12}prized';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  }
  ### DELETE BELOW THIS AFTER SATURDAY
  elsif (my $obj = $winder->inv_rec_scan(1150)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {13}bimbos';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  }
    elsif (my $obj = $winder->inv_rec_scan(1151)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {5}peepers';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  }
    elsif (my $obj = $winder->inv_rec_scan(1152)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {1}furry';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  }
  elsif (my $obj = $winder->inv_rec_scan(1153)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {11}special';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  }elsif (my $obj = $winder->inv_rec_scan(1157)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $self->{'AI'}->{'PRIZEREC'}=$obj->{'PRIZEREC'};
     $prized = 'A {11}good';
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
  } elsif (my $obj = $winder->inv_rec_scan(1158)) {
     $winder->log_append("{6}The {2}$obj->{'NAME'} {6}disappears from your inventory.\n");
     $obj->{'USES'}--;
     $obj->obj_dissolve() if $obj->{'USES'} < 1;
 }
  $main::arena_starting=1;
  &main::rock_shout(undef, "{6}**{4}#{6}** {16}$prized {11}$self->{'AI'}->{'GAMETYPE'} {16}arena will start in about $main::arena_start_time minute".($main::arena_start_time==1?undef:'s').".\n{6}**{4}#{6}** {16}If you want to play, head to the arena PRONTO!\n");
  
  return;
}




sub init_teams_and_map_for_slice_o_rama() {
  my ($self, @players) = @_;
  
  my @players_copy = @players;
  
  my (@teama, @teamb);
  
  # declare teams, slowly shuffling picks off of @players.
#  while (@players) {
#      if (rand(10)<5) {
#          if (rand(10)<5) { push(@teama, pop(@players)); }
#          else { push(@teama, shift(@players)); }
#          
#          if (@players) { 
#              if (rand(10)<5) { push(@teamb, pop(@players)); }
#              else { push(@teamb, shift(@players)); }
#          }
#      } else {
#          if (rand(10)<5) { push(@teamb, pop(@players)); }
#          else { push(@teamb, shift(@players)); }
#          
#          if (@players) { 
#              if (rand(10)<5) { push(@teama, pop(@players)); }
#              else { push(@teama, shift(@players)); }
#          }
#      } 
#  }
#   
  @players = sort { $b->{'ARENA_PTS'} <=> $a->{'ARENA_PTS'} } @players;
  my $team_a_arena_points = 0;
  my $team_b_arena_points = 0;
  foreach my $player (@players) {
      my $player_points = &rockobj::bound($player->{'ARENA_PTS'}, 0, 10)/7 + 3 + rand(2);
      &main::rock_shout(undef, "$player->{'NAME'} has PP of $player_points\n", 1);
      if ( $team_a_arena_points <= $team_b_arena_points ) {
          push @teama, $player;
          $team_a_arena_points += $player_points;
      } else {
          push @teamb, $player;
          $team_b_arena_points += $player_points;
      }
  }
  &main::rock_shout(undef, "Split Team A: $team_a_arena_points, Team B: $team_b_arena_points\n", 1);

  if (rand(10) < 5) {
      &main::rock_shout(undef, "Flipping teams around to look cool\n", 1);
      my @temp;
      @temp = @teama;
      @teama = @teamb;
      @teamb = @temp;
  }

  @players = @players_copy;

  # clear/set ai info and..
  $self->{'AI'}->{'TEAMA'}->[0] = {};    # nobody's on teama yet
  $self->{'AI'}->{'TEAMB'}->[0] = {};    # nobody's on teamb yet
  $self->{'AI'}->{'TEAMA'}->[1]=0;       # score for teama = 0
  $self->{'AI'}->{'TEAMB'}->[1]=0;       # score for teamb = 0

  my @ambient;
  # move npcs to the area first and idle them..
  for (my $n=1; $n<=4; $n++) {
    my $o = $main::map->[$main::roomaliases{'assstart1'}]->item_spawn(166);
    $o->{'RACE'}=14;
    push(@ambient, $o->{'OBJID'}); $o->{'GAME'}=ref($self);

    my $o = $main::map->[$main::roomaliases{'assstart2'}]->item_spawn(166);
    $o->{'RACE'}=15;
    push(@ambient, $o->{'OBJID'}); $o->{'GAME'}=ref($self);
  }

  my ($spoa, $spob, $spoc, $spod, $spoe, $spof, $spog, $spoh);
  for (my $n=1; $n<=2; $n++) {
    $spoa = ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(192))->{'OBJID'}; $main::objs->{$spoa}->{'RACE'}=14;
    $spob = ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(192))->{'OBJID'}; $main::objs->{$spob}->{'RACE'}=15;
    $spoc = ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(48))->{'OBJID'};  $main::objs->{$spoc}->{'RACE'}=14;
    $spod = ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(48))->{'OBJID'};  $main::objs->{$spod}->{'RACE'}=15;
    $spoe = ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(195))->{'OBJID'}; $main::objs->{$spoe}->{'RACE'}=14;
    $spof = ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(195))->{'OBJID'}; $main::objs->{$spof}->{'RACE'}=15;
    $spoe = ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(347))->{'OBJID'}; $main::objs->{$spoe}->{'RACE'}=14;
    $spof = ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(347))->{'OBJID'}; $main::objs->{$spof}->{'RACE'}=15;
    $spog = ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(267))->{'OBJID'}; $main::objs->{$spoa}->{'RACE'}=14;
    $spoh = ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(267))->{'OBJID'}; $main::objs->{$spoa}->{'RACE'}=14;
    push(@ambient, $spoa, $spob, $spoc, $spod, $spoe, $spof, $spog, $spoh);
 }
   # 349
   
 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(708))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(708))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(583))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(583))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(176))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(176))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(349))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(349))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(708))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(708))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(288))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(288))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsa'}]->item_spawn(709))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsa'}]->item_spawn(709))->{'OBJID'});

 push(@ambient, ($main::map->[$main::roomaliases{'teama-itemsb'}]->item_spawn(709))->{'OBJID'});
 push(@ambient, ($main::map->[$main::roomaliases{'teamb-itemsb'}]->item_spawn(709))->{'OBJID'});
 # &main::objs_idle; &main::objs_idle; &main::objs_idle; 288

 @{$self->{'AI'}->{'AMB'}} = @ambient;

 foreach my $o (@teama, @teamb) {
     $o->remove_from_all_groups;
 }
  
  # move all players to their area..
  foreach my $o (@teama) { 
      $o->{'TEMPDROOM'}=$main::roomaliases{'assstart1'};  # Set their temporary death room
      $o->{'TEMPRACE'} = $o->{'RACE'}; $o->{'RACE'}=14;    # Set temporary races
      $self->{'AI'}->{'TEAMA'}->[0]->{$o->{'OBJID'}}=1;   # array element 0 = player objids; 1 = score
  }
  
  foreach my $o (@teamb) {
      $o->{'TEMPDROOM'}=$main::roomaliases{'assstart2'};  # Set their temporary death room
      $o->{'TEMPRACE'} = $o->{'RACE'}; $o->{'RACE'}=15;    # Set temporary races
      $self->{'AI'}->{'TEAMB'}->[0]->{$o->{'OBJID'}}=1;   # array element 0 = player objids; 1 = score
  }


}

sub get_arena_scoreboard_string() {
    my $self = shift;
   
   my (@namesa, @namesb, @teama, @teamb);
   
   @teama = grep { defined $_ } map { $main::objs->{$_} } keys %{$self->{'AI'}->{'TEAMA'}->[0]};
   @teamb = grep { defined $_ } map { $main::objs->{$_} } keys %{$self->{'AI'}->{'TEAMB'}->[0]};
   
   foreach my $o (@teama) { push(@namesa, $o->{'NAME'}); }
   foreach my $o (@teamb) { push(@namesb, $o->{'NAME'}); }

   return "{17}Team A: {14}".join(', ', @namesa).".\n{17}Team B: {14}".join(', ', @namesb).".\n";
}

sub on_event {
    # declare players
    # assstart 1, assstart 2

    my $self = shift;
    my $wait_room = $main::roomaliases{'arenahall'};

    # check if it's time..if not, throw back to events
    if(time < $self->{'AI'}->{'STARTTIME'}) { $main::events{$self->{'OBJID'}}=15; return; }

    $main::arena_starting=0;

    my ($o, @ptemp, @players);
    foreach $o ($self->get_players_waiting_at_entrance()) { 
        # if the exp backup stuff worked, add'em to the player list
        if ($o->exp_make_backup()) { 
	        push(@players, $o);
	        if($o->{'CRYL'}) { $o->cmd_do('deposit'); }
	        delete $o->{'STALKING'};
        }
    }

    # if there's not enough people in the room to play..
    if (scalar(@players) < 2) { 
        $self->say("You need ".(2-scalar(@players))." more active players in order to play.");

        # restore stats of the people who were there
        foreach my $player (@players) { $player->exp_restore_backup(); $player->stats_update(); }
        return;
    }  
    



    $self->{'AI'}->{'KILLSNEEDED'}= 2 * @players;


    # !!!!!!!!!! BEGIN TEAM-SPECIFIC SETUP !!!!!!!!!!!
    $self->init_teams_and_map_for_slice_o_rama(@players);
    # !!!!!!!!! END TEAM-SPECIFIC SETUP !!!!!!!!!!! 


    # announce teams
    &main::rock_shout(undef, "{17}** $main::arena_planning_time\-SECOND PLANNING TIME ** for {7}$self->{'AI'}->{'GAMETYPE'}\{1} has begun!\n");
    &main::rock_shout(undef, $self->get_arena_scoreboard_string());



    foreach $o (@players) {
        $o->stats_allto(int (70 + rand(5))); #keep within 5 ;-)
        $o->{'EXP'}->[15] /= 2; $o->{'EXP'}->[16] /= 2;
        $o->{'GAME'}=ref($self);
        $o->stats_update();
        $o->power_up();
        $o->items_givebasic();
        $o->teleport($o->{'TEMPDROOM'}, 1);
        $o->hostility_toggle("all");
        $o->pref_toggle('attack upon user entry', 1, 1);
    }

    map { $_->{'LAST_ARENA_PTS'} = $_->{'ARENA_PTS'} } (@players); # save old scores for comparison later!



    my $type_cap;
    if($main::arena_time_limit>0) { 
       $type_cap .= "{2}Timed Mode: {5}$main::arena_time_limit minutes. ";
    } else {
       $type_cap .= "{2}Regular Mode: {5}$self->{'AI'}->{'KILLSNEEDED'} kills needed. ";
    }
    $type_cap .= $main::arena_can_life==1?'Unlimited lives.':'One life per player.';
    &main::rock_shout(undef, "$type_cap\n");


    $self->{'AI'}->{'GIP'}=1;            # Game is in progress
    $self->{'AI'}->{'START_TIME'}=time;  # Mark my start time so we know how to end it later.


  #  if ($main::arena_time_limit > 0) {
       $main::eventman->enqueue($main::arena_time_limit*60+1, \&gameover_check, $self);
       $main::eventman->enqueue(15, \&gameover_check, $self, 1);
  #  }

    $main::arena_start_epoch = time;
    $main::eventman->enqueue($main::arena_planning_time, \&main::rock_shout, undef, "{1}A game of {17}$self->{'AI'}->{'GAMETYPE'}\{1} has begun!\n".$self->get_arena_scoreboard_string());
    $self->{'AI'}->{'TEAMNAMESTR'}=$self->get_arena_scoreboard_string();
}

# evalll $main::objs->{'1704'}->gameover_check();

sub gameover_check {
  my $self = shift;
  my $should_start_event_again = shift;
  
  if(!$self->{'AI'}->{'GIP'}) { return; }
  
  # dont count score if we're still in planning time
  if($self->{'AI'}->{'START_TIME'} >= (time - $main::arena_planning_time)) { return; }

  my $timed = $main::arena_time_limit > 0;
  my $wait_room = $main::roomaliases{'arenahall'};

  my ($winner, $ascore, $bscore, $p);
  $ascore = int ($self->{'AI'}->{'TEAMA'}->[1]*=1);
  $bscore = int ($self->{'AI'}->{'TEAMB'}->[1]*=1);
  
  
  # regular arena scoring
  $winner = 0;
  my $end_game = 0;
  
  if($timed && (time - $self->{'AI'}->{'START_TIME'}) > 60 * $main::arena_time_limit ) { 
     &main::rock_shout(undef, "{1}[BC]: {17}TIME'S UP!\n");
     if($ascore > $bscore) { $winner |= 1; }
     elsif($bscore > $ascore) { $winner |= 2; }
     elsif($ascore == 0 && $bscore == 0) { $winner = 0; }
     else { $winner = 3; }
	 $end_game = 1;
  } else {
#	  &main::rock_shout(undef, "{7}-- checking max kills (before: $winner)\n", 1);
     if($ascore >= $self->{'AI'}->{'KILLSNEEDED'}) {
	     $winner |= 1; $end_game = 1;
         &main::rock_shout(undef, "{1}[BC]: {17}Team A Reached Score Threshold of $self->{'AI'}->{'KILLSNEEDED'}!\n");

	 }
     if($bscore >= $self->{'AI'}->{'KILLSNEEDED'}) {
	     $winner |= 2; $end_game = 1;
         &main::rock_shout(undef, "{1}[BC]: {17}Team B Reached Score Threshold of $self->{'AI'}->{'KILLSNEEDED'}!\n");
     }
  }
  
  # if all of one team is dead, then the other team wins!!
  unless (grep { $main::objs->{$_} && ($main::objs->{$_}->{'HP'} > 0 || (time - $main::objs->{$_}->{'DIED'}) <= 15) } keys %{$self->{'AI'}->{'TEAMA'}->[0]}) {
      # team b wins; everyone in team a either disco'd or is dead
	  $winner |= 2;
      $end_game = 1;
         &main::rock_shout(undef, "{1}[BC]: {17}Everyone in Team A is either dead or gone!\n");
  }
  unless (grep { $main::objs->{$_} && ($main::objs->{$_}->{'HP'} > 0 || (time - $main::objs->{$_}->{'DIED'}) <= 15) } keys %{$self->{'AI'}->{'TEAMB'}->[0]}) {
      # team a wins; everyone in team b either disco'd or is dead
	  $winner |= 1;
         &main::rock_shout(undef, "{1}[BC]: {17}Everyone in Team B is either dead or gone!\n");
      $end_game = 1;
  }
  
#	  &main::rock_shout(undef, "{7}-- winner is $winner\n", 1);

  if(!$winner && !$end_game) {  if ($should_start_event_again) {$main::eventman->enqueue(15, \&gameover_check, $self);}   return(0); }

  if(!$winner || ($winner==3)) {
    # if a tie or no winners, check to see that everyone's still playing..
    foreach $p (keys(%{$self->{'AI'}->{'TEAMA'}->[0]})) {
      if(!$main::objs->{$p}) { delete $self->{'AI'}->{'TEAMA'}->[0]->{$p}; }
    }
    foreach $p (keys(%{$self->{'AI'}->{'TEAMB'}->[0]})) {
      if(!$main::objs->{$p}) { delete $self->{'AI'}->{'TEAMB'}->[0]->{$p}; }
    }
    my ($apl, $bpl);
    $apl = scalar(keys(%{$self->{'AI'}->{'TEAMA'}->[0]}));
    $bpl = scalar(keys(%{$self->{'AI'}->{'TEAMB'}->[0]}));

    if(!$apl && !$bpl) { $winner=-1; }
    elsif(!$apl) { $winner=2; }
    elsif(!$bpl) { $winner=1; }
  }
  
  
  my $winningRace;
  
  # otherwise, gather up the players and call it a day..
  if($winner==-1) { &main::rock_shout(undef, "{1}[BC]: {17}Slice-O-Rama {7}has ended. Nobody has won. Rock is sad.\n"); }
  elsif($winner==1) { &main::rock_shout(undef, "{1}[BC]: {17}Slice-O-Rama {7}has ended. {1}Team A resides victorious!\n"); $winningRace=14; }
  elsif($winner==2) { &main::rock_shout(undef, "{1}[BC]: {17}Slice-O-Rama {7}has ended. {1}Team B resides victorious!\n"); $winningRace=15;}
  elsif($winner==3) { &main::rock_shout(undef, "{1}[BC]: {17}Slice-O-Rama {7}has ended. {1}Teams A and B Have Tied!\n"); }
  &main::rock_bshout(undef, "{1}[BC]: {17}Team A: {5}$ascore. {17}Team B: {5}$bscore.\n{17}*** GAME OVER ***\n");
  foreach $p (keys(%{$self->{'AI'}->{'TEAMA'}->[0]}), keys(%{$self->{'AI'}->{'TEAMB'}->[0]})) {
      if($main::objs->{$p}) {
         $p = $main::objs->{$p};
         my $won = ($p->{'RACE'} == $winningRace);
         $p->{'HP'}=$p->{'MAXH'};
         $p->teleport($wait_room, 1);
         
         $p->exp_restore_backup;
         
         $p->stats_update();
         $p->power_up();
         $p->remove_from_all_groups();
         $p->hostility_toggle("none");
         $p->player_stalk('') if $p->{'STALKING'};
         $p->pref_toggle('attack upon user entry', 0, 0);
         
		my $arena_pts_gained =  int(($p->{'ARENA_PTS'} - $p->{'LAST_ARENA_PTS'})*1000)/1000;
        if ($arena_pts_gained >= 0) { 
            $p->log_append(sprintf("{12}You gained %5.2f points through playing this arena match.\n", $arena_pts_gained));
        } else {
            $p->log_append(sprintf("{11}You lost %5.2f points through playing this arena match.\n", -$arena_pts_gained));
        }
        &main::rock_shout(undef, "{2}$p->{'NAME'} es muy $arena_pts_gained arena points mas.. mmm puntos!\n", 1);

         if($won && $self->{'AI'}->{'PRIZEREC'}) {
            
		    if ($arena_pts_gained >= 0) {
			    # their score is higher, so give'em a prize!
		    	my $itemwon = $p->item_spawn_forced($self->{'AI'}->{'PRIZEREC'}); #warning: this could be undef!!
            	$p->log_append("{17}Congratulations! You have won: {6}".$itemwon->{'NAME'}."{17}!\n")
			    	if $itemwon;
			} else {
			    $p->log_error("Your team has won the match, but you must gain at least 0.5 arena point in order to receive a prize.");
			}
         }
         delete $p->{'STALKING'};
      }
  }
  $main::map->[$wait_room]->room_tell($self->{'AI'}->{'TEAMNAMESTR'});
  # reset game
  $self->game_reset;
  return;
}

sub on_death_notify {
   my ($self, $killer, $dyer) = @_;
    my $wait_room = $main::roomaliases{'arenahall'};
   &main::rock_bshout($killer, "{1}[BC]: {17}$killer->{'NAME'} ( {1}$main::races[$killer->{'RACE'}] {17}) {7}has slain $dyer->{'NAME'}.\n"); 
   if($killer->{'RACE'}!=$dyer->{'RACE'}) { 
    if($killer->{'RACE'}==14) { $self->{'AI'}->{'TEAMA'}->[1]++; }
    if($killer->{'RACE'}==15) { $self->{'AI'}->{'TEAMB'}->[1]++; }
   } else {
    if($killer->{'RACE'}==15) { $self->{'AI'}->{'TEAMA'}->[1]--; }
    if($killer->{'RACE'}==15) { $self->{'AI'}->{'TEAMB'}->[1]--; }
   }
   #if($dyer->{'RACE'}==6) { $self->{'AI'}->{'TEAMA'}->[1]--; }
   #if($dyer->{'RACE'}==7) { $self->{'AI'}->{'TEAMB'}->[1]--; }
   &main::rock_bshout(undef, "{1}[BC]: {17}Scorage: {7}Team A: {1}$self->{'AI'}->{'TEAMA'}->[1]. {7}Team B: {1}$self->{'AI'}->{'TEAMB'}->[1].\n"); 
   $main::map->[$wait_room]->room_talktell("{17}$killer->{'NAME'} ( {1}$main::races[$killer->{'RACE'}] {17}) {7}has slain $dyer->{'NAME'}. {17}Scorage: {7}Team A: {1}$self->{'AI'}->{'TEAMA'}->[1]. {7}Team B: {1}$self->{'AI'}->{'TEAMB'}->[1].\n"); 
   $self->{'DESC'}="This control panel is covered in more buttons and flashy red lights than a night at the disco club.\nThe console reads:\n{7}Team A: {1}$self->{'AI'}->{'TEAMA'}->[1]. {7}Team B: {1}$self->{'AI'}->{'TEAMB'}->[1].\n";
   # check me
   $main::donow .= '$main::objs->{'.$self->{'OBJID'}.'}->gameover_check;';
   return;
}

sub on_idle { if($_[0]->{'AI'}->{'GIP'}) { shift->gameover_check; } }

sub game_reset {
  my $self = shift;
  delete $self->{'AI'}->{'PRIZEREC'};
  delete $self->{'AI'}->{'TEAMA'};
  delete $self->{'AI'}->{'TEAMB'};
  delete $self->{'AI'}->{'GIP'};
  $self->{'DESC'} = 'This control panel is covered in more buttons and flashy red lights than a night at the disco club.';
  my $o;
  foreach $o (@{$self->{'AI'}->{'AMB'}}) {
    if(defined($main::objs->{$o})) { $main::objs->{$o}->obj_dissolve; }
  }
  return;
}

# my ($o, $t); foreach $o (@{$main::map}) { if ($o->{'PORTAL'}==7) { $t.="[ $o->{'ROOM'} ]"; } } $t;
#

package web;
@web::ISA = qw( rockobj );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='gridded web' unless $self->{'NAME'};
  $self->{'FPAHD'}='webbized';  $self->{'FPSHD'}='webbize';
  $self->{'TPAHD'}='webbized';  $self->{'TPSHD'}='webbizes';
  $self->{'DESC'} = 'This large net is woven of thick metal strands.';
  $self->{'CATCHFUZ'}=.6 unless $self->{'CATCHFUZ'};
  $self->{'STICKYFUZ'}=.6 unless $self->{'STICKYFUZ'};
  $self->{'DLIFT'}=''; $self->{'CAN_LIFT'}='';
  $self->{'HP'} = 1;
  return($self);
}

sub on_room_enter (who, direction from) {
  my ($self, $who, $dir) = @_;
  # give'em a chance to escape

  if( ($main::allyfriend[$self->{'RACE'}]->[$who->{'RACE'}]) || ($who->{'TYPE'}<=0) || ($who->{'RACE'} == 1) || (rand(1) > $self->{'CATCHFUZ'}) || $who->aprl_rec_scan(119) ){ return; }
 # return unless $who->{'TYPE'} == 1;
  # otherwise..bahahhahahah...bahahhahahaha..bahhahaahhAhem..
  $who->log_append("{3}You become tangled up within the $self->{'NAME'}.\n");
  $who->room_sighttell("{3}$who->{'NAME'} becomes tangled up within the $self->{'NAME'}.\n");
  $who->{'TANGLED'}=$self->{'OBJID'};
  if($self->{'CROBJID'} && $main::objs->{$self->{'CROBJID'}}) {
    $main::objs->{$self->{'CROBJID'}}->log_append("{2}You hear the horrifying sound of $who->{'NAME'}'s scream as $who->{'PRO'} gets caught in your web.\n"); 
  }
  return;
}

# Webs can always be salped. Ooh, ahh.
sub can_be_salped_by {
   my ($self, $salper) = @_;
   if ((time - $self->{'BIRTH'}) < 10 * 60) {
       $salper->log_error("$self->{'NAME'} is too fresh, its outer fibers insulating itself from the salp.");
       return 0;
   } else {
       return 1;
   }
}

sub dam_bonus { 10 }

package debris_pile; 
@debris_pile::ISA = qw( item );
use strict;

sub dug {
    my ($self, $digger) = @_;
    
    if (rand(100) < 5) {
        # found rusted sprocket.. yippie!
        if ( my $new_sprocket = $digger->item_spawn(631) ) {
            $digger->log_append("{12}A flash of {3}dull metal {12}catches your eye, and you pull a {13}$new_sprocket->{'NAME'} {12}from the $self->{'NAME'}.\n");
            $digger->room_sighttell("{12}A flash of {3}dull metal {12}catches $digger->{'NAME'}\'s eye, and $digger->{'PRO'} pulls a {13}$new_sprocket->{'NAME'} {12}from the $self->{'NAME'}.\n");
        } else {
            $digger->log_error("You find something, yet nothing.. GAME BUG?!?!?");
        }
    } else {
        # found nada
        $digger->log_append("{12}You find nothing of interest in the $self->{'NAME'}.\n");
        $digger->room_sighttell("{12}$digger->{'NAME'} digs around in the $self->{'NAME'}, but finds nothing of interest.\n");
    }
    
    # respawn in the future tense (30 minutes from now)
    my @possible_rooms = grep { $_->{'DB'} == 96 } @$main::map;
    $main::eventman->enqueue(30 * 60, \&rockobj::item_spawn, $possible_rooms[int rand @possible_rooms], $self->{'REC'});
    $self->dissolve_allsubs();
}


package dirt_diggable; # diggable dirt, uses TRIGEXIT
@dirt_diggable::ISA = qw( item );
use strict;

sub dug { 
   my ($self, $digger) = @_; 
   $digger->log_append("{2}You dig further into $self->{'NAME'}.\n");
   $digger->room_sighttell("{2}$digger->{'NAME'} digs further into $self->{'NAME'}.\n");
   if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]) { return; }
   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0; # allow entry
   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[2]=1;
   return; 
}

package item_pushable; # diggable dirt, uses TRIGEXIT
@item_pushable::ISA = qw( item );
use strict;

sub pushed { 
   my ($self, $pusher) = @_; 
   $pusher->log_append("{2}You push on the $self->{'NAME'}, revealing an exit to the $main::dirlongmap{$self->{'TRIGEXIT'}}.\n");
   if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]) { return; }
   $pusher->room_sighttell("{2}An exit appears to the $main::dirlongmap{$self->{'TRIGEXIT'}}.\n");
   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0; # allow entry
   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[2]=1;
   return; 
}

package orc_red_button; # diggable dirt, uses TRIGEXIT
@orc_red_button::ISA = qw( item );
use strict;

sub pushed { 
   my ($self, $who) = @_; 
   $who->log_append("{2}You push the red, jolly, candylike button.\n");
   $who->room_sighttell("{2}$who->{'NAME'} fiddles with something as your back is turned.\n");
   
   if($main::map->[$self->{'ROOM'}]->inv_rec_scan(-7) ||
      $main::map->[$main::roomaliases{'mount-gram-hornportal'}]->inv_rec_scan(-7)
     ) { return; }
   
   $self->room_sighttell("{17}A bright portal appears.\n");
   $main::map->[$main::roomaliases{'mount-gram-hornportal'}]->room_sighttell("{17}A bright portal appears.\n");
   
   my $localPort = $main::map->[$self->{'ROOM'}]->item_spawn(7);
   my $mtPort = $main::map->[$main::roomaliases{'mount-gram-hornportal'}]->item_spawn(7);
   $localPort->{'NOENTER'} = 1;
   $localPort->{'PORTAL'} = $mtPort->{'PORTAL'} = 101;
   $localPort->{'ROT'} = $mtPort->{'ROT'} = time + 60;
   $localPort->{'REC'} = $mtPort->{'REC'} = -7;
   
   &main::cleanup_objs();
   return; 
}

package rock_pushable; # diggable dirt, uses TRIGEXIT
@rock_pushable::ISA = qw( item );
use strict;

sub pushed { 
   my ($self, $digger) = @_; 
   $digger->log_append("{2}You wrap your hand around $self->{'NAME'}\, then push it in.\n");
   $digger->room_sighttell("{2}$digger->{'NAME'} pushes deeply into $self->{'NAME'}.\n");
   $self->room_sighttell("{17}Your vision improves, and you notice another exit to the northeast.\n");
#   if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]) { return; }
#   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0; # allow entry
#   $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[2]=1;
   
   $self->execute_create_exit_trigger();  # add my exit
    
   return; 
}

package substring_game;
@substring_game::ISA = qw( item );
use strict;

sub on_say {
    my ($self, $obj, $txt) = @_;
    return if $obj eq $self;
    
    if ($$txt eq "reset game") {
        $self->say("Resetting game");
        $self->reset_game();
    } elsif ($$txt eq "yelp") {
        $self->reveal_random_letter();
        $self->send_game_board();
    } else {
        $self->guess_word($$txt, lc $obj->{'NAME'});
#        $self->say("$$txt");
    }
#    $main::events{$self->{'OBJID'}}=int rand(8) + 4;

}

sub on_event {

}


sub reset_game  {
    my $self = shift;
    my $stats = $self->{'GAMESTATS'} = {};
    $stats->{'SCORES'} = {};
    $self->reset_puzzle();
}

sub reset_puzzle {
    my $self = shift;
    
    my $stats = $self->{'GAMESTATS'};
    
    # get new puzzle data
    opendir SUBSTRDIR, "substr/" or die "Could not open substr dir: $!";
    my @files = readdir SUBSTRDIR;
    closedir SUBSTRDIR;
    
    my $fname = $files[int rand @files];

    $fname =~ /^(\w+)/;
    $stats->{'SUBSTR'} = $1;
#$self->say("Substr is $stats->{'SUBSTR'}");
    $stats->{'WORDS'} = {};
    
    open F, "substr/$fname" or die "Could not open $fname: $!";
    while (my $line = <F>) {
        my ($points, $word) = $line =~ /(\d+):(.+)$/ or next;
#$self->say("Word $word is worth $points points");
        $stats->{'WORDS'}->{lc $word} = { 'POINTS' => $points, "GUESSEDSTR" => "-" x length($word), 'GUESSEDBY' => undef };
    }
    close F;
    
    $self->send_game_board();
}

sub send_game_board {
    my $self = shift;

    my $stats = $self->{'GAMESTATS'};

    $self->room_tell("{7}The current substring is: {17}$self->{'GAMESTATS'}->{'SUBSTR'}\{7}.\n");
    $self->room_tell("{7}".$self->get_words_unguessed()." words have not been guessed yet:\n");
    
    my $colno = 0;
    my $cap = "";
    foreach my $word (keys %{$stats->{'WORDS'}}) {
        my $data = $stats->{'WORDS'}->{$word};
        next if $data->{'GUESSEDBY'};
        $cap .= sprintf("%-20s", $data->{'GUESSEDSTR'});
        $cap .= "\n" unless ++$colno % 3;
    }
    $cap .= "\n" if $colno % 3;
    $self->room_tell($cap);
}

sub guess_word {
    my ($self, $guessed_word, $who) = @_;
    $guessed_word = lc $guessed_word;
    
    my $stats = $self->{'GAMESTATS'};

    foreach my $word (keys %{$stats->{'WORDS'}}) {
        my $data = $stats->{'WORDS'}->{$word};
        next if $data->{'GUESSEDBY'};

        # direct match? ooh cool!
        if ($guessed_word eq $word) {
            # Give credit where it's due
            $data->{'GUESSEDBY'} = $who;
            my $hyphen_count = 0;
            map { $hyphen_count++ if $_ eq "-" } split //, $data->{'GUESSEDSTR'};
            my $points = int($data->{'POINTS'} * $hyphen_count / length($word));
            $self->say("$who guessed '$guessed_word', earning $points points (originally worth $data->{'POINTS'}).");
            
            # Then cycle around and reveal pieces of the unguessed ones
            $self->reveal_unguessed_substr($guessed_word);
            
            # and show scoreboard
            $self->send_game_board();
            
            last;
        }
    }
    
}

sub reveal_random_letter {
    my $self = shift;
    
    my %letters;

    my $stats = $self->{'GAMESTATS'};
    
    foreach my $word (keys %{$stats->{'WORDS'}}) {
        my $data = $stats->{'WORDS'}->{$word};
        next if $data->{'GUESSEDBY'};
        map { $letters{$_}++ } grep { $data->{'GUESSEDSTR'} !~ /$_/ } $word =~ /([^-])/g;
    }
    
    my @letters = sort { $letters{$b} <=> $letters{$a} } keys %letters;
    $self->reveal_unguessed_substr($letters[0]);
}


sub reveal_unguessed_substr {
    my ($self, $substr) = @_;

    my $stats = $self->{'GAMESTATS'};
    
    foreach my $word (keys %{$stats->{'WORDS'}}) {
        my $data = $stats->{'WORDS'}->{$word};
        next if $data->{'GUESSEDBY'};
        
        for (my $i=0; $i<length($word); ++$i) {
            if (substr($word, $i, length($substr)) eq $substr) {
                substr($data->{'GUESSEDSTR'}, $i, length($substr)) = $substr;
            }
        }
        
    }
}

sub get_wordcount() {
    my $self = shift;
    my $stats = $self->{'GAMESTATS'};

    return scalar keys %{$stats->{'WORDS'}};
}

sub get_words_unguessed() {
    my $self = shift;
    my $stats = $self->{'GAMESTATS'};

    return scalar grep { !$_->{'GUESSEDBY'} } values %{$stats->{'WORDS'}};
}

package trigger_ele_ward_new;
@trigger_ele_ward_new::ISA = qw( item );
use strict;

# TRIGKEY: keyphrase (case insensitive) to trigger
# ELEMKEY: elemental key (F is fire, etc)
# TRIGREPLY: phrase it says on success. types \n for you

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if(index(lc($saystr), lc($self->{'TRIGKEY'})) == 0) { 
    my $troom = $main::map->[$main::roomaliases{'dplane_icethrone'}];
    
    if($main::puzzles->{'ele_ward_new'} =~ /$self->{'ELEMKEY'}/) {      
      $obj->log_append("{7}Nothing Happens.\n");
    } else { 
      $self->room_sighttell($self->{'TRIGREPLY'}."\n");
      $main::puzzles->{'ele_ward_new'}.= $self->{'ELEMKEY'};
      
      if(length($main::puzzles->{'ele_ward_new'}) >= 4) {
       $self->room_talktell("{3}A loud grating sound can be heard in the distance.\n");
       $troom->room_sighttell("{16}The elemental seal in the ceiling {16}collapses.\n");
       $troom->{'U'}->[1]=0; # allow entry
       $troom->{'U'}->[2]=1;
       delete $main::puzzles->{'ele_ward_new'};
      }
    }
  } else {
   # if they tried guessing one and got it wrong...ooooohhh
   $saystr = lc($saystr);
   if(index($saystr, 'the ')==0) { 
      for (my $n=0; $n<=$#main::parch_codes; $n++) {
        if($saystr eq $main::parch_codes[$n]) {
          # punish them for guessing the worng one
          $obj->teleport($main::roomaliases{'death_pit'});
          my $ghost = $obj->assassin_haunt();
          $ghost->{'NAME'}='Ice Stalker';
          $ghost->{'INVIS'}=1;
          $ghost->{'NOBOUNTY'}=1;
          $ghost->{'BASEH'}=10000;
          $ghost->{'DESC'}='A slight disturbance shifts through the air here, creating a vague outline of a massive humanoid. It appears to be at least seven feet tall, but from the faded silloute it is impossible to be sure. The stentch of powerful magic hangs around the form, revealing its true nature.';
          $ghost->power_up;
          $self->room_sighttell("{14}A wave of magic ripples through the room as if some sort of alarm has been triggered!\n");
        }
      }
     } 
  }
  return;
}

package trigger_ele_ward;
@trigger_ele_ward::ISA = qw( item );
use strict;

# TRIGKEY: keyphrase (case insensitive) to trigger
# ELEMKEY: elemental key (F is fire, etc)
# TRIGREPLY: phrase it says on success. types \n for you

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if(index(lc($saystr), lc($self->{'TRIGKEY'})) == 0) { 
    my $troom = $main::map->[$main::roomaliases{'dplane_bonethrone'}];
    
    if($main::puzzles->{'ele_ward'} =~ /$self->{'ELEMKEY'}/) {      
      $obj->log_append("{7}Nothing Happens.\n");
    } else { 
      $self->room_sighttell($self->{'TRIGREPLY'}."\n");
      $main::puzzles->{'ele_ward'}.= $self->{'ELEMKEY'};
      
      if(length($main::puzzles->{'ele_ward'}) >= 4) {
       $self->room_talktell("{3}A loud grating sound can be heard in the distance.\n");
       $troom->room_sighttell("{16}The elemental seal to the {6}north {16}collapses.\n");
       $troom->{'N'}->[1]=0; # allow entry
       $troom->{'N'}->[2]=1;
       delete $main::puzzles->{'ele_ward'};
      }
    }
  } else {
   # if they tried guessing one and got it wrong...ooooohhh
   $saystr = lc($saystr);
   if(index($saystr, 'the ')==0) { 
      for (my $n=0; $n<=$#main::parch_codes; $n++) {
        if($saystr eq $main::parch_codes[$n]) {
          # punish them for guessing the worng one
          $obj->teleport($main::roomaliases{'death_pit'});
          my $ghost = $obj->assassin_haunt();
          $ghost->{'NAME'}='Invisible Stalker';
          $ghost->{'INVIS'}=1;
          $ghost->{'NOBOUNTY'}=1;
          $ghost->{'BASEH'}=10000;
          $ghost->{'DESC'}='A slight disturbance shifts through the air here, creating a vague outline of a massive humanoid. It appears to be at least seven feet tall, but from the faded silloute it is impossible to be sure. The stentch of powerful magic hangs around the form, revealing its true nature.';
          $ghost->power_up;
          $self->room_sighttell("{14}A wave of magic ripples through the room as if some sort of alarm has been triggered!\n");
        }
      }
     } 
  }
  return;
}

package trigger_exit_unexact;
@trigger_exit_unexact::ISA = qw( trigger_exit_exact );
use strict;

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if ($saystr =~ /$self->{'TRIGKEY'}/i) { 
      $self->execute_create_exit_trigger();
  }
  return;
}

package trigger_exit_explode;
@trigger_exit_explode::ISA = qw( trigger_exit_exact );
use strict;
use Carp;

# WARNING: this class requires the exit to be hidden/visible on both sides
#          (kind of like a door), or evil things will happen. So you can't have
#          it be a one-way exit.

sub def_set {
    my ($self) = @_;
    $self->SUPER::def_set(@_[1..$#_]);

    $self->{'TRIGEXPLODEKJ'} = $self->{'TRIGEXPLODEMAXKJ'};
}

sub on_explosion() {
    my ($self, $explodeobj, $kj, $attack, $dir) = @_;

    my $neighboring_room = $self->room()->get_room_by_exit($self->{'TRIGEXIT'});

    confess "I have no neighboring room!" unless $neighboring_room;    

    return unless $kj > 0;
    return unless $attack <= 2; # only honor attacks 1 room away, tops

    $self->{'TRIGEXPLODEKJ'} -= int $kj;
#    $self->say("yumm $kj kj hit; $self->{'TRIGEXPLODEKJ'}/$self->{'TRIGEXPLODEMAXKJ'} to go.");
#    $self->say("$attack, $dir");


    if ($self->{'TRIGEXPLODEKJ'} <= 0) {
        # wall is destroyed (or whatever it is)
        if ($self->{'TRIGEXPLODEFINALMSG'}) {
            $self->room_sighttell($self->{'TRIGEXPLODEFINALMSG'});
            $neighboring_room->room_sighttell($self->{'TRIGEXPLODEFINALMSG'});
        }

        $self->execute_create_exit_trigger();
        $self->execute_create_exit_trigger(1); # other side

        # time an auto-respawn if we can
        my $cby = $self->container() || $self->room();
        $main::eventman->enqueue($self->{'TRIGEXPLODERESPAWN'}, \&rockobj::item_spawn, $cby, $self->{'REC'})
            if $self->{'TRIGEXPLODERESPAWN'} && $cby;

        $self->dissolve_allsubs();
    } else {
        # only partially done
        if ($self->{'TRIGEXPLODEFINALMSG'}) {
            $self->room_sighttell($self->{'TRIGEXPLODEPARTIALMSG'});
            $neighboring_room->room_sighttell($self->{'TRIGEXPLODEPARTIALMSG'});
        }

        # pass it on
        return $self->SUPER::on_explosion(@_[1..$#_]);
    }
}

package trigger_exit_dig;
@trigger_exit_dig::ISA = qw( trigger_exit_exact );
use strict;

sub dug ($sayerobj, $what_they_said) {
  my ($self, $who) = @_;
  if ($self->is_my_trigexit_open()) {
      $who->log_error("There is no need to dig the $self->{'NAME'}.");
  } else {
      $who->log_append("{7}You dig the $self->{'NAME'}.\n");
      $who->room_sighttell("{7}$who->{'NAME'} does something behind your back.\n");
      $self->execute_create_exit_trigger();
  }
  return;
}

package trigger_exit_open;
@trigger_exit_open::ISA = qw( item );
use strict;

sub on_open  {
	my ($self, $opener) = @_;
	if ($self->is_my_trigexit_open()) {
    	$opener->log_error("The $self->{'NAME'} is already open.");
	} else {
		$opener->log_append("{3}You open the $self->{'NAME'}.\n");
		$opener->room_sighttell("{3}$opener->{'NAME'} opens the $self->{'NAME'}\n");
		$self->execute_create_exit_trigger();  # add my exit
		$self->execute_create_exit_trigger(1); # add other room's exit
	}
}

sub on_close {
    my ($self, $who) = @_;
	if ($self->is_my_trigexit_open()) {
	    # close it
		$who->log_append("{3}You close the $self->{'NAME'}.\n");
		$who->room_sighttell("{3}$who->{'NAME'} closes the $self->{'NAME'}\n");
		$self->execute_remove_exit_immediate_trigger(); # remove my exit
		$self->execute_remove_exit_immediate_trigger(1); # remove other room's exit
	} else {
	    $who->log_error("The $self->{'NAME'} is already closed.");
	}
}


package item_loose_panel;
@item_loose_panel::ISA = qw( trigger_exit_exact );
use strict;

sub smashed{ return &item_loose_panel::bashed(@_); }
sub bashed{ 
    my ($self, $who) = @_;
    if($who->can_do(0,int $who->{'MAXH'}*.15,10)) {
        $who->log_append("{17}You bash your body into $self->{'NAME'}.\n");
        $who->room_sighttell("{17}With a running start, $who->{'NAME'} bashes $who->{'PPOS'} body into $self->{'NAME'}.\n");
        
        if( rand(3) < ($who->fuzz_pct_skill(0) + $who->fuzz_pct_skill(3) + $who->fuzz_pct_skill(4))/2 ) {
           my @a = @{$main::entropy{$self->{'ENTROPY_KEY'}}};
           $self->room_talktell("{5}A crackling voice escapes from the panel: {14}\"{4}".$a[int rand($#a) + 1]."{14}\"\n" );
        }
    }
}

package trigger_bodypart_panel;
@trigger_bodypart_panel::ISA = qw( item );
use strict;

# If you use a bodypart on this trigger, and the bodypart's rec value is found
# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is either a hand or eye, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You hold the $item->{'NAME'} against the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} places $item->{'NAME'} against the $self->{'NAME'}.\n");

		if ($item->{'CRTRREC'} && 
	    	($self->{'TRIGCRTRREC'} =~ /\b$item->{'CRTRREC'}\b/) &&
			($item->{'NAME'} =~ /^(hand|eye) of/)) {
        	$self->execute_create_exit_trigger();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} beeps, flashing a bright {1}red {7}LED.\n");
		}
	} 
	
  	return 1; # success - they did something worthwhile
}


package trigger_exit_exact;
@trigger_exit_exact::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='trigger' unless $self->{'NAME'};
  $self->{'FPAHD'}='trigged';  $self->{'FPSHD'}='trig';
  $self->{'TPAHD'}='trigged';  $self->{'TPSHD'}='trigs';
  $self->{'DLIFT'}=''; $self->{'CAN_LIFT'}='';
  # SPECIAL
#  $self->{'TRIGKEY'}='' unless $self->{'TRIGKEY'};
  $self->{'TRIGEXIT'}= uc($self->{'TRIGEXIT'});
#  $self->{'TRIGEXITCNT'}=1 unless $self->{'TRIGEXITCNT'};
#  $self->{'TRIGIMMEDREPLY'}='' unless $self->{'TRIGIMMEDREPLY'};
#  $self->{'TRIGDELAYREPLY'}='' unless $self->{'TRIGDELAYREPLY'};
#  $self->{'TRIGDELAY'}='' unless $self->{'TRIGDELAY'};
  return($self);
}

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if($self->{'TRIGKEY'} && $saystr eq $self->{'TRIGKEY'}) { 
      $self->execute_create_exit_trigger();
  }
  return;
}

package explosive_sensitive;
@explosive_sensitive::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='explosive' unless $self->{'NAME'};
  $self->{'XPLODETIME'}=7 unless $self->{'XPLODETIME'};
  $self->{'XPLODEPCT'}=70 unless $self->{'XPLODEPCT'};
  $self->{'RACEFRIENDLY'}=1 unless $self->{'RACEFRIENDLY'};
  $self->{'FLAM'}=90 unless $self->{'FLAM'};
  $self->{'KJ'}=20000 unless $self->{'KJ'};
  $self->{'EXPLOSIVE'}=1;
  $self->{'FPAHD'}='thwacked';  $self->{'FPSHD'}='thwack';
  $self->{'TPAHD'}='thwacked';  $self->{'TPSHD'}='thwacks';
  return($self);
}

sub on_detab {
   my ($self, $igniter) = @_;
   if(!$self->{'XPLODETIME'}) { $igniter->log_append("{13}Fool! That will never explode!\n"); }
   else { 
     $igniter->log_append("{13}You proceed to arm $self->{'NAME'}.\n");
     $igniter->room_sighttell("{13}$igniter->{'NAME'} {7}does something while your back is toward $igniter->{'PPRO'}.\n");
     if(!$main::events{$self->{'OBJID'}}) { $self->{'ARMED'}=1; $self->{'RACE'}=$igniter->{'RACE'}; }
   }
   return;
}

#my ($r, %h); foreach $r (@{$main::map}) { if(!defined($h{$r->{'M'}})) { $h{$r->{'M'}}=$r->{'ROOM'}; $_[0]->log_append($r->{'ROOM'}." "); } }; 
#0 1 20 65 94 95 198 249 288 313 399 425 438 440 487 505 522 549 627
#my $p; foreach $p (values(%{$main::objs})) { $p->{'CRYL'}=0; }
sub on_room_enter (who, direction from) {
  my ($self, $who, $dir) = @_;
  if(ref($who) eq 'garbagetruck') { return; }
  if($self->{'RACEFRIENDLY'} && ( ($who->{'RACE'} == $self->{'RACE'}) || $main::allyfriend[$self->{'RACE'}]->[$who->{'RACE'}]) ) { return; }
  if( rand(100) < $self->{'XPLODEPCT'} ){ $self->explode(); }
  else {
    if( rand(200) < $self->{'XPLODEPCT'} ) { 
      $who->log_append("{07}You hear a clicking sound as you enter the room.\n");
      $main::events{$self->{'OBJID'}}=int rand(8) + 4;
    }
  }
  return;
}

sub on_event {
  my $self = shift; $self->explode();
  return;
}

package explosive_timed;
@explosive_timed::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='explosive' unless $self->{'NAME'};
  $self->{'XPLODETIME'}=15 unless $self->{'XPLODETIME'};
  $self->{'XPLODEPCT'}=70 unless $self->{'XPLODEPCT'};
  $self->{'FLAM'}=90 unless $self->{'FLAM'};
  $self->{'KJ'}=20000 unless $self->{'KJ'};
  $self->{'EXPLOSIVE'}=1;
  $self->{'FPAHD'}='thwacked';  $self->{'FPSHD'}='thwack';
  $self->{'TPAHD'}='thwacked';  $self->{'TPSHD'}='thwacks';
  return($self);
}

sub can_enter (roomid) {
 if( rand(100) < .5 ) { 
   $_[0]->{'ROOM'}=$_[1]; $_[0]->room_sighttell("{3}$_[0]->{'NAME'} {13}seems very unstable.\n");
   $_[0]->explode();
 }
 return 1;
}

sub on_ignite { 
   my ($self, $igniter) = @_;
   if(!$self->{'XPLODETIME'}) { $igniter->log_append("{13}Fool! That will never explode!\n"); }
   else { 
     $igniter->log_append("{13}You proceed to ignite $self->{'NAME'}.\n");
     $igniter->room_sighttell("{13}$igniter->{'NAME'} proceeds to {11}ignite{13} $self->{'NAME'}.\n");
     if(!$main::events{$self->{'OBJID'}}) { $main::events{$self->{'OBJID'}}=$self->{'XPLODETIME'}; $self->{'RACE'}=$igniter->{'RACE'}; }
   }
   return;
}

sub on_event {
    my $self = shift;
    #mich - don't explode in safe rooms
    if( $self->room()->{'SAFE'} ) {
        $self->room_sighttell("{13}$self->{'NAME'}'s fuse glows in and out of vision.\n");
        return;
    }        
    if( rand(100) < $self->{'XPLODEPCT'} ) {
        $self->explode($self->{'XPLODEROOMS'} || undef);
    } else {
        $self->room_sighttell("{13}$self->{'NAME'}'s fuse glows in and out of vision.\n");
        # check again, double odds. maybe relight it.
        if( rand(200) < $self->{'XPLODEPCT'} ) {
            $main::events{$self->{'OBJID'}}=int rand(10) + 1;
        }
    }
    return;
}

package clock;
@clock::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='clock' unless $self->{'NAME'};
  $self->{'FPAHD'}='gave the time to';  $self->{'FPSHD'}='give the time to';
  $self->{'TPAHD'}='gave the time to';  $self->{'TPSHD'}='gives the time to';
  return($self);
}
sub dam_bonus { 8 }

sub desc_get {
  my $self = shift;
  return ($self->desc_hard . "\n".'{13}The time is now: {5}'.&main::time_get(0,0).'{13}.');
}

sub on_event {
  my $self = shift;
  $self->room_talktell("{13}The clock startles you with an annoying ring!\n");
  return;
}

sub on_wind { 
   my ($self, $winder) = @_;
   $winder->log_append("{2}You wind $self->{'NAME'}.\n");
   $winder->room_sighttell("{2}$winder->{'NAME'} winds up $self->{'NAME'}.\n");
   $main::events{$self->{'OBJID'}}=5;
   return;
}


package debris;
@debris::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='debris' unless $self->{'NAME'};
  $self->{'FPAHD'}='brushed at';  $self->{'FPSHD'}='brush at';
  $self->{'TPAHD'}='brushed at';  $self->{'TPSHD'}='brushes at';
  return($self);
}

sub dam_bonus { return(0); }

package garbagetruck;
@garbagetruck::ISA = qw( item );
use strict;
# goes around picking up (and disposing of) garbage.

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='garbagetruck' unless $self->{'NAME'};
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  $self->{'EXP'}->[17]=1000000000; $self->{'EXP'}->[18]=1000000000;
  $self->{'IMMORTAL'}=1;
  $self->{'MAXINV'}=1000;
  return($self);
}

sub garbagetruck::on_idle {
  my $o;
  my $self=shift;
  if($self->{'ROOM'} == $self->{'DUMPROOM'}) {
  # $self->log_append("i'm in the dump room...\n");
    if($self->inv_objsnum) {
     $self->room_sighttell("{3}$self->{'NAME'} {4}empties $self->{'PPOS'} smelly contents; most of them simple compost.\n");
     $self->inv_remove;
    }
  } else {
    #$self->log_append("picking something up.\n");
     $o = $self->pick_something_up;
  }
  if($o) { $main::events{$self->{'OBJID'}}=1; }
  elsif($self->{'ROAMTARG'} && ($self->{'ROOM'} != $self->{'ROAMTARG'})) {
      my $moved = $self->auto_move_targ;
     # $self->say("Moved: $moved");
      $main::events{$self->{'OBJID'}}=1;
      if(!$moved) { $self->{'ROAMTARG'} = $self->{'DUMPROOM'}; }
  } else { 
    if(!$self->ai_roamtarg_garbage) {
  #  $self->log_append("going to the dump.\n");
      $self->{'ROAMTARG'}=$self->{'DUMPROOM'};
      if($self->{'ROOM'} != $self->{'DUMPROOM'}) { $main::events{$self->{'OBJID'}}=1; }
    } else { $main::events{$self->{'OBJID'}}=1; } 
    $self->auto_move_targ;
  }
  return;
}

sub on_event {  $_[0]->on_idle; }

sub on_open {
 my ($self, $by) = @_;
  		#$self->room_sighttell("{2}$uid->{'NAME'} is wisked away.\n");
  		$by->teleport($main::roomaliases{'mists'});
  		return;
}

package body_slicer;
@body_slicer::ISA = qw( item );
use strict;


sub on_hit {
    my ($self, $victim) = @_;
    if(rand(200)<2) { delete ( ($victim->bodypart_drop('skin'))->{'BOUNTYFROM'} ); } # was 20<2
}


package small_map;
@small_map::ISA = qw( item );
use strict;

sub desc_get {
  my ($self, $who) = @_;
  return $self->desc_hard unless $who;
  
  if(!$who->inv_has($self)) { return($self->desc_hard); }
  else { 
    my $room = $main::map->[$self->{'ROOM'}];
    return($self->desc_hard."\n{1}Several jewels glitter softly...\n".&main::lifeform_scan($room->{'M'},$room->{'Z'},$room->{'X'},$room->{'Y'},$room->{'Z'},1).'{6}...altering your mood to a peaceful state');
  }
}

package arena_map;
@arena_map::ISA = qw( item );
use strict;

sub desc_get {
  my ($self, $who) = @_;
    my $rooma = $main::map->[$main::roomaliases{'assstart1'}];
    my $roomb = $main::map->[$main::roomaliases{'assstart2'}];
    return($self->desc_hard."\n".&main::brief_map_floor_lifeform($rooma->{'M'},$rooma->{'Z'},$rooma->{'X'},$rooma->{'Y'},$rooma->{'Z'},1).&main::brief_map_floor_lifeform($roomb->{'M'},$roomb->{'Z'},$roomb->{'X'},$roomb->{'Y'},$roomb->{'Z'},1));
}

package bodypart;
@bodypart::ISA = qw( debris );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='body part' unless $self->{'NAME'};
  $self->{'FPAHD'}='brushed at';  $self->{'FPSHD'}='brush at';
  $self->{'TPAHD'}='brushed at';  $self->{'TPSHD'}='brushes at';
  return($self);
}

sub dam_bonus { return(int rand(20)); }

package arena_battleaxe;
@arena_battleaxe::ISA = qw( item );
sub dam_bonus { if(rand(10)>.5) { return(int rand($_[0]->{'WC'})); } else { return(10000000 + int rand(1000000)); } }

#package weapon;
#@weapon::ISA = qw( item );
#use strict;
#
#sub def_set {
#  my $self = shift;
#  $self->prefmake_item;
#  $self->{'NAME'}='body part' unless $self->{'NAME'};
#  $self->{'FPAHD'}='slashed';  $self->{'FPSHD'}='slash';
#  $self->{'TPAHD'}='slashed';  $self->{'TPSHD'}='slashes';
#  return($self);
#}

package store;
@store::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='store' unless $self->{'NAME'};
  $self->{'INVIS'}=1; $self->{'DLIFT'} = $self->{'LIFT'} = '';
  $self->{'MAXINV'}=80 unless ($self->{'MAXINV'}>80);
  $self->{'MARKUP'}=1.1 unless $self->{'MARKUP'};
  $self->{'MARKDOWN'}=0.2 unless $self->{'MARKDOWN'};
  $self->{'FPAHD'}='storified';  $self->{'FPSHD'}='storify';
  $self->{'TPAHD'}='storified';  $self->{'TPSHD'}='storifies';
  return($self);
}

sub desc_get {
 # returns string of item's description.
 my $self = shift;
 # vars
 my ($cap, $i);
 my @items = $self->inv_objs();
 $cap = $self->desc_hard."\n";
 if(!@items) {
     $cap .= "It does not appear to be selling anything at the moment.";
 } else {
     # header
     $cap .= "{40}This shop appears to be selling the following items:\n";
     $cap .= '{16}+{6}'.('=' x 68)."{16}+\n";
     $cap .= sprintf("{16}|{13} %20s %-55s {16}|\n", substr($self->{'NAME'},0,20), '{2}(owned by {14}'.($self->{'OWN'} || 'Outcasts').'{2})');
     $cap .= '{16}+{6}'.('=' x 68)."{16}+\n";
     # list items.
     my (%inameCount, %inameVal);
     foreach $i (@items) { $inameCount{$i->{'NAME'}}++; $inameVal{$i->{'NAME'}}+=$i->{'VAL'}; }
     foreach my $iname (sort keys(%inameCount)) {
       $cap .= sprintf("{16}|{12} %39s %s {15}~%-7d cryl{16} |\n", length($iname)>39?substr($iname,0,36).'{2}...':$iname, ($inameCount{$iname}>1?sprintf('{4}({14}%2d {5}stocked{4})', $inameCount{$iname}):' 'x12), int ($inameVal{$iname}/$inameCount{$iname}*$self->{'MARKUP'}));
     }
     $cap .= '{16}+{6}'.('=' x 68)."{16}+{41}";
 }
 return($cap);
}

sub inv_cleanup {
  my $self = shift;
  # first, get rid of all non-store items.
  $self->inv_remnodb;
  if(!$self->{'MAXDBINV'} || ($self->{'MAXDBINV'}<0)) { return; }
  my $n = scalar $self->inv_objs;
  $n = $n - $self->{'MAXDBINV'};
  # if i have more DB objects than i should, (if n > 0)...
  while($n>0) {
    my ($blank, $obj) = each (%{$self->{'INV'}});
    if($obj) { $obj->dissolve_allsubs(); }
  }
  return;
}


package orc_guard_bri;
@orc_guard_bri::ISA = qw( npc );

sub on_cryl_receive {
  my ($self, $amt, $from) = @_;
  if($amt < 250) { 
     $self->cryl_give($amt, $from);
     $self->say_rand("Hmm, I seem to have forgotton how to operate this thing..maybe some more cryl would freshen my memory!", "Yawn..I've got better things to do.", "I'm sorry, did you drop this?");
     return;
  }
  if(defined($main::events{$self->{'OBJID'}})) {
     $self->room_talktell("{6}\"The bridge is already open, ya idiot!\" {7}The guard says, though stuffs the money into his coin purse regardless.\n");
     return;
  }
  #delete $self->{'CRYL'};
  $self->room_sighttell("{13}$self->{'NAME'} {2}walks over to a large lever and pulls it.\n{3}A loud grating sound echoes through the marshland, as the drawbridge slowly lowers.\n");
  # allow entry
  if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0] || !$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]) { return; }
  $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0;
  $main::map->[$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->{$self->{'TRIGEXIT'}}->[0]]->{$main::diroppmap{$self->{'TRIGEXIT'}}}->[1]=0;
  $main::map->[$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->{$self->{'TRIGEXIT'}}->[0]]->room_sighttell("{3}A loud grating sound echoes through the marshland, as the drawbridge slowly lowers.\n");
  # set event for lowering
  $main::events{$self->{'OBJID'}}=60 unless defined($main::events{$self->{'OBJID'}});
  return;
}

sub on_event { 
  my $self = shift;
  $self->room_sighttell("{3}Slowly the drawbridge raises, once again preventing passage to the $main::dirlongmap{$self->{'TRIGEXIT'}}.\n");
  # turn off the entry exit
  if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0] || !$main::map->[$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->{$self->{'TRIGEXIT'}}->[0]]->{$main::diroppmap{$self->{'TRIGEXIT'}}}->[0]) { return; }
  $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=1;
  $main::map->[$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->{$self->{'TRIGEXIT'}}->[0]]->{$main::diroppmap{$self->{'TRIGEXIT'}}}->[1]=1;
  $main::map->[$main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->{$self->{'TRIGEXIT'}}->[0]]->room_sighttell("{3}Slowly the drawbridge raises, once again preventing passage to the $main::dirlongmap{$main::diroppmap{$self->{'TRIGEXIT'}}}.\n");
  # tilty bridge!
  foreach my $o ($main::map->[$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]]->inv_objs) {
   if ( (($o->{'TYPE'}==1) || ($o->{'TYPE'}==2)) && !$o->{'FX'}->{'7'} ) { 
     $o->log_append("{3}As the drawbridge raises, you feel a momentous force hurdling you $main::dirlongmap{$main::diroppmap{$self->{'TRIGEXIT'}}}ward.\n"); 
     $o->{'ENTMSG'}='tumbles in';
     $o->{'LEAMSG'}='tumbles down';
     $o->realm_move($main::diroppmap{$self->{'TRIGEXIT'}});
     delete $o->{'ENTMSG'};
     delete $o->{'LEAMSG'};
   }
  }
  return;
}

sub on_ask {
 my ($self, $topic, $from) = @_;
 if ($topic =~ /bridge|open/) { $self->say_rand('You want this bridge down or something? Hm..well, I don\'t know if I can help YOU..', 'you want to get through? it has a price attached..' );  }
 elsif ($topic =~ /price|cost|cryl/) { $self->say('Gee..I could really use 300 cryl..');  }
 else { return undef; }
 return("");
} 

package slot_machine;
@slot_machine::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='slot machine' unless $self->{'NAME'};
  $self->{'WINPCT'}=20 unless $self->{'WINPCT'};           # percent chance of win
  $self->{'AWARDPCT'}=12 unless $self->{'AWARDPCT'};       # amount the player is rewarded
  $self->{'DELAY'}=3 unless $self->{'DELAY'};              # delay for results
  $self->{'COSTPERPLAY'}=10 unless $self->{'COSTPERPLAY'}; # cost in cryl
  $self->{'CONTAINER'}=1;
  $self->{'CRYL'}=100 unless $self->{'CRYL'}; # starting cash
  $self->{'FPAHD'}='slotted';  $self->{'FPSHD'}='slot';
  $self->{'TPAHD'}='slotted';  $self->{'TPSHD'}='slots';
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  return($self);
}

sub on_cryl_receive {
  my ($self, $amt, $from) = @_;
  
  if(($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) && $self->{'AI'}->{'LASTPLYR'} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}} && ($main::objs->{$self->{'AI'}->{'LASTPLYR'}} ne $from) && $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->shares_room($self) ) {
    $self->cmd_do("tell $from->{'NAME'} Someone's already playing - please wait till this fellow is finished.");
    $self->cmd_do("give $amt to $from->{'NAME'}");
    return;
  }
  $self->{'CRYL'}-=$amt;
  $self->{'AI'}->{'COINHOLDER'}+=$amt;
  $self->{'AI'}->{'LASTPLYR'}=$from->{'OBJID'};
  if($main::events{$self->{'OBJID'}}) { return; }
  if($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) { 
    $self->room_sighttell("{6}$self->{'NAME'}'s {7}lights flicker on and off as it begins to quietly hum.\n");
    $main::events{$self->{'OBJID'}}=$self->{'DELAY'};
  } else {
    $self->say('Please insert '.($self->{'COSTPERPLAY'}-$self->{'AI'}->{'COINHOLDER'}).' more cryl to play.');
  }
  return;
}

sub on_event {
  my $self = shift;
  $self->{'CRYL'} += $self->{'COSTPERPLAY'};
  $self->{'AI'}->{'COINHOLDER'} -= $self->{'COSTPERPLAY'};
  if( rand(100) < $self->{'WINPCT'} ) { 
    $self->room_sighttell("{1}$self->{'NAME'} illuminates $main::map->[$self->{'ROOM'}]->{'NAME'} with a burning shade of red.\n");
    my $amt = int ($self->{'CRYL'}*$self->{'AWARDPCT'}/100);
    $self->say_rand('We have a winner!', 'You win! You win!', 'Winner! Winner! Winner!', 'Congratulations!', 'Beep beep booh bahhh beep...', 'Reeooooww! Reooooooww! Meeep meep!', 'Ding ding ding ding!');
    if($self->{'AI'}->{'LASTPLYR'} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->shares_room($self) ) {
       $self->cmd_do("give $amt to $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->{'NAME'}");
    } else {
       $self->cmd_do("unloot $amt");
    }
  } else {
    # llllooooooooooooser... lewwwwwwwwzerrrrr!
    #$self->room_talktell("{7}$self->{'NAME'} dims to a quiet whisper.\n");
    $self->say_rand('Tough luck. Please try again.', 'You lose. Please try again.', 'Ooba Ooba. Please try again.', 'No win. Please try again.', 'Loser! Please try again.', 'You lost. Please try again.', 'Sorry, no win. Please try again.'); 
  }
  if($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) { 
    $self->room_sighttell("{6}$self->{'NAME'}'s {7}lights flicker on and off as it begins to quietly hum.\n");
    $main::events{$self->{'OBJID'}}=$self->{'DELAY'};
  }
  return;
}

sub on_idle {
 my $self = shift;
 if ( (rand(10)>2) || ($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) ) { return; }
 $self->say('Could YOU become a cryllionaire? Try your luck at the fascinating game of slots. Just put cryl into me and you\'re on your way to richness! Only '.$self->{'COSTPERPLAY'}.' cryl per play!');
 return;
}

package item_flag_affector;
@item_flag_affector::ISA = qw( item );
use strict;

# note: since item_flag_affector uses an eval() statement, it is potentially
# extremely dangerous to the game. because of this, the object frame is not
# discussed, or to be discussed in any type of documentation.

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='health affector' unless $self->{'NAME'};
  # special
  $self->{'FLAGEVAL'}='' unless $self->{'FLAGEVAL'};
  $self->{'FLAGTPMSG'}='An odd feeling washes over %R.' unless $self->{'FLAGTPMSG'};
  $self->{'FLAGFPMSG'}='An odd feeling washes over you.' unless $self->{'FLAGFPMSG'};
  # /special
  $self->{'FPAHD'}='BUGGY BUGged';  $self->{'FPSHD'}='BUGGY BUG';
  $self->{'TPAHD'}='BUGGY BUGged';  $self->{'TPSHD'}='BUGGY BUGs';
  $self->{'!SAVE'}=1;
  return($self);
}

sub on_buy (buyer, store) {
  my ($self, $buyer, $store) = @_;
  if(!$self->{'FLAGEVAL'}) { return; }
  # prep message
  my (@msg) = ($self->{'FLAGTPMSG'},$self->{'FLAGFPMSG'});
  grep {  s/\%PS/$self->{'PRO'}/g; s/\%HS/$self->{'PPOS'}/g; s/\%MS/$self->{'PPRO'}/g; s/\%S/\{16\}$self->{'NAME'}\{2\}/g; } @msg;
  grep { s/\%PR/$buyer->{'PRO'}/g; s/\%HR/$buyer->{'PPOS'}/g; s/\%MR/$buyer->{'PPRO'}/g; s/\%R/\{16\}$buyer->{'NAME'}\{2\}/g; } @msg;
  # send message
  $buyer->log_append($msg[1]."\n"); $buyer->room_tell($msg[2]."\n");
  # affect user..EVAL!
  my $r = &{$self->{'FLAGEVAL'}}($self, $buyer);
  #if(!$r) { 
  #    &main::rock_shout(undef, "{11}Error during $self->{'NAME'}'s ($self->{'OBJID'}) eval: $!. Returned $r. Model: ".ref($self)."\n", 1);
  #}
  # dissolve me, of course.
  $self->obj_dissolve;
  return;
}

package refining_machine;
@refining_machine::ISA = qw( item );
use strict;

sub on_inherit {
  my ($self, $obj, $from) = @_;
  # filter received items
  if($obj->{'REC'}!=309) { $obj->obj_dissolve(); }
  return;
}

sub on_wind {
  my ($self, $who) = @_;
  my $total;
  $who->room_sighttell("{3}$who->{'NAME'} does something behind your back.\n");
  $who->log_append("{3}You wind $self->{'NAME'}.\n");
  foreach my $obj ($self->inv_objs) { 
     $total += int rand(25)+1;
     $obj->obj_dissolve();
  }
  if(!$total) { return; }
  $main::map->[$self->{'ROOM'}]->{'CRYL'}+=$total;
  $self->room_sighttell("{3}A steady stream of smoke pours from the machine, followed by {13}".$total."{3} cryl.\n");
}

package item_rosewood_wand;
@item_rosewood_wand::ISA = qw( item );
use strict;

sub on_use {
    my ($self, $user) = @_;
    if($self->{'USES'}-- > 0) { $user->spell_lifeshield(1); }
    else { $user->log_append("Nothing happens.\n"); }
}

package waveskimmer;
@waveskimmer::ISA = qw( item );
use strict;

sub on_enter {
  # when a player enters the object..routes them via portal.
  my ($self, $obj) = @_;
  if(!$obj->{'ADMIN'}) { $obj->log_append("{3}Do you look like an admin? I think not!\n"); return 0; }
  if(!$self->inv_free()) { $obj->log_append("{3}There is no room for you inside $self->{'NAME'}.\n"); return 0; }
  $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the {15}$self->{'NAME'}\{4}.\n");
  if( $obj->item_henter($self) ) {
      $obj->log_append("{2}You enter the {15}$self->{'NAME'}.\n");
      if(!$obj->is_invis()) { 
          $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the $self->{'NAME'}.\n");
      }
  }
  return 1;
}


sub cby_desc {
   my ($self, $obj) = @_;
   # users contained by me see this:
   my $room = $main::map->[$_[0]->{'ROOM'}];
   chomp(my @roomInv = ( $room->room_inv_list($obj), '{16}'.$room->exits_list($self->{'FRM'})) );
   my $cap = &main::lifeform_scan_array($room->{'M'},$room->{'Z'},$room->{'X'},$room->{'Y'},$room->{'Z'}, 2);
   $cap->[0] .= "{1}| {17}-= {14}Enviro-Term: {2}$room->{'NAME'} {17}=-\n";
   $cap->[1] .= "{1}| $roomInv[0]\n";
   $cap->[2] .= "{1}| $roomInv[1]\n";
   $cap->[3] .= "{1}| $roomInv[2]\n";
   $cap->[4] .= "{1}| $roomInv[3]\n";
   $cap->[5] .= "{1}-----/\n";
   my $cap .= join('', @$cap, $self->room_inv_list($obj));
   return(\$cap);
}

sub can_enter (roomid) {1;}
sub can_exit (roomid) {1;}

package item_southland_ship;
@item_southland_ship::ISA = qw ( item );
use strict;

@item_southland_ship::path_to = qw(s s s e s s s s);
@item_southland_ship::path_back = qw(n n n n w n n n);

sub on_enter {
    # when a player enters the object..routes them via portal.
    my ($self, $obj) = @_;
    my $cost = 150;
#    if(!$self->inv_free()) { $obj->log_append("{3}There is no room for you inside $self->{'NAME'}.\n"); return 0; }
    if($obj->{'CRYL'} < $cost) { $obj->log_append("{3}You do not have $cost cryl to pay the fare!\n"); return 0; }
    
    $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the {15}$self->{'NAME'}\{4}.\n");
    if( $obj->item_henter($self) ) {
        $obj->{'CRYL'}-=$cost;
        $obj->log_append("{2}You pay your fare and enter the {15}$self->{'NAME'}.\n");
        if(!$obj->is_invis()) { 
            $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the $self->{'NAME'}.\n");
        }
    }
    
    return 1;
}

sub c_ship_move {
    my $self = shift;
    # ROOM_AT
    # PATH_BACK
    my $going_back = \$self->{'AI'}->{'GOING_BACK'};  # use path_back instead of path_to
    my $dir_list = $$going_back ? (\@item_southland_ship::path_back) : (\@item_southland_ship::path_to);
    my $dir_next = \$self->{'AI'}->{'DIR_NEXT'};        # element to use next move
    
    if(!$$dir_next) {
        foreach my $o ($self->inv_objs) {
            $o->log_append("{2}Your ship departs.\n");
        }
    }
    
    # move to next room, increase $dir_next
    $self->realm_move($dir_list->[$$dir_next++]);
    
    # if reached destination ... 
    if($$dir_next == @$dir_list) {
        # change direction of "going back"
        $$going_back = !$$going_back;
        
        # reset direction list
        $$dir_next = 0;
        
        # dump passengers
        $self->c_dump_passengers();
        
        # move again in 60 seconds
        $self->delay_room_talktell(45, "{17}\"All aboard!\" {6}shouts the captain of the Sea Witch, {17}\"Only 150 cryl for passage!\"\n");
        $main::eventman->enqueue(60, \&c_ship_move, $self);
    } else {
        if(($$dir_next+1) == @$dir_list) {
            foreach my $o ($self->inv_objs) { $o->log_append("{2}Your ship nears the sea's shore.\n"); }
        }
        # move again in 10-15 seconds
        $main::eventman->enqueue(10 + int rand 6, \&c_ship_move, $self);
    }
}

sub on_idle { 
    my $self = shift;
    if(!$self->{'AI'}->{'ACTIVE'}) {
        $self->{'AI'}->{'ACTIVE'} = 1;
        $self->c_ship_move();
    }
}

sub c_dump_passengers {
    my $self = shift;
    $self->room_sighttell("{2}A group of passengers are rushed off the ship, and scuttle off.\n");
    foreach my $o ($self->inv_objs) {
        if($o->{'TYPE'}==1 || $o->{'TYPE'}==2) {
            if(!$o->item_henter($main::map->[$self->{'ROOM'}])) { 
                $o->log_append("{2}##### There was an error getting you off this ship. Please exit the game and email rocksupport.\n");
            } else {
                $o->log_append("{2}You are thanked for your patronage, then rushed off the ship.\n");
            }
        }
    }
}

sub can_enter { 1 };
sub can_exit { 1 };

sub cby_desc {
   my ($self, $obj) = @_;
   # users contained by me see this:
   my $room = $main::map->[$_[0]->{'ROOM'}];
   chomp(my @roomInv = ($self->room_inv_list($obj)) );
   my $cap = &main::lifeform_scan_terrain_array($room->{'M'},$room->{'Z'},$room->{'X'},$room->{'Y'},$room->{'Z'}, 2);
   $cap->[0] .= "{1}| {17}-= {14}Enviro-Term: {2}$room->{'NAME'} {17}=-\n";
   $cap->[1] .= "{1}| $roomInv[0]\n";
   $cap->[2] .= "{1}| $roomInv[1]\n";
   $cap->[3] .= "{1}| $roomInv[2]\n";
   $cap->[4] .= "{1}| $roomInv[3]\n";
   $cap->[5] .= "{1}-----/\n";
   $cap = join ('', @$cap);
   return(\$cap);
}


package item_tripwire;
@item_tripwire::ISA = qw ( item );
use strict;

sub on_room_enter {
   my ($self, $obj, $dir) = @_;
   if($self->fuzz_pct_skill(9, 100) > rand 1) {
       # didn't hit'em
       if($self->skill_has(1, 16)) { $self->log_append("{16}You notice a tripwire on the ground as you enter the room.\n"); }
       return;
   } elsif($self->{'TRIP_TYPE'} == 1) {
       my $dam = 100 + int rand 400;
       $obj->log_append("{3}A pair of darts shoot from a nearby wall, hitting you for $dam damage!\n");
       $obj->room_sighttell("{3}A pair of darts shoot from a nearby wall, hitting $obj->{'NAME'} for $dam damage!\n");
       $self->attack_gen($obj, $dam);
       $self->obj_dissolve();
   }
}

package item_griffon_statue;
@item_griffon_statue::ISA = qw( item );
use strict;

sub on_touch {
    my ($self, $by) = @_;
    if(1) { 

        #my $uses = $self->{'USES'} - 1;
        # preamble messages
        $by->log_append("{2}You lightly touch the small statue, and watch with amazement as it suddenly transforms into a full-grown, living griffon!\n");
        $by->room_tell("{2}$by->{'NAME'} lightly touches the small statue, watching with amazement as it suddenly transforms into a full-grown, living griffon!\n");
        
        # create griffy
        my $room = $main::objs->{$by->{'CONTAINEDBY'}};
        my $griff = $room->item_spawn(487);
        $griff->{'RACE'} = $by->{'RACE'};
        $griff->{'AID'} = $griff->{'STALKING'} = $by->{'OBJID'};
        #$griff->{'USES'} = $uses;
        $griff->{'AI'}->{'MASTER'} = $by->{'NAME'};
        $griff->stats_allto($by->{'LEV'});
        $griff->{'HP'} = $griff->{'MAXH'};
        $griff->{'MA'} = $griff->{'MAXM'};
        
        # ditch myself
        $self->dissolve_allsubs();
    } else {
        # failed
        return &rockobj::on_touch(@_);
    }
}



package mog_bones;
@mog_bones::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  $main::eventman->enqueue(2, \&rockobj::item_spawn, $main::map->[$self->{'ROOM'}], 410);
  $main::map->[$self->{'ROOM'}]->delay_room_sighttell(2, "{3}The pile of bones leap into motion, forming into the rough shape of a gigantic orc!\n");
  $self->obj_dissolve();
}

package item_tree_quest_door;
@item_tree_quest_door::ISA = qw( item );
use strict;

sub on_say {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  $saystr =~ s/^\s+//g;
  if($saystr eq "$self->{'TRIGKEY'}") {
      $obj->log_append("{2}As you speak the ancient password, a stone panel suddenly slides open on the northern wall. The panel reveals three seperate slabs of granite along with an odd button.\n");
      $obj->room_sighttell("{7}A stone panel suddenly slides open on the northern wall.\n");
      $main::map->[$self->{'ROOM'}]->item_spawn(530, 531, 532, 537);
      $self->dissolve_allsubs();
  }
}

package item_tree_quest_button;
@item_tree_quest_button::ISA = qw( item );
use strict;

sub pushed { 
   my ($self, $who) = @_; 
   $who->room_sighttell("{2}$who->{'NAME'} fiddles with something as your back is turned.\n");
   my ($hammer_guy, $pick_guy, $anvil_guy);
   
   if(  ($hammer_guy = $main::map->[$main::roomaliases{'tree-quest-hammer'}]->inv_has_rec_recurse(530))
      && $hammer_guy->{'LEV'} >= 100
      
      && ($pick_guy = $main::map->[$main::roomaliases{'tree-quest-pick'}]->inv_has_rec_recurse(532))
      && $pick_guy->{'LEV'} >= 100
      
      && ($anvil_guy =  $main::map->[$main::roomaliases{'tree-quest-anvil'}]->inv_has_rec_recurse(531))
      && $anvil_guy->{'LEV'} >= 100
      
      && $who->{'LEV'} >= 100

      && $who->{'RACE'} == $anvil_guy->{'RACE'}
      && $anvil_guy->{'RACE'} == $pick_guy->{'RACE'}
      && $pick_guy->{'RACE'} == $hammer_guy->{'RACE'}
      
      && $who->{'TYPE'} == 1
      && $pick_guy->{'TYPE'} == 1
      && $anvil_guy->{'TYPE'} == 1
      && $hammer_guy->{'TYPE'} == 1
      
     ) {
        $self->room_sighttell("{7}The eastern door slides open.\n");
        
        if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]) { return; }
        $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0; # allow entry
        $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[2]=1;
     } else {
        $self->room_sighttell("{2}A cloud of gas envelopes the room.\n");
        foreach my $vic ($self->inv_pobjs) {
            next if $vic->{'TYPE'}!=1;
            $vic->log_append("{2}You are enveloped by a cloud of gas.\n");
            $self->attack_gen($vic, int($vic->{'MAXH'}/3 + int rand 50));
        }
     }
}

package item_reeker;
@item_reeker::ISA = qw( item );
use strict;

#mich is cool
sub do_reeking
{
    my ($self, $by) = @_;
    my $r = $main::map->[$self->{'ROOM'}];
    
	# don't reek havoc (har har) if i landed in a safe room
	return if $r->{'SAFE'};

    $r->room_sighttell("{5}$self->{'NAME'} {3}explodes, {5}filling the room with a {12}putrid stench{5}.\n");
    
	foreach my $o ($r->inv_objs) {
	    next unless $o->{'TYPE'} > 0; # only affect players.
		
		next if $by->cant_aggress_against($o, 1); # only affects players in range, unsafe rooms, etc 
		
        $o->log_append("{15}The pain in your nostrils forces you to RUN!\n");
	    $o->{'ENTMSG'}='flees in';
	    $o->{'LEAMSG'}='flees out';
		
        $o->ai_move(&rockobj::ai_suggest_move_random(undef, $r->exits_hash) );
	    
		delete $o->{'ENTMSG'};
	    delete $o->{'LEAMSG'};

		$by->note_attack_against($o);
	}

    $self->obj_dissolve();
}

sub on_throwdir
{
    my ($self, $dir, $by) = @_;
    $self->do_reeking($by);
}
    
sub on_throw
{
    my ($self, $targ, $by) = @_;
    $self->do_reeking($by);
}
# end of mich beeing cool

package item_tree_talkative;
@item_tree_talkative::ISA = qw( item );
use strict;

sub on_ask {
    my ($self, $topic, $from) = @_;
    return undef if (!$from->inv_has_rec(18));
    if ($topic =~ /word|pass|speak|talk|say|quest|vault/) { 
        return "{2}$self->{'NAME'} whispers, \"$self->{'TRIGKEY'}\"\n";
    }
    return undef;
}

package item_convic_amu;
@item_convic_amu::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $toucher) = @_;
  # Spell uses an expensive item to create a temporary effect that mimics turq-ruby-sapp orbs, but with small fail rate
  if(rand(1) <= .40) {
      $self->obj_dissolve;
      $toucher->log_append("{6}The $self->{'NAME'} shatters into a million pieces.\n");
      $self->room_sighttell("{6}$toucher->{'NAME'} touches the $self->{'NAME'}, which shatters into a million pieces.\n");
  } else {
      $self->log_append("{7}You touch the $self->{'NAME'}.\n");
      $self->room_sighttell("{6}$toucher->{'NAME'} touches $self->{'NAME'}.\n");
  }
  
  $toucher->effect_add(51);
  return;
}

# DAVADA ITEMS
package chronoplate;
@chronoplate::ISA = qw( item );
use strict;


sub on_touch {
    my $self = shift;
    my $victim = shift;
    if($self->{'USES'} <= 0) {
        $victim->log_append("{1}Nothing happens.\n");
        return;
    }
    
    $victim->{'T'} += 150;
    $victim->{'VIGOR'} = 1.5;
    $victim->{'MA'} = $victim->{'MAXM'};
    $victim->{'HP'} = $victim->{'MAXH'};

    $victim->room_sighttell("{15}$victim->{'NAME'}'s chronoplate {2}glows bright {12}green{2} and surrounds $victim->{'PPRO'} in a temporal bubble.\n");
    $victim->log_append("{15}The chronoplate {2}glows bright {12}green{2} and surrounds you in a temporal bubble. Time reverses direction within for a brief moment, and you feel younger and more invigorated.\n");
    
    $self->{'USES'}--;
    return;
}

package mech_weap;
@mech_weap::ISA = qw( item );
use strict;

#sub dam_bonus {
#    return $_[0]->SUPER::dam_bonus(@_);
#}

sub dam_bonus {
    # self, victim,
    my $KMEC;
    $KMEC = $_[1]->{'KMEC'};
    
    return $KMEC;
}



package sonic_weap;
@sonic_weap::ISA = qw( item );
use strict;

#sub dam_bonus {
#    return $_[0]->SUPER::dam_bonus(@_);
#}

sub on_hit {
    # self, victim, holder, hitcount
    # Since this is only called once per melee attack, after the attack,
    # it is only called once, regardless of how many times we hit.
    # However, the hitcount is passed.
    #
    # Since we hit, hitcount is always > 0
    my ($self, $victim, $holder, $hitcount) = @_;

    if (rand(1) <  (1 -  0.98**$hitcount)) {
        $_[1]->effect_add(25) unless $_[1]->{'FX'}->{'25'} > time+120; # only give the effect if they're not currently deaf for at least 2 minutes
    }
    return;
}

# 90


package item_iridescent_flask;
@item_iridescent_flask::ISA = qw( item );
use strict;

sub on_throw {
   my ($self, $targ, $by) = @_;
   $self->c_undust($targ, $by);
}

sub on_use {
   my ($self, $by, $targ) = @_;
   $self->c_undust($targ || $by, $by);
}

sub c_undust {
   # custom func, endusts someone
   my ($self, $targ, $by) = @_;
   $by->log_appendline("{12}The glowing liquid from {13}your{12} iridescent vial splashes onto {13}$targ->{'NAME'}\{12}, scrubbing $targ->{'PPRO'} clean of dust and grime.");
   $targ->room_tell("{12}The glowing liquid from {13}$by->{'NAME'}\'s{12} iridescent vial splashes onto {13}$targ->{'NAME'}\{12}, scrubbing $targ->{'PPRO'} clean of dust and grime.\n", $by);
   $targ->log_appendline("{12}The glowing liquid from {13}$by->{'NAME'}\'s{12} iridescent vial splashes onto {13}you{12}, scrubbing you clean of dust and grime.");

   $targ->{'HIDDEN'} = 0 unless ($targ->{'HIDDEN'}>1);
   
   if(!$targ->{'START_AC'}){ 
	   $targ->{'START_AC'} = $targ->{'AC'}; 
	   }
   if(defined($targ->{'ATYPE'})){
	if(!$targ->{'START_AC'}){ 
	   $targ->{'START_AC'} = $targ->{'AC'}; 
	   $targ->{'AOFFSET'} =  $targ->{'AC'};
	   }
	if($targ->{'AC'}<=(1+($targ->{'START_AC'})*5)){
		$targ->{'AC'}=$targ->{'AC'}+1;
		$by->log_append("{12}The flask of glowing liquid has made {13}$targ->{'NAME'} {12}the armor stronger.\n");
		$targ->{'AOFFSET'} =  $targ->{'AC'};
	}
   }
   
   if(($targ->{'WC'} >= $targ->{'START_WC'}*1.5)&& defined($targ->{'START_WC'})){
		
   }else{
   if(!$targ->{'START_WC'}){ 
	   $targ->{'START_WC'} = $targ->{'WC'}; 
	   }
   if(($targ->{'WC'}) ){
	$targ->{'WC'}++;
	$by->log_append("{12}The flask of glowing liquid has made {13}$targ->{'NAME'} {12}more shiny.\n");
   }

    $self->obj_dissolve();
	}
	$self->obj_dissolve();
}

package item_formaldehyde_flask;
@item_formaldehyde_flask::ISA = qw( item );
use strict;

sub on_throw {
   my ($self, $targ, $by) = @_;
   $self->c_preserve($targ, $by);
}

sub on_use {
   my ($self, $by, $targ) = @_;
   $self->c_preserve($targ || $by, $by);
}

sub c_preserve {
   # custom func
   my ($self, $targ, $by) = @_;
   
   # Tell the world what happened
   $by->log_appendline("{13}You{12} pour the contents of the $self->{'NAME'} onto {13}$targ->{'NAME'}\{12}, preserving $targ->{'PPRO'} in $targ->{'PPOS'} current state.");
   $targ->room_tell("{13}$by->{'NAME'}\{12} pours the contents of the $self->{'NAME'} onto {13}$targ->{'NAME'}\{12}, preserving $targ->{'PPRO'} in $targ->{'PPOS'} current state.\n", $by);
   $targ->log_appendline("{13}$by->{'NAME'}\{12} pours the contents of the $self->{'NAME'} onto {13}you{12}, preserving you in your current state.");

   delete $targ->{'ROT'} if defined($targ->{'ROT'});

   if ($targ->{'TYPE'} == 1 || $targ->{'TYPE'} == 2) {
       $targ->effect_add(66);
   }


   $self->obj_dissolve();
}
package azral_gods;
@azral_gods::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  # types 1-4 (AZRALGOD = 1..6) are 25, 50, 75, 100% damage, based on victim's hp
  if($obj->is_dead() || $main::allyfriend[$self->{'RACE'}]->[$obj->{'RACE'}] ||
     $obj->{'FX'}->{'32'} || $obj->{'FX'}->{'7'}
     ) { return; }
  
  my @godType = ('An angry god sends a', 'An angry god sends a', 'An angry god sends a', 'An angry god sends a', 'An angry god sends a', 'An angry god sends a');
  $obj->log_append("{17}$godType[$self->{'AZRALGOD'}-1] burst of energy throughout your body as the Azral Gods sense your arrival.\n");
  $obj->room_sighttell("{17}$godType[$self->{'AZRALGOD'}-1] burst of energy throughout $obj->{'NAME'}\'s body.\n");
  
  $obj->{'HP'} -= int ( $self->{'AZRALGOD'}/6*1500 );
  if($obj->is_dead()) { $obj->die($self); }
  return;
}
package fallen_rock;
@fallen_rock::ISA = qw( item );
use strict;

sub fallen_rock::on_idle {
  my $self = shift;
  my $o;
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{6}A huge rock falls from the ceiling, but you dodge it just in time!\n");
         $o->room_sighttell("{6}A huge rock falls towards $o->{'NAME'}, but $o->{'NAME'} dodges it just in time!\n");
      } else {
         $o->log_append("{3}A huge rock suddenly falls onto your body, causing horrible pain!\n");
         $o->room_sighttell("{3}A huge rock suddenly falls onto into $o->{'NAME'}\'s body, causing horrible pain!\n");
         if($o->{'WEAPON'}) {
            my $weapon = $main::objs->{$o->{'WEAPON'}};
            $o->log_append("You lose grip on your $weapon->{'NAME'}!\n");
            delete $o->{'WEAPON'}; delete $weapon->{'EQD'};
            $o->item_hdrop($weapon);
            $weapon->{'WC'} = $weapon->{'WC'} - 1;
         }
         $o->{'HP'} -= int ( ($o->{'MAXH'}/6) + rand(15) );
         if($o->{'HP'}<=0) { $o->die(); }
      }
    }
  
  }
  return;
}

sub fallen_rock::on_say {
  my $self = shift;
  my $o;
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{6}A huge rock falls from the ceiling, but you dodge it just in time!\n");
         $o->room_sighttell("{6}A huge rock falls towards $o->{'NAME'}, but $o->{'NAME'} dodges it just in time!\n");
      } else {
         $o->log_append("{3}A huge rock suddenly falls onto your body, causing horrible pain!\n");
         $o->room_sighttell("{3}A huge rock suddenly falls onto into $o->{'NAME'}\'s body, causing horrible pain!\n");
         if($o->{'WEAPON'}) {
            my $weapon = $main::objs->{$o->{'WEAPON'}};
            $o->log_append("You lose grip on your $weapon->{'NAME'}!\n");
            delete $o->{'WEAPON'}; delete $weapon->{'EQD'};
            $o->item_hdrop($weapon);
            $weapon->{'WC'} = $weapon->{'WC'} - 1;
         }
         $o->{'HP'} -= int ( ($o->{'MAXH'}/6) + rand(15) );
         if($o->{'HP'}<=0) { $o->die(); }
      }
    }
  
  }
  return;
}
package trunk;
@trunk::ISA = qw( item );
use strict;

sub stk_trunkunsecure {
 # looks at item with name $iname
 my ($self, $iname) = @_;
 if(!$self->inv_rec_scan('903')) { $self->log_append("You cannot remove something from something you don\'t have.\n"); return; }
 if(!$iname) { $self->log_append("{3}You've got to decide on something to unsecure.\n"); return; }
 if (lc($iname) eq 'all') {

   my $o; foreach $o ($self->inv_rec_scan('903')->stk_objs) { $self->inv_rec_scan('903')->stk_trunkhunsecure($self, $o); }
   return 1;
 }
 my ($success, $item) = $self->inv_rec_scan('903')->inv_cgetobj($iname, 0, $self->inv_rec_scan('903')->stk_objs, undef);
 if($success==1) { 
    $self->inv_rec_scan('903')->stk_trunkhunsecure($self, $item);
    return(1);
 } elsif($success == 0) { $self->log_append("{3}You you have no $iname in storage.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub stk_trunkhunsecure {
 my ($self, $player, $o) = @_;
 if(!$player->inv_rec_scan('903')) { $player->log_append("You cannot remove something from something you don\'t have.\n"); return; }
 if(!$player->inv_free()) { $player->log_append("You have no room to hold $o->{'NAME'}.\n"); return; }
 $player->log_append("{3}You get $o->{'NAME'} from $self->{'NAME'}.\n");
 $player->room_sighttell("{3}$player->{'NAME'} gets $o->{'NAME'} from $self->{'NAME'}.\n");
 #$self->item_hgive ($o, $player); #DOES NOT WORK
 
 
 $player->item_spawn($o->{'REC'});
 $o->obj_dissolve();
 #$self->obj_dissolve($o->{'OBJID'});
 return ;
}

sub stk_list {
  my $self = shift;
  if (!$self->inv_rec_scan('903')) { $self->log_append("{6}You don\'t have anything to store objects in.\n"); return; }
  if (scalar($self->inv_rec_scan('903')->stk_objs)==0) { $self->log_append("{6}You have no objects in storage.\n"); return; }
  else { 
    my (@o, $o);
    foreach $o ($self->inv_rec_scan('903')->stk_objs) { push(@o, $o->{'NAME'}); }
    $self->log_append("{16}-={13}ITEMS IN TRUNK{16}=- {17}".join(', ', @o)."\n");
  }
  return;
}
sub stk_objs {
   # Returns array of objects in STocKed ("secured") inventory.
   my $self = shift;
   return(values(%{$self->{'STK'}}));
}

package ripped_pouch;
@ripped_pouch::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='ripped pouch' unless $self->{'NAME'};
  $self->{'CONTAINER'}=1;
  $self->{'FILLABLE'}=1;
  $self->{'MAXINV'}=5; 
  $self->{'CRYL'}=100+ int rand 300;
  $self->{'FPAHD'}='crunched';  $self->{'FPSHD'}='crunch';
  $self->{'TPAHD'}='crunched';  $self->{'TPSHD'}='crunches';
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
}
sub on_inherit {
  my ($self, $obj, $from) = @_;
  $self->inv_add($obj);
    $obj->{'!SAVE'}=1;
}

sub on_open {
  my ($self, $opener) = @_;
  $opener->room_sighttell('{14}'.($opener->{'NAME'} || $self->{'NAME'})."{2} destroys his pouch fumbling for his stuff.\n");
  $opener->log_append("{14}You open $self->{'NAME'}, which disintegrates to reveal your stuff.\n");
  $self->cmd_do("drop all");
  $self->room_sighttell('{14}'.($self->{'NICK'} || $self->{'NAME'})."{2} crumbles into dust\{4}.\n");
  $self->obj_dissolve();
  return;
  }
  
package floating_castle_traps;
@floating_castle_traps::ISA = qw( item );
use strict;

sub floating_castle_traps::on_idle {
  my $self = shift;
  my $o;
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{6}Something moves to strike you, but you dodge it just in time!\n");
         $o->room_sighttell("{6}Something moves to strike $o->{'NAME'}, but $o->{'NAME'} dodges it just in time!\n");
      } else {
         $o->log_append("{3}Something strikes your body, causing horrible pain!\n");
         $o->room_sighttell("{3}Something strikes $o->{'NAME'}\'s body, causing horrible pain!\n");
         if($o->{'WEAPON'}) {
            my $weapon = $main::objs->{$o->{'WEAPON'}};
            $o->log_append("You lose grip on your $weapon->{'NAME'}!\n");
            delete $o->{'WEAPON'}; delete $weapon->{'EQD'};
            $o->item_hdrop($weapon);
         }
         $o->{'HP'} -= int ( ($o->{'MAXH'}/6) + rand(15) );
         if($o->{'HP'}<=0) { $o->die(); }
      }
    }
  
  }
  return;
}
package trigger_bodypart_panel2;
@trigger_bodypart_panel2::ISA = qw( item );
use strict;

# If you use a bodypart on this trigger, and the bodypart's rec value is found
# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is either a hand or eye, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	if($self == $item){return;}
	if($user == $item){return;}
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You hold the $item->{'NAME'} against the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} places $item->{'NAME'} against the $self->{'NAME'}.\n");

		if (($item->{'NAME'} =~ /^(neck) of/)) {
        	$self->execute_create_exit_trigger();
        	$item->obj_dissolve();
		}elsif (($item->{'NAME'} =~ /^(wrist) of /)) {
        	$self->execute_create_exit_trigger();
        	$item->obj_dissolve();
		}else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} retracts its fang like receptors, as it did not like $item->{'NAME'}.\n");
	    	$user->log_append("$item->{'NAME'} is no longer of any use, you watch in horror as it disappears from your inventory.\n");
	    	
	    	$item->obj_dissolve();
		}
	} 
	
  	return 1; # success - they did something worthwhile
}
package bone_journal;
@bone_journal::ISA = qw( item );
use strict;

# If you use a bodypart on this trigger, and the bodypart's rec value is found
# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is either a hand or eye, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You put the $item->{'NAME'} in the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} places $item->{'NAME'} against the $self->{'NAME'}.\n");

		if ($item->{'REC'} == $self->{'TRIGCRTRREC'} )  {
        	$self->execute_create_exit_trigger();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} remains closed.\n");
		}
	} 
	
  	return 1; # success - they did something worthwhile
}

package monument;
@monument::ISA = qw ( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='Monument' unless $self->{'NAME'};
  $self->{'UPD'}=10;
  $self->{'USES'}=10;
  $self->{'FPAHD'}='flattened';  $self->{'FPSHD'}='flatten';
  $self->{'TPAHD'}='flattened';  $self->{'TPSHD'}='flattens';
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  return($self);
  }

sub on_touch {
	my ($self, $victim) = @_;
	if($victim->can_do(0,0,15)){
	    if($self->{'USES'} > 0){
    	$self->room_sighttell("{3}The $self->{'NAME'} fills $victim->{'NAME'} with a refreshed feeling!\n");
    	$victim->{'T'} -= 20;
    	$victim->{'VIGOR'} = .7;
    	$victim->{'HP'} = $victim->{'MAXH'};
    	$self->{'USES'}--;
    	return;
		}
		else{
			$self->room_sighttell("{3}The $self->{'NAME'} cannot fill $victim->{'NAME'} with a refreshed feeling!\nPlease Try again later\n");
		}
	}
}
package dancing_scim;
@dancing_scim::ISA = qw( item );
use strict;

sub dam_bonus {
    # self, victim, 
    if(!defined($_[2]->{'FX'}->{'22'}) && (rand 1 < .008 )) { $_[2]->room_sighttell("{13}$_[2]->{'NAME'}\'s dancing scimiter releases a bright flash.\n"); $_[1]->room_sighttell("{13}Your dancing scimiter releases a bright flash.\n"); $_[1]->effect_add(22); }
    return $_[0]->SUPER::dam_bonus(@_);
}

package sunshield;
@sunshield::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='sunshield' unless $self->{'NAME'};
  $self->{'UPD'}=5;
  $self->{'USES'}=5;
  $self->{'NOSAVE'}=1;
  $self->{'FPAHD'}='flattened';  $self->{'FPSHD'}='flatten';
  $self->{'TPAHD'}='flattened';  $self->{'TPSHD'}='flattens';
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
  }

sub on_touch {
    my $self = shift;
    my $victim = shift;
    if($self->{'USES'} <= 0) {
        $victim->log_append("{1}Nothing happens.\n");
        return;
    }
    
    $victim->effect_add (50);
    $victim->{'VIGOR'} = .5;
    
    $victim->room_sighttell("{2}$victim->{'NAME'}'s sunshield begins reflecting light.\n");
    $victim->log_append("{2}The sunshield starts to reflect light, as it surrounds you in a reflective sphere.\n");
    
    $self->{'USES'}--;
    return;
}

package black_staff;
@black_staff::ISA = qw ( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='black staff' unless $self->{'NAME'};
  $self->{'USES'}=1;
  $self->{'FPAHD'}='cracked';  $self->{'FPSHD'}='crack';
  $self->{'TPAHD'}='cracked';  $self->{'TPSHD'}='cracks';
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
  }
sub on_use {
  my ($self, $uid) = @_;
  $main::eventman->enqueue($uid->skill_add(12));
  $self->room_sighttell("{2}$uid->{'NAME'} is feeling much more skilled.\n");
  $main::eventman->enqueue(2 * 60, sub {$uid->skill_del(12)});
  $main::eventman->enqueue(2 * 60, sub {$self->room_sighttell("{2}$uid->{'NAME'} is not so skilled anymore.\n")});
  $self->room_sighttell('{14}'.($self->{'NICK'} || $self->{'NAME'})."{2} vanishes as its magic flows through $uid->{'NAME'}\'s vains\{4}.\n");
  $self->obj_dissolve();
  return;
  }
#############################################

package white_staff;
@white_staff::ISA = qw ( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='white staff' unless $self->{'NAME'};
  $self->{'USES'}=1;
  $self->{'FPAHD'}='cracked';  $self->{'FPSHD'}='crack';
  $self->{'TPAHD'}='cracked';  $self->{'TPSHD'}='cracks';
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
  }
sub on_use {
  my ($self, $uid) = @_;
  	$self->room_sighttell("{2}$uid->{'NAME'} is wisked away.\n");
  	$uid->teleport($main::roomaliases{'managath'});
  	$self->room_sighttell('{14}'.($self->{'NICK'} || $self->{'NAME'})."{2} vanishes as its magic flows through $uid->{'NAME'}\'s vains\{4}.\n");
  	$self->obj_dissolve();
  return;
  }
  
package auditory_inflictor;
@auditory_inflictor::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='auditory inflictor' unless $self->{'NAME'};
  $self->{'UPD'}=5;
  $self->{'USES'}=5;
  $self->{'FPAHD'}='beeped';  $self->{'FPSHD'}='beep';
  $self->{'TPAHD'}='beeped';  $self->{'TPSHD'}='beeps';
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
}


sub on_throw {
   my ($self, $targ, $by) = @_;
   $self->user_beep($targ);
}

 sub on_use {
   my ($self, $by, $targ) = @_;
   if($self->{'USES'}<=0) { $by->log_append("{1}Nothing happens.\n"); return; }
   $self->user_beep ($targ || $by);
   $self->room_sighttell("{14}$targ->{'NAME'} beeped.\n");
   $self->{'USES'}--;
   return;
}

sub on_ask {
 my ($self, $topic, $from) = @_;
 $self->user_beep ($topic);
 if ($topic =~ /activation pad|activation|activation pads/) { $self->say_rand('Try me.', 'I work.', );  }
 elsif ($topic =~ /use|touch|throw/) { $self->say_rand('No problem, I do all that and more!', 'Your wish is my command!' );  }
 elsif ($topic =~ /ask|beep/) { $self->say('Ask me about player.'); }
 $self->{'USES'}--;
 return("");
} 

sub on_idle {
  my $self = shift;
  if(rand(10)>3) { return; }
    $self->log_append("{17}$self->{'NAME'} whispers, \"{1}Ask me about things!{17}\"\n");
}

package item_prayable; # diggable dirt, uses TRIGEXIT
@item_prayable::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $toucher) = @_;
  if(!$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[0]) { return; }
   	$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1]=0; # allow entry
   	$main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[2]=1;
   	$toucher->log_append("As you pay hommage to Ker\'el, a low groaning sound emits from above as a white marble slab opens an exit to the up.\n");
}

package item_pilar;
@item_pilar::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'CONTAINER'}=1;
  $self->{'MAXINV'}=1; 
  return($self);
}

sub on_inherit {
  my ($self, $obj, $from) = @_;
  # filter received items
  if($obj->{'REC'}!=$self->{'WANTREC'}) {
	  $from->log_append("$obj->{'NAME'} does not seem to fit on the $self->{'NAME'}\n");
	  return;
	  }
	  else{
		  $from->log_append("$obj->{'NAME'} fits nicely into the opening in $self->{'NAME'}\n");
		  $obj->obj_dissolve();
		  my $newobj = $self->item_spawn($self->{'SPAWN'});
		  $from->log_append("$self->{'NAME'} shakes and reveals $newobj->{'NAME'} in its opening.\n");
	  }
  return;
}

sub on_open {
  my ($self, $opener) = @_;
  $self->cmd_do("drop all");
  return;
  }
  
package huge_iron_door;
@huge_iron_door::ISA = qw( item );
use strict;

# If you use a bodypart on this trigger, and the bodypart's rec value is found
# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is either a hand or eye, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You put the $item->{'NAME'} in the $self->{'NAME'} turn it, and quickly put it back in your pocket.\n");
		$user->room_sighttell("{7}$user->{'NAME'} places $item->{'NAME'} against the $self->{'NAME'}.\n");

		if ($item->{'REC'} == $self->{'TRIGCRTRREC'} )  {
        	$self->execute_create_exit_trigger();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} remains closed.\n");
	    	
		}
	} 
	
  	return 1; # success - they did something worthwhile
}


package zeph_ring;
@zeph_ring::ISA = qw( item );
use strict;

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 my @k = keys(%{$main::activeuids});
 my $p = &main::obj_lookup($main::activeuids->{$k[int rand($#k+1)]});
 
 if(!$p->{'ADMIN'}){
	$victim->log_append("{17}As you touch $self->{'NAME'} $p->{'NAME'} becomes frozen in place.\n");
	$p->effect_add(6);
	$p->log_append("{17}$victim->{'NAME'} touches $self->{'NAME'} and you become frozen in place.\n");
 	$self->{'USES'}--;
 	return;
}
 return;
}
package item_baine_chest;
@item_baine_chest::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'CONTAINER'}=1;
  $self->{'MAXINV'}=4; 
  return($self);
}

sub on_inherit {
  my ($self, $obj, $from) = @_;
  # filter received items
  #ring , bracers, crown, cape
  my $rec1 = $self->{'WANTONE'};
  my $rec2 = $self->{'WANTTWO'};
  my $rec3 = $self->{'WANTTHREE'};
  my $rec4 = $self->{'WANTFOUR'};
  
  if($self->inv_free()){
	 if($obj->{'REC'} == $rec1)
	 {
		 if($self->inv_rec_scan($rec2) || $self->inv_rec_scan($rec3) || $self->inv_rec_scan($rec4))
		 {
			 $self->cmd_do("drop all");
		 }
	 }
	 elsif($obj->{'REC'} == $rec2)
	 {
		 if(!$self->inv_rec_scan($rec1) || $self->inv_rec_scan($rec3) || $self->inv_rec_scan($rec4))
		 {
			 $self->cmd_do("drop all");
		 }
	 }
	 elsif($obj->{'REC'} == $rec3)
	 {
		 if(!$self->inv_rec_scan($rec1) || !$self->inv_rec_scan($rec2) || $self->inv_rec_scan($rec4))
		 {
			 $self->cmd_do("drop all");
		 }
	 }
	 elsif($obj->{'REC'} == $rec4)
	 {
		 if(!$self->inv_rec_scan($rec1) || !$self->inv_rec_scan($rec2) || !$self->inv_rec_scan($rec3))
		 {
			 $self->cmd_do("drop all");
		 }
	 }
	  
  }
  
}

sub on_open {
  my ($self, $opener) = @_;
  if(!$self->inv_free()){
	$opener->log_append("You open the box.\n");
	$self->item_spawn(988);
	$self->{'ADMIN'} = 1;
	$self->cmd_do("destroy ring");
	$self->cmd_do("destroy bracers");
	$self->cmd_do("destroy crown");
	$self->cmd_do("destroy cape");
	$self->{'ADMIN'} = 0;
  	$self->cmd_do("drop preservation");
	}
	else{
		$self->cmd_do("drop all");
		$opener->log_append("You open the box.\n");
	}
  return;
  }

package item_kerel_wall;
@item_kerel_wall::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'CONTAINER'}=1;
  $self->{'MAXINV'}=5; 
  return($self);
}


sub on_inherit {
	my ($self, $obj, $from) = @_;
	#WANT 957 958 959 960 961
	#GET KEREL TO GIVE HALO THINGY
	my $rec1 = '957';
	my $rec2 = '958';
	my $rec3 = '959';
	my $rec4 = '960';
	my $rec5 = '961';
	
	if($self->inv_free()){
	 if($obj->{'REC'} == $rec1)
	 {
		 $from->log_append("Ker\'el says very good you found one!\n");
	 }
	 elsif($obj->{'REC'} == $rec2)
	 {
		 $from->log_append("Ker\'el says very good you found one!\n");
	 }
	 elsif($obj->{'REC'} == $rec3)
	 {
		 $from->log_append("Ker\'el says very good you found one!\n");
	 }
	 elsif($obj->{'REC'} == $rec4)
	 {
		 $from->log_append("Ker\'el says very good you found one!\n");
	 }
	 elsif($obj->{'REC'} == $rec5)
	 {
		 $from->log_append("Ker\'el says very good you found one!\n");
	 }
	 else
	 {
		 $from->log_append("Ker\'el says no no no, that does not belong in there.\n");
		 $self->cmd_do("drop all");
	 }
  }
  if($self->inv_rec_scan($rec1) && 
	 $self->inv_rec_scan($rec2) &&
  	 $self->inv_rec_scan($rec3) &&
     $self->inv_rec_scan($rec4) &&
  	 $self->inv_rec_scan($rec5) ){
	  	 
	$from->item_spawn(934);
	$from->log_append("Ker\'el hands you a Crystalline Halo\n");
	
  }
	
}

package dragon_eyes;
@dragon_eyes::ISA = qw( item );
use strict;

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }
 my @k = keys(%{$main::activeuids});
 my $p = &main::obj_lookup($main::activeuids->{$k[int rand($#k+1)]});
 $victim->log_append("{17}As you touch $self->{'NAME'}, they flare up and being to report the location of $p->{'NAME'}.\n");
 $main::eventman->enqueue(40, \&rockobj::spy_report_location_of, $victim, $p, 5);
 $self->{'USES'}--;
 return;
}

package trap_weeping_tree;
@trap_weeping_tree::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  my $o;
  $self->room_sighttell("{3}The trees around you begin to weep.\n");
  foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    if( ($o->{'TYPE'}==1) && (!$o->is_dead) ){ 
      if($o->got_lucky) { 
         $o->log_append("{3}You manage to avoid their adverse effects.\n");
      } else {
         $o->effect_add(27);
         $o->{'HP'} -= int ( $self->{'WEEPTREE'}/4*500 );
  		 if($o->is_dead()) { $o->die($self); }
      }
    }
  
  }
  return;
}

sub on_room_enter (who, direction from) {
  $main::events{$_[0]->{'OBJID'}}=1 unless $main::events{$_[0]->{'OBJID'}};
  return;
}

sub on_event { $_[0]->on_idle; }

package item_molehill;
@item_molehill::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;
  $main::eventman->enqueue(2, \&rockobj::item_spawn, $main::map->[$self->{'ROOM'}], 1040);
  $main::map->[$self->{'ROOM'}]->delay_room_sighttell(2, "{3}A nasty mole suddenly appears from the small molehill\n");
  #$self->obj_dissolve();
}

package item_giant_mural;
@item_giant_mural::ISA = qw( item );
use strict;

# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is scarab amulet, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You place the $item->{'NAME'} against the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} places $item->{'NAME'} against the $self->{'NAME'}.\n");
		
		if ($item->{'REC'} == $self->{'TRIGCRTRREC'} )  {
        	$self->execute_create_exit_trigger();
        	#$item->obj_dissolve();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} does nothing.\n");
		}
	} 
	
  	return 1; # success - they did something worthwhile
}

package item_scarab_bookshelf;
@item_scarab_bookshelf::ISA = qw( item );
use strict;

sub on_touch {
  my ($self, $by) = @_;
  $self->execute_create_exit_trigger();
  $self->room_sighttell("{17}The $self->{'NAME'} swings open.\n");
  return 1; # success - they did something worthwhile
}

package npc_vaelos;
@npc_vaelos::ISA = qw( npc ); # note!! USED TO check object *BEFORE* player object.
use strict;


sub on_ask ($topic) {
    my ($self, $topic, $from) = @_;
    if($topic =~ /whirlwind/) { $self->say('Yes that whirlwind is made by powerful magic but it can be undone by a chant');  }
    elsif($topic =~ /chant/) { $self->say('Repeat this chant  ..Methos Amathus Endeos..  Proceed with caution the palace has been cursed.');  }
    
    else { return undef; }
}

package npc_desert_nomad;
@npc_desert_nomad::ISA = qw( npc ); # note!! USED TO check object *BEFORE* player object.
use strict;


sub on_ask ($topic) {
    my ($self, $topic, $from) = @_;
    if($topic =~ /book/) { $self->say('Well I just touched that old book shelf and this fell out, very strange!');  }
    elsif($topic =~ /whirlwind/) { $self->say('The Whirlwind? It covers the now ruins of the tyrinin palace. I know nothing about the whirlwind except that it appeared after the palace fell under its curse. The palace wizard fled after the curse perhaps he knows something.');  }
    elsif($topic =~ /curse/) { $self->say('The king of Tyrenin was tricked into freeing his djinn and once freed the djinn killed everyone in the palace and raised them from the dead to serve him for eternity.');  }
    elsif($topic =~ /wizard/) { $self->say('Vaelos the palace wizard fled somewhere to the northwest of the desert after the curse. He is one of the Arcane Mages');  }
    else { return undef; }
}

sub on_room_enter (who, direction from) {
	if(rand( int 10) < 9){
  $main::events{$_[0]->{'OBJID'}}=1 unless $main::events{$_[0]->{'OBJID'}};}
  return;
}

sub on_event { $_[0]->on_idle; }

package trap_sand2;
@trap_sand2::ISA = qw( item );
use strict;

sub on_idle {
  my $self = shift;
  my ($o);

  $self->room_sighttell("{3}You notice the quicksand below you moving rapidly.\n");
  	foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    	if( $o->{'TYPE'} > 0 ){ 
	   	 $o->log_append("{3}Your are pulled down by the quicksand!\n"); $o->effect_add(85); 
    		$o->teleport($main::roomaliases{'hidden_library'});
		}
  	return;
	}
}

sub on_room_enter {
  my $self = shift;
  my ($o);
	if(rand(100) > 30){
  $self->room_sighttell("{3}You notice the quicksand below you moving rapidly.\n");
  	foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) {
    	if( $o->{'TYPE'} > 0 ){ 
	   	 $o->log_append("{3}Your are pulled down by the quicksand!\n"); $o->effect_add(85); 
    		$o->teleport($main::roomaliases{'hidden_library'});
		}
	
  	
	}
}
return;
}

sub on_event { $_[0]->on_idle; }

#koalite_smelter
package koalite_smelter;
@koalite_smelter::ISA = qw( item );
use strict;



#item_spherule_breastplate
package item_spherule_breastplate;
@item_spherule_breastplate::ISA = qw( item );
use strict;

sub on_touch {
 my $self = shift;
 my $victim = shift;
 if($self->{'USES'}<=0) { $victim->log_append("{1}Nothing happens.\n"); return; }

 $victim->item_spawn(135);
 $victim->item_spawn(338);
 $victim->item_spawn(381);
 $victim->item_spawn(381);
 $victim->item_spawn(381);
 $victim->item_spawn(380);
 $victim->log_append("You take a few orbs off the breast plate and watch them grow before your eyes.\n");
 $self->{'USES'}--;
 return;
}


package orb_refining_machine;
@orb_refining_machine::ISA = qw( item );
use strict;

sub on_touch {
#$main::roomaliases{'spherule-grinder'}
	#spherule-grinder
  my ($self, $by) = @_;
  if($by->aprl_rec_scan(1113) && 
	$by->aprl_rec_scan(1115) && 
	$by->aprl_rec_scan(1114) && 
	$by->inv_rec_scan(1117) && 
	$by->aprl_rec_scan(1116)){
	$by->room_sighttell("{17}$by->{'NAME'} quickly moves over to...\n");
	$by->teleport($main::roomaliases{'spherule-grinder'});
	return 1; # success - they did something worthwhile
  }else {
	$by->log_error("You can't use that!");
  }
}

sub on_inherit {
  my ($self, $obj, $from) = @_;
  # filter received items
  if($obj->{'REC'}!=1104 && # diamond
  	$obj->{'REC'}!=1105 &&  # topaz
  	$obj->{'REC'}!=1106 &&  # emerald
  	$obj->{'REC'}!=1107 &&  # amethyst
  	$obj->{'REC'}!=1108 &&  # quartz
  	$obj->{'REC'}!=1109 &&  # sapphire
  	$obj->{'REC'}!=1110 &&  # ruby
  	$obj->{'REC'}!=1111 	# turquoise
  	) { $self->cmd_do("drop all"); }
  return;
}

sub on_open {
  my ($self, $opener) = @_;
  $self->cmd_do("drop all");
}

sub on_wind {
  my ($self, $who) = @_;
  my $total;
  my $diamond =0;
  my $topaz =0;
  my $emerald =0;
  my $amethyst =0;
  my $quartz =0;
  my $sapphire =0;
  my $turquoise = 0;
  my $ruby = 0;
  
  ## cout the totals
  foreach my $obj ($self->inv_objs) {
	  if($obj->{'REC'}==1104){ $diamond++;}
	  if($obj->{'REC'}==1105){ $topaz++;}
	  if($obj->{'REC'}==1106){ $emerald++;}
	  if($obj->{'REC'}==1107){ $amethyst++;}
	  if($obj->{'REC'}==1108){ $quartz++;}
	  if($obj->{'REC'}==1109){ $sapphire++;}
	  if($obj->{'REC'}==1110){ $ruby++;}
	  if($obj->{'REC'}==1111){ $turquoise++;}
  }
  if(($diamond == 2) && ($topaz == 2) && ($emerald == 2) && ($amethyst == 2))
  { 
	  $who->item_spawn(1117);
	  $who->log_append("An orb appears in your inventory.\n");
	  }
  if($turquoise == 5){ 
	  $who->item_spawn(1113); 
	  $who->log_append("A piece of equipment appears in your inventory.\n");
	  }
  if($ruby == 5){ 
	  $who->item_spawn(1114); 
	  $who->log_append("A piece of equipment appears in your inventory.\n");
	  }
  if($sapphire == 5){ 
	  $who->item_spawn(1115); 
	  $who->log_append("A piece of equipment appears in your inventory.\n");
	  }
  if($quartz == 5){ 
	  $who->item_spawn(1116); 
	  $who->log_append("A piece of equipment appears in your inventory.\n");
	  }
  
  #destroy the stuff
  foreach my $obj ($self->inv_objs) {$obj->obj_dissolve(); }
}

#item_azral_fig_time_staff
package item_azral_fig_time_staff;
@item_azral_fig_time_staff::ISA = qw( item );
use strict;

sub can_unequip {
    my ($self, $who) = @_;
  
    $who->log_append("You carefully remove the Figurine from the Staff of Time.\n");
    $self->{'NAME'} = "azral figurine"; 
    
    $self->{'TPSHD'} = "hits";
	$self->{'FPAHD'} = "hit";
	$self->{'TPAHD'} = "hit";
	$self->{'FPSHD'} = "hit";
    
	$self->{'BASEH'} = 600;
    $self->{'BASEM'} = 600;
    $self->{'DESC'} = 'This figurine is about one foot tall, generally cylindrical in shape, about three inches in diameter, and made of the purest Azrite you\'ve ever seen. The Azral depicted is a truly frightening sight. The Figure has his hands out-stretched as if it wanted something.  When you look at the bottom of the figurine, you notice that it looks like it could accept a massive rod.';
	$self->{'ISSTAFF'} = 0;
	$self->{'SAVED_WC'}= $self->{'WC'};
	$self->{'WC'}=60;
	$self->{'ATYPE'} = 'CARRIED';
	$who->item_spawn(734);
	$who->item_spawn(1117);
	$who->log_append("You once again seperate the Azral Figurine from the wooden splinter, and remove the spherule orb from its hand.\n");
    return(1);
  
}

sub can_equip  {
	my ($self, $who) = @_;
	my $orb = $who->inv_has_rec(1117);
	my $splinter = $who->inv_has_rec(734);
	
	if($orb && $splinter){
		$who->log_append("You carefully put the Azral Figurine on top of the massive splinter, and place the spherule orb in its hands.\n");
		$self->{'NAME'}  = "benziliane staff of time";
		
		$who->inv_rec_scan(734)->obj_dissolve();
		$who->inv_rec_scan(1117)->obj_dissolve();
		
		$self->{'DESC'} = 'The Benziliane Staff of Time is six feet long, adorned on the top, is an Azral Figurine, this figurine is about one foot tall, generally cylindrical in shape, about three inches in diameter, and made of the purest Azrite you\'ve ever seen. The Azral depicted is a truly frightening sight. The Figure has his hands out-stretched with a spherule orb in it\'s hands.';
		$self->{'MASS'} = 35;
		$self->{'VOL'} = .5;
		$self->{'BASEH'} = 0;
		delete $self->{'ATYPE'};
    	$self->{'BASEM'} = 0;
		$self->{'ISSTAFF'} = 1;
		$self->{'TPSHD'} = 'strikes';
		$self->{'FPAHD'} = 'struck';
		$self->{'TPAHD'} = 'struck';
		$self->{'FPSHD'} = 'strike';
		if($self->{'SAVED_WC'} >= 90){
			$self->{'WC'} = $self->{'SAVED_WC'};
		}else{
			$self->{'WC'} = 90;
		}
	
	return (1);
	}
	else{return 0;}
}


sub on_touch {
  my ($self, $who) = @_;
  if($self->{'ISSTAFF'}==1 && ($self->{'EQD'}==0)){
  $who->log_append("You carefully remove the Figurine from the Staff of Time.\n");
    $self->{'NAME'} = "azral figurine"; 
    
    $self->{'TPSHD'} = "hits";
	$self->{'FPAHD'} = "hit";
	$self->{'TPAHD'} = "hit";
	$self->{'FPSHD'} = "hit";
    
	$self->{'BASEH'} = 600;
    $self->{'BASEM'} = 600;
    $self->{'DESC'} = 'This figurine is about one foot tall, generally cylindrical in shape, about three inches in diameter, and made of the purest Azrite you\'ve ever seen. The Azral depicted is a truly frightening sight. The Figure has his hands out-stretched as if it wanted something.  When you look at the bottom of the figurine, you notice that it looks like it could accept a massive rod.';
	$self->{'ISSTAFF'} = 0;
	$self->{'SAVED_WC'} = $self->{'WC'};
	$self->{'WC'}=60;
	$who->item_spawn(734);
	$who->item_spawn(1117);
	$who->log_append("You once again seperate the Azral Figurine from the wooden splinter, and remove the spherule orb from its hand.\n");
    return(1);
  }else{
	$who->log_append("Nothing happens.\n");
  }
  
}

package arena_trigger_exit_exact;
@arena_trigger_exit_exact::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='trigger' unless $self->{'NAME'};
  $self->{'FPAHD'}='trigged';  $self->{'FPSHD'}='trig';
  $self->{'TPAHD'}='trigged';  $self->{'TPSHD'}='trigs';
  $self->{'DLIFT'}=''; $self->{'CAN_LIFT'}='';
  # SPECIAL
#  $self->{'TRIGKEY'}='' unless $self->{'TRIGKEY'};
  $self->{'TRIGEXIT'}= uc($self->{'TRIGEXIT'});
#  $self->{'TRIGEXITCNT'}=1 unless $self->{'TRIGEXITCNT'};
#  $self->{'TRIGIMMEDREPLY'}='' unless $self->{'TRIGIMMEDREPLY'};
#  $self->{'TRIGDELAYREPLY'}='' unless $self->{'TRIGDELAYREPLY'};
#  $self->{'TRIGDELAY'}='' unless $self->{'TRIGDELAY'};
  return($self);
}

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if($self->{'TRIGKEY'} && $saystr eq $self->{'TRIGKEY'}) { 
      $self->execute_create_exit_trigger();
  }
  return;
}

package plague;
@plague::ISA = qw( rockobj );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='black plague' unless $self->{'NAME'};
  $self->{'FPAHD'}='plagued';  $self->{'FPSHD'}='plague';
  $self->{'TPAHD'}='plague';  $self->{'TPSHD'}='plagues';
  $self->{'DESC'} = 'This large plague looks very deadly.';
  $self->{'CATCHFUZ'}=.6 unless $self->{'CATCHFUZ'};
  $self->{'DLIFT'}=''; $self->{'CAN_LIFT'}='';
  $self->{'HP'} = 1;
  return($self);
}

sub on_room_enter (who, direction from) {
  my ($self, $who, $dir) = @_;
  # give'em a chance to escape

  if($self->{'ROT'} < time){
	  $self->obj_dissolve;
	  return;}
  
  if( ($main::allyfriend[$self->{'RACE'}]->[$who->{'RACE'}]) || 
  	($who->{'TYPE'}<=0) || 
  	($who->{'RACE'} == 4) || 
  	(rand(100) > $self->{'CATCHFUZ'}) || 
  	$who->aprl_rec_scan(970) ){ 
		  return; }
	if($main::objs->{$self->{'CROBJID'}}->cant_aggress_against($who)){return;}
	#unless ($_[0]->log_cant_aggress_against($victim, 1)) {
  $who->log_append("{3}You catch the $self->{'NAME'}.\n");
  $who->room_sighttell("{3}$who->{'NAME'} catches the $self->{'NAME'}.\n");
  $who->effect_add(27) unless $who->{'NOSICK'};
  $who->{'FX'}->{27} = time + 5 + $self->{'PLAGUED'};
  if($self->{'CROBJID'} && $main::objs->{$self->{'CROBJID'}}) {
    $main::objs->{$self->{'CROBJID'}}->log_append("{2}You hear the horrifying sound of $who->{'NAME'}'s scream as $who->{'PRO'} catches your plague.\n"); 
  }
  return;
}


sub dam_bonus { 10 }


package item_broken_ladder;
@item_broken_ladder::ISA = qw( item );
use strict;

# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is scarab amulet, then the triggie goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You insert $item->{'NAME'} into the gap in the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} pushes $item->{'NAME'} into the $self->{'NAME'}.\n");

		if ($item->{'REC'} == $self->{'TRIGCRTRREC'} )  {
        	$self->execute_create_exit_trigger();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} does nothing.\n");
		}
	} 
	
  	return 1; # success - they did something worthwhile
}

package item_metal_disc;
@item_metal_disc::ISA = qw( item );
use strict;

# inside the trigger's TRIGCRTRREC (a comma-delimited list)
# and the object is bone key, then the trigger goes off!

sub on_use_on {
    my ($self, $user, $item) = @_;
	
	if ($user->can_do(0,0,10)) {
		$user->log_append("{7}You put $item->{'NAME'} into the irregular shaped opening on the $self->{'NAME'}.\n");
		$user->room_sighttell("{7}$user->{'NAME'} puts $item->{'NAME'} into the $self->{'NAME'}.\n");

		if ($item->{'REC'} == $self->{'TRIGCRTRREC'} )  {
        	$self->execute_create_exit_trigger();
		} else {
	    	$self->room_sighttell("{17}The $self->{'NAME'} is not used here.\n");
		}
	} 
	
  	return 1; # success - they did something worthwhile
}

#brain_implant
package brain_implant;
@brain_implant::ISA = qw( item );
use strict;

sub can_remove {
  my ($self, $who) = @_;
	return (0);
}

sub can_wear  {
	my ($self, $who) = @_;
	return (1);
}



package item_trimoral;
@item_trimoral::ISA = qw( item );
use strict;

sub can_unequip {
  my ($self, $who) = @_;
  	$self->{'WC'} = 0;
	return (1);
}

sub can_equip  {
	my ($self, $who) = @_;
	$self->{'WC'}= 40 + ($who->{'LEV'}*.08);
	return (1);
}


package item_auraflood;
@item_auraflood::ISA = qw( item );
use strict;

sub on_room_enter (who, direction from) {
  my ($self, $obj, $dir) = @_;

  
  $main::objbase->[1252] = sub { my $i = npc->new('CRYL', int(rand($obj->{'LEV'})), 'KEXP', 100, 'LIMIT', 4, 'NAME', 'Aura Flood', 'TPSHD', 'hits', 'VOL', 7.3, 'FPAHD', 'hit', 'AC', $obj->{'AC'}, 'TPAHD', 'hit', 'DWEAPNAME', 'sword', 'MASS', 60, 'FPSHD', 'hit', 'WC', $obj->{'LEV'}, 'DESC', 'I am the flood do not get swept away'); $i->stats_allto((100)); $i->gender_set('M'); return($i); };
  $main::eventman->enqueue(0, \&rockobj::item_spawn, $main::map->[$self->{'ROOM'}], 1252);

  #$main::map->[$self->{'ROOM'}]->delay_room_sighttell(2, "{3}A nasty mole suddenly appears from the small molehill\n");
  #$self->obj_dissolve();
}

sub on_open {
 my ($self, $by) = @_;
  		#$self->room_sighttell("{2}$uid->{'NAME'} is wisked away.\n");
  		$by->teleport($main::roomaliases{'cluckys'});
  		return;
}

package item_troitian_crawler;
@item_troitian_crawler::ISA = qw ( item );
use strict;

@item_troitian_crawler::path_to = qw(ne e se e ne se se se ne se s s se e se s sw se e e s sw s s sw sw s sw w nw sw w w w);
@item_troitian_crawler::path_back = qw(e e e ne se e ne n ne ne n n ne n w w nw ne n nw w nw n n nw sw nw nw nw sw w nw w sw);

sub on_enter {
    # when a player enters the object..routes them via portal.
    my ($self, $obj) = @_;
    my $cost = 200;
#    if(!$self->inv_free()) { $obj->log_append("{3}There is no room for you inside $self->{'NAME'}.\n"); return 0; }
    if($obj->{'CRYL'} < $cost) { $obj->log_append("{3}You do not have $cost cryl to pay the fare!\n"); return 0; }
    
    $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the {15}$self->{'NAME'}\{4}.\n");
    if( $obj->item_henter($self) ) {
        $obj->{'CRYL'}-=$cost;
        $obj->log_append("{2}You pay your fare and enter the {15}$self->{'NAME'}.\n");
        if(!$obj->is_invis()) { 
            $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'})."{2} enters the $self->{'NAME'}.\n");
        }
    }
    
    return 1;
}

sub c_ship_move {
    my $self = shift;
    # ROOM_AT
    # PATH_BACK
    my $going_back = \$self->{'AI'}->{'GOING_BACK'};  # use path_back instead of path_to
    my $dir_list = $$going_back ? (\@item_troitian_crawler::path_back) : (\@item_troitian_crawler::path_to);
    my $dir_next = \$self->{'AI'}->{'DIR_NEXT'};        # element to use next move
    
    if(!$$dir_next) {
        foreach my $o ($self->inv_objs) {
            $o->log_append("{2}Your ship departs.\n");
        }
    }
    
    # move to next room, increase $dir_next
    $self->realm_move($dir_list->[$$dir_next++]);
    
    # if reached destination ... 
    if($$dir_next == @$dir_list) {
        # change direction of "going back"
        $$going_back = !$$going_back;
        
        # reset direction list
        $$dir_next = 0;
        
        # dump passengers
        $self->c_dump_passengers();
        
        # move again in 60 seconds
        $self->delay_room_talktell(45, "{17}\"All aboard!\" {6}shouts the captain of the Land Bastard, {17}\"Only 150 cryl for passage!\"\n");
        $main::eventman->enqueue(60, \&c_ship_move, $self);
    } else {
        if(($$dir_next+1) == @$dir_list) {
            foreach my $o ($self->inv_objs) { $o->log_append("{2}Your crawler nears the trips end.\n"); }
        }
        # move again in 10-15 seconds
        $main::eventman->enqueue(10 + int rand 6, \&c_ship_move, $self);
    }
}

sub on_idle { 
    my $self = shift;
    if(!$self->{'AI'}->{'ACTIVE'}) {
        $self->{'AI'}->{'ACTIVE'} = 1;
        $self->c_ship_move();
    }
}

sub c_dump_passengers {
    my $self = shift;
    $self->room_sighttell("{2}A group of passengers are rushed off the crawler, and scuttle off.\n");
    foreach my $o ($self->inv_objs) {
        if($o->{'TYPE'}==1 || $o->{'TYPE'}==2) {
            if(!$o->item_henter($main::map->[$self->{'ROOM'}])) { 
                $o->log_append("{2}##### There was an error getting you off this ship. Please exit the game and email rocksupport.\n");
            } else {
                $o->log_append("{2}You are thanked for your patronage, then rushed off the crawler.\n");
            }
        }
    }
}

sub can_enter { 1 };
sub can_exit { 1 };

sub cby_desc {
   my ($self, $obj) = @_;
   # users contained by me see this:
   my $room = $main::map->[$_[0]->{'ROOM'}];
   chomp(my @roomInv = ($self->room_inv_list($obj)) );
   my $cap = &main::lifeform_scan_terrain_array($room->{'M'},$room->{'Z'},$room->{'X'},$room->{'Y'},$room->{'Z'}, 2);
   $cap->[0] .= "{1}| {17}-= {14}Enviro-Term: {2}$room->{'NAME'} {17}=-\n";
   $cap->[1] .= "{1}| $roomInv[0]\n";
   $cap->[2] .= "{1}| $roomInv[1]\n";
   $cap->[3] .= "{1}| $roomInv[2]\n";
   $cap->[4] .= "{1}| $roomInv[3]\n";
   $cap->[5] .= "{1}-----/\n";
   $cap = join ('', @$cap);
   return(\$cap);
}


package triangular_decay;
@triangular_decay::ISA = qw( item );
use strict;

sub dam_bonus {
    # self, victim, 
    if(!defined($_[2]->{'FX'}->{'23'}) && (rand 1 < .1 )) { $_[2]->room_sighttell("{13}$_[2]->{'NAME'}\'s triangular decay releases a foul wind.\n"); $_[1]->room_sighttell("{13}Your triangular decay releases a foul wind.\n"); $_[1]->effect_add(23); }
    return $_[0]->SUPER::dam_bonus(@_);
}

package pilltop_machine;
@pilltop_machine::ISA = qw( item );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_item;
  $self->{'NAME'}='altar' unless $self->{'NAME'};
  $self->{'WINPCT'}=100 unless $self->{'WINPCT'};           # percent chance of win
  $self->{'AWARDPCT'}=12 unless $self->{'AWARDPCT'};       # amount the player is rewarded
  $self->{'DELAY'}=1 unless $self->{'DELAY'};              # delay for results
  $self->{'COSTPERPLAY'}=10 unless $self->{'COSTPERPLAY'}; # cost in cryl
  $self->{'CONTAINER'}=1;
  $self->{'CRYL'}=100 unless $self->{'CRYL'}; # starting cash
  $self->{'FPAHD'}='slotted';  $self->{'FPSHD'}='slot';
  $self->{'TPAHD'}='slotted';  $self->{'TPSHD'}='slots';
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  return($self);
}

sub on_cryl_receive {
  my ($self, $amt, $from) = @_;
  if ($from->can_do(75,0,1500)) {
  	if(($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) && $self->{'AI'}->{'LASTPLYR'} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}} && ($main::objs->{$self->{'AI'}->{'LASTPLYR'}} ne $from) && $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->shares_room($self) ) {
	    $self->cmd_do("tell $from->{'NAME'} Someone's already praying - please wait till this fellow is finished.");
	    $self->cmd_do("give $amt to $from->{'NAME'}");
	    return;
  	}
  	$self->{'AI'}->{'COINHOLDER'} +=$amt;
  	$self->{'AI'}->{'LASTPLYR'}=$from->{'OBJID'};
  	if($main::events{$self->{'OBJID'}}) { return; }
  	if($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) { 
	    $self->room_sighttell("{6}God sends down a bolt of lightning and strikes the pile of cryl.\n");
	    $main::events{$self->{'OBJID'}}=$self->{'DELAY'};
  	} else {
	    $self->say('Please places at least '.($self->{'COSTPERPLAY'}-$self->{'AI'}->{'COINHOLDER'}).' more cryl to recieve a blessing.');
  	}
	}else{
		$from->{'CRYL'} += $amt;
	}
  return;
}

#sub on_event {
#  my $self = shift;
#  $self->{'CRYL'} += $self->{'COSTPERPLAY'};
#  $self->{'AI'}->{'COINHOLDER'} -= $self->{'COSTPERPLAY'};
#  if( rand(100) < $self->{'WINPCT'} ) { 
#    $self->room_sighttell("{1}$self->{'NAME'} illuminates $main::map->[$self->{'ROOM'}]->{'NAME'} with a burning shade of red.\n");
#    my $amt = int ($self->{'CRYL'}*$self->{'AWARDPCT'}/100);
#    $self->say_rand('We have a winner!', 'You win! You win!', 'Winner! Winner! Winner!', 'Congratulations!', 'Beep beep booh bahhh beep...', 'Reeooooww! Reooooooww! Meeep meep!', 'Ding ding ding ding!');
#    if($self->{'AI'}->{'LASTPLYR'} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}} && $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->shares_room($self) ) {
#       $self->cmd_do("give $amt to $main::objs->{$self->{'AI'}->{'LASTPLYR'}}->{'NAME'}");
#    } else {
#       $self->cmd_do("unloot $amt");
#    }
#  } else {
#    # llllooooooooooooser... lewwwwwwwwzerrrrr!
#    #$self->room_talktell("{7}$self->{'NAME'} dims to a quiet whisper.\n");
#    $self->say_rand('Tough luck. Please try again.', 'You lose. Please try again.', 'Ooba Ooba. Please try again.', 'No win. Please try again.', 'Loser! Please try again.', 'You lost. Please try again.', 'Sorry, no win. Please try again.'); 
#  }
#  if($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) { 
#    $self->room_sighttell("{6}$self->{'NAME'}'s {7}lights flicker on and off as it begins to quietly hum.\n");
#    $main::events{$self->{'OBJID'}}=$self->{'DELAY'};
#  }
#  return;
#}

sub on_event {
#$main::objs->{$self->{'AI'}->{'LASTPLYR'}}->{'NAME'}
#$self->{'AI'}->{'COINHOLDER'}  

my $self = shift;
my $randcoin = int rand($self->{'AI'}->{'COINHOLDER'}*(1.5));
my $player = $main::objs->{$self->{'AI'}->{'LASTPLYR'}};
my $item = $player->inv_rand_item();
my $luck = int($player->{'LUCK'});
my $roll = int(rand(100));
    $self->room_sighttell("{17}Your sacrifical values are {13}$randcoin");
    $self->room_sighttell("{17} and {15}$roll$luck");
    $self->room_sighttell("{17}.\n");
	if(($randcoin >= 1800000) || (($roll > 94)&&($luck > 90))){

    	$self->room_sighttell("$player->{'NAME'} has recieved a trimoral suffering.\n");
    	$player->item_spawn(1250);
    	$self->{'AI'}->{'COINHOLDER'} = 0;
    	return;
	}
	if(($randcoin >= 600000) || (($roll > 80)&&($luck > 90))){
    $player->exp_add( ((($player->{'LEV'}+2)**3) - ($player->{'LEV'}**3))*17 );
   	$self->room_sighttell("$player->{'NAME'} has gained two levels of exp.\n");
   	$self->{'AI'}->{'COINHOLDER'} = 0;
    	return;
	}
	
	if(($randcoin >= 500000) || (($roll > 75)&&($luck > 90))){
    $player->{'CRYL'} = $player->{'CRYL'}+int(($self->{'AI'}->{'COINHOLDER'}*rand(4)));
   	$self->room_sighttell("$player->{'NAME'} cryl has changed massively.\n");
   	$self->{'AI'}->{'COINHOLDER'} = 0;
    	return;
	}
	
	if(($randcoin >= 5000) || (($roll > 70)&&($luck > 90))){
    $player->{'CRYL'} = $player->{'CRYL'}+int(($self->{'AI'}->{'COINHOLDER'}*rand(2)));
   	$self->room_sighttell("$player->{'NAME'} cryl has changed.\n");
   	$self->{'AI'}->{'COINHOLDER'} = 0;
    	return;
	}
   	my $randnum = int rand(5);    	
	if(($randcoin < 5000 && $randcoin > 50) || (($roll> 65)&&($luck > 90))){
    	  	
		#$self->room_sighttell("$item->{'NAME'} was struck by lightning.\n");
    	if($randnum == 5){
			$item->{'BASEH'} += $randnum;
    		$item->{'WC'} += $randnum;
		$self->room_sighttell("$item->{'NAME'} was struck by lightning increasing HP and WC by 5.\n");
    	}elsif($randnum == 4){
	    	$item->{'BASEH'} += $randnum;
			$self->room_sighttell("$item->{'NAME'} was struck by lightning increasing HP 4.\n");
    	}elsif($randnum == 3){
	    	$item->{'WC'} += $randnum;
			$self->room_sighttell("$item->{'NAME'} was struck by lightning increasing WC 3.\n");
    	}elsif($randnum < 3){
	    	$item->{'WC'} += $randnum;
	    	$item->{'BASEH'} += $randnum;
			$self->room_sighttell("$item->{'NAME'} was struck by lightning increasing HP and WC by 3.\n");
    	}
    	
    }
    if(($luck < 3) or (($randcoin < 50) && ($randcoin > 25) )){
    	$player->level_penalty(1);
    	return;
	}
	if($randcoin < 25 ){ 	
      $player->die($self);
	}
	 
  #$player->cmd_do("down");
  delete $self->{'AI'}->{'LASTPLYR'} ;
  
  #$self->{'CRYL'}=0;
  return;
}

sub on_touch {
  my ($self, $by) = @_;
	$by->die($self);	
}

sub on_idle {
 my $self = shift;
 if ( (rand(10)>2) || ($self->{'AI'}->{'COINHOLDER'} >= $self->{'COSTPERPLAY'}) ) { return; }
# $self->say('Could YOU become a cryllionaire? Try your luck at the fascinating game of slots. Just put cryl into me and you\'re on your way to richness! Only '.$self->{'COSTPERPLAY'}.' cryl per play!');
 return;
}

#################################################
### NOTE TO SELF: When making new packages, make sure you change like @item::ISA* to @clock::ISA or whatever.
1;
