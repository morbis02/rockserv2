
package rockobj;
use const_stats;
use strict;

sub spell_mirage {
    my ($self) = @_;
	
        if ($self->effect_has(67)) {
            $self->log_error("You already have summoned the mirage; wait until it goes away.");
            return;
        }

	unless ($main::rock_stats{'monolith_spectral'}==$self->{'RACE'}    ||
	        $self->skill_has(61))
        {
	    $self->log_error("You don't know how to channel the Spectral Monolith.");
		return;
	}

	return unless $self->can_do(int($self->{'MAXM'}/5)+30,0,0);

	$self->log_append("{14}With a wave of your hand, you summon a sentient mirage, similar to you in every way.\n");
	$self->room_sighttell("{4}With a wave of $self->{'NAME'}\'s hand, $self->{'PRO'} summons a sentient mirage, similar to $self->{'PPRO'} in every way.\n");    
	$self->effect_add(67);
}

sub spell_allwell {
    my ($self) = @_;
	
	unless ($main::rock_stats{'monolith_pearled'}==$self->{'RACE'} && $self->{'GENERAL'}   ||
	        $self->skill_has(60))
    {
	    $self->log_error("You don't know how to channel the Pearled Monolith.");
		return;
	}

	return unless $self->can_do(1,10,75);

    # originally was *3. trying a little higher now.
	my $add_hp = abs int ( ($self->{'MA'}+1) * 4 * $self->fuzz_pct_skill(KMED) );
	$self->{'MA'} = 0;
	
	$self->log_append("{14}Channeling the force of the Pearled Monolith, you send a healing wave of energy to all of your loyal troops.\n");
	$self->room_sighttell("{4}A wave of {17}bright white energy {7}washes of off $self->{'NAME'}, as $self->{'PRO'} invokes the power of the Pearled Monolith.\n");
    
	
	# for each player in the game of that race:
	foreach my $targ (grep { $_->{'HP'} > 0 &&  $_->{'RACE'} == $self->{'RACE'} && $_->{'SOLDIER'} } map { $main::objs->{$_} } keys %$main::activeusers) {
		$targ->log_append("{14}You feel a tide of healing energy (+$add_hp) wash across your body.\n");
		if ($targ->{'HP'} < $targ->{'MAXH'}) {
  		    $targ->room_sighttell("{4}$self->{'NAME'}\'s wounds suddenly lessen.\n");
		    $targ->{'HP'} += $add_hp;
			$targ->{'HP'} = $targ->{'MAXH'} if $targ->{'HP'} > $targ->{'MAXH'};
		}
	}
}

sub spy_report_location_of {
    my ($self, $victim, $moretimes) = @_;
    $self->log_append("{6}The image of your astral spy suddenly flashes in your mind, informing\nyou of {17}$victim->{'NAME'}\{6}\'s position: {2}$main::map->[$victim->{'ROOM'}]->{'NAME'}\n");
    
    $main::eventman->enqueue(rand(20) + 40, \&rockobj::spy_report_location_of, $self, $victim, abs($moretimes-1)) if $moretimes;
}

sub spell_astral_spy {
    # tries to cast grapegrow
    my ($self, $vname) = @_;
    my $victim = ref($vname) ? $vname : $self->uid_resolve($vname);
    return 0 if(!$victim);
    if(!$self->skill_has(41)) {
        $self->log_error('You have no clue how to employ the spy.');
        return 0;
    }

    if($victim->is_developer()) {
        $self->log_append("{7}The spy refuses to work versus $victim->{'NAME'}.\n");
        return 0;
    }

    return 0 if(!$self->can_do(100, 0, 25));

    $self->room_tell("{4}$self->{'NAME'} waves $self->{'PPOS'} hand through the air, invoking some sort of spell.\n");
    $self->log_append("{4}You summon forth a spy of astral energy, and send it to locate $victim->{'NAME'}.\n");
    $main::eventman->enqueue(40, \&rockobj::spy_report_location_of, $self, $victim, 5);
    return 1;
}

sub spell_scry {
    my ($self, $cmd) = @_;
    
    if(!$self->skill_has(43)) {
        $self->log_error('Scrykomookie?');
        return 0;
    }

    return 0 if(!$self->can_do(2, 0, 1));
    
    if(!$main::scry_ball_objid || !defined($main::objs->{$main::scry_ball_objid})) {
        $self->log_error('Error: no scryball in play.');
        return 0;
    }
    
    my $scryball = $main::objs->{$main::scry_ball_objid};
    $self->room_sighttell("{4}$self->{'NAME'}\'s eyes grow dim as he intones a spell.\n")
        unless $self->room()->{'SAFE'};
    if ($main::dirlongmap{uc($cmd)} || $cmd =~ /^(?:go|enter) \w+/i) {
        $self->log_append("{4}You intone the spell, forcing the scryball to: {14}$cmd\n");
        $scryball->cmd_do($cmd);
        $self->log_append("{14}Scryball sees: ".$scryball->room()->exits_list()."\n");
    } elsif($cmd =~ /^lo?o?k?$/) { 
        $self->log_append("{17}Through the scryball, you see: " . $scryball->room_str() . "\n");
    } else {
        $self->log_error("Spell failed - Invalid Command - options: [direction], look, go <object>.");
        return 0;
    }
    return 1;
}

sub spell_lifeshield {
    my ($self, $override) = @_;
    # It drains 50% of your remaining mana, and creates an effect that rais
    #es your MAXH by an amount equal to your MDEF + manaused + LEV
    if(!$override) {
        if(!$self->skill_has(44)) {
            $self->log_error('Yeah right - you can hardly shield yourself the way it is!');
            return 0;
        }
        return 0 if(!$self->can_do(int ($self->{'MAXM'}/2), 0, 10));
    }
    
    $self->room_sighttell("{4}A bright energy surrounds $self->{'NAME'}, as $self->{'PRO'} mouths the words to an ancient spell.\n");
    $self->log_append("{4}You form a lifeshield to protect yourself.\n");
    
    $self->effect_add(48);
    return 1;
}

sub spell_detect_forces {
    # tries to cast grapegrow
    my ($self) = @_;
    if(!$self->skill_has(42)) {
        $self->log_error('Detectofuzz?');
        return 0;
    }

    return 0 if(!$self->can_do(75, 0, 15));

    $self->room_sighttell("{4}$self->{'NAME'} raises his hands and invokes a spell.\n");
    my %races;
    my $mnum = $main::map->[$self->{'ROOM'}]->{'M'};
    foreach my $uid (values(%{$main::activeuids})) {
        my $player = $main::objs->{$uid};
        if($main::map->[$player->{'ROOM'}]->{'M'} == $mnum) {
            $races{$player->{'RACE'}}++;
        }
    }
    my $cap;
    foreach my $racenum (sort { $races{$b} <=> $races{$a} } keys %races) {
        $cap .= sprintf "{15}%15s: {5}%2d\n", $main::races[$racenum], $races{$racenum};
    }
    $self->log_append("{4}You detect the following lifeforms residing within this plane:\n$cap");
    return 1;
}

sub spell_wizards_eye {
    # tries to cast grapegrow
    my ($self, $vname) = @_;
    if(!$self->skill_has(39)) {
        $self->log_error('Wizzawhatta?');
        return 0;
    }
    my $victim = ref($vname)?$vname:$self->uid_resolve($vname);
    return 0 if(!$victim);

    if($victim->is_developer()) { 
        $self->log_error("The eye refuses to work versus $victim->{'NAME'}.");
        return 0;
    }

    return if(!$self->can_do(25, 0, 30));
    $self->room_tell("{4}$self->{'NAME'} speaks a few words as $self->{'PRO'} invokes a spell.\n");
    $self->log_append("{4}You cast your sight outwards, searching for $victim->{'NAME'}.\n");
    if(rand $self->fuzz_pct_skill(22)  < rand $victim->fuzz_pct_skill(21)) {
        $victim->log_append("{3}A gigantic eye appears above you, momentarily looking around before it fades into nothingness.\n");
        $victim->room_sighttell("{3}A gigantic eye appears above $victim->{'NAME'}, momentarily looking around before it fades into nothingness.\n");
    }
    $self->log_append($victim->room_str());
    return 1;
}

sub spell_grapegrow {
    # tries to cast grapegrow
    my $self = shift;
    if(!$self->skill_has(21)) {
        $self->log_append("{17}Funny..you don't exactly seem like the gardening type...\n");
        return 0;
    }

    if(!$self->inv_has_rec(297, 18)) {
        $self->log_append("{17}What? You expect it to happen with your magic invisible tools or something?\n");
        return 0;
    }
    
    return if(!$self->can_do(20, 0, 20));
    
    $self->inv_rec_scan(297)->obj_dissolve;
    
    # check for failure, handle social messages
    if($self->fuzz_pct_skill(22, 75) < rand(1)) { $self->log_append("{17}..you accidentally spill your seeds while fumbling with your staff. Clumsy, clumsy, clumsy!\n"); $self->room_sighttell("{2}$self->{'NAME'} spills some seeds on the floor, which promptly disappear.\n"); return; }
    $self->room_sighttell("{5}$self->{'NAME'} {2}scatters a handful of black seeds upon the ground, and waves his staff above them. Within a few seconds, vines begin to sprout upwards, carrying with them a {5}bounty of grapes{2}.\n");
    $self->log_append("{2}...within a few seconds, vines begin to sprout upwards, carrying with them a {5}bounty of grapes{2}.\n");
    
    # spawn grapes
    my $grapes = ($self->fuzz_pct_skill(22, 75)*100/20+1);
    my @a; for (my $x=1; $x<=$grapes; $x++) {
        push(@a, 299);
    }
    $main::map->[$self->{'ROOM'}]->item_spawn(@a);

    return 1;
}

sub spell_flesh_meld {
    # NOTE, the $self is the object that gets melded, NOT the user melding.
    my ($self, $caster) = @_;
    if(!$caster->skill_has(3)) {
        $caster->log_error('{3}You are uneducated in the skills of flesh melding.');
        return 0;
    }

    if(!$self->{'BPART'}) {
        $caster->log_error("{1}$self->{'NAME'} {6}is hardly a body part!");
        return 0;
    }

    return 0 if(!$caster->can_do(5, 0, 1));

    $caster->log_append("{12}You {2}meld the $self->{'NAME'} to your body.\n");
    $caster->room_sighttell("{12}$caster->{'NAME'} {2}melds the $self->{'NAME'} to $caster->{'PPOS'} body.\n");
    $caster->{'HP'} += int $self->{'MAXH'};
    if ($caster->{'HP'} > $caster->{'MAXH'}) { $caster->{'HP'} = $caster->{'MAXH'}; }
    $self->obj_dissolve; # bye bye flesh.
    return 1;
}


sub spell_blinding {
    my ($self, $victim) = @_;
    # if i dont have the blinding skill, tell me and exit
    if(!$self->skill_has(7)) {
        $self->log_error('You have no idea how to blind others.');
        return 0;
    }
    
    # if pvp restrictions dont support it, or i dont have the turns/mana, tell me and exit
    return 0 if($self->log_cant_aggress_against($victim) || !$self->can_do(50, 0, 30));
    
	# Log attack for pvp info
	$self->note_attack_against($victim); 
	
    # Tell myself and the room what happened.
    $self->log_append("{5}You cast the spell of {15}blinding{5} upon {2}$victim->{'NAME'}\{5}.\n");
    $self->room_sighttell("{1}$self->{'NAME'} {5}casts the spell of {15}blinding{5} upon {2}$victim->{'NAME'}\{5}.\n");
    
    # if (random number, compared to stat 22) works out, then blind the victim.
    if(rand(1) < $self->fuzz_pct_skill(22,100)) {
        $victim->effect_add(22);
        $victim->{'FX'}->{'22'} = time + 30;
        $victim->effects_update();
    } else {
        $victim->log_append("{1}You are unaffected.\n");
    }
    
    return 1;
}

sub spell_nomouth {
    my ($self, $victim) = @_;
    # if i dont have the skill, tell me and exit
    if(!$self->skill_has(30)) {
        $self->log_error('You have no idea how to demouth others.');
        return 0;
    }
    
    # if pvp restrictions dont support it, or i dont have the turns/mana, tell me and exit
    return 0 if($self->log_cant_aggress_against($victim) || !$self->can_do(50, 0, 30));

	# Log attack for pvp info
	$self->note_attack_against($victim); 
    
    # Tell myself and the room what happened.
    $self->log_append("{5}You cast the spell of {15}nomouth{5} upon {2}$victim->{'NAME'}\{5}.\n");
    $self->room_sighttell("{1}$self->{'NAME'} {5}casts the spell of {15}nomouth{5} upon {2}$victim->{'NAME'}\{5}.\n");
    
    # if (random number, compared to stat 22) works out, then blind the victim.
    if(rand(1) < $self->fuzz_pct_skill(22,100)) {
        $victim->effect_add(26);
        $victim->{'FX'}->{'26'} = time + 30;
        $victim->effects_update();
    }
    else {
        $victim->log_append("{1}You are unaffected.\n");
    }
    
    return 1;
}



sub spell_obfuscate {
    my ($self) = @_;
    # if i dont have the skill, tell me and exit
    if(!$self->skill_has(31) && $main::rock_stats{'monolith_shadow'}!=$self->{'RACE'}) {
        $self->log_error('You have no idea how to obfuscate yourself.');
        return 0;
    }
    
    # if i dont have the turns/mana, tell me and exit
    return 0 if(!$self->can_do(50, 0, 30));
    
    # Tell myself and the room what happened.
    if($self->skill_has(32) || $main::rock_stats{'monolith_shadow'}==$self->{'RACE'}) {
        # greater obfusc
        $self->log_append("{4}You obfuscate your current position, hiding it from view.\n");
        $self->effect_add(39) if($self->skill_has(31));
    
        if(rand(1) < $self->fuzz_pct_skill(11,80)) { 
            $self->{'HIDDEN'}=1 unless $self->{'HIDDEN'};
            $self->room_sighttell("{4}A sudden darkness removes {7}$self->{'NAME'} {4}from sight!\n");
        }
        else {
            $self->room_sighttell("{4}A sudden darkness removes {7}$self->{'NAME'} {4}from sight...but quickly diffuse into the surroundings.\n");
        }
    
    }
    else { 
        # obfusc
        $self->room_sighttell("{4}With a few words and hand gestures, {7}$self->{'NAME'} {4}blankets $self->{'PPRO'}self in a dark shadow.\n");
        $self->effect_add(39);
    }

    return 1;
}

sub skill_can_do() {
    # non-hostile can_do
    my ($self, $victim) = @_;
    if($self->{'RACE'} != $victim->{'RACE'}) {
        $self->log_error('To someone of an opposing race? Are you crazy?');
        return 0;
    }
    return 1;
}

sub spell_mindvisit {
    my ($self, $victim) = @_;
    if(!$self->skill_has(8)) {
        $self->log_error('You have no idea how to call upon the envisagers.');
        return 0;
    }

    return 0 if(!$self->can_do($self->{'MAXM'}, 0, 25)); # !$self->skill_hcan_do($victim) || 75 mana
    $self->log_append("{2}You call upon the envisagers.\n");
    $self->room_sighttell("{1}$self->{'NAME'} {2}calls upon the envisagers, to visit the mind of $victim->{'NAME'}.\n");

    if($victim->{'FX'}->{'29'}) {
        $victim->log_append("{2}The encrazed envisagers already inside your mind refuse to leave.\n");
    }
    elsif($self->got_lucky(6) || (rand($victim->fuzz_pct_skill(21,35)) < rand($self->fuzz_pct_skill(22,170)))) {
        $victim->effect_add(29);
    }
    else {
        $victim->log_append("{1}You are unaffected.\n");
    }
    return 1;
}

sub spell_close_wounds {
    my ($self) = @_;
    if(!$self->skill_has(4)) {
        $self->log_error('You have no idea how your body could close its wounds.');
        return 0;
    }

    return 0 if(!$self->can_do(20, 0, 10));

    $self->log_append("{12}A section of your wounds rapidly close together.\n");
    $self->room_sighttell("{12}A section of $self->{'NAME'}\'s wounds rapidly close together.\n");
    $self->{'HP'} += int ($self->fuzz_pct_skill(11)*$self->{'MAXH'} / (5 + 15 * $self->is_tired()) );
    if($self->{'HP'} > $self->{'MAXH'}) { $self->{'HP'}=$self->{'MAXH'}; }
    $self->make_tired();
    return 1;
}

sub spell_knit_flesh {
    my ($self) = @_;
    if(!$self->skill_has(19)) {
        $self->log_error('You have no idea how your body could close its wounds.');
        return 0;
    }

    return 0 if(!$self->can_do(15, 0, 2));

    $self->log_append("{12}You knit together a portion of your wounds.\n");
    $self->room_sighttell("{12}$self->{'NAME'} knits together a portion of $self->{'PPOS'} wounds.\n");
    $self->{'HP'} += int rand(25)+20;
    if($self->{'HP'} > $self->{'MAXH'}) { $self->{'HP'}=$self->{'MAXH'}; }
    return 1;
}

#mich patch - mana boost
sub spell_mana_boost {
    my ($self) = @_;

    if(!$self->skill_has(56)) {
        $self->log_error('You\'d have better luck turning hamburgers into cows.');
        return 0;
    }

    return 0 if(!$self->can_do(0, 0, 35));

    #    my $dam = int ((rand($self->{'MAXM'}/4))+($self->{'MAXM'}/10));
    my $dam = int ((rand($self->{'MAXM'}/8))+($self->{'MAXM'}/10)); # plat changed, he's stingy
    $self->log_append("{14}You cull mana from the ether.\n");
    $self->room_tell("{6}$self->{'NAME'} {4}culls mana from the ether.\n");
    
    # Bonuses
    my $i;
    if(($i = $self->inv_rec_scan(418)) && $i->{'EQD'}) { $dam *= 2; } # zeode staff
    # /Bonuses
    
    $self->{'MA'} += $dam;
    $self->{'MA'} = $self->{'MAXM'} if $self->{'MAXM'} < $self->{'MA'};
    return 1;
}
#end mich patch

sub spell_speed_healing {
    my ($self) = @_;
    if(!$self->skill_has(5)) {
        $self->log_error('\"C\'mon, self! Speed up your healing,\" you think to yourself.');
        return 0;
    }

    return 0 if(!$self->can_do(25, 0, 15));

    if($self->{'FX'}->{'30'} || rand(1) > $self->fuzz_pct_skill(8)) {
        $self->log_error('You are unable to heal yourself any faster.');
        return 0;
    }

    $self->effect_add(30);
    $self->room_sighttell("{12}$self->{'NAME'}\'s wounds glitter for a moment with divine speed.\n");
    return 1;
}

sub spell_barkish_int {
    my ($self) = @_;
    if(!$self->skill_has(22)) {
        $self->log_error("..and you think any ol' $main::races[$self->{'RACE'}] can do that?");
        return 0;
    }

    if(!$self->inv_has_rec(298)) {
        $self->log_error('What? You expect it to happen with your magic invisible tools or something?');
        return 0;
    }

    return 0 if(!$self->can_do(20, 0, 35));
    $self->inv_rec_scan(298)->obj_dissolve();
    
    if(rand(1) > $self->fuzz_pct_skill(12)) {
        $self->log_append("{3}Your spell fizzles, turning the bark to useless ash.\n");
        $self->room_sighttell("{3}$self->{'NAME'} casts a spell on $self->{'PPOS'} piece of bark, which fizzles and turns it into useless ash.\n");
        return 0;
    }

    $self->effect_add(35);
    $self->room_sighttell("{12}With a word of magic, $self->{'NAME'}\'s outer skin is replaced by a thick coating of bark.\n");
    return 1;
}

sub spell_blossom_allure {
    my ($self, $dir) = @_;
    $dir = $main::dircondensemap{lc($dir)};

    if(!$self->skill_has(23)) {
        $self->log_error('..you? What-EVER!');
        return 0;
    }

    if(!$self->inv_has_rec(296)) {
        $self->log_error('What? With your charisma alone? Pfft!');
        return 0;
    }
    
    my $r = $main::map->[$self->{'ROOM'}];
    # check dir
    if( !($r->{$dir}->[0] && !$r->{$dir}->[1]) ) {
        $self->log_error('..you can\'t cast it in that direction!');
    }

    my $t = $main::map->[$r->{$dir}->[0]];
    return 0 if(!$self->can_do(20, 0, 35));
    $self->inv_rec_scan(296)->obj_dissolve();
    
    if(rand(2) > $self->fuzz_pct_skill(12)+$self->fuzz_pct_skill(7)) {
        $self->log_append("{3}Your spell fizzles, turning the blossom to useless ash.\n");
        $self->room_sighttell("{3}$self->{'NAME'} casts a spell on $self->{'POS'} blossom, which fizzles and turns into useless ash.\n");
        return 0;
    }

    # success..
    $self->room_sighttell("{5}$self->{'NAME'} {15}pulls out a pinkish blossom and throws it into the air, chanting a series of words as it spirals back down to earth. Just as it seems ready to land it blows off to {5}$main::dirfrommap{$dir}\{15}, carrying with it an intoxicating scent.\n");
    $self->log_append("{15}You pull out a pinkish blossom and throw it into the air, chanting a series of words as it spirals back down to earth. Just as it seems ready to land it blows off to {5}$main::dirfrommap{$dir}\{15}, carrying with it an intoxicating scent.\n");
    
    my $count = 0;
    foreach my $o ($t->inv_objs) {
        if( $o->{'TYPE'} == OTYPE_PLAYER || $o->{'TYPE'} == OTYPE_NPC ) { 
		    next if $self->cant_aggress_against($o, 1); # dont care about which room they're in
            next if( rand($o->fuzz_pct_skill(7)) > rand($self->fuzz_pct_skill(14, 80)) );
            $o->log_append("{5}You catch the alluring scent of a flower from the {2}$main::dirlongmap{$main::diroppmap{$dir}}\{5}, and are compelled to follow it.\n");
            $o->{'ENTMSG'}='shambles in, enticed'; $o->{'LEAMSG'}='shambles out, enticed';
            $count++ if($o->realm_move($main::diroppmap{$dir}, 0));
            delete $o->{'ENTMSG'}; delete $o->{'LEAMSG'};
            last if( ($count >= 3) || (rand(100)<30) );
        }
    }
    
    return 1;
}

sub skill_sprinting {
    my ($self, $dirs) = @_;
    if(!$self->skill_has(24)) {
        $self->log_error('..you\'re hardly prepared for that!');
        return 0;
    }

    if($self->is_tired()) {
        $self->log_error('..must..<pant>..breathe..<pant pant>..too..tired!');
        return 0;
    }

    if(!$dirs) {
        $self->log_error('Format: sprint <direction> [dir] [dir] [dir] [dir]');
        return 0;
    }

    return 0 if(!$self->can_do(0, 0, 40));
    while(index($dirs, '  ')!=-1) { $dirs =~ s/  / /g; }
    my @dirs = split(/ /, $dirs);
    splice @dirs, 5;
    if(rand(1) < $self->fuzz_pct_skill(3, 400)) { $self->{'SCURRYACTIVE'} = 1; }
    
    $self->{'ENTMSG'}='sprints in';
    $self->{'LEAMSG'}='sprints out';
    foreach my $dir (@dirs) {
        delete $self->{'TRD'};
        last if (!defined($main::dircondensemap{lc($dir)}) || !$self->realm_move($main::dircondensemap{lc($dir)}, 1));
    }
    delete $self->{'ENTMSG'};
    delete $self->{'LEAMSG'};
    
    $self->{'TRD'}=time+5; # make tired, and then some
    delete $self->{'SCURRYACTIVE'};
    return 1;
}

sub spell_levitation {
    my ($self) = @_;
    if(!$self->skill_has(14)) {
        $self->log_error('\"C\'mon, self! Repulse that gravity!! Yay Self!,\" you think to yourself.');
        return 0;
    }

    return 0 if(!$self->can_do(5, 0, 10));

    if($self->{'FX'}->{'32'} || (rand(1) > $self->fuzz_pct_skill(12)) ) {
        $self->log_error('You are unable to further repulse gravity.');
        return 0;
    }

    $self->effect_add(32);
    $self->room_sighttell("{12}$self->{'NAME'}\'s body begins to levitate above the ground.\n");
    return 1;
}

sub spell_cloaking {
    my ($self) = @_;
    if(!$self->skill_has(22)) {
        $self->log_error('Yeah, right.. You\'d probably throw yourself into another dimension or something.');
        return 0;
    }

    return 0 if(!$self->can_do(0, 0, 10));

    if($self->{'FX'}->{'33'} || (rand(1) > $self->fuzz_pct_skill(12)) ) {
        #mich says - why does this say levitate? i guess it doesnt matter since this spell isn't in-game
        $self->log_error("You are unable to further levitate yourself.");
        return;
    }

    $self->effect_add(33);
    $self->room_sighttell("{12}$self->{'NAME'}\'s frequency begins to shift.\n");
    return 1;
}

sub spell_harden_flesh {
    # NOTE, the $self is the object that gets melded, NOT the user melding.
    my ($self) = @_;
    
    if(!$self->skill_has(6)) {
        $self->log_error('You have no idea to harden your flesh.');
        return 0;
    }
    
    return 0 if(!$self->can_do(30, 0, 20));

    if($self->{'FX'}->{'31'}) {
        $self->log_error('You are unable to further harden your flesh.');
        return 0;
    }

    $self->effect_add(31);
    $self->room_sighttell("{3}$self->{'NAME'}\'s flesh shrinks slightly as $self->{'PPOS'} flesh hardens.\n");
    return 1;
}

sub spell_flesh_animate {
    # animates flesh based on bodyparts in inventory
    my $self=shift;

    if(!$self->skill_has(37)) {
        $self->log_error('You have no idea how.');
        return 0;
    }

    return 0 if(!$self->can_do(200, $self->{'MAXH'} * .9, 20));

    my ($success, @cparts);

    $self->room_sighttell("{4}$self->{'NAME'} {2}exerts $self->{'PPOS'} own lifeforce in attempt to animate the corpses in the room.\n");
    my $room = $main::map->[$self->{'ROOM'}];
	my @bparts = grep {$_->{'BPART'} && $_->{'TYPE'}==0} $room->inv_objs;

    # animate corpses
    foreach my $part (@bparts) { 
        if($part->{'BPART'} eq 'corpse') {
            $part->make_zombie($self);
            $success = 1;
        }
        else {
            push(@cparts, $part);
        }
    }

    while($#cparts >= 4) {
        my $basepart = shift(@cparts);
        $basepart->objs_meld_into(shift(@cparts), shift(@cparts), shift(@cparts), shift(@cparts));
        $basepart->{'NAME'}='mess of body parts';
        $basepart->make_zombie($self);
        $success = 1;
    }
    
    if(!$success) {
	    $self->log_error('There are not enough body parts on the ground to animate!');
	    return 0;
    }

    return 1;
}

#mich owned this function
sub spell_generic (cap) {
    my ($self, $cap) = @_;
    $cap = &main::rm_whitespace($cap);
    my ($sname, $vname) = split(/ /, $cap, 2);

    if(!$sname) {
        $self->log_error('Cast what? (Format: \"cast <spellname> <victimname>\")');
        return 0;
    }

    if($vname) {
        my ($success, $item) = $self->inv_cgetobj($vname, 0, $main::map->[$self->{'ROOM'}]->inv_objs, $self->inv_objs);
        if($success == 1) {
            return $self->spell_hgeneric($sname, $item);
        }
        elsif($success == 0) {
            $self->log_error("You don't see any $vname to cast upon.");
            return 0;
        }
        elsif($success == -1) {
            $self->log_append($item);
            return 0;
        }
    }

    return $self->spell_hgeneric($sname);
}

#mich says - do we really need this? hahahhahagsgkjskgdg
#mich answers himself after a text search - no we don't
#sub testfail { print "Didn't pass $_[0] test.\n"; return(0); }

#MICH OWNED THIS FUNCTION GOOD
sub spell_hgeneric (spell_code[, receiver object]) {
    my ($self, $spellcode, $receiver, $override) = @_;

    # we need to know this later, so why not save it
    my $acode_is_array = 0;

    if($self->is_tired()) {
        $self->log_error('You\'re much too tired for that right now.');
        return 0;
    }

    if(!$main::spellbase{uc($spellcode)}) {
        $self->log_error("You had no idea that {13}$spellcode {3}was even possible.");
        return 0;
    }

    my ($minm, $minh, $mint, $acode, $mina, $minacc, $maxacc, $rectype, $all, $permit_self, $lifeforms_only, $include_dead, $lvl_restrict, $ret, $code, $msgs_after_spell, @msgs) = @{$main::spellbase{uc($spellcode)}};
    
    # mich note- level restrictions per spell basis not built in at the moment (if it is needed, the call to cant_aggress must be putzed with)
    $lvl_restrict ||= $main::pvp_restrict; # default to $main::pvp_restrict if not already set
  
  
    # if we should skip the checks if override != 0...
    if(!$override) {
        my ($cando, $canreq);
        
        # cando is a boolean, canreq is the user's experience level
        if(ref($acode) eq 'ARRAY') {
            $acode_is_array = 1;
            $cando = $self->skill_has(@{$acode});
            $canreq = $self->{'LEV'};
        }
        else {
            $canreq = $cando = $self->{'GIFT'}->{$acode};
        }
        
        if(!$cando) {
            $self->log_error('You have no idea how to go about doing that!');
            return 0;
        }
        
        if($canreq < $mina) {
            $self->log_error('You are not yet skilled enough to do that!');
            return 0;
        }
    }
  
    # safe room..
    if($main::map->[$self->{'ROOM'}]->{'SAFE'} && $rectype != 1) {
        $self->log_error('Your magic would be useless in this sanctuary!');
        return 0;
    }
    
    if($minh && $minh < 1) { $minh = int ($self->{'MAXH'} * $minh); }
    if($minm && $minm < 1) { $minm = int ($self->{'MAXM'} * $minm); }
    if($mint && $mint < 1) { $mint = int ($self->{'MT'} * $mint); }
    
    
    ## OKAY, so we can do it.
    my (@victims, $victim, @picklist);
  
    # figure out who this is going to affect.
    if($all) { 
        @picklist = $main::map->[$self->{'ROOM'}]->inv_objs;
    } elsif(!$receiver) {
        @picklist = ($self);
    } else {
        @picklist = ($receiver);
    }

    # refine the list, put it into @victims
    foreach $victim (@picklist) {
        if ($rectype == -1 && $self->log_cant_aggress_against($victim)) {
            return 0 if(!$all);
            next;
        }

        if ($victim == $self && !$permit_self) {
            if(!$all) {
                $self->log_error('Nothing happens. You must be immune to your own spell.');
                return 0;
            }
            next;
        }

        if($victim->is_dead && !$include_dead) {
            $self->log_error("{13}$victim->{'NAME'} {3}is very dead.");
            next;
        }
        
        next if  $lifeforms_only &&
		         $victim->{'TYPE'} != OTYPE_NPC &&
				 $victim->{'TYPE'} != OTYPE_PLAYER;
				 
        push(@victims, $victim);
        
		$self->note_attack_against($victim) if $rectype == -1; # if it's offensive, note attack.
    }

    # none of the victims passed the test
    if($#victims == -1) {
        $self->log_error('Nothing happens. Perhaps nobody is here to affect?');
        return 0;
    }

    # if they dont have the resources, give'em the boot.
    return 0 if(!$self->can_do($minm, $minh, $mint));
    $self->make_tired();
  



    $self->trivia_inc(STAT_CASTS);

## BELOW IS A TEMP FIX TILL I CAN GET HOME TO ACTUALLY LOOK AT 
## WHAT'S GOING ON HERE -- NPCS AREN'T ATTACKING BACK. THEY FAIL. IT SUCKS.
if (ref $acode  eq "ARRAY" && @$acode == 1) { 
$acode_is_array = 1;
}

    my $accuracy;
    if($acode_is_array) {
        $accuracy = $maxacc;
		$self->log_append("Accuracy (hard-coded): $accuracy\n") if $self->{'ADMIN'};
    } else {
        $self->gifts_affect($acode);
        $accuracy = ($self->{'GIFT'}->{$acode}-$minacc) * (100 / ($maxacc - $minacc)) unless (!($maxacc-$minacc));
		$self->log_append("Accuracy (based off your GIFT of $acode, minacc $minacc and maxacc $maxacc): $accuracy\n") if $self->{'ADMIN'};
    }
  
    # So we have the resources, but let's see if we fail.
    $accuracy = 100 if($accuracy > 100);
    if(rand(100) >= $accuracy) {
        $self->trivia_inc(STAT_FAILS); 
        # ouch they failed!
        my $victim = $victims[0];
        grep {  s/\%PS/$self->{'PRO'}/g; s/\%HS/$self->{'PPOS'}/g;  s/\%MS/$self->{'PPRO'}/g; s/\%S/\{16\}$self->{'NAME'}\{15\}/g; } @msgs;
        grep {  s/\%PR/$victim->{'PRO'}/g; s/\%HR/$victim->{'PPOS'}/g; s/\%MR/$victim->{'PPRO'}/g; s/\%R/\{16\}$victim->{'NAME'}\{15\}/g; } @msgs;
        $self->log_append("{15}$msgs[3]\n");
        $self->room_sighttell("{15}$msgs[4]\n") if($msgs[4]);
        return 0;
    }

    # note: @msgs is in the form of: 0$send_msg, 1$rec_msg, 2$all_msg, 3$self_fail_msg, 4$others_fail_msg
    grep {  s/\%PS/$self->{'PRO'}/g; s/\%HS/$self->{'PPOS'}/g;  s/\%MS/$self->{'PPRO'}/g; s/\%S/\{16\}$self->{'NAME'}\{15\}/g; } @msgs;

    my @mcopy = @msgs;
    $code = $$code unless ref($code) eq "CODE";

    foreach $victim (@victims) {
        my $was_dead = $victim->is_dead;
        @msgs = @mcopy;
        grep {  s/\%PR/$victim->{'PRO'}/g; s/\%HR/$victim->{'PPOS'}/g; s/\%MR/$victim->{'PPRO'}/g; s/\%R/\{16\}$victim->{'NAME'}\{15\}/g; } @msgs;

        if(!$msgs_after_spell && $mcopy[0]) {
            $self->log_append("{15}$msgs[0]\n");
            $victim->log_append("{15}$msgs[1]\n") if($victim ne $self);
            $self->room_sighttell("{15}$msgs[2]\n", $victim);
        }

        my $dam = &{$code}($self, $victim, $accuracy);

        if($msgs_after_spell && $mcopy[0]) {
            grep { s/\%D/$dam/g; } @msgs;
            $self->log_append("{15}$msgs[0]\n");
            $victim->log_append("{15}$msgs[1]\n") if($victim ne $self);
            $self->room_sighttell("{15}$msgs[2]\n", $victim);
        }

        $self->damAttack($victim, $dam) if($dam);
        $victim->attack_sing($self, 1) if($ret && !$victim->is_tired());
        $victim->die($self) if($victim->is_dead && !$was_dead);
        $main::map->[$self->{'ROOM'}]->tell(2, 1, 0, undef, $self, $victim, undef) if($rectype == -1);
    }

    return 1;   
}

#mich was here
sub can_do(minimum:mana,hp,turns) {
    # $self->can_do($min_mana, $min_hp, $min_turns);
	
    my ($self, $minm, $minh, $mint) = @_;
    my ($room, $mod) = ($main::map->[$self->{'ROOM'}]);

    $minh = 0 if($minh < 0);
    
    # handle turn modifiers
    if($mod = $room->{'TURNMOD'}) {
        $mint = ($mod =~ /\./) ? int($mint * $mod) : $mint + $mod;
    }
    
	# Don't comment this.. We want players to read the damned rules!!
# NOTE: 04/04/2003 Plat commented this. (har har :))
#    if ($self->{'TYPE'}==1 && !$self->pref_get('read rules')) { 
#        $self->log_append("{17}***\n{16}*** {17}Sorry, but you cannot do any commands until you've read the rules.\n{17}*** Type \"help rules\" to view them, and gain permission to play.\n{16}***\n");
#        return(0);
#    }
	
#	# nag only
#    if ($self->{'TYPE'}==1 && !$self->pref_get('read news')) { 
#        $self->log_error("Hey, did you check today's news? What if something important happened?");
#		$self->log_hint("Type \"news\" to list the most recent news articles.");
        #return(0);
#    }
    
	#  if($self->{'TYPE'}==1 && $self->{'LPWCH_TIME'} < $main::min_pw_change_time) {
    #        $self->log_append("{17}***\n{16}*** {17}Sorry, but you cannot do any commands until you've changed your password.\n{17}*** Type \"help chpw\" for info on how to do this.\n{16}***\n");
    #        return(0);
    #  }
    if($self->{'FX'}->{6}) {
        $self->log_error('You cannot do that while you are paralyzed.');
        return 0;
    }

    if($self->{'FROZEN'}) {
        $self->log_error('You cannot do that while you are frozen.');
        return 0;
    }
    
    if(defined($self->{'FX'}->{28}) && (rand(100)<30)) {
        $self->log_error('Your body fails to comply in its weakened state.');
        $self->room_sighttell("{2}$self->{'NAME'} {3}struggles to do something, but appears to be too weakened.\n");
        return 0;
    }

    if($self->is_dead) {
        $self->log_error('You can\'t do that while you\'re dead!');
        $self->log_hint('Type life to come back to life!');
        
        $self->log_suspicious_activity('Typed command while dead.', 15)
            unless $self->{'GAME'};
        return 0;
    }

$self->{'MA'} = $self->{'MAXM'} if $self->{'TYPE'} != 1;

    if($self->{'MA'} < $minm) {
        $self->log_error('You don\'t feel magically strong enough to do that!');
        return 0;
    }

    if($self->{'HP'} <= $minh) {
        $self->log_error('You are not healthy enough to do that!');
        return 0;
    }

    if( $self->{'TYPE'} == OTYPE_PLAYER && $self->{'T'} < $mint && !$self->{'GAME'} ) {
        $self->log_error('You do not have enough turns to do that!');
        $self->log_hint("Every day you get new turns! Come back tomorrow and play s'more!");
        return 0;
    }
    
    # .. etc ...
    
    # take away requirements from player
    $self->{'MA'} -= int $minm;
    $self->{'HP'} -= int $minh; 
    if(!$self->{'GAME'}) { $self->{'T'} -= int $mint; }
    
    # affect vigor.
    if($self->{'TYPE'} == OTYPE_PLAYER && $mint) {  #mich added && $mint
        $self->{'VIGOR'} -= $mint/200; # plat changed; was $mint/250;
        $self->{'VIGOR'} = .01 if($self->{'VIGOR'} <= 0);
    }
    
    # check for actfail
    if( $room->{'ACTFAIL'} && (rand(100) < $room->{'ACTFAIL'}) ) {
        $self->log_error($room->{'ACTFAILMSG'});
        return 0;
    }

    if($self->{'TANGLED'}) {
        if(!$main::objs->{$self->{'TANGLED'}} || $self->{'ROOM'} != $main::objs->{$self->{'TANGLED'}}->{'ROOM'}) {
            delete $self->{'TANGLED'};
        }
        else {
            if(rand(10) < 2.75) {
               $self->struggle_free();
            }
            else {
                $self->room_sighttell("{3}$main::objs->{$self->{'TANGLED'}}->{'NAME'} gets in the way of $self->{'NAME'}'s actions.\n");
                $self->log_error("You cannot do that while you are caught in the web.");
                $self->log_hint('Type struggle to attempt to struggle free.');
            }
            return 0;
        }
       }
    
    # and last, but not least, take away hidden
    if($self->{'HIDDEN'}) {
        $self->{'HIDDEN'}--;
    }
    
    # or not.. handl epoison maybe
    if(  (defined($self->{'FX'}->{27}) || defined($self->{'FX'}->{38})) &&
         !$self->room()->{'SAFE'} ) { 
        my $dam = int rand($self->{'MAXH'} / 15);
        if($dam && !$self->{'NEWBIE'} && !$self->is_dead) {
            $self->log_append("{1}A horrible pain stabs through your intestines, inflicting {17}$dam {1}damage!\n");
            $self->room_sighttell("{1}A horrible pain stabs through {17}$self->{'NAME'}\'s {1}intestines, inflicting {17}$dam {1}damage!\n");
            $self->{'HP'} -= $dam;
            if($self->is_dead) {
                $self->die();
                return 0;
            }
        }
    }
    return 1;
}


sub spell_psiwind {
    my ($self, $victim, $acc) = @_;
    my $dam = int ( (rand(30)+10) * $acc/100 * $self->fuzz_pct_skill(12) * (1 - $victim->fuzz_pct_skill(19)) );
    
    $dam = 0 if($dam <= 0);
    $self->log_append("{5}You send gusting psionic winds at {16}$victim->{'NAME'},{5} inflicting $dam damage!\n");
    $self->room_sighttell("{5}$victim->{'NAME'} is struck by {16}$self->{'NAME'}'s{5} gusting psionic winds, inflicting $dam damage!\n");
    $victim->{'HP'} -= $dam;
    $self->{'EXPMEN'} += $self->{'LEV'} * 10;
    if($main::map->[$victim->{'ROOM'}]->{'EXITS'}) { 
        $victim->room_sighttell("{4}A gust of wind picks {16}$victim->{'NAME'} {4}up.\n");
        $victim->log_append("{4}A gust of wind picks you up.\n");
        $victim->ai_move(&rockobj::ai_suggest_move_random(undef, $main::map->[$victim->{'ROOM'}]->exits_hash));
    }

    return $dam;
}

sub spell_fortune {
    my ($self, $target) = @_;
    
    if(!$self->{'GIFT'}->{'PORTENTS'}) {
        $self->log_error('You have no idea how to do that!');
        return;
    }

    if(!$self->inv_has_rec(161)) {
        $self->log_error('You need a deck of taron cards to foretell the future.');
        return;
    }
    
    return if(!$self->can_do(0,0,50));

    my ($tname, $lval, $cap);
    
    if($target eq $self) {
        $tname = 'Your';
        $self->room_sighttell("{13}$self->{'NAME'} shuffles $self->{'PPOS'} deck of teron cards and attempts to tell $self->{'PPOS'} fortune.\n");
    }
    else {
        $tname = $target->{'NAME'}.'\'s';
        $self->room_sighttell("{13}$self->{'NAME'} shuffles $self->{'PPOS'} deck of teron cards and attempts to tell $target->{'NAME'} $target->{'PPOS'} fortune.\n");
    }
    
    $lval = int rand(101);
    
    $target->{'LUCK'} = $lval;
    
    $lval = int abs( $lval + ( (rand(100) < 50) ? -1 : 1 ) * rand(100 - $self->{'GIFT'}->{'PORTENTS'}) / 2.5 );
    
    $self->gifts_affect('PORTENTS');
    
    if($lval <= 15)   { $cap = "{6}A black wurm reversed is revealed.. $tname future looks horrible!\n";                              $target->{'VIGOR'} = 0.1;}
    elsif($lval <=25) { $cap = "{1}A blazing inferno reversed is revealed.. $tname outlook seems quite bad.\n";                       $target->{'VIGOR'} = 0.2;}
    elsif($lval <=45) { $cap = "{7}A dark moon is revealed.. $tname future doesn't look good.\n";                                     $target->{'VIGOR'} = 0.3;}
    elsif($lval <=55) { $cap = "{4}A calm lake is revealed.. $tname future looks to be uncertain.\n";                                 $target->{'VIGOR'} = 0.4;}
    elsif($lval <=70) { $cap = "{11}A golden sun is revealed.. $tname future looks fairly good.\n";                                   $target->{'VIGOR'} = 0.5;}
    elsif($lval <=85) { $cap = "{17}A prancing unicorn is revealed.. $tname future looks very good.\n";                               $target->{'VIGOR'} = 0.6;}
    elsif($lval <=97) { $cap = "{17}A white wurm is revealed.. $tname future looks extremely bright.\n";                              $target->{'VIGOR'} = 0.7;}
    else              { $cap = "{13}A naked maiden is revealed.. $tname future appears full of prosperity and unparalled fortune.\n"; $target->{'VIGOR'} = 0.8;}
    
    $self->log_append($cap);
    
    return;
}

sub skill_rtrackscan {
    my $self = shift;
    # BANK 0, ID 0
    return if(!$self->can_do(0, 0, 10));

    if(!$self->skill_has(0)) {
        $self->log_error("The tracks all look the same to you!..Mmm..Mud pie!");
        return;
    }

    $self->log_append($main::map->[$self->{'ROOM'}]->tracks_rlist($self));
}

sub skill_trackscan {
    my $self = shift;
    # BANK 0, ID 1
    return if(!$self->can_do(0, 0, 10));

    if(!$self->skill_has(1)) {
        $self->log_error("The tracks all look the same to you!..Mmm..Mud pie!");
        return;
    }

    $self->log_append($main::map->[$self->{'ROOM'}]->tracks_list($self));
}

sub skill_decapitate {
    my ($self, $victim) = @_;
    # BANK 0, ID 2
    if(!$self->skill_has(2)) {
        $self->log_error("You don't know how to decapitate stuff.");
        return;
    }

    return if(!$self->can_do(0,0,10));

    if(rand(1) > $self->fuzz_pct_skill(9)) {
        $self->attack_player($victim, 1);
        return;
    }
    $self->hdecapitate($victim);
}

sub hdecapitate {
    my ($self, $victim) = @_;
    $victim->room_sighttell("{1}$self->{'NAME'} hefts his axe up high, and decapitates $victim->{'NAME'} with one mighty swing.\n");
    $victim->log_append("{1}$self->{'NAME'} hefts his axe up high, and decapitates you with one mighty swing.\n");
    $victim->{'HP'}=-1;
    if ($victim->{'TYPE'} >= 1 || ($victim->can_be_lifted($self) && $self->can_lift($victim))) {
        $victim->die($self);
    } else {
        $victim->room_sighttell("{14}$victim->{'NAME'} {4}grows to replace the missing head.\n");
    }
}

sub htemporal {
    my ($self, $victim) = @_;

    $victim->room_sighttell("{15}Doyos {2}points his trident at {15}$victim->{'NAME'} {2}and unleashes a blast of {12}green temporal energy{2}.\n");
    $victim->log_appendline("{15}Doyos {2}points his trident at you and unleashes a blast of {12}green temporal energy{2}.");
    if($victim->aprl_rec_scan(608)) {
        $victim->room_sighttell("{13}The particles inside $victim->{'NAME'}'s {15}cracked hourglass {13}swarm violently into the top half, deflecting the blast.\n");
        $victim->log_appendline("{13}The particles inside your {15}cracked hourglass{15} swarm violently into the top half, deflecting the blast.");
    } else {
        $victim->room_sighttell("{12}A vicious {14}temporal bubble {12}surrounds $victim->{'NAME'}, aging $victim->{'PPRO'} thousands of years and reducing $victim->{'PPRO'} to dust.\n");
        $victim->log_appendline("{12}A vicious {14}temporal bubble {12}surrounds you, aging you thousands of years and reducing you to dust.");
        $victim->{'HP'} = -1;
        $victim->die($self);
    }
}

sub hcrystallize {
    my ($self, $victim) = @_;
    return if($self->{'ROOM'} != $victim->{'ROOM'});
    return if($self->{'HP'} <= 0);
    $victim->log_append("{5}A beam of pink energy lances from the $self->{'NAME'}\'s sole eye and strikes you squarely in the chest!\n");
    $victim->room_sighttell("{5}A beam of pink energy lances from the $self->{'NAME'}\'s sole eye and strikes $victim->{'NAME'} squarely in the chest!\n");
    
    $victim->log_append("{3}Your body is slowly crystallizing.\n");
    my $dontdoagain = $victim->{'FX'}->{'46'};
    $victim->effect_add(46);
	$victim->{'FX'}->{'46'}=time + 60*4;
    return 0 if($dontdoagain);
    
	$victim->delay_log_append(120, "{3}Your mouth is sealed over by crystals!\n");
    $main::eventman->enqueue(120, sub { my $a = shift; $a->effect_add(26); $a->{'FX'}->{'26'}=time + 60*2; }, $victim, 46);
    $victim->delay_log_append(180, "{3}You become crystallized!\n");
    $main::eventman->enqueue(180, sub { my $a = shift; $a->effect_add(6); $a->{'FX'}->{'6'}=time + 60; }, $victim, 46);

#    $victim->delay_log_append(60, "{3}Your body is slowly crystallizing.\n");
#    $main::eventman->enqueue(120, sub { my $a = shift; $a->effect_add(46); $a->{'FX'}->{'46'}=time + 60*3; }, $victim, 46);
#    $victim->delay_log_append(180, "{3}Your mouth is sealed over by crystals!\n");
#    $main::eventman->enqueue(180, sub { my $a = shift; $a->effect_add(26); $a->{'FX'}->{'26'}=time + 60*2; }, $victim, 46);
#    $victim->delay_log_append(240, "{3}You become crystallized!\n");
#    $main::eventman->enqueue(240, sub { my $a = shift; $a->effect_add(6); $a->{'FX'}->{'6'}=time + 60; }, $victim, 46);
}

sub spell_fuse {
    # MICH STOLE MELD CODE HAHHA
    my ($self, $caster) = @_;

    #i THINK 1 26 is the next free one
    if(!$caster->skill_has(58)) {
        $caster->log_error('You are uneducated in the skills of fusing.');
        return 0;
    }

    my $effy = $main::FUSE_EFFECT_LOOKUP{$self->{'REC'}};
    if(!defined($effy)) {
        $caster->log_error("You can only meld raw materials to yourself!");
        return 0;
    }

    return 0 if(!$caster->can_do(40, 0, 10));

    $caster->log_append("{12}You {2}fuse the $self->{'NAME'} to your body.\n");
    $caster->room_sighttell("{12}$caster->{'NAME'} {2}fuses the $self->{'NAME'} to $caster->{'PPOS'} body.\n");
    $caster->effect_add($effy);
    $self->obj_dissolve; # bye bye item.
    return 1;
}

1;
