use strict;

package player;
@player::ISA = qw( rockobj );
use strict;
BEGIN { do "const_stats.pm"; }

sub def_set {
  my $self = shift;
  $self->prefmake_player;
  return($self);
}

sub on_idle {
  my $self = shift;
  if( ($self->{'RACE'}==4) ) {
    # (skill 25 is salp catalyst)
    $self->{'SALP'} *= (1.1 + (.4*$self->skill_has(25)));
    $self->log_append("{3}Your stomach acids have further strengthened the salp inside it.\n")
        if $self->{'SALP'};
    $self->{'SALP'} = 999_999_999 if $self->{'SALP'} > 999_999_999;
  }
  $self->auto_loot();
  return;
}

sub on_cryl_dropped {
  my $self = shift;
  $self->auto_loot();
}

sub on_odie {
  my ($self, $victim) = @_;

# originally Lev**1.8 ^6 but players seemed to think it was too hard
# so we're bouncing the other way, to Lev**1.7 * 20 + 0
# http://www.dillfrog.com/games/r2/help/exp_bonus.asp?new_exp_power=1.65&new_exp_multiplier=28&new_exp_add=0
#http://www.dillfrog.com/games/r2/help/exp_bonus.asp?new_exp_power=1.65&new_exp_multiplier=27&new_exp_add=0
#http://www.dillfrog.com/games/r2/help/exp_bonus.asp?new_exp_power=1.7&new_exp_multiplier=20&new_exp_add=0
  # leave this at top
  if($self->{'TYPE'}==1 && $victim->{'TYPE'}==2) {
     if(defined($self->{'A_HIST'}->{$victim->{'OBJID'}})) {
       
        my $killPct = $self->{'A_HIST'}->{$victim->{'OBJID'}} / ($victim->{'DAM_RCV'} || 100_000_000_000);
        my $ephy = ($victim->{'KEXP'} || int ( $victim->{'LEV'}**1.7 )*20 ) * $main::lightning_exp_multiplier;


      if($self->{'GAME'}) { 
           $self->{'ARENA_PTS'} += $killPct;
      }
      
        if($killPct >= .9 && $victim->{'REC'} && !vec($self->{'KILLREC'}, $victim->{'REC'}, 1)) {
           if($victim->{'LIMIT'}==1) { 
             $ephy *= 4;
           } else {
             $ephy *= (1.8 + 1/($victim->{'LIMIT'} || 1000));
           }
           vec($self->{'KILLREC'}, $victim->{'REC'}, 1) = 1;
           &main::rock_hrshout($self->{'RACE'}, "{16}$self->{'NAME'} {6}has disintegrated $self->{'PPOS'} first {16}$victim->{'NAME'}!\n") if !$self->{'ADMIN'};
           &main::log_event("First Kill", "$self->{'NAME'} ($main::races[$self->{'RACE'}]) has disintegrated $self->{'PPOS'} first $victim->{'NAME'}.", $self->{'UIN'}, $self->{'RACE'}, $victim->{'REC'}, undef) if !$self->{'ADMIN'};
        }
        
        my $exp = int($killPct * $ephy);
        
        $self->exp_add($exp);
        $self->trivia_add(STAT_NPCEXP, $exp);
        $self->trivia_max(STAT_NPCHIGH, $exp);
        
        delete $self->{'A_HIST'}->{$victim->{'OBJID'}};
     }
  } else {
      if($self->{'GAME'}) { 
           my $killPct = $self->{'A_HIST'}->{$victim->{'OBJID'}} / ($victim->{'DAM_RCV'} || 100_000_000_000);
           $self->{'ARENA_PTS'} += $killPct;
           delete $self->{'A_HIST'}->{$victim->{'OBJID'}};
      }
  }
  
  
  $self->auto_loot();
  return;
}

sub desc_hard {
  my $self=shift;
  if($main::pdescs{lc $self->{'NAME'}}) { return(&rockobj::wrap('','  ',$main::pdescs{lc $self->{'NAME'}})); }
#  elsif(ref($self->{'DESC'})) { return(&rockobj::wrap('','  ',${$self->{'DESC'}})); }
#  else { return(&rockobj::wrap('','  ',$self->{'DESC'}) || 'No description available.'); }
  else { return $self->SUPER::desc_hard(); }
}

sub desc_get {
    # returns string of item's description.
    my ($self, $looker) = @_;
    my $cap;
    
    if($main::races[$self->{'RACE'}]) {
        $cap .= "{15}( {1}".$main::races[$self->{'RACE'}].'{7} of field {1}' . ($self->{'GUILD'} || 'none')."{1} )\n";
    }
    if(defined($self->{'FX'}->{'33'})) {
        $cap .= "{2}$self->{'NAME'}\'s planar frequency must be garbled, for you cannot clearly see $self->{'PPRO'}.";
    } elsif($self->{'ADMIN'}) {
        $cap .= "{2}#### $self->{'NAME'} is one of those $main::adminmap[$self->{'ADMIN'}] {2}guys for the game. ####\n";
    } elsif(defined($self->{'FX'}->{'39'}) || ($self->{'SOLDIER'} && $main::rock_stats{'monolith_shadow'}==$self->{'RACE'})) {
        $cap .= $self->desc_hard()."\n\n{2}$self->{'NAME'}\'s figure is masked in a single dark shadow.";
    } else {
        $cap .= $self->desc_hard()."\n";
        if($looker) {
            $cap .= $looker->stat_compare($self, 0, 1, 2, 3, 4, 5);
        }
        $cap .= "{4}$self->{'NAME'} {14}appears to be ".$self->health_status()."{4}.\n";
        my @objs = $self->inv_objs();
        my ($wearing,@carr);
        if(@objs) {
            my ($o);
            foreach $o (@objs) { 
                unless ($o->is_invis()) {
                    if($o->{'WORN'}) {
                        $wearing .= sprintf('{2}[ {12}%20s{2} ] {6}%s'."\n", $o->{'ATYPE'}, $o->{'NAME'});
                    } elsif($self->{'WEAPON'} == $o->{'OBJID'}) {
                        $wearing .= sprintf('{6}[ {1}%20s{1} {6}] {11}%s'."\n", 'wielded', $main::objs->{$self->{'WEAPON'}}->{'NAME'});
                    } else {
                        push(@carr, $o->{'NAME'});
                    }
                }
            }
        }
    
        if($wearing) {
            $cap .= "{7}".$self->{'NAME'}.'{6} is wearing:'."\n$wearing";
        }
        else {
            $cap .= '{7}'.$self->{'NAME'}."{6} is quite nude at the moment.\n";
        }
        if(@carr) {
            $cap .= "{7}".$self->{'PRO'}.'{6} is carrying: {12}'. join(', ',@carr) . ".\n";
        }
    
        $cap = substr($cap, 0, length($cap)-1); # get rid of last return;
    }
    return '{40}' . $cap . '{41}';
}

sub attack_defend (attacker, victim) {
  my ($self, $attacker, $victim) = @_;
  if($self->{'TYPE'}==1 && ($self->{'HOSTILE'}==1 || !$self->{'HOSTILE'})) { return; }
  if($self->pref_get('verbose messages')) { $self->log_append("{13}You defend $victim->{'NAME'} because you are both allied.\n"); }
  $self->attack_sing($attacker);
  return;
}

sub attack_aggress (attacker, victim) {
  my ($self, $attacker, $victim) = @_;
  if($self->{'TYPE'}==1 && ($self->{'HOSTILE'}==2 || !$self->{'HOSTILE'})) { return; }
  if($self->pref_get('verbose messages')) { $self->log_append("{13}You join $attacker->{'NAME'}'s attack because you are both allied.\n"); }
  $self->attack_sing($victim);
  return;
}

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  #  || ($who eq $self) 
  if(!$self->pref_get('attack upon user entry') || $who->{'TYPE'}==0 || $self->is_tired || $main::map->[$self->{'ROOM'}]->{'SAFE'} ) { return; }
  if (!$self->cant_aggress_against($who)) { $self->attack_player($who, 1); }
  return;
}

sub on_rest {
  my ($self, $rester) = @_;
  if(!$self->cant_aggress_against($rester) && !$self->is_tired && $self->{'HOSTILE'}==HOS_ALL) { $self->attack_sing($rester); }
  return;
}

sub on_attack (objects: attacker, victim, weapon) {
  my ($self, $attacker, $victim, $weapon) = @_;
  if ($self eq $victim) { 
    if($self->{'AID'} == $attacker->{'OBJID'}){ delete $self->{'AID'}; }
    if( (rand(10) > 5) && ($self->{'HP'} < ($self->{'MAXH'}/5)) && ($self->{'TYPE'} != 1) && $self->{'LEV'}>20) 
         { $self->{'TRD'}=1; $self->auto_move(); }
   # if(!$self->is_tired) { $self->attack_sing($attacker); }
  } elsif ($self eq $attacker) { 
  } else {
#  $self->log_append("V: ".$self->is_my_friend($victim)." A: ".$self->is_my_friend($attacker)." CAGV: ".$self->cant_aggress_against($victim)."\n");
    if($self->is_tired) {                                           
    } elsif(($self->{'AID'} == $attacker->{'OBJID'})) { $self->attack_aggress($attacker, $victim);  
    } elsif($self->is_my_friend($victim) &&
          !$self->is_my_friend($attacker) && !$self->cant_aggress_against($attacker)) {
          $self->attack_defend($attacker, $victim); }
    elsif($self->is_my_friend($attacker) &&
          !$self->is_my_friend($victim) && !$self->cant_aggress_against($victim)) {  $self->attack_aggress($attacker, $victim); }
    elsif(($self->{'AID'} == $victim->{'OBJID'})){ 
      $self->room_talktell('{6}'.$self->{'NAME'}.'{16} screams in fury!'."\n");
      $self->attack_sing($attacker); 
    }
  }
  return;
}

sub on_room_exit (objects: exitee; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if ( $self ne $who ) { 
     if( $who->{'OBJID'} == $self->{'STALKING'} && !$self->is_in_a_group()) { 
        $self->log_append('{3}Following '.$who->{'NAME'}."...(Typing {17}$dir {3}for you)\n");
        my $tmplcom = $self->{'LCOM'};
    $self->cmd_do($dir);
        $self->{'LCOM'} = $tmplcom;
     } else {
        if($self->is_following($who)) {
            # follow if i am!
            my $tmplcom = $self->{'LCOM'};
            $self->cmd_do($dir); # try moving that way or else warn.
            $self->{'LCOM'} = $tmplcom;
        }
     }
     
  }
  return;
}

sub on_ask ($topic) {
 my ($self, $topic) = @_;
 if ( ($topic =~ /frog/) && $self->{'FX'}->{4} )  { return("$self->{'NAME'} ribbits, \"Frogs? $self->{'NAME'} like frogs!\"\n"); }
 else { return undef; }
 return("");
} 

sub rest_tempt {
 my $self = shift;
 if($self->{'HP'} == $self->{'MAXH'}) { return; }
 my $hp;
 do {
   $hp = $self->{'HP'};
   $self->rest();
 } while($self->{'HP'} >= $hp);
}


package npc_dupable;
@npc_dupable::ISA = qw( npc );
use strict;

sub on_die {
   my $self = shift;
   if(!$self->{'DUPS'} || !$self->{'DUPREC'}) { return; }
   for(my $i=0; $i<$self->{'DUPS'}; $i++) { 
      $self->room_sighttell('{2}'.$main::map->[$self->{'ROOM'}]->item_spawn($self->{'DUPREC'})->{'NAME'}."{3} stretches from $self->{'NAME'}\'s body.\n");
   }
   return;
}

package leech;
@leech::ISA = qw( npc );
use strict;

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  return if $who->is_dead() || $self->is_dead();
  
  if($self->cant_aggress_against($who)) { return; }
  if($who->aprl_rec_scan(314)) { return; }
  
  if(rand(100) < 50) { return; }
  $who->room_sighttell("{2}$self->{'NAME'} {4}attaches itself to {2}$who->{'NAME'}\'s body {4}and begins to drain $who->{'PPOS'} blood!\n");
  $who->effect_add(38);
  $self->obj_dissolve();
  return;
}


package antisin;
@antisin::ISA = qw( npc );
use strict;

sub on_receive {
  my ($self, $obj, $from, $amt) = @_;
  
  if($obj->{'REC'}!=379) { $self->say('Hmm..not quite what I need, but thanks anyway!'); $obj->obj_dissolve(); return; }
  
  if(++$self->{'AI'}->{'GOTPEAR'}->{$from->{'NAME'}} < 3) {
      $self->say('Ooh! A pear! Yummy! ..but I could use a few more!');
      $obj->obj_dissolve(); 
      return; 
  }
  delete $self->{'AI'}->{'GOTPEAR'}->{$from->{'NAME'}};
  $obj->obj_dissolve(); 
  if(!$from->quest_has(2)) { 
     $self->say("Ohhh thank you, $from->{'NAME'}. I'm looking forward to eating them later! Here, have this as a token of my thanks.");
     $from->quest_add(2);
     $from->log_append("{3}$self->{'NAME'} teaches you the basics of harnessing physicality and mentality.\n{14}You gain 20,000 experience.\n");
     $from->{'EXPMEN'}+=10_000;
     $from->{'EXPPHY'}+=10_000;
     $self->action_do('hug', $from->{'NAME'});
  } else {
     $self->say("Hey, thanks! You know I could never have too many of these, but you really didn't have to! You're such a sweetheart..");
     $self->action_do('kiss', $from->{'NAME'});
     $from->effect_add(3);
  }
  return;
}
 
sub on_ask {
 my ($self, $topic, $from) = @_;
 if ($topic =~ /teach|learn|skill|trick|help|assist/) { $self->say_rand('I\'d show you some skills but I\'m much too hungry for that right now..perhaps later.', 'Me? On an empty stomach? Pshaw!');  }
 elsif ($topic =~ /stomach|food|hungry|hunger|eat|pear/) { $self->say('Laugh.. well I guess you could say I\'m on a pear diet - I know that sounds silly, but those are the doctor\'s orders... and the world outside is much too scary for a lady like me to leave this room.');  }
 elsif ($topic =~ /female|girl|chic|lady/) { $self->say_rand('Just because I\'m female doesn\'t mean I can\'t fight! :(', 'Hey, I don\'t go around calling you a '.$main::races[$from->{'RACE'}].', now, do I?');  }
 elsif ($topic =~ /sex|intercourse/) { $self->say_rand('You sicko!', 'That\'s absurd!', 'Eeww..!!'); $self->action_do('slap', $from->{'NAME'}); }
 else { return undef; }
 return("");
} 

sub on_idle {
 $_[0]->room_talktell("{3}$_[0]->{'NAME'}\'s stomach growls.\n");
}
package gypsy;
@gypsy::ISA = qw( npc );
use strict;

sub on_cryl_receive {
 my ($self, $amt, $who) = @_;
 if ($who->{'GIFT'}->{'PORTENTS'}) {
   $self->say("$who->{'NAME'}, you fool! You are already versed in the art of portents. Begone!");
 } elsif( $amt > (3500 + rand(1000)) ) {
   $self->room_sighttell("{12}$self->{'NAME'} {2}nods approvingly and pulls out a deck of taron cards.\n");
   $self->say('I will teach you the art of portents now...');
   $who->{'GIFT'}->{'PORTENTS'}=2;
 } else {
   $self->room_talktell("{12}$self->{'NAME'} {2}laughs, \"Are you mad?! My talents are worth far more then this!\"\n{3}She slips the cryl into her cloak.\n{2}\"Consider this,\" she says, \"retribution for the insult you just made to all of gypsy-kind!\"\n");
 }
 delete $self->{'CRYL'};
 return;
}
 
sub on_ask {
 my ($self, $topic) = @_;
 if ($topic =~ /gypsy|future/) { $self->say_rand('I can teach you the art of the gypsies.. for a price.', 'I\'d tell you your future, but wouldn\'t you like to find it out for yourself? I can help you.. for a price.');  }
 elsif ($topic =~ /price|learn/) { $self->say_rand('For the price of 8000 cryl.. You will be able to tell your own fortunes!', 'That\'s right, you can learn to tell your own fortunes..for the price of only 8000 cryl!');  }
 else { return undef; }
 return("");
} 

sub on_idle {
  my $self = shift;
  if(rand(10)>7) { 
   SWITCH:for(int rand(3)) {
    /0/ && do { $self->say('Anyone up for some action?'); $self->cmd_do('wink'); last SWITCH; };
    /1/ && do { $self->say('If you\'re interested in the future, just ask!'); last SWITCH; };
    /2/ && do { $self->say('Doesn\'t anyone want to learn how to do things themselves these days?'); last SWITCH; };
   }
  } elsif(rand(10)>9) { 
   SWITCH:for(int rand(5)) {
    /0/ && do { $self->teleport($main::roomaliases{'managath'}); last SWITCH; };
    /1/ && do { $self->teleport($main::roomaliases{'varmoth-square'}); last SWITCH; };
    /2/ && do { $self->teleport($main::roomaliases{'desert-fadedpath'}); last SWITCH; };
    /3/ && do { $self->teleport($main::roomaliases{'cluckys'}); last SWITCH; }; 
    /4/ && do { $self->teleport($main::roomaliases{'hill-4thturn'}); last SWITCH; };
   }
  } else {
    # standard npc stuff
    if(($self->{'HP'} < $self->{'MAXH'}) && ($self->room_safe)) { $self->rest; }
    elsif(rand(10)>2) { $self->auto_move(); }
    else { $self->pick_something_up; $self->equip_best(); }
  }
  return;
}


package rabbit;
@rabbit::ISA = qw( npc ); 
use strict;

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if( (rand(10) > 7) || ($self->{'HP'}<=0) )  { return; }
  if ($dir && (!$self->cant_aggress_against($who))) { $self->cmd_do($dir); }
  return;
}

package frog;
@frog::ISA = qw( npc ); 
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  $self->{'DIGEST'}=1;
  $self->{'DLIFT'}=1; $self->{'CAN_LIFT'}=1;
  return($self);
}
sub on_ask { undef; }

sub on_digest {
  # make modifications 
  my ($self, $digester) = @_;
  $digester->log_append("{12}$self->{'NAME'} squirms down your throat in a final cry for dignity.\n");
  $digester->{'HP'}+=$self->{'HP'} unless ($self->{'HP'}<=0);
  $digester->{'HP'} = $digester->{'MAXH'} if ($digester->{'HP'} > $digester->{'MAXH'});
  return;
}

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if( (rand(10) > 7) || ($self->{'HP'}<=0) )  { return; }
  if ($dir && (!$self->cant_aggress_against($who))) { $self->cmd_do($dir); }
  return;
}

sub on_idle {
  my $self = shift;
  if( (rand(20) < 5) && $self->{'CONTAINEDBY'} && defined($main::objs->{$self->{'CONTAINEDBY'}}) && ($main::objs->{$self->{'CONTAINEDBY'}}->{'TYPE'}==1)) {
    
    my $cby =  &main::obj_lookup($self->{'CONTAINEDBY'});
    if(!$cby->inv_has($self)) { return; } ## prevent stk errors
    $self->say_rand('Fear not, Elvis! I will find you!', 'Good bye, Cruel World!', 'Eh, I didn\'t want my stomach anyway.', 'Nice Meeting You, '.$cby->{'NAME'}, 'Farewell, '.$cby->{'NAME'}.'!', 'Hey!! Don\'t drop meeEeEE!!!....' );
    $cby->log_append("{2}You notice $self->{'NAME'} winding up to punch itself in the face!\n");
    $self->die();
  }
}


package wight;
@wight::ISA = qw( npc ); 

sub on_die {
  # is called right before dying
  my $self = shift;
  $self->room_talktell($self->{'DEATHMSG'} || "{16}$self->{'NAME'} {4}cackles ear-piercingly in a fina{13}---\n");
  $self->explode();
  return;
}

sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  $self->{'FLAM'}=90 unless $self->{'FLAM'};
  $self->{'KJ'}=80000 unless $self->{'KJ'};
  return($self);
}

package npc_kain;
@npc_kain::ISA = qw( npc ); # note!! USED TO check object *BEFORE* player object.
use strict;


sub on_ask ($topic) {
    my ($self, $topic, $from) = @_;
    if($topic =~ /cryl/) { $self->say_rand('Cryl? Yeah - you\'d think something else would be used as currency, like body parts.', 'Too bad it\'s not edible.', 'That reminds me of an old poem.');  }
    elsif($topic =~ /poem/) { $self->say_rand('Ahem.. Cryl, cryl, you are cryl. I am cryl and you are crylly, you crylly cryl.', '..I think that I shall never see.. a cryl as lovely as that of me.. wait! That\'s not right!', 'Ahem.. Here a cryl, there a cryl, everywhere a cryl-cryl.. Old McCrylly had a cryl: e i e i o.. er wait a minute!');  }
    elsif($topic =~ /currency|money/) { $self->say('Well, cryl\'s the only currency I know of. So many people kept stealing and pounding gold that, well, it wasn\'t a reliable source of currency. I sure hope *that* doesnt happen again!');  }
    elsif($topic =~ /people/) { $self->say('People! They\'re everywhere! Trimorals save us all!');  }
    elsif($topic =~ /\d\i\e/) { $self->say('I tried that once - death just ain\'t my thang!');  }
    elsif($topic =~ /interest/) { $self->say('Interest? Interest? Who cares about interest? It\'s not even interesting that you asked me about interest!');  }
    elsif($topic =~ /deposit/) { $self->say('Ya know, you can deposit money by typing "deposit <amount>"!');  }
    elsif($topic =~ /withdraw/) { $self->say('Ya know, you can withdraw money by typing "withdraw <amount>"!');  }
    elsif($topic =~ /standing|account|have/) { $self->say('You can check how much cryl\'s deposited by typing "bank" or "account"!');  }
    elsif($topic =~ /bank/) { $self->say_rand('Yep! And it\'s all mine! Ain\'t she a beaut?', 'Yep. I\'ll take banking over killing any day.', 'Banking\'s the life. You should try it sometime.');  }
    elsif($topic =~ /sell/) { $self->say_rand('Sell? In a bank? Try that in a store.', 'I don\'t sell anything. I\'m just a banker.', 'Try a store if you want to sell stuff.');  }

    else { return undef; }
    return("");
} 

package npc_sludgeguard;
@npc_sludgeguard::ISA = qw( npc ); 
use strict;

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if ($self != $obj) { 
     SWITCH:for (lc($saystr)) {
      /epa|sludge/ && do { $self->say_rand("Sludge? What sludge? I didn't see any sludge!", "The last time I saw sludge here was back in 1969.. my pa used to feed it to me with coleslaw and..", "Get outta here, kids. Now! Scoot!"); last SWITCH; };
      /guard/ && do { $self->say_rand("Are you talkin' to me? Eh? Are YOU.. talkin' ta ME?", "Guards are so unappreciated - people think keeping secrets is sooo easy. Heh! Well you just try keeping sludge secrets away from the EPA and see how long YOU last!"); last SWITCH; };
      /salp/ && do { $self->say_rand("Salp. Sure could use some."); last SWITCH; };
     }
  }
  return;
}

sub on_idle {
  my $self = shift;
  if(rand(10)>9) { return; }
  SWITCH:for(int rand(6)) {
    /0/ && do { $self->cmd_do('glare all'); last SWITCH; };
    /1/ && do { $self->room_sighttell("{3}$self->{'NAME'} fixes his belt.\n"); last SWITCH; };
    /2/ && do { $self->cmd_do('yawn'); last SWITCH; };
    /3/ && do { $self->room_sighttell("{3}$self->{'NAME'} looks around the room cautiously.\n"); last SWITCH; };
    /4/ && do { $self->room_sighttell("{3}$self->{'NAME'} tosses his club around.\n"); last SWITCH; };
    /5/ && do { $self->room_sighttell("{3}$self->{'NAME'} peeks out the Lookout Point.\n"); last SWITCH; };
  }
  return;
}

package npc_clucky;
@npc_clucky::ISA = qw( npc ); 
use strict;

sub on_ask ($topic) {
 my ($self, $topic, $asker) = @_;
 $topic = lc($topic);
 if ($topic =~ /clucky|plucky/) { $self->say_rand('My name is Clucky, I think it\'s good, for I have a clucky, plucky hood.', '"Clucky cluck cluck" they\'d call me in school, which wasn\'t all that very cool.', 'I should say it\'s better than Joe, but who\'s to say that I would know!.');  }
 elsif ($topic =~ /\bday\b/) { $self->say('Days, oh days, they\'re quite the same. People leave the way they came.');  }
 elsif ($topic =~ /\bbarn\b/) { $self->say('Barns, oh barns, they live on farms! Now I operate a Bar!');  }
 elsif ($topic =~ /beer|alcohol|wine/) { $self->say('Talk \'bout THAT when you\'ve come so far? This is but an all-ages bar.');  }
 elsif ($topic =~ /dirt/) { $self->say('Dirty dirt dirt, yummy yum yum! Tastes great and costs less than gum!');  }
 elsif ($topic =~ /\b(drink|bar|meal|eat)\b/) { $self->say_rand('If you are hungry, try some Cluckle! It\'s real good and low on cryl!', 'I\'d give ya some oranges and peanuts and stuff, but last time I did, the Taer threw up!', 'Order something here or else. I gotta make a living for myself!');  }
 elsif ($topic =~ /cluckle/) { $self->say('Cluckle, cluckle! Make sure you\'re buckled! Spend a few cryl and drink a truck-load!');  }
 elsif ($topic =~ /hole/) { $self->say('Oh, I see, is *that* your goal? Fine, enter that little hole!'); $self->room_sighttell("{3}Clucky points toward the energy hole.\n"); }
 elsif ($topic =~ /buy|\send/) {
    my ($o, $drinkobj);
    foreach $o ($self->inv_objs) { if ($o->{'REC'}==57) { $drinkobj=$o; } }
    if ($self->{'AI'}->{'GAVEDRINK'}->{$asker->{'NAME'}}) {
        $self->say("Hey, you already got your share, $asker->{'NAME'}!");
    } elsif($drinkobj) {
        if ($self->item_hgive($drinkobj, $asker)) {
            $self->cmd_do("tell $asker->{'NAME'} sshh! It's on me!");
            $self->{'AI'}->{'GAVEDRINK'}->{$asker->{'NAME'}}=1;
        }
    } else {
        $self->say_rand('We\'re all out.', 'Don\'t have any.', 'Nope.', 'Sorry, all gone.', 'Nah-ah!'); 
    }
 }
 elsif ($topic =~ /hood/) { $self->say_rand('It\'s through that hole I got my hood. You really, really think it\'s good?', 'Hoods are weird, they come from moles. You might find some right through that hole!', 'I didn\'t get this hood from this neighborhood.');  }
 else { return undef; }
 return("");
} 


package bounty_warden;
@bounty_warden::ISA = qw( npc ); # note!! USED TO check object *BEFORE* player object.
use strict;

sub on_receive {
  my ($self, $obj, $from, $amt) = @_;
  if($obj->{'BOUNTYFROM'}) { 
     if(!($amt = $main::bounties{lc($obj->{'BOUNTYFROM'})})) { $self->say("Sorry $from->{'NAME'}, looks like someone already claimed that bounty!"); }
     elsif($main::bounty_codes{lc($obj->{'BOUNTYFROM'})} != $obj->{'BOUNTYCODE'}) { $self->say("It appears as if this $obj->{'NAME'} was from before the bounty was being offered. Sorry! ($main::bounty_codes{lc($obj->{'NAME'})} and $obj->{'BOUNTYCODE'})"); }
     else {
        $self->say("Thanks for disposing of $obj->{'BOUNTYFROM'}! Hold on, I've got your reward right..");
        if(lc($obj->{'BOUNTYFROM'}) eq lc($from->{'NAME'})) {
          $self->say("..Yikes! You ARE $obj->{'BOUNTYFROM'}! Egads! Get away!");
          return;
        } elsif(lc($obj->{'BOUNTYKILLEDBY'}) ne lc($from->{'NAME'})) {
          $self->say("..Liar! You could never have killed $obj->{'BOUNTYFROM'}! Try scamming someone else!");
          return;
        }
        $self->{'CRYL'} += $amt;
        delete $main::bounties{lc($obj->{'BOUNTYFROM'})};
        delete $main::bounty_codes{lc($obj->{'BOUNTYFROM'})};
        $self->cmd_do("give $amt to $from->{'NAME'}");
        $self->say("..here!");
     }
  } else {
     $self->say_rand('So?', '..and this is supposed to prove something?', 'I don\'t want this!', 'Oh. We\'ve got tons of these in the back.', 'What\'s your point?');
     $obj->obj_dissolve;
  }
  return;
}

sub on_cryl_receive {
  my ($self, $amt, $who) = @_;
  $who->log_append("{3}The warden does not want your money.\n{6}Hint: Try {16}bounty <name> <amount>{6} instead!\n");
  $self->cryl_give($amt, $who);
  return;
}

package npc;
@npc::ISA = qw( player ); # note!! USED TO check object *BEFORE* player object.
use strict;

sub can_be_lifted { return(!$_[0]->is_dead); }


sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  return($self);
}

sub on_rest {
  my ($self, $rester) = @_;
  #&main::rock_shout(undef, "{11}Debug: can't:  $aggress  tired: $amtired  hostile: $hostile\n", 1);
  if((!$self->cant_aggress_against($rester)) &&
      !$self->is_tired() &&
      ($self->{'HOSTILE'} == 3)
     ) {
         $self->attack_sing($rester, 1); # no tiredness penalty
     } else {
         $self->{'HP'}+=int($self->{'MAXH'}*.05);
         if($self->{'HP'}>$self->{'MAXH'}) { $self->{'HP'}=$self->{'MAXH'}; }
     }
  return;
}

sub on_ask ($topic) {
 my ($self, $topic) = @_;
 if ($topic =~ /frog/) { return("{1}$self->{'NAME'} greedily replies.. {3}Frogs? $self->{'NAME'} like frogs!\n"); }
 return undef;
} 


#sub desc_hard {
#  # SAME AS PLAYER
#  my $self=shift;
#  if(ref($self->{'DESC'})) { return(&rockobj::wrap('','  ',${$self->{'DESC'}})); }
#  else { return(&rockobj::wrap('','  ',$self->{'DESC'}) || 'No description available.'); }
#}

sub on_cryl_receive {
  my ($self, $amt, $who) = @_;
  $who->log_append("{3}$self->{'NAME'} does not appear to be interested in your money.\n");
  $self->cryl_give($amt, $who);
  return;
}

sub on_receive {
  my ($self, $obj, $from) = @_;
#  $self->say("Hey, thanks for the $obj->{'NAME'}, $from->{'NAME'}!");
  if(ref($obj) eq 'frog') { 
    if(ref($self) eq 'frog') {
      $self->say("Disgusting! Be free, little frog, be free!");
      $self->room_tell("{2}$self->{'NAME'} hops away.\n");
      $obj->dissolve_allsubs();
    } else {
      $self->cmd_do('eat '.$obj->{'NAME'});
      $self->cmd_do('tell '.$from->{'NAME'}.' mmm! me like frogs!');
      $self->{'CRYL'}+=3;
      $self->cmd_do('give 3 to '.$from->{'NAME'});
    }
  } elsif ($obj->{'NOSAVE'}) {
	$obj->dissolve_allsubs();
  }
  return;
}

sub attack_sing {
  my ($self, $victim, $notired) = @_;
  if( (  $self->{'LIMIT'} > 1 &&
         rand(10) < 7 &&
         !$self->{'SENT'}
      )
# PLAT GOT RID OF MEE      || $victim->{'RESTACTIVE'}
    ) { return &rockobj::attack_sing(@_); }
      
  my $weapon = $self->weapon_get();
  
  return if $self->is_dead();

  my $targ = $self->ai_get_hostile_target($victim);
  
  if( ($targ)  &&  ($weapon)  ){ 
       $self->attack_melee($targ, $weapon, $notired); 
  }
}

sub on_order ($topic) {
    my ($self, $topic, $by) = @_;
    return undef if $self->{'AID'} ne $by->{'OBJID'} && !$by->{'ADMIN'};
   
    my ($fw) = $topic =~ /^([^ ]+)/;
    $fw = lc($fw);
    
    if($self->{'LEV'} < 50 && $by->{'ADMIN'} && $topic =~ /die/i) {
        $self->die();
    } elsif ($main::amap->{$fw}) { 
        if( $self->action_do(split(/ /, $topic, 2)) != 1) { $self->action_do('shrug'); };
        return('');
    } elsif (
            ($topic =~ /^(?:move|go)?\s*(\w+)/i)
            &&
            $main::dircondensemap{lc($1)}
          ) { $self->realm_move($main::dircondensemap{lc($1)}, 1); return(''); }
    return undef;
} 

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  $saystr = $$saystr;
  if ($self != $obj) { 
     if( ($saystr =~ / poop/) && (rand(20) < 5) ) {
       $self->say("Poop is smelly");
     }
  }
  return;
}

sub on_cleanup { }

sub on_idle {
  if(($_[0]->{'HP'} < $_[0]->{'MAXH'}) && $_[0]->room_safe()) { $_[0]->rest; }
  elsif((rand(10)>6) || !$_[0]->pick_something_up() ) { 
    if(!$_[0]->{'STALKING'}) { $_[0]->auto_move(); }
  } else { $_[0]->equip_best(); }
  return;
}

sub on_packcall() {
 my ($self, $caller, $radius, $dir) = @_;
 if($caller->{'RACE'}==$self->{'RACE'}) {
   # move closer if/when possible
   while( ($caller->{'ROOM'} != $self->{'ROOM'}) && ($self->realm_move($dir)) ) {
     $caller->packcall($radius);
   }
   # stalk the caller
   $self->{'STALKING'}=$caller->{'OBJID'};
 }
}

sub can_enter {
  my ($self, $room) = @_;
  if ($main::maps->[$room]->{'NOMOB'}) { return(0); }
  return 1;
}

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if( (rand(10) > 4) || ($self eq $who) || ($self->{'HOSTILE'}!=3) || $self->is_tired || ($self->{'HP'}<=0) ) { return; }
  if ( ($self->{'HP'} < ($self->{'MAXH'}/4)) && $dir && $self->{'LEV'}>20) { $self->cmd_do($dir); }
  elsif (!$self->cant_aggress_against($who)) { 
     # $self->attack_sing($who, 1);
     my $targ = $self->ai_get_hostile_target($who);
      $self->attack_player($targ, 1) if $targ;
      ##$self->attack_sing($who) if $who;
  }
  return;
}

sub on_room_exit (objects: exitee; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if ( $self ne $who ) { 
     if( $who->{'OBJID'} eq $self->{'STALKING'} ) { 
        $self->log_append('{3}Following '.$who->{'NAME'}."...(Typing {17}$dir {3}for you)\n");
        $self->cmd_do($dir);
     } elsif(!$who->{'ADMIN'} && ($self->{'LEV'} > 18) && !$self->cant_aggress_against($who, 1) && (!$who->{'SCURRYACTIVE'} || (rand(10)<2)) && (($who->{'HP'}/$who->{'MAXH'})<.25) && !$self->{'SENT'} && (rand(10)<7) && $main::dirlongmap{$dir} ) {
        $self->realm_move($dir);
        delete $self->{'TRD'};
        if( (rand(10)<6) && ($self->{'HOSTILE'}==3) ) { $self->attack_sing($who); }
     } elsif(!$self->{'ADMIN'} && !$self->cant_aggress_against($who, 1)  &&  (($self->{'HP'}/$self->{'MAXH'}) < 0.7) && (rand(1) < .5) ) {
        # rest up :-)
        unless ($self->{'MONOLITH'}) {
            my $dam = int ( (((rand($self->{'MAXH'}/4))+($self->{'MAXH'}/6)))*($self->fuzz_pct_skill(8,20)+$self->fuzz_pct_skill(19,20)) );
            $self->{'HP'} += int(.8*$dam); if($self->{'HP'}>=$self->{'MAXH'}) { $self->{'HP'} = $self->{'MAXH'}; }
        }
     }
  }
  return;
}


package shadow_assassin;
@shadow_assassin::ISA = qw( npc );
use strict;

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  if ( !$self->cant_aggress_against($who) && !$who->is_dead ) { 
   if(!$who->got_lucky(6)) { 
    my $dam = int ( $who->{'MAXH'}/4 - 10 + rand(21) );
    
    $who->room_sighttell("{1}$self->{'NAME'} stabs his twin blades easily into $who->{'NAME'}\'s back, doing $dam damage!\n");
    $who->log_append("{1}A pair of darkened blades runs through your back, causing immense pain!\n");
    
    $who->{'HP'} -= $dam;
    
    if($who->{'HP'}<=0) { $who->die; }
    else { $self->attack_sing($who, 1); }
    
   } else {
    $who->log_append("{6}A pair of darkened blades flies past you!\n");
    $who->room_sighttell("{6}$self->{'NAME'} flings his twin blades alongside $who->{'NAME'}\'s back, just barely missing!\n");
   }
  }
  return;
}

package shadow_mage;
@shadow_mage::ISA = qw( npc );
use strict;

sub protectme { 
   my $self = shift;
   $self->room_sighttell("{1}$self->{'NAME'} solidifes the darkness around him, making it difficult to attack!\n");
   $self->{'AI'}->{'PROTECT'}=time + 10;
}

sub dam_defense {
    ## passed attacker object. returns defense value (the higher the better)
    my ($self, $a, $w) = @_;
    if($self->{'AI'}->{'PROTECT'} > time) { return (1000000000000000000); } # AOFFSET is the total AC of all armour
    return ( int rand(50) );
}

sub attack_sing {
  my ($self, $victim) = @_;
  if(!ref($victim)) { &main::rock_shout(undef,"$self->{'NAME'} tried a-sing crash.\n", 1); }
  if($victim->is_dead || $self->is_dead) { return; }
  else {
    if(rand(100)<20) { $self->spell_ebony_blast($victim); }
    elsif( (rand(100)<20) && ($self->{'AI'}->{'PROTECT'} < time) ) { $self->protectme; }
    elsif($self->{'WEAPON'}) { $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}}); }
    elsif($self->{'DWEAP'}) {  $self->attack_melee($victim, &main::obj_lookup($self->{'DWEAP'})); }
    return;
  }
}

sub on_idle {
  my $self = shift;
  my @p = $main::map->[$self->{'ROOM'}]->inv_spobjs;
  if(!@p) { return; }
  my $victim = $p[int rand($#p+1)];
  $self->attack_sing($victim);
  return;
}

package rest_assassin;
@rest_assassin::ISA = qw( npc );
use strict;
# appears when bounty'd folks rest.. bahahah

sub def_set {
  my $self = shift;
  $self->prefmake_npc();
  $self->{'NAME'}='Mistrana' unless $self->{'NAME'};
  if (!$self->{'DESC'}) { 
    $self->{'DESC'}=$self->{'NAME'}.' slides softly across the floor, flexing her muscles whenever time allows. The only thing keeping her from staring at you is your wallet.';
  }
  $self->gender_set('F');
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  $self->{'BASEH'}=50;
  return($self);
}

sub sick_em (obj) {
  # sicks object :-)
  my ($self, $o) = @_;
  $self->{'STALKING'}=$o->{'OBJID'};
  $self->{'ROAMTARG'}=$o->{'OBJID'};
  $main::events{$self->{'OBJID'}}=1;
  $o->{'WANTED'}++;
  return;
}

sub on_idle {
  my $self = shift;
  my $v = $main::objs->{$self->{'ROAMTARG'}};
  if (!$v ||
      !$self->{'ROAMTARG'} ||
      !$v->{'WANTED'} ||
      ($self->{'AI'}->{'GIVEUP'} && ($main::map->[$v->{'ROOM'}]->{'M'} != $main::map->[$self->{'ROOM'}]->{'M'} ||
      $self->ai_moves_to($v) > 5 )) ) {
      $self->room_sighttell("{6}$self->{'NAME'} {16}dissipates in displeasure.\n");
      $self->obj_dissolve();
      return;
  }
  
  if ($self->{'ROOM'} != $v->{'ROOM'}) {
      $self->ai_move_to($v);
  } elsif (!$self->is_tired()) {
      $self->attack_player($v, 1);
  }
  $main::events{$self->{'OBJID'}}=5;
  return;
}

sub auto_move {}

sub on_kill {
  my ($self, $victim) = @_;
  $self->cmd_do('smile');
  if($self->{'ROAMTARG'} == $victim->{'OBJID'}) {
    my $i;
    foreach $i ($main::map->[$self->{'ROOM'}]->inv_objs) { if(ref($i) eq 'bodypart') { $self->cmd_do("g $i->{'NAME'}"); } }
    $self->cmd_do('loot');
    if(!$self->room()->{'PVPROOM'} && !$self->{'NOBOUNTY'} && $main::bounties{lc($victim->{'NAME'})}) {
       $victim->{'LAST_ASSASSINATION_DEATH'} = time;
       $self->room_sighttell("{6}$self->{'NAME'} {16}claims the bounty on $victim->{'NAME'}, and dissipates in greed.\n");
       delete $main::bounties{lc($victim->{'NAME'})};
    }
    delete $self->{'CRYL'};
    $self->obj_dissolve;
  }
  return;
}

sub on_event {  $_[0]->on_idle; }

package npc_alert;
@npc_alert::ISA = qw( npc );
use strict;

sub on_noise (from_direction, object_that_made_noise, noise_desc, [ verbose_desc ]) {
  ## Registered briefs: talking.
  my ($self, $dir, $obj, $brief, $verbose) = @_;
  if (rand(10) > 9) {
   $self->realm_move($dir);
   $self->say_rand('Oof! I thought I heard a noise!', 'What was that?', 'Hey you! Yeah, you '.$obj->{'NAME'}.'!', 'Would you quiet down in here?', 'Quiet!', 'Calm down already!');
  }
  return;
}

package orc_fanatic;
@orc_fanatic::ISA = qw( npc );

sub attack_sing {
  my ($self, $victim) = @_;
  if($victim->is_dead || $self->is_dead) { return; }
  else {
    if(rand(100)<50) { $self->orc_suikill($victim); }
    elsif($self->{'WEAPON'}) { $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}}); }
    elsif($self->{'DWEAP'}) {  $self->attack_melee($victim, &main::obj_lookup($self->{'DWEAP'})); }
    return;
  }
}

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  &npc::on_room_enter(@_);
  if(!$self->cant_aggress_against($who)) {
    $self->{'AI'}->{'SUIKILL'}=$who->{'OBJID'};
    $main::events{$self->{'OBJID'}}=(5+int rand(10)) unless $main::events{$self->{'OBJID'}};
  }
  return;
}

sub on_event {
  my $self = shift;
  my $oid = $self->{'AI'}->{'SUIKILL'};
  if(!defined($main::objs->{$oid}) || !$main::objs->{$oid}) { return; }
  $self->orc_suikill($main::objs->{$oid});
  return;
}

sub orc_suikill {
  my ($self, $victim) = @_;
  if($self->is_dead() || $victim->is_dead() || ($victim->{'ROOM'} != $self->{'ROOM'})) { return; }
  delete $self->{'CRYL'}; # no cryl on a suikill
  my $dam = int($victim->{'MAXH'}/2 - 20 + int rand(41));
  $victim->log_append("{2}The $self->{'NAME'} hops from foot to foot, then leaps at you! His chest spike wounds you for {12}$dam {2}damage.\n");
  $victim->room_sighttell("{2}The $self->{'NAME'} hops from foot to foot, then leaps at {12}$victim->{'NAME'}\{2}! His chest spike wounds $victim->{'NAME'} for {12}$dam {2}damage.\n");
  $victim->{'HP'}-=$dam;
  if($victim->is_dead()) { $victim->die($self); }
  $self->die();
  return;
}

package incorporeal;
@incorporeal::ISA = qw( npc );

sub incorporeal::dam_defense {
    ## passed attacker object. returns defense value (the higher the better)
    my ($self, $a, $w) = @_;
    if(!$w->{'INCORP'}) { return (1000000000000000000); } # AOFFSET is the total AC of all armour
    return ( int rand(20) );
}

package eldar_quest_baby;
@eldar_quest_baby::ISA = qw( npc );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  $self->{'NAME'}='baby' unless $self->{'NAME'};
  $self->{'DLIFT'}=$self->{'CAN_LIFT'}=1;
  return($self);
}

sub on_idle {
  my $self = shift;
  if(!$self->{'CONTAINEDBY'} || !$main::objs->{$self->{'CONTAINEDBY'}} || !$main::objs->{$self->{'CONTAINEDBY'}}->inv_has($self) ) {
     return;
  }
  if(rand(10)>9) { return; }
  SWITCH:for(int rand(3)) {
    /0/ && do { $self->room_talktell("{3}The $self->{'NAME'} whines loudly, tears pouring down her soft plump face.\n"); last SWITCH; };
    /1/ && do { $self->room_sighttell("{3}Tooting noises come from the little $self->{'NAME'}, as she glances around for her mother.\n"); last SWITCH; };
    /2/ && do { $self->room_sighttell("{3}A foul stentch wafts up from the $self->{'NAME'}... It seems as if she has had a little accident.\n"); last SWITCH; };
  }
  return;
}


package eldar_quest_noblewoman;
@eldar_quest_noblewoman::ISA = qw( npc );
use strict;

sub on_attack {
  my ($self, $attacker, $victim, $weapon) = @_;
  if ($self eq $victim) { 
    $attacker->room_sighttell("{5}The Eldar noblewoman frowns darkly and points a finger at $attacker->{'NAME'}.\n");
    $attacker->log_append("{5}The Eldar noblewoman frowns darkly and points a finger at you.\n");
    $attacker->effect_add(6);
    if($attacker->{'CRYL'}) {
      $attacker->room_sighttell("{3}A planar thief sneaks in from the planos and loots $attacker->{'NAME'}\'s inventory, then disappears in a flash.\n");
      $attacker->log_append("{3}A planar thief sneaks in from the planos and loots your inventory, then disappears in a flash.\n");
      delete $attacker->{'CRYL'};
    }
  }
  return;
}

sub die {  my $self = shift; $self->{'HP'}=$self->{'MAXH'}; }

sub on_ask ($topic) {
 my ($self, $topic) = @_;
 if ( ($topic =~ /baby|help|demon/) )  { return("\"Yes.\" The Eldar Noblewoman replies. \"A demon stole my baby and ran off\ninto the dimensional nexus. I believe he went into the Plane of\nDamnation. Before he left, he dropped something that looks valuable. If\nyou get my baby for me, I will give it to you. Hurry, before something\nbad happens!\"\n"); }
 else { return undef; }
 return("");
} 

sub on_idle {
  my $self = shift;
  if(rand(10)>9) { return; }
  SWITCH:for(int rand(2)) {
    /0/ && do { $self->room_sighttell("{3}The $self->{'NAME'} sighs loudly, dabbing at her tears with a soft satin handkerchief.\n"); last SWITCH; };
    /1/ && do { $self->room_sighttell("{3}With a sob, the $self->{'NAME'} says, \"Someone stole my baby... A demon of some kind! Please help me!\"\n"); last SWITCH; };
  }
  return;
}

sub on_receive {
  my ($self, $obj, $from) = @_;
  if($obj->{'REC'}==271) {
    $self->room_talktell("{17}\"OH thanks you!\" cries the Eldar Noblewoman. \"here.. take this as payment.\"\n");
   
    if(!$from->quest_has(0)) {
      $self->{'CRYL'}=1000;
      $self->cryl_give(1000, $from);
      $from->quest_add(0);
      # exp reward
      $from->{'EXPMEN'}+=1500; 
      $from->log_append("{17}You gain {1}1,500 {17}mental experience.\n"); 
    }
    
    my $i = $self->item_spawn(213);
    $self->item_hgive($i, $from);
    $self->room_sighttell("{6}The Eldar Noblewoman grabs her baby tightly, and presses several buttons on her silver bracelet. A small portal opens up, and she jumps through. Without a sound, the portal closes quickly behind her.\n");
    # respawn self -- I didn't die, so the onDeath_RESPAWN isn't otherwise executed.
    $main::eventman->enqueue($self->{'onDeath_RESPAWN'} * 60, \&rockobj::item_spawn, $self->container(), $self->{'REC'});
    $self->dissolve_allsubs;
  }
  return;
}

package drunk_demon;
@drunk_demon::ISA = qw( npc );
use strict;


sub on_idle {
  my $self = shift;
  if(rand(10)>9) { return; }
  SWITCH:for(int rand(3)) {
    /0/ && do { $self->room_sighttell("{3}The drunken rolls over on his stomache, letting loose with a foul belch.\n"); last SWITCH; };
    /1/ && do { $self->room_talktell("{3}The drunken demon mutters in his alchol-induced stupor, 'All hail the tentacled one!'\n"); last SWITCH; };
    /2/ && do { $self->room_talktell("{3}With a groan the drunken demon spits in disgust, 'Damn prison guards making me work all night!'\n"); last SWITCH; };
 }
  return;
}

package bloodlord;
@bloodlord::ISA = qw( npc );
use strict;

sub attack_sing {
  my ($self, $victim) = @_;
  if($victim->is_dead || $self->is_dead) { return; }
  else {
    if(rand(100)<40) { $self->hdecapitate($victim); }
    elsif($self->{'WEAPON'}) { $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}}); }
    elsif($self->{'DWEAP'}) {  $self->attack_melee($victim, &main::obj_lookup($self->{'DWEAP'})); }
    return;
  }
}

package vampire_quest;
@vampire_quest::ISA = qw( npc );
use strict;

sub on_idle {
  my $self = shift;
  $self->room_talktell("{2}The starved vampire pulls weakly at his chains. He looks up to you with hallowed eyes \"Please.. bring me blood. It will be worth your trouble.\"\n");
}

sub on_receive {
  my ($self, $obj, $from, $amt) = @_;
  if($obj->{'REC'}==156) { 
    $self->room_sighttell("{2}The starved vampire greedily slurps down the blood, with a sigh of relief. He eyes you for a moment, then pulls of a ring from his finger. \"Your assistance is appreciated. Take this, as a reward.\"\n");
    my $o=$self->item_spawn(157);
    $obj->obj_dissolve;
    $self->item_hgive($o, $from);
    $self->room_sighttell("{3}With a final wave, the vampire rushes from the cell, dispappearing quickly within the engulfing shadows.\n");
    # respawn self -- I didn't die, so the onDeath_RESPAWN isn't otherwise executed.
    $main::eventman->enqueue($self->{'onDeath_RESPAWN'} * 60, \&rockobj::item_spawn, $self->container(), $self->{'REC'});
    $self->obj_dissolve();
  }
}

package thief;
@thief::ISA = qw( npc );
use strict;

sub def_set {
  my $self = shift;
  $self->prefmake_npc;
  $self->{'NAME'}='thief' unless $self->{'NAME'};
  $self->gender_set('M');
  $self->{'DLIFT'}=0; $self->{'CAN_LIFT'}=0;
  $self->{'ALOOT'}=1;
  return($self);
}

sub on_item_drop (who, what,...) {
  ## Registered briefs: talking.
  my ($self, $who, $what) = @_;
  if (($self ne $who) && $what->{'VAL'} && !$what->{'JUNK'} && $self->can_lift($what) && $what->can_be_lifted($self)) {
    $self->item_get($what->{'NAME'});
    $self->cmd_do("hug $what->{'NAME'}");
  }
  return;
}

sub on_idle {
 my $self = shift;
 if(($self->pick_something_up)[1]) {
    $main::events{$self->{'OBJID'}}=1;
 } elsif(($self->{'HP'} < $self->{'MAXH'}) && ($self->room_safe)) { $self->rest; }
 elsif(rand(10)>6) { $self->auto_move(); }
}

sub on_event {  
    if(($_[0]->pick_something_up)[1]){ $main::events{$_[0]->{'OBJID'}}=1; }
}

package guard_hound;
@guard_hound::ISA = qw( npc );
use strict;

sub on_itemthrew (item, thrower, fromdir) {
  my ($self, $item, $thrower, $fromdir) = @_;
  if($item->{'EDIBLEBAIT'} && $self->item_get($item->{'NAME'})) {
     $item->on_hdigest($self);
     $self->room_sighttell("{3}$self->{'NAME'} disappears, sated.\n"); 
     $self->obj_dissolve();
  }
  return;
}

package monolith_guardian;
@monolith_guardian::ISA = qw( npc );
use strict;
use rockdb;

sub prefmake_npc {
  my $self = $_[0];
  &rockobj::prefmake_npc(@_);
  $main::monolithstoobjid{$self->{'MONOLITH'}} = $self->{'OBJID'};
  $self->{'NOSICK'} = 1; # dont make me sick -- too easy to plagueball me
}

sub on_room_enter {
    my $self = shift;
    $main::events{$self->{'OBJID'}} ||= 5;
}

sub on_before_die {
    my ($self, $killer) = @_;
    return if $killer && $killer->{'ADMIN'};
    $self->{'IMMORTAL'} = $main::rock_stats{'armageddon_started_by_race'} != 0;
}

#sub attack_sing {
#  my ($self, $victim) = @_;
#  $self->say("I LIKE MEAT");
#  if($victim->is_dead || $self->is_dead) { return; }
#  else {
#    if(rand(100)<40) { $self->hdecapitate($victim); }
#    elsif($self->{'WEAPON'}) { $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}}); }
#    elsif($self->{'DWEAP'}) {  $self->attack_melee($victim, &main::obj_lookup($self->{'DWEAP'})); }
#    return;
#  }
#}


sub on_event {
    my $self = shift;

    if ($self->is_tired()) {
        $main::events{$self->{'OBJID'}} ||= 2;
    } elsif (my $targ = $self->ai_get_random_target()) {
        # 2004-05-02 RTG changed from:  $self->attack_player($targ, 1);
        # I guess theoretically this could like.. not work.. if the users
        # are in differnet rooms or something, but let's try it and see how it
        # goes.
        $self->attack_sing($targ);
        $targ->attack_sing($self);

        # If i might be able to attack someone else, log it
        $main::events{$self->{'OBJID'}} ||= 2;
    } else {
    }
}


sub on_die {
  # is called right before dying
  my ($self, $by) = @_;

  my $room = $main::map->[$self->{'ROOM'}];
  
  # if we dont know who killed me, ignore
  if(!$by || !defined($by->{'RACE'}) || $by->{'RACE'}==$self->{'RACE'}) { return &main::rock_shout(undef, "{1}ERROR: {17}Monolith killed by no attacker!\n", 1); }
  
  # or if we're in a conspicuous room
  if (!$room->{'MONOLITH'} || !$self->{'MONOLITH'}) { 
     return &main::rock_shout(undef, "{1}ERROR: {17}Monolith ids do not match up!\n", 1);
  }

  $by->{'DP'} += 2;
  
  # otherwise announce it
  &main::rock_shout(undef, "{3}*{13}##{16}o{13}##{3}*  {17}The {12}$main::races[$by->{'RACE'}]s {17}have captured {2}$main::monolithtoname{$self->{'MONOLITH'}}\{17}!\n         {17}[ {7}Type {17}monoliths {7}for the breakdown {17}]\n");
  
  &main::log_event("Monolith Capture", "$by->{'NAME'} lands the final blow to $self->{'NAME'}, claiming the $main::monolithtoname{$self->{'MONOLITH'}} for the $main::races[$by->{'RACE'}]s.", $by->{'UIN'}, $by->{'RACE'}, $self->{'REC'}, undef);

  
  
  # reconfig room info
  $room->{'MONOLITH'} = $self->{'MONOLITH'}.'|'.$by->{'RACE'};
  
  # record capturage in rock_stat
  $main::rock_stats{$self->{'MONOLITH'}} = $by->{'RACE'};
  
  my ($monolith_name) = $self->{'MONOLITH'} =~ /^monolith_(.+)$/;
  my $dbh = rockdb::db_get_conn();
  $dbh->do(<<END_SQL, undef, int $by->{'RACE'}, ($by->{'UIN'} || undef), $monolith_name);
UPDATE
$main::db_name\.monolith_capture_status
SET owned_by_race = ?,
    captured_by_uin = ?,
    date_captured = sysdate(),
    date_contested = null
WHERE name = ?
END_SQL
#  &main::rock_shout(undef, "matched on $monolith_name\n");

  
  # and flatten
  &main::rock_flatten_realm();
  
  # deploy new NPC
  $room->item_spawn($self->{'REC'})->{'RACE'}=$by->{'RACE'};  

  # deploy random item
  my @prize_recs = qw(135 381 380 338);
  my $prize_count = 0;
  my $hours_alive = (time - $self->{'BIRTH'}) / 60 / 60;
  $prize_count++ if $hours_alive >= 5 && $by && $by->got_lucky();
  $prize_count++ if $hours_alive >= 24 * 1;
  $prize_count++ if $hours_alive >= 24 * 2;
  $prize_count++ if $hours_alive >= 24 * 3;
  $prize_count++ if $hours_alive >= 24 * 5;
  for (my $i=0; $i<$prize_count; ++$i) {
      if (my $spawned_item = $room->item_spawn($prize_recs[int rand @prize_recs])) {
          $room->room_sighttell("{3}$spawned_item->{'NAME'} appears on the floor.\n");
      }  
  }
  
  return "Success!";
}

sub on_odie {
  my ($self, $obj) = @_;
  if ( ($self ne $obj) && (!$obj->{'MONOLITH'}) ) { 
       $self->{'HP'} += (1 + int rand(3))*$obj->{'MAXH'} + 20;
       if($self->{'HP'} > $self->{'MAXH'}) { $self->{'HP'} = $self->{'MAXH'}; }
       $obj->room_sighttell("{1}As {2}$obj->{'NAME'} {1}dies, {2}$self->{'NAME'} {1}assimilates $obj->{'PPOS'} discarded life essence.\n");
  }
  
  return;
}

sub attack_sing {
  my ($self, $victim) = @_;

  use integer;
  if((time - $self->{'RACEWARN'}) > 45) { 
     $self->cmd_do("gos Help! I'm getting attacked by a $main::races[$victim->{'RACE'}]!");
     $self->{'RACEWARN'} = time;

     my ($monolith_name) = $self->{'MONOLITH'} =~ /^monolith_(.+)$/;
     my $dbh = rockdb::db_get_conn();
     $dbh->do(<<END_SQL, undef, $monolith_name);
UPDATE
$main::db_name\.monolith_capture_status
SET
    date_contested = sysdate()
WHERE name = ?
END_SQL

  }
  no integer;
  
  my $weapon = $self->weapon_get();

  my $targ = $self->ai_get_hostile_target($victim) || $victim;

  #$self->say("Death to $targ->{'NAME'}!\n");
  if ($victim->is_dead || $self->is_dead) { return; }
  else {
     if( $targ  &&  $weapon ){ 
       $self->attack_melee($targ, $weapon); 
     }
  }

  $self->on_event();
}


package npc_spectral_monolith_guardian;
@npc_spectral_monolith_guardian::ISA = qw( monolith_guardian );
use strict;




package npc_temporal_monolith_guardian;
@npc_temporal_monolith_guardian::ISA = qw( monolith_guardian );
use strict;
use const_stats;
#(22:59:38) Kler: The Time Watcher hits you with his mighty time sucking attack, draining 400 turns!
#(23:02:44) Kler: I really think we should make that... maybe like .5% chance per hit..
#(23:03:21) Kler: and also an age attack that reduces all your physical stats by 25%


sub attack_sing {
    my ($self, $victim) = @_;
    
    # possibly throw a spell on 'em
    if ($victim->{'TYPE'} == 1 && rand(100) < 0.5) {
        my $turns_lost = int(rand(200)) + 300;
        $self->room_sighttell("{11}$self->{'NAME'} {1}hits {11}$victim->{'NAME'} {1}with $self->{'PPOS'} mighty time-sucking attack, draining $turns_lost turns!\n", $victim);
        $victim->log_append("{11}$self->{'NAME'} {1}hits you {1}with $self->{'PPOS'} mighty time-sucking attack, draining $turns_lost turns!\n");
        $victim->{'T'} -= $turns_lost;
        $self->note_attack_against($victim);
        $self->make_tired();  # Important: if you don't do this, you'll end up in a recursive loop
    }

    if ($victim->{'TYPE'} == 1 && rand(100) < 5 && !$victim->effect_has(68)) {
        $self->room_sighttell("{11}$self->{'NAME'} {1}points the tip of $self->{'PPOS'} blade at {11}$victim->{'NAME'}\{1}, unleashing a beam of temporal energy.\n", $victim);
        $victim->log_append("{11}$self->{'NAME'} {1}points the tip of $self->{'PPOS'} blade at you, unleashing a beam of temporal energy.\n", $victim);
        $victim->effect_add(68);
        $self->note_attack_against($victim);
        $self->make_tired();        
    }

    # do the regular attack stuff
    return $self->SUPER::attack_sing(@_[1..$#_]);
}




package npc_beastly_fuzzem;
@npc_beastly_fuzzem::ISA = qw( npc );
use strict;

sub on_room_enter (objects: enterer; string: fromdir, observation) {
    my ($self, $who, $dir) = @_;
    if ($dir && (!$self->cant_aggress_against($who))) { $self->auto_move(1); }
    return;
}

sub on_take {
    my ($self, $by) = @_;
    if(.95 > rand(1)) {
        # scurry away 90% of the time
        $by->room_sighttell("{2}Beastly Fuzzem squeals in fright and darts from $self->{'NAME'}\'s grasp!\n");
        $by->log_append("{2}Beastly Fuzzem squeals in fright and darts from your grasp!\n");
        $by->inv_del($self);
        $main::map->[$by->{'ROOM'}]->inv_add($self);
        $self->auto_move(1);
    }
}

package fuzzem;
@fuzzem::ISA = qw( npc );
use strict;

@fuzzem::rand_idle = (
    sub { $_[0]->room_tell("{3}$_[0]->{'NAME'} dances around the room, filling it with joy!\n"); },
    sub { $_[0]->room_tell("{1}$_[0]->{'NAME'} {16}sings, \"Happy, happy, we are happy. Happy, happy, fuzzy happy.\"\n"); },
    sub { return if !$_[0]->{'AI'}->{'TARGNAME'}; $_[0]->room_tell("$_[0]->{'NAME'} grabs $_[0]->{'AI'}->{'TARGNAME'} by the hands and begins to dance 'round and round!\n"); },
    sub { return if !$_[0]->{'AI'}->{'TARGNAME'}; $_[0]->room_tell("$_[0]->{'NAME'} makes a soft purring sound, while looking up at $_[0]->{'AI'}->{'TARGNAME'} with round, caring eyes.\n"); },
    sub { $_[0]->room_tell("{3}$_[0]->{'NAME'} bounces happily around the room.\n"); },
    sub { $_[0]->say("Ask fuzzem bout song ta get goodgood present!"); },
    sub { $_[0]->say("Loogha Loogha"); $_[0]->{'AI'}->{'STAGE'}=0; }
);

sub on_idle {
   my $self = shift;
   return if
          (
          !$self->{'AI'}->{'TARGID'} ||
          !defined($main::objs->{$self->{'AI'}->{'TARGID'}}) ||
          ($main::objs->{$self->{'AI'}->{'TARGID'}})->{'ROOM'} != $self->{'ROOM'}
       );

   &{$fuzzem::rand_idle[rand @fuzzem::rand_idle]}($self);
}

sub on_room_enter (objects: enterer; string: fromdir, observation) {
  my ($self, $who, $dir) = @_;
  # latch if possible
  if(  
       $who->{'TYPE'}==1 &&
 
       (
          !$self->{'AI'}->{'TARGID'} ||
          !defined($main::objs->{$self->{'AI'}->{'TARGID'}}) ||
          ($main::objs->{$self->{'AI'}->{'TARGID'}})->{'ROOM'} != $self->{'ROOM'}
       )
  )
  { 
    $self->{'AI'}->{'TARGNAME'} = $who->{'NAME'};
    $self->{'AI'}->{'TARGID'} = $who->{'OBJID'}; 
    if(ref($self) eq 'fuzzem_runt') { 
         $self->{'STALKING'} = $who->{'OBJID'};
         $who->delay_log_append(1, "{12}$self->{'NAME'} {2}smiles brightly as you enter the room, and begins mimicking your every move.\n");
    }
    $main::eventman->enqueue(2 + int rand(3), \&rockobj::action_do, $self, 'hug', $who->{'NAME'});
  }
  
  return &npc::on_room_enter(@_);
}

sub on_ask ($topic) {
 my ($self, $topic, $who) = @_;
 if ($topic =~ /songs?|music/)  {
      $self->say("$who->{'NAME'}, you want ME to sing? Happyhappy!");
      $self->delay_room_tell(2, "{12}$self->{'NAME'} {2}clears his throat.\n");
      $self->delay_room_tell(3 + int rand(3), "{12}$self->{'NAME'} {2}starts dancing around you while singing, \"Happy happy, fuzzy happy! Happy, happy, fuzzy time! Happy,happy, dancy happy! Happy, happy, fuzzy time! We like fuzzy, we like $who->{'NAME'}uzzy, we like happy time!\"\n");
      return('');
 } elsif ($topic =~ /bach/)  {
      $self->say("I win!");
      return '';
 } else { return undef; }
 return("");
} 

sub on_say ($sayerobj, $what_they_said) {
  my ($self, $obj, $saystr) = @_;
  next if (($obj eq $self) || $obj->{'TYPE'}!=2);
  my $stage = \$self->{'AI'}->{'STAGE'};
  if ($self != $obj) { 
     SWITCH:for (lc($$saystr)) {
      /loogha loogha/ && $$stage == 0 && do { $self->delay_say(2 + int rand(2), "Woogha Woogha"); $$stage++;last SWITCH; };
      /woogha woogha/ && $$stage == 1 && do { $self->delay_say(2 + int rand(2), "Toogha Toogha"); $$stage++; last SWITCH; };
      /toogha toogha/ && $$stage == 2 && do { $self->delay_say(2 + int rand(2), "Beegatoo!"); $$stage = 0; last SWITCH; };
     }
  }
  return;
}

sub on_digest {
   my ($self, $who) = @_;
   my $delay = 60 + int rand(61);
   $self->{'NAME'} =~ /(\w+) .*/;
   my $color = lc($1);
   $main::eventman->enqueue($delay - 10, \&rockobj::action_do, $who, 'cough');
   $main::eventman->enqueue($delay, \&rockobj::room_talktell, $who, "{3}$who->{'NAME'} coughs up a $color hairball.\n");
   $main::eventman->enqueue($delay, \&rockobj::log_append, $who, "{3}You cough up a $color hairball.\n");
}

package npc_wounded_captain;
@npc_wounded_captain::ISA = qw(npc);
use strict;

sub on_receive {
    my ($self, $obj, $from) = @_;
    if($obj->{'REC'} != 618) { return $self->SUPER::on_receive(@_); }

    $self->room_sighttell("{2}The Wounded Captain's eyes soften for a moment in deep appreciation.\n");
    $self->say("I will return this to Elthros's family immediately. If you were able to retrieve this sword from one of the Eldars, perhaps you are worthy of defeating Doyos himself.");

    $obj->dissolve_allsubs(); # trash the precious sword ;)

    my $item = $self->item_spawn(608); # give cracked hourglass
    $self->item_hgive($item, $from, 0, 1); 

    $self->delay_say(4, "This heirloom saved my life in the face of the Eldar's evil magic. Perhaps it will serve you just as well.");
}


sub on_ask {
    my ($self, $topic, $from) = @_;
#    if ($topic =~ /battle|war|beast/i) { 
#        return <<END_CAP;
#Wounded Captain says, "I was with the Troitian garrison that attacked the dark army. Thousands of Troitians confronted the vicious iron and stone golems created by Doyos. We very nearly acheived victory, if not for the evil Eldar's magic. Doyos swept his trident across our lines, sending out a green pulse of dark magic. Men struck by it were instantly aged thousands of years, turning them to dust. Only I was able to evade the wave and return to our base. I myself witnessed one of the three Eldars, Garron, pry our garrison commander's sword from his crumbling hand."
#END_CAP
#    } elsif ($topic =~ /commander|sword|elthros/i) { 
#        return <<END_CAP;
#Wounded Captain says, "Our garrison commander, Elthros, was a man of true character. I would love the opportunity to return his sword to his family, but trying to recapture his sabre is far too dangerous in these difficult times. In fact, if you are able to retrieve the sword, I may be able to help you defeat Doyos himself."
#END_CAP
#    } elsif ($topic =~ /doyos|enemy|eldar|garron/i) { 
#        return <<END_CAP;
#Wounded Captain says, "We don't know exactly where the treacherous Eldars came from, but we know there are three of them. Most likely, they were outcast from the Eldar home plane, only to arrive on our doorstep. They are indeed powerful, and Troitia is not able to sustain combat with their forces for much longer."
#END_CAP
#    } elsif ($topic =~ /hourglass|cracked|found|defeat/i) { 
#        return <<END_CAP;
#Wounded Captain says, "An envoy from the Eldar plane presented the Troitians with this cracked hourglass. According to their scholars, it neutralizes temporal magic. It is probably the only reason I was able to escape the battle."
#END_CAP
#    }
    return undef;
}

package fuzzem_runt;
@fuzzem_runt::ISA = qw( fuzzem );
use strict;

sub on_idle {
   my $self = shift;
   if(rand(4)<3) { $self->say_rand('You me pal!', 'I wuv you!', 'Happy, happy..me is happy! Party, party, happy party!'); }
}

package spell_caster;
@spell_caster::ISA = qw( npc );
use strict;

# generic, inherited class; calls sc_gen_attack of
# class which inherits me

sub attack_sing {
  my ($self, $victim) = @_;
 
  my $weapon = $self->weapon_get();
  my $targ = $self->{'LIMIT'}==1?($self->ai_pvp_target_lowest('HP', $self->{'LEV'}/2) || $victim):$victim;
  
  if($victim->is_dead || $self->is_dead) { return; }
  else {
     if( ($targ)  &&  ($weapon)  ){ 
       $self->sc_gen_attack($targ, $weapon);
     }
  }
}

sub sc_gen_attack { }

package sapphire_ele;
@sapphire_ele::ISA = qw( spell_caster );
use strict;

sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    if(  ($self->{'STAT'}->[22] - $targ->{'STAT'}->[21])*5  > 600 ) { return if $self->spell_hgeneric('TSTAB', $targ, 1); }
    $self->attack_melee($targ, $weapon); 
}


package npc_sulphax;
@npc_sulphax::ISA = qw( spell_caster );
use strict;

sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    if( rand(1) < .2 ) { return if $self->spell_hgeneric('SULPH-DBREATH', $targ, 1); }
    $self->attack_melee($targ, $weapon); 
}

package npc_zeode;
@npc_zeode::ISA = qw( spell_caster );
use strict;

sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    $self->attack_melee($targ, $weapon); 
    if(my $spore = $main::map->[$self->{'ROOM'}]->item_spawn(478)) {
        $spore->room_tell("{4}Zeode launches a crystal spore high into the air!\n");
        $spore->attack_player($targ, 1);
        
        # convert to the larger spore after ~10-20 seconds
        my $delay = 8 + int rand 5;
        $main::eventman->enqueue($delay, \&c_crystal_spawn, $spore);
    }
}

sub c_crystal_spawn {
    my $spore = shift;
    $spore->room_sighttell("{4}$spore->{'NAME'} suddenly grows, transforming into a vicious spawn!\n");
    my $spawn = $main::map->[$spore->{'ROOM'}]->item_spawn(479);
    $spore->dissolve_allsubs();
    
    my $destruct_time = 40 + int rand 20;
    $spawn->delay_room_sighttell($destruct_time, "{4}$spawn->{'NAME'} shatters apart.\n");
    $main::eventman->enqueue($destruct_time, \&rockobj::dissolve_allsubs, $spawn);
}

package quartz_ele;
@quartz_ele::ISA = qw( spell_caster );

sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    if( rand(1) < .05 ) { return $self->hcrystallize($targ); }
    $self->attack_melee($targ, $weapon); 
}

package npc_mog;
@npc_mog::ISA = qw( npc );

sub on_die {
   my $self = shift;
   $main::eventman->enqueue(60 * 60 * 6, \&rockobj::item_spawn, $main::map->[$self->{'ROOM'}], 411);
}

package npc_unicorn;
@npc_unicorn::ISA = qw( npc );

sub on_attack {
  my ($self, $attacker, $victim, $weapon) = @_;
  if($self == $victim && (.5 < rand 1)) { 
     $self->{'HP'}=$self->{'MAXH'};
     $self->room_sighttell("{3}$self->{'NAME'}\'s golden horn shines with light, as he is surrounded by a healing aura.\n");
  }
  return $self->SUPER::on_attack(@_);
}


package npc_citizen;
@npc_citizen::ISA = qw( npc );

sub on_attack {
  my ($self, $attacker, $victim, $weapon) = @_;
  $self->summon_guards($attacker) if($victim == $self);
  return $self->SUPER::on_attack(@_);
}

sub summon_guards {
  my ($self, $victim) = @_;
  my $success=0;
  $self->cmd_do("say ERROR: no victim passed") if !$victim;
  foreach my $objid (keys %main::npc_guard_map) {
     if(!defined($main::objs->{$objid})) { delete $main::npc_guard_map{$objid}; next; }
     if(!defined($main::objs->{$main::npc_guard_map{$objid}})) { $main::npc_guard_map{$objid}=''; }
     next if $main::npc_guard_map{'OBJID'};
     
     next unless $victim->is_on_same_plane_as($main::objs->{$objid}); # guards can be on multiple planes
     
     $main::npc_guard_map{$objid}=$victim->{'OBJID'};
     $main::objs->{$objid}->guard_terminate($victim);
     $success = 1;
  }
  
  if ($success) {
      if ($self->{'REC'} == 646) { # canines
          $self->action_do("bark");
      } else {
          $self->room_talktell("{3}$self->{'NAME'} screams for a guard!\n");
      }
  }
}

@npc_citizen::cheeractions = qw(cheer dance worship ovation handshake);
@npc_citizen::cheeractions_canine = qw(lick bark);

sub on_odie {
  my ($self, $victim, $killer) = @_;
  if(ref($killer) eq 'npc_guard' && $killer ne $self) {
     return if (rand(1) < .3);
     if ($self->{'REC'} == 646) {
         $self->delay_action_do(rand 6+1, $npc_citizen::cheeractions_canine[rand @npc_citizen::cheeractions_canine], $killer->{'NAME'});
     } else {
         $self->delay_action_do(rand 6+1, $npc_citizen::cheeractions[rand @npc_citizen::cheeractions], $killer->{'NAME'});
     }
  }
}



package npc_guard;
@npc_guard::ISA = qw( npc_citizen );
use strict;

sub new {
   my $self = shift;
   my $newself = $self->SUPER::new(@_);
   $main::npc_guard_map{$newself->{'OBJID'}}=''; # register me on guard map
   return $newself;
}
sub guard_terminate {
    my ($self, $victim) = @_;
    $self->guard_troll_to($victim);   
    $self->{'STALKING'}=$victim->{'OBJID'};
}

sub punish_user {
    my ($self, $victim) = @_;
    if($self->{'ROOM'} != $victim->{'ROOM'}) {
       $self->guard_troll_to($victim);
    } else {
    
       return if $victim->is_dead();
       
       if(!$self->is_tired()) { 
          $self->attack_player($victim, 1);
        
          if($victim->is_dead()) {
              # done
              if ($self->{'REC'} == 646) { # canines dont cheer
                  $self->action_do('prance');
              } else {
                  $self->action_do(rand(1)<.5?'cheer':'bow');
              }
              $main::npc_guard_map{$self->{'OBJID'}}='';
              delete $self->{'STALKING'};
              return;
          }
       }
       
       $main::eventman->enqueue(1 + int rand 4, \&punish_user, $self, $victim);
    }
}

sub guard_troll_to {
   # walks toward victim, one second at a time.
   # $self->ai_troll_to($victim);
   
   my ($self, $victim) = @_;
   
   delete $self->{'TRD'};
   
   if($self->ai_move_to($victim)) {
      $main::eventman->enqueue(1 + int rand 4, \&guard_troll_to, $self, $victim);
   } else {
      if($self->{'ROOM'} == $victim->{'ROOM'}) {
         $self->punish_user($victim);
      } else {
         
         if(rand(1)<.4  && $victim->{'HP'} > 0) {
           if ($self->{'REC'} == 646) { # davada says: canines growl!
                 $self->action_do(rand(1)<.5?'growl':'bang');
           } else {
               rand(1)<.2?
                   $self->action_do('sigh'):
                   $self->say_rand('blah', 'i give up', 'durnit!', 'confounded...');
           }
         }
         
         # done
         $main::npc_guard_map{$self->{'OBJID'}}='';
         delete $self->{'STALKING'};
      }
   }
}

package npc_master_mechanic;
@npc_master_mechanic::ISA = qw ( npc_quest_receiver );
use strict;

sub on_ask {
    my ($self, $topic, $from) = @_;
    
    return undef;
} 


package npc_quest_receiver;
@npc_quest_receiver::ISA = qw ( npc );
use strict;
use Carp;
#
# Quest Receiver
#
# onReceive [ 
#              {
#  *REQUIRED*     wantITEMS => [233, 444]
#  *REQUIRED*     rewardITEMS => [1, 2, 3]
#                 QUEST => 10 || undef
#                 msgDONE => "Thanks you!\n"
#                 msgPART_DONE => "I'm still hungry, bla bla"
#                 msgUSED => "You already bla bla quest"
#                 msgNO_WANT => ""
#                 msgGOT_ALREADY => "you already blah blah that item you gave me"
#              } 
#

sub on_cryl_receive {
    my ($self, $cryl, $from) = @_;
    
    # check wanted list for things we want to get from the player
    foreach my $wanted (@{$self->{'onReceive'}}) {
        
        next unless $wanted->{'wantCRYL'};

        # there's a slot open for the item we got! wheee.. but did they
        # fulfill the quest already?
        if ($wanted->{'QUEST'} && $from->quest_has($wanted->{'QUEST'})) {
            # if it's a quest that was fulfilled, all is sad. skip it.
            $self->qc_do_command_agenda($from, "$wanted->{'msgUSED'}");
        } else {
                
            $from->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"} += $cryl;

            # Give back cryl if we have too much
            if ($from->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"} > $wanted->{'wantCRYL'}) {
                $self->cryl_give($from->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"} - $wanted->{'wantCRYL'}, $from);
                $from->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"} = $wanted->{'wantCRYL'};
            }
            


            # See if they finished the quest   
            if ($self->qc_has_user_met_requirements_for_quest($from, $wanted)) {
                $self->qc_complete_quest_for($from, $wanted);
            } else {
                $self->qc_do_msgpart_done_for($from, $wanted, "$cryl cryl");
            }

            last; # don't check additional slots, we found a place
        } 

    }

    return;
}

sub qc_has_user_met_requirements_for_quest {
    my ($self, $who, $wanted) = @_;
    # determine whether or not the user has completed the quest.
    my $completed_quest = 1; # true if user has completed quest
    for (my $i=@{$wanted->{'wantITEMS'}}-1; $i>=0; --$i) {
        $completed_quest = 0 unless vec($who->{'Q_HIST'}->{$wanted->{'ID'}}, $i, 1);
    }
    $completed_quest = 0 if $wanted->{'wantCRYL'} && $who->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"} < $wanted->{'wantCRYL'};
    return $completed_quest;
}

sub qc_complete_quest_for {
    # Completes the quest $wanted for user $who
    my ($self, $who, $wanted) = @_;

    unless ($self->qc_has_user_met_requirements_for_quest($who, $wanted)) {
        $self->say("Can't complete quest -- you didnt fill requirements yet. Buggy bug.");
        return 0;
    }
    
    # if success, then the user has fit the requirements for this quest.
    # we should now reward them!

    # say done message
    if (ref($wanted->{'msgDONE'}) eq "CODE") {
        # if it's code, execute it!
        &{$wanted->{'msgDONE'}}($self, $who);
    } else {
        $self->qc_do_command_agenda($who, $wanted->{'msgDONE'}) if $wanted->{'msgDONE'};
    }

    # mark that they took the quest, if it's limited
    if($wanted->{'QUEST'}) { $who->quest_add($wanted->{'QUEST'}); }   

    # spawn items in me, give to player
    foreach my $iagenda (@{$wanted->{'rewardITEMS'}}) {
        next unless length $iagenda; # can be blank, I guess.
        $self->qc_give_item_agenda($who, $iagenda);
    }

    # reset got-list
    delete $who->{'Q_HIST'}->{$wanted->{'ID'}};
    delete $who->{'Q_HIST'}->{"$wanted->{'ID'}\_CRYL"};
    
    return 1;
}

sub qc_do_msgpart_done_for {
    # Does the msgPART_DONE command(s), assuming there even is one
    # associated with this quest.
    
    my ($self, $who, $wanted, $item_name) = @_;
    if (my $tmp_msg = $wanted->{'msgPART_DONE'}) {
        my ($has, $total, $want);

        for(my $i=0; $i<@{$wanted->{'wantITEMS'}}; $i++) {
            $has++ if vec($who->{'Q_HIST'}->{$wanted->{'ID'}}, $i, 1);
            $total++;
        }
        for ($tmp_msg) {
            s/\%MORE_NAMED/$self->get_name_of_items_i_want_from($who, $wanted)/eg;
            s/\%MORE/$total - $has/eg;
            s/\%TOTAL/$total/eg;
            s/\%HAS/$has/eg;
            s/\%I/$item_name/eg;
        }
        $self->qc_do_command_agenda($who, $tmp_msg);
    }
}

sub qc_check_quest_criteria {
    my ($self, $obj, $from, $wanted, $contributed, $got_already) = @_;

    my $dissolve_the_item = 1;
    my $quest_id = $wanted->{'ID'};
    
    if ($self->qc_has_user_met_requirements_for_quest($from, $wanted)) {
        $self->qc_complete_quest_for($from, $wanted);
    } elsif ($contributed) {
        # user worked on quest but hasn't finished it yet:
        $self->qc_do_msgpart_done_for($from, $wanted, $obj->{'NAME'});
    } else {
        if ($got_already && $wanted->{'msgGOT_ALREADY'}) {
            $self->qc_do_command_agenda($from, $wanted->{'msgGOT_ALREADY'});
        }
        $self->action_do('frown');
        $self->item_hgive($obj, $from, 0, 1); # not quiet, and always give back
        $dissolve_the_item = 0;
    }

    return $dissolve_the_item;
}

sub on_receive {
    my ($self, $obj, $from) = @_;
    my $obj_rec = $obj->{'REC'};

    my $dissolve_the_item = 1;
    # check wanted list for things we want to get from the player
    my $contributed = 0; # true if user has contributed an item to the quest
    my $got_already = 0; # true if we already received one of this item

    foreach my $wanted (@{$self->{'onReceive'}}) {
        
        for (my $i=0; $i<@{$wanted->{'wantITEMS'}}; $i++) {
            next unless $wanted->{'wantITEMS'}->[$i] == $obj_rec; # it doesn't match this item? don't care! skip it then.

            if ( vec($from->{'Q_HIST'}->{$wanted->{'ID'}}, $i, 1) ) {
                # if we already have the rec, note it; we can't fill this slot again
                $got_already = $wanted;
            } else {
                # there's a slot open for the item we got! wheee.. but did they
                # fulfill the quest already?
                if ($wanted->{'QUEST'} && $from->quest_has($wanted->{'QUEST'})) {
                    # if it's a quest that was fulfilled, all is sad. skip it.
                    $self->qc_do_command_agenda($from, "$wanted->{'msgUSED'}");
                } else {
                   # if we still want it, then all is happy. mark that we got it.
                    vec($from->{'Q_HIST'}->{$wanted->{'ID'}}, $i, 1) = 1;
                    $contributed = 1;
                    last; # don't check additional slots, we found a place
                }
            } 
        }
 
        # Check whether we satisfied this quest
        if ($contributed) {
            if ($self->qc_has_user_met_requirements_for_quest($from, $wanted)) {
                $self->qc_complete_quest_for($from, $wanted);
            } else {
                # user worked on quest but hasn't finished it yet:
                $self->qc_do_msgpart_done_for($from, $wanted, $obj->{'NAME'});
            }
            
            last; # We contributed, so don't apply to multiple quests
        } 

    }


    unless ($contributed) {
        # didn't satisfy anything
        if ($got_already && $got_already->{'msgGOT_ALREADY'}) {  
            $self->qc_do_command_agenda($from, $got_already->{'msgGOT_ALREADY'});
        }
        $self->action_do('frown');
        $self->item_hgive($obj, $from, 0, 1); # not quiet, and always give back
        $dissolve_the_item = 0;
    }
        
    # ditch the item
    $obj->dissolve_allsubs() if $dissolve_the_item;

    return;
}

sub get_name_of_items_i_want_from {
    my ($self, $from_who, $wanted) = @_;
    
    my %want_recs;
    
    for (my $i=0; $i<@{$wanted->{'wantITEMS'}}; ++$i) {
        ++$want_recs{$wanted->{'wantITEMS'}->[$i]} unless vec($from_who->{'Q_HIST'}->{$wanted->{'ID'}}, $i, 1);
    }

    my @wanted_named = map { my $count = $want_recs{$_}; $count = &main::get_an_str(&main::get_item_name_by_rec($_)) if $count == 1; my $s = $count > 1?"s":""; "$count ".&main::get_item_name_by_rec($_).$s } keys %want_recs;
    
    my $cryl_wanted = $wanted->{'wantCRYL'} - $from_who->{'Q_HIST'}->{$wanted->{'ID'}."_CRYL"};
    push @wanted_named, "$cryl_wanted cryl" if $cryl_wanted > 0;
    my $str = &main::commify_join_with_and(@wanted_named); 

    return $str;
}

sub qc_do_command_agenda {
    my ($self, $to, $iagenda) = @_;
    
    return if $iagenda eq ""; # NO AGENDA, NO PROBLEM!
    
    my ($cmd, $h_args) = $iagenda =~ /^([^ ]+)[ ]+(.*)$/;
    if($cmd eq 'echo') {
       $self->room_sighttell("$h_args\n");
    } elsif($cmd eq 'say') {
       $self->say($h_args);
    } else {
       $self->say("Error parsing or matching agenda: $iagenda");
       confess "Command Agenda Parse Error"; 
    }
    return;
}

sub qc_give_item_agenda {
    my ($self, $to, $iagenda) = @_;
    
    # clean up whitespace on $iagenda
    for($iagenda) {
       s/^\s+//g;
       s/\s+$//g;
       s/\s*(\||\&)\s*/$1/g;
    }
        
    # split up the |'s
    my @options = split(/\|/, $iagenda);
    
    ### $self->say("Options: ".join(" *** OR *** ", @options));
    
    # for each possible set
    QC_ORDER:
    foreach my $oset (@options) {
        my @order = sort qc_item_order (split (/&/, $oset));
        ### $self->say("Oset: $oset; order @order");
        foreach my $itext (@order) {
            # if can't create item, try next possible set
            next QC_ORDER if !$self->qc_give_item($to, $itext);
        }
        # if we're here, we created the item. dont go through the others
#                $self->action_do('cheer');
        last;
    }
    
    return;
}

sub qc_give_item {
    my ($self, $to, $itext) = @_;
    # handles 
    if ($itext =~ /^(\d+) \s+ exp$/xi) {
        my $totalexp = $1;
        $to->exp_add($totalexp);
    } elsif ($itext =~ /^([1-9]\d*) \s+ levels?(?:\s+ maxlev \s+ (\d+))$/xi) {
        my $levels = $1;
        my $maxlev = $2;
        my $real_level =  $to->get_real_level();
        $real_level = &rockobj::min($maxlev, $real_level) if $maxlev;
        $to->exp_add((($real_level + $levels)**3 - $real_level**3)*17);
    } elsif ($itext =~ /^(\d+) \s+ expphy$/xi) {
        $to->{'EXPPHY'}+= $1;
        $to->log_append("{1}You gain {17}".&rockobj::commify($1)." {1}physical experience.\n");
    } elsif ($itext =~ /^(\d+) \s+ expmen$/xi) {
        $to->{'EXPMEN'}+= $1;
        $to->log_append("{1}You gain {17}".&rockobj::commify($1)." {1}mental experience.\n");
    } elsif ($itext =~ /^(\d+) \s+ cryl$/xi) {
        $self->{'CRYL'} += $1;
        $self->cryl_give($1, $to);
    } elsif($itext =~ /^items? \s* (\d+,?)+$/xi) { 
        # item[s] 1, 2, 3
        my @inums = split(/\s*,\s*/, $1);
        my @tmpobjs;
        foreach my $i (@inums) { 
            if ($i = $self->item_spawn($i)) {
               # if we could create it, add to list
               push(@tmpobjs, $i);
            } else {
               # if we couldn't, dissolve the ones we created and return 0
               foreach my $obj (@tmpobjs) { $obj->dissolve_allsubs(); }
               ### $self->say("Had trouble filling itext request.");
               return 0;
            }
        }
        # success!
        foreach my $i (@tmpobjs) {
            $self->item_hgive($i, $to, 0, 1); # quiet = 0, override = 1
        }
    } elsif($itext =~ /^skill \s* (\d+)$/xi) { 
        my ($skill_num) = ($1);
        if ($to->skill_has($skill_num)) { return 0; }
        $to->skill_add($skill_num);
        $to->log_append("{16}You have attained the skill, \"{6}$main::skillinfo[$skill_num]->[0]\{16}\"\n");
        return 1;
    } else {
        $self->say("Error: unmatched item string/num: [$itext]");
        return 0;
    }
    return 1;
}

sub qc_item_order {
  if ( (substr($a, 0, 4) eq 'item') && (substr($b, 0, 4) ne 'item') ) {
    return -1;
  } elsif ( (substr($b, 0, 4) eq 'item') && (substr($a, 0, 4) ne 'item') ) {
    return 1;
  } elsif ( (substr($a, 0, 4) eq 'skill') && (substr($b, 0, 4) ne 'skill') ) {
    return -1;
  } elsif ( (substr($b, 0, 4) eq 'skill') && (substr($a, 0, 4) ne 'skill') ) {
    return 1;
  } else {
    return 0;
  }
};


package npc_griffon;
@npc_griffon::ISA = qw( npc );
use strict;

sub on_idle {
    my $self = shift;
    if( (.4 > rand 1) && (my $friend = $self->aid_get()) ) {
        $friend->log_append("{2}$self->{'NAME'} affectionately nuzzles you, then lazily stretches its muscles.\n");
        $friend->room_tell("{2}$self->{'NAME'} affectionately nuzzles $friend->{'NAME'}, then lazily stretches its muscles.\n");
#Kler says, "Royal Griffon manages a sort of grin and says, "My name is Gwendal!"
#"
#Kler says, "Stretching its wings to their limits, the Royal Griffon screeches de
#lightfully as he ruffles his feathers."
#Kler says, "Royal Griffon nudges Plat mawkishly and produces a soft hoot."
    }
}


sub on_touch {
    my ($self, $by) = @_;
    #my $friend = $self->aid_get();

    if($by->{'NAME'} eq $self->{'AI'}->{'MASTER'}) {         
        # preamble messages
        $by->log_append("{2}You gently touch the griffon's head, causing it to revert back to a stone statuette.\n");

        $by->room_tell("{2}$by->{'NAME'} gently touches the griffon's head, causing it to revert back to a stone statuette.\n");
        
        # create statue
        #mich- changed friend to by
        my $statue = $by->item_spawn_forced(490);
        $statue->{'USES'} = $self->{'USES'};
                
        # ditch myself
        $self->dissolve_allsubs();
    } else {
        # failed
        return &rockobj::on_touch(@_);
    }
}

package npc_spitting_viper;
@npc_spitting_viper::ISA = qw( npc );
use strict;

sub on_room_enter {
    my ($self, $who, $dir) = @_;
    if($who->{'RACE'} != $self->{'RACE'} && rand 1 < .25) {
        $who->room_sighttell("{2}$self->{'NAME'} sprays a mist of poison at $who->{'NAME'}\'s eyes!\n");
        $who->log_append("{12}$self->{'NAME'} coils itself tightly into a circle, and raises its head warily. Without warning, the snake opens its mouth and sprays a mist of poison at your eyes!\n");
        $who->effect_add(22);
    }
    return &npc::on_room_enter(@_);
}

package npc_wounded_northlander;
@npc_wounded_northlander::ISA = qw( npc );
use strict;

sub on_idle {
    if(rand 1 < .5) {
        $_[0]->room_tell("{3}Wounded Northlander winces in pain, and attempts to smack the inept nurse in the head with his warhammer.\n{5}Nurse deftly steps out of the way of the northlander's blow.\n");   
    } else {
        $_[0]->room_tell("{3}Wounded Northlander leans back on his cot and mutters, \"Sulphax and his Muggs! I'll never be able to retrieve the treasures now!\"\n");   
    }
}

sub on_ask {
 my ($self, $topic, $from) = @_;
 if ($topic =~ /treasure|sulphax|mugg|quest/) { 
     return <<END_TXT; 
Wounded Northlander sighs and nods, "Yes, I am on a quest. Years ago, Sulphax and an army of Muggs invaded the Northhall.. my home. I was just a child then, and my mother sent me away with my siblings to this city for protection. No one else survived the invasion. The northland craftermasters created magnificent treasures, and it fell on me to steal them back from Sulphax. I managed to sneak past the Mugg guards, but when I reached the vault I found it locked by some sort of magic! I remember an old tale about the passwords needed to open the vault, but it seems like foolishness to me."
END_TXT
 } elsif ($topic =~ /tale|vault|password/) { 
     return <<END_TXT; 
Wounded Northlander frowns and says, "The tale was about our lord craftmasters, creating an impenetrable vault to protect their most precious treasures. After creating the vault, the story goes, they visited the mighty treants and asked them to keep the passwords safe through all eternity. The treants agreed, and bestowed the knowledge onto their tree elders. It can't be true.. How can anyone possibly talk to trees and get the passwords back?!"
END_TXT
 } elsif ($topic =~ /elder|treant/) { 
     return <<END_TXT; 
Wounded Northlander shrugs indifferently, "I don't know the first thing about those blasted trees. Us northlanders are.. were bred as miners and smiths. Maybe you should ask the local Oracle about it."
END_TXT
 } else { return undef; }
 return("");
} 

package npc_oracle;
@npc_oracle::ISA = qw( npc );
use strict;

sub on_ask {
 my ($self, $topic, $from) = @_;
 if ($topic =~ /tree|elder|treant/) { 
     return <<END_TXT; 
Oracle pulls thoughtfully on his beard, then nods his head. "Yes.. the elder trees of the forest are well known to me. There are five in number, protected from sight by woodland magic. A maple, rosewood, greenwood, fir, and willow tree I believe. They store the ancient knowledge of the treants and pixies. But if it is the northland vault you wish to enter, then there is much more you need to know."
END_TXT
 } elsif ($topic =~ /know|vault|north?/) { 
     return <<END_TXT; 
"Indeed." The Oracle begins, "The vault has a secondary security system as well..." He pauses for a second then scratches his head. Glancing around, the Oracle mutters then sighs. "Alas, I seem to have forgotten what it is. Perhaps you should look in the eastland library. It used to hold some impressive tomes of knowledge in its time."
END_TXT
 } elsif ($topic =~ /zeode/) { 
     return <<END_TXT; 
The Oracle shudders at the mention of that word. "A mineral attuned to the mana flow within the universe. Yes, yes.... It is semi-organic too, constantly traveling along the planar eddies as it looks to merge with more of its kind. A large chunk of Zeode landed on Vastis years ago, in the great savanna to the south. A bad.. bad day, it was. Even now, that zeode chunk is growing! Melal, our local mage, is a skilled zeode-shaper. He can make powerful tools with raw zeode."
END_TXT
 } elsif ($topic =~ /tool/) { 
     return <<END_TXT; 
"It'd be best to talk to Melal about such things." The Oracle says, a bit uncomfortable with the topic.
END_TXT
 } else { return undef; }
 return("");
} 

package npc_king_edger;
@npc_king_edger::ISA = qw( npc_quest_receiver );
use strict;

sub on_room_enter {
    my ($self, $who) = @_;
    $who->delay_log_append(1, "{3}King Edger broads gloomily on his throne.\n");
}

sub on_ask {
    my ($self, $topic, $from) = @_;
    if ($topic =~ /help|quest|gloom/) { 
        return <<END_TXT; 
King Edger sighs wistfully, "Hello, young chap. Yes, it is a sad day.. It has been a sad day for years now. All the same. Ever since I lost half of the skyblade battling Sulphax and his armies. If only I had it back..."
END_TXT
    } else { return undef; }
} 

package npc_elder_treant;
@npc_elder_treant::ISA = qw( npc_quest_receiver );
use strict;

sub on_room_enter {
    my ($self, $who) = @_;
    $who->delay_log_append(1, "{3}Elder Treant looks sadly up from its pine-guarded glade, and sighs. In a feeble feminine voice, she asks. \"Have you come to aid with the search?\"\n");
}

sub on_ask {
    my ($self, $topic, $from) = @_;
    if ($topic =~ /search|aid|help|earthstone|yes/) { 
        return <<END_TXT; 
The treant smiles weakly, creating an odd expression with her bark-covered face. "The earthstones have been stolen. Please, help find the stones and return them to me. The reward will be immense."
END_TXT
    } else { return undef; }
} 

package npc_melal;
@npc_melal::ISA = qw( spell_caster );
use strict;

sub on_ask {
    my ($self, $topic, $from) = @_;
    if ($topic =~ /zeode|tool/) { 
        return <<END_TXT; 
Melal looks you over with his stormy-blue eyes, then nods slowly. "I do have the gift of zeode-shaping, but utilizing it is taxing. If you bring me a piece of zeode, along with, say... 5000 cryl, I'd gladly make you an interesting tool of magic."
END_TXT
    } else { return undef; }
} 

sub on_receive {
    my ($self, $obj, $from) = @_;
    if($obj->{'REC'} != 417) { return $self->SUPER::on_receive(@_); }
    if($from->{'CRYL'} >= 5000) { 
        $from->{'CRYL'} -= 5000;
        $self->room_sighttell("{2}Melal takes the offered zeode piece and 5000 cryl. With a wave of his hand, and a few muttered words, he molds the crystal into a long, gleaming staff.\n");
        my $new_item = $self->item_spawn(418);
        $obj->dissolve_allsubs(); # get rid of the zeode; people were killing melal to get it back. meanies.
        $self->item_hgive($new_item, $from, 0, 1); 
    } else {
        $self->item_hgive($obj, $from, 0, 1); 
        $self->say('If you want me to make you a staff, it will cost 5000 cryl.');
    }
}

sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    if(rand(100) < 40) { return if $self->spell_hgeneric('MBEAM', $targ, 1); }
    $self->attack_melee($targ, $weapon); 
}


package npc_fuzzem_elder;
@npc_fuzzem_elder::ISA = qw( npc_quest_receiver );
use strict;

sub on_idle { 
    $_[0]->room_talktell("{3}Fuzzem Elder looks around the village and sighs, his usually happy mood long dead. \"Happy-happy.. not happy.. beastly gone.. happy gone.. Help find.. present and happy too if you can.\"\n");
}


package npc_nurse;
@npc_nurse::ISA = qw( npc );
use strict;

sub on_idle { $_[0]->room_sighttell("Nurse secures the wounded northlander's bandages a bit too tight, causing him to scream out.\n"); }

package npc_westland_bard;
@npc_westland_bard::ISA = qw( npc_quest_receiver );
use strict;

sub on_idle {
    if(rand 1 < .5) {
        $_[0]->room_tell("{3}$_[0]->{'NAME'} strums his mandolin, reciting one of his favorite tunes.\n");   
    } else {
        $_[0]->say('For only twenty cryl, I will sing you a ballad.');   
    }
}

sub on_cryl_receive {
    my ($self, $cryl, $from) = @_;
    if($cryl >= 20) {
        if((time - $self->{'AI'}->{'LASTSONG'}) < 60) {
            $self->say_rand('Sorry, I don\'t want to get a sore throat!', 'Thanks, but wait! I just finished my last gig!', 'Let me rest for a little first, please.');
            $self->cryl_give($cryl, $from);
            return;
        }
        $self->{'AI'}->{'LASTSONG'} = time;
        $self->room_talktell("{2}$self->{'NAME'} thanks $from->{'NAME'} and breaks out in song...\n");
        $self->delay_room_talktell(2, "{6}$npc_westland_bard::songs[rand @npc_westland_bard::songs]");
        $self->delay_action_do(7, 'bow', 'all');
    } else {
        $self->action_do('bow', $from->{'NAME'});
        $self->say_rand('Thank you for the donation!', 'Thank you, kind sir.', 'Gee, thanks!', 'Gosh golly gee!', 'Thank you, thank you.');
    }
}

$npc_westland_bard::songs[0] = <<END_TXT;
The king of hope, Ker'el his name.
Traveling far and wide, to here he came.
He brought with him, a tool of good.
A monolith of magic, only he understood.
Beseeching our lord, he asked for aid.
To place his dreams in a secluded glade.
Our king agreed, his dreams fulfilled.
A place of peace, the two would build.
END_TXT

$npc_westland_bard::songs[1] = <<END_TXT;
Long ago, when Vastis was pure
A queen was born, her name Ladur
Like her father before, the eastlanders she'd rule
Not justly or kind, but viciously and cruel.
Her might grew fast, her enemies did cower
As her magic developed, from which she drew power
Beauty and youth were all Ladur desired.
With magic she found, a small cost was required.
For eternity they'd be hers, all for a toll.
That included her people, the land, and her soul.
In the end, the price she decidedly paid
Would destroy her subjects, and all that they made.
Leaving a land of darkness, a place of night
As all that remained of a once flourishing sight.
END_TXT


$npc_westland_bard::songs[2] = <<END_TXT;
A beast of doom, Sulphax the red
rose in the north, and burned many dead
He rallied the Muggs, led them to war
against the northlanders, the pixies and many more.
The King of the north, fell to the beast
Sulphax's advance didn't slow in the least.
The westlandish lord, called to his men.
Together they rode, out to defend.
The great king-lord, in one hand held high
a sword of power, the blade of the sky.
With it he challenged the mighty Sulphax,
and as the battle grew fierce, his powers were taxed.
Fire from the beast, sword stabs from the man.
They dueled for hours, until neither could stand.
A mighty thrust, brought blade into meat,
piercing the dragon, who howled in defeat.
The king's mighty blade, broken apart.
One piece in hand, the other near the beast's heart.
To the north Sulphax ran, his Muggs following suit.
The king returned home, the danger now moot.
END_TXT

$npc_westland_bard::songs[3] = <<END_TXT;
Four in number, they hold nature's spirit.
Stones of power, containers of merit.
Once held in a glade, surrounded by pine.
Secured away, their safty divine.
Then came from night, a group of creatures.
Imps of darkness and evil, with vicious features.
They grabbed the stones, and fled away.
They cackled and danced, but for long did not stay.
Now the earth does suffer, as the stones depart.
Farther away, they travel from its heart.
One north, one south, and east and west.
The earthstones of Vastis, their retreveal a quest.
END_TXT

package npc_nightmare;
@npc_nightmare::ISA = qw( spell_caster );
use strict;

# inherits from spell_caster; sc_gen_attack called whenever npc is to attack.
sub sc_gen_attack {
    my ($self, $targ, $weapon) = @_;
    
    if(    !$targ->effect_has(52)
        && .75 < rand 1
       ) {
        $targ->room_sighttell("{13}$self->{'NAME'} sends a pulse of negative energy towards $targ->{'NAME'}.\n");
        $targ->log_append("{13}$self->{'NAME'} sends a pulse of negative energy towards you!\n");
        $targ->effect_add(52);
    }
    
    $self->attack_melee($targ, $weapon);
}


package scum_bag;
BEGIN { do 'const_stats.pm'; }
@scum_bag::ISA = qw( npc );
use strict;

sub def_set {
    my $self = shift;
    $self->prefmake_npc;

    $self->{'NAME'} ||= &main::rand_ele('Bruno Blisterfist', 'Gumdrop Gerard', 'Freddy Fistwhack', 'Jerry the Jerk', 'Darth Doombringer');
    $self->{'HOSTILE'} ||= 3;
    $self->{'DESC'} ||= $self->{'NAME'} . " looks like he just pulled off a bank robbery! Better not mess with him while he's countin' his cryl.";

    $self->gender_set('M'); # only guys are scum bags!
    $self->{'DLIFT'} = 0;
    $self->{'CAN_LIFT'} = 0;
    #unless(defined($self->{'BASEH'}) {
    #    $self->{'BASEH'} = 7000;
    #}
    return $self;
}

sub sick_em {
    my ($self, $o) = @_;
    $self->{'STALKING'} ||= $o->{'OBJID'};
    $self->{'ROAMTARG'} ||= $o->{'OBJID'};
    $main::events{$self->{'OBJID'}} = 2;
    return;
}

sub stop_sick {
    my ($self) = @_;
    delete $self->{'STALKING'};
    delete $self->{'ROAMTARG'};
    $main::events{$self->{'OBJID'}} = 0;
    $self->rest();
    $self->delay_rest(1);
    $self->delay_rest(2);
}

sub on_kill {
    my ($self, $victim) = @_;
    $self->cmd_do('laugh');

    if($self->{'ROAMTARG'} == $victim->{'OBJID'}) {
        $self->stop_sick();
    }

    return;
}

sub on_attack {
    my ($self, $attacker, $victim, $weapon) = @_;
    if($self == $victim) {
        $self->sick_em($attacker);
        if($self->{'HP'} < ($self->{'MAXH'} * 0.5)) { 
            $self->rest();
            $self->delay_rest(2);
            $self->delay_rest(1);
        }
    }
    return $self->SUPER::on_attack(@_);
}

sub on_event {
    my $self = shift;

    my $v = $main::objs->{$self->{'ROAMTARG'}};
    if(!$v || !$self->{'ROAMTARG'} || ($self->{'AI'}->{'GIVEUP'} && ($main::map->[$v->{'ROOM'}]->{'M'} != $main::map->[$self->{'ROOM'}]->{'M'} || $self->ai_moves_to($v) > 5)) ) { $self->stop_sick(); return; }
    if($self->{'ROOM'} != $v->{'ROOM'}) { $self->ai_move_to($v);  }
    elsif(!$self->is_tired()) {  $self->attack_player($v, 1);  }
    $main::events{$self->{'OBJID'}} = 2;
    return;
}


########################################
# DAVADA STUFF
########################################

package npc_doyos;
@npc_doyos::ISA = qw( npc );
use strict;

#stole from bloodlord
sub attack_sing {
  my ($self, $victim) = @_;
  if($victim->is_dead || $self->is_dead) { return; }
  else {
    if(rand(100)<70) { $self->htemporal($victim); }
    elsif($self->{'WEAPON'}) { $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}}); }
    elsif($self->{'DWEAP'}) {  $self->attack_melee($victim, &main::obj_lookup($self->{'DWEAP'})); }
    return;
  }
}
1;
