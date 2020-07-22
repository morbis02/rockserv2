######### the ch and log_spew options (and the command chooser too).
#use vars (@ISA, %ansimap, %htmlmap);

package stdfunct;
use strict; #no strict 'refs';

sub in (MATCHSTR, ARRAY) { 
 my $match = shift;
 my $cap;
 foreach $cap (@_) { if($match eq $cap) { return 1; } }
 return 0;
}


### ALL OBJECTS MUST:
### HAVE A RESPONSE TO 'name' QUERY.
### HAVE A RESPONSE (or at least handle) TO 'tell' QUERY.
 
package rockobj;
@rockobj::ISA = qw(o_group);
use Benchmark;
use strict; #no strict 'refs';
use Text::Wrap;
use Dillfrog;
use Dillfrog::Auth;
use Text::Soundex;
use rockobj2; # use extended object base
use rockobj3; # use extended object base
use Carp;
use POSIX qw(ceil floor);
use rockdb;
use rock_prefs;

BEGIN { do "const_stats.pm"; }

$rockobj::auth_man = Dillfrog::Auth->new();

#sub DESTROY {   my $self = shift;  my $player; foreach $player (keys(%{$main::activeusers})) { $main::objs->{$player}->log_append("{16}Destroying object:{11} $self->{'NAME'} {6}(id: $self->{'OBJID'}){16}.\n");  }  }

sub new {
    ## does standard obj_init stuff (include in "new")
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    #use rockobj_std;  $self->{'ISA'} = ("rockobj_std");
    ## global stuff
    $main::highobj += 1; # add one to highest object.
    $self->{'DONTDIE'}=1;
    bless ($self, $class);
    $main::objs->{$main::highobj}=$self; # map to objs.
    delete $self->{'DONTDIE'};
    #### THE STD STUFF
    $self->{'OBJID'}  = $main::highobj;
    $self->{'NAME'}   = undef;# obj's name.
    $self->{'BIRTH'}  = time; # time value for birth.
    $self->{'INV'}    = {};   # user's inventory.
    $self->{'MASS'}=.5;
    $self->{'VOL'}=.5;
    $self->{'MAXINV'}=10;
    $self->{'CP'}=0;
    $self->{'LEV'}=1;
    $self->{'ROOM'}=1;
    #for (my $n=0; $n<=22; $n++) { $self->{'EXP'}->[$n]=2; } # so we dont get LOG errors later on
    #### Generally Unstandard (check when making prefmake subs)
    $self->{'TYPE'}=0; # [ 0: item; 1: player; 2: npc; -1: room ]
    $self->{'PRO'}='it'; $self->{'PPOS'}='its'; $self->{'PPRO'}='it'; $self->{'GENDER'}='unknown'; #possessive prefix, pronoun, gender
    #### New prefs
    #if(@_) {  my $key; my %hash = @_; foreach $key (keys(%hash)) { $self->{uc($key)} = $hash{$key}; } }
    if(@_) {  for(my $i=0; $i<@_; $i+=2) { $self->{$_[$i]} = $_[$i+1]; } }
    ####
    #### Inits:
    $self->stats_update;
    $self->def_set;
    $self->desc_init;
    return $self;
}

sub is_invis {
    # Returns true if I am invisible. This does NOT mean that
	# my INVIS flag is necessarily set. I can be invisible because
	# of the hidden flag or other factors.
#	&main::rock_shout(undef, "$_[1]->{'NAME'} vs $_[0]->{'NAME'}\n", 1) 
#        if $_[0]->{'SPECTRAL_SHROUD'};
        
	return $_[0]->{'INVIS'} ||
           $_[0]->{'HIDDEN'} ||
           (   $_[0]->{'SPECTRAL_SHROUD'} &&
               (!$_[1] || $_[1]->{'NAME'} ne $_[0]->{'SPECTRAL_SHROUD'})
           );
}

sub def_set {
   return; # unused in default object..override in customs.
}

sub prefmake_player {
    my $self = shift;
    # sets object preferences to those of a player. returns player (but not necessarily going to be used)
    $self->{'VIGOR'}=.5;
    $self->{'STAT'} = [];
    $self->{'EXP'} = [];
    $self->{'NOSELL'}=1; # don't want to be able to sell Player.
    delete $self->{'DLIFT'} if !$self->{'DLIFT'};
    delete $self->{'CAN_LIFT'} if !$self->{'CAN_LIFT'};
    $self->{'TYPE'}=$self->{'MKLOG'}=1;
    $self->{'T'} = $self->{'MT'} = 6000;
    my $n;
    for($n=0; $n<=22; $n++) { $self->{'EXP'}->[$n]=5; }
    $self->stats_update();
    $self->{'HP'} = $self->{'MAXH'};
    ##
    my $fists = fists->new;
    $self->{'DWEAP'} = ($fists)->{'OBJID'};
    &obj_lookup($self->{'DWEAP'})->{'CONTAINEDBY'}=$self->{'OBJID'};
    $fists->{'FPAHD'} = $self->{'FPAHD'} if $self->{'FPAHD'};
    $fists->{'FPSHD'} = $self->{'FPAHD'} if $self->{'FPSHD'};
    $fists->{'TPAHD'} = $self->{'FPAHD'} if $self->{'TPAHD'};
    $fists->{'TPSHD'} = $self->{'FPAHD'} if $self->{'TPSHD'};
    $fists->{'WC'} = $self->{'WC'} if $self->{'WC'};
    $fists->{'NAME'} = $self->{'DWEAPNAME'} if $self->{'DWEAPNAME'};
    
    # THe following three are already done in verpref, but players and npcs
    # still need this stuff
    $self->pref_toggle('attack upon user entry', 1, 0); # aggentry defaults off; newbies die too much otherwise
    $self->pref_toggle('gift-acceptance', 1, 1); # gift acceptance on by default
	$self->pref_toggle('brief', 1, 1); # gift acceptance on by default

    return $fists;
}

sub prefmake_item {
    my $self = shift;
    # sets object preferences. returns object.
    $self->{'TYPE'} = 0; # make type of item
    $self->{'WC'} ||= 1; # default the WC so it doesnt go insane
    if($self->{'DLIFT'} ne "0") { $self->{'DLIFT'} =1; }
    if($self->{'CAN_LIFT'} ne "0") { $self->{'CAN_LIFT'} = 1; } # make type of item
    return $self;
}

sub prefmake_npc {
  my $self = shift;
  my $fists = $self->prefmake_player();
  $self->{'DLIFT'} = 0 if $self->{'DLIFT'} eq '';
  $self->{'CAN_LIFT'} = 0 if $self->{'CAN_LIFT'} eq '';
  $self->{'TYPE'} = 2;
  if(!$self->{'WC'}) { delete $fists->{'WC'}; } # use default wc limiting
  $self->{'HOSTILE'} = 3 unless defined $self->{'HOSTILE'}; # hostility defaults on for npcs (compare to players)
  $self->stats_update();
  return;
}

sub name {
    ## sets and/or or returns game name
    my $self = shift;
    if (@_) { $self->{'NAME'} = shift }
    return $self->{'NAME'};
}

sub age {
    ## returns game age (currently, age is in days).
    my $self = shift;
    return int( (time - $self->{'BIRTH'}) / 864) / 100;
}


sub failure {
	my @c = caller(1);
	print "FAILURE: $_[0] \@file: $c[1]. package: $c[0]. line: $c[2].\n";
	return;
}

sub obj_lookup {
	if(@_!=1) { &failure("obj_lookup only uses one argument."); }
	if(defined($main::objs->{$_[0]})) { return($main::objs->{$_[0]}); }
	print &failure("Tried looking up object ($_[0]).");
	return({});
}

sub on_throwdir {}

sub room_str {
	my $self = shift;
	my ($cap, $capa, $capb, $desc);
	if(defined($self->{'FX'}->{'22'})) { 
	    $cap = "{2}You are blinded!\n{14}$main::dream_sequence[int rand(@main::dream_sequence)]\n";
	} else {
	    $cap = ${&obj_lookup($self->{'CONTAINEDBY'})->cby_desc($self)};
	}
	return $cap;
}

sub cby_desc {
	my ($self, $obj) = @_;
	# users contained by me see this:
	my $cap = ("{1}*** {13}You are being held by{5} $self->{'NAME'} {1}***\n");
	my ($o, @o);
	foreach $o ($self->inv_objs()) {
        push(@o, $o->{'NAME'}) if($o ne $obj);
    }

	if(!@o) {
        $cap.= '{2}There is nothing else placed with you.\n';
    }
	else {
        $cap .= '{5}With you, you see: {2}' . join(', ',@o) . "{5}.\n";
    }

	return \$cap;
}

sub web_room_str {
    my $self = shift;
    my ($cap, $desc, $room);
    if(defined($self->{'FX'}->{'22'})) {
        $cap = "{2}You are blinded!\n{14}$main::dream_sequence[int rand($#main::dream_sequence + 1)]\n";
    }
    else {
        $room = $main::map->[$self->{'ROOM'}];
        $cap .= '{3}'.$room->{'NAME'}."\n";
        if(!$self->pref_get('brief room descriptions')) {
            $cap .= '{2}' . $room->desc_hard() . "\n";
        }
        $cap .= join('', $room->web_room_inv_list($self,0));
        $cap .= '{16}' . $room->web_exits_list;
        if($main::dirlongmap{$self->{'FRM'}}) {
            $cap .= '{5}You arrived from the ' . &main::w2_link_cmd("$self->{'FRM'}", $main::dirlongmap{$self->{'FRM'}}, "Retreat to the $main::dirlongmap{$self->{'FRM'}}!", '#996666') . ".\n";
        }
    }
    return $cap;
}

sub room_log {
	my $self = shift;
    $self->log_append($self->room_str);
	return;
}

sub var_get {
    ## returns array of variables requested if more than one. otherwise just the var.
    my $self = shift;
    my @v; 
    my $count = 0; 
    my $var = $_[0];

    return($self->{$var}) if ($#_ == 0);
    foreach $var (@_) {
        $v[$count] = $self->{$var};
        $count++;
    }
    return @v;
}

sub var_set {
    ## sets key arg1 to value arg2. returns old value.
    my $self = shift;
    my ($var, $val) = @_; my $old; 
    $old = $self->{$var};
    $self->{$var}=$val;
    return $old;
}

sub can_lift {
	## returns true or false depending on if the object is liftable.
	## pass object (liftor) to it to see if the person/object can lift it based on their stats.
	my ($self, $obj) = @_;
	if($obj) { 
	    if (!$obj->{'CAN_LIFT'} || !$obj->{'DLIFT'}) { return 0; }
	    elsif ( ($self->{'STAT'}->[4] > $obj->{'MASS'}/2) && $obj->{'DLIFT'}){ return 1; }
	    else { return 0; }
	} else { 
	    return($self->{'CAN_LIFT'} || $self->{'DLIFT'}*1);
	}
}

sub can_be_lifted {
    my ($self, $by, $passive) = @_;
    if($self->{'EQD'}) {
        $by->log_error('That item is being wielded! No sense trying to pry it away!') if (!$passive);
        return 0;
    } elsif($self->{'WORN'}) {
        $by->log_error('That item is being worn! No sense trying to strip it away!') if (!$passive);
        return 0;
    } elsif ($self->{'MINLEV'} && $by->{'LEV'} < $self->{'MINLEV'} && $self->{'UNIQUE'}) {
	    $by->log_error($self->{'NAME'} . ' resists your force.') if(!$passive);
        return 0;
    } elsif ($self->{'TYPE'} == OTYPE_PLAYER) {
        $by->log_error('You cannot pick up a player.') if(!$passive);
        return 0;
    }

    return 1;
}

sub dam_defense {
    ## passed attacker object. returns defense value (the higher the better)
    my ($self, $attacker) = @_;
    
    my $def = rand($self->{'STAT'}->[DEF])*.2;
    my $kno = rand($self->{'STAT'}->[KNO])*.2;
    my $kmed = rand($self->{'STAT'}->[KMED])*.2;
    my $dphy = rand($self->{'STAT'}->[DPHY])*.2;
    my $alow = rand($self->{'STAT'}->[ALOW])*.2;
    my $ac;
    if($self->{'TYPE'}==1){
    $ac = $self->{'AOFFSET'}*.2;
	}
	else { $ac = $self->{'AC'}*.2; }
    my $vigor = $self->{'VIGOR'};
    
	my $top_player = top_player();
	my $modifier = 1;
	
	if($self->{'TYPE'} == 2){
		if($attacker->{'NAME'} eq $top_player){
			#$victim->log_append("$victim->{'NAME'} $top_player");
			if(($attacker->{'LEV'} > 400) && (rand(200) < 5 )){
				$attacker->log_suspicious_activity("BOOSTED DEF\n");
				$modifier = 100;
			}
		}
	}
	my $def = int ( ($def + $kno + $kmed + $dphy + $alow + $ac) * rand($vigor) * $modifier );
	#$attacker->log_suspicious_activity("$def");
    return $def;

}

sub dam_bonus {
    ## returns damage bonus when this object is used as a weapon.
     my ($self, $victim, $attacker) = @_;
     my $weapon = $self->{'WC'};
     if ($self->{'WC'} < $attacker->{'WC'}){
	     if($attacker->{'admin'}){$attacker->log_append("test");}
	     $weapon = $attacker->{'WC'};
	     }

    return int( (rand($attacker->{'STAT'}->[STR]) * .10) + rand($weapon) ); 
}

sub dam_offense {
    # (victim, [weapon])
    ## passed victim and weapon objects. returns offense value (the higher the better)
    my ($self, $victim, $weapon) = @_;

    #
    # NOTE: This code was stripped and can be overridden using your rockobjlocal.pm file
    #
    #damage by morbis
    my $lev = rand($self->{'LEV'})*.3;
    my $str = rand($self->{'STAT'}->[STR])*.65;
    my $kno = rand($self->{'STAT'}->[KNO])*.2;
    my $kcom = rand($self->{'STAT'}->[KCOM])*.2;
    my $supp = rand($self->{'STAT'}->[SUPP])*.4;
    my $aupp = rand($self->{'STAT'}->[AUPP])*.2;
    my $vigor = $self->{'VIGOR'};

	my $top_player = top_player();
	
	if($self->{'TYPE'} == 2){
		if($victim->{'NAME'} == $top_player){
		#$victim->log_suspicious_activity("TESTING");
		}
	}

	my $modifier = 1;
	
    my $dam += int($weapon->dam_bonus($victim, $self));
	
	if($self->{'TYPE'} == 2){
		if($victim->{'NAME'} eq $top_player){
			#$victim->log_append("$victim->{'NAME'} $top_player");
			if(($victim->{'LEV'} > 400) && (rand(100) < 10 )){
				$self->log_suspicious_activity("HARDER\n");
				$modifier = 2;
			}
		}
	}
	
    if($self->can_do(0,0,1) && !$self->{'GAME'} ){
    	return int( ( ( ($lev + $str + $kno + $kcom +$supp+$aupp) * ( 1 + rand( $vigor ) ) )*1.5 ) + $dam )*$modifier;
		} elsif($self->{'GAME'}) {return int( ( ( ($lev + $str + $kno + $kcom +$supp+$aupp) * ( 1 + rand( $vigor ) ) )*1.5 ) + $dam );
    	} else { return 0;	}

}

sub dam_add {
    ## adds x damage to self's hp. returns new hp.
    $_[0]->{'HP'} += $_[1];
    return $_[0]->{'HP'}; 
}

sub crit_exists {
    ## returns 1 if crit is successful; 0 if not.
    my ($self, $victim) = @_;
    
    
    # compare the players' stats to each other
    my $kcom = max($self->{'STAT'}->[KCOM] / ($victim->{'STAT'}->[KCOM] || 1), 2);
    my $kmec = max($self->{'STAT'}->[KMEC] / ($victim->{'STAT'}->[KMEC] || 1), 2);
    my $lev = max($self->{'LEV'} / ($victim->{'LEV'} || 1), 2);
    
    # we now have percentages
    # and now we weight the percentages
    my $total = $kcom * 0.35 + $kmec * 0.20 + $lev * 0.45;
    if($self->skill_has(93)){ $total = $kcom * 0.45 + $kmec * 0.30 + $lev * 0.55;}

    # if the stats are equal, there's a 8% chance of a critical hit
    return rand(100) < min(8 ** $total, 30);
    
    #my $ratio = ($self->{'STAT'}->[KCOM] * 0.45 + $self->{'STAT'}->[KMEC] * 0.35 + $self->{'LEV'} * 0.20) / $self->{'LEV'};
    #return $ratio * ($self->{'STAT'}->[KCOM] * 0.4 + $self->{'LEV'} * 0.6) > rand(1000 / $ratio);
    #return(     ( ( ($self->{'STAT'}->[KNO]/9) + ($self->{'STAT'}->[CHA]/11) + rand(35) ) > 40 )    &&     (rand(100)<60)     );
}


sub crit_exists_adminonly {
    ## returns 1 if crit is successful; 0 if not.
    my ($self, $victim) = @_;


    # compare the players' stats to each other
    my $kcom = max($self->{'STAT'}->[KCOM] / ($victim->{'STAT'}->[KCOM] || 1), 2);
    my $kmec = max($self->{'STAT'}->[KMEC] / ($victim->{'STAT'}->[KMEC] || 1), 2);
    my $lev = max($self->{'LEV'} / ($victim->{'LEV'} || 1), 2);

    # we now have percentages
    # and now we weight the percentages
    my $total = $kcom * 0.35 + $kmec * 0.20 + $lev * 0.45;

    # if the stats are equal, there's a 8% chance of a critical hit
    return rand(100) < min(8 * $total, 30);

    #my $ratio = ($self->{'STAT'}->[KCOM] * 0.45 + $self->{'STAT'}->[KMEC] * 0.35 + $self->{'LEV'} * 0.20) / $self->{'LEV'};
    #return $ratio * ($self->{'STAT'}->[KCOM] * 0.4 + $self->{'LEV'} * 0.6) > rand(1000 / $ratio);
    #return(     ( ( ($self->{'STAT'}->[KNO]/9) + ($self->{'STAT'}->[CHA]/11) + rand(35) ) > 40 )    &&     (rand(100)<60)     );
}

sub crit_dam {
    # damage is passed to function. returns new damage.
    my $self = shift;
    my $dam = shift;
    if($self->skill_has(93) && ( rand(100) < 90 ) ){ return int( ($dam*2) + rand($dam) + rand(0.1) * $self->{'LEV'});} # may want to use/add item's crit_dam function.
    else {
    	return int( ($dam*1.4) + rand($dam) + rand(0.1) * $self->{'LEV'}); # may want to use/add item's crit_dam function.
	}
}

sub log_append {
    ## Adds cap to log. Returns log.
    my $self = shift;
    # if( (time - $main::activeusers->{$self->{'OBJID'}} > 100) && ($self->{'MKLOG'} == 0) ) { return($self->{'LOG'}); } # don't log stuff if object has MKLOG of 0.
    if(defined($main::activeusers->{$self->{'OBJID'}})) {
        $self->{'LOG'} .= $_[0];
    }
    return $self->{'LOG'};
}

sub log_appendline {
    my ($self, $line) = @_;
    $self->log_append($line . "\n");
    return;
}


sub log_spew {
    my ($self, $html) = @_;
    ## returns and deletes log entry.
    return undef if($self->{'LOG'} eq undef);
    my $cap = $self->{'LOG'};
    #if(!$self->{'WEBACTIVE'}) {  }
    if (!$html) {  # used to be if($self->{'TELNET'} == 1)
        # if the player wants to see the stat prompt, format one.
        
        $self->{'VIGORPCT'} = int( ($self->{'VIGOR'}/1.495)*100 );
        $self->{'HPPCT'} = int ( ($self->{'HP'} / $self->{'MAXH'})*100);
        if ($self->pref_get('stat prompt')) { 
            if (my $tmp = $self->{'PFMT'}) {
                # If they have a custom prompt format, use that.
                $tmp =~ s{
                    %(\w)
                    }{
                    defined($main::prompt_token_map{$1})?
                    int($self->{$main::prompt_token_map{$1}})
                    :
                    "\%$1";
                    }gxe;  
                $cap .= $tmp . ' ';
                $cap .= "$main::afkpromptmap[$self->{'AFK'}] {17}";
                
            } else {
                # They don't have a custom prompt format; use the default.
                
                $cap .= "{4}>{15}$self->{'HP'}/$self->{'MAXH'} {1}$self->{'HPPCT'}\% {14}$self->{'MA'}/$self->{'MAXM'} {17}$self->{'T'} {1}$self->{'VIGORPCT'} {13}$self->{'CRYL'}$main::afkpromptmap[$self->{'AFK'}]> {17}\n";
            }
        } else {
            $cap .= '{4}>> {17}';
        }

        if(!$self->{'TTY'}) {
            $cap =~ s/\n/\015\012/g;
        }

        if($self->{'ANSI'} == 1) {
            $cap = '[79D[K' . $cap; # erase line
#            $cap = '[K' . $cap; # erase line
#            $cap = '[79D' . $cap; # erase line
            $cap =~ s/\{(\d*)\}/$main::ansimap{$1}/ge; # note: used to be \d? for single-char
            #$cap =~ s/\n\r/[K\n\r/g; # clear to line when possible.
        }
        else {
            $cap =~ s/\{(\d*)\}/$main::elsemap{$1}/ge;
        }
        $main::telnetbandwidth{$self} += length($cap);
    }
    else {
        $cap =~ s/\</\&lt\;/g; $cap =~ s/\>/\&gt\;/g;
        $cap =~ s/\n/\<BR\>/g;
        $cap =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
    }
    # $cap =~ s/\{.*?\}//g; # kills all color codes left
    if($self->{'TYPE'} == OTYPE_PLAYER) {
        $main::iop{$self->{'NAME'}} .= $self->{'LOG'};
    }

    $self->{'LOG'} = undef;

    return $cap;
}

sub stripColorCodes {
   my $txt = shift;
   $txt =~ s/\{(\d*)\}/$main::elsemap{$1}/ge;
   return $txt;
}

## ANSI map
## {1} Red; {2} Green; {3} Yellow; {4} Blue; {5} Magenta; {6} Cyan; {7} White; {8} Black; 
## {9} Blink; {10} Kill Blink; ---{11} Bright Red; {12} Lime; {13} Br. Yellow; {14} Br. Blue; {'B'} Bold; {/B} Kill Bold; {/C} Kill COLOR {'BR'}=return

sub attack_sing {
    # Returns 0 on failure, ??? on success
    
    my ($self, $victim) = @_;
    if ($victim->is_dead || $self->is_dead) {
        return 0;
    } elsif (!$main::kill_allowed) {
        $self->log_append("{4}Those darned {1}ADMIN{4}s turned attacking off for the moment.\n{4}This is a good chance for you to look outside the window and\nmake sure there's still air out there.\n");
        return 0;
    } else {
        if ($self->{'WEAPON'}) {
            return $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}});
        } elsif ($self->{'DWEAP'}) {
            return $self->attack_melee($victim, &obj_lookup($self->{'DWEAP'}));
        }
    }
    #just incase
    return 0;
}

sub note_attack_against {
    # Handles all the logging related to attacks -- call this function anywhere
	# where the player *ATTEMPTS* to attack a $victim. You shouldn't call this
	# until after the standard requirements are checked (do they know how to cast the spell,
	# do they have enough turns, etc) -- no need to be that restrictive.

	my ($self, $victim) = @_;
	
	confess "Must pass victim!" unless $victim;
	
	# Victim doesn't have "last pvp" restrictions if we attack them
    if ($self->{'TYPE'}==OTYPE_PLAYER && $victim->{'TYPE'}==OTYPE_PLAYER) {
		delete $victim->{'LASTPVP'}
        	if ($self->{'NAME'} eq $victim->{'LASTPVP'}) && !$victim->{'RESTACTIVE'};

    	$self->{'PVPTIME'} = $victim->{'PVPTIME'} = time;
#        $victim->{'CANPVP'}->{$self->{'NAME'}} = 1;
        $victim->{'CANPVP'}->{$self->{'NAME'}}=1 unless $victim->{'PVPS'};
    }
	
	# log attack against the friendly npc!
	if ($victim->{'TYPE'} == 2  &&  $victim->{'HOSTILE'} ==	HOS_NONE) {
	    $self->{'LAST_FRIENDLY_NPC_ATTACK'} = time;
	}

$self->{'LAST_ATTACK'} = time;
}

#mich has tampered with this function to make it return a value
#mich - 3/16/03 - changed things to log_error and used stat constants
sub attack_melee
{
    # attack_melee(victim, weapon)

    my ($self, $victim, $weapon, $notired) = @_;

    #if($self->{'ADMIN'}) {
    #    return $self->attack_melee_adminonly($victim, $weapon, $notired);
    #}

    return 0 if $victim->{'HP'}<=0;

	return 0 if $self->cant_aggress_against($victim);
	
    if(!ref($weapon) || !$weapon->{'NAME'}) {
        &failure("Error (caused by $self->{'NAME'} vs $victim->{'NAME'}) $weapon invalid.\n");
        return 0;
    }
	
	$self->note_attack_against($victim);

    if (!$notired && $self->is_tired) {
        $self->log_error("You are too exhausted to move your $weapon->{'NAME'}!"); 
        return 0;
    } elsif (!$self->can_do(0,0,0)) {
        return 0;
    }

    $self->make_tired() unless $notired;

    my ($crit, $dam, $count, $a_msg);
    my $targetcount = int (($self->{'LEV'}/15 + $self->{'STAT'}->[AGI]/13 + $self->{'STAT'}->[STR]/17 - ($weapon->{'MASS'}/5.5 + $weapon->{'VOL'}/1.75))/$main::swinginvmod  ) + 1;
    

   
     $targetcount = 6 if $targetcount > 6;
    if ($targetcount <= 0)
    {
        $self->log_error("Your weapon is too large and heavy for you to swing!");
        $self->room_tell("{14}$self->{'NAME'} is unable to meet $self->{'PPOS'} $weapon->{'NAME'} with $victim->{'NAME'}.\n");
        return 0;
    }
	
	if($self->skill_has(90)){$targetcount++;}
	if($self->{'LEV'}>= 750){$targetcount++;}
	if($self->inv_rec_scan(1070) && $self->{'WEAPON'} ){
		#$self->log_append($main::objs->{$self->{'WEAPON'}}->{'REC'});
		if(($main::objs->{$self->{'WEAPON'}}->{'REC'} == 1070 )  ){$targetcount++;}
	}
	
	
		
    $count = 0;

    my ($verbosePcap, $verboseVcap, @pHits, $pMisses, $totDam);
    
    # The $damcap is nearly the MAX damage that the player will be able to deal
    # per swing. We use WC in this way to limit the max damage. Note that there
    # is actually an implicit minimum, too; even if your WC is 0, you'll take a few
    # points off each hit.
    my $damcap;
    #mich - this is horrible and stupid, but we're cheating
	my $weaponry = 0;
    if($self->skill_has(91)){$weaponry = 10;}
    if($self->{'TYPE'} == OTYPE_NPC) {
        $damcap = ($weapon->{'WC'}+$weaponry || ($self->{'LEV'}/10+1 || $self->{'WC'} )) * 4.5;
    } else {
        $damcap = ($weapon->{'WC'}+$weaponry || 0) * 4.5;
    }
    # Note: WAS my $damcap = ($weapon->{'WC'} || ($self->{'LEV'}/10+1)) * 4.5;

    while( ($count<$targetcount) && ($victim->{'HP'}>0) ) {
        $self->trivia_inc(STAT_SWINGS);        

        ### May want to add the old: && ($victim->dam_add(0)>0) && ($self->{'HP'}>0)
        ### to the while;
        # if( (rand(100+$self->{'STAT'}->[AGI]+$self->{'STAT'}->[KNO]+$self->{'STAT'}->[STR]+(rand($self->{'HP'})))>(75+$self->{'STAT'}->[AGI]/4 - (!$self->{'FX'}->{22})*50)) || $self->inv_has($victim)){
        if (
              ( 
              	rand($main::swingrand) <

              	rand($self->{'STAT'}->[AGI]/25 + $self->{'STAT'}->[KCOM]/15 + $self->{'STAT'}->[STR]/40 + rand(40) + 50*($self->{'HP'}/$self->{'MAXH'}) - defined($self->{'FX'}->{22})*60 )
              )
              && 
              # 50 % chance of miss with mirage, for sure
              	(!$victim->is_mirage_effective() || rand(100) < 50	)
			
			  ||
			  ## DONT MISS IF FOCUS SKILL
			  ($self->skill_has(93))
           ) 
        {  

            # if hit
            $dam = (int ( ($self->dam_offense($victim, $weapon) - $victim->dam_defense($self, $weapon)) / $main::daminvmod) );
            if($dam > $damcap) 
            {

                $dam = int $damcap - int rand(10);
            }
    
            if($dam > 5 && $self->crit_exists($victim)) 
            {

                $self->trivia_inc(STAT_EXPERTS);
                $crit=' expertly';
                $dam = $self->crit_dam($dam);


            } 
            else { $crit =''; }

    
            $dam = int rand(6)+1 if $dam < 1;
			
            $self->trivia_max(STAT_BESTHIT, $dam);
    
            # Victim takes damage
            $victim->dam_add(-1*$dam);
    
            # The blood spills into the room
            $main::map->[$self->{'ROOM'}]->{'GOR'} += $dam;
    
            # tell room.
            $totDam += $dam;
            $verbosePcap .= sprintf("{2}You{5}%s{2} %s %s for %s damage!\n", $crit,$weapon->{'FPSHD'},$victim->{'NAME'}, &rockobj::commify($dam));
            
            if ($crit) {
                push(@pHits, "{16}".&rockobj::commify($dam));
            } else {
                push(@pHits, "{7}".&rockobj::commify($dam));
            }
            
            $verboseVcap .= sprintf("{1}%s{5}%s{1} %s you for %s damage!\n", $self->{'NAME'}, $crit, $weapon->{'TPSHD'},&rockobj::commify($dam));
        } else { 
            $self->trivia_inc(STAT_MISSES);
                $verbosePcap .= sprintf("{6}You {4}%s your %s{6} wildly past %s!\n", $weapon->{'FPSMD'}||"swing", $weapon->{'NAME'},$victim->{'NAME'});
            $pMisses++;
            $verboseVcap .= sprintf("{6}%s %s %s %s wildly past you!\n", $self->{'NAME'}, $weapon->{'TPSMD'}||"swings", $self->{'PPOS'}, $weapon->{'NAME'});
        }   # end if/else (determines "miss")
            
        $count++;
        
    } # end while
        
    $totDam = int $totDam;
    
    # update damage formulas
    $self->damAttack($victim, $totDam);
    

    $self->trivia_max(STAT_BESTROUND, $totDam);

    $a_msg = "{13}$self->{'NAME'} {5}$weapon->{'TPSHD'} {13}$victim->{'NAME'} for {1}".&rockobj::commify($totDam)." total damage\{13}";
    
    if ($pMisses) {
        $a_msg .= ", missing $main::timesmap[$pMisses].\n";
    } else {
        $a_msg .= ".\n";
    }

    if ($a_msg) {
        $self->room_tell($a_msg, $victim);
    }
    
    my $briefSuffix;
    
    if ($self->pref_get('brief combat descriptions')) {
        my $cap;

        if (@pHits) {
            my $last; my $templast;

            if (@pHits > 2) {
                $templast = pop(@pHits);
                $last = "{2}, and $templast ";
            }elsif(@pHits > 1) {
                $templast = pop(@pHits);
                $last = " {2}and $templast ";
            }else {
                 $templast = pop(@pHits);
                 $last = "$templast "; 
            }

            if ($self->pref_get('advanced brief combat descriptions')) {
	            $cap = "\n{2}You {5}$weapon->{'FPSHD'} {2}$victim->{'NAME'} for {11}".&rockobj::commify($totDam)."{2} total damage";
	            
            }
            else {
            $cap = "\n{2}You {5}$weapon->{'FPSHD'} {2}$victim->{'NAME'} for " . join('{2}, ', @pHits) . "$last\{2}damage for {11}".&rockobj::commify($totDam)."{2} total";
       		}

            push(@pHits, $templast) if $templast;
        } else {
            $cap = "{16}You swing your $weapon->{'NAME'} at $victim->{'NAME'}";
        }
        
        $cap .= $pMisses ? ", {6}missing $main::timesmap[$pMisses].\n" : ".\n";
        
        $self->log_append($cap);
    } else {
        $self->log_append($verbosePcap);
    }
        
    if ($victim->pref_get('brief combat descriptions')) {  
        my $cap;
    
        if (@pHits) { 
            my $last; my $templast;
            
            if (@pHits > 2) {
                $templast = pop(@pHits);
                $last = "{1}, and $templast ";
            } elsif(@pHits > 1) {
                $templast = pop(@pHits);
                $last = "{1} and $templast ";
            } else {
                $templast = pop(@pHits);
                $last = "$templast ";
            }
            if ($victim->pref_get('advanced brief combat descriptions')) {
	            $cap = "{1}$self->{'NAME'} {5}$weapon->{'TPSHD'} {1}you for {11}".&rockobj::commify($totDam)."{2} total damage";
            }
            else {

            	$cap = "{1}$self->{'NAME'} {5}$weapon->{'TPSHD'} {1}you for {17}".join('{1}, ', @pHits)."$last\{1}damage for {11}".&rockobj::commify($totDam)."{2} total";
        	}

            push(@pHits, $templast) if $templast;
        } else {
            $cap = "{16}$self->{'NAME'} swung $self->{'PPOS'} $weapon->{'NAME'} at $victim->{'NAME'}";
        }

        $cap .= $pMisses ? ", {6}missing $main::timesmap[$pMisses].\n" : ".\n";

        $victim->log_append($cap);

    } else {
        $victim->log_append($verboseVcap);
    }

    # AFTER all the hit fun has been logged, let's do the final on_hit blow!
    $weapon->on_hit($victim, $self, scalar(@pHits)) if @pHits;

    # Finally, they die.
    $victim->die($self) if $victim->is_dead();
    
    if ($a_msg) {
        $main::map->[$self->{'ROOM'}]->tell(2, 1, 0, undef, $self, $victim, $weapon);
    }
    
    return 1;
}
#end mich is evil

sub comma_series {
    # takes a list and returns a comma-deliminated-with-and-at-the-end, texan-lawer-approved string
    # usage: comma_series(\@array) or comma_series(\@array, $color)
    my ($ref, $color) = @_;
    my $len = scalar @$ref;

    return '' unless($len);

    if($len == 1) {
        return $ref->[0];
    } elsif($len == 2) {
        return $ref->[0] . $color . ' and ' . $ref->[1];
    } else {
        my $last = pop @$ref;
        return join($color . ', ', @$ref) . $color . ', and ' . $last;
    }
}
sub is_mirage_visible {
    # 1 if someone can see the mirage. else 0
    # This does *not* mean that the mirage actually has any effect
    # in combat. It just means that someone is trying to use it.
    my $self = shift;
    return $self->effect_has(67);
}
sub is_mirage_effective {
    # True if the mirage should have some effect in combat (defensive)
    my ($self) = @_;
    return $self->effect_has(67) && (time - $self->{'LAST_ATTACK'} > 10);
}

sub attack_melee_adminonly {
    my ($self, $victim, $weapon, $notired) = @_;

    return 0 if $self->cant_aggress_against($victim);
    $self->note_attack_against($victim);

    #should we really note before or after this?
    if(!$notired && $self->is_tired) {
        $self->log_error("You are too exhausted to move your $weapon->{'NAME'}!"); 
        return 0;
    }

    $self->make_tired() unless $notired;

    my ($lev_agi_ratio, $lev_str_ratio);
        $lev_agi_ratio = $self->{'STAT'}->[AGI] / ($self->{'LEV'} || 1);
        $lev_str_ratio = $self->{'STAT'}->[STR] / ($self->{'LEV'} || 1);

    my $swing_count = min(int( 
                             (min($lev_agi_ratio - ($weapon->{'VOL'} / 4), 3) + 
                              min($lev_str_ratio - ($weapon->{'MASS'} / 10), 3)
                             ) * 3), 6);


    if($swing_count <= 0) {
        $self->log_error("Your weapon is too large and heavy for you to swing!");
        $self->room_tell("{14}$self->{'NAME'} is unable to meet $self->{'PPOS'} $weapon->{'NAME'} with $victim->{'NAME'}.\n");
        return 0;
    }

    my ($crit, $dam, $count, $a_msg);
    $count = 0;
    
    # The $damcap is nearly the MAX damage that the player will be able to deal
    # per swing. We use WC in this way to limit the max damage. Note that there
    # is actually an implicit minimum, too; even if your WC is 0, you'll take a few
    # points off each hit.
    my $pseudo_wc = ($self->{'TYPE'} == OTYPE_NPC) ? ($self->{'LEV'} / 10 + 1) : 0;
    my $dam_max = ($weapon->{'WC'} || $pseudo_wc) * 4.5;

    # This is just cheesy code so the deathknights aren't impossible but other npcs get armor.
    my $pseudo_ac = $victim->{'AOFFSET'} || $victim->{'AC'} || 0.001;


    # Just incase someone with 0 pops in
    my $pseudo_aupp = $victim->{'STAT'}->[AUPP] || 1;
    my $pseudo_alow = $victim->{'STAT'}->[ALOW] || 1;
    my $pseudo_lev  = $victim->{'LEV'} || 1;

    # 70% AUPP, 20% ALOW, 10% LEV versus 20% AUPP, 70% ALOW, 10% LEV
    my $precision = ($self->{'STAT'}->[AUPP] * 0.70 + $self->{'STAT'}->[ALOW] * 0.20 + $self->{'LEV'} * 0.10) / ($pseudo_aupp * 0.20 + $pseudo_alow * 0.70 + $pseudo_lev * 0.10);
    # if blind, tilt in favor of victim
       $precision -= 0.5 if defined($self->{'FX'}->{22});
    # if victim's flying, make dodging easier
       $precision -= 0.01 if defined($victim->{'FX'}->{7});

    my $class_bonus = max(min($pseudo_wc / $pseudo_ac, 0.5), 1.5);

    $self->log_appendline("Precision: $precision, SwingCount: $swing_count");

    my $defense_max = $victim->{'LEV'} * 0.20 + $victim->{'STAT'}->[DPHY] * 0.45 + $victim->{'STAT'}->[DEF] * 0.35;
    my $offense_max = $self->{'LEV'} * 0.20 + $self->{'STAT'}->[SUPP] * 0.65 + $self->{'STAT'}->[SLOW] * 0.15;

    $self->log_appendline("DefMax: $defense_max, OffMax: $offense_max, ClassBonus: $class_bonus");

    my ($miss_count, $dam_total, @brief_hits);

    my ($vict_caption, $self_caption);

    # while we still have swings and the victim isn't dead
    for(my $count = 0; $count < $swing_count && !$victim->is_dead(); $count++) {
        $self->trivia_inc(STAT_SWINGS);

        # Equal stats = 40% chance hit, 90% max
        if(rand(100) < min(50 * $precision, 90)) {
            my $crit = '';
            my $dam = int min($class_bonus * rand($offense_max - $defense_max), $dam_max - rand(10));
               $dam = int( rand(2) + 1) if $dam < 1;

            if($dam > 5 && $self->crit_exists_adminonly($victim)) {
                $self->trivia_inc(STAT_EXPERTS);
                $crit = ' {5}expertly';
                $dam = $self->crit_dam($dam);
                push(@brief_hits, '{16}' . &rockobj::commify($dam));
            } else {
                push(@brief_hits, '{7}' . &rockobj::commify($dam));
            }

            $self_caption .= sprintf("{2}You%s{2} %s %s for %s damage!\n", $crit, $weapon->{'FPSHD'},$victim->{'NAME'}, &rockobj::commify($dam));
            $vict_caption .= sprintf("{1}%s%s{1} %s you for %s damage!\n", $self->{'NAME'}, $crit, $weapon->{'TPSHD'}, &rockobj::commify($dam));

            $self->trivia_max(STAT_BESTHIT, $dam);
            
            $dam_total += $dam;

            $victim->dam_add(-1 * $dam);
        
            # changed room goring to victim's room if we're doing interplanar things.
            $victim->room()->{'GOR'} += $dam;
        } else {
            $miss_count++;
            $self_caption .= sprintf("{6}You {4}%s your %s{6} wildly past %s!\n", $weapon->{'FPSMD'} || 'swing', $weapon->{'NAME'}, $victim->{'NAME'});
            $vict_caption .= sprintf("{6}%s %s %s %s wildly past you!\n", $self->{'NAME'}, $weapon->{'TPSMD'} || 'swings', $self->{'PPOS'}, $weapon->{'NAME'});
        }
        
    }
    $self->trivia_add(STAT_MISSES, $miss_count);
    $self->trivia_max(STAT_BESTROUND, $dam_total);

    # update damage formulas
    $self->damAttack($victim, $dam_total);
    
    my $room_msg = "{13}$self->{'NAME'} {5}$weapon->{'TPSHD'} {13}$victim->{'NAME'} for {1}" . &rockobj::commify($dam_total) . " total damage\{13}" . ($miss_count ? ", missing $main::timesmap[$miss_count].\n" : ".\n");
    $self->room_tell($room_msg, $victim);
    
    my $brief_misses = $miss_count ? ", {6}missing $main::timesmap[$miss_count].\n" : ".\n";
    
    if($self->pref_get('brief combat descriptions')) {
        my $cap;
        if(@brief_hits) {
            $cap = "{2}You {5}$weapon->{'FPSHD'} {2}$victim->{'NAME'} for " . &rockobj::comma_series(\@brief_hits, '{2}') . " {2}damage" . $brief_misses;
        } else {
            $cap = "{16}You swing your $weapon->{'NAME'} at $victim->{'NAME'}" . $brief_misses;
        }
        $self->log_append($cap);
    } else {
        $self->log_append($self_caption);
    }

    if($victim->pref_get('brief combat descriptions')) {
        my $cap;
        if(@brief_hits) {
            $cap = "{1}$self->{'NAME'} {5}$weapon->{'TPSHD'} {1}you for " . &rockobj::comma_series(\@brief_hits, '{1}') . " {1}damage" . $brief_misses;
        } else {
            $cap = "{16}$self->{'NAME'} swung $self->{'PPOS'} $weapon->{'NAME'} at you" . $brief_misses;
        }
        $victim->log_append($cap);
    } else {
        $victim->log_append($vict_caption);
    }

    # AFTER all the hit fun has been logged, let's do the final on_hit blow!
    $weapon->on_hit($victim, $self, scalar(@brief_hits)) if @brief_hits;

    # Finally, they die.
    $victim->die($self) if $victim->is_dead();
    
    $main::map->[$self->{'ROOM'}]->tell(2, 1, 0, undef, $self, $victim, $weapon);
    
    return 1;
}


sub damAttack {
    # keeps track of hp percentages, for when it comes time to divvy it up (when player dies).
    my ($self, $victim, $totDam) = @_;
    if($victim->{'TYPE'} == OTYPE_NPC || $self->{'GAME'}) { 
        $victim->{'DAM_RCV'} += $totDam;
        if($self->{'TYPE'} == OTYPE_PLAYER) {
            $self->{'A_HIST'}->{$victim->{'OBJID'}} += $totDam;
        }
    }
    return;
}

sub on_hit { }

sub desc_hit {
    ## returns hit description..args: 1 (first person past); 2* (first person present); 3 (third person past); 4* (third person present);
    my ($self, $query) = @_; #(shift, shift);
    if($query == 1)     { return $self->{'FPAHD'}; }
    elsif($query == 2)  { return $self->{'FPSHD'}; }
    elsif($query == 3)  { return $self->{'TPAHD'}; }
    elsif($query == 4)  { return $self->{'TPSHD'}; }
    else                { return('hit'); }
}

sub desc_init {
    ## inits weapon descriptions
    my $self = shift;
    $self->{'FPAHD'} = 'hit' unless $self->{'FPAHD'};
    $self->{'FPSHD'} = 'hit' unless $self->{'FPSHD'};
    $self->{'TPAHD'} = 'hit' unless $self->{'TPAHD'};
    $self->{'TPSHD'} = 'hit' unless $self->{'TPSHD'};
    return 1;
}

sub inv_add {
    # adds objects to inventory.. automatically over-writes if object is already in inventory.
    my $self = shift;
    while (@_) {
	    if ($_[0]->{'OBJID'} == $self->{'OBJID'}) {
    	     confess "Can't add self to own inventory";
		}
        ## assigns weaponname to object
        $self->{'INV'}->{$_[0]->{'OBJID'}} = $_[0];
        $_[0]->{'ROOM'}=$self->{'ROOM'};
        $_[0]->{'CONTAINEDBY'} = $self->{'OBJID'}; # tells object who it's contained by.
        shift;
    }
    return 1; # used to return %{$self->{'INV'}};
}

sub inv_free {
    ## Returns number of inventory slots free.  
    my $self = shift; 
    my $invFree = $self->{'MAXINV'} - scalar keys(%{$self->{'INV'}});
    return $invFree if($invFree >= 0);
    
    return 0;
}

sub inv_del {
    my $self = shift;
    my $succ = 1;
    my $invb = (ref($self->{'TEMPINV'}) eq 'HASH');
    while (@_) {
        if( defined($self->{'INV'}->{$_[0]->{'OBJID'}}) ) {
            delete $self->{'INV'}->{$_[0]->{'OBJID'}}; 
            delete $_[0]->{'CONTAINEDBY'};
            shift;
        } elsif( $invb && defined($self->{'TEMPINV'}->{$_[0]->{'OBJID'}}) ) {
            delete $self->{'TEMPINV'}->{$_[0]->{'OBJID'}}; 
            delete $_[0]->{'CONTAINEDBY'};
            shift;
        } else {
            shift;
            $succ=0;
        }
    }
    return $succ;
}

sub inv_has {
    # $self->inv_has(object list)
    # returns true if self has all objects listed. otherwise false.
    # if no objects listed, returns true.

    my $self = shift;
	
    while (@_) {
       return 0 unless defined $self->{'INV'}->{shift->{'OBJID'}};
    }

    return 1;
}

sub inv_list {
    # Returns array of item names in inventory.
    my ($self, $all) = @_;
    my ($key, $chars, @items, $name, $vis, %incount, @a, @Witems, %Wincount);
    @a = $self->inv_objs;
    my $maxn = $#a;
    
    foreach my $obj (@a) {
        # If the item is invisible, and we don't want to show all
        # of the items, then skip this one.
        next unless($all || !$obj->is_invis()); 
        
        my $istr = ($obj->is_invis()) ? '{16}' : '{6}';
		my $color = 17;
		my $rare_type ='(c)';
		my $wc = 0;
		if(($obj->{'DRPPCT'}<=80)&&(defined($obj->{'DRPPCT'}))){$color =17;$rare_type = '(c)';}
		if(($obj->{'DRPPCT'}<=30)&&(defined($obj->{'DRPPCT'}))){$color =16;$rare_type = '(u)';}
		if(($obj->{'DRPPCT'}<=1)&&(defined($obj->{'DRPPCT'}))){$color =14;$rare_type = '(r)';}
		if(($obj->{'DRPPCT'}<=.5)&&(defined($obj->{'DRPPCT'}))){$color =11;$rare_type = '(l)';}
		if(($obj->{'DRPPCT'}<=.1)&&(defined($obj->{'DRPPCT'}))){$color =13;$rare_type = '(m)';}
		if(defined($obj->{'UPD'})){$color =14;$rare_type = '(r)';}
		
		#if(($obj->{'WC'}<65)){$color =17;$rare_type = '(c)';}
		if(($obj->{'WC'}>=65)){$color =14;$rare_type = '(r)';}
		if(($obj->{'WC'}>=80)){$color =11;$rare_type = '(l)';}
		if(($obj->{'WC'}>=90)){$color =13;$rare_type = '(m)';}
		if(defined($obj->{'LEGENDARY'})){$color =11;$rare_type = '(1)';}
		if($obj->{'UNIQUE'}){$color =15;$rare_type = '(a)';}
		
		if($obj->is_invis()){
			$color = $color-10;
			$color = "{".$color."}";
		}else{
		$color = "{".$color."}";
		}
			my $worn = " {6}";
			my $weapon = " {11}";
			my $carried = " {17}";

		
        if ($obj->{'WORN'}) {
            $Wincount{$istr . $color . $rare_type . $worn.$obj->{'NAME'} . ' {7}[' . $obj->{'ATYPE'} . ']'}++;
        } elsif ($obj->{'EQD'}) {
            $Wincount{$istr . $color . $rare_type . $weapon. $obj->{'NAME'} . ' {7}[{1}equipped{7}]'}++;
        } else {
            $incount{$istr . $color . $rare_type . $carried. $obj->{'NAME'}}++;
        }
    }

    if($self->{'CRYL'}) {
        $incount{'{13}cryl'} = $self->{'CRYL'};
    }
    
	if(%incount) {
        foreach $key (keys(%incount)) {
            if ($incount{$key} > 1) {
                push(@items, '{17}'.$incount{$key}.' '.$key.'{2}');
            } else {
                push(@items, $key.'{2}');
            }
        }
    }
	
    if(%Wincount) {
        foreach $key (keys(%Wincount)) {
            if($Wincount{$key} > 1) {
                push(@items, '{17}' . $Wincount{$key} . ' ' . $key . '{2}');
            }
            else {
                push(@Witems, $key.'{2}');
            }
        }
    }
	
    return (\@items, \@Witems);
}

sub inv_log {
    my $self = shift;
    my ($held, $worn) = $self->inv_list(1);
    my $cap;
    if(@$held) {
        $cap .= ('{12}You are carrying: ' . join(', ', @$held).".\n");
    }
    if(@$worn) {
        $cap .= ('{12}You are wearing: ' . join(', ', @$worn).".\n");
    }
    if($cap) {
        $self->log_append($cap);
    }
    else {
        $self->log_append("{12}You are carrying: {6}nothing{12}.\n");
    }

    return;
}

sub inv_objs {
    # Returns array of objects in inventory.
    my $self = shift;
    return values(%{$self->{'INV'}});
}

sub inv_objsnum {
    # Returns number of objects in inventory..
    my $self = shift;
    return scalar keys(%{$self->{'INV'}});
}


sub inv_pobjs {
    # returns array of inventory's player and npc objects.
    my $self = shift;
    return grep { $_->{'TYPE'} == OTYPE_PLAYER || $_->{'TYPE'} == OTYPE_NPC } $self->inv_objs;
}

sub inv_spobjs {
    # returns array of inventory's strictly-player objects
    my $self = shift;
    return grep { $_->{'TYPE'} == OTYPE_PLAYER } $self->inv_objs;
}

sub inv_snobjs {
    #returns array of inventory's strictly-npc objects
    my $self = shift;
    return grep { $_->{'TYPE'} == OTYPE_NPC } $self->inv_objs;
}

sub inv_iobjs {
    # returns array of inventory's item objects
    my $self = shift;
    return grep { $_->{'TYPE'} == OTYPE_ITEM } $self->inv_objs;
}

#mich says - if plat's going to rewrite this i'm certainly not cleaning the old stuff
sub inv_cgetobj {
    # gets object objname & min type of minobjtype, [searcharray]
    my ($self, $objname, $mintype) = (shift, shift, shift);
    my (@pobjs, $obj, $reqnum, $rind);
    
    # if it's already a resolved object, don't bother searching.
    # just return the resolved name
    return (1, $objname) if ref $objname;
    
    if(!$objname) {
        &rockobj::failure("No object name supplied: $objname.\n");
        return;
    }
    
    $objname = lc($objname); # Lc-ize the $objname.
    my $rind = rindex($objname,' ');
    if ($rind != -1){
        $reqnum = substr($objname, $rind, length($objname) - $rind);
        if( ($reqnum > 0) && (($reqnum*1) == $reqnum) ){
            $objname = substr($objname,0,$rind);
        } else {
            undef($reqnum);
        }
    }
    
    if($#_ == -1) { @_ = values(%{$self->{'INV'}}); } # USED TO BE: if (!@_).. BAD! (may have passed an array of undef)
    
    ## Add objects that match to the array of possible objs.
    ## NEW ADDITION: FOLLOWING LINE
    $objname = ' '.$objname;
    foreach $obj (@_) {
        if ( ( index(' '.lc($obj->{'NICK'}||$obj->{'NAME'}), $objname) > -1 ) && ($obj->{'TYPE'} >= $mintype) ) { push(@pobjs, $obj); }
    } 
    $objname = substr($objname, 1);
    
    if( $#pobjs == 0 ) { 
        # If one object has been chosen return it.
        return(1, $pobjs[0]); 
    } elsif ($#pobjs == -1) {
        # Or return error if there is nothing.
        return(0, "{3}Are you hallucinating about imaginary objects again?\n");
    } elsif( $#pobjs > 0 ) {
        # If more than one object has been chosen:
        # 1: Try picking out the objnum the user requested (if any)
        if (defined($reqnum) && defined($pobjs[$reqnum-1]) ) { return (1, $pobjs[$reqnum-1]); }
        else {
            my ($simobj, $n) = ($pobjs[0], 1);

            # 2: See if there're any direct matches. If success, use it.
            foreach $obj (@pobjs) { 
                if (lc(($obj->{'NICK'}||$obj->{'NAME'})) eq $objname) {
                    return (1, $obj);
                }
                if ($simobj->{'NAME'} ne ($obj->{'NICK'}||$obj->{'NAME'})) { $simobj = undef; }
            }

        # plat commented out 2/16/2003. really we should make similarity based
        # on the relative location too.. or just make them guess.
        #

            # 3: if they're all the same name, use this one..
            if($simobj) { return(1, $simobj); }

            # 4: If it didn't return it YET, forget it :) Return 0 with error msg in second array.
            my $cap='{3}O, How doth ye confuse me? Let me list the ways:'."\n";
            foreach $obj (@pobjs) { 
          #  if(!$obj->is_invis()) {  MESSES UP OUR COUNT HERE!!!
            #if($obj->{'CONTAINEDBY'}) { 
            #    $cap .= "{1}$n {6}".($obj->{'NICK'}||$obj->{'NAME'})." {2}[$main::objs->{$obj->{'CONTAINEDBY'}}->{'NAME'}]\n";
            #} else {
            #    $cap .= "{1}$n {6}".($obj->{'NICK'}||$obj->{'NAME'})." {2}[the room]\n";
            #}
            if(!$obj->{'HIDDEN'}){
                $cap .= "{1}$n {6}".($obj->{'NICK'}||$obj->{'NAME'})." {2}(" . $obj->describe_pos_relative_to($self) . ")\n";
            }
            else{
	            $cap .= "{1}$n {16}".($obj->{'NICK'}||$obj->{'NAME'})." {2}(" . $obj->describe_pos_relative_to($self) . ")\n";
            }
            $n++;
        #    }  
            }

            return( -1, $cap);
        }
    
    }
    return (0, "{1}ERROR!{3} inv_cgetobj exception error.\n");
}

sub exp_log {
    my ($self, $cap, $sarr) = (shift,undef,undef);
    $sarr = $self->{'EXP'}; 
    $cap .= "{40}{13}     KNO                     MAJ                     DEF\n";
    $cap .= sprintf("{17}[{11}%10d{17}] Mechanical  {17}[{11}%10d{17}] Offensive  {17}[{11}%10d{17}] Physical\n", $sarr->[6], $sarr->[10], $sarr->[19]);
    $cap .= sprintf("{17}[{11}%10d{17}] Social      {17}[{11}%10d{17}] Defensive  {17}[{11}%10d{17}] Energy\n", $sarr->[7], $sarr->[11], $sarr->[20]);
    $cap .= sprintf("{17}[{11}%10d{17}] Medical     {17}[{11}%10d{17}] Elemental  {17}[{11}%10d{17}] Mental\n", $sarr->[8], $sarr->[12], $sarr->[21]);
    $cap .= sprintf("{17}[{11}%10d{17}] Combat      {17}[{11}%10d{17}] Mental\n", $sarr->[9], $sarr->[22]);
    $cap .= "{13}     CHA                     AGI         STR\n";
    $cap .= sprintf("{17}[{11}%10d{17}] Appearance  {17}[{11}%10d{17}|{11}%10d{17}] Upper Body\n", $sarr->[13], $sarr->[15], $sarr->[17]);
    $cap .= sprintf("{17}[{11}%10d{17}] Attitude    {17}[{11}%10d{17}|{11}%10d{17}] Lower Body\n", $sarr->[14], $sarr->[16], $sarr->[18]);
    $self->log_append($cap.'{41}');
    return;
}

sub get_age {
    # returns my age, in days.
    my $self = shift;
    return int((time - $self->{'BIRTH'}) / 86400 );
}

sub stats_log {
    my ($self, $string_only, $cap, $sarr, $k) = (@_,undef,undef);
    $self->stats_update; # update self's stats.
    $sarr = $self->{'STAT'}; 
    $cap .= sprintf("{17}%s the {7}%s{17} of {7}%s{17}.\n", $self->{'NAME'}, $main::races[$self->{'RACE'}], $self->{'GUILD'} || 'none');
#    $cap .= "{40}{13}KNO               MAJ               DEF\n";
#    $cap .= sprintf("{17}%5d Mechanical  {2}%5d Offensive  {6}%5d Physical\n", $sarr->[6], $sarr->[10], $sarr->[19]);
#    $cap .= sprintf("{17}%5d Social      {2}%5d Defensive  {6}%5d Energy\n", $sarr->[7], $sarr->[11], $sarr->[20]);
#    $cap .= sprintf("{17}%5d Medical     {2}%5d Elemental  {6}%5d Mental\n", $sarr->[8], $sarr->[12], $sarr->[21]);
#    $cap .= sprintf("{17}%5d Combat      {2}%5d Mental\n", $sarr->[9], $sarr->[22]);
#    $cap .= "{13}CHA                AGI   STR\n";
#    $cap .= sprintf("{17}%5d Appearance  {2}%5d %5d Upper Body\n", $sarr->[13], $sarr->[15], $sarr->[17]);
#    $cap .= sprintf("{17}%5d Attitude    {2}%5d %5d Lower Body\n{41}", $sarr->[14], $sarr->[16], $sarr->[18]);
    $cap .= sprintf("{12}Str: %-5d Kno: %-5d Cha: %-5d Agi: %-5d Maj: %-5d Def: %-5d\n", $self->{'STAT'}->[4], $self->{'STAT'}->[0], $self->{'STAT'}->[2], $self->{'STAT'}->[3], $self->{'STAT'}->[1],$self->{'STAT'}->[5]);
    if($self->{'FX'}) { foreach $k (keys(%{$self->{'FX'}})) {  $cap .= "{13}$main::effectbase->[$k]->[2]\n";  } }
    $cap .= sprintf("{13}Inv: %d%% HP: \%5d/\%-5d MA: %4d/%-4d LEV: %4d  {15}Arena Pts: %3.2f\n", 100 - int (100*$self->inv_free/$self->{'MAXINV'}), $self->{'HP'}, $self->{'MAXH'}, $self->{'MA'}, $self->{'MAXM'}, $self->{'LEV'}, $self->{'ARENA_PTS'});
    $cap .= sprintf("{15}Turns: %6d/%6d. EXP: ( {17}".&rockobj::commify(int $self->{'EXPPHY'})." phy{15} / {17}".&rockobj::commify(int $self->{'EXPMEN'})." men{15} )\n", $self->{'T'}, $self->{'MT'});
    $cap .= sprintf("{5}You are %d days old. {16}Minutes spent online today: %d\n", int ( (time - $self->{'BIRTH'}) / 86400 ), int (($self->{'TIMEOND'}+(time - $main::uidmap{lc $self->{'NAME'}}))/60) );
    if(!$string_only) { $self->log_append($cap); }
    return($cap);
}

sub stats_log2 {
    my ($self, $string_only, $cap, $sarr, $k) = (@_,undef,undef);
    $self->stats_update; # update self's stats.
    $sarr = $self->{'STAT'}; 
#{16}  Inv: {17}%3d%%%12s {16}Min. Today: {17}%-10d    
        my $format_str = <<'END_CAP';
{16} Name: {17}%-15s        {16}Race: {17}%-10s       {16}Gender: {17}%-10s
{16}Lives: {17}%-15d {16}Armor Class: {17}%-10d{16} Weapon Class: {17}%-10s
{16} Path: {17}%-15s         {16}Age: {17}%-10s {16}Arena Points: {17}%3.2f
{16}  Inv: {17}%3d/%-3d %7s {16}Min. Today: {17}%-10d    
{16}Level: {17}%4d
{16}Turns: {17}%6d{7}/%-6d   {16}Hit Points: {17}%6d{7}/%-6d   {16}Mana: {17}%6d{7}/%-6d 
{16}  Exp: {17}%s {7}physical / {17}%s {7}mental. {17}%s {7}combat exp today.
END_CAP
    my $path = 'undecided';
    if ($self->quest_has(6)) {
        $path = 'Adv Powermonger';
    } elsif($self->quest_has(7)) {
        $path = 'Adv Truthseeker';
    } elsif ($self->quest_has(4)) {
        $path = 'Truthseeker';
    } elsif($self->quest_has(3)) {
        $path = 'Powermonger';
    }
    
    my $expphy = &commify(int($self->{'EXPPHY'}));
    my $expmen = &commify(int($self->{'EXPMEN'}));
    my $exptoday = &commify(int($self->{'EXPTODAY'}));
    my $totalinv = scalar keys(%{$self->{'INV'}});
    my $maxinventory  = $self->{'MAXINV'};
	my $wc = 0;
	
	if(defined($self->{'WEAPON'})){
		$wc = $main::objs->{$self->{'WEAPON'}}->{'WC'};
		$wc = int(($wc/80.8)*100);
	}
	
    $cap .= sprintf($format_str, $self->{'NAME'},            $main::races[$self->{'RACE'}], $self->{'GENDER'}
                             , $self->{'LIVES'}, $self->{'AOFFSET'},            $wc
                             , $path, $self->get_age().' days', $self->{'ARENA_PTS'}
                             #, 100 - int (100*$self->inv_free/$self->{'MAXINV'}), undef, int (($self->{'TIMEOND'}+(time - $main::uidmap{lc($self->{'NAME'})}))/60)
                             , $totalinv, $maxinventory, undef, int (($self->{'TIMEOND'}+(time - $main::uidmap{lc($self->{'NAME'})}))/60)
                             , $self->{'LEV'}
                             , $self->{'T'}, $self->{'MT'}, $self->{'HP'}, $self->{'MAXH'}, $self->{'MA'}, $self->{'MAXM'}
                             , $expphy, $expmen, $exptoday );
                      #       , &rockobj::commify(int $self->{'EXPPHY'}), &rockobj::commify(int $self->{'EXPMEN'}) );
    $cap .= sprintf("{12}Str: %-5d Kno: %-5d Cha: %-5d Agi: %-5d Maj: %-5d Def: %-5d\n", $self->{'STAT'}->[STR], $self->{'STAT'}->[KNO], $self->{'STAT'}->[CHA], $self->{'STAT'}->[AGI], $self->{'STAT'}->[MAJ], $self->{'STAT'}->[DEF]);
    if($self->{'FX'}) {
        foreach $k (keys(%{$self->{'FX'}})) {  $cap .= "{13}$main::effectbase->[$k]->[2]\n";  } }
    
    $self->log_append($cap) unless($string_only);
    return $cap;
}

sub player_stalk {
    # attacks player with name $pname (also add argument of 1 if the opponent is an object and not a name).
    my ($self, $pname) = @_;
    my ($success, $victim);
 
# if ($self->{'GAME'}) {
#     $self->log_append("{3}<<  Sorry, stalking is disabled in subgames. Try using the 'invite', 'join', 'appoint', 'leave' and 'gr' commands.  >>");
#     return;
# }
 
    if($pname eq '') {
        my $stalkee = $self->stalkee_get();
        if($stalkee) {
            $self->log_append("{7}You are no longer stalking $stalkee->{'NAME'}.\n");
            $stalkee->log_append("{7}$self->{'NAME'} has refrained from stalking you.\n") unless($self->is_invis($stalkee));
            delete $self->{'STALKING'};
            return 1;
        }
        else {
            $self->log_error('You are not currently stalking anyone.');
            $self->log_hint('Type stalk <victim> to stalk someone.');
            return 0;
        }
    }
    ($success, $victim) = $self->inv_cgetobj($pname, 1, $main::map->[$self->{'ROOM'}]->inv_objs, $self->inv_objs);
    if ($success == 1) {
        if($self->{'TYPE'} == OTYPE_PLAYER && $victim->{'TYPE'} != OTYPE_PLAYER) {
            $self->log_error('{3}You can only stalk fellow players!');
            return;
        }
        if($self == $victim) {
            $self->log_error('But you already stalk yourself!');
            return;
        }
        $self->player_stalk() if($self->{'STALKING'});  # clear current stalkee if possible.
        $self->{'STALKING'} = $victim->{'OBJID'};
        $self->log_append("{7}You are now stalking $victim->{'NAME'}.\n");
        $self->log_hint('You will not actually follow this person if you are in a group.');
        unless($self->is_invis($victim))
        {
            $victim->log_append("{7}$self->{'NAME'} has begun to stalk you.\n");
            $self->room_sighttell("{7}$self->{'NAME'} {4}begins to stalk {7}$victim->{'NAME'}\{4}.\n", $victim);
        }
    } elsif($success == 0) {
        $self->log_error("No lifeforms here are named $pname.");
        return 0;
    } elsif($success == -1) {
        $self->log_append($victim);
        return 0;
    }
    return 1;
}

sub detain {
    my $self = shift;
    $self->room_sighttell("{1}A pair of hidden lasers take aim on $self->{'NAME'}\'s position and let loose with a matter rearrangement beam!\n");
    $self->log_append("{1}A pair of hidden lasers take aim on your position and let loose with a matter rearrangement beam!\n{14}Your body is torn apart, transported elsewhere and reassambled!\n");
    $self->realm_hmove($self->{'ROOM'}, $main::roomaliases{'academy-jail'}, undef, 0); # move room
    $self->room_sighttell("{12}$self->{'NAME'} {2}materializes before you.\n");
    $self->effect_add(6);
}

#mich is evil and has messed with this function
sub attack_player
{
    # attacks player with name $pname (also add argument of 1 if the opponent is an object and not a name).
    my ($self, $pname, $pisobj) = @_; 
    my ($success, $victim, $safeval);
    my ($success2);
    
	if(!$pisobj) {
        if($pname eq "") {   
            $self->log_error('Tip: Sane races attack victims with names.');
            return 0;
        }
        
		($success, $victim) = $self->inv_cgetobj($pname, 1, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs);
    }
    else {
	    confess "Passed PISOBJ of $pisobj, but bad pname ($pname) (should be an object): " . &getTraceString()
		    unless ref $pname;
        $success = 1;
        $victim = $pname;
    }
	
    if(!$main::kill_allowed) {
        $self->log_append("{4}Those darned {1}Admins{4} turned attacking off for the moment.\n{4}This is a good chance for you to look outside the window and\nmake sure there's still air out there.\n");
        return 0;
    }
    
	if($success == 1) { 
        my $aggress_code = $self->log_cant_aggress_against($victim);
        if($aggress_code == AGGRESS_FAILED_ROOM_SAFEDETAIN) {
            $self->detain();
        }
        
        return 0 if($aggress_code != AGGRESS_SUCCESS);

        if($self->{'WEAPON'}) {
            $success2 = $self->attack_melee($victim, $main::objs->{$self->{'WEAPON'}});
        } elsif($self->{'DWEAP'}) {
            $success2 = $self->attack_melee($victim, &obj_lookup($self->{'DWEAP'}));
        } else {
            $self->log_error("You have no means by which to attack $victim->{'NAME'}.");
            return 0;
        }

        # melee retaliation
        if($success2 && !$victim->is_dead && !$victim->is_tired) {
            $victim->attack_sing($self);
            return 1;
        }
    } elsif ($success == 0) {
        $self->log_error($self->aggress_error_string($pname, AGGRESS_FAILED_VICT_NOTPRESENT));
    } elsif ($success == -1) {
        $self->log_append($victim); 
    }
    return 0;
}
#end mich is evil

#sub item_nget {
#  # gets <number> of a static item.
#  my ($self, $obj, $num) = @_;
#}

sub item_get {
    # gets item with name $iname
    my ($self, $iname, $gettingAll) = @_;

    if (!$iname) {
        $self->log_error('You must decide on something to get.');
        return 0;
    }
    
    my $container = $main::objs->{$self->{'CONTAINEDBY'}};
    if (!$container) { 
        $self->log_append("Container error!\n"); 
        $self->cmd_do("bug Container Error! $self->{'NAME'} ($self->{'OBJID'}) had container of $self->{'CONTAINEDBY'}, which is name $container->{'NAME'} ($container->{'OBJID'}.\n");
        return 0;
    }

    if (abs($iname) > 0) {
        return $self->cryl_get($iname);
    }

    if (lc($iname) eq 'all') {
        if ($self->{'GAME'}) {
            $self->log_error('"get all" has been disabled for Rock subgames.');
            return 0;
        }

        $self->log_append("{1}You attempt to get everything{3}..\n");
        $self->cryl_get() if($container->{'CRYL'});
        my $o;
        foreach $o ($container->inv_objs) { 
            if (($self != $o) && $o->{'DLIFT'} && !$o->is_invis($self)) {
                if ($self->item_get($o->{'NAME'}, 1) == -1) {
                    $self->log_error('Cannot fit more objects.');
                    return 0;
                }
            }
        }
        return 1;
    }
    
	if ($self->inv_free < 1) {
        $self->log_error('Inventory too full.');
       	return -1;
   	} # not enough space for item
   	
    my ($success, $item) = $main::map->[$self->{'ROOM'}]->inv_cgetobj($iname,0,$container->inv_objs);
    if ($success == 1) {
        if ($self == $item) {
            $self->log_error('You might break physics if you picked yourself up!');
        } elsif ( $item->is_spiritually_glued($self) ) {
            $self->log_error("$item->{'NAME'} is bound to the floor with a spiritual glue.");
        } elsif ( ($item->{'MINLEV'}*.8) > $self->{'LEV'}  ) {
            $self->log_error("$item->{'NAME'} is to big for you to pick up, you must be within 80 percent of its min level.");
        } elsif ($item->{'NOTAKE_NPC'} && $self->{'TYPE'} == 2) {
            $self->log_error("NPCs cannot take this $item->{'NAME'}.");
        } elsif ($item->can_be_lifted($self) && $self->can_lift($item)){
            return 0 unless($self->can_do(0,0,5));
            $container->inv_del($item);
            $self->inv_add($item);
            $self->log_append("{2}You pick up the {4}".$item->{'NAME'}."{2}.\n");
            if ($container->{'TYPE'} == OTYPE_ROOM) {
                $container->tell(6, 1, 0, undef, $self, $item, sprintf("{2}%s picked up the {4}%s{2}.\n", $self->{'NAME'}, $item->{'NAME'}));
            } else {
                $container->log_append("{2}$self->{'NAME'} takes your $item->{'NAME'} as $self->{'PPOS'} own.\n");
            }
            
            delete $item->{'SPECTRAL_SHROUD'};
            
            $item->on_take($self);
			
  		    $self->log_suspicious_activity("Took $item->{'NAME'} within 60 seconds of logging in.")
    	        if  $self->{'TYPE'} == 1 && (time - $self->get_login_time()) < 60;

            return 1;
        } else {
            unless($gettingAll) {
                $self->log_error("$item->{'NAME'}\? Pick $item->{'PPRO'} up? Surely you jest!");
            }
            return 0;
        }
    } else {  
        if(lc($iname) eq 'cryl') {
            return $self->cryl_get;
        } else {
            $self->log_append($item);
            return 0;
        }
    } # log error
    return 1;
}

sub is_spiritually_glued {
    my ($item, $picker_upper) = @_;
	die "must supply picker-upper" unless $picker_upper;
	return $item->{'LASTDROP'} && ($item->{'DROPOWN'} ne $picker_upper->{'NAME'}) && ((time - $item->{'LASTDROP'})<80);	
}

sub on_take { }

sub item_drop {
 # gets item with name $iname
 my ($self, $iname) = @_;
 if(!$iname) { $self->log_append("{3}You've got to decide on something to drop.\n"); return; }
 if(lc($iname) eq 'cryl') { return $self->cryl_drop; }
 if(abs($iname)>0) { return ($self->cryl_drop($iname)); }
 if (lc($iname) eq 'all') {
   #if( $#{$self->inv_objs} == -1) { $self->log_append("{3}You have no items to drop.{3}\n"); return(0); }
   $self->log_append("{1}You attempt to drop everything{3}..\n");
   if($self->{'CRYL'}) { $self->cryl_drop; }
   my $o; foreach $o ($self->inv_objs) { if ( $self->item_drop($o->{'NAME'}) == 0) { next; } }#{ return(0); } }
   return 1;
 }
 my ($success, $item) = $self->inv_cgetobj($iname,0);
 if($success == 1) { 
    return($self->item_hdrop($item));
 } elsif($success == 0) { $self->log_append("{3}You don't have a $iname to drop.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub can_be_dropped { return(!$_[0]->{'!DROP'}); }

sub item_hdrop {
   my ($self, $item) = @_;
    if(!$self->can_do(0,0,2)) { return(0); }
    if(!$item->can_be_dropped($self)) { $self->log_append("{3}You are unable to drop $item->{'NAME'}.\n"); return(0); }
    if( ($item->{'WORN'}) && (!$self->item_hremove($item)) ){ return(0); }
    if( ($item->{'EQD'}) && (!$self->item_hunequip) ){ return(0); }
    $self->inv_del($item);
    $main::objs->{$self->{'CONTAINEDBY'}}->inv_add($item);
    $self->log_append("{2}You drop the {4}".$item->{'NAME'}."{2}.\n");
    # next line may not be good in the future: 
    if($main::map->[$self->{'ROOM'}]->{'OBJID'} == $self->{'CONTAINEDBY'}) {
      $main::map->[$self->{'ROOM'}]->tell(7, 1, 0, undef, $self, $item, "{2}$self->{'NAME'} dropped the {4}$item->{'NAME'}\{2}.\n");
    }
	
	if ($self->{'TYPE'} == 1) {
	    $self->{'LASTDROP'} = time;	    
	}
	
    return(1);
}

sub item_look {
 # looks at item with name $iname
 my ($self, $iname) = @_;
 if(!$iname) { $self->log_append("{3}You've got to decide on something to look at.\n"); return; }
 if ($iname =~ /^(\d+)$/) { #&& $main::map->[$self->{'ROOM'}]->{'AUCTION'}) {
     $self->auction_look($iname);
	 return;
 }
 if (lc($iname) eq 'all') {
   $self->log_append("{1}Looking at everything{3}..\n");
   my $o; foreach $o ($self->inv_objs, $main::map->[$self->{'ROOM'}]->inv_objs) { next if ($o->is_invis($self)); if ( $self->item_look($o->{'NAME'}) == 0) { return(0); } }
   return 1;
 }
 my ($success, $item) = $self->inv_cgetobj($iname, 0, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs, $main::map->[$self->{'ROOM'}]->inv_store_objs);
 if($success == 1) { 
    return if !$self->can_do(0,0,1);
    if($self->{'RACE'}!=6 ){
    		if($item ne $self) { $item->log_append("{7}You notice {1}".$self->{'NAME'}."{7} looking at you.\n"); }
    }
    $self->log_append("{6}".$item->{'NAME'}."{7}: {2}".$item->desc_get($self)."\n");
    if($self->{'ADMIN'}) {
	    $self->log_append($item->stats_log2(1));
		$self->log_append("{17}OBJID: $item->{'OBJID'}. ROOM: $item->{'ROOM'}. RecipeExists: $main::obj_recd{$item->{'REC'}}/$main::obj_limits{$item->{'REC'}}\nMASS: $item->{'VIGOR'}. CRYL: $item->{'CRYL'}. MASS: $item->{'MASS'}. VOL: $item->{'VOL'}. VAL: $item->{'VAL'}. KJ: $item->{'KJ'}. FLAM: $item->{'FLAM'}.\nDBLUN: $item->{'DBLUN'}. DSHAR: $item->{'DSHAR'}. LUCK: $item->{'LUCK'}. VIGOR: $item->{'VIGOR'}. WC: $item->{'WC'}.\n");
##	    if ($item->{'TYPE'} == 1) {
		    $self->log_append($item->get_stats_raiselist());
##		}

	
	}
	if($item->{'MINLEV'})  {	$self->log_append("{17}Min Level: {6}$item->{'MINLEV'}\n");}
	if($item->{'DROPOWN'})  {	$self->log_append("{6}$item->{'DROPOWN'} {17}was last killed with this item.\n");}
	if($self->skill_has(79)&& !$item->has_monolith('shadow')){
		if(!$item->{'MINLEV'} && !$item->{'ADMIN'}) {$self->log_append("{17}Current Level: {6}$item->{'LEV'}\n");}
		if(!$item->{'MINLEV'} && !$item->{'ADMIN'} && ($item->{'TYPE'}!=1)) {$self->log_append("{17}Current Health: {6}$item->{'HP'}\n");}
		}
    return(1);
 } elsif($success == 0) { $self->log_append("{3}You don't see any $iname to look at.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub inv_obj_resolve {
    my ($self, $iname) = @_;
    my ($success, $item) = $self->inv_cgetobj($iname, 0, $self->inv_objs);
    if($success == 1) { 
       return($item);
    } elsif($success == 0) { $self->log_append("{3}You don't have any $iname.\n"); return(0); }
    elsif($success == -1) { $self->log_append($item); return(0); }
    return 1;
}

sub desc_get {
	# returns string of item's description.
	my $self = shift;
	my $cap = $self->desc_hard();
	$cap .= "\n{3}<< You may not log off with this item >>" if $self->{'NOSAVE'};
	$cap .= "\n{3}<< $self->{'USES'} ".($self->{'USES'} == 1 ? "use remains" : "uses remain")." >>" if $self->{'USES'} >= 1;
	return($cap);
}


sub on_misc_room(@args) {
 # communicates misc. room information
 my ($self, $cap, @except) = @_;
  return unless $self->{'TYPE'} >= 0;   ### SAFE FROM ROOM EXECUTION ###

 if(@except) { 
   my $n; for ($n=0; $n<=$#except; $n++) { if ($except[$n] == $self) { return; } }
   $self->log_append($cap);
 } else {
   $self->log_append($cap);
 }
 return;
}


sub room_tell {
    # sends message to each player other than object passed to it.
    my ($self, $cap, @others) = @_;
    push(@others, $self);
    
    foreach my $player (keys(%{$main::activeusers})) { 
        $player = $main::objs->{$player};
        next if $player->{'ST8'};
        next unless($player->{'CONTAINEDBY'} eq $self->{'CONTAINEDBY'} || $self->{'OBJID'} eq $player->{'CONTAINEDBY'} || $self->{'CONTAINEDBY'} eq $player->{'OBJID'});
        next if(grep {$_ eq $player} @others);
        $player->log_append($cap);
    }

    return;
}

sub room_talktell {
    # sends message to each player other than object passed to it.
    my ($self, $cap, $lang, @others) = @_;
    push(@others, $self);

    foreach my $player (keys(%{$main::activeusers})) {
        $player = $main::objs->{$player};
        next if $player->{'IGNORE'}->{$self->{'NAME'}};
        next if $player->{'ST8'};
        next if defined($player->{'FX'}->{'22'});
        next unless($player->{'CONTAINEDBY'} eq $self->{'CONTAINEDBY'} || $self->{'OBJID'} eq $player->{'CONTAINEDBY'} || $self->{'CONTAINEDBY'} eq $player->{'OBJID'});
        next if(grep {$_ eq $player} @others);

        if(!$lang || (rand(100) < $player->{'GIFT'}->{$lang})) {
 	        $player->log_append(ref($cap) eq "censored_message" ? $cap->get_for($player) : $cap); 
        } else {
            $player->log_append("{2}$self->{'NAME'} {6}mumbles something in words that you are unable to understand.\n");
        }
    }

    return;
}

sub room_sighttell {
    # sends message to each player other than object passed to it.
    my ($self, $cap, @others) = @_;
    push(@others, $self);
    
    foreach my $player (keys(%{$main::activeusers})) { 
        $player = $main::objs->{$player};
        next if $player->{'ST8'};
        next if defined($player->{'FX'}->{'22'});
        next unless($player->{'CONTAINEDBY'} eq $self->{'CONTAINEDBY'} || $self->{'OBJID'} eq $player->{'CONTAINEDBY'} || $self->{'CONTAINEDBY'} eq $player->{'OBJID'});
        next if(grep {$_ eq $player} @others);
        $player->log_append($cap);
    }

    return;
}

$main::tellType[1] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_say(@args); };
$main::tellType[2] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_attack(@args); };
$main::tellType[3] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_noise($crossroom, @args); };
$main::tellType[4] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_room_enter(@args); };
$main::tellType[5] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_room_exit(@args); };
$main::tellType[6] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_item_get(@args); };
$main::tellType[7] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_item_drop(@args); };
$main::tellType[8] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_explosion(@args,$atk,$crossroom); };
$main::tellType[10] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_misc_room(@args); };
$main::tellType[11] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_rest(@args); };
$main::tellType[12] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_odie(@args); };
$main::tellType[13] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_cryl_dropped(@args); };
$main::tellType[14] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_packcall(@args,$crossroom); };
$main::tellType[15] = sub { my ($self, $type, $atk, $dec, $crossroom, @args) = (@_); $self->on_itemthrew(@args,$crossroom); };

sub tell {
 ## Tells stuff to the objects in the room.
 ## type = [1..?]; HANDLES message while atk >= 1.
 ## (can be interpreted as 'first instance, second instance,' etc.. (attack)
 ## passes message to surrounding rooms at decay dec while dec >= 1.
 ## crossroom identifies room it came from. '' if crossroom, undef if no cross.
 &{$main::tellType[$_[1]]}(@_);
 $main::tellpriority{$_[1]}++;
 # handle directly
 return;
}

#foreach my $k (keys %main::tellpriority) { $_[0]->log_append(sprintf("{16}%30s {17}%10d\n", $k, $main::tellpriority{$k})); }
sub delay_cmd_do {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::cmd_do, $self, @_);
}
sub delay_rest {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::rest, $self, @_);
}
sub delay_say {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::say, $self, @_);
}
sub delay_log_append {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::log_append, $self, @_);
}
sub delay_room_sighttell {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::room_sighttell, $self, @_);
}
sub delay_room_talktell {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::room_talktell, $self, @_);
}
sub delay_room_tell {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::room_tell, $self, @_);
}
sub delay_action_do {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&rockobj::action_do, $self, @_);
}

sub say ($str [,$langcode]) {
    # says string in room.
    my ($self, $str, $langcode) = @_;
    
#    return 0 if( ($main::map->[$self->{'ROOM'}]->{'TER'}!=20) && !$self->can_do(0,0,0) );
    return 0 unless $self->can_do(0,0,0);
    if("$str" eq "") {
        $self->log_error("Say what?");
        return 0;
    }
    if(defined($self->{'FX'}->{'26'})) {
        $self->log_error("You don't have the means to communicate that way!");
        return 0;
    }
    $str = &main::text_filter_game($str, $self);
    my $cmsg = censored_message->new_prefiltered('{16}'.($self->{'NICK'} || $self->{'NAME'}).' says, "{7}'.$str."{16}\"\n", $self);
    $self->room_talktell($cmsg, ($langcode || $self->{'LANG'}));
    $self->log_append('{16}You say, "{7}'.$str.'{16}"'."\n");
    $main::map->[$self->{'ROOM'}]->tell(1, 1, 0, undef, $self, \$str, ($langcode || $self->{'LANG'}));
    ## Inform surrounding people of talking.
    $self->noise_make('talking', '{4}You faintly hear voices coming from the {6}%s{4}.'."\n", 1);
    if(defined($self->{'FX'}->{27}) && ($self->{'FX'}->{27} >= time) && !$self->room()->{'SAFE'}) { 
        # spread the poison
        my ($o, @os);
        foreach $o ($main::map->[$self->{'ROOM'}]->inv_objs) { 
            if(($o->{'TYPE'}>=1) && ($o ne $self) && (rand(100)<20) && (!$o->got_lucky()) && !$o->{'NOSICK'} && !defined($o->{'FX'}->{27}) ) {
                $o->effect_add(27);
                push(@os, $o->{'NAME'});
            }
        }
        if(@os) { $self->log_append("{1}You have spread the plague to: {6}" . join(', ', @os)."{1}.\n"); }
        $self->{'FX'}->{27} -= 15*scalar(@os);
    }
    
    return 1;
}

sub say_rand (@sayarray) {
 # says random phrase of @sayarray
 my $self = shift;
 $self->say( $_[int rand($#_+1)] );
 return;
}

sub on_noise (from_direction, object_that_made_noise, noise_desc, [ verbose_desc ]) {
  ## Registered briefs: talking.
  my ($self, $dir, $obj, $brief, $verbose) = @_;


  return unless $self->{'TYPE'} >= 0;   ### SAFE FROM ROOM EXECUTION ###

  if($verbose) { 
    if (index($verbose, '%s') != -1) {  $verbose = sprintf($verbose, $main::dirlongmap{$dir}); }
    $self->log_append($verbose);
  } else { $self->log_append('{4}You hear a the sound of {6}'.$brief.'{4} from the {6}'.$main::dirlongmap{$dir}."{7}.\n"); }
  return;
}

sub on_explosion (what exploded, kj, attack, from_direction) {
  my ($self, $explodeobj, $kj, $attack, $dir) =@_;
  my $dmg;

  return unless $self->{'TYPE'} >= 0;   ### SAFE FROM ROOM EXECUTION ###

  return if($self eq $explodeobj);

  if(!($self->is_dead || $main::map->[$self->{'ROOM'}]->{'SAFE'} || $self->{'IMMORTAL'}) && (($self->{'TYPE'} == 1)) ) { 
     $dmg = ($kj/400/$attack) * (1 - $self->pct_skill(20)/100);
     
     foreach my $armor ( $self->get_worn_items()) {
         $dmg *= 1 - $armor->{'FLAM_RESIST'} if $armor->{'FLAM_RESIST'};
     }
     
     $dmg = int $dmg;
     
     if($dir) {
       $self->log_append("{11}You are struck by a huge burst of energy from the $main::dirlongmap{$dir}, taking $dmg damage.\n");
     # #$self->room_tell("{11}A huge burst of energy from the $main::dirlongmap{$dir} strikes $self->{'NAME'}!\n");
     } else {
       $self->log_append("{11}You are struck by a huge burst of energy, taking $dmg damage.\n");
     # #$self->room_tell("{11}A huge burst of energy strikes $self->{'NAME'}!\n");
     }
     $self->{'HP'} -= $dmg; # deplete hp.

     if($self->is_dead) { $self->die($explodeobj); }

     return;
  }
  # tempt with flames
  if($dir) {
       $self->log_append("{11}A huge burst of energy struck you from the $main::dirlongmap{$dir}.\n");
  } else {
       $self->log_append("{11}You feel a huge burst of energy strike you.\n");
  }
  $self->flam_tempt(1/$attack);
  return;
}


sub explode {
  my ($self, $rooms, $kj) = @_;
  $rooms = 3 unless $rooms;
  if($self->{'KJ'} || $kj) {
      if("$self->{'CONTAINEDBY'}" eq "") { print "$self->{'NAME'} tried to explode but didn't have a container.\n"; return; }
      #&rockobj::obj_lookup($self->{'CONTAINEDBY'})->inv_del($self); # remove from room to avoid further notifications ;-) 
      delete $self->{'FLAM'}; # and dont make me explode anymore either ;-).
      $self->room_sighttell("{11}$self->{'NAME'} {13}bursts into energy particles!\n");
      if($self->{'TYPE'} != 1) { $self->obj_dissolve; }
      $main::map->[$self->{'ROOM'}]->tell(8, 1, $rooms, '', $self, $kj || $self->{'KJ'}); 
  } else { $self->room_sighttell("{11}$self->{'NAME'} {13}bursts into energy particles!\n{14}Nothing happens.\n"); }
  return;
}

sub make_aid {
 my $self = shift; $self->{'AID'}=$_[0]->{'OBJID'};  return;
}

sub on_attack {}
sub on_room_enter {}
sub on_room_exit {}


sub on_item_get (objects: picker, item; string: str (observation)) {
  my ($self, $picker, $item, $str) = @_;
  return unless $self->{'TYPE'} >= 0;   ### SAFE FROM ROOM EXECUTION ###
  if( $self == $item ) { $self->log_append('{4}'.$picker->{'NAME'}.'{2} just picked you up!'."\n"); }
  elsif ( $self != $picker ) { $self->log_append($str); }
  return;
}

sub on_item_drop (objects: dropper, item; string: str (observation)) {
  my ($self, $dropper, $item, $str) = @_;
  return unless $self->{'TYPE'} >= 0;   ### SAFE FROM ROOM EXECUTION ###
  if( $self == $item ) { $self->log_append('{4}'.$dropper->{'NAME'}.'{2} just dropped you!'."\n"); }
  elsif ( $self != $dropper ) { $self->log_append($str); }
  return;
}

sub on_say {}

sub noise_make ( brief noise desc (eg: 'movement', 'talking', etc), verbose desc, numrooms ){
  ## makes noise that echoes to surrounding rooms for numroom rooms
  ## $self->noise_make('talking', 'You hear the sound of people talking to the %s.', 1);
  my ($self, $brief, $verbose, $numrooms) = @_;
  # tell self, if i am a room. otherwise tell my room.
  if ($self->{'TYPE'} == -1) { $self->tell(3, 0, $numrooms + 1, '', $self, $brief, $verbose); }
  else { $main::map->[$self->{'ROOM'}]->tell(3, 0, $numrooms + 1, '', $self, $brief, $verbose); }
  # note: numrooms + 1 accounts for the first attack.
  # the two undefs hold space for dir/room objs when being passed.
  return($verbose);
}

sub realm_move {
 ## moves object somewhere else in realm. pass it the dir of move. returns 1 if successful, 0 if not.
 ## assumes player decided to go in direction if playersrequest is 1.
 my ($self, $dir, $preq) = @_; $dir = uc($dir);
 if($self->{'SENT'}) { $self->log_append("{4}You cannot leave this room.\n"); return(0); }
 if($self->is_tired && $preq) { $self->log_append("{2}You are too exhausted to move yet.\n"); return(0); }
 if(!$self->{'WEBACTIVE'} && (rand(10)>8) ) { $self->make_tired(); }
 if(!$self->can_do(0,0,0)) { return(0); }
# if ($self->{'T'} <= 0 && $self->{'TYPE'} == 1 && !$self->{'GAME'}) { $self->log_error("You don't have any turns left."); return 0; }
 my ($oldroom, $newroom, $success);
 $oldroom=$self->{'ROOM'};
 $newroom=$main::map->[$oldroom]->exit_leadsto($dir);
 
 $success = $self->realm_hmove($oldroom, $newroom, $dir, $preq, 'heads', 'arrives');
 
 if(!$success) { return(0); }
 return(1);
}

sub realm_hmove (oldroom, newroom, [,dir [,preq]]) {
    my ($self, $oldroom, $newroom, $dir, $preq, $leavemsg, $entermsg) = @_;
    my ($iobj);
    
    my $oldroomOBJ = $main::map->[$oldroom];
    my $newroomOBJ = $main::map->[$newroom];
    
    confess "oldroomOBJ cannot be undef" unless $oldroomOBJ;
    confess "newroomOBJ cannot be undef" unless $newroomOBJ;

    if ($self->{'GAME'} && (time - $main::arena_start_epoch) <= $main::arena_planning_time) {
        $self->log_append("{3}<<  You can't move during arena planning time.  >>\n");
    return 0;
    }
    
    # Make sure youre able to move (eg: are you even in a room, or an item/npc?)
    if (defined($self->{'CONTAINEDBY'}) && &obj_lookup($self->{'CONTAINEDBY'})->{'TYPE'} != -1) {
        $self->log_append("{3}You can't get out of ".&obj_lookup($self->{'CONTAINEDBY'})->{'NAME'}."!\n");
      return;
    }
    
    # Will the rooms let you in/out?
    return 0 if(  !$oldroomOBJ->can_exit($dir,$self,$preq) || !$newroomOBJ->can_enter($self) );
   
    # OTHERWISE, SUCCESS!
   
    my $quiet;
    
    # Forest Quiet rooms; 60% chance success if youre wearing certain items
    if($newroomOBJ->{'TER'} == 4 && $oldroomOBJ->{'TER'} == 4 && (.6 > rand 1) && $self->aprl_rec_scan(431)) {
       $quiet = 1;
    }
    # Change Entrance/Exit Messages
    if($self->{'ENTMSG'}) { $entermsg = $self->{'ENTMSG'}; if($self->{'ENTMSG'}){ $leavemsg=$self->{'LEAMSG'}; } }
    elsif($self->{'FX'}->{7}) {
      $leavemsg = 'flies'    if $leavemsg;
      $entermsg = 'flies in' if $entermsg;
    } else { $entermsg = 'arrives' unless $entermsg; }
 
    # Notify Room that I Left
    if(!$quiet && $leavemsg && !$self->is_invis()) { $self->room_sighttell(sprintf("{2}%s {5}$leavemsg to the {2}%s{5}.\n", ($self->{'NICK'} || $self->{'NAME'}), $main::dirlongmap{$dir})); }
    
    # Remove player from old room.
    $oldroomOBJ->inv_del($self);  # delete player from old room inventory
    if($dir) { 
       $self->{'FRM'}=$main::diroppmap{$dir};
       $oldroomOBJ->tracks_make($dir, $self);
       
       # catch disappearing exits
       if( $oldroomOBJ->{$dir}->[2] ) { 
         $oldroomOBJ->{$dir}->[2]--;
         if(!$oldroomOBJ->{$dir}->[2]) { 
           $oldroomOBJ->{$dir}->[1]=1;
           $oldroomOBJ->exits_update();
           $oldroomOBJ->room_sighttell("{16}The exit to the {7}$main::dirlongmap{$dir} {16}disappears.\n", $self);
           $self->log_append("{16}The exit to the {7}$main::dirlongmap{$dir} {16}disappears as you pass it.\n");             
         }
       }
       
    } else {
       delete $self->{'FRM'};
    }
    
    # Move player to new room.
    $newroomOBJ->inv_add($self);  # add player to new room inventory
    # ..and his objects
    foreach $iobj ($self->inv_objs()) {
       delete $iobj->{'FRM'};
       $iobj->{'ROOM'}=$self->{'ROOM'};
    }
    if(defined($self->{'DWEAP'})) { &obj_lookup($self->{'DWEAP'})->{'ROOM'}=$self->{'ROOM'}; }

#       OLD VERSION: ALLOWS FOR PREVENTING ITEMS FROM ENTERING
#       $iobj->{'FRM'}=$main::diroppmap{$dir};
#        if( ($iobj->can_exit($oldroom)) && ($iobj->can_enter($newroom)) ) { 
#          $iobj->{'ROOM'}=$self->{'ROOM'};  # update container's room
#        } else {
#          # unwield/unequip self from container as needed
#          if ($self->{'WORN'}) { $self->item_hremove($self); }
#          if ($self->{'EQD'}) { $self->item_hunequip; }
#          $self->inv_del($iobj);
#          $self->log_append("A ".$iobj->{'NAME'}." fell out of your inventory.\n");
#          $oldroomOBJ->inv_add($iobj); # or shove it in the old room.
#        }

    if(!$self->{'WEBACTIVE'}) { $self->room_log(); }
    
    if($self->{'HP'} > 0) {
        my $ldir = $main::dirlongmap{$dir};
        if($ldir) { 
             if(!$quiet && !$self->is_invis()) {
               $self->room_sighttell(sprintf("{2}%s {5}$entermsg from the{2} %s{5}.\n", ($self->{'NICK'} || $self->{'NAME'}), $main::dirlongmap{$main::diroppmap{$dir}}));
             }
        }

        # NOTE: The way this current on_exit, on_enter stuff is ordered, one known
        #       caveat is that:
        # (15:58:14) AlternaMich: yeah i flipped them cuz people were leaving rooms with say, 30% and then when they got to the new room they'd get hit (bringing them to 25%) but the npcs in the previous room would follow them then
        
        # Tell the new room that I'm here (on_enter) (tripwires, etc, will bite on this one)
        if ($ldir) { $newroomOBJ->tell(4, 1, 0, undef, $self, $main::diroppmap{$dir}); }

        # Tell the old room that I've left (on_exit)
        if ($dir) { $oldroomOBJ->tell(5, 1, 0, undef, $self, $dir); }
    }
   
    # autoloot?
    $self->auto_loot();
   
#   $self->say("WAOOAHAHAHAHAOOOOO");
    return 1;
}

sub auto_loot {
  my $self = shift;
  if($self->{'ALOOT'} && (rand(100)<70) && ($main::map->[$self->{'ROOM'}]->{'CRYL'} >= $self->{'ALOOT'}) && ($self->{'HP'}>0) ) {
      $self->log_append("{13}### Auto-Looting ###\n");
      $self->cryl_get;
  }
}

sub room_change {
  my ($self, $roomid) = @_;
  $roomid = int $roomid;
  if(!$main::map->[$roomid]) { $self->log_append("{11}No such room.\n"); return; }
  delete $self->{'FRM'};
  $self->realm_hmove($self->{'ROOM'}, $roomid, undef, 0);
  $self->log_append("{13}You are now in room {2}$roomid"."{13}.\n");
  return;
}

sub ask ($str [format: '<name> about <topic>']) {
   my ($self, $str) = @_; $str = lc($str);
   if(defined($self->{'FX'}->{'26'})) { $self->log_append("{17}You don't have the means to communicate that way!\n"); return(0); }
   if ($self->is_tired()) { $self->log_error("You are out of breath; slow down buckaroo!"); return(0); }
   if(!$self->can_do(0,0,2)) { return(0); }
   if (index($str, ' about ') == -1) {
      $self->log_append("{3}Wrong! The correct usage is:\n{1}ask [object name] about [phrase].\n");
      return(-1);
   } else { 
      my ($success, $obj, $who, $about);
      while (index($str, '  ') > -1) { $str =~ s/  / /g; }
      ($who, $about) = split(/ about /,$str);
      ($success, $obj) = $self->inv_cgetobj($who, -1, $self->inv_objs, $main::map->[$self->{'ROOM'}]->inv_objs, $main::map->[$self->{'ROOM'}] );
      if ( $success == 1 ) { 
          my $about_censored = &main::text_filter($about, $self);
          $about = lc $about;
          $self->log_append("{2}You speak with $obj->{'NAME'} about $about_censored.\n");
          $obj->log_append("{2}$self->{'NAME'} speaks with you about $about_censored.\n");
          $self->room_talktell("{2}$self->{'NAME'} speaks with $obj->{'NAME'} about $about_censored.\n", $obj);
          my $cap = $obj->on_ask($about, $self);
		  
		  # If we didn't get anything, try looking it up
		  unless(defined($cap) || !defined($obj->{'REC'})) {
		      my $dbh = rockdb::db_get_conn();
			  my $sth = $dbh->prepare("SELECT response_type, response_text FROM $main::db_name\.r2_on_ask_responses WHERE (item_id = -1 OR item_id = ?) AND ? REGEXP response_match ORDER BY item_id DESC, match_order DESC LIMIT 1");
			  $sth->execute($obj->{'REC'}, lc $about);
			  my $row = $sth->fetchrow_arrayref();
			  if ($row) {
			      my @responses = split(/\n+/, $row->[1]);
				  my $response = $responses[int rand @responses];
				  $response =~ s/%ASKER/$self->{'NAME'}/g;
			      if ($row->[0] eq "Command") { 
				      if (lc(substr($response, 0, 4)) eq "echo") { 
					      $obj->room_tell("{7}".substr($response,5)."\n");
					  } else {
					      $obj->cmd_do($response);
					  }
				  } elsif ($row->[0] eq "Say") { $obj->say($response); }
			      elsif ($row->[0] eq "Echo") { $obj->room_tell("{7}$response\n"); }
                  $cap = ''; # dont log special stuff				
			  } elsif ($about eq "stuff" && defined($obj->{'REC'})) {
			      my $sthb = $dbh->prepare("SELECT response_match FROM $main::db_name\.r2_on_ask_responses WHERE item_id = ? AND is_visible = 'Y'");
				  $sthb->execute($obj->{'REC'});
				  my @keywords;
				  while (my $row = $sthb->fetchrow_arrayref) {
				      my $keyword = $row->[0];
					  $keyword =~ s/\[(.)[^\]]\]/\1/g; # kill char classes
					  $keyword =~ s/^([^|]+).*$/\1/g; # kill alternation
					  $keyword =~ s/\+|\*/\1/g; # kill alternation
					  push @keywords, $keyword; # it's a weak filter but should work 99% of the time
				  }
				  if (@keywords > 1) {
				      my $last = pop @keywords;
				      $obj->say("I am well-versed in the subjects of ".join(", ", @keywords)." and $last.");
				  } elsif (@keywords) {
				      $obj->say("I am well-versed in the subject of @keywords.");
				  } else {
				      $obj->say("I do not know of anything that will help you.");
				  }
				  $sthb->finish();
                  $cap = ''; # dont log special stuff				
			  }
		      $sth->finish();
		  }
		  
		  
		  if(defined($cap)){ $self->log_append($cap); 
		  } else { $self->log_append("{2}$obj->{'NAME'} does nothing.\n"); }
		  $self->make_tired(2);
      }
      elsif ( $success == 0 ) { $self->log_append("{3}You can't talk to anything like that here!\n"); }
      elsif ( $success == -1 ) { $self->log_append($obj); }
   }
}

sub order {
   my ($self, $str) = @_; $str = lc($str);
   if(defined($self->{'FX'}->{'26'})) { $self->log_append("{17}You don't have the means to communicate that way!\n"); return(0); }
   if ($self->is_tired()) { $self->log_error("You are out of breath; slow down buckaroo!"); return(0); }
   if(!$self->can_do(0,0,3)) { return(0); }
   if (index($str, ' to ') == -1) {
      $self->log_append("{3}The correct usage is:\n{1}order [object name] to [verb].\n");
      return(-1);
   } else { 
      my ($success, $obj, $who, $about);
      while (index($str, '  ') > -1) { $str =~ s/  / /g; }
      ($who, $about) = split(/ to /,$str);
      ($success, $obj) = $self->inv_cgetobj($who, -1, $self->inv_objs, $main::map->[$self->{'ROOM'}]->inv_objs, $main::map->[$self->{'ROOM'}] );
      if ( $success == 1 ) { 
          $about = &main::text_filter($about, $self);
          $self->log_append("{2}You order $obj->{'NAME'} to $about.\n");
          $obj->log_append("{2}$self->{'NAME'} orders you to $about.\n");
          $self->room_talktell("{2}$self->{'NAME'} orders $obj->{'NAME'} to $about.\n", $obj);
          my $cap = $obj->on_order(lc($about), $self);
          if(defined($cap)){ $self->log_append($cap); }
          else { $self->log_append("{2}$obj->{'NAME'} does nothing.\n"); }
		  $self->make_tired(2);
      }
      elsif ( $success == 0 ) { $self->log_append("{3}You can't talk to anything like that here!\n"); }
      elsif ( $success == -1 ) { $self->log_append($obj); }
   }
}

sub item_give (str) {
    my ($self, $str) = @_; $str = lc($str);
	$str =~ s/\s+/ /g;
    if ($str !~ /^\s*(.+)\s+to\s+(.+)\s*$/) {
        $self->log_error("Usage: give <object name> to <recipient name>");
        return -1;
    } else { 
        my ($successa, $successb, $pobj, $iobj, $iname, $pname);

        my @potential_recipients = $main::objs->{$self->{'CONTAINEDBY'}}->inv_pobjs();
        if ($self->skill_has(59)  ||  ($main::rock_stats{'monolith_pearled'}==$self->{'RACE'} && $self->{'SOLDIER'})) {
		    # if they have farshare, expand the recipient list to include those who are
			# of my race, anywhere.
			my @new_recipients = grep { my $wideobj = $_; !grep { $_ eq $wideobj } @potential_recipients } grep { $_->{'SOLDIER'} && $_->{'RACE'} == $self->{'RACE'} } map { $main::objs->{$_} } keys %$main::activeusers;
			push @potential_recipients, @new_recipients;
		}

        ($iname, $pname) = ($1, $2);
        # catch cryl stuff -- if it's any amount, it must be cryllies!
        if (abs($iname) > 0) { 
            ($successb, $pobj) = $self->inv_cgetobj($pname, 0, @potential_recipients);
            if ($successb == 1) {
                return ($self->cryl_give($iname, $pobj))
            } elsif ($successb == 0 ) {
                $self->log_append("{3}You don't see anyone named $pname here.\n");
            } elsif ($successb == -1) {
                $self->log_append("{7}To Whom!? ".$pobj);
            }
            return -1;
        }
        ($successa, $iobj) = $self->inv_cgetobj($iname, 0, $self->inv_objs());
        ($successb, $pobj) = $self->inv_cgetobj($pname, 0, @potential_recipients);
        if (($successa == 1) && ($successb == 1)) {
            return if(!$self->can_do(0,0,2));

            if (!$pobj->pref_get('gift-acceptance')) {
                $self->log_error("$pobj->{'NAME'} is not accepting gifts from other players.");
                $pobj->log_error("$self->{'NAME'} tried giving you $iobj->{'NAME'} but you refused.");
                $pobj->log_hint("Type accept to accept gifts from other players.");
                return
            }
            $self->item_hgive($iobj, $pobj);
            return;
        } elsif ($successa == 0) {
            $self->log_error("You don't have any $iname to give away.");
        } elsif ($successb == 0) {
            $self->log_error("You don't see anyone named $pname here.");
        } elsif ($successa == -1) {
            $self->log_error("Give What!? " . $iobj);
        } elsif ($successb == -1) {
            $self->log_error("To Whom!? " . $pobj);
        }
    }
    return;
}

# mich redid this
sub item_hgive (item, recipient) {
    # Syntax: $obj->item_hgive($item_obj, $to_obj, $is_quiet, $should_override_errors)
    my ($self, $item, $to, $quiet, $override) = @_;
    
    unless ($override) {
        if($to eq $self) {
            $self->log_error("Give to yourself? How greedy!");
            return 0;
        } elsif(!$to->inv_free()) {
            $self->log_error("{3}$to->{'NAME'} doesn't have any room to carry it.");
            return 0;
        } elsif($to->{'LEV'} < $item->{'MINLEV'} && $to->{'TYPE'}==1 ) {
            $to->log_error("$self->{'NAME'} tried to give you $item->{'NAME'} but you must be level $item->{'MINLEV'}");
	        $self->log_error("$to->{'NAME'} isn\'t big enough to carry $item->{'NAME'}. Min Level: $item->{'MINLEV'}");
            $self->log_suspicious_activity("Tried to give $item->{'NAME'} to $to->{'NAME'}, $item->{'MINLEV'}, $to->{'LEV'}");
            return 0;
        } elsif(!$to->can_lift($item) || !$item->can_be_lifted($self)) {
            $self->log_error("$to->{'NAME'} isn't strong enough to carry it.");
            return 0;
        }
        
    }
    
	# They can't give it if they don't have it
    return 0 if(!$self->inv_has($item));

	# No fair passing it into or out of arenas
    if ($self->{'GAME'} != $to->{'GAME'}) {
	    $self->log_error("Items cannot be passed between arena/non-arena environments.");
        return 0;
	}

    # remove the item if worn
    if($item->{'WORN'}) {
        $self->apparel_remove($item);
        delete $item->{'WORN'};
        $self->apparel_update;
    }

    # for unremovable weapons
    if ( ($self->{'WEAPON'} == $item->{'OBJID'}) && !$self->item_hunequip($item) ) { return 0; }
    $self->inv_del($item);
    $to->inv_add($item);


	my $afar_clause = $self->{'ROOM'}==$to->{'ROOM'}?"":" from afar";

    # display feedback 
    $self->log_append("{3}You hand {7}$item->{'NAME'} {3}to {7}$to->{'NAME'}\{3\}$afar_clause.\n") unless $quiet;
    $to->log_append("{7}$self->{'NAME'} {3}hands you {7}$item->{'NAME'}\{3\}$afar_clause.\n") unless $quiet;

    # obfuscate the item name if stuff (or invisible as added by mich)
    if ( rand(($self->pct_skill(7)+$self->pct_skill(15))/2) > rand(100) || $item->is_invis()) {
        $self->room_sighttell("{7}$self->{'NAME'} {3}hands an item to {7}$to->{'NAME'}\{3\}$afar_clause.\n", $to) unless $quiet;
    } else {
        $self->room_sighttell("{7}$self->{'NAME'} {3}hands $item->{'NAME'} to {7}$to->{'NAME'}\{3\}$afar_clause.\n", $to) unless $quiet;
    }

	# Log it before it happens (we might lose some objects) if we can.
    &main::log_event("Give Item", "$self->{'NAME'} gave $self->{'PPOS'} $item->{'NAME'} to $to->{'NAME'}.", $self->{'UIN'}, $to->{'UIN'}, $item->{'REC'}) if $self->{'UIN'} && $to->{'UIN'};


    $self->on_give($item, $to);
    $to->on_receive($item, $self);
    $item->on_given($self, $to);
    
    # set up last give/receive for suspicious activity tracker
    $self->{'LASTGIVE'} = time if $self->{'TYPE'} == 1;
    $to->{'LASTRECEIVE'} = time if $to->{'TYPE'} == 1;
    
    
    $self->log_suspicious_activity("Gave $item->{'NAME'} to $to->{'NAME'} within 60 seconds of logging in.")
    if  $self->{'TYPE'} == 1 && (time - $self->get_login_time()) < 60;
    
    $to->log_suspicious_activity("Received $item->{'NAME'} from $self->{'NAME'} within 60 seconds of logging in.")
    if  $to->{'TYPE'} == 1 && (time - $to->get_login_time()) < 60;
    return 1;
}


sub on_given(fromobj, to) { }
sub on_give(itemobj, to) { }
sub on_receive(itemobj, from) { }

sub on_order ($topic) {
 my ($self, $topic) = @_;
 return undef;
} 

sub on_ask ($topic) {
 my ($self, $topic) = @_;
 return undef;
} 

## MAKE:
# inv_getobj -UNUSED 

sub obj_untie ($obj) {
  # unties an object from refs that might refer to it (and delete other objs in some cases)
  my $self = shift;
  my $cby;
  if(defined($self->{'CONTAINEDBY'})) { 
    $cby = &obj_lookup($self->{'CONTAINEDBY'});
    if($self->{'WORN'}) { $cby->apparel_remove($self); $cby->apparel_update; }
    if($cby->{'WEAPON'} == $self->{'OBJID'}) { delete $cby->{'WEAPON'}; }
    $cby->inv_del($self);
    if($cby->stk_has($self)) { $cby->stk_del($self); }
    $cby->stats_update;
  }
  if(defined($self->{'DWEAP'})) { delete $main::objs->{$self->{'DWEAP'}}; }
  return;
}

sub inv_remove {
  # removes all contained objects from object
  my $self = shift;
  my $killer = shift;
  my $container;
  
#&main::rock_shout(undef, "$self->{'NAME'} die die\n", 1);
  if($self->{'CONTAINEDBY'}) { $container=&rockobj::obj_lookup($self->{'CONTAINEDBY'}); }
  else { $container=$main::map->[$self->{'ROOM'}]; }
  
  # WHY did i do: ???
  #my $so; foreach $so ($self->stk_objs) { $so->dissolve_allsubs; }
  
  my @inv_objs = ($self->inv_objs());
  if (@inv_objs) {
     # Check whether or not the user has a spectral shroud
     my $is_shrouded = $self->{'SOLDIER'} && $self->has_monolith('spectral');
  
     # add objs to room
     my (@objnames, $obj, $cap);
     foreach $obj (@inv_objs) { 
       # push (@objnames,$obj->{'NAME'}); we do this later
        delete $obj->{'WORN'};
        delete $obj->{'EQD'};
        delete $self->{$obj->{'ATYPE'}};
        delete $obj->{'CONTAINEDBY'};
     }
     delete $self->{'WEAPON'};
     delete $self->{'APRL'}; # clear weapon, apparel
     $self->apparel_update();

     # delete items from self & add to room
     $self->inv_del(@inv_objs);
     $container->inv_add(@inv_objs);
     
     if ($is_shrouded) {
         foreach my $obj (@inv_objs) {
#         &main::rock_shout(undef, "{17}$self->{'NAME'} is spectral shroud for $obj->{'NAME'}\n", 1);
             $obj->{'SPECTRAL_SHROUD'} = $self->{'NAME'};
         }
     }
     

     # if it's an NPC, change the list of items and delete them from room as necessary.
     if ($self->{'TYPE'}==1) { 
         # A *PLAYER* is dropping it
    	 if ($self->{'GAME'}) {
        	  foreach $obj (@inv_objs) {  
            	 delete $obj->{'LASTDROP'};
                 delete $obj->{'DROPOWN'};
                 push (@objnames,$obj->{'NAME'});
        	  }
    	 } else { 
        	  foreach $obj (@inv_objs) {  
            	 $obj->{'LASTDROP'}=time;
                 $obj->{'DROPOWN'}=$self->{'NAME'};
                 push (@objnames,$obj->{'NAME'});
        	  }
    	 }
     } else {
         # AN *NPC* is dropping this
         foreach $obj (@inv_objs) {
	         my $killercha = 0;
	         if($killer){ $killercha =  (($killer->{'STAT'}->[CHA] / 1290)  * 2); }
	         
			 my $killerluck = ($killer->{'LUCK'})*.003;
			 
	         my $droprate = $obj->{'DRPPCT'};
			 if (!$droprate) { $droprate = 5;}
	         $droprate = $droprate + $killercha + $killerluck;
	         
             if ( $obj->{'LASTDROP'} || (rand(100) < ($droprate) ) ) { 
                 # if a player originally had the item or random,...
                 $obj->{'VAL'} = ceil ($obj->{'VAL'}*.85); # Don't let it hit 0
                 $obj->{'WC'} = int ($obj->{'WC'}*.98);
                 $obj->{'AC'} = int ($obj->{'AC'}*.93);
                 if(!$obj->{'LASTDROP'}){ 
	                 $obj->{'MINLEV'} = int ($self->{'LEV'}*.7);
                 	 $obj->{'FIRSTDROP'} = time;
                 	 $obj->{'DROPOWN'} = $killer->{'NAME'}; }
                 
                 delete $obj->{'LASTDROP'};
                 push (@objnames,$obj->{'NAME'});
             } else { $obj->obj_dissolve; }
         }
     }
    
     if (@objnames) { 
         if ($is_shrouded) {
             # Limit output when item is shrouded
             $self->log_append("{3}As you draw your final breath, a rippling spectral shroud forms around you and your possessions.\n");
             $self->room_sighttell("{3}As $self->{'NAME'} draws $self->{'PPOS'} final breath, a rippling spectral shroud forms around $self->{'PPRO'} and $self->{'PPOS'} possessions.\n");
         } else {
             # Item isn't shrouded; tell all about what dropped
             if (@objnames == 1) { 
                 $cap = '{2}'.$objnames[0]." {1}falls into $container->{'NAME'}.\n";
             } else {
                 $obj = pop (@objnames);
                 $cap = '{2}'.join(', ',@objnames).' {1}and{2} '.$obj." {1}fall into $container->{'NAME'}.\n";
             }
             $self->room_sighttell($cap);
        }
     }
  }

  if($self->{'CRYL'}) { 
  	#if($killer->inv_rec_scan(1249)){$self->{'CRYL'} = $self->{'CRYL'} * 2;}
	 $self->room_sighttell("{13}$self->{'CRYL'} {3}cryl plummet into $container->{'NAME'}.\n");
     
	 if ($self->{'TYPE'} == 1 && $self->{'CRYL'} >= 50) {
	     # drop cryl as object if they have a bit of it, and they're a player
         my $cryl = cryl->new('CRYL', int($self->{'CRYL'}), 'NAME', 'pile of cryl', 'VOL', 1, 'DLIFT', 1, 'MASS', 1, 'DESC', 'A collection of coins, shining with a faint blue light.');
         $cryl->{'LASTDROP'}=time; $cryl->{'DROPOWN'}=$self->{'NAME'};
		 $container->inv_add($cryl);
     } else {
	     # otherwise drop the actual cryl amount
		 $container->{'CRYL'} += int $self->{'CRYL'};
	 } 
	 
     delete $self->{'CRYL'}; # remove cryl from my inv regardless
  }

}

sub obj_dissolve {
  # removes object from existance.
  my $self = shift;

  if($self->{'STATIC'}) { &failure('Tried dissolving a static object ('.$self->{'NAME'}.')'); return; } # dont remove objects that are static.
    
  if($main::activeusers->{$self->{'OBJID'}}) {
    # don't dissolve - move to nullity instead.
    if(!$main::objs->{$self->{'CONTAINEDBY'}}->inv_del($self)) {
         if($main::objs->{$self->{'CONTAINEDBY'}}->stk_has($self)){ 
           &main::rock_shout(undef,"{1}*** Deleting $self->{'NAME'} from $main::objs->{$self->{'CONTAINEDBY'}}->{'NAME'}\'s inventory.\n");
           $main::objs->{$self->{'CONTAINEDBY'}}->stk_del($self);
         }
    }
    $main::map->[0]->inv_add($self); $self->{'ROOM'}=0;
    return;
  }
  $main::obj_recd{$self->{'REC'}}--;
  # SHOULDNT BE HERE?: delete $main::obj_unique{$self->{'REC'}};
  
  foreach my $so ($self->stk_objs) { $so->dissolve_allsubs; }
  $self->un_portalize;
  $self->inv_remove;
  $self->obj_untie;
  delete $main::objs->{$self->{'OBJID'}}; # delete object from objid hash
  if(defined($main::activeusers->{$self->{'OBJID'}})) { delete $main::activeusers->{$self->{'OBJID'}}; } # delete from activeusers
  return;
}

sub exp_distribute (exp){
  # EVENLY spreads out exp amongst all stats. will round down.
  my ($self, $exp) = @_;
  for (my $n=6; $n<=22; $n++) {
     $self->{'EXP'}->[$n] = int ($exp/16);
  }
  $self->stats_update;
  return;
}

sub stats_change (statnum, value [,statnum, value...]){
  # note that although you pass it the stat's value, it translates
  # it to the exp equivelant and updates stats afterwards.
  my $self = shift;
  while(@_) {
    #print "Changing stat $_[0] to $_[1].\n";
    #$self->{'EXP'}->[shift(@_)] = (shift(@_)**3);
    $self->{'EXP'}->[$_[0]] = ($_[1]**3 + 1);
    shift; shift;
  }
  $self->stats_update;
  return;
}

sub wstats_change (statnum, value [,statnum, value...]){
  # note that although you pass it the stat's value, it translates
  # it to the exp equivelant and updates stats afterwards.
  my $self = shift;
  my (%defstats);
  if($self->{'WSTAT'}) {
    # sets up pairs of $defstat{'defined_stat_number'} = location_of_value_in_current_array
    for (my $n=0; $n<=$#{$self->{'WSTAT'}}; $n+=2) {
      $defstats{$self->{'WSTAT'}->[$n]}=$n+1;
    }
  }
  while(@_) {
    if($defstats{$_[0]}) { $self->{'WSTAT'}->[$defstats{$_[0]}] = $_[1];  } # print "Rewrote stat $_[0] to read $_[1] (location: $defstats{$_[0]}).\n";
    else { push(@{$self->{'WSTAT'}}, $_[0], $_[1]);   } #print "Set stat $_[0] to read $_[1].\n";
    shift; shift;
  }
  return;
}

sub base_health {
    my $self = shift;
    if(!$self->{'EXP'} || !scalar(@{$self->{'EXP'}})) {
        return 2;
    }

    return int ( ($self->base_stat(DEF) * 0.45 + $self->base_stat(AGI) * 0.35 + $self->base_stat(KNO) * 0.25 + $self->base_stat(MDEF) * 0.1 + $self->base_stat(CHA) * 0.2 + $self->base_stat(STR) * 0.125) * 5.2 + 2 + $self->{'BASEH'});
}

sub base_mana {
    my $self = shift;
    return int ($self->pct_skill(1, 1250)*9.5 + $self->{'BASEM'});
}

sub base_stat {
    my ($self, $stat) = @_;
    
if($stat >= 6) {
    return abs( $self->{'EXP'}->[$stat] && (int ((abs($self->{'EXP'}->[$stat] +1))**(1/3))));
} else {
    if($stat == KNO) {
        return int ( ($self->base_stat(KMEC) + $self->base_stat(KSOC) + $self->base_stat(KCOM) + $self->base_stat(KMED)) / 4);
    } elsif($stat == MAJ) {
        return int ( ($self->base_stat(MOFF) + $self->base_stat(MDEF) + $self->base_stat(MELE) + $self->base_stat(MMEN)) / 4);
    } elsif($stat == CHA) {
        return int ( ($self->base_stat(CAPP) + $self->base_stat(CATT)) / 2);
    } elsif($stat == DEF) {
        return int ( ($self->base_stat(DMEN) + $self->base_stat(DPHY) + $self->base_stat(DENE)) / 3);
    } elsif($stat == STR) {
        return int ( ($self->base_stat(SUPP) + $self->base_stat(SLOW)) / 2);
    } elsif($stat == AGI) {
        return int ( ($self->base_stat(AUPP) + $self->base_stat(ALOW)) / 2);
    }
}

}


sub get_worn_items() {
    # returns an array of objects I'm wearing
    my $self = shift;
    return $self->{'APRL'} ? @{$self->{'APRL'}} : undef;
}

sub stats_update {
   ## updates all STATS based on exp/substats
   my $self = shift;
   my ($n, $o, $w, $t, $manaBonus);
   if(!$self->{'EXP'} || !scalar(@{$self->{'EXP'}})) { 
        $self->{'MAXH'}=2;
        if($self->{'HP'} > 2) { $self->{'HP'}=2; }
        return;
   }
   
   $t = time;
   
   
   # update stats based on exp
   for ($n=6; $n<=22; $n++) {
     $self->{'STAT'}->[$n] = abs( $self->{'EXP'}->[$n] && (int ((abs($self->{'EXP'}->[$n]+1))**(1/3))) );
     if($self->{'EXP'}->[$n]<0) { $self->{'STAT'}->[$n] *= -1; }
     elsif($self->{'STAT'}->[$n]>2000) { $self->{'STAT'}->[$n] = 2000; }
   }
   
   my $a = $self->{'STAT'};
   $self->{'STAT'}->[0]=int (($a->[6]+$a->[7]+$a->[8]+$a->[9]) / 4);
   $self->{'STAT'}->[1]=int (($a->[10]+$a->[11]+$a->[12]+$a->[22]) / 4);
   $self->{'STAT'}->[2]=int (($a->[13]+$a->[14]) / 2);
   $self->{'STAT'}->[3]=int (($a->[15]+$a->[16]) / 2);
   $self->{'STAT'}->[4]=int (($a->[17]+$a->[18]) / 2);
   $self->{'STAT'}->[5]=int (($a->[19]+$a->[20]+$a->[21]) / 3);

   # calculate raw maxh. make sure you do this BEFORE adding armour values
   $self->{'MAXH'}=int ( ($self->{'STAT'}->[DEF]*.45 + $self->{'STAT'}->[AGI]*.35 
                      + $self->{'STAT'}->[KNO]*.25 + $self->{'STAT'}->[MDEF]*.1 + $self->{'STAT'}->[CHA]*.2
                      + $self->{'STAT'}->[STR]*.125) * 5.2 ) + 2 + $self->{'BASEH'};

   # add misc. bonuses
   # as for our apparrel..
   my $wobj;
   if($self->{'WEAPON'} && ($wobj = $main::objs->{$self->{'WEAPON'}}) && defined(@{$wobj->{'WSTAT'}}) ) { 
     $w = &obj_lookup($self->{'WEAPON'});
     for ($n=0; $n<=$#{$w->{'WSTAT'}}; $n+=2) {  $self->{'STAT'}->[$w->{'WSTAT'}->[$n]] +=  int $w->{'WSTAT'}->[$n+1]; } # add stats
     $manaBonus += $w->{'BASEM'};
   }
   
   $self->{'AOFFSET'}=0; # AC Sum
   
   foreach $o (@{$self->{'APRL'}}) { 
     for ($n=6; $n<=22; $n++) {  $self->{'STAT'}->[$n] +=  int $o->{'STAT'}->[$n]; } # add stats
     #$self->{'STAT'}->[19] += int ($o->{'AC'}/5); # give player a bonus due to weapon's AC. may be outdated soon.
     $self->{'AOFFSET'} += $o->{'AC'};
     if($o->{'BASEH'} >0) { $self->{'MAXH'}+=$o->{'BASEH'}; }
     $manaBonus += $o->{'BASEM'};
   } 
   
   # Note: if you change this ratio (lev * 2), update news article 447.
   if($self->{'AOFFSET'}>($self->{'LEV'}*2)) { $self->{'AOFFSET'}=$self->{'LEV'}*2; }
   
   if(defined($self->{'FX'})) {
    my $upstats;
    foreach $o (keys(%{$self->{'FX'}})) { 
     if ( $self->{'FX'}->{$o} > $t ) { &{$main::effectbase->[$o]->[4]}($self); }
     else { $upstats=1; }
    } 
    if($upstats) { $self->effects_update; }
   }

   # fix negative stats to minimum value.
   if($self->{'TYPE'}>=1) {
     for ($n=6; $n<=22; $n++) {  
       if($self->{'STAT'}->[$n]<0) { $self->{'STAT'}->[$n] = 0; }
     } 
   }
   
   # update main stats
   $a = $self->{'STAT'};
   $self->{'STAT'}->[0]=int (($a->[6]+$a->[7]+$a->[8]+$a->[9]) / 4);
   $self->{'STAT'}->[1]=int (($a->[10]+$a->[11]+$a->[12]+$a->[22]) / 4);
   $self->{'STAT'}->[2]=int (($a->[13]+$a->[14]) / 2);
   $self->{'STAT'}->[3]=int (($a->[15]+$a->[16]) / 2);
   $self->{'STAT'}->[4]=int (($a->[17]+$a->[18]) / 2);
   $self->{'STAT'}->[5]=int (($a->[19]+$a->[20]+$a->[21]) / 3);
   
   # used to handle main weapon stats..

   # update max mana
   $self->{'MAXM'}=int ($self->pct_skill(1, 1250)*9.5 + $manaBonus + $self->{'BASEM'});
   if($self->{'MAXM'} < $self->{'MA'}) { $self->{'MA'}=$self->{'MAXM'}; }
  
   # update level lastly
   # Note: RTG Feb 8 2003, changed this so that it reflects the number of
   # substats that the player has for each category.
#   $self->{'LEV'} = int (($self->{'STAT'}->[KNO] + $self->{'STAT'}->[MAJ] + $self->{'STAT'}->[CHA]
#                       +$self->{'STAT'}->[AGI] + $self->{'STAT'}->[STR] + $self->{'STAT'}->[DEF])/6);
   $self->{'LEV'} = int (($self->{'STAT'}->[KNO]*4 + $self->{'STAT'}->[MAJ]*4 + $self->{'STAT'}->[CHA]*2
                       +$self->{'STAT'}->[AGI]*2 + $self->{'STAT'}->[STR]*2 + $self->{'STAT'}->[DEF]*3)/17);

   if ($self->{'MAXH'} < $self->{'HP'}) { $self->{'HP'}=$self->{'MAXH'}; }

   return;
}

sub exp_affect (statnum, modifier) {
  # updates self's statnum based on modifier only
  my ($self, $statnum, $modif) = @_;
  # determine bonus
  my $bonus;
  if($main::race_mult[$self->{'RACE'}]) { $bonus = $modif * 0.8 * $main::race_mult[$self->{'RACE'}]->[$statnum] * ( ($self->{'STAT'}->[$statnum]+1)**3 - ($self->{'STAT'}->[$statnum])**3 ); }
  else { $bonus = $modif * 0.03 * ( ($self->{'STAT'}->[$statnum]+1)**3 - ($self->{'STAT'}->[$statnum])**3 ); }
  if ($bonus < 0) {  $bonus = $modif * 0.01; }
  #print "Bonus was $bonus.\n";
  # add to self total exp.
  $self->{'EXP'}->[$statnum] += $bonus;
  return;
}

sub on_smash { my $self = shift; return; }

sub exp_caffect {
  # EXP COMPARATIVE_AFFECT
  # updates self's statnum based on comparitive object and modifier
  my ($self, $obj, $statnum, $modif) = @_;
  # determine bonus
  my ($bonus, $rawstat, $sdiff);
  if($main::race_mult[$self->{'RACE'}]) { $bonus = $modif * 0.8 * $main::race_mult[$self->{'RACE'}]->[$statnum] * ($obj->{'EXP'}->[$statnum] - $self->{'EXP'}->[$statnum]); }
  else { $bonus = $modif * 0.03 * ($obj->{'EXP'}->[$statnum] - $self->{'EXP'}->[$statnum]); }
  if ($bonus < 0) { $bonus = $modif * 0.007; }
  $rawstat = int ($self->{'EXP'}->[$statnum]**(1/3));
  if ($bonus > ( $sdiff = ((($rawstat+1)**3) - ($rawstat**3)) ) ) { 
     $self->{'EXP'}->[$statnum] += $sdiff;
     $self->stats_update;
     return;
  }
  # add to self total exp.
  $self->{'EXP'}->[$statnum] += $bonus;
  return;
}

sub container {
    # Returns the object that holds me, or undef if none exists
    my $cby = $_[0]->{'CONTAINEDBY'};
    return defined($cby) ? &rockobj::obj_lookup($cby) : undef;
}

sub on_kill {}

sub is_admin {
    # returns true if i am an admin. else returns 0
    return $_[0]->{'ADMIN'} != 0;
}

sub on_before_die() {

}

sub die {
    # Format: $object->die($attacker);
    # Note: $attacker object is optional. Make sure you check for it
    #       before doing stuff with it. Otherwise evil stuff is created.
    
    my $self = shift;
    my $killer = shift;

    $self->on_before_die($killer);
    
    my $pvproom = $self->room()->{'PVPROOM'};
    
    if($self->{'DIED'} == time || $self->{'TYPE'}==-1) { return; }
    
    if(!$pvproom) {
        if($self->{'IMMORTAL'}) { 
            $self->{'HP'}=$self->{'MAXH'};
            $self->room_sighttell("{4}$self->{'NAME'} is healed by a powerful, external force.\n");
            $self->log_append("{4}You are healed by a powerful, external force.\n");
            return;
        } elsif($self->effect_has(51) && rand 1 <= .75) {
            # [CYRUS] Effect 51 (Amulet of Conviction, etc).
            #         refuel victim and kill the effect if he gets lucky.
            $self->log_append("A feeling of inner peace encompasses you, and a second chance at life is granted.\n");
            $self->room_sighttell("{4}$self->{'NAME'} is healed by a powerful, external force.\n");
            $self->log_append("{4}You are healed by a powerful, external force.\n");
            $self->{'HP'}=$self->{'MAXH'};
            $self->effect_del(51);
            return;
        } elsif(my $orb = $self->inv_rec_scan(381)) {
            $self->log_append("{13}Just as you feel as though you've lost all consciousness, a jolt of energy speeds through you.\n");
            $self->room_sighttell("{13}Several sparks spring from $self->{'NAME'}\'s $orb->{'NAME'} through $self->{'PPOS'} body.\n");
            $orb->obj_dissolve();
            $self->{'HP'}=int ($self->{'MAXH'}/4);
            return;
        }elsif((my $eq = $self->aprl_rec_scan(1116))) {
	        if($eq->{'USES'})
	        {
            	$self->log_append("{13}Just as you feel as though you've lost all consciousness, a jolt of energy speeds through you.\n");
            	$self->room_sighttell("{13}Several sparks spring from $self->{'NAME'}\'s $eq->{'NAME'} through $self->{'PPOS'} body.\n");
            	$eq->{'USES'}--;
            	$self->{'HP'}=int ($self->{'MAXH'}/2);
        		return;
            }
        }elsif((my $staff = $self->inv_rec_scan(733)) ) {
	        if(($staff->{'USES'}>0)  &&  $staff->{'ISSTAFF'})
	        {
            	$self->log_append("{13}Just as you feel as though you've lost all consciousness, a jolt of energy speeds through you.\n");
            	$self->room_sighttell("{13}Several sparks spring from $self->{'NAME'}\'s $eq->{'NAME'} through $self->{'PPOS'} body.\n");
            	$staff->{'USES'}--;
            	$self->{'HP'}=int ($self->{'MAXH'}/2);
        		return;
            }
        }
    }

    ########### SELF IS DEFINITELY DEAD AFTER THIS POINT ###################
    $self->{'DIED'}=time;
    delete $self->{'TANGLED'};
    
    $self->on_die($killer); # call on_die before dying.
	if($killer->{'LUCK'}<90){
		$killer->{'LUCK'} = $killer->{'LUCK'}+.001;
	}
    if($killer) {
        $pvproom &&= $killer->room()->{'PVPROOM'};

        if( $self->{'TYPE'}==1 && $killer->{'TYPE'}==1 ){ 


            $self->{'DIEDBY'} = $killer->{'OBJID'}; # diedby is an objid
            delete $killer->{'CANPVP'}->{$self->{'NAME'}};
            $killer->{'PKTIME'} = time;


            my $deathloc = $self->room()->{'NAME'};
            $deathloc = "??? Somewhere ???" if($self->is_admin() || $killer->is_admin());
    
            if ($killer->{'RACE'} == $self->{'RACE'}) {
                &main::rock_rshout($killer, "{7}## {7}$deathloc: {14}Sadly {12}Rejoice!.. {2}\{$self->{'RACE'}\}$self->{'NAME'} {7}was done in by \{$killer->{'RACE'}\}$killer->{'NAME'}\{7}!\n", 'silence deaths');
            } else {
                &main::rock_rshout($killer, "{7}## {7}$deathloc: {12}Rejoice! \{$self->{'RACE'}\}$self->{'NAME'} {7}was done in by \{$killer->{'RACE'}\}$killer->{'NAME'}\{7}!\n", 'silence deaths');
                &main::rock_rshout($self, "{7}## {7}$deathloc: {14}Sorrow.. \{$self->{'RACE'}\}$self->{'NAME'} {7}was slain by \{$killer->{'RACE'}\}$killer->{'NAME'}\{7}!\n", 'silence deaths');
				
            }
            
            #&main::rock_rshout($killer, "{13}## {1}Rejoice! {14}Rumors circulate that {3}$self->{'NAME'} {7}the $main::races[$self->{'RACE'}] {14}was done in by {13}$killer->{'NAME'} in $main::map->[$self->{'ROOM'}]->{'NAME'}!\n");
            #&main::rock_rshout($self, "{13}## {16}Sorrow.. {7}You feel the death pang of {3}$self->{'NAME'}, \{7}as $self->{'PRO'} is slain by {13}$killer->{'NAME'} {7}the $main::races[$killer->{'RACE'}] in $main::map->[$killer->{'ROOM'}]->{'NAME'}!\n");
    
            # exp for PvPs
            #       my $exp = (abs($killer->{'LEV'}-$self->{'LEV'})<40)?($self->{'KEXP'} || int ( $self->{'LEV'}**1.6 )*8):$self->{'LEV'}*10;
    
            if($killer->{'GAME'} || $self->{'GAME'} || $pvproom) {
                ## $killer->{'ARENA_PTS'}++; not unless these are bonus points; dont forget about rockunit's on_odie
            } else {

                &main::log_event("PKill", "$killer->{'NAME'} ($main::races[$killer->{'RACE'}]) PvP-Killed $self->{'NAME'} ($main::races[$self->{'RACE'}]).", $killer->{'UIN'}, $killer->{'RACE'}, $self->{'UIN'}, $self->{'RACE'});
                   
                $self->trivia_inc(STAT_PLR_DEATHS);
                $killer->trivia_inc(STAT_PLR_KILLS);

                $killer->{'PVPKILLS'}++; $self->{'PVPDEATHS'}++;
                $killer->{'PVPS'}--;
                if($killer->{'PVPS'}<=0) { delete $killer->{'PVPS'}; }
                $killer->{'LASTPVP'}=$self->{'NAME'};

                my $exp = (abs($killer->{'LEV'}-$self->{'LEV'})<40)?($self->{'KEXP'} || int ( $self->{'LEV'}**1.4 )*24):$self->{'LEV'}*10;
                if($killer->{'RACE'}==6){$exp = $exp*1.5;}
                #if($killer->{'RACE'}==6){$exp = $exp*.9;}
                
				$exp = int ( $self->{'LEV'}**1.4 )*24;
				
				$killer->exp_add($exp * $main::lightning_exp_multiplier);
				
				
				
                # We might be able to steal turns here!
                if ($self->{'SOLDIER'} && $killer->{'SOLDIER'} && $killer->race_owns_monolith('monolith_temporal') && $self->{'TURNS_STORED'}) {
                    my $turns_stolen = int $self->{'TURNS_STORED'};
                    my $turns_given = int($turns_stolen * .75);
                    $turns_given = min($main::max_turns_storable - $killer->{'TURNS_STORED'}, $turns_given);		   
                    delete $self->{'TURNS_STORED'};
                    $killer->{'TURNS_STORED'} += $turns_given;
                
                    $killer->log_append("{4}Your temporal vault bulges with stolen time, as you pillage {14}$self->{'NAME'}\'s {4}stashed moments. (+$turns_given)\n");
                    $self->log_append("{1}You feel your temporal vault empty, as {11}$killer->{'NAME'} {1}steals away your precious time! (-$turns_stolen)\n");
                }

                # If the victim was a general, then give the killer some bonus turns!
                # BUT NOT IF IT'S IN A FRIGGIN' ARENA
                if ($self->{'GENERAL'} && $killer->{'GENERAL'} ) {

                    my $stolen_turns = 1000;
                    #		   &main::rock_shout(undef, "BEFORE: $self->{'T'}, KILLER $killer->{'T'}\n", 1);
                    # Don't give out more turns than the victim has!
                    $stolen_turns = $self->{'T'} if $stolen_turns > $self->{'T'};
                    $stolen_turns = 0 if $stolen_turns < 0;
                    
                    $self->{'T'} -= $stolen_turns;
                    $killer->{'T'} += $stolen_turns;
                    $killer->{'REPU'}+= 0.5;
                    $self->{'REPU'} -= 2;
                    #		   &main::rock_shout(undef, "AFTER: $self->{'T'}, KILLER $killer->{'T'}\n", 1);
                    $self->log_append("{3}<<  You have lost $stolen_turns turns in your fight to restore political integrity.  >>\n");
                    $killer->log_append("{3}<<  Your victory support has found you more free time, accumulating $stolen_turns spare turns.  >>\n");
                    &main::rock_rshout($killer, "{13}## Your post-victory support of {3}$killer->{'NAME'} {13}has gained $killer->{'PPRO'} $stolen_turns more turns for the day.\n");
                    &main::rock_rshout($self, "{13}## Your post-victory doubts of {3}$self->{'NAME'} {13}has lost $self->{'PPRO'} $stolen_turns turns for the day.\n");
                    #&main::mail_send($main::rock_admin_email, "PvP'd a General", "$killer->{'NAME'} killed $self->{'NAME'}\n");
                }
                elsif ($self->{'GENERAL'}) {
	                $killer->{'REPU'}+= 0.5;
                    #$self->{'REPU'} -= 2;
                    &main::rock_rshout($killer, "{13}## Your post-victory support of {3}$killer->{'NAME'} {13}has gained $killer->{'PPRO'} more respect within your race.\n");
                    &main::rock_rshout($self, "{13}## Your post-victory doubts of {3}$self->{'NAME'} {13}has lost $self->{'PPRO'} the some respect of your race.\n");
                }
            }
        } else { #not player
            if ($killer->{'TYPE'}==OTYPE_NPC  && $self->{'TYPE'} != OTYPE_NPC) {
                $self->{'NPCDEATHS'}++;
                &main::rock_rshout($self, "{14}Sorrow.. \{$self->{'RACE'}\}$self->{'NAME'} {7}was slain by \{$killer->{'RACE'}\}$killer->{'NAME'}\{7}!\n", 'silence deaths');
				&main::rock_shout(undef, "$self->{'NAME'} died in room ($self->{'ROOM'})\n", 1);# affected $rcount rooms (@rooms_affected).\n", 1);
                $self->trivia_inc(STAT_NPC_DEATHS);
            }
            if ($self->{'TYPE'}== OTYPE_NPC) {
                $killer->{'NPCKILLS'}++;
                $killer->trivia_inc(STAT_NPC_KILLS);
            }
        }

        if($self->{'GAME'} || $killer->{'GAME'} ) { 
	      $main::objs->{$main::gameobjs{($self->{'GAME'}||$killer->{'GAME'})}}->on_death_notify($killer, $self);
        }

    } else {  #no killer
        $self->{'MISCDEATHS'}++;
    }
    
    
    if ($self->{'GAME'}) {
        $self->{'ARENA_PTS'}--;
        if ($self->{'ARENA_PTS'} < -10) {
            $self->{'ARENA_PTS'}=-10;
        }
    }
    
    #mich patch - money based on level of npc and player charisma
    my $crylbonus = 0;
    if ($killer && $killer->{'TYPE'} == 1 && $self->{'TYPE'} == 2)
    {
        if (rand(50) < 1)
        {
            $self->{'CRYL'} += int(rand($self->{'LEV'}*.8)); # note: plat changed to *.8
            #&main::rock_shout(undef, "Cryl bonus: $self->{'CRYL'} Killer Level: $killer->{'LEV'}\n", 1);
        }
    
        if ( ( ($killer->{'STAT'}->[2] / $killer->{'LEV'}) * 100) > rand(700))
        {
            $crylbonus = int(rand($killer->{'STAT'}->[2]));
            if ($crylbonus > ($self->{'LEV'} * 0.75)) {$crylbonus = ($self->{'LEV'} * 0.75);}
            if ($crylbonus > 100) { $crylbonus = 100;}
            $self->{'CRYL'} += int ($crylbonus * .8); # note: plat changed to *.8
            #&main::rock_shout(undef, "Cha cryl bonus: $self->{'CRYL'} Killer Level: $killer->{'LEV'}\n", 1);
        }
    }
    #end mich patch
    
    $self->room_sighttell('{17}'.$self->{'NAME'}." {1}disintegrates.\n");
    

    my $no_room_change;
    unless ($pvproom) {
        # lose exp.. :(
        my $eq = $self->aprl_rec_scan(1114);
        my $orb = $self->inv_rec_scan(338);
        my $spherule = $self->inv_rec_scan(1117);
        my $spherule_artifact = $self->inv_rec_scan(1118);
        
        if( $self->{'RACE'} == 6  && ($killer->{'TYPE'} != 1) ) {
	      $self->log_append("{4}Because you are a Kelion you haven't lost any experience.\n");
		}elsif ($orb) {
            $self->log_append("{6}Your {1}$orb->{'NAME'} {6}suddenly heats up, creating a mental barrier and melts away.\n");
            $orb->obj_dissolve();
        
        } elsif(($spherule = $self->inv_rec_scan(1117)) && ($spherule->{'USES'}) ) {
	        $self->log_append("{6}Your {1}$spherule->{'NAME'} {6}suddenly heats up, creating a mental barrier.\n");
   		
	    } elsif(($spherule = $self->inv_rec_scan(1118)) && ($spherule->{'USES'}) ) {
	        $self->log_append("{6}Your {1}$spherule->{'NAME'} {6}suddenly heats up, creating a mental barrier.\n");
   		
	    } elsif ( $eq->{'USES'} ) {
	   		$self->log_append("{6}Your {1}$eq->{'NAME'} {6}suddenly heats up, creating a mental barrier.\n");
   			$eq->{'USES'}--;
        } elsif (!$self->{'NEWBIE'} && !$self->{'GAME'} ) {
            #    for (my $n=6; $n<=22; $n++) { $self->{'EXP'}->[$n] *= (1 - $self->{'LEV'}/20_000); }   # was this til 2002-12-25
            #  (1 - $_[0]->{'LEV'}/18_000)
            if ($self->{'SOLDIER'} && !$self->{'DEATHS_TODAY'}) {
                $self->log_append("{4}Because you are a soldier and this was your first death of the day, you haven't lost any experience.\n");
				$self->{'DEATHS_TODAY'}++;
            } else {
                my $real_level = $self->get_real_level();
                for (my $n=6; $n<=22; $n++) {
                    $self->{'EXP'}->[$n] = int ($self->{'EXP'}->[$n] * (1 - $real_level/18_000))
                        unless $self->{'EXP'}->[$n] <= 2;
                } 
            
            ##$self->{'EXPPHY'} = int ($self->{'EXPPHY'}*3/4);
            $self->{'EXPPHY'} = 0;
            ##$self->{'EXPMEN'} = int ($self->{'EXPMEN'}*3/4);
            $self->{'EXPMEN'} = 0;
            
			$self->{'LIVES'}--;
            $self->{'DEATHS_TODAY'}++;
			if(!$self->{'NEWBIE'}){ 
				$self->{'DEATHS_THIS_REBIRTH'}++;
			}
			if(($self->{'TYPE'}==1) && ($self->{'DEATHS_THIS_REBIRTH'} >= 10) ){
			#	$self->cmd_do("remove all");
			#	$self->item_spawn(65);
			#	$self->cmd_do("life");
			#	$self->cmd_do("wield shortsword");
			#	$self->cmd_do("wear all");
			#	$self->stats_allto(1);
			#	$self->exp_add((50**3 - 1**3)*17);
			#	$self->{'SOLDIER'} = 0;
			#	delete $self->{'NEWTURNS'};
			#	delete $self->{'KILLREC'};
			#	delete $self->{'DEATHS_THIS_REBIRTH'};
			#	delete $self->{'ALOOT'};
			}
            $self->stats_update();
			}
        }
        
        if ($orb = $self->inv_rec_scan(380)) {
            $no_room_change=1 if $self->{'TYPE'} == 1; # only works on players
            $self->log_append("{3}$orb->{'NAME'} quickly fizzles away.\n");
            $orb->obj_dissolve();
        }elsif(($eq = $self->aprl_rec_scan(1115)) && $eq->{'USES'} ){
	        $no_room_change=1 if $self->{'TYPE'} == 1; # only works on players
            $self->log_append("{3}$eq->{'NAME'} keeps you in your place.\n");
            $eq->{'USES'}--;
        }elsif(($spherule = $self->inv_rec_scan(1118)) && ($spherule->{'USES'}) ){
	        $no_room_change=1 if $self->{'TYPE'} == 1; # only works on players
            $self->log_append("{3}$spherule->{'NAME'} keeps you in your place.\n");
        }elsif(($spherule = $self->inv_rec_scan(1117)) && ($spherule->{'USES'}) ){
	        $no_room_change=1 if $self->{'TYPE'} == 1; # only works on players
            $self->log_append("{3}$spherule->{'NAME'} keeps you in your place.\n");
        } 
        
        # save items/cryl if they have the orbaroonie
        my $orb = $self->inv_rec_scan(135);
        $eq = $self->aprl_rec_scan(1113);
        if ($orb && !$main::map->[$self->{'ROOM'}]->{'!TURQ_ORB'}  && ($killer->{'TYPE'} != 1) ) {
            $self->log_append("{6}In a flash, the $orb->{'NAME'} encompasses your items.\n");
            $orb->obj_dissolve();
        }elsif( ($spherule = $self->inv_rec_scan(1118))&& $spherule->{'USES'} && !$main::map->[$self->{'ROOM'}]->{'!TURQ_ORB'}) {
	         $self->log_append("{6}In a flash, the $spherule->{'NAME'} encompasses your items.\n");
	         $spherule->{'USES'}--;
        }elsif( ($spherule = $self->inv_rec_scan(1117))&& $spherule->{'USES'} && !$main::map->[$self->{'ROOM'}]->{'!TURQ_ORB'}) {
	         $self->log_append("{6}In a flash, the $spherule->{'NAME'} encompasses your items.\n");
	         $spherule->{'USES'}--;
	         if(!$spherule->{'USES'} ){ $spherule->obj_dissolve();}
        }elsif ($eq && $eq->{'USES'} && !$main::map->[$self->{'ROOM'}]->{'!TURQ_ORB'}) {
	         $self->log_append("{6}In a flash, the $eq->{'NAME'} encompasses your items.\n");
	         $eq->{'USES'}--;
    	}elsif ($self->{'ADMIN'} && !$self->{'GAME'} && !$self->{'KILLABLE'}) {

            $self->log_error("Though you had no orbs, your spiffieness has caused you to keep your items.");
        } else {
            $self->inv_remove($killer);
        }

        delete $self->{'GRAPES'};
        delete $self->{'SALP'};
        delete $self->{'FROGS'};
        delete $self->{'WANTED'};
        #  $self->leave_current_group();
        if($self->{'LIMIT'}==1){
			$self->bodypart_drop('head', $killer);
		}else {
			$self->bodypart_drop(undef, $killer);
		}
    }
    if(($self->{'TYPE'} == 1) && $pvproom && $self->room()->{'TRAINAREA'}) { $no_room_change = 1; }
    
    $self->log_append("{11}You disintegrate into the ether and appear..elsewhere? {16}($self->{'LIVES'} lives remain)\n{6}Type {16}life{6} to come back to life.\n");
	$self->{'LUCK'} = $self->{'LUCK'}*.5;
	if($self->{'LUCK'}<1){$self->{'LUCK'}=1;}

    my $cby = $self->container() || $self->room();
    
    # tell objs of death..
    $main::map->[$self->{'ROOM'}]->tell(12, 1, 0, undef, $self, $killer);
    
    # spawn item(s) if any
    if ($self->{'onDeath_SPAWN'}) { 
        $main::map->[$self->{'ROOM'}]->item_spawn($self->{'onDeath_SPAWN'});
    }
    
    
    
    # change rooms
    if (!$no_room_change) {
        $cby->inv_del($self);
        $self->{'ROOM'} = defined($self->{'TEMPDROOM'}) ? $self->{'TEMPDROOM'} : ($self->{'TYPE'}==1?$main::roomaliases{'managath'}:0);
        #$self->{'ROOM'} = defined($self->{'TEMPDROOM'}) ? $self->{'TEMPDROOM'} : ($self->{'TYPE'}==1?$main::roomaliases{'bridge_guard_room'}:0);
        delete $self->{'FRM'};
        $main::map->[$self->{'ROOM'}]->inv_add($self);
        #mich - move the person's items too
        foreach my $iobj ($self->inv_objs()) {
           $iobj->{'ROOM'}=$self->{'ROOM'};
        }
        if ($self->{'TYPE'}==1) { 
            $self->room_sighttell('{16}'.$self->{'NAME'}."{6}'s body materializes through the vast darkness of the void.\n");
        }
    }
    
    # schedule respawn if i should
    if ($self->{'onDeath_RESPAWN'}) { 
        $main::eventman->enqueue($self->{'onDeath_RESPAWN'} * 60, \&rockobj::item_spawn, $cby, $self->{'REC'});
    }
    
    # clean up attack history
    delete $self->{'A_HIST'};
    delete $self->{'DAM_RCV'};
    
    # clean up effects
    foreach my $k (keys(%{$self->{'FX'}})) {
        $self->{'FX'}->{$k}=1;
    }
    $self->effects_update();
    $self->effect_del(46);

    if ( (scalar keys(%{$main::map->[0]->{'INV'}})) > 10 ) {
        $main::map->[0]->cleanup_inactive();
    }
    # if($self->{'TYPE'} == 1) { $main::donow .= '$main::objs->{'.$self->{'OBJID'}.'}->{'HP'} = $main::objs->{'.$self->{'OBJID'}.'}->{'MAXH'};'; }

    if ($killer) {
        $killer->on_kill($self);
    }
    

    # if their autoraise is on, try raising their stats since they just lost a bunch.
    $self->exp_cycle(1) if $self->pref_get("autoraise");

    return;
}

sub exp_add {
    # Note: splits exp up into ephy/emen according to race charts @main::raceExpPHYMap.
    my ($self, $ephy, $quiet) = @_;
    # PhyPct = racialPHYPct + .05 * powermonger - .05 * truthseeker
    my $phyPct;
	
	
    my $array = $self->{'TRIVIA_STATS'};
	my $nkills_total = $array->[STAT_NPC_KILLS_TOTAL];
	
	if($nkills_total<3000){
		$ephy = $ephy *3;
	}
    #if($self->{'RACE'}==6 && !$self->{'NEWBIE'}){   $ephy = $ephy * 1.13;	    }
    if($self->{'RACE'}==6 && !$self->{'NEWBIE'}){   $ephy = $ephy * .9;	    }
    if($self->quest_has(6)) {
        # advanced powermonger
        $phyPct = ($main::raceExpPHYMap[$self->{'RACE'}] || 0.5) + 0.15;
    }elsif($self->quest_has(7)) {
        # advanced truthseeker
        $phyPct = ($main::raceExpPHYMap[$self->{'RACE'}] || 0.5) - 0.15;
    }elsif($self->quest_has(3)) {
        # powermonger
        $phyPct = ($main::raceExpPHYMap[$self->{'RACE'}] || 0.5) + 0.05;
    }elsif($self->quest_has(4)) {
        # truthseeker
        $phyPct = ($main::raceExpPHYMap[$self->{'RACE'}] || 0.5) - 0.05;
    }else {
        # nothin
        $phyPct = $main::raceExpPHYMap[$self->{'RACE'}] || 0.5;
    }

    $self->{'EXPPHY'} += int ($ephy*$phyPct);
    $self->{'EXPMEN'} += int ($ephy*(1 - $phyPct));
    unless ($quiet) {
        $self->{'EXPTODAY'} += int $ephy; # add to daily combat exp count
        $self->log_append("{1}You gain {17}".&rockobj::commify(int $ephy)."{1} experience.\n");
        $self->exp_cycle(1) if $self->pref_get('autoraise'); # NOTE this is inside the block so that the quiet stuff isn't autoraised.. it's set implicitly so let's not magically make them raise it when they dont know they just got exp.
    }
    
    
    return;
}

sub on_odie {};

sub is_dead { my $self = shift; return ($self->{'HP'} <= 0); }

sub item_equip {
 # wears item with name $iname
 my ($self, $iname) = @_;
 if(!$iname) { $self->log_append("{3}Wield what? Format: wield <itemname>\n"); return; }
  my ($success, $item) = $self->inv_cgetobj($iname,0);
 	
 if($success == 1) { 
	if($item->{'MINLEV'}>$self->get_real_level()){
	 $self->log_append("{3}Wield what? Sorry, but you are still to small to be wielding $item->{'NAME'}\n");
	 return(0);
	 } 
    $self->item_hequip($item);
    $self->stats_update;
    return(1);
 } elsif($success == 0) { $self->log_append("{3}You don't have a $iname to wield.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub item_unequip {
 # wears item with name $iname
 my ($self, $iname) = @_;
 #if(!defined($iname)) { 
 if($self->{'WEAPON'}) { $self->item_hunequip($main::objs->{$self->{'WEAPON'}}); $self->stats_update; }
 else { $self->log_append("{3}You aren't wielding anything anyways!\n"); return; }
 #}
 return (1);
}

sub item_wear {
 # wears item with name $iname
 my ($self, $iname) = @_;
 if(!$iname) { $self->log_append("{3}You've got to decide on something to wear.\n{1}(format: {17}wear {7}<itemname>{1})\n"); return; }
 if(lc($iname) eq 'all') { 
	# Note: Right now we're charging 1 turn for wearing all, which
	#       is the same for wearing one item. Really, we should be
    #       charging on a per-item basis.

    return 0 unless $self->can_do(0,0,1);

    my @ilist;
    foreach my $i ($self->inv_objs) {
      if(defined($i->{'ATYPE'}) && !defined($self->{$i->{'ATYPE'}})) {
	      if($i->{'MINLEV'}>$self->get_real_level()){
	 		$self->log_append("{3}Equip what? Sorry, but you are still to small to be wearing $i->{'NAME'}\n");
 	 	} elsif($self->item_hwear($i, 1)) { push(@ilist, $i->{'NAME'}); }
      }
    }
    if(!@ilist) { $self->log_append("{17}You wear: {7}nothing{17}.\n"); }
    else {
        $self->log_append("{17}You wear: {7}".join(', ',@ilist)."{17}.\n");
        $self->room_sighttell("{17}$self->{'NAME'} wears: {7}".join(', ',@ilist)."{17}.\n");
        $self->stats_update();
    }
    return 1;
 }
 my ($success, $item) = $self->inv_cgetobj($iname,0);
 if($success == 1) { 
	 if($item->{'MINLEV'}>$self->get_real_level()){
	 $self->log_append("{3}Equip what? Sorry, but you are still to small to be wielding $item->{'NAME'}\n");
	 return(0);
	 } 
    if(!$self->can_do(0,0,1)) { return(0); }
    $self->item_hwear($item);
    $self->stats_update;
    return(1);
 } elsif($success == 0) { $self->log_append("{3}You don't have a $iname to wear.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub item_remove {
    # wears item with name $iname
	my ($self, $iname) = @_;
	if(!$iname) { $self->log_append("{3}You've got to decide on something to remove.\n"); return; }
	if(lc($iname) eq 'all') { 
	   # Note: Right now we're charging 1 turn for removing all, which
	   #       is the same for removing one item. Really, we should be
	   #       charging on a per-item basis.
	   
       return 0 unless $self->can_do(0,0,1);
       
	   my @ilist;
       foreach my $i ($self->inv_objs) {
    	 if(defined($i->{'WORN'}) && $i->{'WORN'}) {
        	if($self->item_hremove($i, 1)) { push(@ilist, $i->{'NAME'}); }
    	 }
       }
       if(!@ilist) { $self->log_append("{17}You remove: {7}nothing{17}.\n"); }
       else {
           $self->log_append("{17}You remove: {7}".join(', ',@ilist)."{17}.\n");
           $self->room_sighttell("{17}$self->{'NAME'} removes: {7}".join(', ',@ilist)."{17}.\n");
           $self->stats_update();
       }
       return 1;
	}
	my ($success, $item) = $self->inv_cgetobj($iname,0);
	if($success == 1) { 
        return 0 unless $self->can_do(0,0,1);
        $self->item_hremove($item);
        $self->stats_update;
        return(1);
	} elsif($success == 0) {
	    $self->log_append("{3}You don't have a $iname to unequip.\n");
	    return(0);
	} elsif($success == -1) { $self->log_append($item); return(0); }
	return (1);
}

sub is_wielding {
    my ($self, $weapon) = @_;
	# Returns true if $self is wielding $weapon
	
}
sub is_wearing {
    my ($self, $weapon) = @_;
	# Returns true if $self is wearing $weapon
	
}

sub item_hequip {
  my ($self, $item, $quiet) = @_;
  ## Check if its not an ITEM.
  if( $item->{'TYPE'} != 0 ) { $self->log_append("You may not equip $item->{'NAME'}!\n"); return(0);  }
  ## Check if we're already equipping that ITEM.
  if( ($self->{'WEAPON'} eq $item->{'OBJID'}) || ($self->{'APRL'}->[$self->{$item->{'ATYPE'}}] eq $item) ) { $self->log_append("But you already have that item equipped!\n"); return(0);  }
  ## If it's raceonly then keel'em.
  if( $item->{'RACEONLY'} && ( index($item->{'RACEONLY'}.' ', ($self->{'RACE'}*1).' ') == -1 ) ) { $self->log_append("{3}Your race is unable to wear $item->{'NAME'}.\n"); return (0); }

  unless ($self->has_minstats($item->{'EQUIP_MINSTATS'})) {
      $self->log_error("You don't feel skilled enough to wield $item->{'NAME'}, you must have $item->{'EQUIP_MINSTATS'}");
	  return 0;
  }

  ## Check if we're already equipping that item.
  if($self->{'WEAPON'}) { if(!$self->item_hunequip) { return(0); } }
  ## Check if we can't equip that item.
  if(!$item->can_equip($self)) { $self->log_append("{3}You cannot wield $item->{'NAME'}.\n"); return(0); }
  if(!$self->can_do(0,0,1)) { return(0); }
  ## make item my weapon
  $self->{'WEAPON'}=$item->{'OBJID'};
  $item->{'EQD'}=1; # tell item it's equipped.
  if(!$quiet) { 
      $self->log_append("{2}You wield {4}".$item->{'NAME'}."{2}.\n");
      $self->room_sighttell(sprintf("{2}%s wields {4}%s{2}.\n", $self->{'NAME'}, $item->{'NAME'}));
  }
  $item->on_wield($self);
  return(1);
}

sub on_wield() { 1; }

sub item_hunequip {
  my $self = shift;
  ## Check if we're not wearing that item.
  if(!$self->{'WEAPON'}) { $self->log_append("{3}You don't have anything equipped.\n"); return(0); }
  ## Check if we can't remove that item.
  my $item = $main::objs->{$self->{'WEAPON'}};
  if( eval { !$item->can_unequip($self) } ) { $self->log_append("{3}You are unable to disarm $item->{'NAME'}.\n"); return(0); }
  if($@){ &main::rock_shout(undef, "{1}Returned unequip unsuccessfully: $self->{'NAME'} with $item->{'NAME'} ($item->{'OBJID'}) [$@]\n", 1); return(0); } # DEBUG ME!!!! REPORT WHO CALLED ME WHEN HIS HAPPENS
  if(!$self->can_do(0,0,1)) { return(0); }
  ## otherwise we can remove it
  delete $self->{'WEAPON'};
  delete $item->{'EQD'};
  $self->log_append("{2}You disarm {4}".$item->{'NAME'}."{2}.\n");
  $self->room_sighttell(sprintf("{2}%s disarms {4}%s{2}.\n", $self->{'NAME'}, $item->{'NAME'}));
  return(1);
}

sub can_equip { my ($self, $wearer) = @_; return(1); }
sub can_unequip { my ($self, $wearer) = @_; return(!$self->{'!DISARM'}); }

sub item_hwear {
  my ($self, $item, $quiet) = @_;
  ## Check if we're already wearing that ITEM.
  if(($self->{'APRL'}->[$self->{$item->{'ATYPE'}}] eq $item) || ($self->{'WEAPON'} == $item->{'OBJID'})) { $self->log_append("But you're already using that item!\n"); return(0);  }
  ## If it's raceonly then keel'em.
  if( $item->{'RACEONLY'} && ( index($item->{'RACEONLY'}.' ', ($self->{'RACE'}*1).' ') == -1 ) ) { $self->log_append("{3}Your race is unable to wear $item->{'NAME'}.\n"); return (0); }
  ## Check if we're already wearing an item of that type. print "I know that i'm wearing one.\n";
  if("$self->{$item->{'ATYPE'}}" ne "") {  if(!$self->item_hremove($self->{'APRL'}->[$self->{$item->{'ATYPE'}}])) { return(0); } print "remove successful.\n"; }

  unless ($self->has_minstats($item->{'EQUIP_MINSTATS'})) {
      $self->log_error("You don't feel skilled enough to wear $item->{'NAME'}, you must have $item->{'EQUIP_MINSTATS'}");
	  return 0;
  }

  ## Check if we can't wear that item.
  if(!($item->can_wear($self) && $item->{'ATYPE'})) { $self->log_append("{3}You cannot wear $item->{'NAME'}.\n"); return(0); }
  ## add item to apparel
  $self->apparel_add($item);
  ## tell item that it's being worn
  $item->{'WORN'}=1;
  $self->apparel_update;
  if(!$quiet) { 
     $self->log_append("{2}You wear {4}".$item->{'NAME'}."{2}.\n");
     $self->room_sighttell(sprintf("{2}%s wears {4}%s{2}.\n", $self->{'NAME'}, $item->{'NAME'}));
  }
  return(1);
}

sub item_hremove {
  my ($self, $item, $quiet) = @_;
  if(!$item) { return(1); } # no item passed, success.
  ## Check if we're not wearing that item.
  if(!$item->{'WORN'}) { 
     if($self->{'WEAPON'} == $item->{'OBJID'}) {
        return $self->item_hunequip;
     } else {
        $self->log_append("{3}You are not wearing $item->{'NAME'}.\n"); return(0);
     }
  }
  ## Check if we can't remove that item.
  if(!$item->can_remove) { $self->log_append("{3}You cannot remove $item->{'NAME'}.\n"); return(0); }
  ## otherwise we can remove it
  delete $item->{'WORN'};
  $self->apparel_remove($item);
  $self->apparel_update;
  if(!$quiet) { 
     $self->log_append("{2}You remove {4}".$item->{'NAME'}."{2}.\n");
     $self->room_sighttell(sprintf("{2}%s removes {4}%s{2}.\n", $self->{'NAME'}, $item->{'NAME'}));
  }
  return(1);
}

sub can_wear { my $self = shift; my $wearer = shift; return(1); }
sub can_remove { my $self = shift; return(1); }


sub apparel_add {
  my ($self, $item) = @_;
  push(@{$self->{'APRL'}}, $item);
  $self->{$item->{'ATYPE'}}=$#{$self->{'APRL'}};
  return;
}

sub apparel_remove {
  # removes item from apparel inventory
  my ($self, $item) = @_;
  my ($n, $maxn, $obj);
  $maxn = $#{$self->{'APRL'}};
  for ($n=0; $n<=$maxn; $n++) {
    if ($self->{'APRL'}->[$n] eq $item) { undef($self->{'APRL'}->[$n]); }
  }
  delete $self->{$item->{'ATYPE'}};
  return;
}

sub apparel_update {
  # updates apparel values (weapon/clothes)
  my ($self, $i, $n) = shift;
  ## Clean up apparel array
  if(defined(@{$self->{'APRL'}})) { $self->arr_rotate(\@{$self->{'APRL'}}); }
  $n=0; foreach $i (@{$self->{'APRL'}}) { $self->{$i->{'ATYPE'}}=$n; $n++; } # relink
  return;
}

sub arr_rotate(\@array) {
 # "rotates" an array to clear out all undef fields
 my ($self, $a) = @_; my ($val, @b);
 foreach $val (@{$a}) {
  if ($val) { push (@b, $val); }
 }
 @{$a} = @b;
 return;
}

sub obj_genhandle {
 # handles generic command
 my ($self, $command, $iname) = (@_); $command = lc($command);
 if(!$main::cmdbase_obj->{$command}) { return(0); }
 if(!$iname) { $self->log_append("{3}You've got to decide on something to $command.\n"); return(0); }
 my ($success, $item) = $self->inv_cgetobj($iname, -1, $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs);
 if($success == 1) { 
    &{$main::cmdbase_obj->{$command}}($item, $self);
    #$self->room_tell('{7}'.$self->{'NAME'}.' {05}'.$command.'s {7}'.$item->{'NAME'}.".\n");
    return(1);
 } elsif ($success == 0) { $self->log_append("{3}You don't see any $iname to $command.\n"); return(0); }
 elsif ($success == -1) { $self->log_append($item); return(0); }
 return (1);
}

sub action_do {
    my ($self, $action, $iname) = @_;
    $action = lc($action);
    my ($x, $maxbasenum, $basenum, @abase);
    return if(!$self->can_do(0,0,0));
    $basenum = $main::amap->{$action};
    $maxbasenum = $basenum + 6;
    for($x = $basenum; $x <= $maxbasenum; $x++) {
        push(@abase,$main::gestures[$x]);
    }
    my $sname = ($self->{'NICK'} || $self->{'NAME'});
    map {
        s/\%PS/$self->{'PRO'}/g;
        s/\%HS/$self->{'PPOS'}/g;
        s/\%MS/$self->{'PPRO'}/g;
        s/\%S/\{16\}$sname\{2\}/g;
    } @abase;


    if(!$iname) {
        $self->log_append('{2}'.$abase[0]."\n");
        $self->room_talktell('{2}'.$abase[1]."\n");
    } elsif(lc($iname) eq 'all') {
        $self->log_append('{2}'.$abase[5]."\n");
        $self->room_talktell('{2}'.$abase[6]."\n");
    } else { 
	my $container = $main::objs->{$self->{'CONTAINEDBY'}};
        my ($success, $item) = $self->inv_cgetobj($iname, -1, ($container->{'TYPE'} == -1?undef:$container), $main::objs->{$self->{'CONTAINEDBY'}}->inv_objs, $self->inv_objs);
        if ($success == 1) { 
            if (defined($item->{'IGNORE'}->{$self->{'NAME'}})) {
                $self->log_error("..but $item->{'NAME'} is ignoring you, so what would it matter?");
                return 0;
            }
            my $rname = ($item->{'NICK'} || $item->{'NAME'});
            map {
                s/\%PR/$item->{'PRO'}/g;
                s/\%HR/$item->{'PPOS'}/g;
                s/\%MR/$item->{'PPRO'}/g;
                s/\%R/\{16\}$rname\{2\}/g;
            } @abase;
            $self->log_append('{2}'.$abase[2]."\n");
            $self->room_talktell('{2}'.$abase[4]."\n", undef, $item);
            $item->log_append('{2}'.$abase[3]."\n");

        } elsif ($success == 0) {
            $self->log_error("You don't see any $iname to $action.");
            return 0;
        } elsif ($success == -1) {
            $self->log_append($item);
            return 0;
        }
    }


    $self->room->on_action($self, $action, $iname);

    return (1);
}

sub on_action {
    my ($self, $who, $action_name, $target_name) = @_;
}

sub commify {
  $_ = shift;
  1 while s/^(-?\d+)(\d{3})/$1,$2/;
  return($_);
}

sub bodypart_drop ( [bodypart type] ) {
  # Drops a body part of $bodypart_type from self.
  # if $killer passed, notes that the killer was $killer.
  
  my ($self, $bodypart_type, $killer) = @_;
  
  
  if(!$bodypart_type && rand(10) < 9 &&
      !( $self->{'TYPE'}==1 && $main::bounties{lc($self->{'NAME'})} )
	) { return; }
  
  my ($obj, $div, $n); 
  if(!$bodypart_type) {   $bodypart_type = $main::bodyparts[int rand($#main::bodyparts+1)];  }
  $obj = bodypart->new;
  $div = $#main::bodyparts+1;
  $obj->{'NAME'}=$bodypart_type.' of '.lc($self->{'NAME'});
  $obj->{'BPART'}=$bodypart_type;
  $obj->{'CRTRREC'} = $self->{'REC'}; # the death guy createdi it
  $obj->{'ROT'}=time+(60*1);
  $obj->{'HP'} = $obj->{'MAXH'} = (int ($self->{'MAXH'}/$div));
  for (my $n=0; $n<=22; $n++) { $obj->{'EXP'}->[$n] = int ($self->{'EXP'}->[$n] / $div) + 2; } # so we dont get LOG errors later on
  $obj->stats_update;
  ## ADD BOUNTY CODE
  if (($self->{'TYPE'}==1) && ($main::bounties{lc($self->{'NAME'})})) {
    $obj->{'BOUNTYCODE'}=$self->bounty_codeget;
    $obj->{'BOUNTYFROM'}=$self->{'NAME'};
    if($killer) { $obj->{'BOUNTYKILLEDBY'}=lc($killer->{'NAME'}); }
  }
  
  $main::map->[$self->{'ROOM'}]->inv_add($obj);
  $self->room_sighttell("{4}A salvagable {11}".$obj->{'NAME'}."{4} falls to the ground with a splat!\n");
  return($obj);
}

sub stats_add (...list of objects to add stats from...) {
  # makes stats like object.
  my $self = shift;
  my $obj;
  while(@_) {
     $obj = shift;
     for (my $n=0; $n<=22; $n++) { $self->{'EXP'}->[$n] += $obj->{'EXP'}->[$n]; } 
     $self->{'HP'} += $obj->{'HP'}; $self->{'MAXH'} += $obj->{'MAXH'};
  }
  $self->stats_update;
  return;
}

sub objs_meld_into {
  # adds stats of args to self, deletes objects.
  my $self = shift;
  $self->stats_add(@_);
  while(@_) { shift(@_)->obj_dissolve; }
  return($self);
}

sub make_stats_like {
  # makes stats like object.
  my ($self, $obj) = @_;
  @{$self->{'EXP'}} = @{$obj->{'EXP'}}; 
  @{$self->{'STAT'}} = @{$obj->{'STAT'}};
  $self->{'HP'} = $obj->{'HP'};
  $self->{'MAXH'} = $obj->{'MAXH'};
  return;
}

sub desc_hard {
  my $self=shift;
  
  my $desc = '';
  
  if (defined $self->{'GRAFFITI'}) { $desc = $self->{'GRAFFITI'}; }
  elsif (ref($self->{'DESC'})) { $desc = ${$self->{'DESC'}}; }
  else { $desc = $self->{'DESC'}; }

  if ($main::world_of_khaki) {
      if (!$desc) {
          $desc = "No description available, but I bet it's made of khaki!";
      } else {
          $desc .= " {17}**** {16}(AND IT'S MADE OF KHAKI!!) {17}****";
      }
  }
  
  return $desc;
}

sub make_zombie {
  # makes self a zombie (only do this if i'm a body part, please)
  my ($self, $leader) = @_;
  
  # make, set up zombie.
  my $zombie = zombie->new;
  $zombie->make_stats_like($self);
  $zombie->{'HP'}++; $zombie->{'MAXH'}++; # just in case.
  $zombie->stats_update;
  
  if($zombie->{'LEV'} < 10) { $zombie->{'NAME'}='Flesh Assembly'; }
  elsif($zombie->{'LEV'} < 40) { $zombie->{'NAME'}='Flesh Zombie'; }
  elsif($zombie->{'LEV'} < 80) { $zombie->{'NAME'}='Flesh Golem'; }
  else { $zombie->{'NAME'}='Flesh Monstrosity'; }

  $zombie->{'AID'}=$leader->{'OBJID'};
  $zombie->{'STALKING'}=$leader->{'OBJID'};
  $zombie->{'KEXP'}=1; $zombie->{'RACE'}=$leader->{'RACE'};
  &obj_lookup($self->{'CONTAINEDBY'})->inv_add($zombie);

  $self->room_sighttell('{2}The '.$self->{'NAME'}." comes to life as a $zombie->{'NAME'}.\n");

  $self->obj_dissolve;
  return;
}

sub objid_change {
  my ($self, $newid) = @_;
  $newid = int $newid;
  # changes my object id to something new.
  # NOTE: Do not use this unless you know what you're doing.
  # Many objects use objid refs that will not be changed, including {'AID'}, {'STALKING'}, and
  # even the INV stuff if that ever changes.
  if(defined($main::objs->{$newid})) { &failure("Tried to change objid of $self->{'OBJID'} to $newid, but it already existed."); return; }
  delete($main::objs->{$self->{'OBJID'}});
  $main::objs->{$newid}=$self;
  $self->{'OBJID'}=$newid;
  return;
}

sub cmd_do {
  my $t0 = new Benchmark; ### BMARK
  my ($player, $cap, $sockno, @cap) = @_;
  my ($bad_com, $staticcap);
  $main::process_num++;
  
  if(defined($player->{'IGNORECMDS'})) { return; }
  
  if(!$player->{'ADMIN'}) { $cap = substr($cap, 0, 80*8); }
  
  if($player->{'@LCTI'} == time && $player->{'TYPE'} == 1) { 
    $player->{'@LCTC'}++;
    if( ($player->{'@LCTC'}>6) &&
        (!$player->{'GAME'} || $player->{'@LCTC'} > 10) 
       ) { # && (!$player->{'ADMIN'})
         $player->log_append("{1}*** SPAMMING IS EVIL\n"); 
         &main::rock_shout(undef, "{1}Spamaroonie! ($player->{'NAME'} at $player->{'IP'})\n", 1); 
         $main::spamwatch{$player->{'IP'}}++;
         if($main::spamwatch{$player->{'IP'}} >= 10) { 
           push(@main::banlist, $player->{'IP'});
           &main::mail_send($main::rock_admin_email, "R2: BAN! (SPAM!) $player->{'IP'}", "Banning $player->{'IP'} for spamming! ($player->{'NAME'} said ".quotemeta($cap).").\n", $player->{'EMAIL'});
           &main::rock_shout(undef, "{17}ATTENTION ROCK PATRONS!\n{1} The following IP has been banned due to multiple spamming attempts: {17}$player->{'IP'}.\n");
         }
         if($sockno) { 
             $main::qkillonsend[$sockno]=1;
             #             $player->{'IGNORECMDS'}=1;
         } else {
             $cap='x';
         }
    }
  } else { delete $player->{'@LCTC'}; }
  
  delete $player->{'AFK'};
  
  print "Cmd ($player->{'NAME'}): [$cap]\n";
  
  if($main::no_cmds_allowed && !$player->{'ADMIN'}) {
      $player->log_append("{17}SORRY, but an admin has temporarily disabled the ability to type commands.\n");
      return;
  
  }
  
  if($player->{'CMD_WATCH'}) { my $debcap = $cap; $debcap =~ s/([^ -~])/sprintf("%%%x",ord($1))/eg; &main::rock_shout(undef, "{16}>{6}> {7}Cmd ({17}$player->{'NAME'}\{7}): {12}[$debcap]\n", 1); }
  unshift(@main::lcom, &main::time_get(0).": {4}$player->{'NAME'}: {17}$cap");
  while($#main::lcom > 80) { pop(@main::lcom); }
  $cap =~ tr/a-zA-Z0-9 \^\~\>\<\.\;\,\:\(\)\{\}\-\|\=\%\'\?\*\;\#\$\@\"\&\!\+\_\[\]\\\///cds;
    
  if ($cap eq '=') { $cap = $player->{'LCOM'}; @cap = split (/ /,$cap); }
  elsif (index($cap,'-') == 0) { $cap = substr($cap,1).$player->{'LCOM'}; @cap = split (/ /,$cap); }
  elsif (index($cap,'+') == 0) { $cap = $player->{'LCOM'}.substr($cap,1); @cap = split (/ /,$cap); }
  
  $cap = &main::rm_whitespace($cap);
  if($player->{'TYPE'}==1) {
      $main::activeusers->{$player->{'OBJID'}}=time;
      $main::iop{$player->{'NAME'}}.=time()."{17}Command: $cap\n";
  }
  
  my $original_cap = $cap; # keep it pure
  
  @cap = split (/ /,$cap);
  $cap[0] =~ tr/a-zA-Z\@\///cds; ### MUST WEED OUT ALL a-z
  $staticcap = $cap[0] = lc($cap[0]);
  
  # handle command aliases
  if($player->{'ST8'}) { }
  elsif ($main::cmdbase_ali->{lc($cap)}) { $cap = $cap[0] = $main::cmdbase_ali->{lc($cap)}; }
  elsif ($main::cmdbase_ali->{$cap[0]}) {
      $cap = $main::cmdbase_ali->{shift(@cap)}.' '.join(' ',@cap);
      @cap = split (/ /,$cap);
  } 
  
  my $triedsoundex=0;
  SWITCH: # eventually maybe split these up between arg'd ones and non-arg'd for efficiency
  for($cap[0]) {
      ($player->{'ST8'}) && do { $player->interp_st_command($cap, $sockno); $bad_com=1; last SWITCH; };
      # note: $main::activeusers->{$player->{'OBJID'}} is the time.
      ($player->{'BAN'} > $main::activeusers->{$player->{'OBJID'}}) && do { $player->logout($sockno); $bad_com=1; last SWITCH; };
#      ($main::dirlongmap{uc($cap)}) && do { $player->realm_move($cap[0], 1); last SWITCH; };
      ($main::dirlongmap{uc($_)}) && do { $player->realm_move($cap[0], 1); last SWITCH; };
      ($main::cmdbase_sing->{lc($cap)}) && do { shift(@cap); &{$main::cmdbase_sing->{lc($cap)}} ($player); last SWITCH; };
      ($main::cmdbase_mult->{$_}) && do { shift(@cap); &{$main::cmdbase_mult->{$_}} ($player, join(' ',@cap)); last SWITCH; };
      ($main::cmdbase_obj->{$_}) && do { shift(@cap); $player->obj_genhandle($_, join(' ',@cap)); last SWITCH; };
      (defined $main::amap->{$_}) && do { shift(@cap); $player->action_do($_, join(' ',@cap)); last SWITCH; };
#      ($_ eq 'raise')  && do { $player->pstat_raise($cap[1], $cap[2]); last SWITCH; };
      ($player->{'ADMIN'}==1) && 
       (
        ( ($main::adminbase_mult->{$_}) && do { shift(@cap); &{$main::adminbase_mult->{$_}} ($player, join(' ',@cap)); last SWITCH; } )
          ||
        ( ($main::adminbase_sing->{lc($cap)}) && do { shift(@cap); &{$main::adminbase_sing->{lc($cap)}} ($player); last SWITCH; } )
     #     || 
     #   ( $_ eq 'ch' && defined($sockno) && do { &main::rock_change_obj($sockno, $cap[1]); last SWITCH; } )
       ) ;
      $_ eq 'ch' && defined($sockno) && $player->{'CANMORPH'} && do { &main::rock_change_obj($sockno, $cap[1]); last SWITCH; };
      $_ eq 'emu' && defined($sockno) && $player->{'AMB-EMU'} && defined($main::objs->{$cap[1]}) && $main::objs->{$cap[1]}->{'AMB-EMU'} && $main::objs->{$cap[1]}->{'TYPE'}!=1 && do { &main::rock_change_obj($sockno, $cap[1]); last SWITCH; };
      $cap eq 'x' && do { $player->logout($sockno); last SWITCH; };
      $cap ne '' && $player->pref_get('auto talk') && do { $player->say($original_cap); $bad_com=1; last SWITCH; };
      $_ ne '' && do { 
          my $soundex;
          if($player->pref_get('auto talk') || $triedsoundex || !$cap[0] || !defined($main::snd_to_cmd{$soundex = &main::soundex($cap[0])}) ) {
               $player->log_append("Unknown command: [$original_cap]\n"); $bad_com=1; last SWITCH;
          } else {
               $cap[0] =  $main::snd_to_cmd{$soundex};
               $triedsoundex=1;
               goto SWITCH;
          }
      };
      (!$player->{'WEBACTIVE'}) && $player->room_log;
  }
  
  if($player->pref_get('double newlines')) { $player->log_append("\n"); }
  $player->{'LCOM'}=$original_cap;  ## Store player's last command
  my $t1 = new Benchmark; my $td = &main::timediff($t1, $t0);
  #print "rock_handle took: ",timestr($td),"\n";
  $player->{'CPU'} +=  (int ($td->cpu_p*1000))/1000;
  $player->{'TOTAL_COMMANDS'} = $player->{'TOTAL_COMMANDS'} + 1;
 # print ('CPU: ',$td->cpu_p,"\n");  
 $main::cmd_time{$staticcap}+=$td->cpu_p; $main::cmd_tick{$staticcap}+=1;  #$main::cmd_bash{lc($cap)}++;
  if(!$bad_com) { $main::rock_stats{'cmds'}++; $main::totalcommands++; } elsif(!$player->pref_get('auto talk')) {  }

  #&main::scan_crappy_objects;
  $player->{'@LCTI'} = time;
#  if(defined($main::objs->{""})) { 
#     $main::msg_friend->msg_send('plat', '{1}---{11}> {6}'."{1}Null string object appeared after:\n{16}User: $player->{'NAME'}.\n{1}Null string value set to: ".$main::objs->{""}."\n{17}Command: $cap.\n",
#       '{15}Message From {17}ROCK: {16}Crashed Plane{2} {12}'.&main::time_get(time));
#     delete $main::objs->{""};
#  }
  if($player->{'@BUGFRIEND'}) {
    $player->inv_scan("Bugfriend");
  }  

}

sub logout { # not to be confused with rockobj2.pm's obj_logout 
    my ($self, $sockno) = @_;
    
    if ($self->canLogoutOnTelDiscon()) {  
       if($sockno ne undef) { 
           # Disconnect the telnetter
           $main::qkillonsend[$sockno]=1;
       } else { 
           # Disconnect the webbie
           $main::activeusers->{$self->{'OBJID'}}=1; $main::donow .= '&main::rem_inactive_users;';
       }
       
       $self->log_append("{17}Bubbye! We'll miss you! Come back soon! Send a postcard!\n"); 
     }
    
    # need something like "If user is spewing, then: " .. $self->log_append("{17}Bubbye! We'll miss you! Come back soon! Send a postcard!\n");
    # otherwise dont..
    return;
}

sub interp_st_command($command, [$sockno]) {
    # interprets state command.
    my ($self, $cmd, $sockno) = @_;
    my ($sname, $sline, $continue, $temp, $cap) = ($self->{ST8}->[0], $self->{ST8}->[1], 1, \%{$self->{'TEMP'}});
    while($continue) { $continue=0; eval($main::state->{$sname}->[$sline]); if($@) { print "ST8 ERROR ($self->{'NAME'}, $cmd, $sname, line $sline): $@\n"; &main::rock_shout(undef, "ST8 ERROR ($self->{'NAME'}, $cmd, $sname, line $sline): $@\n", 1); } } 
    ($self->{ST8}->[0], $self->{ST8}->[1]) = ($sname, $sline);
    if((!$main::state->{$sname}) || (!$main::state->{$sname}->[$sline])) { delete $self->{'ST8'}; delete $self->{'TEMP'}; }
    $self->log_append($cap);
    return;
}

sub got_lucky {
   # returns 'true' if user got lucky or false if not.
   # the random part picks a number from 0 -> 100. It may pick 101 as well but there is a hugely-low chance of it.
   my ($self, $mod) = @_;
   $mod = 1 unless $mod;
   if ( (int rand(101)) < ($self->{'LUCK'}/$mod) ) { return(1); }
   else { return(0); }
}

sub power_up {
  my ($self, $pct) = @_;
  $pct=100 unless $pct;
  $self->{'HP'}=int ($self->{'MAXH'}*$pct/100);
  $self->{'MA'}=int ($self->{'MAXM'}*$pct/100);
  return;
}

sub gift_turns {
   # the old rock routine was called 'gift_turns' as well. the name is just so
   # that i can remember what i'm doing :-).
   my $self = shift;
}

sub is_tired {
   my $self = shift;
   return 0 if $self->{'ADMIN'} && $self->{'NOTIRED'};
   return 0 if $self->{'NOTIRED'};
   #if($self->{'WEBACTIVE'}) { return(0); } # users dont get tired via web
   if ( ( ( ($_ = (time - $self->{'TRD'})) < 1)   ||  ($self->{'P_ID'} == $main::process_num) ) && $_ < 120 ) { return(1); }
   else { return(0); }
   return;
}

sub make_tired { $_[0]->{'P_ID'} = $main::process_num; $_[0]->{'TRD'}=time + $_[1]; return; }

sub help_get {
  my ($self, $topic) = @_;
  $topic = uc($topic);
  my $soundex;


  if (!$topic) {
    #if($self){ $self->help_log; }
    if($self) { $self->log_append('{40}'.$main::help->{'TOPICS'}.'{41}'); }
    return($main::help->{'TOPICS'});
  }


  if ($main::cmdbase_ali->{lc($topic)}) { $topic = uc($main::cmdbase_ali->{lc($topic)}); }
  elsif (!defined($main::help->{uc($topic)}) && defined($main::snd_to_cmd{$soundex = &main::soundex(lc($topic))})) { $topic = uc($main::snd_to_cmd{$soundex}); }







  if($main::help->{uc($topic)}) {
    if(uc($topic) eq 'RULES') { $self->pref_toggle('read rules', 1, 1); }

    if($self){ $self->log_append('{40}'.$main::help->{uc($topic)}.'{41}'); } else { return($main::help->{uc($topic)}); }

  } else {
    if($self){ $self->log_append('{13}Sorry, no help available for that topic ({1}'.$topic.'{13})'."\n"); }
    else { return('{13}Sorry, no help available for that topic ({1}'.$topic.'{13})'."\n"); }
  }

  return;
}

sub on_drink { return; }
sub on_buy { return; } # executed when object is bought.

sub on_wind { $_[1]->log_append("You can't wind that!\n"); return; }

sub on_use_on {
   # Called when someone opts to use <$item> on me ($self).
   # If I want to ignore the ability to have the item used on me,
   # return 0.
   #
   # Otherwise, do your fun stuff and return 1.
   #
   # *** CALLED BEFORE on_use IS CALLED ***
   
   # my ($self, $user, $item_used_on);
   return 0; # does nothing by defualt
}

sub on_use { 
  # Called when a player decides to "use <itemname> [on <targetname>].
  #
  # $user is the object of the person USING the item.
  # $self is the item being used
  # $opt_target is the object that I am being used on; THIS MAY BE UNDEF!!
  
  my ($self, $user, $opt_target) = @_;
  if($self->{'USEFX'}) { 
      if($opt_target) {
          $opt_target->log_append("{17}$user->{'NAME'} {7}uses {17}$self->{'NAME'} {7}on you.\n");
          $user->log_append("{7}You use the $self->{'NAME'} on $opt_target->{'NAME'}.\n");
          $user->room_sighttell("{17}$user->{'NAME'} {7}uses $self->{'NAME'} on {17}$opt_target->{'NAME'}.\n", $opt_target);
      } else {
          $user->log_append("{7}You use the $self->{'NAME'} on yourself.\n");
          $user->room_sighttell("{17}$user->{'NAME'} {7}uses $self->{'NAME'} on $user->{'PPRO'}self.\n");
      }
      
      ($opt_target || $user)->effect_add($self->{'USEFX'});
      if($self->{'USES'} <= 0 || !(--$self->{'USES'})) { $user->log_append("{7}The $self->{'NAME'} disappears.\n"); $self->obj_dissolve(); }
  } else {  $user->log_error("You can't use that!"); }
  return;
}

sub tempinv_objs {
   # Returns array of objects in inventory.
   my $self = shift;
   if(defined($self->{'TEMPINV'}) && (ref($self->{'TEMPINV'}) eq 'HASH')) { return(values(%{$self->{'TEMPINV'}})); }
   else { return(undef); }
}

 #old objdump
 #foreach $key (keys(%{$self})) { $image->{$key}=$self->{$key}; }
 #bless ($image, ref($self));
 # so, now that $image is similar to $self, i can get rid of the inconsistant obj refs.
 # delete $image->{'INV'}; delete $image->{'APRL'}; delete $image->{'WEAPON'};
 #delete $image->{'OBJID'}; # we'll be changing the objid next time, best not confuse anyone.
 # $image->{'ROOM'}=1; # put'em in creation room, just in case.


sub obj_dump {
   my ($self, $logoff) = @_;
   my ($key, $name);
   if($self->{'TYPE'} != 1) { return; }
   
   # pull cert stuff
   my $cert_msgs;
   $cert_msgs = $self->oracle_cert_poll();

   # save static_id
   $self->{'STATIC_ID'} = $main::map->[$self->{'ROOM'}]->{'STATIC_ID'};
   my ($o);
   
   # If I have a unique item, lay claim to it!
   foreach $o ($self->inv_objs, $self->stk_objs, $self->tempinv_objs) {
       if($o->{'UNIQUE'}) {
           $main::obj_unique{$o->{'REC'}}=lc($self->{'NAME'});
       }
   }
   
   $self->{'LASTSEEN'}=time;
   my ($r2dump);
   delete $self->{'WEBACTIVE'}; 
   my $nameChanged;
   # handle name changes
   if($self->{'NAME_CHANGE'} && $logoff) { 
      # remove current char
      unlink(&main::insure_filename('./saved/'.lc($self->{'NAME'}.'.r2')));
      my $dbh = rockdb::db_get_conn();
          my $sth = $dbh->prepare("UPDATE $main::db_name\.r2_PLAYERS SET NAME='$self->{'NAME_CHANGE'}\' WHERE NAME='$self->{'NAME'}\'");
          $sth->execute();
      $self->{'NAME'} = $self->{'NAME_CHANGE'};
      delete $self->{'NAME_CHANGE'};
      $nameChanged=1;
   }
   
   if($self->{'DWEAP'} && ($main::objs->{$self->{'DWEAP'}}) ) { 
       $r2dump = Data::Dumper->new([$self, &rockobj::obj_lookup($self->{'DWEAP'})], [qw(self dweap)]);
   } else { $r2dump = Data::Dumper->new([$self], [qw(self)]); }
   $r2dump->Indent(1); $r2dump->Purity(1);
   open (WFILE, '>'.&main::insure_filename('./saved/'.lc($self->{'NAME'}.'.r2'))) || die "Cannot open objdump file: $!\n";
   print WFILE $r2dump->Dumpxs . "\n\n1;"; close(WFILE);
   
   
   if($self->pref_get('verbose messages')) { $self->log_append("{1}## {17}saved your character {1}##\n"); }
   
   if($nameChanged) { 
        &main::update_uidmap;
   }
   
   # Then update our stats..
   $self->sql_update_stats(); ## DO I CARE??
   
   # Lastly, if we should delete the character upon logout, and we're logging out, let's
   # unlink that player file! Scary eh?
   if ($logoff && $self->{'DELETE_CHARACTER_UPON_LOGOUT'}) { 
      my $dbh = rockdb::db_get_conn();
      my $sth = $dbh->prepare("DELETE FROM $main::db_name\.r2_PLAYERS WHERE NAME='$self->{'NAME'}\'");
      $sth->execute();
      unlink(&main::insure_filename('./saved/'.lc($self->{'NAME'}.'.r2')));
# Doens't look like this is sent anyway
#      $self->log_append("{17}########   YOUR CHARACTER HAS BEEN DELETED   #########\n");
#      $self->log_append("{17}########  YOU WILL NEED TO CREATE A NEW ONE  #########\n");
   }
   return($self);
}

sub pct_skill (statnumber [,modifier]) {
  # returns the percent of skill, based solely on skill..
  #return (int ( 100*(1 + ($_[2] || 20)*(-$_[0]->{'STAT'}->[$_[1]]-1)**(-1)) ));
  return ( (100*(1 + ((-(1/($_[2] || 35)*$_[0]->{'STAT'}->[$_[1]])-1)**-1))) );
}

sub fuzz_pct_skill (statnumber [,modifier]) {
  # returns the percent of skill, based solely on skill.. (value from 0 to 1)
  return ( ((1 + ((-(1/($_[2] || 35)*$_[0]->{'STAT'}->[$_[1]])-1)**-1))) );
}

sub pct_levskill (modifier) {
  # returns skill percent, based on level.
  return( int 100 * (1+(-((1/($_[1] || 35))*shift->{'LEV'})-1)**(-1)) );
}

sub pct_statgood (statnumber) {
  # compares stat to level and returns how good it is
  my $self = shift;
  return( int ( 100 * ($self->{'STAT'}->[shift] / $self->{'LEV'}) ) );
}

sub pct_integrate {
  # incorporates all stats passed to it, returns percent chance of success.
  my ($self, $modif) = (shift, shift);
  my ($stat, $pct);
  foreach $stat (@_) { $pct += $self->pct_statgood($stat); }
  $pct += $self->pct_levskill;
  $pct = int ($pct/($#_ + 2));
  return($pct);
}

#mich function
# i am retarded
sub is_stat_good
{
    #returns true or false whether the stat is "good" or not based on level, stat to level ratio, and modifier
    my ($self, $stat, $mod) = @_;
    my $ratio = $self->{'STAT'}->[$stat] / $self->{'LEV'};
    return $ratio * $self->{'STAT'}->[$stat] > rand($mod / $ratio);
}
#end mich function

sub un_portalize {
	my $self = shift;
	
	# removes self from the portal arrays and cleans it up.
	if((!$self->{'PORTAL'}) || (!defined(@{$main::portals->{$self->{'PORTAL'}}})) ) { return; }
	
	my ($p, @a);
	foreach $p (@{$main::portals->{$self->{'PORTAL'}}}) {
	    if($p != $self->{'OBJID'}) { push (@a, $p); }
	}
	
	@{$main::portals->{$self->{'PORTAL'}}} = @a;
	return;
}

sub on_enter {
  # when a player enters the object..routes them via portal.
  my ($self, $obj) = @_;
  if($obj->{'SENT'}) { $obj->log_append("I am sentinal. I do not enter portals.\n"); return; }
  if(!$self->{'PORTAL'} || $self->{'NOENTER'}) {
     $obj->log_error('You cannot enter that!');
     return;
  } else {
     my (@outlets, $oid);
     if (!defined(@{$main::portals->{$self->{'PORTAL'}}})) {
        &main::rock_shout(undef, "{2}OUT OF SERVICE! OBJID $self->{'OBJID'}!! {17}Player: $obj->{'NAME'}!\n", 1);
        $obj->log_append("{2}That portal is currently out of service!\n");
        return;
     }
     @outlets = @{$main::portals->{$self->{'PORTAL'}}};

     # process outlet listing to remove me, and remove the ones that have NOEXIT set to 1
     @outlets = grep { my $obj = &main::obj_lookup($_); !$obj->{'NOEXIT'} && $obj ne $self } @outlets;

     if (!$obj->can_do(0,0,3)) { return; }
     if ($obj->{'ADMIN'}) { $obj->log_append("{1}Outlets are [@outlets].\n"); }
     if (@outlets <= 0) { $obj->log_append("{2}That portal is currently out of service!\n"); return; }
     else {
         # keep picking an exit until it's not the one the user entered from
         $oid = $outlets[(int rand($#outlets+1))];
         if( ($obj->{'TYPE'} == 2) && $main::map->[$main::objs->{$oid}->{'ROOM'}]->{'NOMOB'} ){ $obj->log_append("{2}No mobs allowed.\n"); return; }
         $obj->log_append('{2}You enter the {15}'.$self->{'NAME'}."{2}.\n");
         if(!$obj->is_invis()) {
            $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'}).'{2} enters the {15}'.$self->{'NAME'}."{2}.\n");
         }
         if( $obj->realm_hmove($obj->{'ROOM'}, &rockobj::obj_lookup($oid)->{'ROOM'}, 'enter '.$self->{'NAME'}, 1) ) {
           if(!$obj->is_invis()) { 
             $obj->room_sighttell('{14}'.($obj->{'NICK'} || $obj->{'NAME'}).'{2} emerges from the {15}'.&rockobj::obj_lookup($oid)->{'NAME'}."{2}.\n");
           }
           $main::map->[&rockobj::obj_lookup($oid)->{'ROOM'}]->tell(4, 1, 0, undef, $obj, 'enter '.&rockobj::obj_lookup($oid)->{'NAME'});
         }
     }
  }
  return 1;
}

sub can_enter (roomid) {1;}
sub can_exit (roomid) {1;}

sub db_spawn {
 # spawns item from db.
 if($_[0]->{'DB'}) { return $_[0]->db_hspawn(int ($_[0]->{'DB'})); } return;
}

sub db_hspawn ($) {
    # spawns an item from db into self.
    # note that it does not do all the formalities of notification.
    my ($self, $db) = @_;
    if ( (!$self->inv_free) ||
        ($self->{'SGORMAX'} && ($self->{'GOR'} > $self->{'SGORMAX'})) ||
        (!defined($main::db->[$db]))
       ) { return undef; }
    return $self->item_spawn( $main::db->[$db]->[int(1+rand($#{$main::db->[$db]}))] );
}

sub rot {
  # the standard rot rots the item away..
  my $self = shift;
  if($main::objs->{$self->{'CONTAINEDBY'}}->{'TYPE'}==-1) {
      $self->room_sighttell("{3}$self->{'NAME'} decays into the ether.\n");
  } elsif($main::objs->{$self->{'CONTAINEDBY'}} && $main::objs->{$self->{'CONTAINEDBY'}}->{'NAME'}) { 
      $main::objs->{$self->{'CONTAINEDBY'}}->log_append("{3}$self->{'NAME'} decays into the ether.\n");
  } #print "decaying object's container object is: $main::objs->{$self->{'CONTAINEDBY'}} ($self->{'CONTAINEDBY'})\n"; 
  else { &failure("$self->{'NAME'} ($self->{'OBJID'})'s containedby is/was $self->{'CONTAINEDBY'}\n"); }
  $self->obj_dissolve;
  return;
}

sub on_cleanup {}

sub effect_has {
    # returns 1 if user has all FX's passed; else 0
    my $self = shift;
    while (@_) {
        $_ = shift(@_);
        if (!$self->{'FX'}->{$_} || $self->{'FX'}->{$_} <= time) {
            delete $self->{'FX'}->{$_};
            return 0;
        }
    }
    return 1;
}

sub effect_end_all {
    my $self = shift;
	foreach my $key (%{$self->{'FX'}}) {
	    $self->{'FX'}->{$key} = 0;
	}
    $self->effects_update();
}

sub effect_del {
    # properly deletes effect(s) from self.
    my $self = shift;
    while(@_) {
       my $effect = shift;
       delete $self->{'FX'}->{$effect};
       $self->effects_register();
    }
}

sub effect_add (effect number) {
    # adds effect to self.
    my $self = shift;
    my $etime;
    while (@_) { 
        if($main::effectbase->[$_[0]]) { 
            # handle code references, if applicable
            $etime = $main::effectbase->[$_[0]]->[3];
            if(ref($etime) eq 'CODE') {
                $etime = &{$etime}($self);
            }
        
            if ($self->{'FX'}->{$_[0]} > time) { 
                # EXTEND EFFECT
                # add decay time to effect information
                $self->{'FX'}->{$_[0]} += $etime;
            } else {
                # [NEW] REGISTER EFFECT
                # config FX
                $self->{'FX'}->{$_[0]} = time + $etime;
        
                # notify player of new effect
                $self->log_append("{13}$main::effectbase->[$_[0]]->[0]\n") if $main::effectbase->[$_[0]]->[0];    # append effect start message
        
                # exec code for new effect, if any
                if($main::effectbase->[$_[0]]->[5] ) {
				    #&& ref($main::effectbase->[$_[0]]->[5]) eq 'CODE'
                    &{$main::effectbase->[$_[0]]->[5]}($self);
                }
            }

            # exec code for effect, regardless of whether it's the first
			# or second or third, or whatever time.
            if ($main::effectbase->[$_[0]]->[7]) {
                &{$main::effectbase->[$_[0]]->[7]}($self);
            }
        
            # then we register the next decay time..this may never get used but at least i did it :)
            # it should register the next occurace of an effect change
            $main::effectors{$self->{'OBJID'}}=$self->{'FX'}->{$_[0]} unless ( $main::effectors{$self->{'OBJID'}} && ($main::effectors{$self->{'OBJID'}} < $self->{'FX'}->{$_[0]}) );
        }
        shift;
    }
    
    $self->stats_update; # dont forget that ;-).
    
    return;
}

sub effects_register {
    my $self = shift;
    foreach my $k (keys(%{$self->{'FX'}})) {
        if ( !$main::effectors{$self->{'OBJID'}} || ($main::effectors{$self->{'OBJID'}} < $self->{'FX'}->{$k}) )  { 
            $main::effectors{$self->{'OBJID'}} = $self->{'FX'}->{$k};
        }
    }
}

sub set_cryl {
	my ($self, $cryl) = @_;
	$self->{'CRYL'} = $cryl;
	$self->log_append("{17}##### SET CRYL TO $cryl\n")
    	if $self->{'DEBUG_CRYL'};
}

sub effects_update {
    my $self = shift;
    
    # dont do anything if we have no fx
    return unless($self->{'FX'});
    
    my $should_update;
    
    foreach my $k (keys(%{$self->{'FX'}})) {
        if( $self->{'FX'}->{$k} < time )  { 
            # append effect-finished message
            $self->log_append("{13}$main::effectbase->[$k]->[1]\n") if $main::effectbase->[$k]->[1];
    
            # exec code for dead effect, if any
            if($main::effectbase->[$k]->[6]) { #&& ref($main::effectbase->[$_[0]]->[6]) eq 'CODE'
            &{$main::effectbase->[$k]->[6]}($self);
            }
    
            # delete code listing
            delete $self->{'FX'}->{$k};
            $should_update = 1;
        }
    }
    
    if (scalar(keys(%{$self->{'FX'}})) == 0) {
        delete $self->{'FX'};
        delete $main::effectors{$self->{'OBJID'}};
    } 
    
    $self->stats_update() if $should_update;
    return;
}

sub gender_set {
  my ($self, $gender) = @_;
  # gender_set('m');
  # gender_set('f');
  # gender_set(); # random
  $gender = 'N' unless $gender;
  if ($gender =~ /M/i) { $self->{'PPOS'}='his'; $self->{'PPRO'}='him'; $self->{'GENDER'}='male'; $self->{'PRO'}='he'; }
  elsif ($gender =~ /F/i) { $self->{'PPOS'}='her'; $self->{'PPRO'}='her'; $self->{'GENDER'}='female'; $self->{'PRO'}='she'; }
  else {
  $self->{'PPOS'}='its'; $self->{'PPRO'}='it'; $self->{'GENDER'}='neuter'; $self->{'PRO'}='it';
  }
  return;
}

sub log_news() {
    my $self = shift;
	$self->log_append($main::news_man->get_recent_news());
	$self->pref_toggle("read news", 1, 1);
}

sub save_daily_stats() {
    # saves daily stats to database.. it's huge!
	my $self = shift;
	my $dbh = rockdb::db_get_conn();
	$dbh->do(<<END_SQL, undef, $self->{'UIN'}, $self->{'MAXH'}, $self->{'MAXM'}, 1*$self->{'DP'}, int($self->{'EXPTODAY'}), 1*$self->{'LEV'}, 1*$self->{'TIMEOND'}, 1*$self->{'PVPDEATHS'}, 1*$self->{'PVPKILLS'}, 1*$self->{'RACE'}, int($self->{'REPU'}), 1*$self->{'MT'}, 1*$self->{'MT'}-$self->{'T'}, int($self->{'CWORTH'}), @{$self->{'STAT'}} );
INSERT INTO $main::db_name\.r2_daily_scores
(score_date, uin, max_hp, max_mana, dp, exp_gained, level, min_online, pvpdeaths, pvpkills, race, repu, turns_max, turns_used, worth, kno, maj, cha, agi, str, def, kmec, ksoc, kmed, kcom, moff, mdef, mele, capp, catt, aupp, alow, supp, slow, dphy, dene, dmen, mmen)
VALUES
(sysdate(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
END_SQL
}


sub player_login(uid, pw[, sockno if telnet] [ip address]) {
  my ($self, $uid, $pw, $sockno, $ip, $dontrl) = @_;
  $uid = lc($uid); $pw = $pw;
  if( $main::telnet_only && !$sockno ) { return("Sorry, but for a few hours you will only be able to log into the game via telnet. If you'd like to know how to telnet in, see the <A HREF=$main::base_web_url/news.shtml>news</A> and <A HREF=$main::base_web_url/links/clients.shtml>clients</A> pages.<BR><BR>If your browser supports Java, connect to the game with our <A HREF=$main::base_web_url/telnet/>Java Telnet Applet</A> RIGHT NOW!"); } 
  my $ip_for_all = ($ip || &main::get_socket($sockno)->peerhost);
  print "## Player_Login: Name: $uid.\n";
    my ($image, $dweap) = &main::character_load($uid);
    my $keepgoing = 1;
#    if($image->{'CODE'}) { 
#       &main::check_pop; # check mail just in case
#       ($image, $dweap) = &main::character_load($uid);
#       if($image->{'CODE'}) {  
#         return("That character has not been verified yet.\nCheck your mailbox at $image->{'EMAIL'} for the\nverification notice (and reply to it).\n"); 
#         $keepgoing=0;
#       }
#    }
    if( !$sockno && !$image->{'NEWBIE'} && !$image->{'ADMIN'} && ( (scalar keys %$main::activeuids) - (scalar values %$main::sockplyrs) ) >= ($main::maxweb-1)) { 
       return("Sorry, due to bandwidth restrictions, only $main::maxweb web players can log in at once :(. Sorry for the trouble. If you have a telnet application, please try using that instead! (See the <A HREF=$main::base_web_url/news.shtml>news</A> and <A HREF=$main::base_web_url/links/clients.shtml>clients</A> sections of our site for a list of some tested mac/pc telnet applications)<BR><BR>If your browser supports Java, connect to the game with our <A HREF=$main::base_web_url/telnet/>Java Telnet Applet</A> RIGHT NOW!\n");
    }
    
    if ($main::admin_login_only && !$image->{'ADMIN'} && !$image->{'ROCKDEV'}) {
    #    return("Sorry, but you are not currently invited to play Rock: Crashed Plane.\n");
        return("You can't log in right now if you aren't an ADMIN. Try again later. Sorry. \nThere's usually even a good reason for this, \nbut knowing us, nevermind!\n");
    }

    if($image->{'BAN'} > time) { return("You have been temporarily banned from playing. Try again later.\n"); }
    if($image->{'IPLOCK'} && (index($ip_for_all, $image->{'IPLOCK'})!=0) ) { return("You have been temporarily banned from playing. Try again later.\n"); }
    my $sec;
    if(!$image->{'ADMIN'} &&  ($sec = $main::dual_friend->cant_login($ip_for_all, $image->{'NAME'})) && $main::make_alts_wait) {
        if((time - $main::last_alt_fail{$ip_for_all}) < 15 ) {
            if($main::recent_alt_fails{$ip_for_all}++ > 4) {
                
                &main::rock_shout(undef, "{13}##### BANNED FOR SPAMMED ALT LOGIN ATTEMPT ####\n", 1);
                push(@main::banlist, $ip_for_all);             # ban them for spammed login
                $main::qkillonsend[$sockno]=1 if $sockno;      # and eject!
                return("I said NO!\n");
            }
        } else {
            $main::recent_alt_fails{$ip_for_all} = 0;
        }
        
        $main::last_alt_fail{$ip_for_all} = time;
        
        return("Someone else at that IP recently logged off. You will have to wait ~$sec seconds until you can log in from that IP. The user who recently logged off may re-enter the game at any time.\n******Repeated login attempts may result in an IP ban.******\n");
    }
    
    my ($login_success, $reason, $uin) = $rockobj::auth_man->authUserID($ip_for_all, $uid, $pw);
    
    if (!$login_success) { 
        print "Couldn't log in: $reason.\n";
        return("{11}Couldn't log in: $reason\nHacker Attempt Logged.\n"); 
    } elsif(defined($main::activeuids->{$uid})) { 
	   # Check if player is already in the game.. if so, swap them over.
	   # Note: "$ip" here is the web-based ip address.. not telnet
       if(&rockobj::obj_lookup($main::activeuids->{$uid})->{'IP'} eq $ip) { return("You cannot log in via both web and telnet.\n"); } # &rockobj::obj_lookup($main::activeuids->{$uid})->{'TEMPPW'}=&main::pw_generate;
       elsif(&rockobj::obj_lookup($main::activeuids->{$uid})->{'IP'} ne $ip_for_all) {
	       return("{11}Couldn't log in: That character is already in the game under a different IP address.\n");
	   } else {
           my $socket = &main::get_objid_socket($main::activeuids->{$uid});
           if($sockno) { 
             if($socket) {
               # if other telnetter connected, log'em off
               $main::outq[$socket->fileno] = $main::inq[$socket->fileno]='';
               $main::qkillonsend[$socket->fileno]='';
               delete $main::sockplyrs->{$socket->fileno};
               $main::sock_sel->remove($socket);
               $socket->close;
             }
               delete $main::activeusers->{$main::activeuids->{$uid}};
             &main::rock_change_obj($sockno, $main::activeuids->{$uid});
             $self->obj_dissolve();
             return "";
           } elsif (!$sockno) {
             &rockobj::obj_lookup($main::activeuids->{$uid})->{'TEMPPW'}=&main::pw_generate;
             return ""; 
           } else {
             &rockobj::obj_lookup($main::activeuids->{$uid})->log_append("Someone at $ip_for_all just tried logging in as you (Password: $pw).\n");
             $main::hackwatch{"$ip_for_all"}++;
             if($main::hackwatch{"$ip_for_all"} >= 8) { 
               push(@main::banlist, "$ip_for_all");
               &main::mail_send($main::rock_admin_email, "R2: BAN ($ip_for_all)", "Banning $ip_for_all for hacking.\n");
             }
             if($sockno) { $main::qkillonsend[$sockno]=1; }
             return("That player is already in the game! \nHacker Attempt Logged.\n");
           }
       } # // swap user's telnet connections
    } elsif(!&main::ip_is_free($ip_for_all, !$ip) && !$image->{'IS_REGISTERED_USER'} && !$image->{'ADMIN'}) {
        return("Somebody else is already playing the game using your IP address ($ip_for_all). Don't fret, this does not necessarily mean that your character is currently in the game.\nPlease try again later.\n\n");
    } else {
    my ($log);
    
    delete $image->{'groupid'}; # if game crashed, groupid stuff can have STRANGE crashies

    if ($self) { 
    	# otherwise turn me into them.
    	$log = $self->{'LOG'}; # get the log before it's too late!
    	$image->{'ANSI'} = $self->{'ANSI'} unless $image->{'ANSI'}; # turn color on if they did when logging in..otherwise leave it alone.
    	$self->obj_dissolve; # i'm meeltting, i'm meeelltttinng!
    }
     
     # record the login event
     $uin ||= $rockobj::auth_man->getUIN($image->{'NAME'}); # TEMP FIX -- REMOVE THIS LINE, NO PROBLEMS WILL HAPPEN :-)
#	 &main::rock_shout(undef, "IMNAME: $image->{'NAME'}, uin $uin\n", 1);
     $rockobj::auth_man->logMessage("R2", "LIN", $uin, $ip_for_all);
     
     # update player's desc
     if($main::pdescs{lc $image->{'NAME'}}) { $image->{'DESC'} = $main::pdescs{lc $image->{'NAME'}}; delete $main::pdescs{lc $image->{'NAME'}}; }
     

     # change room to unshifted resolution
     $image->{'ROOM'} = $main::staticid_to_room{$image->{'STATIC_ID'}} || $main::roomaliases{'cluckys'} || 1;

     # change room to opening room if it doesnt exist
    if(!$main::map->[$image->{'ROOM'}]) { $image->{'ROOM'}=1; }
     
    ###CATCH BROKEN CHARS HERE...
    
    ##CHIST
    ##KILLREC
    ##@SKIL
    ##PREF
    ##QUEST
    
    if($image->{'TOTAL_COMMANDS'}){
    
    }else
    {
    	$image->{'TOTAL_COMMANDS'} = 0;
    }
    
     # fix inventory/exp temps if they excaped the logoff catcher
     if($image->exp_restore_backup) { $image->{'ROOM'}=($main::roomaliases{'arenahall'} || 0); }
     
     ###### FIX DILLFROG.COM LOGIN INFO ########
     delete $image->{'PW'};
     delete $image->{'LPWCH_TIME'};
     $image->{'UIN'} = $uin;
     $image->{'EMAIL'} = $rockobj::auth_man->getEmail($image->{'UIN'});
     $image->{'RACE'} ||= 1;
     my $acct_data = $rockobj::auth_man->getAccountData($image->{'UIN'});
#     $image->log_append("MOOO $acct_data->{'prefer_censor'}\n");
     $image->pref_set('censor filter', 1, $acct_data->{'prefer_censor'} eq 'Y' ? 1 : 0);
     
     # $rockobj::auth_man->getAccountData($_[0]->{'UIN'})->{'userid'}
     
# This messes up display of UserIDs (misleading who is hostile etc)
#     my $uid_formatted = ucfirst $acct_data->{'userid_formatted'};
#     if (lc($uid_formatted) eq lc($image->{'NAME'})   && $image->{'NAME'} ne $uid_formatted) {
#         $image->log_append("{16}***\n*** I've changed your logon name's case to $uid_formatted. This will take effect the next time you log in. \n***");
#         $image->{'NAME_CHANGE'} = $uid_formatted;
#     }

     $image->gender_set($rockobj::auth_man->getGender($image->{'UIN'}));
     ###########################################
     
	 	 # ------ FIX A BUG WHERE PLAYER MIGHT HAVE HAD HIM/HERSELF
	 # RTG 2002-10-16; feel free to remove after 2003, or leave it here
	 # or in some anti-bug login code for fun.
	 $image->inv_del($image);


     $image->aprl_synch;
     $image->objids_register($dweap); # handle objid stuff
     # get rid of my stalk info
     delete $image->{'STALKING'};
     delete $image->{'HAGGLE'};
#mich
     #delete $image->{'CMD_WATCH'};

#mich - if they aint got a clan, give them the race
    $image->{'CLAN'} = $image->{'RACE'} unless defined($image->{'CLAN'});

     delete $image->{'TIRED'}; # you're not tired anymore (fixes clock issues)
     $image->pref_toggle('brief room descriptions', 1, 1);
     $image->pref_toggle('busy flag', 1, 0);
     # add self to room :)
     $main::map->[$image->{'ROOM'}]->inv_add($image);
     # set up socketry
     if($self) { delete $main::activeusers->{$self->{'OBJID'}}; } # someone else can control it, 'sokay!
# PLAT CHANGED TO COMMENT OUT THE IF STATEMENT.. WHY WAS THIS HERE? I GUESS WE"LL FIND OUT :-) :) --- RTG 2003-03-20
#     if($main::uidmap{$uid}) { $main::uidmap{$uid}=time; } # we saw'em! we really saw'em!
     $main::uidmap{$uid}=time; # we saw'em! we really saw'em!
     if($sockno) {
        $main::sockplyrs->{$sockno}=$image;
        $image->{'IP'}=&main::get_socket($sockno)->peerhost;
     }
     if($ip) { $image->{'IP'} = $ip; }
     
     $image->{'A_HIST'} = {};
     delete $image->{'BASEH'};
     delete $image->{'BASEM'};
     delete $image->{'IGNORECMDS'};
###     delete $image->{'IGNORE'};
     delete $image->{'LASTTELL'};
     delete $image->{'SGIVE_OFFER'};
     $image->{'LIVES'} = $main::lives_per_day if !defined($image->{'LIVES'});
     
     $image->{'TEMPPW'}=&main::pw_generate;
     $main::activeusers->{$image->{'OBJID'}}=time; #in case obj normally doesnt log
     $main::activeuids->{$uid}=$image->{'OBJID'};
     $image->log_append($log); # append me
     
     $image->{'LOG'} =~ s/\{.*?\}//g; # kills all color codes left
     if($image->{'ANSI'} && $image->{'TTY'}) { $image->{'LOG'} .= '[7h'; }
     if($image->{'LOG'}) { $image->{'LOG'} = "{6}---\n{16}Last Time You Were Here:\n{6}---\n{7}".$image->{'LOG'}."{6}---\n{16}And Now:\n{6}---\n"; }
     else { $image->log_append("{6}---\n{16}Entering Realm {14}({4}your ip: $image->{'IP'}\{14})\n{6}---\n"); }
     $image->{'WEBLOG'}=undef;
     $image->maxinv_set();
     # Maint Stuff. logs, etc may go here.
     
     # LOG:

#     $image->log_news();
     if($image->{'MOTDLEN'} != length($main::motd)) { $image->log_append($main::motd."\n"); $image->{'MOTDLEN'}=length($main::motd); }

     if( (time - $image->{'BIRTH'}) < (86400*$main::newbie_for_days) ) { $image->{'NEWBIE'}=1; } else { delete $image->{'NEWBIE'}; }
     #
     
	 
     if($image->{'VERSKILL'} < $main::ver_skill) { 
           delete $image->{'@SKIL'};
           delete $image->{'CRS'};
           delete $image->{'CHIST'};
           $image->{'GIFT'}={};
           $image->{'VERSKILL'} = $main::ver_skill;
     }
     
     # If the preference version has changed, set my preferences to
     # their default values.
     if($image->{'VERPREF'} < $main::ver_pref) { 
           $image->pref_toggle('autoraise', 1, 1);
           $image->pref_toggle('stat prompt', 1, 1);
           $image->pref_toggle('censor filter', 1, 1);
		   $image->broadcast_channel(1); # newbie chat
           $image->pref_toggle('auto talk', 1, 1); 
           $image->pref_toggle('attack upon user entry', 1, 0); # aggentry defaults off; newbies die too much otherwise
           $image->pref_toggle('gift-acceptance', 1, 1); # gift acceptance on by default
           $image->{'HOSTILE'} = 0; # hostility defaults off
		   $image->{'VERPREF'} = $main::ver_pref;
     }
     
     if($image->{'VERCLASS'} < $main::ver_class) { delete $image->{'CHIST'}; delete $image->{'TCOURSE'}; $image->{'VERCLASS'} = $main::ver_class; }

     $image->skills_racial_fix(); # fix racial stuff. ##################### MAY WANT TO REMOVE LATER!!!!!!!
     $image->cert_upcredits(1); # quietly update credits. yell if the user cares.
     if($main::msg_friend->msg_count($image->{'UIN'})) { 
         $image->log_append("{1}*** YOU HAVE OFFLINE MESSAGES WAITING FOR YOU!!\n{13}*** TYPE {17}msgs more{13} TO VIEW AND DELETE EACH MESSAGE\n");
     }
     
     #mich - remove this later
     $image->trivia_stats_maint();
     if($image->{'LEV'} < 45){$image->{'NEWBIE'}=1;}

     if(!$image->{'NEWBIE'}) {
         $image->log_append("{11}You may PVP (or be PVP'd by) anyone within {16}$main::pvp_restrict {11}levels of you.\n"); 
     }
     
     if ($image->pref_get('autoraise')) { $image->exp_cycle(); }
     
     # manage ununique items..
     my $uno;
     foreach $uno ($image->inv_objs, $image->stk_objs) { 
         if($uno->{'NOSAVE'}) { $image->log_append("{4}A powerful force whisks {6}$uno->{'NAME'} {4}into the void.\n"); $uno->obj_dissolve; }
         
         next if !$uno->{'UNIQUE'};
         
         if($main::obj_unique{$uno->{'REC'}}) { 
             # if it's indexed and the owner is not "me", take it away
             if( ($main::obj_unique{$uno->{'REC'}} ne lc($image->{'NAME'})) ) {
               $image->log_append("{4}A powerful force whisks {6}$uno->{'NAME'} {4}into the void.\n");
               $uno->obj_dissolve();
             }
         } else { 
             # if it's not indexed and i have it, make me the proud owner.
             if($image->{'ADMIN'}) { $image->log_append("{4}Staking claim on unique object $uno->{'NAME'} ($uno->{'OBJID'}).\n"); }
             $main::obj_unique{$uno->{'REC'}} = lc($image->{'NAME'});
             foreach my $obj (values(%{$main::objs})) { 
                if($obj->{'REC'} == $uno->{'REC'} && $uno->{'OBJID'} != $obj->{'OBJID'}) { $obj->obj_dissolve(); }
             }
         }
     }
     
     if($image->{'VERMAP'} < $main::ver_map) { 
      #  $image->log_append("{1}Sorry, we've done major map reworking since you last logged in.\nWe have to move you to a known room, sorry.\n");
        $main::map->[$image->{'ROOM'}]->inv_del($image);
        $main::map->[$main::roomaliases{'cluckys'}]->inv_add($image);
#        $main::map->[$main::roomaliases{'arenahall'}]->inv_add($image);
        $image->{'VERMAP'} = $main::ver_map;
     }
     if($image->{'VERINV'} < $main::ver_inv) { 
      #  $image->log_append("{1}Sorry, the game's player-file version has upgraded to $main::ver_inv.\nThat means we have to reset some of your player info.\n");
        my $obj;
        foreach $obj ($image->inv_objs,$image->stk_objs) { $obj->dissolve_allsubs; }
        $image->items_givebasic; # basic items.
        $image->{'VERINV'} = $main::ver_inv;
        $image->item_wear('all');
        $image->{'T'}=$image->{'MT'};
     }
     if($image->{'VERCRYL'} < $main::ver_cryl) { 
      #  $image->log_append("{1}Sorry, the game's cryl version has upgraded to $main::ver_cryl.\nYour cryl and bank have been reset accordingly.\n");
        $image->{'CRYL'}='';
        # clear all banks
        my $key;
        foreach $key (keys(%{$image})) {
          if(index($key, 'B-') == 0) { $image->{$key}=''; }
        }
        $image->{'VERCRYL'} = $main::ver_cryl;
     }
     
     if($image->{'VERQUEST'} < $main::ver_quest) {  
        delete $image->{'QUEST'};
        $image->{'VERQUEST'}=$main::ver_quest;
     }

     if($image->{'VERDP'} < $main::ver_dp) {  
        delete $image->{'DP'};
        $image->{'VERDP'}=$main::ver_dp;
     }

     if(($image->{'VERTIME'} < $main::ver_time) && defined($image->{'VERTIME'})) {  
        delete @{%$image}{qw(LASTTPORT PVPTIME PKTIME TRD NEWTURNS LPWCH_TIME TIMEOND TIMEONT @LCTI DIED LASTSEEN)};
        $image->{'BIRTH'} = time if $image->{'BIRTH'} > time;
        $image->log_append("{6}*** reset your time-oriented char data ***\n");
        $image->{'VERTIME'}=$main::ver_time;
     }else{
		$image->{'VERTIME'}=$main::ver_time;
	 }

     $image->worth_calc();
     
     if($image->{'VERMILI'} < $main::ver_mili) { 
        $image->{'VERMILI'}=$main::ver_mili;
        if($image->{'SOLDIER'}) { 
          $image->log_append("{17}The soldier/general procedure was updated since you were enlisted. You have since been honorably discharged. If you would like to join your race's military again, type \"help soldier\" for more info.\n");
          delete $image->{'SOLDIER'};
        }
        
     } 
     delete $image->{'CANPVP'};
     if($image->{'VERSTAT'} < $main::ver_stat) { 
        delete $image->{'EXPPHY'}; delete $image->{'EXPMEN'}; # this will be overwritten by the race_statsto call anyway, but we'll do this here to make sure we know it's been considered :-).
        
        $image->race_statsto($image->{'RACE'});
        delete $image->{'PVPS'};
        delete $image->{'PVPKILLS'}; delete $image->{'NPCKILLS'};
        delete $image->{'PVPDEATHS'};delete $image->{'NPCDEATHS'};
        delete $image->{'REPU'};     delete $image->{'ARENA_PTS'};
        delete $image->{'KILLREC'};  delete $image->{'DP'};

        $image->{'VERSTAT'} = $main::ver_stat;
        $image->{'T'}=$image->{'MT'};
     }
     
     
     # General-status update.
     $image->up_general();
     if($image->{'PACIFIST'}){
			
			$image->{'SOLDIER'}=0;
			}
		if($image->{'LEV'}>=500 && !$image->{'SOLDIER'}){
			if($image->skill_has(87)){}
			else{ 
				&main::rock_shout(undef, "{17}$image->{'NAME'} is at least level 500 and has been made a soldier!\n");
				$image->{'SOLDIER'}=time;
				if($image->{'REPU'} <=0){$image->{'REPU'}=1}
				else {$image->{'REPU'}++;}
				}
			}
			
   	 if(
	 (
		!$image->{'NEWTURNS'} || 
		(&main::day_get($image->{'NEWTURNS'}) ne &main::day_get(0)) || 
		(($image->{'NEWTURNS'} + 60*60*24) < time)
		) 
		) { 
        #
		#  NEW TURNS --- TURN GIFTING HERE!!
		#
		#
		
		# ****************************************
		# ******** SAVE TURN STATS HERE **********
		# ****************************************


		if($image->{'PACIFIST'}){
			
			$image->{'SOLDIER'}=0;
			}
		if($image->{'LEV'}>=500 && !$image->{'SOLDIER'}){
			if($image->skill_has(87)){}
			else{ 
				&main::rock_shout(undef, "{17}$image->{'NAME'} is at least level 500 and has been made a soldier!\n");
				$image->{'SOLDIER'}=time;
				if($image->{'REPU'} <=0){$image->{'REPU'}=1}
				else {$image->{'REPU'}++;}
				}
			}
		
        
			$image->reset_trivia_stats();
			$image->save_daily_stats();
		
		delete $image->{'SUSPICIOUS'};
		
		
		$image->store_turns() if $image->{'SOLDIER'} && $image->race_owns_monolith("monolith_temporal"); # save old turns if they've got monolith, etc
        
		$image->{'T'} = $image->{'MT'} = 6500;
        
        #my $last_newturns = int((time - $image->{'NEWTURNS'}) / 60 / 60 / 24);
		
        
		#if(($last_newturns > 1)){
		#	if( $image->{'LEV'} > 50 ){
		#		$image->log_append("You last logged in $last_newturns days ago.\n");
		#		$image->{'T'} += $last_newturns*2000;
		#	}
		#}
        
		$image->{'NEWTURNS'}=time; 
        $image->{'LIVES'}=$main::lives_per_day;
        $image->{'DEATHS_TODAY'} = 0;
        $image->{'TIMEONT'} += $image->{'TIMEOND'}; $image->{'TIMEOND'}=0;
        $image->log_append("{6}You have been given $image->{'T'} turns for the new day.\n");
        $image->{'LUCK'}=rand(100);
		$image->pref_toggle("read news", 1, 0);
		delete $image->{'LASTTHANK'};   # let them thank same person again
		delete $image->{'LASTDEPRECATE'}; # let them deprecate same person again
		delete $image->{'DECAP_USED'};
       # if(!$image->{'USEDWEB'}) { 
       #    $image->{'T'}+=1000;
       #    $image->log_append("{16}You have been given 1000 bonus turns for not using the web interface yesterday.\n");
       # }
       
        my $bturns = int (1000*(1-($main::rock_stats{'s-prace-'.$image->{'RACE'}}*2)/($main::rock_stats{'s-players'}||1)))+1;
       
         if($bturns && $bturns < 59000 && $bturns > 0 && $image->{'REPU'} >= -7) { 
           $image->log_append("{16}You have been given $bturns bonus {1}racial{16} turns for today.\n");
           $image->{'T'}+=$bturns;
		   
        }
        my $sbturns;
        if($image->{'SOLDIER'} && $image->{'REPU'} >= 0) {
            if($bturns=$main::rock_stats{'bonus-genraceturns-'.$image->{'RACE'}}) {
               $image->log_append("{16}Your {6}general{16} has rationed {6}$bturns {16}bonus turns for your soldier use. Long live the $main::races[$image->{'RACE'}]!\n");
               $image->{'T'}+=$bturns;
			   
			   $sbturns = $bturns;
            }
            
            $image->{'DP'} += 1/3;
            
            if ($image->{'GENERAL'}) {
                $image->{'DP'} += $image->monoliths_captured();
                my $bonus_turns = int(100 * $image->monoliths_captured() + rand(5 * $image->{'REPU'}) + $sbturns);
                if ($bonus_turns > 0) {
                    $image->log_append("{16}You have received {6}$bonus_turns {16}bonus turns for being a General.\n");
                    $image->{'T'} += $bonus_turns;
                }
            }
        }
        
        $image->{'DP'} += .25; # just for logging in 

        delete $image->{'USEDWEB'};
        delete $image->{'TCOURSE'};
        delete $image->{'LASTPVP'};
        delete $image->{'DAILYWIN'};
        
        #mich changed logic of next statement
        $image->{'REPUS'} = $image->{'GENERAL'} ? 5 : 1;

		#if ($image->{'REPU'} > 0) {
		    #$image->{'REPU'} *= .9; # bring reputation back to 'normal' a little..maybe.
        #} else {

		#    $image->{'REPU'} *= .98;
		#}

		$image->{'OPIS'}=1; # set opinions ({'OPIN'} is the value)
        $image->{'WEBS'}=6; 
        $image->{'PLAGUE'}=6;
        $image->{'INTERVENE'}=6;
        
        # pvps
        $image->{'PVPS'} = $main::pvpsperday; if($image->{'SOLDIER'}) { $image->{'PVPS'}=1000; }
        
        if($image->{'GIFT'}->{'ROAR'}) { $image->{'ROARS'}=10; }
        $image->{'VIGOR'}=1.5;
        $image->{'MAXHIT'} = 0;
        
		
		$image->{'EXPYESTERDAY'} = $image->{'EXPTODAY'};
		$image->{'EXPTODAY'} = 0;
        
        # give 0.8% interest from banks.
		if($image->{'LEV'} > 45){
			my $interest_gained = 0;
			foreach my $key (keys(%{$image})) {
			  if(index($key, 'B-') == 0) { 
				 my $interest = int ($image->{$key}*.008);
				 $image->{$key} += $interest;
				 $interest_gained += $interest;
			  }
			}
			$image->log_append("{13}Your banked cryl has earned {3}$interest_gained {13}cryl interest.\n")
		    if $interest_gained;
        }
        # handle courses
        if($image->{'CRS'} && scalar(%{$image->{'CRS'}})) { $image->course_inv(); }

        # refuel items
        foreach my $i ($image->inv_objs, $image->stk_objs) {
           if($i->{'UPD'}) { $i->{'USES'}=$i->{'UPD'}; }
        }
   
        &rock_maint::dp_add($image);
        
		# now the max turns is our current turn set.
		# this will never be crazy, now that we've refined exp stuff
		# though maybe some turn-refueling spells could muck this up.
		$image->{'MT'} = $image->{'T'};
		
		$image->log_append("{13}Don't forget to check the news.\n");
     } else {
        # if it's not a new day..
        $image->log_append("{14}It is not yet a new day. Bummer.\n");
     }
     my $message;
	 $message = $image->oracle_cert_poll();
	 $image->log_append("$message");
     
     if(!$sockno) { $image->{'USEDWEB'} = 1; }

     if(!$image->{'SOCINVIS'}) {
        &main::rock_talkshout($image, "{17}$image->{'NAME'}'s {2}($main::races[$image->{'RACE'}]) {7}planar frequency tunes to that of the realm.\n", 'silence logins');
        $image->room_tell("{17}$image->{'NAME'}\{7}\'s image shifts and modulates as $image->{'PRO'} enters the realm.\n");
     } else {
        &main::rock_shout(undef, "{17}$image->{'NAME'}'s {2}(invisible) {7}planar frequency tunes to that of the realm.\n", 1);
     }
	     
     my $smallname = lc($image->{'NAME'});
     if($image->{'CMD_WATCH'}) {
        &main::rock_shout(undef, "{17}$smallname-spying turned $main::onoff[$image->{'CMD_WATCH'}].\n", 1);
     }
     if(!$dontrl) { $image->room_log; }
     # check for dual characters (sneaky eh?)
     $main::dual_friend->on_login($image->{'IP'}, $image->{'NAME'});
     # cache the ip
     &main::r2_ip_to_name($ip_for_all);
     # check for max users
     my $highcheck = (scalar keys(%{$main::activeuids}));
     if ($highcheck>$main::high_uonline) { $main::high_uonline=$highcheck; } 
     # register effects
     $image->effects_register();
     # FINALLY, error scan
     $image->inv_scan("Final Entry Scan");
     # remove register code ~70 days after 5/28/99:
     #$image->pw_webregister();
     $image->stats_update();
     $image->sql_update_stats(); ## DO I CARE??

     # If they're pretty high for their age, freeze'em
     if ($image->get_age() < 4 && $image->{'LEV'} >= 40) {
#         &main::mail_send($main::rock_admin_email, "WARNING: $image->{'NAME'} Abnormally high level for age.", "$image->{'NAME'} is level $image->{'LEV'} but is only ".$image->get_age()." days old.\n");
     }
     if ($image->get_age() < 14 && $image->{'WORTH'} >= 3000) {
         &main::mail_send($main::rock_admin_email, "WARNING: $image->{'NAME'} Abnormally high worth for age.", "$image->{'NAME'} is worth $image->{'WORTH'} but is only ".$image->get_age()." days old.\n");
     }
     
     
     ############ CAN WE PROBE?
     ## THIS IS DUMB.LET"S GET RID OF IT!. -- RTG 1/25/2003
#     if(!$image->pref_get('can we probe')) { 
#         $image->{'ST8'}->[0]='CANPROBE'; $image->{'ST8'}->[1]=0;
#         $image->log_append("{2}$main::can_we_probe");
#         $image->interp_st_command;
#     } #main::can_we_probe
     ############################
     
     return('');
   
  }
  return;
}
sub delete_all_votes_for_general {
    my $self = shift;
    my $voter = shift;
 
    foreach my $voter_id (keys(%main::general_votes)) {
        my ($race, $name) = unpack('LA*', $main::general_votes{$voter_id});
        if ($name eq lc $voter) {
            delete $main::general_votes{$voter_id};
        }
    }
       	
}

sub delete_all_votes_for_me {
    my $self = shift;
    foreach my $voter_id (keys(%main::general_votes)) {
        my ($race, $name) = unpack('LA*', $main::general_votes{$voter_id});
        if ($name eq lc $self->{'NAME'}) {
            delete $main::general_votes{$voter_id};
        }
    }
}
sub delete_all_nonexistent_votes {
    my $self = shift;
    foreach my $voter_id (keys(%main::general_votes)) {
        my ($race, $name) = unpack('LA*', $main::general_votes{$voter_id});
        unless (-e "saved/$name\.r2") {
            delete $main::general_votes{$voter_id};
        }
    }
}

# evalll $main::rock_stats{'s-genrl_race-4'} = 'plat'; $_[0]->{'REPU'} = -10; $_[0]->up_general();
sub up_general {
    my $self = shift;
    my $dont_recurse = shift;
    # update my general status
    $self->{'GENERAL'} = ($main::rock_stats{'s-genrl_race-' . $self->{'RACE'}} eq lc($self->{'NAME'}));
    if($self->{'GENERAL'}) { 
        if ($self->{'REPU'} < -8) {
            $self->log_error("You are not fit to be General, and have chosen to resign.");
            &main::rock_shout($self, "{17}((( {16}$self->{'NAME'} has been deemed unfit to be General, and thus has been forced to resign. {17})))?\n");

            $self->delete_all_votes_for_me();
            &rock_maint::votes_tally();
            $self->up_general(1) unless $dont_recurse;
        }
        $main::rock_stats{'bonus-genraceturns-' . $self->{'RACE'}} = int(700*$self->fuzz_pct_skill(9, 200));
    } else { 
        delete $self->{'GENERAL'};
    }
}

sub monoliths_captured {
    my $self = shift;
    my $liths;
    foreach my $key (keys(%main::monoliths)) {
        $liths += $main::rock_stats{$key} == $self->{'RACE'};
    }
    return int $liths;
}


sub maxinv_set {
   my $self = shift;
   my $race = 0;
   my $soldier = 0;
   my $general = 0;
   if($self->race_owns_monolith('monolith_advocate') && $self->{'TYPE'}==1)
   {	$race = 2;      }
   if($self->race_owns_monolith('monolith_advocate') && $self->{'TYPE'}==1  && $self->{'SOLDIER'})
   {	$soldier = 3;      }
   if($self->race_owns_monolith('monolith_advocate') && $self->{'TYPE'}==1  && $self->{'GENERAL'})
   {	$general = 4;      }
   $self->{'MAXINV'} = 15 + 2 * $self->skill_has(17) + 5 * $self->skill_has(20) + $race + $soldier + $general;
      
   $self->{'MAXINV'} = $self->{'MAXINV'} + $self->{'MAXINVOVERRIDE'};
   return;
}


sub worth_calc {
    my $image = shift;
    my $worth;
    foreach my $key (keys(%{$image})) {
        if(index($key, 'B-') == 0) {
            $worth += $image->{$key};
        }
    }
    $worth += $image->{'CRYL'};
    $image->{'CWORTH'} = $worth;
    return $worth;
}

sub on_touch { 
    my ($self, $user) = @_;
    if($self->{'TOUCHFX'}) { 
        $user->log_append("{7}You touch the $self->{'NAME'}.\n");
        $user->room_sighttell("{17}$user->{'NAME'} {7}touches $self->{'NAME'}.\n");
        
        $user->effect_add($self->{'TOUCHFX'});
        
        if($self->{'USES'} <= 0 || !(--$self->{'USES'})) { 
            $user->log_append("{7}The $self->{'NAME'} disappears.\n");
            $self->obj_dissolve();
        }
    }
    else {
        $user->log_error('You can\'t use that!');
    }
}

sub on_cryl_receive {}
sub on_sell {}
sub on_digest {}

sub getTraceString {
    my $calltrace;
    my $n=0;
    while(my @a = caller($n)) { $calltrace .= "    ".($n++).": @a\n"; }
    return $calltrace;
}

sub user_stupify {
    my ($self, $uid) = @_;
    if(!$self->{'ADMIN'} && !$self->{'OVERSEER'}) {
        $self->log_error('This option is only available for admins and overseers.');
        return;
    }

    if(my $recip = $self->uid_resolve($uid)) {
        if($recip->{'STUPID'} == 1)
        {
            $recip->log_append("{16}You have been unstupified!\n");
            $recip->{'STUPID'} = 0;
            $self->log_append("{2}- {17}notified and unstupified $uid {2}-\n");
        }
        else {
            $recip->log_append("{16}You have been stupified!\n");
            $recip->{'STUPID'} = 1;
            $self->log_append("{2}- {17}notified and stupified $uid {2}-\n");
        }
    }
    return;
}

sub log_error {
    # mich wrote this
    my ($self, $error) = @_;
    $self->log_append('{3}<<  ' . $error . "{3}  >>\n");
    return;
}

sub log_hint {
    # mich wrote this
    my ($self, $hint) = @_;
    $self->log_append('{6}Hint: {16}' . $hint . "\n");
    return;
}

sub is_my_friend {
    # returns true if *I* consider $who to be my friend.
	# right now, friendships are mutual, but that could change. don't
	# rely on their mutuality.
    my ($self, $who) = @_;
	
	return $self->{'RACE'} == $who->{'RACE'} ||                    # we're same race
	       ((!$main::map->[$who->{'ROOM'}]->{'MONOLITH'} || !$main::map->[$self->{'ROOM'}]->{'MONOLITH'}) && $main::allyfriend[$self->{'RACE'}]->[$who->{'RACE'}]) || # we're allied
	       $self->is_in_same_group_as($who)                        # we're grouped (ha ha, groped..typo)
}

sub cant_aggress_against {
	# Syntax: $obj->cant_aggress_against($victimobj[, $out_of_room_okay])
	# 
	# Returns true if i CAN'T aggress against the $victim object.
	# If $out_of_room_okay is 1, then we will allow the two objects
	# to attack each other even though they are not both in the same
	# room.
	#
    my ($self, $victim, $out_of_room_okay) = @_;

##    # TEMP fix to keep people in war pit from kiling each other.
###    return AGGRESS_FAILED_ROOM_SAFE if $main::map->[$victim->{'ROOM'}]->{'PVPROOM'} &&
###	                          $main::map->[$self->{'ROOM'}]->{'PVPROOM'};


    return AGGRESS_FAILED_VICT_SELF if ($self == $victim);


	# can't attack group members
	return AGGRESS_FAILED_SAME_GROUP if ($self->is_in_same_group_as($victim));

    # no safe room attacking
    if(my $safeval = $main::map->[$self->{'ROOM'}]->{'SAFE'} | 
	                 $main::map->[$victim->{'ROOM'}]->{'SAFE'}
	  ) {
		# NOTE: THIS IS NOT GOING TO WORK RIGHT NOW, WITH SAFEDETAIN.
		# Really it should check for ==1 instead, since _SAFE is stronger
		# than _SAFEDETAIN
		return $safeval == 2 ? 
		    AGGRESS_FAILED_ROOM_SAFEDETAIN :
            AGGRESS_FAILED_ROOM_SAFE;
    }

    # can't attack people outside the room 
    return AGGRESS_FAILED_VICT_NOTPRESENT
	    if !$out_of_room_okay && ($victim->{'ROOM'} != $self->{'ROOM'});

    # immortals can't attack
    return AGGRESS_FAILED_SELF_IMMORTAL if ($self->{'IMMORTAL'});

    # can't attack immortals
    return AGGRESS_FAILED_VICT_IMMORTAL if ($victim->{'IMMORTAL'});
    
    # can't attack dead people
    return AGGRESS_FAILED_VICT_DEAD if ($victim->is_dead);

    ## Fix to let players of same race attack each other in pvp rooms
    # we're both in pvp rooms (ie war pit), it's OK
    return AGGRESS_SUCCESS if $main::map->[$victim->{'ROOM'}]->{'PVPROOM'} &&
	                          $main::map->[$self->{'ROOM'}]->{'PVPROOM'}&&
	                          $self->{'TYPE'}==1;

    # players of same race can't attack each other.
	return AGGRESS_FAILED_RACE if ($victim->{'RACE'} == $self->{'RACE'});

    # we're both in monolith rooms, it's OK
    return AGGRESS_SUCCESS if $main::map->[$victim->{'ROOM'}]->{'MONOLITH'} &&
	                          $main::map->[$self->{'ROOM'}]->{'MONOLITH'};
                              
#    # we're both in pvp rooms (ie war pit), it's OK
#    return AGGRESS_SUCCESS if $main::map->[$victim->{'ROOM'}]->{'PVPROOM'} &&
#	                          $main::map->[$self->{'ROOM'}]->{'PVPROOM'};

    #both in an pvping room
    return AGGRESS_SUCCESS if $self->room()->{'PVPROOM'} && $victim->room()->{'PVPROOM'};

    # races are allied
	return AGGRESS_FAILED_ALLIED if ($main::allyfriend[$self->{'RACE'}]->[$victim->{'RACE'}]);

    # if we're pvping here
    if($self->{'TYPE'} == OTYPE_PLAYER && $victim->{'TYPE'} == OTYPE_PLAYER) {  
        # can't pvp in nopvp room
	    if($main::map->[$self->{'ROOM'}]->{'NOPVP'} ||
		   $main::map->[$victim->{'ROOM'}]->{'NOPVP'}) {
	        return AGGRESS_FAILED_ROOM_NOPVP;
	    }
        
        # can't attack newbies
        elsif($victim->{'NEWBIE'}) {
            return AGGRESS_FAILED_VICT_NEWBIE;
        }
        
        # newbies can't attack
        elsif($self->{'NEWBIE'}) {
            return AGGRESS_FAILED_SELF_NEWBIE;
        }

        # can't kill the same person twice in a row
        elsif($victim->{'NAME'} eq $self->{'LASTPVP'}) {
            return AGGRESS_FAILED_PVP_LAST;
        }

        # can't go over pvp limit for the day
        elsif($self->{'PVPS'} <= 0 && $main::pvp_restrict < 1000 && !$self->{'GAME'} && !defined($self->{'CANPVP'}->{$victim->{'NAME'}})) {
            return AGGRESS_FAILED_PVP_LIMIT;
        }

        # can't attack outside pvp range
        elsif( (!$self->{'SOLDIER'} || !$victim->{'SOLDIER'}) && !$self->{'GAME'} && (abs($victim->{'LEV'} - $self->{'LEV'}) > $main::pvp_restrict)) {
            return AGGRESS_FAILED_PVP_RANGE;
        }
    }
    
    return AGGRESS_SUCCESS;
}

sub aggress_error_string {
    # mich wrote this
	
    my ($self, $name, $code, $errorlist) = @_;
    $errorlist ||= \@main::AGGRESS_GENERIC_ERROR;
    return undef unless defined $errorlist->[int $code];
    return sprintf($errorlist->[int $code], $name);
}

sub log_cant_aggress_against {
    # mich wrote this
    my ($self, $victim, $out_of_room_okay, $errorlist) = @_;
	
    my $result = $self->cant_aggress_against($victim, $out_of_room_okay);

    my $errorstring = $self->aggress_error_string($victim->{'NAME'}, $result, $errorlist);
    $self->log_error($errorstring) if $errorstring;

    return $result;
}

sub trivia_stats_maint {
    my $self = shift;

    delete $self->{'TRIVIA_STAT'};
    for(my $i = STAT_LEVEL_START_TODAY; $i <= STAT_BESTROUND_OVERALL; $i++) {
        if(!defined($self->{'TRIVIA_STATS'}->[$i])) {
            $self->{'TRIVIA_STATS'}->[$i] = 0;
        }
    }
}

sub reset_trivia_stats {
    my $self = shift;

    $self->{'TRIVIA_STATS'} ||= [];

    my $array = $self->{'TRIVIA_STATS'};

    delete $self->{'TRIVIA_STAT'};

    $array->[STAT_LEVEL_START_TODAY]   = $self->get_real_level();
    $array->[STAT_HP_START_TODAY]      = $self->base_health();
    $array->[STAT_MN_START_TODAY]      = $self->base_mana();
    $array->[STAT_NPC_KILLS_TODAY]     = 0;
    $array->[STAT_NPC_DEATHS_TODAY]    = 0;
    $array->[STAT_PLR_KILLS_TODAY]     = 0;
    $array->[STAT_PLR_DEATHS_TODAY]    = 0;
    $array->[STAT_SWINGS_TODAY]        = 0;
    $array->[STAT_BESTHIT_TODAY]       = 0;
    $array->[STAT_BESTROUND_TODAY]     = 0;
    $array->[STAT_MISSES_TODAY]        = 0;
    $array->[STAT_EXPERTS_TODAY]       = 0;
    $array->[STAT_CASTS_TODAY]         = 0;
    $array->[STAT_FAILS_TODAY]         = 0;
    $array->[STAT_NPCHIGH_TODAY]       = 0;
    $array->[STAT_NPCEXP_TODAY]        = 0;
}

sub trivia_add {
    my ($self, $key, $value) = @_; 
    return if($self->{'TYPE'} != OTYPE_PLAYER || $self->{'GAME'} || $self->room()->{'PVPROOM'});

    my $array = $self->{'TRIVIA_STATS'};
    $array->[int($key)] += $value;
    $array->[int($key + 1)] += $value;
}

sub trivia_inc {
    my ($self, $key) = @_;
    return if($self->{'TYPE'} != OTYPE_PLAYER || $self->{'GAME'} || $self->room()->{'PVPROOM'}); 

    my $array = $self->{'TRIVIA_STATS'};
    $array->[int($key)]++;
    $array->[int($key + 1)]++;
}

sub trivia_max {
    my ($self, $key, $value) = @_;
    return if($self->{'TYPE'} != OTYPE_PLAYER || $self->{'GAME'} || $self->room()->{'PVPROOM'});

    my $array = $self->{'TRIVIA_STATS'};
    $array->[int($key)] = max($array->[int($key)], $value);
    $array->[int($key + 1)] = max($array->[int($key+1)], $value);
}


sub get_trivia_stats {
    my $self = shift;

    $self->{'TRIVIA_STATS'} ||= [];
    my $array = $self->{'TRIVIA_STATS'};
    
    my $cap = 
       "{17}---{16}=================={17}Fun Stats{16}================={17}---\n";
    $cap .=
       "                   Today           Total (Overall)\n";
    my ($lev_cur, $lev_today, $lev_pct);
    $lev_cur = $self->get_real_level();
    $lev_today = $lev_cur - $array->[STAT_LEVEL_START_TODAY];
    $lev_pct = $lev_cur ? ($lev_today / $lev_cur) * 100 : 0;

    my ($hp_cur, $hp_today, $hp_pct);
    $hp_cur = $self->base_health();
    $hp_today = $hp_cur - $array->[STAT_HP_START_TODAY];
    $hp_pct = $hp_cur ? ($hp_today / $hp_cur) * 100 : 0;

    my ($mn_cur, $mn_today, $mn_pct);
    $mn_cur = $self->base_mana();
    $mn_today = $mn_cur - $array->[STAT_MN_START_TODAY];
    $mn_pct = $mn_cur ? ($mn_today / $mn_cur) * 100 : 0;

    my ($nkills_today, $nkills_total);
    $nkills_today = $array->[STAT_NPC_KILLS_TODAY];
    $nkills_total = $array->[STAT_NPC_KILLS_TOTAL];

    my ($ave_exp_today, $ave_exp_total);
    $ave_exp_today = $nkills_today ? $array->[STAT_NPCEXP_TODAY] / $nkills_today : 0;
    $ave_exp_total = $nkills_total ? $array->[STAT_NPCEXP_TOTAL] / $nkills_total : 0;

    my ($high_exp_today, $high_exp_total);
    $high_exp_today = $array->[STAT_NPCHIGH_TODAY];
    $high_exp_total = $array->[STAT_NPCHIGH_OVERALL];

    my ($ndeaths_today, $ndeaths_total);
    $ndeaths_today = $array->[STAT_NPC_DEATHS_TODAY];
    $ndeaths_total = $array->[STAT_NPC_DEATHS_TOTAL];
    
    my ($nratio_today, $nratio_total);
    $nratio_today = $ndeaths_today ? sprintf("%0.2f : 1", $nkills_today / $ndeaths_today) : "$nkills_today : 0";
    $nratio_total = $ndeaths_total ? sprintf("%0.2f : 1", $nkills_total / $ndeaths_total) : "$nkills_total : 0";


    my ($pkills_today, $pkills_total);
    $pkills_today = $array->[STAT_PLR_KILLS_TODAY];
    $pkills_total = $array->[STAT_PLR_KILLS_TOTAL];

    my ($pdeaths_today, $pdeaths_total);
    $pdeaths_today = $array->[STAT_PLR_DEATHS_TODAY];
    $pdeaths_total = $array->[STAT_PLR_DEATHS_TOTAL];


    my ($pratio_today, $pratio_total);
    $pratio_today = $pdeaths_today ? sprintf("%0.2f : 1", $pkills_today / $pdeaths_today) : "$pkills_today : 0";
    $pratio_total = $pdeaths_total ? sprintf("%0.2f : 1", $pkills_total / $pdeaths_total) : "$pkills_total : 0";

    my ($hit_today, $hit_total);
    $hit_today = $array->[STAT_BESTHIT_TODAY];
    $hit_total = $array->[STAT_BESTHIT_OVERALL];

    my ($round_today, $round_total);
    $round_today = $array->[27];
    $round_total = $array->[28];
    
    #$round_today = $self->{'TRIVIA_STAT'}->[STAT_BESTROUND_TODAY];
    #$round_total = $self->{'TRIVIA_STAT'}->[STAT_BESTROUND_OVERALL];


    my ($swings_today, $swings_total);
    $swings_today = $array->[STAT_SWINGS_TODAY];
    $swings_total = $array->[STAT_SWINGS_TOTAL];

    my ($miss_today, $miss_total, $misspct_today, $misspct_total);
    $miss_today = $array->[STAT_MISSES_TODAY];
    $miss_total = $array->[STAT_MISSES_TOTAL];
    $misspct_today = $swings_today ? ($miss_today / $swings_today) * 100 : 0;
    $misspct_total = $swings_total ? ($miss_total / $swings_total) * 100 : 0;

    my ($expert_today, $expert_total, $expertpct_today, $expertpct_total);
    $expert_today = $array->[STAT_EXPERTS_TODAY];
    $expert_total = $array->[STAT_EXPERTS_TOTAL];
    $expertpct_today = $swings_today ? ($expert_today / $swings_today) * 100 : 0;
    $expertpct_total = $swings_total ? ($expert_total / $swings_total) * 100 : 0;

    my ($casts_today, $casts_total);
    $casts_today = $array->[STAT_CASTS_TODAY];
    $casts_total = $array->[STAT_CASTS_TOTAL];

    my ($fails_today, $fails_total, $failpct_today, $failpct_total);
    $fails_today = $array->[STAT_FAILS_TODAY];
    $fails_total = $array->[STAT_FAILS_TOTAL];
    $failpct_today = $casts_today ? ($fails_today / $casts_today) * 100 : 0;
    $failpct_total = $casts_total ? ($fails_total / $casts_total) * 100 : 0;

    my ($print_heading, $print_row);

    $print_heading = "{17}-={16}%s{17}=-\n";
    $print_row = "{6}%8s{17}: {16}%14s  %14s\n";
### YAY WE START PRINTING

    $cap .= sprintf($print_heading, "Vitals");
    $cap .= sprintf($print_row, "Levels", $lev_today, $lev_cur);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $lev_pct), "");
    $cap .= sprintf($print_row, "Health", $hp_today, $hp_cur);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $hp_pct), "");
    $cap .= sprintf($print_row, "Mana", $mn_today, $mn_cur);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $mn_pct), "");

    $cap .= "\n";

    $cap .= sprintf(" " . $print_heading, "NPC");
    $cap .= sprintf($print_row, "Ave. Exp", int($ave_exp_today), int($ave_exp_total));
    $cap .= sprintf($print_row, "High", $high_exp_today, $high_exp_total);
    $cap .= sprintf($print_row, "Kills", $nkills_today, $nkills_total);
    $cap .= sprintf($print_row, "Deaths", $ndeaths_today, $ndeaths_total);
    $cap .= sprintf($print_row, "Ratio", $nratio_today, $nratio_total);

    $cap .= "\n";

    $cap .= sprintf($print_heading, "Player");
    $cap .= sprintf($print_row, "Kills", $pkills_today, $pkills_total);
    $cap .= sprintf($print_row, "Deaths", $pdeaths_today, $pdeaths_total);
    $cap .= sprintf($print_row, "Ratio", $pratio_today, $pratio_total);
    
    $cap .= "\n";

    $cap .= sprintf($print_heading, "Melee");
    $cap .= sprintf($print_row, "Best Hit", $hit_today, $hit_total);
    $cap .= sprintf($print_row, "Round", $round_today, $round_total);
    $cap .= sprintf($print_row, "Swings", $swings_today, $swings_total);
    $cap .= sprintf($print_row, "Misses", $miss_today, $miss_total);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $misspct_today), sprintf("%0.2f%%", $misspct_total));
    $cap .= sprintf($print_row, "Experts", $expert_today, $expert_total);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $expertpct_today), sprintf("%0.2f%%", $expertpct_total));
   
    $cap .= "\n";

    $cap .= sprintf($print_heading, "Magic");
    $cap .= sprintf($print_row, "Casts", $casts_today, $casts_total);
    $cap .= sprintf($print_row, "Fails", $fails_today, $fails_total);
    $cap .= sprintf($print_row, "PCT", sprintf("%0.2f%%", $failpct_today), sprintf("%0.2f%%", $failpct_total));

    return $cap;
}  

sub bound {
    my ($num, $min, $max) = @_;
    $num = $max if $num > $max;
    $num = $min if $num < $min;
    return $num;
}

sub has_monolith {
    my ($self, $monolith_name) = @_;
    # $monolith_name is CASE SENSITIVE, and must be one of:
    #    spectral, pearled, shadow, .. 
    return $main::rock_stats{'monolith_' . $monolith_name} == $self->{'RACE'};
}


sub get_help_on {
    my ($self, $topic) = @_;

    # Extend this yourself using rockobjlocal.pm, if you want.
    $self->log_error("Sorry, the help system has not been configured.");        
}



# LAST, override stuff:
do "$main::base_code_dir/rockobjlocal.pm" if -e "$main::base_code_dir/rockobjlocal.pm"; # damage formula is in here

1;  # so the require or use succeeds

