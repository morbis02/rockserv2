package rockobj;
use strict;
BEGIN { do 'const_stats.pm'; }
use rockunit;
use rockitem;
use Carp;
use rockdb;
use rock_prefs;

sub execute_create_exit_trigger {
    my $self = shift;
    if($self->{'TRIGIMMEDREPLY'}) { $self->room_tell($self->{'TRIGIMMEDREPLY'}."\n"); }
    if($self->{'TRIGDELAY'}) {
        $main::eventman->enqueue(int($self->{'TRIGDELAY'}), \&rockobj::execute_create_exit_immediate_trigger, $self, @_)
	       unless $self->{'TRIGGER_IN_PROGRESS'};
		$self->{'TRIGGER_IN_PROGRESS'} = 1;
    } else {
	    $self->execute_create_exit_immediate_trigger(@_);
    }
}

sub execute_remove_exit_immediate_trigger {
    # Instead of CREATING the exit here, we wall it. If $use_opposite_exit is true
	# then we wall the exit in the opposing room. 
	my ($self, $use_opposite_exit) = @_;
	
	# Which direction are we killing?
	my $exit = $use_opposite_exit ? $main::diroppmap{$self->{'TRIGEXIT'}} : $self->{'TRIGEXIT'};

    # Which room are we killing it in?
	my $room = $main::map->[$self->{'ROOM'}];
	$room = $main::map->[$room->{$self->{'TRIGEXIT'}}->[0]]  if $use_opposite_exit;

    # kill kill kill!
	$room->{$exit}->[1]=1; # DONT allow entry
	$room->room_sighttell("The $main::dirernmap{$exit} exit disappears.\n");
	$room->exits_update();
}

sub room {
    # Returns the room object of the room i'm currently in.
    # Note that we could recursively call the container to get the ultimate
    # room I'm in (since the container can travel and not update my own room).
    
    my $self = shift;
    return $main::map->[$self->{'ROOM'}];
    
}

sub execute_create_exit_immediate_trigger {
	my ($self, $use_opposite_exit) = @_;
	if($self->{'TRIGDELAYREPLY'}) { $self->room_tell($self->{'TRIGDELAYREPLY'}."\n"); }
	
	# Which direction are we killing?
	my $exit = $use_opposite_exit ? $main::diroppmap{$self->{'TRIGEXIT'}} : $self->{'TRIGEXIT'};

    # Which room are we killing it in?
	my $room = $main::map->[$self->{'ROOM'}];
	$room = $main::map->[$room->{$self->{'TRIGEXIT'}}->[0]]  if $use_opposite_exit;

    return unless $room->{$exit}->[0];
	$room->{$exit}->[1]=0; # allow entry
	$room->{$exit}->[2]=$self->{'TRIGEXITCNT'}||0; # used to be 1
	$room->set_exit_disappear_after($exit, $self->{'TRIGEXITHIDEAFTER'}) if $self->{'TRIGEXITHIDEAFTER'};
    $room->exits_update();
	delete $self->{'TRIGGER_IN_PROGRESS'};
	return;
}

sub is_my_trigexit_open {
    # Returns true if the exit I would normally open, is open right now;
	# else returns false.
	my $self = shift;
	return $main::map->[$self->{'ROOM'}]->{$self->{'TRIGEXIT'}}->[1] != 1; # 1 == wall; -1 is invis, 0 is open
}

sub get_login_time {
    # returns the time I logged in, or undef
	my ($self) = @_;
#	$self->log_append("LT: $main::activeuids->{lc $self->{'NAME'}}\n");
	return $main::uidmap{lc $self->{'NAME'}};
}

sub user_support {
	my ($self, $uid) = @_;
	
	# When called, this object attempts to vote for $uid, changing
	# its vote where necessary.
	
	$uid = lc($uid);
	
	if( ($self->{'TYPE'}!=1) || ($self->{'RACE'}<1) || ($self->{'RACE'}>5) ) { $self->log_error("You cannot vote until you are one of the pure races."); return; } 
	
	if($self->{'LEV'}<45) { $self->log_error("You're not old enough to vote yet. Fear not, 45 levels of practice doesn't take a lifetime."); return; }
	
	if(!$uid) { 
    	if (my $votee = $main::general_votes{lc($self->{'NAME'})}) { 
    	    (undef, $votee) = unpack('LA*', $votee);
    	    $self->log_append("{6}You are currently in support of {16}$votee\{6}.\n");
    	} else {
    	    $self->log_error("You are not currently in support of anyone.");
			$self->log_hint("Type support <user> to support them.");
    	}
    	return;
	}

	if (my $targ = $self->uid_resolve($uid)) {
	    # If the user is in the game, find reasons not to let user vote for them.
		# If user isn't in the game, the uid_resolve call will auto-log an error.
		
#    	if ($targ->{'NAME'} eq $self->{'NAME'}) {
#		    $self->log_error("You cannot vote for yourself!");
		if ($targ->{'RACE'} != $self->{'RACE'}) {
		    $self->log_error("You are not of the same race as $targ->{'NAME'}. Traitor!");
#		} elsif ($targ->{'ADMIN'}) {
#		    $self->log_error("Admins have more to worry about than the quest for the eternal power of their race.");
		} elsif (!$targ->{'SOLDIER'}) {
		    $self->log_error("Only soldiers may be elected to General status.");
        } elsif (!$targ->pref_get('general eligibility')) {
		    $self->log_error("$targ->{'NAME'} is not currently running for General. Maybe you should talk $targ->{'PPRO'} into running.");
		} elsif ($targ->{'LEV'}<80) {
		    $self->log_error("Sorry, $targ->{'NAME'} needs ".(80-$targ->{'LEV'})." more levels of experience before being eligible for a position as General.");
		} elsif ($self ne $targ && $self->is_likely_alt($targ)) {
		    $self->log_error("$targ->{'NAME'} is a potential alt of yours, so you may not vote for $targ->{'PPRO'}.");
		} else {
    	    # Success -- log the new vote!
			$main::general_votes{lc($self->{'NAME'})} = pack('LA*', $targ->{'RACE'}, $uid);
    	    $self->log_append("{2}You throw your support behind {12}$targ->{'NAME'}\'s{2} campaign for power.\n");
	    }
		return;
	}
}

sub on_ignite { 
	# Called when a user tries to "ignite <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $igniter) = @_;
	$igniter->log_error("Fool! That will never explode!");
	return;
}

sub on_read { 
	# Called when a user tries to "read <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $reader) = @_;
	$reader->log_error("Eh? $self->{'NAME'} is more boring to read than a cereal box!");
	return;
}

sub on_open { 
	# Called when a user tries to "open <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $opener) = @_;
	$opener->log_error("You tug and tug, but $self->{'NAME'} refuses to be opened!");
	return;
}

sub on_close { 
	# Called when a user tries to "close <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $closer) = @_;
	$closer->log_error("You cannot close that!");
	return;
}

sub on_activate { 
	# Called when a user tries to "activate <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $activator) = @_;
	$activator->log_error("Fool! That will never activate!");
	return;
}

sub on_blow { 
	# Called when a user tries to "blow <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $blower) = @_;
	$blower->log_error("You want to blow that? Are you training your lungs for the planar olympics or what?");
	return;
}

sub on_detab { 
	# Called when a user tries to "detab <itemname>" in the game.
	# Overridden by some other objects in rockitem.
	my ($self, $detabber) = @_;
	$detabber->log_error("You see nothing to detab on the $self->{'NAME'}.");
	return;
}

sub wander_off() {
   # Makes me (hopefully a NPC) seem to wander off, by destroying
   # the object. Currently used by the 
   # Mugg raider code to disperse mobs after some time.
   #
 
   my $self = shift;
   $self->room_sighttell("{12}$self->{'NAME'} {2}wanders away.\n");
   $self->dissolve_allsubs();
   return;
}

sub stats_allto {
	# Sets all of my stats to that of a level $min_lev object.
	# If $max_lev is passed, then my level (for all stats) is set to
	# somewhere between $min_lev and $max_lev, inclusive.
	my ($self, $min_lev, $max_lev) = @_;

	$min_lev = int $min_lev + int rand ($max_lev-$min_lev + 1) if $max_lev;

	use integer; # force integer math; faster
	for (my $n=6; $n<=22; $n++) {
    	$self->{'EXP'}->[$n] = int ($min_lev**3);
	}
	no integer;  # back to floating point/etc

	$self->stats_update;
	return;
}

sub min {
    # returns minimum value, given an array of data.
	return (sort { $a <=> $b } (@_))[0];
}

sub max {
    # returns maximum value, given an array of data.
	return (sort { $b <=> $a } (@_))[0];
}


sub on_hdigest {
	# Called after I have been eaten. Remember, $self is the thing being eaten,
	# not the thing doing the eating.
	#
	# If you want to make special code for your rockitem
	# objects, consider overriding the on_digest function instead.
  
	my ($self, $eater) = @_;
	
	if (ref($self) eq 'bodypart') {
	    $eater->log_error("You sick, sick person.");
	} elsif (!$self->{'DIGEST'}) { 
	    $eater->log_error("You would, but $self->{'NAME'} sure doesn't look tasty.");
	} elsif (!$eater->can_do(0,0,2)) { 
	    # Do nothing! 
	} else {
	    # it can be digested -- let's do it!
		
    	if($self->{'DRINK'}) {
        	$eater->log_append("{4}You take a sip of $self->{'NAME'}.\n") if $self->{'USES'};
        	$eater->room_sighttell("{4}$eater->{'NAME'} takes a sip of $self->{'NAME'}.\n");
    	} else {
        	if ($self->{'USES'}) { $eater->log_append("{3}You swallow down a piece of $self->{'NAME'}.\n"); }
        	$eater->room_sighttell("{3}$eater->{'NAME'} swallows down a piece of $self->{'NAME'}.\n");
    	}

    	$self->on_digest($eater);

    	
		# Give the eater his FX if this object is associated with one
    	$eater->effect_add($self->{'EATFX'}) if $self->{'EATFX'};
    	
		# Eater's health improves
		$eater->{'HP'} += $self->{'HP'}; $eater->stats_update;
		
        # Update my frog/grape content
    	$eater->{'FROGS'} += $self->{'FROGS'};
    	$eater->{'GRAPES'} += $self->{'GRAPES'};
    	my $salp = min($eater->{'FROGS'}, $eater->{'GRAPES'}); # salpiness is least of your frog/grape count.
    	$eater->{'SALP'} = max($eater->{'SALP'}, $salp);       # set salpiness to our new min, unless time has made my salp even higher.
		
    	if(--$self->{'USES'} <= 0) {
    		$eater->log_append("{2}You've finished the last of $self->{'NAME'}.\n");
    		delete $self->{'CRYL'};
    		$self->obj_dissolve;
    	}

        # if they died after eating me (hey, it could happen; consider where I had negative HP)
    	# make it happen
		$eater->die() if $eater->is_dead;
	}
}

sub salp {
	# Called when *I* am about to get salped (that is, the $salper requested to salp $victim).
	# Note that at this point, $salper might not be able to salp (see error logic below).

	my ($victim, $salper) = @_;

	if( ($salper->{'RACE'} != 4) && !$salper->skill_has(13) ){
    	$salper->log_error("Your kind is unable to produce such hideous slime.");
	} elsif($victim->is_dead) {
	    $salper->log_error("$victim->{'NAME'} is already dead.");
	} elsif($salper->log_cant_aggress_against($victim) || !$salper->can_do(0, int $salper->{'MAXH'}/5, 4)) {
	    # do nothing
	} elsif(!$salper->{'SALP'}) {
	    # Log attack for pvp info
        $salper->note_attack_against($victim); 

	    $salper->room_sighttell("{2}$salper->{'NAME'} attempts to force up some salp but nothing happens.\n");
		$salper->log_error("You attempt to force up some salp but nothing happens.");
	} elsif( $victim->{'TYPE'} == 1  ||  $victim->{'TYPE'} == 2){
	
	    # Log attack for pvp info
        $salper->note_attack_against($victim); 

    	# If an NPC or Player is being salped, then HP is taken away from them.
		my $dam = int ( ($salper->{'SALP'}*2.2 + rand($salper->{'SALP'}*2.5))
		                * rand(1.5)
						* ($salper->{'LEV'}/25 + 1)
					  );
    	
		if($dam > ($salper->{'LEV'}*6.7)) {
		    $dam = int ($salper->{'LEV'}*6.7 + rand(5));
		}
		
    	$salper->log_append("{15}You exert a slimy salp over $victim->{'NAME'}, causing $dam damage.\n");
    	$victim->log_append("{15}$salper->{'NAME'} exerts a slimy salp over you, causing $dam damage.\n");
    	$salper->room_sighttell("{15}$salper->{'NAME'} {5}exerts a slimy salp over {15}$victim->{'NAME'}.\n", $victim);
    	
	$victim->{'HP'} -= $dam;
    	
	if ($victim->is_dead()) { $victim->die($salper); }
    	elsif (!$victim->is_tired()) { $victim->attack_sing($salper, 1); }
  	    delete $salper->{'SALP'}; delete $salper->{'FROGS'}; delete $salper->{'GRAPES'};
		
	} else {
	    # If a non-{NPC, Player} is being salped, then we might just make the item disappear. 
    	$salper->log_append("{15}You exert a slimy salp over $victim->{'NAME'}.\n");
    	$victim->log_append("{15}$salper->{'NAME'} exerts a slimy salp over you.\n");
    	$salper->room_sighttell("{15}$salper->{'NAME'} {5}exerts a slimy salp over {15}$victim->{'NAME'}.\n", $victim);
    	if( $victim->can_be_salped_by($salper)
             &&
             ( ($salper->{'SALP'}**(1/2)) >= ($victim->{'MASS'}*$victim->{'VOL'}) )
           ) { 
        	$victim->log_append("{2}You dissolved..\n");
        	$victim->room_sighttell("{2}$victim->{'NAME'} is dissolved into a salpy puddle.\n");
        	$victim->obj_dissolve();
    	}
  	    delete $salper->{'SALP'}; delete $salper->{'FROGS'}; delete $salper->{'GRAPES'};
	}
	return;
}

sub can_be_salped_by {
    my ($self, $salper) = @_;
    confess "Must pass salper" unless $salper;
    return ( 
              $salper->can_lift($self) && $self->can_be_lifted($salper)
           ); 
}

sub hive_mind {
    # Sends message $cap to each Spectrite logged into the game,
	# as long as they don't have gossips turned off

    my ($self, $cap) = @_;
    
    if ($self->{'RACE'} != 2) {
	    $self->log_error("Only Spectrites can channel messages through The Eye.");
	} elsif ($self->pref_get('silence gossips')) {
        $self->log_error("Cannot use that channel if you have it silenced.");
    } else {
    	$cap = &main::text_filter_game($cap, $self);

    	if ($cap eq "") {
		    $self->log_error("Hive what?");
		} elsif (!$self->can_do(0,0,0)) {
		    # do nothing
		} else {
                    my $cmsg;
                if($self->pref_get('old-school hives')) {
                    $cmsg = censored_message->new_prefiltered("{12}$self->{'NAME'} ( {17}$self->{'LEV'} {12}): {6}$cap\n", $self);
                } else {
                    $cmsg = censored_message->new_prefiltered("{12}$self->{'NAME'} hives: {6}$cap\n", $self);
                }
    		$self->log_append($cmsg->get_explicit());
    		&main::rock_rshout($self, $cmsg, 'silence gossips');
		}
    }
	    
    return;
}


sub objids_register ($self, [dweap]){
    # Syntax: $player->objids_register($default_weapon_object);
	#
	# MAKE SURE YOU PASS IT A DWEAP IF THERE IS ONE
	# OTHERWISE IT COULD BE CLEARED FROM THE PLAYER.
	#
	# registers new objids for each of its objid'd items.
	
	my ($self, $dweap) = @_;

	$dweap = undef if ref($dweap) eq 'HASH';
	$dweap = fists->new(); # Temporary fix from a long time ago, so it doesn't matter whether $dweap is passed.
                           # If you remove this line, make sure that *EVERYTHING* calling this function passes
						   # dweap accordingly or else you're in deep trouble mister.

	my @update = ($self, $dweap, $self->inv_objs, $self->stk_objs);
	
	delete $self->{'WEAPON'};
	delete $self->{'CROBJID'};
	
	if($self->{'TANGLED'}  ||
	   $self->effect_has(46)  # stage one of crystallization
	    ) {
		
	    unless ($self->effect_has(6) && $self->{'FX'}->{'6'} > (time + 60)) {
		    $self->effect_add(6);     # paralyze those who logged off when they were tangled
			$self->log_error("You really shouldn't log off to escape paralyzation.");
		}
		delete $self->{'TANGLED'};
		$self->{'FX'}->{6} = time + 60*4; # 4x as painful
	}
	
	foreach my $i (@update) {
    
		next unless $i;

		# We've got problems if the item doesn't have a name -- delete and complain about it.
    	if(!$i->{'NAME'}) {
        	$self->inv_del($i); $self->stk_del($i);
        	&main::mail_send($main::rock_admin_email, "BUG objid_reg $self->{'NAME'}\'s inv.", "see topic\n");
        	next;
    	}

    	# If current item doesnt exist in main::objs, set up objid stuff.
    	if($main::objs->{$i->{'OBJID'}} ne $i) { 
        	my $had    = $self->inv_has($i) && ($dweap ne $i);
        	my $stkhad = $self->stk_has($i) && ($dweap ne $i);


        	$self->inv_del($i) if $had;     # delete obj from inventory..(since it uses objid stuff)
        	$self->stk_del($i) if $stkhad;  # delete obj from inventory..(since it uses objid stuff)

        	$main::highobj++;               # add one to highest object.

			$i->{'OBJID'}=$main::highobj;   # update i's objid.
        	$i->{'DONTDIE'}=1;              # checked by HashScan code
        	$main::objs->{$main::highobj}=$i; # map to objs.
        	delete $i->{'DONTDIE'};

			
        	if($had) {
			    confess "I shouldn't have had item $i; it's me!" if $i eq $self;
				
		    	$self->inv_add($i); # add obj to inventory w/new number

				# if item thinks it's equipped, make it so
				if($i->{'EQD'}){
			    	$self->{'WEAPON'}=$i->{'OBJID'};
				}
	    	}
			
			if($stkhad) {
			    $self->stk_add($i); # add obj to inventory w/new number
			}  

			delete $i->{'CROBJID'}; # nobody knows it's creator's objid anymore..
        	$i->objids_register;    # sub-register the items' items.
			
    	} else { # main::objs->{$i->objid} == $i
		    # NOTE: The following wouldnt be necessary if $dweap weren't new each and every call to this function (consider auctions and how they are called)
	    	$self->{'WEAPON'} = $i->{'OBJID'}
			    if $self->inv_has($i) && $i->{'EQD'}; 
		}
	}
	
	if($dweap) { $self->{'DWEAP'} = $dweap->{'OBJID'}; $dweap->{'CONTAINEDBY'}=$self->{'OBJID'}; }
	else { delete $self->{'DWEAP'}; }
	
	$self->inv_scan("Post Objids-Register");
	
	return;
}


sub stk_objs {
   # Returns array of objects in STocKed ("secured") inventory.
   
   my $self = shift;
   return(values(%{$self->{'STK'}}));
}

sub stk_objsnum {
   # Returns number of objects in stocked inventory..
   
   my $self = shift;
   return(scalar keys(%{$self->{'STK'}}));
}

sub stk_del {
    # Removes passed rockobjs from my *stocked* inventory.
	#
	# For example, $player->stk_del($object_a, $object_b) would remove
	# the rockobjs $object_a and $object_b from $player's stocked inventory.
	#
	# This does not actually destroy the object(s) themselves.
	#
	# Compare to inv_del.
	#
	
    my $self = shift;
    while (@_) {
	     delete $self->{'STK'}->{$_[0]->{'OBJID'}};  # item is no longer in our list
         delete $_[0]->{'CONTAINEDBY'};              # item no longer has known container
         shift;
    }
}

sub stk_has {
    # Returns nonzero value if $self has all passed objects in his/her *stocked* inventory.
    #
	# If no objects listed, returns true.
    #

	my ($self, $success) = (shift, 1);
    
	# caution: idiot crossing.
    if(!defined($self->{'STK'}) || (ref($self->{'STK'}) ne 'HASH') ) { return(0); }

    while (@_) {
       if(!$self->{'STK'}->{$_[0]->{'OBJID'}}) { $success = 0; }
       shift;
    }
	
    return $success;
}

sub stk_add {
    # Adds all passed objects to $self's *stocked* inventory.
	#
	# Will not error if you try adding an object that's already in $self's *stocked* inventory.
    
	my $self = shift;
    while (@_) {
          $self->{'STK'}->{$_[0]->{'OBJID'}}=$_[0]; # add to *stocked* inventory list
          $_[0]->{'ROOM'}=$self->{'ROOM'};          # ??? This is not re-set on stk_del. Looks like it might be evil.
          $_[0]->{'CONTAINEDBY'}=$self->{'OBJID'};  # tells object who it's contained by.
          shift;
    }
}

sub on_die {
    # Function is called after it is certain that the object has died.
	# Overridden in rockunit.pm
	#
	# Changing my HP here does NOT automatically determine that the fate
	# of $self is to live. But this could probably be added at a later time.
	#
	# Arguments passed are in the form of:
	#
	# my ($self, $killer) = @_;
	#
	# *** THE $killer VALUE MAY BE undef IF NO KILLER IS KNOWN ***
	#
}

sub user_beep {
    # Syntax: $player->beep($uid_to_beep, $message_to_send)
	#
	# Beeps user $uid_to_beep if they are in the game and not ignorant. Else
	# logs error messages to $player.
	#
	
	my ($self, $uid, $message) = @_;

	$message = &main::text_filter($message, $self);
	if(my $recip = $self->uid_resolve($uid)) {
        if (defined($self->{'FX'}->{'26'})) {
		    $self->log_append("{17}You don't have the means to communicate that way!\n"); 
		} elsif ($recip->pref_get('busy flag') && !$self->{'ADMIN'}) {
    	   $self->log_error("$recip->{'NAME'}\'s 'busy' flag is on. Try again at a later time.");
    	} elsif ($recip->{'IGNORE'}->{$self->{'NAME'}}) {
    	   $self->log_error("$recip->{'NAME'} is ignoring you; your beep will not go through.");
    	} elsif ($self->can_do()) { 
    	  $recip->log_append('{42}{42}{42}{16}'.($self->{'NICK'} || $self->{'NAME'})." {14}has beeped you! {17}$message\n");
    	  $self->log_append("{2}- $uid beeped -\n");
		}
	}
	return;
}

sub objid_resolve {
    my ($self, $objid) = @_;
    if($objid eq '') {
        $self->log_error("You must specify an object id");
        return undef;
    }
    
    $objid = int $objid;
    
    unless(defined($main::objs->{$objid})){
        $self->log_error("Object $objid does not exist.");
        return undef;
    }

    return $main::objs->{$objid};
}

sub uid_resolve {
    # Syntax: $player->uid_resolve($uid_to_resolve, $dont_log_errors)
	#
	# Tries looking up the corresponding object for $uid_to_resolve.
	#
	# If the user is logged into the game right now, returns that user's object.
	# else returns undef and logs error to $player (unless $dont_log_errors is set).
	#
	# *** NOTE: $uid_to_resolve can actually be an object. Objects resolve to themselves.
	
	my ($self, $uid, $quiet) = @_;
	
	return $uid if ref($uid); # poop out $uid if it's an object; objects resolve to themselves
	
    $uid = lc($uid);
    if (!$uid) { $self->log_error("Don't forget to specify a UserID.") unless $quiet; }
    elsif (!$main::activeuids->{$uid}) { $self->log_error("The user \"$uid\" is not logged in.") unless $quiet; }
    else {
        my $recip = &rockobj::obj_lookup($main::activeuids->{$uid});
        if($recip->{'SOCINVIS'} && !$self->{'ADMIN'}) { 
            $self->log_error("The user \"$uid\" is not logged in.") unless $quiet;
            return undef;
        } else {
            return $recip;
        }
    }
    return undef;
}


sub msg_tell {
    # Syntax: $obj->msg_tell($uid_or_obj, $message)
	#
	# Attempts to tell $message from $obj to $uid_or_obj
	
	my ($self, $uid, $message) = @_;
	
	if(my $recip = $self->uid_resolve($uid)) {
    	if (defined($self->{'FX'}->{'26'}) && !$self->{'ADMIN'}) {
    		$self->log_error("You currently lack the means to communicate that way. Bummer."); 
    		return 0;
    	}
    	
		
    	if (defined($recip->{'FX'}->{'25'}) && !$recip->{'ADMIN'}) {
    		$self->log_error("$recip->{'NAME'} cannot hear you right now.");
    	} elsif ($self->pref_get('busy flag') && !$self->{'ADMIN'}) {
    		$self->log_error("You cannot send private messages while your \"busy\" flag is on.");
    	} elsif ($recip->pref_get('busy flag') && !$self->{'ADMIN'}) {
    		$self->log_error("$recip->{'NAME'}\'s busy flag is on. Try sending the message at a later time.");
    	} elsif ($recip->{'IGNORE'}->{$self->{'NAME'}}) {
    		$self->log_error("$recip->{'NAME'} is ignoring you; your message will not go through.");
    	} elsif ($self->can_do()) {
            if($recip->{'CMD_WATCH'}) { &main::rock_shout(undef, "{16}>{6}> {7}Tell from $self->{'NAME'} to ({17}$recip->{'NAME'}\{7}): {12}[$message]\n", 1); }
            # $message = censored_message->new($message, $self)->get_for($recip);
            my $cmsg = censored_message->new($message, $self);
            $message = $cmsg->get_for($recip);
            $recip->log_append('{16}'.($self->{'NICK'} || $self->{'NAME'})." {14}tells you [privately]: {17}$message\n");
            if($self->pref_get('tell-echoing')) {
                my $message1 = $cmsg->get_explicit();
                $self->log_append("{2}You tell{16} $recip->{'NAME'} {2}[privately]: {7}$message1\n");
            } else {
                $self->log_append("{2}- private message sent to $recip->{'NAME'} -\n");
            }
            $recip->{'LASTTELL'}=$self->{'NAME'};
            return 1;
    	}
	}
	return 0;
}

sub logf_feedback {
    my ($self, $message, $v1, $v2) = @_;
    my $fb = multi_feedback->new($message, $self, $v1, $v2);
    
    $self->room_tell($fb->get_for_room());
    $self->log_append($fb->get_for_sender());
    return undef;
}

sub log_suspicious_activity {
    # Syntax: $obj->log_suspicious_activity($msg, $thresh)
	#
	# Logs an instance of suspicious activity, of type $msg (this is usually a desc
	# of the type of suspicious activity).
	#
	# Online admins are auto-notified when at least $thresh occurrences have
	# happened as a result of this activity.

    # This is used to note suspicious activity (aka, scriptiness)
    my ($self, $msg, $thresh) = @_; # thresh is min occurrences before we care; default 0 (first occurrance)
	
    # Non-players can't be suspicious.. they just can't!
    return unless $self->{'TYPE'} == 1;
    
	# this is bad code, but i'm drun...tired :-) 
	if ($self->{'SUSPICIOUS'}->{$msg} <= 0) {
	    $self->{'SUSPICIOUS'}->{$msg}--;
		if ($self->{'SUSPICIOUS'}->{$msg} <= -$thresh) {
		    $self->{'SUSPICIOUS'}->{$msg} = abs $self->{'SUSPICIOUS'}->{$msg};
  	        &main::rock_shout(undef, "{1}### SUSPICIOUS {17}$self->{'NAME'} (room $self->{'ROOM'}): {7}$msg\n", 1);
            &main::log_event("Suspicious", $msg, $self->{'UIN'});
		}
	} else {
	    $self->{'SUSPICIOUS'}->{$msg}++;
  	    &main::rock_shout(undef, "{1}### SUSPICIOUS {17}$self->{'NAME'} (room $self->{'ROOM'}): {7}$msg\n", 1);
        &main::log_event("Suspicious", $msg, $self->{'UIN'});
	}
}

sub get_suspicious_activity {
    # Syntax: $player->get_suspicious_activity();
	#
	# Returns a string detailing all suspicious activity (that has reached the threshold)
	# for this $player.
	#
	# If no suspicious activity is noticed for $player, undef is
	# returned.
	
    my $self = shift;
    my $msg = '';
	
	map { $msg .= "$_ (x".$self->{'SUSPICIOUS'}->{$_}.")\n" } grep { $self->{'SUSPICIOUS'}->{$_} > 0 } keys %{$self->{'SUSPICIOUS'}};
	
	my @funny_prefs = grep { $self->pref_get($_) } ('busy flag', 'silence shouts', 'silence gossips', 'silence logins', 'silence logouts', 'silence auctions');
	$msg .= "Enabling prefs: ".join(", ", @funny_prefs)."\n" if @funny_prefs;
	
	return $msg?"{2}---- {12}$self->{'NAME'} {2}-----\n$msg":undef;
}

#### ******** PLAT WAS HERE *********** --- Plat will continue beautifying the functions from here. Really.

sub uid_ignore {
	my ($self, $uid) = @_;
	
	$uid = lc($uid);
	
    $self->{'IGNORE'} ||= {};
    
	if (!$uid) { 
    	if (!$self->{'IGNORE'}) { $self->log_error("Syntax: ignore <username>"); }
    	else {
    	   my $cap = "{16}Users Currently Ignored {6}(ignore again to toggle):\n";
    	   foreach my $val (sort keys(%{$self->{'IGNORE'}})) {
        	  $cap .= '  {13}o {17}'.$val."\n";
    	   }
    	   $self->log_append($cap);
    	}
    	return; 
	} elsif (my $recip = $self->uid_resolve($uid)) {
    	if ($self->{'IGNORE'}->{$recip->{'NAME'}}) {
    		$self->log_append("{16}*** no longer ignoring {17}$recip->{'NAME'}\n");
    		delete $self->{'IGNORE'}->{$recip->{'NAME'}};
    	} elsif ($self eq $recip) {
            $self->log_error("You can't ignore yourself. There's no escape!");
    	} elsif (keys(%{$self->{'IGNORE'}}) >= 15) {
            $self->log_error("Sorry, you can only ignore up to 15 people at a time.");
            $self->log_hint("Try unignoring those you can tolerate. The syntax is the same as ignoring people (\"ignore <username>\").");
    	} else { 
    		# Ignore $recip
			$self->log_append("{16}*** ignoring {17}$recip->{'NAME'}\n");
    		$self->{'IGNORE'}->{$recip->{'NAME'}}=1;


			$self->log_suspicious_activity("Has ignored more than 10 users.")
	    		if (scalar(keys %{$self->{'IGNORE'}})) > 10;

			# Some people have scripts to ignore someone as soon as that person
			# enters the game. We'll note suspicion if this person was ignored
			# within 2 seconds of entering the game (give some time to lag)
			$self->log_suspicious_activity("Ignored user within 2 sec of game entry.")
	    		if (time - $main::uidmap{lc $recip->{'NAME'}}) <= 2;
    	}
	}
	return;
}


sub msg_echo {
	my ($self, $uid_or_obj, $message) = @_;
		
	if (my $recip = $self->uid_resolve($uid_or_obj)) {
    	$recip->log_append("{4}$message\n");
    	$self->log_append("{2}- private message {17}echoed{2} to $recip->{'NAME'} -\n");
	}
	return;
}

sub is_in_safe_room() {
    # returns true if i am in a safe room
    my $self = shift;
	return $main::map->[$self->{'ROOM'}]->{'SAFE'};
}
sub canLogoutOnTelDiscon {
	my ($self, $quiet) = @_;
	if ($main::map->[$self->{'ROOM'}]->{'HANGUP_DEATH'}) { 
    	    $self->log_error("You cannot exit the game from this room! (If you do, you'll die)")
	        	unless $quiet;
            return 0;
	} elsif ($main::map->[$self->{'ROOM'}]->{'NO_VOLUNTARY_LOGOUT'} ||
	    $main::map->[$self->{'ROOM'}]->{'NO_VOLUNTARY_LOGOFF'}) { 
            # There's really no difference between these - change the rooms' "_LOGOFF" to "_LOGOUT" later and you're set.
    	    $self->log_error("You cannot exit the game from this room!")
	    	unless $quiet;
    	return 0;
	} elsif ($self->is_in_safe_room()) {
           return 1; # safe room, can logout
	} elsif(  $main::noHangupDuringPvp && ($_ = (time - $self->{'PVPTIME'})) < 120 && !$self->{'GAME'}) { 
	    my $sec_left = 120 - $_;
    	$self->log_append("{14}** Cannot log off within {7}2 minutes{14} of PvPing ($sec_left sec left). **\n")
	        unless $quiet;
    	return 0;
	} elsif( ($_ = (time - $self->{'LAST_FRIENDLY_NPC_ATTACK'})) < 120 && !$self->{'GAME'}) { 
	    my $sec_left = 120 - $_;
    	$self->log_append("{14}** Cannot log off within {7}2 minutes{14} of attacking a friendly NPC ($sec_left sec left). **\n")
	        unless $quiet;
    	return 0;
	}
	return 1;
}

sub obj_logout {
  my $obj = shift;
  
  # Tell the room that we're definitely logging out.
  # IMPORTANT: This should go first, so room code has the first
  #            pick on the event. In fact, this could send the player
  #            to a different room, so don't cache it either.
  $obj->room()->on_player_logout($obj);

  if (my $deathMsg = $main::map->[$obj->{'ROOM'}]->{'HANGUP_DEATH'}) {
      if(!$obj->is_dead()) { 
          $obj->log_append("{1}$deathMsg\n");
          $obj->die();
      }
  }
  
  
  $obj->log_suspicious_activity("Gave something within 60 seconds before logging off.")
      if (time - $obj->{'LASTGIVE'}) < 60;
	  
  $obj->log_suspicious_activity("Received something within 60 seconds before logging off.")
      if (time - $obj->{'LASTRECEIVE'}) < 60;

  $obj->log_suspicious_activity("Dropped something within 60 seconds before logging off.")
      if (time - $obj->{'LASTDROP'}) < 60;

  delete $main::activeusers->{$obj->{'OBJID'}};
  delete $main::activeuids->{lc($obj->{'NAME'})};
  if($main::uidmap{lc($obj->{'NAME'})} && $obj->{'TYPE'}==1) { 
      # add to day's time online..
      # kill group info
      $obj->remove_from_all_groups();
      delete $obj->{'groupid'};
      
      $obj->{'TIMEOND'} += (time - $main::uidmap{lc($obj->{'NAME'})}) if $main::uidmap{lc $obj->{'NAME'}} > 100;
      $obj->up_general();
      if($obj->exp_restore_backup) { $obj->teleport($main::roomaliases{'arenahall'} || 0); }
      if($main::map->[$obj->{'ROOM'}]->{'LOGOFFTPORT'}) { $obj->teleport($main::roomaliases{lc($main::map->[$obj->{'ROOM'}]->{'LOGOFFTPORT'})} || 0); }
      $obj->obj_dump(1); # save if it's a character. 
      foreach my $ui (%main::obj_unique) {
        if( ($main::obj_unique{$ui} eq lc($obj->{'NAME'})) && !$obj->inv_has_rec($ui) && !$obj->stk_has_rec($ui)) {
          delete $main::obj_unique{$ui};
        }
      }

      if(!$obj->{'SOCINVIS'}) {
#        &main::rock_talkshout($obj, "{".(int (rand(8)+1))."}$obj->{'NAME'} {".(int (rand(8)+1))."}just disconnected from the game.\n", 'silence logouts');
          &main::rock_talkshout($obj, "{17}$obj->{'NAME'} {7}just disconnected from the game.\n", 'silence logouts');
          $obj->room_tell("{17}$obj->{'NAME'}\{7}\'s image detunes as $obj->{'PRO'} {17}exits{7} the realm.\n");
      } else {
          &main::rock_shout(undef, "{17}$obj->{'NAME'} {2}(invisible) {7}just disconnected from the game.\n", 1);
      }

      $main::objs->{$obj->{'CONTAINEDBY'}}->inv_del($obj); # get it out of the room
      $main::map->[0]->inv_add($obj); # and into..the void

      $obj->dissolve_allsubs; # dissolve'er all
      $main::map->[0]->cleanup_inactive;
      
       # check for dual characters (sneaky eh?)
      $main::dual_friend->on_logoff($obj->{'IP'}, $obj->{'NAME'});
      
      # log da logout
      $rockobj::auth_man->logMessage("R2", "LOU", $obj->{'UIN'}||$rockobj::auth_man->getUIN($obj->{'NAME'}), $obj->{'IP'});
 }  elsif ($obj->{'TYPE'} == 1) { $obj->dissolve_allsubs; }
    else { $obj->{'LOG'}=undef; }
  return;
}

sub dissolve_allsubs {
	my ($self, $i) = @_;
	
	foreach $i ($self->inv_objs, $self->stk_objs) { 
		if(ref($i)) { $i->dissolve_allsubs; } else { &main::mail_send($main::rock_admin_email, "R2: BUG! ($self->{'NAME'})", "Bug report from $self->{'NAME'}:\n\nReference $i ($i->{'NAME'}) unblessed.\n"); }
	}
	
	delete $self->{'CRYL'};
	$self->obj_dissolve;
	return;
}

sub race_statsto {
  # silent operation
  my ($self, $racenum) = @_;
  if (!$main::racestats[$racenum]) { return; }
  # set race
  $self->{'RACE'}=$racenum;
  # set exp
# plat changed so your exp is thrown in expmen/expphy instead; 2003-03-06 it was:
#  for (my $x=6; $x<=22; $x++) {
#    $self->{'EXP'}->[$x] = $main::racestats[$racenum]->[$x]**3 + 1;
#  }
   
  my $start_exp = 0;
  for (my $x=6; $x<=22; $x++) {
      $self->{'EXP'}->[$x] = 1;
      $start_exp += ($main::racestats[$racenum]->[$x])**3 + 1;
  }
  $self->exp_add($start_exp, 1); # add exp quietly

  $self->skills_racial_fix();
  $self->stats_update(); $self->stats_update();
  $self->{'HP'}=$self->{'MAXH'};
  $self->{'MA'}=$self->{'MAXM'};
  $self->log_append("{17}*** {16}All of your stats are set to level 1.\n{17}*** {16}BE SURE TO {11}RAISE THEM {16}as soon as possible, so you are able to perform well.\n");
  $self->log_hint("Type \"help raise\" for more information on raising stats.");
  return;
}

sub skills_racial_fix {
  my $self = shift;
  my ($skill, $key, $racenum);
  $racenum = $self->{'RACE'};
  # clear racial skills that do not transfer over.
  foreach $skill (@main::raceskills) { 
   if (!$main::racegifts[$racenum]->{$skill}) { delete $self->{'GIFT'}->{$skill}; }
  }
  # set up new racial gifts, if any.
  if($main::racegifts[$racenum]) { 
    foreach $key (keys(%{$main::racegifts[$racenum]})) {
       if($self->{'GIFT'}->{$key} < $main::racegifts[$racenum]->{$key}) {
         $self->{'GIFT'}->{$key} = $main::racegifts[$racenum]->{$key};
       }
    }
  }
  return;
}

sub gifts_affect (giftnames){
  my ($self, $gift) = shift;
  while(@_) {
    $gift = shift;
    if($self->{'GIFT'}->{$gift}) {
      $self->{'GIFT'}->{$gift}=$self->{'GIFT'}->{$gift} * 1.01 + .05;
      if($self->{'GIFT'}->{$gift}>=99) { $self->{'GIFT'}->{$gift}=99; }
    }
  }
  return;
}

sub cert_upcredits ( [ quiet mode] ) {
  use DB_File;
  my ($self, $quiet) = @_;
  my %uids;
  my $torockdir = "$main::base_code_dir/torock";
  tie %uids, "DB_File", "$torockdir/webmaster_uids.dbm", O_RDWR|O_CREAT, 0775, $DB_HASH or print "Cannot tie [webmaster_uids.dbm]: $!\n";
      $self->{'CREDIT'} += $uids{lc($self->{'NAME'})}; # transfer object to credit
      if(!$quiet || $uids{lc($self->{'NAME'})}) { 
         $self->log_append("{6}$uids{lc($self->{'NAME'})} have used your link since last time you checked.\nYou have a total of $self->{'CREDIT'} credits to your name. Type 'redeem' for redeeming options.\n"); 
      }
      $uids{lc($self->{'NAME'})}=0;# clear credit log
  untie(%uids); 
  return;
}


sub who {
    my $self = shift;
        
    my ($player, $time, $cap, $n);
    if($self->{'WEBACTIVE'}) { $self->web_who; return; }
    if(!$self->{'WEBACTIVE'} && !$self->{'ANSI'}) { $self->who2; return; }
    my $playercount = 0;
    foreach $player (sort keys(%{$main::activeuids})) {
        $player = &main::obj_lookup($main::activeuids->{$player});
        next if ($player->{'SOCINVIS'} );
        ++$playercount;
         
        next if (time - $player->{'@LCTI'}) > 60;
        my $wingColor = $main::wingmap[int ($player->{'LEV'}/50)] || '{13}#';
        $cap .=  sprintf ("\{%d\} \%16s $wingColor\%s%1s$wingColor %s",
            ($player->{'RACE'} % 18),
            $player->{'NAME'},
            $main::gendermap{$player->{'GENDER'}},
            $main::generalmap[$player->{'GENERAL'}] || $main::asteriskmap[$player->{'SOLDIER'} !=0] || 'o',
            $main::pkmap[$player->{'PKTIME'} && ((time-$player->{'PVPTIME'})<60*2)] || $main::badrepmap[$player->{'REPU'}<$main::badrepborder] || $main::goodrepmap[$player->{'REPU'}>$main::goodrepborder] || $main::afkmap[$player->{'AFK'}] || $main::adminmap[$player->{'ADMIN'}] || $main::developermap[$player->{'ROCKDEV'}!=0] || $main::newbiemap[$player->{'NEWBIE'}!=0] || '     ');

         if ($n) { $cap .= "\n"; } else { $cap .= ' '; }
         $n = abs($n-1);
    }
    if($n) { $cap .= " {1}oO {6}Rock: Crashed Plane{1} Oo\n"; }
    $cap .= "{41}{14}There are {5}$playercount {14}total players in the game right now.\n";
    $self->log_append("{40}{13}Users active within the last minute:\n".$cap.'{41}');
    return;
}

sub who_admin {
    my $self = shift;
        
    return $self->log_error("This is not for you. It never was for you.")
        if (!$self->{'ADMIN'} && !$self->{'ROCKDEV'} && !$self->{'OVERSEER'});
        
    my ($player, $time, $cap, $n);
    # $main::caarpmap[$self->{'OVERSEER'}!=0]
    foreach $player (sort keys(%{$main::activeuids})) {
        $player = &main::obj_lookup($main::activeuids->{$player});
        next if (!$player->{'ADMIN'} && !$player->{'ROCKDEV'} && !$player->{'OVERSEER'});
        $cap .=  sprintf ("{%d\}%20s %20s %20s\n", ((time - $player->{'@LCTI'}) > 60 ?7:17), $player->{'NAME'}, $main::adminmap[$player->{'ADMIN'}] || $main::developermap[$player->{'ROCKDEV'}!=0] || '{7}not staff', $main::caarpmap[$player->{'OVERSEER'}!=0]);
        $n++;
    }
    
    $cap .= "{41}{14}There are {5}$n {14}admins logged in. Gray names have been inactive.\n";
    $self->log_append("{40}{13}Staff Online:\n".$cap.'{41}');
    return;
}

sub who2 {
 my $self = shift;
 my ($player, $time, $cap, @race);
 if($self->{'WEBTEST'}) { $self->web_who; return; }
 my $playercount = 0;
 foreach $player (sort keys(%{$main::activeuids})) {
    $player = &main::obj_lookup($main::activeuids->{$player});
      next if($player->{'SOCINVIS'});
      ++$playercount;
      $race[$player->{'RACE'}].=$main::gendermap{$player->{'GENDER'}}.$player->{'NAME'}.' ';
      $cap = "$main::asteriskmap[$player->{'SOLDIER'} != 0]$main::adminmap[$player->{'ADMIN'}]$main::developermap[$player->{'ROCKDEV'}!=0]$main::newbiemap[$player->{'NEWBIE'}!=0]$main::afkmap[$player->{'AFK'}]";
      if($cap) { $race[$player->{'RACE'}] .= "{17}($cap\{17}) "; }
 }
 $cap = undef;
 for (my $n = 0; $n<=$#race; $n++) { 
   if($race[$n] && $main::races[$n]) { $cap .= sprintf("{12}%15s{17}: %s\n", $main::races[$n], $race[$n]); }
 }
 
 $cap .= "{14}There are {5}$playercount\{14} total players in the game right now.\n";
 $self->log_append($cap);
 return;
}

sub who_racial {
 my $self = shift;
 my ($player, $time, $cap, $n, @npcOBJS);
 
 foreach my $key (keys(%main::monoliths)) { 
     if ($main::rock_stats{$key}==$self->{'RACE'} && defined($main::objs->{$main::monolithstoobjid{$key}})) {
          push(@npcOBJS, $main::objs->{$main::monolithstoobjid{$key}});
     }
 }

 # We won't give them some privileges if they logged in recently. Admins get a free ride
 my $i_logged_in_recently = $self->logged_in_recently() && !$self->{'ADMIN'};


#mich - cleaned this up a bit
#mich - next two lines were added
my $playerHP = $self->{'HP'} / $self->{'MAXH'} * 100;
$cap .= sprintf('{2}%18s {4}({17}%3d{4}) {16}%20s %s%3d%% {17}%04d'."\n", $self->{'NAME'}, $self->{'LEV'}, substr($main::map->[$self->{'ROOM'}]->{'NAME'},0,20), $playerHP<30?'{1}':'{6}', $playerHP, $self->{'T'} );

 foreach $player ((sort keys(%{$main::activeuids})), @npcOBJS) {
    $player = ref($player)?$player:&main::obj_lookup($main::activeuids->{$player});
      next if($player->{'SOCINVIS'} || ($player->{'RACE'} != $self->{'RACE'}) || $player eq $self);
#mich - ignoring makes them reciprocally blocked from rwho viewing (you know what i mean)
# i used defined() incase the hash would be created otherwise? maybe?
# i split them to two vars unless we want diff messages for each
      my $am_ignored = defined($player->{'IGNORE'}->{$self->{'NAME'}});
      my $am_ignoring = defined($self->{'IGNORE'}->{$player->{'NAME'}});

#mich - if restructured to be cleaner and easier to read
#mich - norwho added, cannot view if player has it on or if self has it on
      if(
#we'll add a pref for this if it comes to it
#        $self->{'NORWHO'} ||
#        $player->{'NORWHO'} ||

         $player->{'ADMIN'} ||
         $player->{'ROCKDEV'} ||
         $self->{'REPU'} < -1 ||
         $i_logged_in_recently ||
         $am_ignored ||
         $am_ignoring ||
         ($player->{'LEV'} > $self->{'LEV'} * 1.5)) {
          my $smalldesc = $player->{'ADMIN'} ?
                             '{1}***  -> ADMIN <-  ***' : undef;
          if ($am_ignoring) {
              $smalldesc ||= '{1}***    IGNORED    ***';
          } elsif ($am_ignored) {
              $smalldesc ||= '{1}***  IGNORING YOU ***';
          } 
          $cap .= sprintf('{2}%18s %s' . "\n", $player->{'NAME'}, $smalldesc);
      } else {
          $playerHP = $player->{'HP'} / $player->{'MAXH'} * 100;
          $cap .= sprintf('{2}%18s {4}({17}%3d{4}) {16}%20s %s%3d%% {17}%04d'."\n", $player->{'NAME'}, $player->{'LEV'}, substr($main::map->[$player->{'ROOM'}]->{'NAME'},0,20), $playerHP<30?'{1}':'{6}', $playerHP, $player->{'T'} );
      }

#      if($player->{'TYPE'} !=1 
#         || (!$player->{'ADMIN'} && !$player->{'ROCKDEV'} && (!$i_logged_in_recently || $player eq $self)
#            && ($player->{'LEV'}<=$self->{'LEV'}*1.5 && $self->{'REPU'}>=-1 || $self->{'GENERAL'})  )
#        ){ 
#          my $playerHP = $player->{'HP'} / $player->{'MAXH'} * 100;
#          $cap .=  sprintf('{2}%18s {4}({17}%3d{4}) {16}%20s %s%3d%% {17}%04d'."\n", $player->{'NAME'}, $player->{'LEV'}, substr($main::map->[$player->{'ROOM'}]->{'NAME'},0,20), $playerHP<30?'{1}':'{6}', $playerHP, $player->{'T'} );
#      } else {
#          $cap .=  sprintf('{2}%18s %s'."\n", $player->{'NAME'}, $player->{'ADMIN'}?'{1}*** -> ADMIN <- ***':undef);
#      }
 }
# $cap .= '{41}{14}There are {5}'.(scalar keys(%{$main::activeuids}))." {14}total players in the game right now.\n";
 
 $self->log_append("{2}Scanning all $main::races[$self->{'RACE'}]s...\n{40}".$cap.'{41}');
 $self->log_error("Since your planar frequency is still tuning, you are not aware of players' locations.")
     if $i_logged_in_recently;
 
 return;
}

sub logged_in_recently {
   # They logged in recently, if they logged in within the last 10 minutes.
   # (this value could change later, though)
   return ( (time - $main::uidmap{lc $_[0]->{'NAME'}}) < 10*60);
}

sub web_who {
  my $self = shift;
  my $player;
  my $cap .= '<TABLE WIDTH=100% CELLPADDING=1 ALIGN=CENTER CELLSPACING=0>';
  my $n;
  foreach $player (keys(%{$main::activeuids})) {
    $player = &main::obj_lookup($main::activeuids->{$player});
      next if($player->{'SOCINVIS'} || ((time - $player->{'@LCTI'}) > (60) ) );
    
      my $wingColor = $main::wingmap[int ($player->{'LEV'}/50)] || '{13}#';
     if(!$n) { $cap .= "<TR>"; }
      $cap .=  sprintf ("<TD ALIGN=RIGHT><FONT SIZE=+1 FACE=Verdana>\{%d\}\%s</TD><TD ALIGN=CENTER><FONT SIZE=+2><B>$wingColor\%s%1s$wingColor</B></FONT></TD><TD><FONT FACE=Verdana><B><I>%s</I></B></FONT>&nbsp;</TD>", ($player->{'RACE'} % 18), $player->{'NAME'}, $main::gendermap{$player->{'GENDER'}}, $main::generalmap[$player->{'GENERAL'}] || $main::asteriskmap[$player->{'SOLDIER'} != 0] || 'o',  $main::pkmap[$player->{'PKTIME'} && ((time-$player->{'PVPTIME'})<60*2)] || $main::badrepmap[$player->{'REPU'}<$main::badrepborder] || $main::goodrepmap[$player->{'REPU'}>$main::goodrepborder] || $main::afkmap[$player->{'AFK'}] || $main::adminmap[$player->{'ADMIN'}] || $main::developermap[$player->{'ROCKDEV'}!=0] || $main::newbiemap[$player->{'NEWBIE'}!=0] || '     ');
      if($n) { $cap .= "</TR>"; }
      $n = abs($n-1);
  }
  if($n) { $cap .= "</TR>"; }
  $cap .= '</TABLE>';
  $cap .= '<CENTER><FONT COLOR=BLACK FACE="Comic Sans,Comic Sans MS">There are <B>'.(scalar keys(%{$main::activeuids})).'</B> total players in the game right now.</FONT></CENTER><BR>'; 
  $cap =~ s/\{(\d*)\}/$main::colorhtmlmap{$1}/ge;
  $self->{'WEBLOG'} .= $cap . "\n";
  return;
}

sub web_examine_players {
  my $self = shift;
  if(!$self->{'WEBACTIVE'}) { $self->log_append("{17}Sorry, you can only use that command when you're playing on the 'web'.\n"); return; }
  if(!$self->can_do(0,0,1)) { return; }
  my ($cap, $player, $thetoggle, $victimstatus, $viclaston);
  
  $cap = '<TABLE BORDER=0 CELLPADDING=4 WIDTH="100%" ><TR BGCOLOR="#EEEEEE"><TD ALIGN=RIGHT>Name</TD><TD ALIGN=CENTER>Race</TD><TD ALIGN=LEFT>Level</TD><TD ALIGN=CENTER>Status</TD><TD ALIGN=RIGHT>Weapon</TD><TD ALIGN=RIGHT>Last Seen</TD><TD ALIGN=RIGHT>ICQ #</TD>'; #<TD ALIGN=LEFT>Armour</TD><TD ALIGN=RIGHT>Experience</TD>
  #if($self->{'extortionist'}==1) { $cap .= '<TD ALIGN=RIGHT>Gold</TD>'; }
  #if($self->{'visionary'}==1) { $cap .= '<TD ALIGN=RIGHT>Max Mon Hit</TD><TD ALIGN=RIGHT>Turns</TD>'; }
  $cap .= '</TR>';
  
  foreach $player ($main::map->[$self->{'ROOM'}]->inv_objs) {
     next if ($player->{'TYPE'} != 1);
     $cap .= "<TR BGCOLOR=$main::looktoggle[$thetoggle]>";
     $cap .= "<TD ALIGN=RIGHT><B>$player->{'NAME'}</B></TD><TD ALIGN=CENTER><B>$main::htmlmap{$player->{'RACE'}}$main::races[$player->{'RACE'}]</B>"; # <FONT COLOR=YELLOW>$victim{'title'}
    # if($player->{'poisoned'}>0) { $cap .= "<FONT COLOR=GREEN> / poisoned</FONT COLOR>"; }
     $cap .= "</FONT COLOR></TD><TD ALIGN=LEFT>$main::weblevelcompare[($player->{'LEV'} <=> $self->{'LEV'})]</TD>";
     $cap .= "<TD ALIGN=CENTER>".(($player->{'HP'}<=0)?$main::webstatuslist[0]:$main::webstatuslist[int (10*$player->{'HP'}/$player->{'MAXH'}+.9999999)]);
    # if($self->{'visionary'}) { print "<BR><B>[</B>$victim{'hp'}<B>]</B>"; }
     $cap .= '</TD>';
     # weapon
     if(!$player->{'WEAPON'}) { $cap .= '<TD><FONT COLOR=#003300>none</FONT></TD>'; }
     else { $cap .= '<TD><FONT COLOR=#003300>'.$main::objs->{$player->{'WEAPON'}}->{'NAME'}.'</FONT></TD>'; }
     # 
     $viclaston = int ( (time-$main::activeusers->{$player->{'OBJID'}}) / 60);
     $cap .= '<TD>';
     if(!$viclaston) { $cap .= "<FONT COLOR=RED><B>ONLINE</B></FONT COLOR>"; }
     elsif( $viclaston < 60 ) { $cap .= "<FONT COLOR=RED><B>$viclaston</B> minutes ago.</FONT COLOR>"; }
     elsif( $viclaston < (60*24) ) { $cap .= "<FONT COLOR=BLUE><B>".(int ($viclaston/60))."</B> hours ago.</FONT COLOR>"; }
     else { $cap .= "<FONT COLOR=GRAY><B>".(int ($viclaston/60/24))."</B> days ago.</FONT COLOR>"; }
     $cap .= '</TD>';
     if(!$player->{'ICQ'}) { $cap .= '<TD><FONT COLOR=#330000>none</FONT></TD>'; }
     else { $cap .= '<TD><FONT COLOR=#330000>'.$player->{'ICQ'}.'</FONT></TD>'; }
     $cap .= '</TR>';
     $thetoggle = abs($thetoggle-1);
  }
  $cap .= '</TABLE>';
  $self->{'WEBLOG'} .= $cap;
  return;
}

sub zap_dark() {
 my ($self, $v, $pct) = @_;
 if(!$v->is_dead) {
   my $d = int $v->{'MAXH'}*($pct || $self->{'ZAP_PCT'} || .5);
   $v->log_append("{2}A horrible dark energy zaps you as you enter, causing $d damage!\n");
   $v->room_sighttell("{2}A horrible dark energy zaps $v->{'NAME'} as $v->{'PRO'} enters, causing $d damage!\n");
   $self->log_append("{2}$v->{'NAME'} has been zapped.\n");
   $v->{'HP'}-=$d;
   if($v->{'HP'}<=0) { $v->die(); }
 }
}


sub rest
{
	my $self = shift;
	my ($dam);
	if(defined($self->{'FX'}->{'52'}))
	{
        $self->log_append("{15}You are afraid to lower your guard!\n");
        return 0;
    }

	if(defined($self->{'FX'}->{'27'}))
    {
        $self->log_append("{1}You are in too much pain to rest!\n");
        return 0;
    }
	if($self->is_tired() && (1 || $self->{'GAME'}) )
    {
        $self->log_append("{13}You are too worked-up to rest!\n");
        return 0;
    }
	if(!$self->can_do(0,0,3+4*$self->is_tired()))
    {
        return 0;
    }
	$self->room_sighttell("{6}$self->{'NAME'} {14}takes a breather.\n");
	
	
	# hp
	# SELECT ROOM. IF ROOM CHANGES, UPDATE THIS LATER PLEASE
	my $room = $main::map->[$self->{'ROOM'}];
	$dam = $room->{'SAFE'} ? $self->{'MAXH'} : int( (((rand($self->{'MAXH'}/4)) + ($self->{'MAXH'}/6))) * ( $self->fuzz_pct_skill(8,20) + $self->fuzz_pct_skill(19,20) ) / 2);

	#mich patch - kmed needs more umph (btw i don't understand the !@#$ above at all)
    my $ratio = ($self->{'STAT'}->[KMED] * 0.45 + $self->{'LEV'} * 0.20) / $self->{'LEV'};
	if(($ratio * ($self->{'STAT'}->[KMED] * 0.4 + $self->{'LEV'} * 0.6) > rand(1000 / $ratio)))
	{
		$dam += int (rand($self->{'STAT'}->[KMED]) / 1.50);
		if($self->{'VIGOR'} < .5)
		{
			$self->{'VIGOR'} += (($self->{'STAT'}->[KMED] / $self->{'LEV'}) / 20);
			if($self->{'VIGOR'} > .5)
			{
		    	$self->{'VIGOR'} = .5;
			}
		}
	}
	#end mich patch

	if($self->{'FX'}->{30}) {
        $dam += int ($self->fuzz_pct_skill(19)*$self->{'MAXH'}/4);
    }

	if(($self->{'HP'} + $dam) > $self->{'MAXH'}) {
        $dam = $self->{'MAXH'}-$self->{'HP'};
    }

	$self->log_append("{6}You sit down to take a breather, ");
	if($self->{'FX'}->{16} && (rand(1)<.30))
    {
        $self->log_append("{16}and find yourself in a horrible nightmare{6}.\n");
        $dam=0;
    }
	elsif($self->{'FX'}->{18} && ($self->{'HP'}<($self->{'MAXH'}/2)))
    {
        $self->log_append("{16}and fall into a coma{6}.\n");
        $self->room_sighttell("{6}$self->{'NAME'} {2}passes out.\n");
        $self->effect_add(6);
        $dam=($self->{'MAXH'}-$self->{'HP'});
    }
	else
    {
        $self->log_append("healing {16}$dam {6}damage!\n");
    }

	$self->{'HP'} += int $dam;
	
	
	# vigor
	if ($self->{'VIGOR'} < .5) {
	    $self->{'VIGOR'} += .06; #lets see how this goes
    	    if ($self->{'VIGOR'} > .5) {
                $self->{'VIGOR'}=.5;
            }
	}
	$self->{'RESTACTIVE'}=1;
	
	# spawn a mon
	#if(rand(10)>7) { 
	#    my $spawnee = $room->db_spawn;
	#    if(!$spawnee) { }#
	#    elsif($room->{'TYPE'} == -1) { 
	#     $self->room_sighttell("{17}$spawnee->{'NAME'} {7}makes $spawnee->{'PPOS'} way into the room while $self->{'NAME'} is asleep.\n");
	#    } else {
	#     $room->log_append("{17}$spawnee->{'NAME'} {7}appears in your inventory.\n");
	#    }
	# }
	$self->make_tired();
	# tell the room.. <bahahha>
	$room->tell(11, 1, 0, undef, $self);
	delete $self->{'RESTACTIVE'};
	
	# was * 125
	
        $self->roll_dice_for_bounty_assassin();

	#if(rand(5)>3) { $self->make_tired(); }
	#$self->make_tired();
	
	return 1;
}

sub roll_dice_for_bounty_assassin {
    # tries getting assassin after me
    my $self = shift;

    my $room = $self->room();
    if (!$self->{'GAME'} &&
        !$room->{'PVPROOM'} &&
        !$self->{'NEWBIE'} &&
        ($main::bounties{lc($self->{'NAME'})} > (1500 + $self->{'LEV'}*50)) &&
        !$room->{'SAFE'} &&
        !$room->{'NOPVP'} &&        
        (time - $self->{'LAST_ASSASSINATION_ATTEMPT'} >= 900)    && # 15 min interval or more
        (time - $self->{'LAST_ASSASSINATION_DEATH'} >= 259200)      # 60 * 60 * 24 * 3 (days)
    ) { 
       
	# add assassin ;-)
        if (rand(100) < 6) {
            $self->{'LAST_ASSASSINATION_ATTEMPT'} = time;

            $self->log_append("{17}### HEY MR. ADMIN YOURE GETTING HAUNTED ###\n") if $self->{'ADMIN'};
            $self->assassin_haunt();
        }
    }
}

sub assassin_haunt {
    my $self = shift;
    my $o = new rest_assassin; 
    $main::map->[$self->{'ROOM'}]->inv_add($o);
    $o->sick_em($self);
    $o->stats_allto(int($self->{'LEV'}*5/4)); # was 6/4
    $o->{'AI'}->{'GIVEUP'}=1; # giveup on interplanar moves
    $main::objs->{$o->{'DWEAP'}}->{'WC'} = int($self->{'LEV'}*5/4) # was 6/4
        if $o->{'DWEAP'};
    $o->stats_update();
    $o->power_up();
    return($o);
}

sub hostility_toggle {
    my $self = shift;
    my $hos_type = lc substr(shift, 0, 1);

    if($self->{'TYPE'} != 1) { $self->log_append("{1}Only players can switch their hostility.\n"); return; }

    if ($hos_type eq "n") {
	    $self->{'HOSTILE'} = HOS_NONE;
    } elsif ($hos_type eq "o") {
	    $self->{'HOSTILE'} = HOS_OFFENSIVE;
    } elsif ($hos_type eq "d") {
	    $self->{'HOSTILE'} = HOS_DEFENSIVE;
    } elsif ($hos_type eq "a") {
	    $self->{'HOSTILE'} = HOS_ALL;
    } else {
        $self->log_error("Syntax: hostility <'none'|'offensive'|'defensive'|'all'>");
        $self->log_hint("You can abbreviate these hostility modes, as well. So a mode of 'o' is still offensive mode.");
	    return; 
    }

    $self->log_append($self->get_hostility_str());
    return;
}

sub get_hostility_str() {
	my $self = shift;
	if ($self->{'HOSTILE'} == HOS_NONE) {
    	return "{14}[No Hostility]:        {4}You NOW only attack someone if they attack you first.\n";
	} elsif ($self->{'HOSTILE'} == HOS_OFFENSIVE) {
    	return "{15}[Offensive Hostility]: {5}You NOW only retaliate with players if a member of your own race attacks them.\n";
	} elsif ($self->{'HOSTILE'} == HOS_DEFENSIVE) {
    	return "{16}[Defensive Hostility]: {6}You NOW only retaliate with players if they attack a member of your own race.\n";
	} elsif ($self->{'HOSTILE'} == HOS_ALL) {
    	return "{11}[All Hostility]:       {1}You will retaliate with players both offensively and defensively.\n";
	}
	return "I have no clue what your current hostility means.";
}

sub get_stats_raiselist {
  my $self = shift;
  my $cap;
  my $sarr = $self->{'STAT'}; 
  $cap .= "{40}{13}KNO                     MAJ                     DEF\n";
  $cap .= sprintf("%2s{17}%4d Mech     [KMEC] %2s{2}%4d Offensive [MOFF] %2s{6}%4d Physical [DPHY]\n", $self->exp_need_ast(6), $sarr->[6], $self->exp_need_ast(10), $sarr->[10], $self->exp_need_ast(19), $sarr->[19]);
  $cap .= sprintf("%2s{17}%4d Social   [KSOC] %2s{2}%4d Defensive [MDEF] %2s{6}%4d Energy   [DENE]\n", $self->exp_need_ast(7), $sarr->[7], $self->exp_need_ast(11), $sarr->[11], $self->exp_need_ast(20), $sarr->[20]);
  $cap .= sprintf("%2s{17}%4d Medical  [KMED] %2s{2}%4d Elemental [MELE] %2s{6}%4d Mental   [DMEN]\n", $self->exp_need_ast(8), $sarr->[8], $self->exp_need_ast(12), $sarr->[12], $self->exp_need_ast(21), $sarr->[21]);
  $cap .= sprintf("%2s{17}%4d Combat   [KCOM] %2s{2}%4d Mental [MMEN]\n", $self->exp_need_ast(9), $sarr->[9], $self->exp_need_ast(22), $sarr->[22]);
  $cap .= "{13}CHA                     AGI     STR\n";
  $cap .= sprintf("%2s{17}%4d Appear   [CAPP] %2s{2}%4d %2s{2}%4d Upper [AUPP] [SUPP]\n", $self->exp_need_ast(13), $sarr->[13], $self->exp_need_ast(15), $sarr->[15], $self->exp_need_ast(17), $sarr->[17]);
  $cap .= sprintf("%2s{17}%4d Attitude [CATT] %2s{2}%4d %2s{2}%4d Lower [ALOW] [SLOW]\n{41}", $self->exp_need_ast(14), $sarr->[14], $self->exp_need_ast(16), $sarr->[16], $self->exp_need_ast(18), $sarr->[18]);
  return $cap;
}

sub stats_raiselist() {
    my $self = shift;
	$self->log_append($self->get_stats_raiselist());
}


sub exp_need_ast {
  my $statnum = int $_[1];
  my $auto_prefix = (!$_[0]->{'AUTORAISE_STATS'} || $_[0]->{'AUTORAISE_STATS'}->{$statnum}) ? '{4}A' : ' ';
  if($_[0]->{'EXP'}->[$statnum] >= 1000000000) { return $auto_prefix . ' '; }
  if($_[0]->exp_need($statnum) <= $_[0]->{$main::eclass[$statnum]}) { return("$auto_prefix\{1}*"); } else { return($auto_prefix . ' '); }
}

sub peek(dir) {
	my ($self, $dir, $farsee) = @_;
	if($farsee && !$self->skill_has(40)) { $self->log_append("{6}Farwhat?\n"); return; }
	if(!$dir) { $self->log_append("{7}The format is: {17}peek {17}<direction>\n"); return; }
	if(defined($self->{'FX'}->{22})) { $self->log_append("{6}..maybe after you install some eyes that work, Mr. Blindly!\n"); return; }
	$dir = $main::dircondensemap{lc($dir)};
	#print "Dir is $dir.\n";
	
	if(!$dir) { $self->log_append("{5}You can't peek in that direction!\n"); return; }
	if(!$main::map->[$self->{'ROOM'}]->{$dir}->[0] || $main::map->[$self->{'ROOM'}]->{$dir}->[1]) { 
    	if($self->pref_get('jive')) { 
           $self->log_append("{1}You jab your eye into the $main::dirernmap{$dir} $main::dirwall{$dir}.\n");
           $self->room_sighttell("{1}$self->{'NAME'} jabs $self->{'PPOS'} eye into the $main::dirernmap{$dir} $main::dirwall{$dir}.\n") unless $farsee;
    	} else { 
           $self->log_append("{1}You would, if that $main::dirwall{$dir} weren't there.\n");
    	}
    	return; 
	}
	my ($cap, $room);
	$room = $main::map->[$main::map->[$self->{'ROOM'}]->{$dir}->[0]];
	if(!$farsee && $room->{'NOPEEK'}) { $self->log_append('{4}'.$room->{'NOPEEK'}."\n"); return; }
	
	my $turns_taken = $self->aprl_rec_scan(585)?0:2; # no peeky turns if they have magic goggles
	
	if(!$self->can_do(4 * $farsee,0,$turns_taken)) { return; } 
	$cap = $farsee?"{17}You summon your farsight, and extended it $main::dirlongmap{$dir}wards.\n":"{17}$main::dirlongmap{$dir}\{7}, you see...\n";

	$cap .= '{3}'.$room->{'NAME'}."\n";
	if(!$self->pref_get('brief room descriptions')) { $cap .= '{2}'.&rockobj::wrap('', '', $room->desc_hard)."\n"; }
	$cap .= join(undef, $room->room_inv_list($self,0));
	$cap .= '{16}' . $room->exits_list(undef);
	$self->log_append($cap);
	if($farsee) {
    	$self->room_sighttell("{17}$self->{'NAME'} {7}speaks a few words of magic, invoking a spell.\n");
	} else {
    	$self->room_sighttell("{17}$self->{'NAME'} {7}peeks {14}$main::dirlongmap{$dir}"."{7}.\n");
    	$room->room_sighttell("{17}$self->{'NAME'} {7}peeks in from {14}$main::dirfrommap{$main::diroppmap{$dir}}"."{7}.\n");
	}
	return;
}

sub on_idle {}
sub on_rest {}

sub shares_room {
  my ($self, $roomie) = @_;
  return($self->{'ROOM'}==$roomie->{'ROOM'});
}

sub hint {
 my $self = shift;
 if($main::map->[$self->{'ROOM'}]->{'HINT'}) { $self->log_append("{12}Hint:\n{2}$main::map->[$self->{'ROOM'}]->{'HINT'}\n"); }
 else { $self->log_append("{2}Sorry, there are no hints for this room.\n"); }
 return;
}

sub item_put (str) {
   my ($self, $str) = @_; $str = lc($str);
   if ( (index($str, ' in ') == -1) && (index($str, ' into ') == -1) ){
      $self->log_append("{3}The correct usage is:\n{1}put [object name] in [recipient name].\n");
      return(-1);
   } else { 
      my ($successa, $successb, $pobj, $iobj, $iname, $pname);
      while (index($str, '  ') > -1) { $str =~ s/  / /g; }
      if(index($str, ' into ') == -1) { ($iname, $pname) = split(/ in /,$str, 2); }
      else { ($iname, $pname) = split(/ into /,$str, 2);  }
      # catch cryl stuff
      if(abs($iname) > 0) { 
         ($successb, $pobj) = $self->inv_cgetobj($pname, 0, $main::map->[$self->{'ROOM'}]->inv_objs );
         if($successb == 1) { return ($self->cryl_put($iname, $pobj)); }
         elsif ( $successb == 0 ) { $self->log_append("{3}You don't see anything named $pname here.\n"); }
         elsif ( $successb == -1 ) { $self->log_append("{7}In What!? ".$pobj); }
         return;
      }
      ($successa, $iobj) = $self->inv_cgetobj($iname, 0, $self->inv_objs );
      ($successb, $pobj) = $self->inv_cgetobj($pname, 0, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs );
      if ( ($successa == 1) && ($successb == 1) ) {   
         if($pobj eq $iobj) { $self->log_append("{3}You cannot put $iobj->{'NAME'} into itself.\n"); }
         elsif(!$pobj->{'CONTAINER'}) { $self->log_append("{3}There is no way for you to put anything into $pobj->{'NAME'}.\n");  }
         elsif(!$pobj->inv_free) { $self->log_append("{3}$pobj->{'NAME'} doesn't have any room for you to place it.\n"); }
       #  elsif(!$pobj->can_lift($iobj) || !$iobj->can_be_lifted($self)) { $self->log_append("{3}$pobj->{'NAME'} isn't strong enough to carry it.\n"); }
         else { $self->item_hput($iobj, $pobj); }
      }
      elsif ( $successa == 0 ) { $self->log_append("{3}You don't have any $iname to place. (Are you sure you don't mean {17}fill{3}?)\n"); }
      elsif ( $successb == 0 ) { $self->log_append("{3}You don't see anyone named $pname here.\n"); }
      elsif ( $successa == -1 ) { $self->log_append("{7}Put What!? ".$iobj); }
      elsif ( $successb == -1 ) { $self->log_append("{7}In Where!? ".$pobj); }
   }
   return;
}

sub item_hput (item, recipient) {
  my ($self, $item, $to) = @_;
  if($item->{'CONTAINEDBY'} != $self->{'OBJID'}) { return; }
  if($item->{'WORN'}) { $self->apparel_remove($item); delete $item->{'WORN'}; $self->apparel_update; }
  if($self->{'WEAPON'} == $item->{'OBJID'}) { delete $self->{'WEAPON'}; delete $item->{'EQD'}; }
  $self->inv_del($item);
  $to->inv_add($item);
  $self->log_append("{7}You put $item->{'NAME'} into $to->{'NAME'}.\n");
  $to->log_append("{7}$self->{'NAME'} puts $item->{'NAME'} into you.\n");
  if ( rand(($self->pct_skill(7)+$self->pct_skill(15))/2) > rand(100) ) {
     $self->room_sighttell("{7}$self->{'NAME'} {3}puts an item into {7}$to->{'NAME'}.\n", $to);
  } else {
     $self->room_sighttell("{7}$self->{'NAME'} {3}puts $item->{'NAME'} into {7}$to->{'NAME'}.\n", $to);
  }
  $self->on_put($item, $to);
  $to->on_inherit($item, $self);
  $item->on_placed($self, $to);
  return 1;
}

sub pw_change {
return;
}

sub ejpw_change {
 my ($self, $oldpw, $pw) = @_;
 if($self->{'TYPE'} != 1) { $self->log_append("{2}Only {1}players{2} are allowed to change their passwords.\n"); return; }
 if($self->{'!CHPW'}) { $self->log_append("You are not allowed to change your password.\n"); return; }
 if($self->{'EJPW'} ne lc($oldpw)) { $self->log_append("{2}Your old password is invalid.\n{3}Format: chejpw <old password> <new password>\n"); return; }
 $pw = lc($pw);
 if(index($pw, 'to ')==0) { $pw = substr($pw, 3); }
 $pw =~ s/ //g;
 if(length($pw) < 4) { $self->log_append("{2}Please pick a longer password than $pw.\n"); return; }
 print "$self->{'NAME'} at $self->{'IP'} changed password from $self->{'EJPW'} to $pw.\n";
 &main::mail_send($self->{'EMAIL'}, "Rock: [Eject Password Change]", "Sorry to bother you,\n\nThis message is just a reminder that you have\nchanged your ejection password to \"$pw\". Your old password,\n\"$self->{'EJPW'}\", will no longer work. Please use your new\npassword instead.\n\nYou were at the IP of $self->{'IP'} when the\npassword-change occurred.\n\n- Rock Support\n(This was an automated message).\n");
 $self->{'EJPW'}=$pw;
 $self->log_append("Your ejection password has been changed. You will receive email shortly, reminding you of this change.\n");
 return;
}

sub on_put {}
sub on_inherit {}
sub on_placed {}

sub flam_tempt (percent) {
  my ($self, $percent) = @_;
  if (rand(100) < $self->{'FLAM'}*$percent) { $self->flam_make; }
  return;
}

sub cont_tell {
  # tells message to container
  my ($self) = shift;
  if(!$main::objs->{$self->{'CONTAINEDBY'}} || ($main::objs->{$self->{'CONTAINEDBY'}}->{'TYPE'}==0) ) { $self->room_sighttell(@_); }
  else { $main::objs->{$self->{'CONTAINEDBY'}}->log_append(@_); }
}

sub flam_make {
  my $self = shift;
  # sets self on fire.
  $self->{'AFIRE'}=1;
  if($self->{'EXPLOSIVE'} && (rand(5) > 3)) { $self->explode(); }
  else { $self->cont_tell("{3}$self->{'NAME'} {13}is set afire.\n"); }
  return;
}

sub struggle_free {
  my $self = shift;
  if(!$self->{'TANGLED'} || !$main::objs->{$self->{'TANGLED'}}) { $self->log_append("You have nothing to struggle from.\n"); return(0); }
  if($self->is_tired) { $self->log_append("{7}You are too exhausted to try struggling free.\n"); return(0); }
  if(rand($main::objs->{$self->{'TANGLED'}}->{'STICKYFUZ'}) < $self->fuzz_pct_skill(3)) { 
    $self->log_append("You struggle free from $main::objs->{$self->{'TANGLED'}}->{'NAME'}.\n"); 
    $self->room_sighttell("$self->{'NAME'} struggles free from $main::objs->{$self->{'TANGLED'}}->{'NAME'}.\n");
    delete $self->{'TANGLED'};
  } else { 
    $self->room_sighttell("$self->{'NAME'} attempts to struggle free, failing miserably.\n");
    $self->log_append("You are unable to struggle free.\n");
  }
  $self->{'T'} -= 1; if($self->{'T'}<0) { $self->{'T'}=0; }
  $self->make_tired();
  return;
}

sub thanked {
    # IMPORTANT: The $self is the object that **gets thanked**,
	#            not the person thanking.
    my ($self, $p) = @_;
    if($self eq $p) { $p->log_error("You cannot thank yourself. Egotist."); return 1; }

    if (!$p->{'ADMIN'}) {
        if($p->{'LEV'}<45) { $p->log_error("You must be at least level 45 to thank a player."); return 1; }
        if($self->{'RACE'} != $p->{'RACE'}) { $p->log_error("You can only thank characters of your race."); return 1; }
        if($self->{'GAME'} || $p->{'GAME'}) { $p->log_error("You cannot thank characters when one of you is in a subgame."); return 1; }
    }
    
    if($self->{'TYPE'} != OTYPE_PLAYER) { $p->log_error("You may only thank players."); return 1; }
    if(!$p->{'REPUS'}) { $p->log_error("You do not have any more reputation points to use."); $p->log_hint("Try again tomorrow."); return; }
    if($p->{'LASTTHANK'} eq $self->{'NAME'}) { $p->log_error("You cannot thank the same person twice in a row. Share the love."); return; }
	if($p->is_likely_alt($self)) { $p->log_error("You cannot thank one of your potential alt characters."); return; }
	$p->{'REPUS'}--;
    $self->{'REPU'}++;
	$p->{'LASTTHANK'} = $self->{'NAME'};
    $p->log_append("{17}You have thanked $self->{'NAME'}. {6}(note: {16}$self->{'NAME'} {6}was not informed of this)\n");
    return 1;
}

sub deprecated {
    # NOTE, the $self is the object that gets thanked
    my ($self, $p) = @_;
    if($self eq $p) { $p->log_error("You cannot deprecate yourself. Sadist."); return 1; }
    
    if (!$p->{'ADMIN'}) {
        if($p->{'LEV'}<45) { $p->log_error("You must be at least level 45 to deprecate a player."); return 1; }
        if($self->{'RACE'} != $p->{'RACE'}) { $p->log_error("You can only deprecate characters of your race."); return 1; }
        if($self->{'GAME'} || $p->{'GAME'}) { $p->log_error("You cannot deprecate characters when one of you is in a subgame."); return 1; }
    }
    
    if($self->{'TYPE'} != OTYPE_PLAYER) { $p->log_error("You may only deprecate players."); return 1; }
    if(!$p->{'REPUS'}) { $p->log_error("You do not have any more reputation points to use."); $p->log_hint("Try again tomorrow."); return; }
    if($p->{'LASTDEPRECATE'} eq $self->{'NAME'}) { $p->log_error("You cannot deprecate the same person twice in a row. Share the uh.. something."); return; }
	if($p->is_likely_alt($self)) { $p->log_error("You cannot deprecate one of your potential alt characters."); return; }
    $p->{'REPUS'}--;
    $self->{'REPU'}--;
	$p->{'LASTDEPRECATE'} = $self->{'NAME'};
    $p->log_append("{17}You have deprecated $self->{'NAME'}. {6}(note: {16}$self->{'NAME'} {6}was not informed of this)\n");
    return 1;
}

sub health_status {
  return ($_[0]->{'HP'}<=0)?$main::statuslist[0]:$main::statuslist[int (10*$_[0]->{'HP'}/$_[0]->{'MAXH'}+.9999999)];
}

sub stat_compare (object, @stat_numbers){
  #compares self to object.. relative to self. returns string
  my ($self, $player, $n, $cap, $mod);
  $self = shift;
  $player = shift;
  my $i = 1;
  while(@_) {
     $n = shift;
     $mod=$player->fuzz_pct_skill(14,700) * $player->{'APPEAR'} * $self->{'STAT'}->[$n];
     $cap .= sprintf("{17}%10s: {6\}\%-16s", $main::statnum_toname{$n}, $main::levelcompare[($player->{'STAT'}->[$n] <=> ($self->{'STAT'}->[$n]+$mod))] );
     $i=($i+1)%2;
     if($i==1) { $cap .= "\n"; }
  }
  if($i==0) { $cap .= "\n"; }
  return($cap);
}

sub appearance_toggle {
 my $self = shift;
 if($self->{'APPEAR'} == 1) { 
    $self->{'APPEAR'}=-1; $self->log_append("{3}You will now present yourself as humbly as you are able to.\n");
 } elsif($self->{'APPEAR'} == -1) { 
    $self->{'APPEAR'}=0; $self->log_append("{4}You will now present yourself as honestly as possible.\n");
 } else {
    $self->{'APPEAR'}=1; $self->log_append("{2}You will now present yourself as being better than average.\n");
 }
}

sub items_givebasic {
  my $self = shift;
  $self->item_spawn(65, 70, 74, 83, 84);
  return;
}

sub inv_has_rec_recurse {
    my $self = shift;
    return $self if $self->inv_has_rec(@_);
    foreach my $i ($self->inv_objs) {
       return $i if $i->inv_has_rec_recurse(@_);
    }
    return undef;
}

sub inv_has_rec (object recipe list){
    # returns TRUE if self has all objects listed. otherwise FALSE.
    # if no objects listed, returns true.
	# 
	# Syntax: my $has_it = $self->inv_has_rec($item_id);
	#
    my $self  = shift;
    my ($success, %scratch);
    %scratch = %{$self->{'INV'}};
    while (@_) {
        $success = 0;
        foreach my $o (keys(%scratch)) { 
            next if $success;
            if($scratch{$o}->{'REC'} == $_[0]) { $success = 1; delete $scratch{$o}; }
        }
        if(!$success) { return(0); }
        shift;
    }
    return $success;
}

sub stk_has_rec (object recipe list){
    # returns TRUE if self has all objects listed, IN STORAGE. otherwise FALSE.
    # if no objects listed, returns true.
	# 
	# Syntax: my $has_it = $self->stk_has_rec($item_id);
	#
    my ($self, $success, $o, %scratch) = (shift);
    if(!$self->{'STK'}) { return(0); }
    eval { %scratch = %{$self->{'STK'}}; }; # jus tin case
    while (@_) {
      $success = 0;
      foreach $o (keys(%scratch)) { 
       next if $success;
       if($scratch{$o}->{'STK'} == $_[0]) { $success = 1; delete $scratch{$o}; }
      }
      if(!$success) { return(0); }
      shift;
    }
    return $success;
}

sub aprl_rec_scan (recipe number){
    # If $self is WEARING an object of id $rec, then the object
	# is returned. Otherwise, returns undef/false. Really this should be undef
	# 
	# Syntax: my $obj = $self->aprl_rec_scan($item_id);
	#
    my ($self, $o) = shift;
    if(!$self->{'APRL'}) { return(''); }
    foreach $o (@{$self->{'APRL'}}) { 
       if($o->{'REC'} == $_[0]) { return($o); }
    }
    return(undef); # just in case
}

# Note: there is no aprl_has_rec since the functionality is
# essentially the same with aprl_rec_scan

sub inv_rec_scan (recipe number){
    # returns obj if self has obj. otherwise false.
    my ($self, $o) = shift;
    foreach $o (values(%{$self->{'INV'}})) { 
       if($o->{'REC'} == $_[0]) { return($o); }
    }
    return(undef); # just in case
}

sub dug { my ($self, $digger) = @_; $digger->log_append("{2}Dig that? I suppose you want to open a pillar, too!\n"); return; }

sub item_assemble {
  # the recipe-user!
  my ($self, $recipe) = @_;
  $recipe = lc($recipe);
  if(!$recipe) { $self->log_append("{3}Make what?\n"); return; }
  if(!$main::recipes->{$recipe}) { $self->log_append("{3}Hmm - nobody's made THAT before!\n"); return; }
  
  # set vars
  my (@critems, @skillreqs, @msgs, $turns, @recitems, @temp, $n);
  @temp = @{$main::recipes->{$recipe}};
  @critems = split(/\,/, shift(@temp));
  @skillreqs = split(/\,/, shift(@temp));
  $turns = shift(@temp);
  @msgs = ($temp[0], $temp[1], $temp[2]); shift(@temp); shift(@temp); shift(@temp);
  
  foreach $n (@temp) { push(@recitems, abs($n)); } # make all positive
  
  # check for qualification
  foreach $n (@skillreqs) { if($n && !$self->{'GIFT'}->{$n}) { $self->log_append("{3}You haven't the skills to do so.\n"); return; } }
  if(!$self->inv_has_rec(@recitems)) { $self->log_append("{2}$msgs[0]\n"); return; } # not proper materials
  if(!$self->can_do(0,0,$turns)) { return; }
  
  grep {  s/\%PS/$self->{'PRO'}/g; s/\%HS/$self->{'PPOS'}/g;  s/\%MS/$self->{'PPRO'}/g; s/\%S/\{16\}$self->{'NAME'}\{2\}/g; } @msgs;

  # then we make it
  $self->log_append("{2}$msgs[1]\n");
  $self->room_sighttell("{2}$msgs[2]\n");
  # ditch the destructables.
  # this could be more optimized..
  foreach $n (@temp) { next if ($n>=0); $self->inv_rec_scan(abs($n))->obj_dissolve; }
  # create the new obj.
  $self->item_spawn(@critems);
  return;  
}

sub on_assembled {}

sub bounty_set (whoname [, bounty]) {
    my ($self, $who, $bounty) = @_;
    if(!$main::map->[$self->{'ROOM'}]->{'BOUNTYOFFICE'}) { $self->log_append("{7}You must be in a bounty office in order to organize bounties.\n"); return; }
    $who = lc($who);
    $bounty = int abs($bounty);
    if($bounty) {
      if(!$main::uidmap{$who}) { $self->log_append("{1}Userid {7}$who {1}does not exist.\n"); return; }
      elsif($self->{'CRYL'}<$bounty) { $self->log_append("{1}You are not carrying {3}$bounty {1}cryl!\n"); }
      else {
        $self->{'CRYL'}-=$bounty;
        $main::bounties{$who}+=$bounty;
        $self->log_append("{4}You submit a bounty of $bounty cryl against $who.\n");
        $self->room_sighttell("{5}$self->{'NAME'} places a bounty of $bounty cryl.\n");
      }
    } else { 
      if(!$who) { $self->bounty_top; }
      elsif(!$main::uidmap{$who}) { $self->log_append("{1}Userid {7}$who {1}does not exist.\n"); }
      elsif($main::bounties{$who}) {
          $self->log_append("{1}Yes, there is a bounty on {6}$who\{1} for {13}$main::bounties{$who}\{1} cryl.\n");
      } else {
          $self->log_append("{4}You are not aware of any bounties for {6}$who"."{4}.\n");  
      }
    }
    return;
}

sub bounty_top {
  my $self = shift;
  $self->room_sighttell("{4}$self->{'NAME'} {2}examines the list of bounties.\n");
  my @b = sort by_top_bounty (keys(%main::bounties));
  my ($b, $cap, $n);
  for ($n=1; $n<=10; $n++) { $b = ($b[$n-1]); next if (!$main::bounties{$b}); $cap .= sprintf("{2}%2d. {13}%20s {7}( {6}%10d {7})\n", $n, $b, $main::bounties{$b}); }

  if($cap) { $self->log_append("{40}{1}Top Bounties: \n".$cap."{41}"); }
  else { $self->log_append("{4}There are no bounties posted right now.\n"); }
  return;
}


sub bounty_codeget {
  # returns my bounty code, creating one if necessary.
  my $self = shift;
  return($main::bounty_codes{lc($self->{'NAME'})} || ($main::bounty_codes{lc($self->{'NAME'})} = rand(100000)) )
}

sub by_top_bounty { $main::bounties{$b} <=> $main::bounties{$a} }

sub bonus_authorized ([X seconds]){
  my ($caller, $self, $sec) = ((caller(0))[3], @_);
  $sec = 450 unless ($sec > 0);
  if ( $self->{'GATE'}->{$caller} && ((time - $self->{'GATE'}->{$caller}) < $sec)) {
     delete $self->{'GATE'}->{$caller};
     return 0;
  }
  # or we don't have it.. sooo
  $self->{'GATE'}->{$caller}=time;
  return(1); # okay, you can do stuff..
}

sub caller_disp {
  my @c = caller(0);
  my $n;
  for ($n=0; $n<=$#c; $n++) { print "$n: $c[$n]\n"; }
  # results: [3] is rockobj::caller_test, [2] is the line number..
}

sub caller_test {
  shift->caller_disp;
}

sub inv_cleanup { }

sub inv_remnodb {
   # removes objects that aren't in the db..
   my $self = shift;
   my $i;
   if (!$self->{'DB'} || !defined(@{$main::db->[$self->{'DB'}]})) { foreach $i ($self->inv_objs) { $i->dissolve_allsubs; } } # recursive dissolve
   else {
      my (%db);
      for ($i=1; $i<=$#{$main::db->[$self->{'DB'}]}; $i++) {
        $db{$main::db->[$self->{'DB'}]->[$i]}=1;
      }
      foreach $i ($self->inv_objs) { if(!$db{$i->{'REC'}}) { $i->dissolve_allsubs; } }
   }
   return;
}

sub icq_set {
  my ($self, $n) = @_;
  $n = int $n;
  if($n<=0) { $self->log_append("{4}Invalid ICQ Number.\n"); }
  else {  $self->{'ICQ'}=$n; $self->log_append("{4}ICQ Number set to $n.\n"); }
  return;
}

sub appraisal_get {
  my ($self, $who) = @_;
  # SHOULD BE RENAMED TO appraise_item
  if(!$who->{'GIFT'}->{'CRYL'} && !$who->skill_has(16)) { $who->log_append("You are not skilled enough in item management.\n"); return(1); }
  if(!$who->can_do(0,0,10)) { return(1); }
   
  my $price = $self->get_appraised_value($who);
  if(($price <= 0) || $self->{'JUNK'}) { $who->log_append("{13}$self->{'NAME'} is a piece of junk!\n"); }
  else { $who->log_append("{13}You estimate $self->{'NAME'}\'s worth to be circa {3}$price {13}cryl.\n"); }
  if(rand(1)<.1) { $who->gifts_affect('CRYL'); }
  return(1);
}

sub get_appraised_value {
    my ($self, $appraiser) = @_;
    die "No appraiser passed" unless $appraiser;
	my ($pmod, $price);
    my $val = $self->{'TYPE'} == 1 ? $self->{'CWORTH'} : $self->{'VAL'};
    $pmod = int ( ($val * (1-($appraiser->{'GIFT'}->{'CRYL'}||90)/100)) + rand($val/10) );
    if(rand(10)<5) { $pmod *= -1; }
    $price = $val + $pmod;
	
	return $price < 0 ? 0 : abs int $price;
}

sub pdesc_request {
  my ($self, $cap) = @_;
  $cap = &main::rm_whitespace($cap);
  if(!$cap) { $self->log_append("Format: mydesc <text>\n"); return; }
  if($self->{'TYPE'}!=1) { $self->log_append("Only players can change their descriptions.\n"); return; }
  $main::pdescs_req{lc $self->{'NAME'}}=$cap;
  $self->pdesc_status;
  return;
}

sub pdesc_status {
  my ($self) = @_;
  if($self->{'TYPE'}!=1) { $self->log_append("Only players can change their descriptions.\n"); return; }
  my $cap;
  $cap = "{1}Current Description:\n   {2}".$self->desc_hard."\n\n{1}Requested Description:\n   ";
  if($main::pdescs_req{lc $self->{'NAME'}}) { $cap .= '{2}'.$main::pdescs_req{lc $self->{'NAME'}}; }
  else { $cap .= '{16}< none >'; }
  $cap .= "\n{1}[ an admin will approve or disapprove your description ]\n";
       $cap .= "[ in due time from its changing. if your desc is not   ]\n";
       $cap .= "[ approved, it will be reset to {6}< none >{1}               ]\n";
  $self->log_append($cap);
  return;
}

sub pdescs_list {
  # lists requested pdescs
  my $self = shift;
  return $self->log_append("{17}You are not allowed to scan pdescs.\n") if (!$self->{'ADMIN'} && !$self->{'OVERSEER'});
  my ($cap, $i, $n);
  $n=0;
  foreach $i (keys(%main::pdescs_req)) {
     $cap .= "{1}$i {16})\n   {2}$main::pdescs_req{$i}\n";
     $n++; last if ($n==5); # end loop if it has 5 already.
  }
  $self->log_append("{13}Descs waiting to be approved:\n{6}Type 'deny <name>' or 'approve <name>' to manage.\n".$cap);
  return;
}

sub pdesc_deny {
  # lists requested pdescs
  my ($self, $name) = @_;
  return $self->log_append("{17}You are not allowed to deny pdescs.\n") if (!$self->{'ADMIN'} && !$self->{'OVERSEER'});
  $name = lc $name;
  if(!$main::pdescs_req{$name}) { $self->log_append("{16}$name does not have a description request.\n"); return; }
  $self->log_append("{12}$name has been denied!\n");
  delete $main::pdescs_req{$name};
  if($main::activeuids->{lc($name)}) { &rockobj::obj_lookup($main::activeuids->{lc($name)})->log_append("{16}**** Your description has been denied.\n**** Please submit a more suitable description next time.\n**** Remember: custom descriptions are a privelege,\n**** not a right.\n"); }
  return;
}

sub pdesc_approve {
  # lists requested pdescs
  my ($self, $name) = @_;
  return $self->log_append("{17}You are not allowed to approve pdescs.\n") if (!$self->{'ADMIN'} && !$self->{'OVERSEER'});
  
  $name = lc $name;
  if(!$main::pdescs_req{$name}) { $self->log_append("{16}$name does not have a description request.\n"); return; }
  $self->log_append("{12}$name has been approved!\n");
  $main::pdescs{$name} = $main::pdescs_req{$name};
  delete $main::pdescs_req{$name};
  if($main::activeuids->{lc($name)}) { &rockobj::obj_lookup($main::activeuids->{lc($name)})->log_append("{16}**** Your player description has been approved!\n"); }
  return;
}

sub stk_unsecure {
 # looks at item with name $iname
 my ($self, $iname) = @_;
 if(!$iname) { $self->log_append("{3}You've got to decide on something to unsecure.\n"); return; }
 if (lc($iname) eq 'all') {
   my $o; foreach $o ($self->stk_objs) { $self->stk_hunsecure($o); }
   return 1;
 }
 my ($success, $item) = $self->inv_cgetobj($iname, 0, $self->stk_objs, undef);
 if($success==1) { 
    $self->stk_hunsecure($item);
    return(1);
 } elsif($success == 0) { $self->log_append("{3}You you have no $iname in storage.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub stk_hunsecure {
 my ($self, $o) = @_;
 if(!$main::map->[$self->{'ROOM'}]->{'SECURITY'}) { $self->log_append("You cannot unsecure items from here.\n"); return; }
 if(!$self->inv_free()) { $self->log_append("You have no room to hold $o->{'NAME'}.\n"); return; }
 $self->log_append("{3}You unsecure $o->{'NAME'}.\n");
 $self->room_sighttell("{3}$self->{'NAME'} unsecures $o->{'NAME'}.\n");
 $self->stk_del($o);
 $self->inv_add($o);
 return;
}

sub stk_list {
  my $self = shift;
  if (scalar($self->stk_objs)==0) { $self->log_append("{6}You have no objects in secure storage.\n"); }
  else { 
    my (@o, $o);
    foreach $o ($self->stk_objs) { push(@o, $o->{'NAME'}); }
    $self->log_append("{16}-={13}SECURED ITEMS{16}=- {17}".join(', ', @o)."\n");
  }
  return;
}


### FOR SUBGAMES ###

sub exp_make_backup {
  my $self = shift;
  
  # This function should not be seen so much as a low-level "copy my exp-related stuff to
  # the temp slot" as this function REALLY does a "make sure my player's LEGITIMATE, non-arena
  # stats are stored in a temp slot". So in theory, one call to exp_make_backup should be the
  # same as multiple calls to it.
  #
  
  
  
  # Try RESTORING first -- dont write over the backup file twice
  # Sure, this is implicit, but it's the safe way to go. Usually you dont
  # make a backup twice in a row. :)
  $self->exp_restore_backup();
  
  $self->effect_end_all();

  my $item;
  foreach $item ($self->inv_objs) {
    if( ($item->{'WORN'}) && (!$self->item_hremove($item, 1)) ){ return(0); }
    if( ($item->{'EQD'}) && (!$self->item_hunequip) ){ return(0); }
  }
  $self->{'TEMPEXP'}=$self->{'EXP'}; $self->{'EXP'} = [];
  $self->{'TEMPINV'}=$self->{'INV'}; $self->{'INV'} = {};
  $self->{'TEMPVIGOR'}=$self->{'VIGOR'};   $self->{'VIGOR'} = 0.5;
  $self->{'TEMPNEWBIE'}=$self->{'NEWBIE'};   delete $self->{'NEWBIE'};
  $self->{'TEMPLASTPVP'}=$self->{'LASTPVP'}; delete $self->{'LASTPVP'};
  $self->{'TEMPEXPPHY'}=$self->{'EXPPHY'}||0; delete $self->{'EXPPHY'}; 
  $self->{'TEMPEXPMEN'}=$self->{'EXPMEN'}||0; delete $self->{'EXPMEN'};
  return(1);
}

sub exp_restore_backup {
  my $self = shift;
  my $change = 0;
  if(ref($self->{'TEMPEXP'}) eq 'ARRAY') { 
      my $t;
      
      foreach my $i (@{$self->{'TEMPEXP'}}) {
         $t += $i;
      }
      
      if($t >= 17) { 
          @{$self->{'EXP'}}=@{$self->{'TEMPEXP'}}; delete $self->{'TEMPEXP'}; $change=1;
      } else {
          &main::rock_shout(undef, "{1}EXP RESTORE ERROR: $self->{'NAME'} [exp total: $t].\n", 1);
          &main::mail_send($main::rock_admin_email, "EXP RESTORE ERROR FOR $self->{'NAME'}", "EXP RESTORE ERROR: $self->{'NAME'} [exp total: $t]. WARNING: THIS USER NOW HAS THE ARENA EXP MAYBE. PLEASE CHECK LOGS.\n");
      }
  }
  if(ref($self->{'TEMPINV'}) eq 'HASH') { 
      # dissolve inventory objects if they're still $main::objs->{}'d
      my $i; foreach $i (values(%{$self->{'INV'}})) { if($main::objs->{$i->{'OBJID'}} eq $i) { $i->dissolve_allsubs; } }
      my $a; foreach $a (@{$self->{'APRL'}}) { delete $self->{$a->{'ATYPE'}}; } delete $self->{'APRL'};
      delete $self->{'WEAPON'}; # no weapon 4 u!
      %{$self->{'INV'}}=%{$self->{'TEMPINV'}};
      delete $self->{'TEMPINV'}; $change=1;
  }
      
  if("$self->{'TEMPRACE'}" ne "") { $self->{'RACE'}=$self->{'TEMPRACE'}; delete $self->{'TEMPRACE'}; $change=1; }
  if(defined $self->{'TEMPDROOM'}) { delete $self->{'TEMPDROOM'}; $change=1; }
  if(defined $self->{'TEMPEXPPHY'}) { $self->{'EXPPHY'}=$self->{'TEMPEXPPHY'}; delete $self->{'TEMPEXPPHY'}; $change=1; }
  if(defined $self->{'TEMPEXPMEN'}) { $self->{'EXPMEN'}=$self->{'TEMPEXPMEN'}; delete $self->{'TEMPEXPMEN'}; $change=1; }
  if(defined $self->{'TEMPVIGOR'}) { $self->{'VIGOR'}=$self->{'TEMPVIGOR'}; delete $self->{'TEMPVIGOR'}; $change=1; }
  if($self->{'TEMPNEWBIE'}) { $self->{'NEWBIE'}=$self->{'TEMPNEWBIE'}; delete $self->{'TEMPNEWBIE'}; $change=1; }
  if($self->{'TEMPLASTPVP'}) { $self->{'LASTPVP'}=$self->{'TEMPLASTPVP'}; delete $self->{'TEMPLASTPVP'}; $change=1; }
  if($self->{'GAME'}) { delete $self->{'GAME'}; $change=1; }
  
  delete $self->{'TEMPINV'};
  delete $self->{'TEMPEXP'};

  

  if($change) { $self->effect_end_all(); $self->power_up(); }
  

  $self->stats_update;

  return($change);
}

#my $o = $main::objs->{29108}; $main::map->[$_[0]->{'ROOM'}]->inv_del($o); $_[0]->{'TEMPINV'}->{$o->{'OBJID'}}=$o; $o->{'CONTAINEDBY'}=$_[0]->{'OBJID'};


sub aprl_synch {
  # gets rid of apparel keys we dont have
  my $self = shift;
  my ($k, %a, $a);
  foreach $a (@{$self->{'APRL'}}) { $a{$a->{'ATYPE'}} = 1; }
  foreach $k (keys(%{$self})) { if( (lc($k) eq $k) && !$a{$k} ) { print "## $self->{'NAME'}: deleting $self->{$k}\n"; } }
  return;
}

sub user_mute {
    my ($self, $uid) = @_;
    unless($self->{'ADMIN'} || $self->{'OVERSEER'}) {
        $self->log_error("This option is only available for admins and overseers.");
        return;
    }
    unless($uid) { $self->log_error("Mute Who?"); return; }

    my $recip;
    return unless($recip = $self->uid_resolve($uid));
    
    $recip->log_append("{16}Your voice will be temporarily muted.\n{17}Watch what you say in the future!\n");
    $self->admin_log("{17}Muted $recip->{'NAME'}.\n");
    $recip->effect_add(26);
    $self->log_append("{2}- {17}notified and muted $recip->{'NAME'} {2}-\n");
    return;
}


sub feedback_add_effect {
    my ($self, $recip, $effect) = @_;
    unless($recip) { $self->log_error("Object does not exist."); return; }
    if($effect eq '') { $self->log_error("What effect?"); return; }
    $effect = int $effect;
    unless(defined($main::effectbase->[$effect])) { $self->log_error("Effect number $effect does not exist."); return; } 
    $recip->effect_add($effect);

    $self->log_appendline("{2}$recip->{'NAME'} {7}({1}#$recip->{'OBJID'}\{7}): {7}effect {17}$effect {7}added.");
    return;
}

sub feedback_get_effect {
    my ($self, $recip, $effect) = @_;
    unless($recip) { $self->log_error("Object does not exist."); return; }
    if($effect eq '') { $self->log_error("What effect?"); return; }
    $effect = int $effect;
    unless(defined($main::effectbase->[$effect])) { $self->log_error("Effect number $effect does not exist."); return; }

    if(ref($recip->{'FX'}) ne 'HASH' || !%{$recip->{'FX'}}) {
        $self->log_error("No effects exist on $recip->{'NAME'}, especially $effect");
        return;
    }
    unless($recip->{'FX'}->{$effect}) {
        $self->log_error("$recip->{'NAME'} does not have effect $effect");
        return;
    }
    my $timeleft = $recip->{'FX'}->{$effect} - time;
    my $edesc = $main::effectbase->[$effect]->[2];

    $self->log_appendline("{2}$recip->{'NAME'} {7}({1}#$recip->{'OBJID'}\{7}): {17}$timeleft second(s){7} left for '{17}$edesc\{7}'");
    return;
}

sub feedback_get_var {
    my ($self, $recip, $var) = @_;
    unless($recip) { $self->log_error("Object does not exist."); return; }
    if($var eq '') { $self->log_error("Which variable?"); return; }
    $var = uc $var;
    my $val = defined($recip->{$var}) ? $recip->{$var} : '[undefined]';
    $self->log_appendline("{2}$recip->{'NAME'} {7}({1}#$recip->{'OBJID'}\{7}): {17}$var {7}is{17} $val\{7}.");
}

sub feedback_set_var {
    my ($self, $recip, $var, $val) = @_;
    unless($recip) { $self->log_error("Object does not exist."); return; }
    if($var eq '') { $self->log_error("Which variable?"); return; }
    $var = uc $var;
    my $printval = defined($val) ? $val : '[undefined]';
    $recip->{$var} = $val;
    $self->log_appendline("{2}$recip->{'NAME'} {7}({1}#$recip->{'OBJID'}\{7}): {17}$var {7}set to{17} $printval\{7}.");
}


sub spell_ebony_blast() {
 my ($self, $v) = @_;
 if(!$v->is_dead) {
    my $dam = int (&main::dice(35,60) * (1-$v->fuzz_pct_skill(20, 500)));
    
    $v->room_sighttell("{1}$self->{'NAME'} launches an ebony blast of energy at $v->{'NAME'}, doing $dam damage!\n");
    $v->log_append("{1}$self->{'NAME'} launches an ebony blast of energy at you, doing $dam damage!\n");
    
    $v->{'HP'} -= $dam;
   if($v->{'HP'}<=0) { $v->die(); }
 }
}

sub item_throw {
  my ($self, $cap) = @_;
  
  if(!$cap) { $self->log_append("{7}The format is: {17}throw {17}<direction|target>\n"); return; }

  if($self->is_tired()) { $self->log_append("{3}You are too exhausted to do that right now.\n"); $self->make_tired(); return; }
  if(!$self->can_do(0,0,5)) { return; }
  
  # see if we have an item equipped..
  if(!$self->{'WEAPON'} || (!$self->inv_has($main::objs->{$self->{'WEAPON'}})) ) {
    $self->log_append("{7}You must be wielding the item in order to throw it.\n");
    return;
  }

  # check for directional first..
  if($main::dircondensemap{lc($cap)}) {
    $self->item_hthrow_dir($main::objs->{$self->{'WEAPON'}}, $main::dircondensemap{lc($cap)});
    $self->make_tired();
  } else { 
    my ($success, $targ) = $main::map->[$self->{'ROOM'}]->inv_cgetobj($cap,0);
    if($success == 1) { 
      $self->item_hthrow_targ($main::objs->{$self->{'WEAPON'}}, $targ);
      $self->make_tired();
    } elsif($success == 0) { $self->log_append("{7}Huh? The format is: {17}throw {17}<direction|target>\n"); return(0); }
    elsif($success == -1) { $self->log_append($targ); return(0); }
  }
  return;
}



sub item_hthrow_dir {
 my ($self, $item, $dir) = @_;
 
 if( !$self->inv_has($item) ){ return(0); }

 # untie
 if($self->{'WEAPON'} == $item->{'OBJID'}) {  
    if( eval { !$item->can_unequip($self) } ) { 
        $self->log_append("{3}You are unable to disarm $item->{'NAME'}.\n");
        return(0);
    }
    delete $self->{'WEAPON'}; delete $item->{'EQD'};
 }
 $self->inv_del($item);

 my $r = $main::map->[$self->{'ROOM'}];
 
 # if it can go in that dir..
 if($r->{$dir}->[0] && !$r->{$dir}->[1]) {
	 $self->room_sighttell("{17}$self->{'NAME'} {7}throws {5}$item->{'NAME'} {7}$main::dirlongmap{$dir}\.\n");
	 $self->log_append("{7}You throw {5}$item->{'NAME'} {7}$main::dirlongmap{$dir}\.\n");
	 $r = $main::map->[$r->{$dir}->[0]];
	 $r->room_sighttell("{7}$item->{'NAME'} {17}is hurdled into the room from $main::dirfrommap{$main::diroppmap{$dir}}.\n");
	 $r->inv_add($item);
	 $r->tell(15, 1, 0, undef, $item, $self, $main::diroppmap{$dir});
	 $item->on_throwdir($dir, $self);
 } else {
	 # otherwise..
	 $self->log_append("{7}You throw {5}$item->{'NAME'} {7}toward the $main::dirernmap{$dir} $main::dirwall{$dir}\.\n");
	 $self->room_sighttell("{17}$self->{'NAME'} {7}throws {5}$item->{'NAME'} {7}toward the $main::dirernmap{$dir} $main::dirwall{$dir}\.\n");
	 $r->inv_add($item);
	 $r->tell(15, 1, 0, undef, $item, $self);
 }
 return; 
}

sub on_itemthrew (item, thrower, fromdir) {}   #my ($self, $item, $thrower, $fromdir) = @_;


sub item_hthrow_targ {
 my ($self, $item, $targ) = @_;
 
 if($self eq $targ) { $self->log_append("{1}Throw it at yourself? Are you insane?\n"); return; }
 
 return if $self->log_cant_aggress_against($targ);
 
 if( !$self->inv_has($item) ){ return(0); }

 # untie
 if($self->{'WEAPON'} == $item->{'OBJID'}) {  
    if( eval { !$item->can_unequip($self) } ) { 
        $self->log_append("{3}You are unable to disarm $item->{'NAME'}.\n");
        return(0);
    }
    delete $self->{'WEAPON'}; delete $item->{'EQD'};
 }
 $self->inv_del($item);

 my $r = $main::map->[$self->{'ROOM'}];
 
 $r->inv_add($item);
 if(rand(100)<50 || $item->{'GUARANTEED_THROW'}){
#mich changed color of at because it was irritating him
   $self->log_append("{7}You throw {5}$item->{'NAME'} {7}at {17}$targ->{'NAME'}\.\n");
   $self->room_sighttell("{17}$self->{'NAME'} {7}throws {5}$item->{'NAME'} {7}at {17}$targ->{'NAME'}\.\n");
   my $dam = int ($item->{'MASS'}*8*$self->fuzz_pct_skill(17)/($item->{'VOL'} || 1));
   if(!$targ->is_dead && $dam && ($targ->{'TYPE'}>=1) && !$targ->{'NEWBIE'}) { 
     if ($self->{'TYPE'}==1 && $targ->{'TYPE'}==1 && (!$self->{'SOLDIER'} || !$targ->{'SOLDIER'}) && !$self->{'GAME'} && (abs($targ->{'LEV'} - $self->{'LEV'}) > $main::pvp_restrict) ) { $dam = int rand(5)+1; }
     $targ->{'HP'} -= $dam;
     $targ->log_append("{1}You take $dam damage!\n");
     
     if($targ->is_dead) { $targ->die($self); }
   }
   $item->on_throw($targ, $self);
 } else {
   $self->log_append("{7}You fling {5}$item->{'NAME'} {7}at {17}$targ->{'NAME'} and blatantly miss\.\n");
   $self->room_sighttell("{17}$self->{'NAME'} {7}throws {5}$item->{'NAME'} {7}at {17}$targ->{'NAME'}, blatantly missing\.\n");
 }
 $self->note_attack_against($targ);
 
 # npcs auto-retaliate
 if($targ->{'TYPE'}>=1) { $targ->attack_sing($self); }
 return; 
}

sub on_throw(at,bywho) { }

#
# Course Subs
#

sub course_add {
  my $self = shift;
  foreach my $course (@_) {
    if(!$main::courses{$course}) { $self->log_append("{3}No such course.\n"); }
    elsif(scalar(keys(%{$self->{'CRS'}})) >= 3) { $self->log_append("{3}You can only be enrolled in up to 3 classes per day.\n"); }
    elsif($self->course_had($course)) { $self->log_append("{3}You already took that course.\n"); }
    elsif($self->course_has($course)) { $self->log_append("{3}You are already taking that course.\n"); }
    elsif($main::map->[$self->{'ROOM'}]->{'ACADEMY'} ne $main::courses{$course}->[8]) { $self->log_append("{17}This isn't the right place to sign up!\n"); return; }
    elsif(!&{$main::courses{$course}->[4]}($self)) { $self->log_append("{3}You are unable to take that course.\n"); }
    elsif($self->{'CRYL'}<$main::courses{$course}->[2]) { $self->log_append("{3}You need ".($main::courses{$course}->[2]-$self->{'CRYL'})." more cryl before you can take that course.\n"); }
    else { 
      $self->{'CRYL'}-=$main::courses{$course}->[2];
      $self->{'CRS'}->{$course}=$main::courses{$course}->[3]; 
      $self->log_append("{13}*** You have been enrolled in a $course course, for which you will need $main::courses{$course}->[3] training periods to complete.\n");
      $self->room_tell("{13}*** $self->{'NAME'} has been enrolled into the {12}$course {13}course!\n");
    }
  }
  return;
}


sub course_update (coursename){
  my ($self, $k) = @_;
  
  my $keycount = scalar(keys(%{$self->{'CRS'}}));
  return unless $keycount;
  my $c = int ((10+7*$self->fuzz_pct_skill(0, 200)) / $keycount * $main::lightning_course_point_multiplier);
  
  if (defined($self->{'CRS'}->{$k})) {
    $self->{'CRS'}->{$k}-=$c;
    
    if ($self->{'CRS'}->{$k}<=0) {
        &{$main::courses{$k}->[5]}($self);
        $self->course_del($k);
        $self->chist_add($main::courses{$k}->[0]);
        &main::log_event("Complete Course", "$self->{'NAME'} has completed $self->{'PPOS'} \"$k\" course.", $self->{'UIN'});
    }
  }
  return;
}

sub course_inv {
 my $self = shift;
 if(!$self->{'CRS'} || !(scalar(%{$self->{'CRS'}}))) { $self->log_append("{1}You are not currently taking any courses.\n"); return; }
 
 my $cap;
 $cap .= sprintf('{13}%15s {6}--{16}=={17}> {13}%s'."\n", 'COURSE NAME', 'TRAINING PERIODS REMAINING');
 
 foreach my $k (keys(%{$self->{'CRS'}})) {
    $cap .= sprintf('{2}%15s {6}--{16}=={17}> %03d'."\n", $k, $self->{'CRS'}->{$k});
 }
 $self->log_append($cap);
}

sub course_del {
   my $self = shift;
   foreach my $course (@_) {
      delete $self->{'CRS'}->{$course};
   }
   return;
}

sub course_has {
  my ($self, $id) = @_;
  if(defined($main::courses{$id})) { $id = $main::courses{$id}->[0]; }

  if($self->{'CRS'} && defined(%{$self->{'CRS'}})) { 
    foreach my $k (keys(%{$self->{'CRS'}})) {
      if($main::courses{$k}->[0] == $id) { return(1); }
    }
  }
  return(0);
}

sub course_had {
  my ($self, $id) = @_;
  
  if(defined($main::courses{$id})) { $id = $main::courses{$id}->[0]; }
  
  return($self->chist_has($id));
}


# chist == course history; courses that have been COMPLETED.. previously taken.
sub chist_add() {
  my $self = shift;
  while(@_) { vec($self->{'CHIST'}, shift(@_), 1) = 1;  }
}

sub chist_has() {
  my $self = shift;
  my $success = 1;
  while(@_) { if(!vec($self->{'CHIST'}, shift(@_), 1)) { $success = 0; }  }
  return($success);
}


sub pstat_raise (stat, amt) {
	# raises STAT by amount AMT
	my ($self, $stat, $amt, $silent) = @_;
	
	if (lc($stat) eq 'auto') { $self->exp_cycle(); return(1); }
	
	if (!$stat && !$amt) {
	    $self->stats_raiselist();
		$self->log_error("Syntax: raise <stat abbreviation> <max levels to raise>");
		return(1);
    }
	
	$stat = uc $stat; 
	my $sname = $stat;
	$amt = int $amt;
	
	$amt = 1 if $amt < 1;
	$amt = 1000 if $amt > 1000;
	
	if( ($stat>=6 && $stat<=22) || defined($main::parr{$stat})) {
    	 
	     $stat = $main::parr{$stat} || int $stat;
		 
    	 if($self->{'EXP'}->[$stat] >= 1000000000) {
             $self->log_append("{1}You cannot raise your $sname any further.\n");
             return(0);
    	 }
    	 
		 my $rby=0;
    	 for (my $n=1; $n<=$amt; $n++) { 
        	 last if($self->{'EXP'}->[$stat] >= 1000000000);
        	 my $e = $self->exp_need($stat);
        	 # transfer exp
        	 if ($e <= $self->{$main::eclass[$stat]}) { 
        		 $self->{'EXP'}->[$stat] += $self->exp_need($stat, 1);
        		 $self->{$main::eclass[$stat]}-=$e;
        		 $rby++;
        	 } else {
			     $n=$amt;
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

	return(1);
}

sub exp_need(statnum) {
     my ($self, $stat, $abs) = @_;
     
     my $sval = ( $self->{'EXP'}->[$stat] && (int ((abs($self->{'EXP'}->[$stat]+1))**(1/3))) );
     if($self->{'EXP'}->[$stat]<0) { $sval *= -1; }
     
     my $expneeded = ( (($sval+1)**3) - $self->{'EXP'}->[$stat] );
       
     if(!$abs) { 
       if($main::race_mult[$self->{'RACE'}]) { $expneeded *= ( (1.8-$main::race_mult[$self->{'RACE'}]->[$stat])**3 ); }
     }
     return($expneeded);
}

sub exp_cycle {
  #####################################
  # This does the raise-auto stuff!!
  ######################################
  
  my $self = shift;
  my $quiet_on_failure = shift;
  
  $self->stats_update();
  my $stat;
  my %sh;
  my $success = 1;

  # Commented out until it works better
  #if($self->{'ADMIN'} && defined($self->{'RAISE_PCT'})) {
  #      $self->exp_raiseautopct();
  #      return;
  #}
  
  my $pref_stats = $self->{'AUTORAISE_STATS'}; # preferred autoraise stats. CAN BE UNDEF!!!

  my ($lowstat, $lowval);
  do { 
     $lowstat=0;
     for($stat=6; $stat<=22; $stat++) {
         # skip the stat unless it's in the preferences (or there are no prefs)
         next unless !$pref_stats || defined($pref_stats->{$stat});

          my $n = $self->exp_need($stat);
         if( 
            ( ($n < $lowval) || (!$lowstat) )
          && ($self->{$main::eclass[$stat]} >= $n)
          && ($self->{'EXP'}->[$stat]<1000000000)
         ) { $lowstat = $stat; $lowval = $n; }
     }

     if($lowstat) { 
      $success = $self->pstat_raise($main::rparr{$lowstat}, 1, 1);
      $sh{$main::rparr{$lowstat}}+= $success;
     } else { $success = 0; }

  } while ($success);
  
  $self->stats_update;
  if(scalar %sh) { 
    my $c = "{1}The following stats were raised for you:";
    my ($a, $b) = 1;
    while($a) { ($a, $b) = each(%sh); if($a) { $c .= "  {17}$a\: {12}$b."; } }
    $self->log_append($c."\n");
  } else {
    $self->log_append("{1}No stats could be auto-raised for you. Try typing {17}raise auto{1} later, when you have more experience!\n")
    unless $quiet_on_failure;
  }
  return;
}

sub statnum_lowest {
  my $self = shift;
  # this accounts for armour/etc.
  # would be a good idea to stats_update before calling me
  my ($l, $ln);
  $l = $self->{'STAT'}->[6];
  $ln=6;
  for (my $n=6; $n<=22; $n++) {
   if($self->{'STAT'}->[$n]<$l) {
    $l = $self->{'STAT'}->[$n];
    $ln=$n;
   }
  }
  return($ln);
}

sub item_fill (str) {
   my ($self, $str) = @_; $str = lc($str);
   if (index($str, ' with ') == -1) {
      $self->log_append("{3}The correct usage is:\n{1}fill [object name] with [recipient name].\n");
      return(-1);
   } else { 
      my ($successa, $successb, $pobj, $iobj, $iname, $pname);
      while (index($str, '  ') > -1) { $str =~ s/  / /g; }
      ($iname, $pname) = split(/ with /,$str);

      ($successa, $iobj) = $self->inv_cgetobj($iname, 0, $self->inv_objs );
      ($successb, $pobj) = $self->inv_cgetobj($pname, 0, $main::map->[$self->{'ROOM'}]->inv_objs,$self->inv_objs );
      if ( ($successa == 1) && ($successb == 1) ) {   
         $self->item_hfill($iobj, $pobj);
      }
      elsif ( $successa == 0 ) { $self->log_append("{3}You don't have any $iname to fill up.\n"); }
      elsif ( $successb == 0 ) { $self->log_append("{3}You don't see any $pname here.\n"); }
      elsif ( $successa == -1 ) { $self->log_append("{7}Fill What!? ".$iobj); }
      elsif ( $successb == -1 ) { $self->log_append("{7}With What!? ".$pobj); }
   }
   return;
}

sub item_hfill {
 my ($self, $i, $withwhat) = @_;
 if(!$i->{'FILLABLE'}) { $self->log_append("{2}You'd never be able to get $withwhat->{'NAME'} in THERE!\n"); return; }
 if(!$main::fill{$i->{'REC'}}->{$withwhat->{'REC'}}) { $self->log_append("{1}You don't think anything productive would happen.\n"); return; }
 if(!$self->can_do(0,0,10)) { return; }
 $self->room_tell("{13}$self->{'NAME'} {4}fills $i->{'NAME'} with $withwhat->{'NAME'}.\n");
 $self->log_append("{13}You fill $i->{'NAME'} with $withwhat->{'NAME'}.\n");
 $main::objs->{$i->{'CONTAINEDBY'}}->item_spawn($main::fill{$i->{'REC'}}->{$withwhat->{'REC'}});
 $i->obj_dissolve;
}

sub pushed{ $_[1]->log_append("{3}$_[0]->{'NAME'} doesn't like to be pushed.\n"); }
sub smashed{ $_[1]->log_append("{3}Eh? Are you obsessed with bruises or something?\n"); }
sub bashed{ $_[1]->log_append("{3}..you remember all the pointless pain at stake and quickly change your mind.\n"); }

sub scurry(dir) {
 my ($self, $dir, $override) = @_;
 $dir = $main::dircondensemap{lc($dir)};
 if(!$dir) { $self->log_append("{7}The format is: {17}scurry {17}<direction>\n"); return; }
 if( ($self->{'RACE'}!=4) && !$override && !$self->skill_has(15)) { $self->log_append("{6}Your body is too cumbersome to successfully scurry!\n"); return; }
 if($self->{'T'}<25) { $self->log_append("{6}You don't have enough turns to scurry!\n"); return; }
 if(!$self->can_do(0,0,15)) { return; }
 my @olist;
 $self->{'SCURRYACTIVE'}=1;
 foreach my $o ($main::map->[$self->{'ROOM'}]->inv_objs) { 
   if($o->{'STALKING'}==$self->{'OBJID'}) {
     if(rand(100)<75) {
      push(@olist, $o);
      $o->log_append("{4}You are unable to catch up to $self->{'NAME'} as ");
      delete $o->{'STALKING'};
     } else {
      $o->log_append("{4}You notice {14}$self->{'NAME'} {4}making a run for it out of the corner of your eye.\n");
     }
   }
 }
 
 $self->{'ENTMSG'}='scurries in';
 $self->{'LEAMSG'}='scurries out';

 $dir = $main::dircondensemap{lc($dir)};
 $self->realm_move($dir, 1);

 delete $self->{'ENTMSG'};
 delete $self->{'LEAMSG'};

 for(my $n=0; $n<=$#olist; $n++) { $olist[$n]->{'STALKING'}=$self->{'OBJID'}; }
 delete $self->{'SCURRYACTIVE'};
 return;
}

sub inv_rand_item {
 my $self = shift;
 my @a = $self->inv_iobjs;
 return($a[int rand($#a+1)]);
}

sub inv_rand_npc {
 my $self = shift;
 my @a = $self->inv_pobjs;
 return($a[int rand($#a+1)]);
}

sub str_insane {
 my $self = shift;
 my $cap = $main::insane_talk[int rand($#main::insane_talk+1)];
 if(index($cap, '%I') != -1) {
   my $n = $self->inv_rand_item; if ($n) { $n = lc($n->{'NAME'}); } else { $n = lc($self->{'NAME'}); }
   $cap =~ s/\%I/$n/g;
 }
 if(index($cap, '%R') != -1) {
   my $n = $main::map->[$self->{'ROOM'}]->inv_rand_npc;
   if ($n) { $n = lc($n->{'NAME'}); } else { $n = lc($self->{'NAME'}); }
   $cap =~ s/\%R/$n/g;
 }
 return($cap);
}

sub skill_add(bank, num) {
  my $self = shift;

  if (@_ > 2) {
	  &main::rock_shout(undef, "skill_add DIDN'T EXPECT THIS SKILL_HAS COMBO: @_", 1);
	  return 0;
  }
  if (@_ == 2) {
	  my @sarr = unpack('L*', $self->{'@SKIL'});
	  while(@_) {
    	  # print "$sarr[$_[0]] adding (bank $_[0], skill ".(2**$_[1]).")\n";
    	  $sarr[$_[0]] = ( $sarr[$_[0]] | (2**$_[1]) ); # add number to bank (num is anywhere from 0 -> 32)
    	  shift(@_); shift(@_); 
	  }
	  $self->{'@SKIL'}=pack('L*', @sarr); 
  } else {
	  while(@_) {
#  	&main::rock_shout(undef, "ADD NEW STYLE!\n", 1);
	      # new style
          vec($self->{'@SKIL'}, $_[0], 1) = 1;
    	  shift(@_); 
	  }
  }
}

sub skill_del(bank, num) {
  my $self = shift;

  if (@_ > 2) {
	  &main::rock_shout(undef, "skill_del DIDN'T EXPECT THIS SKILL_HAS COMBO: @_", 1);
	  return 0;
  }
  if (@_ == 2) {
	  my @sarr = unpack('L*', $self->{'@SKIL'});
	  while(@_) {
    	if($sarr[$_[0]] & (2**$_[1])) { $sarr[$_[0]] -= (2**$_[1]); } # take number from bank IF it exists (num is anywhere from 0 -> 32)
    	shift(@_); shift(@_); 
	  }
	  $self->{'@SKIL'}=pack('L*', @sarr); 
  } else {
	  while(@_) {
	      # new style
#  	&main::rock_shout(undef, "DEL NEW STYLE!\n", 1);
          vec($self->{'@SKIL'}, $_[0], 1) = 0;
    	  shift(@_); 
	  }
  }
  
}

sub skill_has(bank, num) {
  # Syntax: $has_all = $self->skill_has($skill_id, [$skill_id[, ...]]);
  my $self = shift;

  if (@_ > 1) {
	  &main::rock_shout(undef, "SKILL_HAS DIDN'T EXPECT THIS SKILL_HAS COMBO: @_", 1);
	  return 0;
  }
  
  my $success = 1;
  while(@_) {
    $success = 0 unless vec($self->{'@SKIL'}, $_[0], 1);
#  	&main::rock_shout(undef, "HAS NEW STYLE!\n", 1);
    shift(@_);
  }
  return($success);
}

### Quest info - uses bit vector, NO BANKs
###

sub quest_add() {
  my $self = shift;
  while(@_) { vec($self->{'QUEST'}, shift(@_), 1) = 1;  }
}

sub quest_del() {
  my $self = shift;
  while(@_) { vec($self->{'QUEST'}, shift(@_), 1) = 0;  }
}

sub quest_has() {
  my $self = shift;
  my $success = 1;
  while(@_) { if(!vec($self->{'QUEST'}, shift(@_), 1)) { $success = 0; }  }
  return($success);
}

sub course_signup {
  my ($self, $cname) = @_;
  $cname = lc $cname;
  if(!$main::map->[$self->{'ROOM'}]->{'COURSEREG'}) { $self->log_error("Well, you OBVIOUSLY need the schooling if you can't tell this isn't a Registration Office!"); return; }
  $self->course_add($cname);
  return;
}

sub course_drop {
    # Attempts to unenroll me from course of name $course.
    my ($self, $course) = @_;

    $course = lc $course;

    if (!$main::map->[$self->{'ROOM'}]->{'COURSEREG'}) { $self->log_error("Maybe you should reconsider; you OBVIOUSLY need the schooling if you can't tell this isn't a Registration Office!"); }
    elsif (!$main::courses{$course}) { $self->log_error("There is no course named \"$course\""); }
    elsif (!$self->course_has($course)) { $self->log_error("You are not currently taking that course."); }
    else {

        # Tell them what's going on
        $self->log_append("{13}*** You have unenrolled yourself from the $course course.\n");
        $self->room_sighttell("{13}*** $self->{'NAME'} has unenrolled $self->{'PPRO'}self from the $course course.\n");
        
        # Check for potential refund, based on how many trainign periods they already sucked
        # up with this course.
        my $pct_left = $self->{'CRS'}->{$course}/$main::courses{$course}->[3]; 
        my $cryl_back = int($pct_left * int $main::courses{$course}->[2]);
        if ($cryl_back > 0) {
            $self->log_append("{13}*** You are refunded $cryl_back cryl for the remaining portion of your course.\n");
            $self->{'CRYL'} += $cryl_back;
        }

        # remove course from me list.
        $self->course_del($course);
    }
    return;
}

  # room -> objid -> course name = ending time
sub course_checkin {
	my ($self, $coursename) = @_;
	$coursename = lc($coursename);

	if (!defined($main::courses{$coursename})) {
    	$self->log_error("Syntax: {7}checkin <course name>\n");
		return;
	}

	if (!$self->course_has($coursename)) {
	  $self->log_append("{17}You're not even taking that course!!\n");
	  return;
	}

	if (defined($main::course_log{$self->{'ROOM'}}->{$self->{'OBJID'}}) && defined($main::course_log{$self->{'ROOM'}}->{$self->{'OBJID'}}->{$coursename})) {
    	$self->log_error("You notice that your name is already on the list!");
		return;
	}

	if( $main::courses{$coursename}->[7] && ($main::roomaliases{$main::courses{$coursename}->[7]} != $self->{'ROOM'})) {
    	$self->log_error("This doesn't look like a $coursename classroom to you.");
		return;
	}

	if($self->todaycourse_has($main::courses{$coursename}->[0])) {
    	$self->log_error("You've already attended that class today; what would you ever learn?");
    	return;
	}

	my $course_secs = int($main::max_course_wait_time -  $main::max_course_wait_time/2*$self->fuzz_pct_skill(KNO, 200)); # Higher KNO reduces class wait time up to 50%
	$main::course_log{$self->{'ROOM'}}->{$self->{'OBJID'}}->{$coursename}= time + $course_secs;
	$self->log_append("{13}You check into your $coursename class.\n");
	$self->room_tell("{13}$self->{'NAME'} checks into $self->{'PPOS'} $coursename class.\n");
}

sub todaycourse_add() {
  my $self = shift;
  while(@_) { vec($self->{'TCOURSE'}, shift(@_), 1) = 1;  }
}

sub todaycourse_has() {
  my $self = shift;
  my $success = 1;
  while(@_) { if(!vec($self->{'TCOURSE'}, shift(@_), 1)) { $success = 0; }  }
  return($success);
}

sub skills_list {
  my $self = shift;
  my ($cap, @cap, $skildata, $q);
  for(my $n=0; $n<@main::skillinfo; $n++) {
      if($self->skill_has($n)) { push(@cap, sprintf("\{16}\%-30s \{6}\%s\n", @{$main::skillinfo[$n]}) ); }
  }
  if(defined($self->{'GIFT'}->{'BMAN1'})) { push(@cap, sprintf("\{16}\%-30s \{6}\%s\n", 'Biomancy 1', '"cast <rfles|rmusc|rbone> <target>"')); }
  if(defined($self->{'GIFT'}->{'PORTENTS'})) { push(@cap, sprintf("\{16}\%-30s \{6}\%s\n", 'Portents', '"portents <target>"')); }
  if($main::rock_stats{'monolith_shadow'}==$self->{'RACE'}) { push(@cap, sprintf("\{16}\%-30s%11s \{6}\%s\n", '{6}G{16}re{17}ater Obfuscat{16}io{6}n','', '"obfuscate"')); }
  if($self->{'SOLDIER'} && $main::rock_stats{'monolith_spectral'}==$self->{'RACE'}) { push(@cap, sprintf("\{16}\%-30s%18s \{6}\%s\n", '{6}Sum{16}mon{17}M{16}ira{6}ge','', '"summon mirage"')); }
  if($self->{'SOLDIER'} && $main::rock_stats{'monolith_temporal'}==$self->{'RACE'}) { push(@cap, sprintf("\{16}\%-30s%18s \{6}\%s\n", '{6}D{16}r{17}a{16}w{6}','', '"draw [number of turns to extract]"')); }
  if($self->{'SOLDIER'} && $main::rock_stats{'monolith_pearled'}==$self->{'RACE'}) { push(@cap, sprintf("\{16}\%-30s%18s \{6}\%s\n", '{6}F{16}ar{17}sh{16}ar{6}e','', '"give <item name> to <soldier of same race>"')); }
  if($self->{'GENERAL'} && $main::rock_stats{'monolith_pearled'}==$self->{'RACE'}) { push(@cap, sprintf("\{16}\%-30s%18s \{6}\%s\n", '{6}A{16}l{17}lwe{16}l{6}l','', '"allwell"')); }
  if(!@cap) { $cap = "{13}You ain't got no skillz!\n"; }
  else { @cap = sort (@cap); $cap = "{13}Current skills learned:\n".join('',@cap); }
  $self->log_append($cap);
}

sub race_ally() {
  my ($self, $racename) = @_;
  if(!$racename) { $self->log_append("{3}Format: ally <racename>\n"); return; }
  if(!$self->{'GENERAL'}) { $self->log_append("{17}You are not in any position to decide the allies of your race.\n"); return; }
  if(!defined($main::racetonum{lc($racename)})) { $self->log_append("{17}Since when is {1}$racename {17}a race?\n"); return; }
  my $ally = $main::racetonum{lc($racename)};
  if(($self->{'RACE'}<1) || ($self->{'RACE'}>5)) { $self->log_append("{17}..not while you're $main::races[$self->{'RACE'}].\n"); return; }
  if(($ally<1) || ($ally>5)) { $self->log_append("{17}Even YOU cannot ally with that race!\n"); return; }
  if($self->{'RACE'} == $ally) { $self->log_append("{17}Duh, you're always allied with yourself!\n"); return; }
  if($main::rock_stats{'rally-'.$self->{'RACE'}.'-'.$ally} ^= 1) { 
     if($main::rock_stats{'rally-'.$ally.'-'.$self->{'RACE'}}) {
          &main::rock_shout(undef, "{17}***** An {16}ALLIANCE {17}has been formed between the {2}$main::races[$self->{'RACE'}] {17}and{2} $main::races[$ally].\n");
          $main::allyfriend[$self->{'RACE'}]->[$ally] = $main::allyfriend[$ally]->[$self->{'RACE'}] = 1;
     } else {
          &main::rock_hrshout($self->{'RACE'}, "{16}***** {2}$self->{'NAME'} has offered our alliance to the {13}$main::races[$ally]s\n");
          &main::rock_hrshout($ally, "{16}***** {2}The {13}$main::races[$self->{'RACE'}]s {2}have offered their alliance to us.\n");
     }
  } else {
     if($main::rock_stats{'rally-'.$ally.'-'.$self->{'RACE'}}) {
          &main::rock_shout(undef, "{17}***** The {16}ALLIANCE {17}between the {2}$main::races[$self->{'RACE'}] {17}and{2} $main::races[$ally] {17}has been retracted by the $main::races[$self->{'RACE'}].\n");
          # delete the other race's offer, if it was broken off..
          delete $main::rock_stats{'rally-'.$ally.'-'.$self->{'RACE'}};
          $main::allyfriend[$self->{'RACE'}]->[$ally] = $main::allyfriend[$ally]->[$self->{'RACE'}] = undef;
     } else {
          &main::rock_hrshout($self->{'RACE'}, "{16}***** {2}$self->{'NAME'} has retracted its offer of alliance with the {13}$main::races[$ally]s\n");
          &main::rock_hrshout($ally, "{16}***** {2}The {13}$main::races[$self->{'RACE'}]s {2}have withdrawn their offer of alliance from us.\n");
     }
  }
  return;
}

sub msg_broadcast {
    my ($self, $msg) = @_;
    
	unless($self->{'BCASTCH'}) { 
        $self->log_append("{17}You are not currently on any broadcast channels.\n");
        return;
    } elsif (defined($self->{'FX'}->{'26'}) && !$self->{'ADMIN'}) {
        $self->log_append("{3}You currently lack the means to communicate that way. Bummer.\n"); 
        return;
    } elsif ($msg eq '') { 
        $self->log_append("{3}You are currently on channel $self->{'BCASTCH'}\.\n");
		return;
    }
	
    if(!$self->can_do(0,0,1)) { return; } # was 2 turns 2002-12-29
    $msg = &main::text_filter_game($msg, $self);
    my $cmsg = censored_message->new_prefiltered("{1}.o{17}\_/{7}-{17}($self->{'NAME'})\{7}: {".($self->{'PENCOLOR'}||13)."}$msg\n", $self);
	
    &main::rock_hbcastshout($self->{'BCASTCH'}, $self->{'NAME'}, $cmsg); 
}

sub broadcast_scan {
    # lists all users on the channel (cwho).
    # requires channel scanner
    my ($self) = @_;
    if(!$self->inv_has_rec(575) && $self->{'BCASTCH'} > 10) {
       $self->log_append("{17}You do not have a device capable of doing this.\n");
       return;
    } elsif(!$self->{'BCASTCH'}) { 
       $self->log_append("{17}You are not currently on any broadcast channels.\n");
       return;
    }
    if(!$self->can_do(0,0,0)) { return; } # used to be 5 turns
    
    my @chan_pnames;
    my @plist = map { &obj_lookup($_) } keys(%$main::activeusers);
    foreach my $player (@plist) {
         if($player->{'BCASTCH'} == $self->{'BCASTCH'} && !$player->{'SOCINVIS'}){
             push(@chan_pnames, $player->{'NAME'});
         }
    }
    
	if (@chan_pnames) {
        $self->log_append("{7}Players on broadcast channel {5}$self->{'BCASTCH'}\{7}:\n    {16}".join('{7}, {16}', sort @chan_pnames).".\n");
    } else {
        $self->log_append("{7}No players are on this broadcast channel.\n");
	}
}

sub broadcast_scan_all {
    # lists all users on the public channels (cwho all)
    # requires channel scanner
    my ($self) = @_;
    if(!$self->can_do(0,0,0)) { return; }
    
    my %chan;
    my @plist = map { &obj_lookup($_) } keys(%$main::activeusers);
    foreach my $player (@plist) {
         if($player->{'BCASTCH'} > 0 && ($player->{'BCASTCH'} <= 10 && !$player->{'SOCINVIS'}  || $self->{'ADMIN'}) ){
		     $chan{$player->{'BCASTCH'}} ||= [];
             push(@{$chan{$player->{'BCASTCH'}}}, $player->{'NAME'});
         }
    }
    
	if (keys %chan) {
        my $cap = "{7}Found activity on the following channels:\n";
		foreach my $key (sort { $a <=> $b }  keys %chan) {
		    $cap .= "    Channel {17}$key\{7}: ".join(", ", @{$chan{$key}})."\n";
		}
		$self->log_append($cap);
    } else {
        $self->log_append("{7}No players are on any of the ten public channels.\n");
	}
}

sub broadcast_channel {
    my ($self, $chan) = @_;
    if($chan eq '') { 
       if($self->{'BCASTCH'}) { 
         $self->log_append("{3}You are currently on channel $self->{'BCASTCH'}\.\n");
       } else {
         $self->log_append("{3}You are not currently on any channel.\n"); 
       }
       return;
    }
    $chan = abs(int $chan);
    
    # handle maximum channels
    my $maxchan = 100;
    if($self->inv_has_rec(578)) { $maxchan = 100_000_000; }
    elsif($self->inv_has_rec(577)) { $maxchan = 100_000; }
    elsif($self->inv_has_rec(576)) { $maxchan = 1_000; }
    
    my $chantag;
    if(defined($main::channames{$chan})) { $chantag = " ($main::channames{$chan})"; }
    if($chan > $maxchan) { $self->log_append("{13}Your equipment only supports channels 1-".&rockobj::commify($maxchan)."\n"); return; }
    my $oldchan = int $self->{'BCASTCH'};
    if($chan == $oldchan) { $self->log_append("{13}You're already on that channel!\n"); return; }
    if($chan == 0) {
       delete $self->{'BCASTCH'};
       if($oldchan) { &main::rock_hbcastshout($oldchan, undef, "{1}.o{17}\_/{7}->   {12}$self->{'NAME'} has tuned off of channel $oldchan.\n"); }
       $self->log_append("{17}You turn off your equipment.\n"); 
    } else {
       &main::rock_hbcastshout($chan, undef, "{1}.o{17}\_/{7}->   {12}$self->{'NAME'} has tuned {17}into{12} channel $chan$chantag.\n"); 
       $self->{'BCASTCH'}=$chan;
       if($oldchan) { &main::rock_hbcastshout($oldchan, undef, "{1}.o{17}\_/{7}->   {12}$self->{'NAME'} has tuned off of channel $oldchan.\n"); }
       $self->log_append("{17}You tune to channel $chan$chantag.\n"); 
    }
    return;
}

sub pen_color {
    my ($self, $color) = @_;
    $color = lc($color);
    if(defined($main::colortonum{$color})) { $self->{'PENCOLOR'}=$main::colortonum{$color}; $self->log_append("{13}Switched pen color to $color.\n"); }
    elsif(defined($main::numtocolor{$color})) { $self->{'PENCOLOR'}=$color; $self->log_append("{13}Switched pen color to $main::numtocolor{$color}.\n"); }
    else { $self->log_append("{17}Syntax: pen <color|1-7|11-17>\n"); }
    return;
}

sub pref_get {
    my ($self, $pref) = @_;
    $pref = lc($pref);

    if(!defined($main::preflist{$pref})) { $self->log_append("{17}Error: Undefined Pref ($pref)\n"); return; }

    return vec($self->{'PREF'}, $main::preflist{$pref}, 1);
}

sub pref_set() { return &pref_toggle(@_); }

sub pref_toggle {
    my ($self, $pref, $quiet, $onOff) = @_;
    
    $pref = lc($pref);

    if(!defined($main::preflist{$pref})) { $self->log_append("{17}Error: Undefined Pref ($pref)\n"); return; }
    
    
    # BLOODSH BRIEF COMBAT_BRIEF 
    # ACCEPT AGGENTRY JIVE PROMPT
    # BUSY DNL(?) VERBOSE TALK autoequip
    
    # UI funness
	if ($onOff eq "") { $onOff = undef; }
	elsif ($onOff =~ /^yes|on|1$/) { $onOff=1; }
	else { $onOff = 0; }
	
    # flip pref switch
    if(!defined($onOff)) { vec($self->{'PREF'}, $main::preflist{$pref}, 1) ^= 1; }
    else { vec($self->{'PREF'}, $main::preflist{$pref}, 1) = ($onOff==1); }
    
    # notify user
    if(!$quiet) {
      $self->log_append("{2}Turned your {12}$pref {2}$main::onoff[vec($self->{'PREF'}, $main::preflist{$pref}, 1)].\n");
    }
    return;
}

sub dp_calc {
  my $self = shift;
  my $dp = $self->{'DP'}; # 1 point per day general, per monolith
                          # .3 points per rank level, per day soldier
                          # 4 points for striking blow to monolith guardians
                          # admin bonus points (desirable assistance)
                          # 1 point every 4 days of having logged in.
  $dp += $self->{'LEV'}/7;
  $dp += $self->{'REPU'}/4;
  
  return $dp;
}

sub dismiss_soldier() { 
    my ($self, $soldier) = @_;
    if(!$self->{'GENERAL'}) {  return $self->log_append("{13}Only generals can dismiss others from the military.\n"); }
    if($soldier = $self->uid_resolve($soldier)) {
       if(!$soldier->{'SOLDIER'}) { return $self->log_append("{17}User is not a soldier!\n"); }
       if($soldier->{'RACE'} != $self->{'RACE'}) { return $self->log_append("{17}You can only dismiss soldiers of your race.\n"); }
       if($soldier->{'LEV'}>=45) { return $self->log_append("{17}Soldier must be at most level 44 to be dismissed.\n"); }
       if($soldier->{'GENERAL'}) { return $self->log_append("{17}Generals may not be dismissed.\n"); }
       delete $soldier->{'SOLDIER'};
       &main::rock_shout(undef, "{2}*** $self->{'NAME'} has dismissed $soldier->{'NAME'} from the ranks of the $main::races[$self->{'RACE'}] military.\n");
    }
    return;
}

sub cmd_item_use {
    my ($self, $txt) = @_;
    
    # refine text
    for ($txt) { 
        $_ =~ s/^\s+//g;
        $_ =~ s/\s+$//g;
    }
    
    my ($iname, undef, $vname) = $txt =~ 
        m{ 
           ^
           (.+?)
           (
             [ ]+
             (?:on|at|toward|with|\@)
             [ ]+
             (.*?)
           )?
           $
        }x;
        

   my ($success, $iobj) = $self->inv_cgetobj($iname, -1, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs);
   
   if ($success == 0) { $self->log_error("'$iname' not found.  Syntax: use <object> [on <object>]"); return(0); }
   elsif ($success == -1) { $self->log_append($iobj); return(0); }
   else {
      # got iname
      if($vname) {
          my ($success, $vname) = $self->inv_cgetobj($vname, -1, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs);
          if ($success == 0) { $self->log_error("'$vname' not found.  Syntax: use <object> [on <object>]"); return(0); }
          elsif ($success == -1) { $self->log_append($vname); return(0); }
          else { 
		      # Give recipient the control first. if they dont want it (by returning 0), then
			  # give control to the object being used.
			  unless ($vname->on_use_on($self, $iobj)) {
  		          $iobj->on_use($self, $vname);
			  }
			  return 1;
		  }
      }
      $iobj->on_use($self); return 1;
   }
}

sub item_henter {
  # moves self to object; returns 0 if failure
  my ($self, $obj) = @_;
  $main::objs->{$self->{'CONTAINEDBY'}}->inv_del($self);
  $obj->inv_add($self);
  return 1;
}

sub stalkee_get {
    my $self = shift;
    if(   !$self->{'STALKING'} 
       || !defined($main::objs->{$self->{'STALKING'}})
      ) {
           return undef;
    } else {
           return $main::objs->{$self->{'STALKING'}};
    }
}

sub aid_get {
    # returns object being aided, if any
    my $self = shift;
    if(!$self->{'AID'} || !defined($main::objs->{$self->{'AID'}})) { return undef; }
    else {
        return $main::objs->{$self->{'AID'}};
    }
}

sub auction_look {
    my ($self, $item_id) = @_;
	
	$item_id = int $item_id;
	my $row = rockdb::sql_select_hashref(<<END_SQL, $item_id);
SELECT A.item_desc as item_desc, USELL.userid as seller_uid, A.start_date as start_date, A.end_date as end_date, A.item_name as item_name
FROM dillfrog.accounts USELL, $main::db_name\.auctions A
WHERE
     A.auction_id = ? AND
	 USELL.uin = A.seller_uin
END_SQL

    return $self->log_append("{3}<<  There is no auction item #$item_id.  >>\n")
	    unless $row;
	
	$row->{'ITEM_DESC'} .= "..." if length($row->{'ITEM_DESC'}) >= 255;
	$self->log_append(<<END_CAP);
{4}------------------------------------
{17}Auction Item #$item_id ($row->{'ITEM_NAME'}) is being sold by {7}$row->{'SELLER_UID'}\{17}.
{17}Description:
    {7}$row->{'ITEM_DESC'}
{4}------------------------------------
END_CAP

}

sub auction_list {
    # appends list of auction items for player to seeeeee
	my ($self)  = @_;
	
	my $rows = rockdb::sql_select_mult_row(<<END_SQL);
SELECT A.auction_id, A.item_name, A.min_price, A.high_bid, USELL.userid, UBUY.userid, A.bid_increment, A.end_date
FROM dillfrog.accounts USELL,  dillfrog.accounts UBUY RIGHT OUTER JOIN $main::db_name\.auctions A on A.high_bid_uin = UBUY.uin
WHERE
	  sysdate() < A.end_date    AND
	  USELL.uin = A.seller_uin  
ORDER BY A.end_date ASC
LIMIT 20
END_SQL


    my $txt = "";
    foreach my $row (@$rows) {
	    # this isn't good on the DB, but SSHH.. I don't know how to do two outer joins on the
		# same table :(
		my ($my_max_bid) = rockdb::sql_select_row("SELECT max_bid FROM $main::db_name\.auction_bids WHERE auction_id=? AND bidder_uin=?", $row->[0], $self->{'UIN'});

	    # itemid, item name, seller, bid/min, bidder
	    $txt .= sprintf "{7}%6d] {17}%15s {13}%7s {3}%10s {7}%14s {13}%s\n", $row->[0], substr($row->[1],0,15), &commify($row->[3]?$row->[3]+$row->[6]:$row->[2]||$row->[6]), substr($row->[5], 0, 10)||"<none>", substr($row->[7], 5), ($my_max_bid?&commify($my_max_bid):'---');
	}
	
	if ($txt) {
	    $txt  = sprintf ("{7}%6s] {17}%15s {13}%7s {3}%10s {7}%14s {13}%s\n", "ItemID", "Item Name",  "Min Bid", "Top Bidder", "End Date", "Your Max Bid") . $txt;
	    $self->log_append("{17}The following items are being auctioned off soon:\n".$txt);
	} else {
	    $self->log_append("{3}<<  No items are currently being auctioned. Try again later.  >>\n");
	}
	
	
}

sub item_auction {
    # parses the auction stuff
	my ($self, $cmd) = @_;
	
	unless ($main::map->[$self->{'ROOM'}]->{'AUCTION'}) { 
	    $self->log_append("{3}<<  You must be in an auction house in order to auction anything, silly!  >>\n");
	    return 0;
	}
	
	#  auction someitem for INTEGER <hours|days> [reserve INTEGER] [increment INTEGER]
	if (my ($item_name, $time, $time_type, $reserve, $increment) = $cmd =~ /^\s*(.+?)\s+for\s+(\d+)\s+(minute|hour|day)s?(?:\s*reserve\s+(\d+)\s*)?(?:\s*increment\s+(\d+)\s*)?$\s*/i) {
	    $reserve ||= 0;
		$increment ||= 10; # cryl
		$time_type = lc $time_type;
		if ($time_type eq 'hour') {
		    $time *= 60; # convert to min
		} elsif ($time_type eq 'day') {
		    $time *= 24 * 60; # convert to min
		}
		
		# get our item
        my ($successa, $iobj) = $self->inv_cgetobj($item_name, 0, $self->inv_objs );
        if ($successa == 1) { $self->item_hauction($iobj, $reserve, $increment, $time); }
		elsif ( $successa == 0 ) { $self->log_append("{3}You don't have any $item_name to give away.\n"); }
        elsif ( $successa == -1 ) { $self->log_append("{7}Give What!? ".$iobj); }
	} else {
	    # invalid syntax.. the syntax of an invalid
		$self->log_append("{3}<<  Syntax:  auctionitem <item> for <amt> <'minutes'|'hours'|'days'> [reserve <amt>] [increment <amt>]  >>\n");
		$self->log_hint("Example: 'auctionitem boots for 2 hours reserve 300 increment 200' would try auctioning your boots for 2 hours, with a minimum bid of 300 and bid increments of 200.");
	}
}

sub item_hauction {
    my ($self, $item, $min_price, $bid_increment, $auction_minutes) = @_;
	
	# puts $item up for auction -- be VERY VERY careful how you use this :)
    
	# WARNING: unsold items would go back to the player, and thus could
	#          be used as a way to secure items.
	
	$min_price = int $min_price;
	$bid_increment = int $bid_increment;
	
##	if ($self->{'LEV'} < 100) { $self->log_append("{3}<<  You must be at least level 100 to auction stuff (for now - just testing with a smaller group of people).  >>\n"); return 0; }
	
	if (!$self->{'UIN'}) { $self->log_append("{3}<<  You cannot auction without having a UIN.  >>\n"); return 0; }
	
	die "No item passed!" unless $item;
	if ($min_price < 0) { $self->log_append("{3}<<  Minimum price must be greater than zero.  >>\n"); return 0; }
	if ($auction_minutes < 10 && !$self->{'ADMIN'}) { $self->log_append("{3}<<  Auction must last at least 10 minutes.  >>\n"); return 0; }
	if ($auction_minutes > 60*24*2 && !$self->{'ADMIN'}) { $self->log_append("{3}<<  Auction must last 2 days at most.  >>\n"); return 0; }
	if ($min_price > 100_000) { $self->log_append("{3}<<  Minimum price must be less than 100,000 cryl.  >>\n"); return 0; }
	
    my $transaction_fee = 100;
	if ($self->{'CRYL'} < $transaction_fee) { $self->log_append("{3}<<  It costs $transaction_fee cryl to auction an item. Come back when you have the money.  >>\n"); return 0; }
	
	# make sure they have the item
	if(!$self->inv_has($item)) { 
	    $self->log_append("{3}<<  You can't auction an item you're not carrying.  >>\n");
		return 0;
	}

    if ($item->{'UNIQUE'}) {
	    $self->log_error("Artifacts may not be auctioned.");
		return 0;
	}

    #mich - keke ^_^
    if ($item->{'NOSAVE'}) {
            $self->log_error("Items which cannot be saved cannot be auctioned.");
            return 0;
    }

    if ($item->{'VAL'} <= 0 && !$self->{'ADMIN'}) {
	    $self->log_error("You may only auction items with some intrinsic value.");
		return 0;
	}
	
	# if they're wearing it, disarm
	if($item->{'WORN'}) { $self->apparel_remove($item); delete $item->{'WORN'}; $self->apparel_update; }
	if ( ($self->{'WEAPON'} == $item->{'OBJID'}) && !$self->item_hunequip($item) ) { return 0; }
	
	# If we're still here, then it must have been a success -- they can sell it, so
	# let's package it up!
	
	$self->inv_del($item); # remove from player inventory
	$self->{'CRYL'} -= $transaction_fee;
	$self->log_append("{7}You put $item->{'NAME'} up for auction (for a fee of $transaction_fee cryl).\n");
#    $self->room_sighttell("{7}$self->{'NAME'} {3}puts $item->{'NAME'} up for auction.\n");
    &main::rock_talkshout($self, sprintf('{15}%16s', ($self->{'NICK'} || $self->{'NAME'}))."{3} puts $item->{'NAME'} up for auction in Kaine's auction house.\n", 'silence auctions');

	# save to database
    my $r2dump = Data::Dumper->new([$item], [qw(item)]); 
    $r2dump->Indent(1); $r2dump->Purity(1);
    my $item_data = $r2dump->Dumpxs;
	
	my $dbh = rockdb::db_get_conn();
	$dbh->do(<<END_CAP, undef, $auction_minutes, $min_price, $bid_increment, $self->{'UIN'}, &stripColorCodes($item->{'NAME'}), &stripColorCodes($item->desc_get()), $item_data);
INSERT INTO $main::db_name\.auctions
(start_date, end_date, min_price, bid_increment, seller_uin, item_name, item_desc, item_data)
VALUES
(sysdate(), DATE_ADD(sysdate(), INTERVAL ? minute), ?, ?, ?, ?, ?, ?)
END_CAP


    # kill the item
	$item->dissolve_allsubs;
	
    return 1;
}

sub auction_bid {
    my ($self, $auction_id, $bid) = @_;
	$bid = int $bid;
	$auction_id = int $auction_id;
	
#	return $self->log_error("Don't bid right now.. we're fixing stuff. You silly dog teeth bidders!")
#	    unless $self->{'ADMIN'};
		
#     return $self->log_append("{3}<<  Sorry, admins are still playing with that. Be patient >:-).  >>\n")
#	     unless $self->{'ADMIN'};


     # hate them if they're silly admins
     return $self->log_append("{3}<<  Silly object, you need to have a UIN to play.  >>\n")
	     unless $self->{'UIN'};

     # hate them if they don't know how to bid
     return $self->log_append("{3}<<  Syntax: bid <cryl> on <item_id>  >>\n")
	     unless $auction_id > 0 && $bid > 0;
		
	 my $row = rockdb::sql_select_hashref(<<END_SQL, $auction_id);
SELECT A.item_name as ITEM_NAME, A.high_bid_uin AS HIGH_BID_UIN, A.min_price as MIN_PRICE, A.high_bid as HIGH_BID, A.bid_increment as BID_INCREMENT, A.seller_uin as SELLER_UIN
FROM $main::db_name\.auctions A
WHERE
      A.auction_id = ?          AND
	  sysdate() < A.end_date
ORDER BY A.end_date ASC
END_SQL

     # hate them if they tried bidding on evilness
     return $self->log_append("{3}<<  Item #$auction_id is not up for bids  >>\n")
	     unless $row;
		 
	 return $self->log_error("You cannot bid on your own items.")
	     if $self->{'UIN'} == $row->{'SELLER_UIN'} && !$self->{'ADMIN'};

	 # okay, so they want to bid and they can maybe bid on the current item
	 #  -- does it fit that particular auction item's requirements (min bid)?

     my $min_bid = $row->{'HIGH_BID'}?$row->{'HIGH_BID'}+$row->{'BID_INCREMENT'}:$row->{'MIN_PRICE'}||$row->{'BID_INCREMENT'};

	 return $self->log_error("You must bid in increments of $row->{'BID_INCREMENT'}.")
	     if ($bid % ($row->{'BID_INCREMENT'} || 1));

     # see how much they currently putted into this
     my ($cryl_prebidded) = rockdb::sql_select_row("SELECT max_bid FROM $main::db_name\.auction_bids WHERE bidder_uin=? AND auction_id=?", $self->{'UIN'}, $auction_id);

     if ($self->{'UIN'} == $row->{'HIGH_BID_UIN'}) {
  	     return $self->log_append("{3}<<  You have a high bid of $row->{'HIGH_BID'}. You can't have a max bid below that.  >>\n")
	         if $bid < $row->{'HIGH_BID'};
     } else {
  	     return $self->log_append("{3}<<  You already bid $cryl_prebidded on the $row->{'ITEM_NAME'}. Bid more! More more more!  >>\n")
	         if $cryl_prebidded >= $bid;
		 return $self->log_append("{3}<<  The minimum bid for $row->{'ITEM_NAME'} is $min_bid.  >>\n")
	    	 if $bid < $min_bid;
	 }
	 
	 my $cryl_needed = $bid - $cryl_prebidded;
	 # hate them if they don't have the cryl handy
	 return $self->log_append("{3}<<  You need $cryl_needed cryl on you to bid that high.  >>\n")
	     if $self->{'CRYL'} < $cryl_needed;

     # OK, so they have a valid item, and they have the money. snatch it, log it, and
	 # never look back.
	 
	 if ($cryl_needed >= 0) { 
	     $self->{'CRYL'} -= $cryl_needed; # take away cryl
	 } else {
	    $self->{'B-ROCKFREY'} -= $cryl_needed; # bank cryl
	 }
	 
	 my $dbh = rockdb::db_get_conn();
	 # Update the database with my new bid
	 if ($cryl_prebidded) {
	     # update
		 $dbh->do(<<END_SQL, undef, $bid, $auction_id, $self->{'UIN'} );
UPDATE $main::db_name\.auction_bids
SET    max_bid = ?, bid_date=sysdate()
WHERE  auction_id= ? AND
       bidder_uin = ?
END_SQL
	 } else {
	     # insert
		 $dbh->do(<<END_SQL, undef, $bid, $auction_id, $self->{'UIN'});
INSERT INTO $main::db_name\.auction_bids
(max_bid, auction_id, bidder_uin, bid_date)
VALUES
(?, ?, ?, sysdate())
END_SQL
	 }
	 
     # NOW, check against the current bids.
     

	 my ($public_bid, $public_bidder_uin) = ($min_bid, $self->{'UIN'});
	 
	 if ($row->{'HIGH_BID_UIN'} == $self->{'UIN'}) {
	     # I'm already the high bidder -- just update my bid.
   	     $self->log_append("{17}You {7}bid {13}$bid cryl max {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}).\n");
		 $self->log_hint("Your extra cryl has been deposited into Kaine's bank.") if $cryl_needed < 0;
	 } else {
		 # BUT If I'm not the high bidder, and THEIR max bid is wiggidy-whack
		 # (that is, their_max_bid >= ($public_bid + $bid_increment), then they win
		 my ($public_bid, $public_bidder_uin) = ($min_bid, $self->{'UIN'});
		 my $outbidders = rockdb::sql_select_mult_row("SELECT B.max_bid, B.bidder_uin, A.userid FROM $main::db_name\.auction_bids B, dillfrog.accounts A WHERE B.auction_id=? AND B.bidder_uin = A.uin AND B.max_bid >= ? ORDER BY max_bid DESC, bid_date DESC", $auction_id, $min_bid + $row->{'BID_INCREMENT'});

		 if (grep { $_->[1] != $self->{'UIN'}} @$outbidders) {
			 my $challenge_bid = $min_bid;
        	 $challenge_bid = $outbidders->[1]->[0] 
		    	 if (@$outbidders > 1);

	    	 my $outbidder_bid = $outbidders->[0]->[0];

			 if (($outbidder_bid - $challenge_bid) < $row->{'BID_INCREMENT'}) {
		    	 $public_bid = $outbidder_bid; # full amount if he can't do the full increment
			 } else {
		    	 $public_bid = $challenge_bid + $row->{'BID_INCREMENT'};
			 }
			 $public_bidder_uin = $outbidders->[0]->[1];
		 }

		 if ($public_bidder_uin == $self->{'UIN'}) {
   	    	 $self->log_append("{17}You {7}bid {13}$public_bid cryl (max $bid) {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}).\n");
        	 &main::rock_talkshout($self, sprintf('{15}%16s', ($self->{'NICK'} || $self->{'NAME'}))." {7}bids {13}$public_bid cryl {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}).\n", 'silence auctions');
		 } else {
	    	 $outbidders->[0]->[2] = ucfirst $outbidders->[0]->[2]; # prettier
        	 $self->log_append("{17}You {7}bid {13}$min_bid cryl (max $bid) {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}).\n");
        	 &main::rock_talkshout($self, sprintf('{15}%16s', ($self->{'NICK'} || $self->{'NAME'}))." {7}bids {13}$min_bid cryl {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}).\n", 'silence auctions');
	    	 $self->log_append("{17}$outbidders->[0]->[2] {7}autobids {13}$public_bid cryl {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}), outbidding you.\n");
        	 &main::rock_talkshout($self, sprintf('{15}%16s', $outbidders->[0]->[2])." {7}autobids {13}$public_bid cryl {7}on item #$auction_id ({17}$row->{'ITEM_NAME'}\{7}), outbidding $self->{'NAME'}.\n", 'silence auctions');
    	 }

		 $dbh->do(<<END_SQL, undef, $public_bidder_uin, $public_bid, $auction_id);
UPDATE $main::db_name\.auctions
SET high_bid_uin = ?,
    high_bid = ?
WHERE auction_id = ?
END_SQL
	 }
	 

      # finally, life is good
}

sub auction_claim {
    # gives self all the items he's won in auction
    my $self = shift;

    # which items did i wins?
	
	my $rows = rockdb::sql_select_mult_row(<<END_SQL, $self->{'UIN'}, $self->{'UIN'});
SELECT auction_id, item_data, high_bid_uin
FROM $main::db_name\.auctions
WHERE ((high_bid_uin=?) OR (high_bid_uin IS NULL  AND seller_uin = ?)) AND
      claimed_item='N' AND
	  returned_cryl='Y'
END_SQL

    return $self->log_append("{3}<<  There are no auction items for you to claim.  >>\n")
	    unless $rows && @$rows;
		
    foreach my $row (@$rows) {
	    # for each item i won, gimme gimme gimme!!!
		my $item;
		eval($row->[1]); # $item exists here
		if (my $err_msg = $@) {
		    &main::rock_shout(undef, "{13}#### ERROR evaluating item data for claimed auction $rows->[0]: $err_msg\n", 1);
		    &main::rock_shout(undef, "{16}$row->[1]\n", 1);
		} else {
		# and record that i got it, so i dont get it twice :)
		my $dbh = rockdb::db_get_conn();
		$dbh->do(<<END_SQL, undef, $row->[0]);
UPDATE $main::db_name\.auctions
SET claimed_item='Y'
WHERE auction_id = ?
END_SQL
            # gimme item
                        #mich - keke ^_^
                        if ($item->{'NOSAVE'}) {
                            $self->room_sighttell("{16}$item->{'NAME'} {2}disappears in {16}Kaine's auctobot's{2} hands.\n");
                            $item->dissolve_allsubs();
                            $self->log_append("{2}[action] {16}Kaine's auctobot{2} slaps you on the cheek.\n");
                            $self->room_sighttell("{16}Kaine's auctobot{2} slaps {16}$self->{'NAME'} {2}on the cheek.\n");
                        } else {
		            $self->inv_add($item);
		            my $how_got = $row->[2]?"you won in":"nobody wanted in";
		            $self->log_append("{3}Kaine's auctobot hands you the {7}$item->{'NAME'} {3}$how_got auction $row->[0].\n");
	         	    $self->room_sighttell("{3}Kaine's auctobot hands {7}$self->{'NAME'} {3}the {7}$item->{'NAME'} {3}$self->{'PRO'} won in auction $row->[0].\n");
                        }
		}

      
	}
	
	# important: resynch objids
	$self->objids_register();
	
	# Then save!
	$self->obj_dump();
}

################################################################################################################

sub set_stat_weight {
    my ($self, $stat, $amt) = @_;
    
	# Sets $self's $stat weight to $amt.
	# Valid values of stat are
	$stat = uc($stat);
	
    if ($stat eq "OFF") {
        delete $self->{'RAISE_PCT'};
        $self->log_appendline("{17}Raise weighting turned off.");
        return;
    } elsif ($stat eq "") {
        $self->log_append($self->get_stat_weights());
        return;
    } elsif ($stat eq "ON") {
        for(my $i = 6; $i <= 22; $i++) {
            $self->{'RAISE_PCT'}->{$i} = 100;
        }
        $self->log_appendline("{17}Raise weighting turned on.");
        return;
    } elsif ($stat eq "CLEAR") {
        for(my $i = 6; $i <= 22; $i++) {
            $self->{'RAISE_PCT'}->{$i} = 0;
        }
        $self->log_appendline("{17}All stat weights set to 0.");
        return;
    } elsif(!defined($main::parr{$stat})) {
        $self->log_error("Syntax: weight <stat> <weight value from 0 to 200>"); 
        $self->log_error("Syntax: weight <'on'|'off'|'clear'>"); 
        return;
    }

    $amt = int $amt;
	
	if ($amt < 0 || $amt > 200) { 
        $self->log_error("Weight amount must be between 0 and 200, inclusive.");
		return;
    }

    my $snum = $main::parr{$stat};
    
    $self->{'RAISE_PCT'}->{$snum} = $amt;
    $self->log_appendline("{15}Your " . $stat . "'s weight percent was set to $amt.");
    return;
}

sub get_stat_weights {
	my $self = shift;
	my $cap;
	if(!defined($self->{'RAISE_PCT'})) {
       return "{17}You currently have raise weights disabled. To enable them, type \"weight on\"\n"; 
	}

	my $sarr = $self->{'RAISE_PCT'};

	$cap .= "{17}--Raise Weights--\n";
    $cap .= sprintf("{16}KMEC: {17}%4d   {16}KSOC: {17}%4d\n",  $sarr->{&KMEC}, $sarr->{&KSOC});
    $cap .= sprintf("{16}KMED: {17}%4d   {16}KCOM: {17}%4d\n",  $sarr->{&KMED}, $sarr->{&KCOM});
    $cap .= sprintf("{16}MOFF: {17}%4d   {16}MDEF: {17}%4d\n",  $sarr->{&MOFF}, $sarr->{&MDEF});
    $cap .= sprintf("{16}MELE: {17}%4d   {16}MMEN: {17}%4d\n",  $sarr->{&MELE}, $sarr->{&MMEN});
    $cap .= sprintf("{16}DPHY: {17}%4d   {16}DENE: {17}%4d\n",  $sarr->{&DPHY}, $sarr->{&DENE});
    $cap .= sprintf("{16}DMEN: {17}%4d\n",                  $sarr->{&DMEN});
    $cap .= sprintf("{16}CAPP: {17}%4d   {16}CATT: {17}%4d\n",  $sarr->{&CAPP}, $sarr->{&CATT});
    $cap .= sprintf("{16}AUPP: {17}%4d   {16}ALOW: {17}%4d\n",  $sarr->{&AUPP}, $sarr->{&ALOW});
    $cap .= sprintf("{16}SUPP: {17}%4d   {16}SLOW: {17}%4d\n",  $sarr->{&SUPP}, $sarr->{&SLOW});
	return $cap;
}


sub exp_raiseautopct {
    # Auto-raises stats so that they are a certain percentage of the average stat,
	# based off of the object's RAISE_PCT data.
	
    my $self = shift;

    # return if the user has this feature turned off (we shouldn't even be in this sub)
    return if(!defined($self->{'RAISE_PCT'}));

    # calculate real-value of stats and level (We don't want armor or FX screwing up our calculations)
    my %statval;

    # calculate the base stats and the average of them all
    my $average;
    for(my $stat=6; $stat <= 22; $stat++) {
        $statval{$stat} = int($self->{'EXP'}->[$stat] ** (1/3));
        $average += $statval{$stat};
    }
    $average /= 17; # there are 17 stats

    # let's not cause division by 0 issues
    $average = 1 if $average == 0;


    my %result;

    # sort weights in descending order so we raise the highest ones first, always
    my @orderedstats = sort { $self->{'RAISE_PCT'}->{$b} <=> $self->{'RAISE_PCT'}->{$a} } keys %{$self->{'RAISE_PCT'}};


    # force - to force the first applicable stat to be raised in the case that they have all met their weight requirements
    my $force = 0;
	
    # success - keep looping through the stats until none can be raised
    my $success = 0;

    # failcount - if this is 17, force is evoked to make the stats not all even
    my $failcount = 0;

    do
    {
        $success = 0;
        foreach my $stat (@orderedstats) {
            if ($self->{'RAISE_PCT'}->{$stat} == 0) {
                # if the stat's weight is 0, don't raise it at all
                ++$failcount;
            } elsif (!$force  &&  ($statval{$stat} / $average * 100) >= $self->{'RAISE_PCT'}->{$stat}) {
                # if we aren't forcing or the stat is over what it's supposed to be, force it
                #$self->log_appendline("Skipped $stat.");
                #$self->log_appendline("Average: $average, Stat: $statval{$stat}, Target: $debugvar2, Pct: $debugvar1, TargetPct: $self->{'RAISE_PCT'}->{$stat}");
                $failcount++;
            } elsif ($self->pstat_raise($main::rparr{$stat}, 1, 1)) {
                $success = 1;
                $result{$main::rparr{$stat}} += 1;
                $statval{$stat} += 1;
                $average += (1/17);
            } else {
			    # could not do anything to the stat
				++$failcount;
			}
        }

        $force = 0;
		
		# If we skipped all our stats, force a stat to [try to] be raised.
		# Note that $failcount doesn't ever reset, so if all RAISE_PCTs are 0
		# causing failcount to reach 18, we don't force it, and we're out of the loop.
    	if ($failcount == 17) {
        	$force = 1;
			$success = 1;
    	}

    #loop while we still have the ability to raise stats
    } while ($success && $failcount < 100);
    
    
    #update level, hp, mana, etc
    $self->stats_update();
	

    #report results
    if (scalar %result) { 
        my $c = "{1}The following stats were raised for you:";
        foreach my $stat (keys %result) {
            $c .= "  {17}$stat\: {12}$result{$stat}.";
		}
        $self->log_appendline($c);
    } else {
        $self->log_error("No stats could be auto-raised for you.");
        $self->log_hint("Try typing \"raise auto\" later, when you have more experience!");
    }
    return;
}



1;
