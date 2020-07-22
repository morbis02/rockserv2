package rockobj;
use strict;
BEGIN { do 'const_stats.pm'; }
use rockunit;
use rockitem;
use Carp;
use Dillfrog::Mail;

sub get_real_level {
    my ($self) = @_;
    # returns $self's real level, based solely off of exp
    # (no effects, etc). What most of the game uses right now is
    # the player's effective level, which can change for temporary
    # periods of time (besides just raising stats using exp).

    # NOTE: this will actually vary slightly from the calculated
    #       "stats_update" level calculation, even if you have
    #       no effects. But it will be very, very close. And about as
    #       accurate as one can get when using this for determining
    #       how much experience someone should receive.

    my $total = 0;

    for (my $i=6; $i<=22; ++$i) {
        $total += $self->{'EXP'}->[$i]**(1/3);
    }

    return int($total / 17);
}

sub compare_items {
    # itema and itemb can be either strings or objects. strings will
    # be resolved..
    my ($self, $itema, $itemb) = @_;
    
    if (!$self->skill_has(16)) {
        $self->log_error("You have no clue how to appraise objects.");
        $self->log_hint("You can enroll in a course at the academy that will teach you this skill.");
        return;
    }
    my $success;
    
    ($success, $itema) = $self->inv_cgetobj($itema, 0, $self->inv_objs(), $self->room()->inv_iobjs());
    if ($success != 1) {
        $self->log_error("Could not identify first item to compare.");
        $self->log_append($itema);
        return;
    }
    
    ($success, $itemb) = $self->inv_cgetobj($itemb, 0, $self->inv_objs(), $self->room()->inv_iobjs());
    if ($success != 1) {
        $self->log_error("Could not identify second item to compare.");
        $self->log_append($itemb);
        return;
    }
    
    # okay, we've identified items a and b. let's compare.
    if ($itema eq $itemb) {
        $self->log_error("That is the same item.");
    } else {
        return unless $self->can_do(0,5,10);
        my @relative_desc = ('{4}weaker', '{3}the same', '{1}stronger');
        my $rel_wc = 1 + ($itema->{'WC'} <=> $itemb->{'WC'});
        my $rel_ac = 1 + ($itema->{'AC'} <=> $itemb->{'AC'});
        my $rel_val = 1 + ($itema->{'VAL'} <=> $itemb->{'VAL'});
        $self->room_sighttell("{7}$self->{'NAME'} skillfully compares {17}$itema->{'NAME'}\{7} to {17}$itemb->{'NAME'}\.\n");
        my @notes;
        push @notes , "\{7}WC is $relative_desc[$rel_wc]\{7}";
        push @notes , "\{7}AC is $relative_desc[$rel_ac]\{7}" if $itemb->{'ATYPE'} && $itema->{'ATYPE'};
        push @notes , "\{7}value is $relative_desc[$rel_val]\{7}";
        $self->log_append("{7}The {17}$itema->{'NAME'}\{7}\'s ".join(', ', @notes[0..@notes-2]).", and $notes[@notes-1] compared to {17}$itemb->{'NAME'}\.\n");
    }
    
}

sub describe_pos_relative_to {
    # returns string description of my position, relative to $obj
    my ($self, $obj) = @_;
    
    my $cby = &main::obj_lookup($self->{'CONTAINEDBY'});
    
    return "" unless $cby; # no container? that sucks, but we better not crash. only rooms shouldn't have containers.
    
    if ($obj eq $self) {
        return "you";
    } elsif ($self->{'CONTAINEDBY'} == $obj->{'CONTAINEDBY'}) {
        return "on the floor";
    } elsif ($cby->{'TYPE'} == -1) {
        # i'm held by a room
        return "in $cby->{'NAME'}";
    } else {
        my $rel_name_pos = $cby eq $obj ? "your" : "$cby->{'NAME'}\'s";
        my $rel_name = $cby eq $obj ? "you" : "$cby->{'NAME'}";
        
        # i'm held by a player/npc/item
        if ($self->{'WORN'}) {
            return "worn on $rel_name_pos $self->{'ATYPE'}";
        } elsif ($self->{'EQD'}) {
            return "wielded by $rel_name";
        } elsif (ref($cby) eq 'store') {
            return "selling for ".(int $self->{'VAL'}* $cby->{'MARKUP'})." cryl";
        } else {
            return "in $rel_name_pos inventory";
        }
    }
    
    return "";
}

sub has_minstats {
   # IMPORTANT:: THIS FUNCTION IS CHEAP.
   # IT EXPECTS ALL STRINGS PASSED TO IT TO BE IN
   # THE FORM OF "A >= B". That is, it's always greater thn or equal to.
   # this can change.. but that's not how it currently is! Do not be misled!
   
   my ($self, $minstat_str) = @_;
   
   $minstat_str =~ s/^ +//g;
   $minstat_str =~ s/ +$//g;
   
   return 1 unless $minstat_str; # if no requirements, we meet them! low expectations are what we excel at!
   
   my @statreqs = $minstat_str =~
    m{
        ([A-Z]+ | \d+)

        [^A-Z0-9]+   

        (\d+)
    }xg;

	for(my $i=0; $i<@statreqs; $i+=2) {
    	if($self->{'STAT'}->[$main::parr{$statreqs[$i]}] < $statreqs[$i+1]) {
        	return 0;
    	}
	}
	
	return 1;
}

sub pickpocket {
	return 1;
	}

sub is_on_same_plane_as {
    my ($self, $obj) = @_;
	# Returns true if $self and $obj are both located on the same plane.
	return $main::map->[$self->{'ROOM'}]->{'M'} == $main::map->[$obj->{'ROOM'}]->{'M'};
}

#sub min {
#    return $_[0] > $_[1] ? $_[1] : $_[0];
#}
#sub max {
#    return $_[0] > $_[1] ? $_[0] : $_[1];
#}
#sub log_spellcheck_for_item {
#    # Logs spellcheck results for room $room. If no room is passed,
#	# then the player's current room is used. Note that $room is an object,
#	# not an integer.
#	#
#	# Syntax: $self->log_spellcheck_for_room([$silent_if_ok, [$room_object]]);
#    my ($self, $silent_if_ok, $room) = @_;
#    $room ||= $main::map->[$self->{'ROOM'}];
#    my $msg = &main::get_spellcheck_str($room->{'NAME'}." ".$room->desc_get());
#	return if !$msg && $silent_if_ok;
#	$self->log_append("{3}Spell-checking objid $room->{'OBJID'} (room $room->{'ROOM'}, rec $room->{'REC'}):\n" . ($msg || "    {2}<< NO ERRORS FOUND >>\n"));
#}


#Ghaleon says, "had 11250 in vault stolen from shadow, then logged out directly at new turns (well few mins after) with 11777 left over and they went in with what i already had"

# $_[0]->store_turns(3);
sub store_turns {
    my ($self, $turn_count, $quiet) = @_;
	
	# Tries storing $turn_count turns. If none are specified, then
	# we store all we've got!

	$turn_count ||= $self->{'T'};   # default to all our turns
	$turn_count = int abs $turn_count;
	
	$turn_count = min($self->{'T'}, $turn_count);

	$turn_count = min($turn_count, $main::max_turns_storable - $self->{'TURNS_STORED'});
	$self->{'TURNS_STORED'} += $turn_count;
	$self->{'T'} -= $turn_count;

    unless ($quiet) {
        $self->log_append("{14}$turn_count {4}of your turns are secreted into your temporal vault.\n");
        $self->room_sighttell("{14}$turn_count {4}of {14}$self->{'NAME'}\'s {4}turns are secreted into $self->{'PPOS'} temporal vault.\n");
	}
}

sub is_in_same_room_as_monolith {
    my ($self, $keyword) = @_;
	# Returns true if i am in same room as monolith with the particular keyword.
	return substr($main::map->[$self->{'ROOM'}]->{'MONOLITH'}, 0, length($keyword)) eq $keyword;
}
sub race_owns_monolith {
    my ($self, $keyword) = @_;
	# Returns true if race owns the monolith with the particular keyword.
	return $main::rock_stats{$keyword}==$self->{'RACE'};
}

sub list_stored_turns {
    my ($self) = @_;
	my $turn_count = int $self->{'TURNS_STORED'};
	$self->log_append("{17}$turn_count {7}of your turns are stored in your temporal vault.\n");
}

sub unstore_turns {
    my ($self, $turn_count) = @_;
	
	unless ( $self->race_owns_monolith('monolith_temporal') && $self->{'SOLDIER'} && $self->is_in_same_room_as_monolith("monolith_temporal")) {
	    $self->log_error("You don't know how to channel the Temporal Monolith.");
		$self->log_hint("You must be a soldier of a race who controls the Temporal Monolith, and in the same room as the monolith.");
		return;
	}

	# Tries storing $turn_count turns. If none are specified, then
	# we draw all we've got!

	$turn_count ||= $self->{'TURNS_STORED'};   # default to all our turns
	$turn_count = int abs $turn_count;
	
	$turn_count = $self->{'TURNS_STORED'} if $turn_count > $self->{'TURNS_STORED'};
	
	if ($turn_count > 0) {
		$self->{'TURNS_STORED'} -= $turn_count;
		$self->{'T'} += $turn_count;

    	$self->log_append("{4}You draw {14}$turn_count {4}of your turns back from your temporal vault.\n");
    	$self->room_sighttell("{14}$self->{'NAME'} {4}draws {14}$turn_count {4}of $self->{'PPOS'} turns back from $self->{'PPOS'} temporal vault.\n");
	} else {
	    $self->log_error("You don't have any turns stored.");
		$self->log_hint("Turn-secretion is performed automatically every turn-gifting when your race owns the Temporal Monolith.");
	}
}


sub level_penalty
{
    my ($self, $level) = @_;
    #level=how many levels to decrease

    $level = $self->{'LEV'} - $level;
    if($level < 10) {$level = 10;}
    #level now = destined level
    $self->log_append("{3}<<  You feel smaller -- and no cake will save you!  >>\n");
    while($self->{'LEV'} > $level) { $self->stats_update(); for (my $n=6; $n<=22; $n++) { $self->{'EXP'}->[$n] *= .98; } }
    $self->{'EXPPHY'} = 0;
    $self->{'EXPMEN'} = 0;
}

sub simple_inv_cgetobj {
    my $self = shift;
    my $victim_name = shift;
    my $min_obj_type = shift;

    my ($success, $victim) = $self->inv_cgetobj($victim_name, $min_obj_type, @_);
    if ($success != 1) {
        $self->log_append($victim);
        return undef;
    }
    
    return $victim;
}


sub do_chaos {
    my ($self, $cmd) = @_;
    
    return unless $self->can_cause_chaos();
    #if(!$self->{'ADMIN'}){return;}

    &main::rock_shout(undef, "{17}#### $self->{'NAME'} used {16}$cmd\n", 1);
    
    if ($cmd =~ /^graffiti\s+(.+)$/i) {
        my $room_desc = $1;
        
        my $color = $self->{'PENCOLOR'} || 11;
        $self->room_sighttell("{14}$self->{'NAME'} scribbles about the room with $self->{'PPOS'} $main::numtocolor{$color} crayon.\n");
        $self->log_append("{14}You've scribbled the room with your $main::numtocolor{$color} crayon.\n");
        
        $self->room->{'GRAFFITI'} = "{$color}" .ucfirst(&main::text_filter($room_desc));
    } elsif ($cmd =~ /^khakify/i) {
        return unless $self->can_do($self->{'MAXM'}, 0, 0);
        $main::world_of_khaki ^= 1;
        my $desc = $main::world_of_khaki ? 'khakified' : 'de-khakified';
        $self->log_append("{14}You have $desc the world!\n");
        $self->room_sighttell("{14}$self->{'NAME'} has $desc the world!\n");
        
    } elsif ($cmd =~ /^immortal/i) {
        return unless $self->can_do($self->{'MAXM'}/20, 0, 0);
        $self->{'IMMORTAL'}=abs($self->{'IMMORTAL'}-1);
        $self->log_append("{2}Immortality turned $main::onoff[$_[0]->{'IMMORTAL'}]\n");
        $self->room_sighttell("{14}$self->{'NAME'} has switched $self->{'PPOS'} immortality $main::onoff[$_[0]->{'IMMORTAL'}]\{14}!\n");
    } elsif ($cmd =~ /^brainwash/i) {
        return unless $self->can_do($self->{'MAXM'}*2/3, 0, 0);
        $self->log_append("{3}Scrub-a-dub-dub goes Mr. and Mrs. Brain!\n");
        my @washes = (
            "{6}You like rock. {4}There is no lag. {6}You will continue to play until Bill Clinton is re-elected. {4}You will enjoy playing.",
            "{6}You like cheese. {4}There is {1}no {4}car in a carrot. {6}Two plus three is ninety-nine. {4}Frogs smell really pleasing.",
            "{6}Plat likes colors. {4}A blob is half of a blobbo. {6}Showering is overrated. {4}You enjoy throwing away 6-pack rings without cutting them to be dolphin-safe.",
            "{6}A star does not cost a buck. {4}There is {1}no {4}car in a carrot. {6}Two plus three is ninety-nine. {4}Frogs smell really pleasing."
        );
        &main::rock_shout(undef, $washes[int rand @washes]."\n");
    } elsif ($cmd =~ /^invis/i) {
        $self->{'INVIS'}=abs($self->{'INVIS'}-1);
        $self->log_append("{2}Invisibility turned $main::onoff[$_[0]->{'INVIS'}]\n");
        $self->room_sighttell("{14}$self->{'NAME'} has switched $self->{'PPOS'} invisibility $main::onoff[$_[0]->{'INVIS'}]\{14}!\n");
    } elsif ($cmd =~ /^killol/i) {
        return unless $self->can_do($self->{'MAXM'}, 0, 0);
        
        # make sure it's a killol
        $main::objbase->[5] = sub { return(item->new('NOSAVE', 1, 'VAL', 16000, 'NAME','killol','DESC','This sword, adorned with glittering rubies is the perfect gift for anyone who wants to die..', 'WC', 1000)); };

$main::objbase->[6] = sub { return(store->new('NAME','store','DESC','It looks like a store to you.', 'CRYL', 1000000));
};
        
        $self->log_append("{14}A hands appears in your killol (HuH?)!\n");
        $self->room_sighttell("{14}A killol appears in {17}$self->{'NAME'}\'s {14}hands.\n");
        $self->item_spawn(5);
    } elsif ($cmd =~ /^mindvisit/i) {
        return unless $self->can_do($self->{'MAXM'}, 0, 0);
        $self->log_append("{14}You have mindvisited the world!\n");
        $self->room_sighttell("{14}$self->{'NAME'} has mindvisited the world!\n");
        foreach my $player (&main::get_players_logged_in()) {
            $player->effect_add(29) unless $player->effect_has(29);
        }
    } elsif ($cmd =~ /^turnsneeze/i) {
        return unless $self->can_do($self->{'MAXM'}, 0, 0);
        $self->action_do('sneeze');
        my $turns = int ($self->{'T'} / 2);
        $self->{'T'} -= $turns;
        
        $self->log_append("{14}You have sneezed {17}$turns {14}turns all about the realm, which multiply almost immediately!\n");
        $self->room_sighttell("{14}$self->{'NAME'} has sneezed {17}$turns {14}turns all about the realm, which multiply almost immediately!\n");
        foreach my $player (&main::get_players_logged_in()) {
            next if $player eq $self;
            next if $player->{'T'} > 100_000;
            $player->{'T'} += $turns;
            $player->log_append("{17}$self->{'NAME'}\'s {14}turn-laden snot has become part of your chronological self.\n");
        }
    }elsif ($cmd =~ /^crylsneeze/i) {
        return unless $self->can_do($self->{'MAXM'}, 0, 0);
        $self->action_do('sneeze');
        my $cryl = int ($self->{'CRYL'} / 2);
        $self->{'CRYL'} -= $cryl;
        
        $self->log_append("{14}You have sneezed {17}$cryl {14}cryl all about the realm, which multiply almost immediately!\n");
        $self->room_sighttell("{14}$self->{'NAME'} has sneezed {17}$cryl {14}cryl all about the realm, which multiply almost immediately!\n");
        foreach my $player (&main::get_players_logged_in()) {
            next if $player eq $self;
            next if $player->{'cryl'} > 100000;
            $player->{'CRYL'} += $cryl;
            $player->log_append("{17}$self->{'NAME'}\'s {14}cryl-laden snot has become part of your economicalogical self.\n");
        }
    } 
	
	elsif ($cmd =~ /^transport\s+(.+)/i) {
        my $victim_name = lc $1;
        
            if ($self->{'GAME'}) {
                $self->log_error("Can't do that - you're in a subgame!");
                return;
            }

        if ($victim_name eq 'all') {
            return unless $self->can_do($self->{'MAXM'}, 0, $self->{'T'}/3);
            my @all_players = sort { int(rand(3))-1 } &main::get_players_logged_in();
            my $max_players = 4;
            foreach my $player (@all_players) {
                next if $player->{'GAME'};
                next if $player eq $self;
                return if $self->{'RACE'} != $player->{'RACE'} && $self->cant_aggress_against($player);
                $self->user_transport($player);
                last if --$max_players <= 0;
            }
            $self->make_tired(20);
        } else {
            my $victim = $self->uid_resolve($victim_name) or return;
            return if $self->{'RACE'} != $victim->{'RACE'} && $self->log_cant_aggress_against($victim);
            if ($victim->{'GAME'}) {
                $self->log_error("Can't do that - they're in a subgame!");
                return;
            }
            return unless $self->can_do($self->{'MAXM'}, 0, 0);
            $self->user_transport($victim);
            $self->make_tired(10);
        }
    } elsif ($cmd =~ /^decap[^ ]*\s+(.+)/i) {
        my $victim_name = lc $1;
        
        my $victim = $self->simple_inv_cgetobj($victim_name, 0, $self->room()->inv_objs())
                or return;
                
        return if $self->log_cant_aggress_against($victim);
        
        my $mana_req = $victim->{'TYPE'}==1 ? $self->{'MAXM'}/2 : $self->{'MAXM'}/20;
        return unless $self->can_do($mana_req, 0, 0);
        $self->hdecapitate($victim);
    } elsif ($cmd =~ /^effect[^ ]*(?:\s+#?(\d+))?/i) {
        my $effect = $1;
        $effect = int rand @$main::effectbase unless length($effect);
        $effect = abs int $effect;
        
        if (!$main::effectbase->[$effect]) {
            $self->log_error("Effect #$effect does not exist! Pick a number between 0 and ".@$main::effectbase);
            return;
        }
        
        return unless $self->can_do($self->{'MAXM'}/5, 0, 0);
        $self->effect_add($effect);
        $self->log_append("{3}It is soooo effectitious.\n");
    } elsif ($cmd =~ /^normalize(?:\s+(.+))?/i) {
        my $victim_name = $1;
        
        my $victim = $self;
        
        if ($victim_name) {
            $victim = $self->simple_inv_cgetobj($victim_name, 0, $self->room()->inv_objs())
                or return;
        }

        return unless $self->can_do($self->{'MAXM'}/20, 0, 0);
        
#        my $whose_first = $victim eq $self ? 'your' : $victim->{'NAME'} . "'s";
#        my $whose_third = $victim eq $self ? $self->{'PPOS'} : $victim->{'NAME'} . "'s";
        
        $self->log_append("{14}You have normalized ".($self eq $victim ? 'yourself' : $victim->{'NAME'})."!\n");
        $self->room_sighttell("{14}$self->{'NAME'} has normalized ".($self eq $victim ? $self->{'PPOS'}.'self' : $victim->{'NAME'})."!\n");
        $victim->effect_end_all();
######################################################################        
# goto
# fan tasstick
# skill
    } elsif ($cmd =~ /^goto\s+(.+)/i) {
        my $victim_name = lc $1;
        
        my $victim = $self->uid_resolve($victim_name) or return;
                    if ($victim->{'GAME'}) {
        
        $self->log_error("Can't do that - they're in a subgame!");
            return;
        }

        return unless $self->can_do($self->{'MAXM'}/3, 0, 0);
        $self->teleport($victim->{'ROOM'});
        
        $self->make_tired(5);
        ####################################
        # ADD MORE HERE
        ##############################
    } elsif ($cmd =~ /^nullity/i) {
        return unless $self->can_do($self->{'MAXM'}/5, 0, 0);
        $self->teleport(0);
    } elsif ($cmd =~ /^courseturbo/i) {
        return unless $self->can_do($self->{'MAXM'}/5, 0, 0);
        my @courses = keys %{$self->{'CRS'}};
        if (!@courses) {
            $self->log_error("You're not in any courses! Try enrolling in some first!");
            return;
        }
        
        while (@courses = keys %{$self->{'CRS'}}) {
            foreach my $k (@courses) { $self->course_update($k); }
        }
            
        $self->log_append("{17}Speed reading never felt so fast! You're quick!\n");
       $self->course_inv();
    } elsif ($cmd =~ /^nonewb/i) {
        if ($self->{'NEWBIE'}) {
            delete $self->{'NEWBIE'};
            $self->log_append("{3}Okay, you're not quite a newbie now.. for a while.\n");
        } else {
            $self->log_error("You already aren't a newbie!");
        }
    } else {
        $self->log_error("That is an unknown CHAOS command! Make sure you typed it correctly.");
    }

}

sub begin_armageddon {
    my $self = shift;
    
    if ($main::rock_stats{'armageddon_started_by_race'}) {
        $self->log_error("Armageddon has already begun!");
    } elsif (!$main::rock_stats{'armageddon_is_possible'}) {
        $self->log_error("Armageddon isn't even possible yet - monoliths need to be captured and full control maintained.");
    } elsif ($main::rock_stats{'armageddon_is_possible'} != $self->{'RACE'}) {
        $self->log_error("The $main::races[$main::rock_stats{'armageddon_is_possible'}] race has control, not you.");
    } elsif (!$self->{'GENERAL'}) {
        $self->log_error("Only the General can begin Armageddon.");

    } else {
        $main::rock_stats{'armageddon_started_by_race'} = abs int $self->{'RACE'};
        &main::rock_shout(undef, <<END_CAP);
{3}/---================================================---\
{3}(               {17}ARMAGEDDON HAS BEGUN                  {3}(
{3}\---================================================---/
{3}   >
{3}   >  {7}The {17}$main::races[$main::rock_stats{'armageddon_started_by_race'}] {7}race has harnessed the 
{3}   >  {7}power of the monoliths, causing a period of biased
{3}   >  {7}control. Some would say {11}CHAOS{7}. Other people
{3}   >  {7}probably wouldn't say anything, because they're
{3}   >  {7}a tad bit confused.
{3}   >
{3}   >  {7}One thing's for sure, though:
{3}   >
{3}   >    ===> {7}There is no turning back! {3}<===
{3}   >
{3}/---================================================---\
{3}(  (   (   (   (   (   (   (   (   (   (   (   (   (   ( 
{3}\------------------------------------------------------/
END_CAP

    }
}

sub can_cause_chaos {
    my ($self, $quiet) = @_;
    
    return 1 if $self->{'ADMIN'};
   
    if (!$main::rock_stats{'armageddon_is_possible'}) {
        $self->log_error("Armageddon isn't possible yet; help your race capture and maintain control of the monoliths first.") unless $quiet;
        return 0;
    } elsif (!$main::rock_stats{'armageddon_started_by_race'}) {
        $self->log_error("Armageddon is possible, but has not begun. Hurry up! Tell your General to begin armageddon, before someone takes your monoliths!") unless $quiet;
        return 0;
    } elsif ($main::rock_stats{'armageddon_started_by_race'} != $self->{'RACE'}) {
        $self->log_error("Your race doesn't control the monoliths. So you can't cause chaos.") unless $quiet;
        return 0;
    } elsif (!$self->{'SOLDIER'}) {
        $self->log_error("Only soldiers can cause chaos.") unless $quiet;
        return 0;
    } elsif ($self->{'SOLDIER'} > (time - 60*60*24*14)) {
        my $soldier_days = int((time - $self->{'SOLDIER'}) / 60/60/24);
        $self->log_error("You must be a soldier for at least 2 weeks in order to qualify.") unless $quiet;
        return 0;
    }
    
    return 1;
}
sub soft_add_effect {
    my ($self, $effect) = @_;
    $effect = abs int $effect;
    if (!$main::effectbase->[$effect]) {
        $_[0]->log_error("Effect number $_[1] does not exist.");
        return;
    }
    
    $self->effect_add(int $_[1]);
    $self->log_append("{4}O{14}k{4}.\n");
}








sub afk {
  my $self = shift;
  if($self->{'AFK'}) {
    delete $self->{'AFK'};
    $self->log_append("{16}You are no longer marked as being away from your keyboard.\n");
  } else {
    $self->{'AFK'}=1;
    $self->log_append("{16}You are marked as being away from your keyboard.\n");
  }
  return;
}
sub get_custom_biorythm {
	
	my $self = shift;
	
	my $race = "$main::racestats[$self->{'RACE'}]->[0]-$self->{'NAME'}";
	my $kmec = $self->{'CKMEC'};
	my $ksoc = $self->{'CKSOC'};
	my $kmed = $self->{'CKMED'};
	my $kcom = $self->{'CKCOM'};
	my $moff = $self->{'CMOFF'};
	my $mdef = $self->{'CMDEF'};
	my $mele = $self->{'CMELE'};
	my $capp = $self->{'CCAPP'};
	my $catt = $self->{'CCATT'};
	my $aupp = $self->{'CAUPP'};
	my $alow = $self->{'CALOW'};
	my $supp = $self->{'CSUPP'};
	my $slow = $self->{'CSLOW'};
	my $dphy = $self->{'CDPHY'};
	my $dene = $self->{'CDENE'};
	my $dmen = $self->{'CDMEN'};
	my $mmen = $self->{'CMMEN'};
	
	my $cap = undef;
	$cap .= sprintf("\n{40}{17}RACE: {$self->{'RACE'}}%6s\n", $race);		
    $cap .= "{40}{13}KNO             MAJ            DEF\n";
    $cap .= sprintf("{17}{14}%3d{17} Mechanical  {17}{14}%3d{17} Offensive  {17}{14}%3d{17} Physical\n", $kmec, $moff, $dphy);
    $cap .= sprintf("{17}{14}%3d{17} Social      {17}{14}%3d{17} Defensive  {17}{14}%3d{17} Energy\n", $ksoc, $mdef, $dene);
    $cap .= sprintf("{17}{14}%3d{17} Medical     {17}{14}%3d{17} Elemental  {17}{14}%3d{17} Mental\n", $kmed, $mele, $dmen);
    $cap .= sprintf("{17}{14}%3d{17} Combat      {17}{14}%3d{17} Mental\n", $kcom, $mmen);
    $cap .= "{13}CHA             AGI  STR\n";
    $cap .= sprintf("{17}{14}%3d{17} Appearance  {17}{14}%3d{17} {14}%3d{17}  Upper Body\n", $capp, $aupp, $supp);
    $cap .= sprintf("{17}{14}%3d{17} Attitude    {17}{14}%3d{17} {14}%3d{17}  Lower Body\n", $catt, $alow, $slow);
    $self->log_append($cap.'{41}');
    return;


	
}


sub get_biorythm {
	
	my $self = shift;
	
	my $race = $main::racestats[$self->{'RACE'}]->[0];
	my $kmec = int($main::racestats[$self->{'RACE'}]->[6]);
	my $ksoc = int($main::racestats[$self->{'RACE'}]->[7]);
	my $kmed = int($main::racestats[$self->{'RACE'}]->[8]);
	my $kcom = int($main::racestats[$self->{'RACE'}]->[9]);
	my $moff = int($main::racestats[$self->{'RACE'}]->[10]);
	my $mdef = int($main::racestats[$self->{'RACE'}]->[11]);
	my $mele = int($main::racestats[$self->{'RACE'}]->[12]);
	my $capp = int($main::racestats[$self->{'RACE'}]->[13]);
	my $catt = int($main::racestats[$self->{'RACE'}]->[14]);
	my $aupp = int($main::racestats[$self->{'RACE'}]->[15]);
	my $alow = int($main::racestats[$self->{'RACE'}]->[16]);
	my $supp = int($main::racestats[$self->{'RACE'}]->[17]);
	my $slow = int($main::racestats[$self->{'RACE'}]->[18]);
	my $dphy = int($main::racestats[$self->{'RACE'}]->[19]);
	my $dene = int($main::racestats[$self->{'RACE'}]->[20]);
	my $dmen = int($main::racestats[$self->{'RACE'}]->[21]);
	my $mmen = int($main::racestats[$self->{'RACE'}]->[22]);
	
	my $cap = undef;
	$cap .= sprintf("\n{40}{17}RACE: {$self->{'RACE'}}%6s\n", $race);		
    $cap .= "{40}{13}KNO             MAJ            DEF\n";
    $cap .= sprintf("{17}{14}%3d{17} Mechanical  {17}{14}%3d{17} Offensive  {17}{14}%3d{17} Physical\n", $kmec, $moff, $dphy);
    $cap .= sprintf("{17}{14}%3d{17} Social      {17}{14}%3d{17} Defensive  {17}{14}%3d{17} Energy\n", $ksoc, $mdef, $dene);
    $cap .= sprintf("{17}{14}%3d{17} Medical     {17}{14}%3d{17} Elemental  {17}{14}%3d{17} Mental\n", $kmed, $mele, $dmen);
    $cap .= sprintf("{17}{14}%3d{17} Combat      {17}{14}%3d{17} Mental\n", $kcom, $mmen);
    $cap .= "{13}CHA             AGI  STR\n";
    $cap .= sprintf("{17}{14}%3d{17} Appearance  {17}{14}%3d{17} {14}%3d{17}  Upper Body\n", $capp, $aupp, $supp);
    $cap .= sprintf("{17}{14}%3d{17} Attitude    {17}{14}%3d{17} {14}%3d{17}  Lower Body\n", $catt, $alow, $slow);
    $self->log_append($cap.'{41}');
    return;

	
}

sub inventory_update {
	my $self = shift;
	my $obj;
	
	if(!$self->{'CAN_UPINV'}){return;}
	$self->cmd_do("remove all");
	$self->effect_end_all();
	#$self->skill_del(2);
		foreach $obj ($self->inv_objs) { 
			#if(!$obj->{'UNIQUE'}) {
		
			my $item = $self->item_spawn_forced($obj->{'REC'});
			#$self->log_append("Fixing $item->{'NAME'}\n");
			#$item->{'WC'} = $obj->{'WC'};
			#$item->{'AC'} = $obj->{'AC'};
			#$item->{'VAL'} = $obj->{'VAL'};
			#$item->{'VOL'} = $obj->{'VOL'};
			$item->{'INVIS'} = $obj->{'INVIS'};
			$item->{'HIDDEN'} = $obj->{'HIDDEN'};
			$item->{'MINLEV'} = $obj->{'MINLEV'};			
			#if(!$obj->{'MINLEV'}) {	$item->{'MINLEV'} = int ($self->{'LEV'}*.7); }
			#elsif($obj->{'MINLEV'} > ($self->{'LEV'}-40)){$item->{'MINLEV'} = int ($self->{'LEV'}*.7); }
			#else {$item->{'MINLEV'} = $obj->{'MINLEV'}; }
			
			$obj->obj_dissolve();
			
			#}
			
		 }
		 
		$self->cmd_do("wear all");
		
		return;
}
#################

sub enlist_soldier {
	my ($self, $targ) = @_;
	my $targ = ref($targ) ? $targ : $self->uid_resolve($targ);
	if($self->{'GENERAL'}){
		if(!$targ->{'SOLDIER'}){
			if(!$targ->{'PACIFIST'} && ($targ->{'LEV'} >= 350) && lc(($targ->{'VOTING4'}) == lc($self->{'NAME'})) ){
				$targ->{'SOLDIER'} = time;
				&main::rock_shout(undef, "{16}$self->{'NAME'} {12}has enlisted {16}$targ->{'NAME'} {12}into the army, gotta love the draft!\n");
				$targ->{'ENLISTED'} = $self->{'NAME'};
			}
		}
	}
}

sub awol {
	my $self = shift;
	if($self->{'ENLISTED'}){
		$self->{'SOLDIER'}=0;
		$self->{'ENLISTED'}=0;
		$self->{'REPU'}--;
		&main::rock_shout(undef, "{16}$self->{'NAME'} {12}has gone AWOL, find them and kill them.\n");
	}
}

sub get_exp_needed {
  my $self = shift;
  my $cap;
  $self->stats_update();
  my $sarr = $self->{'STAT'}; 
  $cap .= "{40}{13}KNO                     MAJ                     DEF\n";
  $cap .= sprintf("{12}%8s{17} Mech     [KMEC] {12}%8s {17}Offensive [MOFF] {12}%8s{17} Physical [DPHY]\n", int($self->exp_need(6)), int($self->exp_need(10)), int($self->exp_need(19)));
  $cap .= sprintf("{12}%8s{17} Social   [KSOC] {12}%8s {17}Defensive [MDEF] {12}%8s{17} Energy   [DENE]\n", int($self->exp_need(7)), int($self->exp_need(11)), int($self->exp_need(20)));
  $cap .= sprintf("{12}%8s{17} Medical  [KMED] {12}%8s {17}Elemental [MELE] {12}%8s{17} Mental   [DMEN]\n", int($self->exp_need(8)), int($self->exp_need(12)), int($self->exp_need(21)));
  $cap .= sprintf("{12}%8s{17} Combat   [KCOM] {12}%8s {17}Mental [MMEN]\n", int($self->exp_need(9)),int($self->exp_need(22)));
  $cap .= "{13}CHA                     AGI     STR\n";
  $cap .= sprintf("{12}%8s{17} Appear   [CAPP] {12}%8s {12}%8s{17} Upper [AUPP] [SUPP]\n", int($self->exp_need(13)), int($self->exp_need(15)), int($self->exp_need(17)));
  $cap .= sprintf("{12}%8s{17} Attitude [CATT] {12}%8s {12}%8s{17} Lower [ALOW] [SLOW]\n{41}", int($self->exp_need(14)), int($self->exp_need(16)), int($self->exp_need(18)));
  $self->log_append("$cap\n");
}


sub equipment_stat_raise (stat, amt) {
	# raises STAT by amount AMT
	my ($self, $stat, $amt, $silent) = @_;
	my $level_modified = $self->aprl_rec_scan(1248);
	if(!$level_modified){
		$self->cmd_do("raise $stat $amt");
		return;}
	
	if (lc($stat) eq 'auto') {  
		if($self->{'LEV'}<1000){
			$self->exp_cycle();
		}
		
		if($self->{'LEV'}>=1000){
			$self->log_error("You should have a good understanding of the game, raise your own stats now."); 
		}
	return(1); }
	
	if (!$stat && !$amt) {
	    $self->log_append($self->aprl_rec_scan(1248)->get_stats_raiselist());
		$self->log_error("Syntax: upgrade <stat abbreviation> <max levels to raise>");
		$level_modified->{'BASEH'}=int ( ($level_modified->{'STAT'}->[DEF]*.4 + $level_modified->{'STAT'}->[AGI]*.3 
                      + $level_modified->{'STAT'}->[KNO]*.2 + $level_modified->{'STAT'}->[MDEF]*.09 + $level_modified->{'STAT'}->[CHA]*.15
                      + $level_modified->{'STAT'}->[STR]*.12) * 5 ) + 2;
        $level_modified->stats_update();
        $self->stats_update();
		return(1);
    }
	
	$stat = uc $stat; 
	my $sname = $stat;
	$amt = int $amt;
	
	$amt = 1 if $amt < 1;
	$amt = 1290 if $amt > 1290;
	
	
	if( ($stat>=6 && $stat<=22) || defined($main::parr{$stat})) {
    	 
	     $stat = $main::parr{$stat} || int $stat;
		 
	   
		$self->log_append("Attempting to raise stats on $level_modified->{'NAME'}.\n");
    	 if($level_modified->{'EXP'}->[$stat] >= 2146689000) {
             $self->log_append("{1}You cannot raise your $sname any further.\n");
             return(0);
    	 }
    	 
    	 if($self->{'EXP'}->[$stat] != 2146689000) {
             $self->log_append("{1}You cannot raise you $sname implant until your base stat is maxed.\n");
             $self->log_append("{1}Your $sname will be raised for you.\n");
             $self->cmd_do("upgrade $sname $amt");
             return(0);
    	 }
    	 
		 my $rby=0;
		 if($self->{'LEV'} >= 1100  && $self->skill_has(63))
		 {
    	 for (my $n=1; $n<=$amt; $n++) { 
        	 last if($level_modified->{'EXP'}->[$stat] >= 2146689000);
        	 my $e = $self->exp_need($stat);
        	 # transfer exp
        	 if ($e <= $self->{$main::eclass[$stat]}) { 
        		 $level_modified->{'EXP'}->[$stat] += $level_modified->exp_need($stat, 1);
        		 $self->{$main::eclass[$stat]}-=$e;
        		 $rby++;
        	 } else {
			     $n=$amt;
			 }
    	 }
	 	}
	 	else
	 	{
		 for (my $n=1; $n<=$amt; $n++) { 
        	 last if($level_modified->{'EXP'}->[$stat] >= 1000000000);
        	 my $e = $self->exp_need($stat);
        	 # transfer exp
        	 if ($e <= $self->{$main::eclass[$stat]}) { 
        		 $level_modified->{'EXP'}->[$stat] += $level_modified->exp_need($stat, 1);
        		 $self->{$main::eclass[$stat]}-=$e;
        		 $rby++;
        	 } else {
			     $n=$amt;
			 }
    	 }	
	 	}
		 
    	 if (!$rby) {
		     $self->log_append("{1}You need more experience in order to raise your $sname.\n") unless $silent;
			 return(0);
	     } elsif ($rby < $amt) {
		     $self->log_append("{12}Your $sname could only be raised by $rby.\n") unless $silent;
			 $self->stats_update();
		 } else { 
		     $self->log_append("{15}Your $sname has been raised by $rby.\n") unless $silent;
			 $self->stats_update();
		 }
	} else {
		$self->log_error("Syntax: raise <stat abbreviation> <max levels to raise>") unless $silent;
	    return(0);
    }
    $self->cmd_do("upgrade");
	return(1);
  }



sub find_commands {
    my $self = shift;
    
    my %cmds;
    #map { $cmds{$_}=1; } keys(%$main::adminbase_mult), keys(%$main::cmdbase_mult), keys(%$main::cmdbase_sing), keys(%$main::cmdbase_obj);
    map { $cmds{$_}=1; } keys(%$main::cmdbase_mult), keys(%$main::cmdbase_sing), keys(%$main::cmdbase_obj);
    #map { delete $cmds{$main::cmdbase_ali->{$_} || $_}; } @commands;
    
    my $dontshow = "qwerty, approve, armarr, autoequip, awho, ban, bmap, caarp, chrm, cmap, compress, crex, crow, crpl, dbmap, delete portal, deny, desc, descs, destroy, dmap, emus, flatten, getrec, liquify, map, mkaid, mkcor, mkeye, mkhand, mkwri, msgs clear, msgs more, mute, new portal, newhelp, noadmin, nomob, nullify, objs, page, pdescs, pset, push, refs, remark, remcode, remrefs, ritems, room, stock, stupify, terrain, title, tmap, voice, weight";
    
    map { delete $cmds{$_} } split(/, /, $dontshow);
    
    $self->log_append("{16}The following is a list of player commands: {6}".join(", ", sort keys %cmds).".\n");
   
}

sub admin_commands {
    my $self = shift;
	    
    my %cmds;
    map { $cmds{$_}=1; } keys(%$main::cmdbase_mult), keys(%$main::cmdbase_sing), keys(%$main::adminbase_mult), keys(%$main::adminbase_sing), keys(%$main::cmdbase_obj);
    #map { $cmds{$_}=1; } keys(%$main::cmdbase_mult), keys(%$main::cmdbase_sing), keys(%$main::cmdbase_obj);
    #map { delete $cmds{$main::cmdbase_ali->{$_} || $_}; } @commands;
    
    my $dontshow  = ""; #= "activate, approve, armarr, auction, autoequip, autoloot, awho, ban, bash, blow, bmap, caarp, canattack, cast, chrm, close, cmap, compress, crex, crow, crpl, cwho all, dance, dbmap, decapitate, delete portal, deny, desc, descs, destroy, detab, dig, dmap, emus, enroll list, flatten, getrec, ignite, liquify, map, mkaid, mkcor, mkeye, mkhand, mkwri, msgs clear, msgs more, mute, new portal, newhelp, noadmin, nomob, nullify, objs, open, page, pdescs, pick, prompt format, pset, push, read, refs, remark, remcode, remrefs, ritems, room, silence auctions, silence deaths, silence gossips, silence logins, silence logouts, smash, stock, stupify, terrain, title, tmap, touch, voice, weight, wind";
    
    map { delete $cmds{$_} } split(/, /, $dontshow);
    
    $self->log_append("{16}The following is a list of all commands: {6}".join(", ", sort keys %cmds).".\n");
   
}

#use LWP::Simple;
#use LWP::Protocol::https;
#use LWP::UserAgent;
#use Math::Round qw(:all);
#use Math::BigInt;

#sub bandwidth_usage {
#	my $self = shift;
#	my $ua = new LWP::UserAgent;
#	$ua->timeout(120);
#	my $url = 'https://vpscp.supremevps.com:5656/api/client/command.php?key=JE3XR-BXS8E-W0FSI&hash=abff30438d4cab3283cbaf469c8610761ddc5739&action=status&bw=true';
#
#	my $request = new HTTP::Request('GET', $url);
#	my $response = $ua->request($request);
#	my $content = $response->content();
#	my $start = "<bw>";
#	my $end  = "</bw>";
#   my $startmem = "<mem>";
#   my $endmem = "</mem>";
#	my $line = $content;
#   my $linemem = $content;
#	$line =~ /$start(.*?)$end/;
#   $linemem =~ /$startmem(.*?)$endmem/;
#	my $matched = $1;
#   my $matchedmem = $1;
#	
#	my @bandwidth = split /,/, $matched;
#	my $bw1 = $bandwidth[0];
#	my $bw2 = $bandwidth[1]; #BYTES USED
#	my $bw3 = $bandwidth[2];
#	my $bw4 = $bandwidth[3];
#   
#   my @memory = split /,/, $matchedmem;
#	my $mem1 = $memory[0];
#	my $mem2 = $memory[1]; #BYTES USED
#	my $mem3 = $memory[2];
#	my $mem4 = $memory[3];
#   
#
#	use bignum;
#	my $MBused = ($bw2 / (1024 * 1024));
#   my $MBusedmem = ($mem2 / (1024 * 1024));
#	#$self->log_append("$MBused MB used.\n");
#	my $percentage = ($bw2/$bw1);
#   my $percentagemem = ($mem2/$mem1);
#	$percentage = ($percentage+0)->bstr();
#   $percentagemem = ($percentagemem+0)->bstr();
#	#my $result = nearest(.0001, $percentage);
#	$percentage = substr( $percentage , 0 , 7);
#   $percentagemem = substr( $percentagemem , 0 , 7);
#	$main::rock_stats{'bandwidth'} = $percentage;
#   $main::rock_stats{'memory'} = $percentagemem;
#	$self->log_append("$MBused MB used. $percentage\% used.\n");
#   $self->log_append("$MBusedmem MB used. $percentagemem\% used.\n");
#
#}

sub who_racial_all {
 my $self = shift;
 my ($player, $time, $cap, $n, @npcOBJS);
 
 foreach my $key (keys(%main::monoliths)) { 
     if ($main::rock_stats{$key}==$self->{'RACE'} && defined($main::objs->{$main::monolithstoobjid{$key}})) {
          push(@npcOBJS, $main::objs->{$main::monolithstoobjid{$key}});
     }
 }
my $i_logged_in_recently = $self->logged_in_recently() && !$self->{'ADMIN'} && !$self->{'GENERAL'};
my $playerHP = $self->{'HP'} / $self->{'MAXH'} * 100;
 foreach $player ((sort keys(%{$main::activeuids})), @npcOBJS) {
    $player = ref($player)?$player:&main::obj_lookup($main::activeuids->{$player});
      next if($player eq $self);
      my $am_ignored = defined($player->{'IGNORE'}->{$self->{'NAME'}});
      my $am_ignoring = defined($self->{'IGNORE'}->{$player->{'NAME'}});
      if(
         #$player->{'ROCKDEV'} ||
         $self->{'REPU'} < -1 ||
         $i_logged_in_recently ||
         $am_ignored ||
         $am_ignoring ||
         ($player->{'LEV'} > $self->{'LEV'} * 1.5)) {
          my $smalldesc;
          if ($am_ignoring) {
              my $smalldesc ||= '{1}***    IGNORED    ***';
          } elsif ($am_ignored) {
              $smalldesc ||= '{1}***  IGNORING YOU ***';
          } 
          $cap .= sprintf('{2}%18s %s' . "\n", $player->{'NAME'}, $smalldesc);
      } else {
          $playerHP = $player->{'HP'} / $player->{'MAXH'} * 100;
          $cap .= sprintf('%3d {2}%15s {4}({17}%3d{4}) {4}({17}%3d{4}) {16}%15s %s%3d%% {17}%04d'."\n", $player->{'RACE'}, $player->{'NAME'}, $player->{'LEV'}, $player->get_real_level(), &commify(int($player->{'EXPTODAY'})), $playerHP<30?'{1}':'{6}', $playerHP, $player->{'T'} );
      }
 } 
$self->log_append("{2}\nRace          Name   Lev   RLev            Exp    HP Turns{17}\n".$cap.'{41}');
 
 return;
}

1;
