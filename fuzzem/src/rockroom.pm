use strict;

package room;
@room::ISA = qw( rockobj );
use strict;

sub on_shout {
    # someone shouted in this room!
    my ($self, $who, $shout_text) = @_;
}

sub enviro_idle {
    # Note: This function is only called for rooms where there
    # are activeuids. So don't expect stuff to happen if no players
    # are actually in the room.
}

sub cmd_do {
  my $self = shift;
  &main::rock_shout(undef, "{6}Someone tried making $self->{'NAME'} do a command! Bastards!\n", 1);
  return("A-duh!\n");
}

sub obj_lookup {
    #if($#_ > 0) { &failure("More arguments received than should at obj_lookup"); }
    if($main::objs->{$_[0]}) { return($main::objs->{$_[0]}); }
    print &failure("Tried looking up object ($_[0]).");
    return({});
}

sub on_player_logout {
    # Called when the player definitely logs out. No return value (yet?).
    # Note that this is called before all the other stuff is called (like auto-transporting
    # the user to another room), so if you move them to another room, different logic could
    # occur and other (not-in-this-subroutine) logic might be missed.
    my ($self, $player) = @_;
#    &main::rock_shout(undef,"Unlucky charms for $player->{'NAME'} says mr. $self->{'NAME'} $self->{'ROOM'}\n", 1);
}

sub new {
    ## does standard obj_init stuff (include in "new")
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    #use rockobj_std;  $self->{'ISA'} = ("rockobj_std");
    $self->{'DONTDIE'}=1;
    ## global stuff
    $main::highobj += 1; # add one to highest object.
    bless ($self, $class);
    $main::objs->{$main::highobj}=$self; # map to objs.
    delete $self->{'DONTDIE'};
    #print "Mapping self to $main::highobj.\n";
    #### THE STD STUFF
    $self->{'OBJID'}  = $main::highobj;
    $self->{'NAME'}   = 'Untitled Room';# character's name.
    $self->{'BIRTH'}  = time; # time value for birth.
    $self->{'INV'}    = {};   # room's inventory.
    $self->{'DESC'}   = 'This room has been created from out of the void.';
    $self->{'TER'}=''; # let map-setter set it
    $self->{'BANK'}='';
    ####
    $self->{'DB'}=''; $self->{'OWN'}=''; 
    #$self->{'N'}=undef; $self->{'E'}=undef; $self->{'S'}=undef; $self->{'W'}=undef;     # refers to room object numbers
    #$self->{'NE'}=undef; $self->{'NW'}=undef; $self->{'SE'}=undef; $self->{'SW'}=undef; # refers to room object numbers
    #$self->{'U'}=undef; $self->{'D'}=undef; # each has array of 0:roomto, 1: objecttype, 2->? free
    $self->{'EXITS'}=0; $self->{'TYPE'}=-1; #$self->{'MAXINV'}=100; $self->{'GRAV'}=9.8; # (m/s)
    #### assigns vals
    my ($key, %varray); %varray = @_;
    foreach $key (keys(%varray)) { $self->{$key}=$varray{$key}; print "Set $key to $varray{$key}.\n"; }
    ####
    return $self;
}

sub inv_free { 	return 10;	}

sub auto_bless {
    if(ref($_[0]) ne 'room') {
        return 0; 
    } elsif($_[0]->{'BLESS'}) {
        bless $_[0], $_[0]->{'BLESS'};
    } elsif(length $_[0]) {
      for ($_[0]->{'TER'}) {
        if( $_ == 6 || $_ == 17 || $_ == 18 ) { # water-shallow, water-medium, water-deep
            bless($_[0], 'min_pool_room');
            return 1;
        } elsif ($_ == 15) {  # tundra
            bless($_[0], 'tundra_room');
            return 1;
        } elsif ($_ == 21) {  # underwater
            bless($_[0], 'under_water_room');
            return 1;
        } elsif ($_ == 23) {  # flatlands
            bless($_[0], 'flatlands_room');
            return 1;
        }
      }
    }
}


# There seems to be some confusion about what the room exit array means.
# Granted, I coded that a while ago, so don't hurt me for its lameness. Here's
# the cheat sheet.
#
# $dir->[0]:  The room *NUMBER* (not object) that the direction leads to.
# $dir->[1]:  If true, the exit is INVISIBLE. If false, the exit is visible.
# $dir->[2]:  If nonzero (should always be 0 or greater, or DIE), the number
#             of times someone can use this exit before it closes.
# $dir->[3]:  The timestamp (seconds since epoch) when the exit is closed.
#

sub is_exit_visible {
    # Returns true if the exit exists and is visible.
    my ($self, $dir) = @_;
    #$dir = uc $dir;
    return defined($self->{$dir}) && !$self->{$dir}->[1] ? 0 : 1;
}

sub set_exit_visibility {
    my ($self, $dir, $is_visible) = @_;
    die "must pass direction" unless $dir;
    die "must pass visibility" unless $is_visible;
    #$dir = uc $dir;
    return 0 unless defined($self->{$dir}) && ref($self->{$dir});
    $self->{$dir}->[1] = !$is_visible;
    return 1;
}

sub set_exit_disappear_after {
    my ($self, $dir, $sec) = @_;
    die "must pass direction" unless $dir;
    die "must pass sec" unless $sec;
    #$dir = uc $dir;
    return 0 unless defined($self->{$dir}) && ref($self->{$dir});
    
    # set the exit to disappear after $sec sec
    $self->{$dir}->[3] = time + $sec;
    
    # set timer to re-check and hide exit
    $main::eventman->enqueue($sec, \&room::check_for_disappearing_exits, $self);

}

#  evalll $_[0]->room()->set_exit_disappear_after("U", 5);

sub check_for_disappearing_exits {
    # Checks whether I have any exits that should disappear.
    # if there are any, they disappear. Voila!

    my $self = shift;
    if($self->{'EXITS'}) { 
      foreach my $dir (@main::dirlist) {
          if (($self->{$dir}->[0] > 0) && $self->{$dir}->[3] && $self->{$dir}->[3] <= time){
              # aha, we should disappear!
			  $self->room_sighttell("The $main::dirernmap{$dir} exit disappears.\n") unless $self->{$dir}->[1] == 1;
			  $self->{$dir}->[1] = 1; # wall it off
			  $self->{$dir}->[3] = 0; # reset timer
              $self->exits_update();
          }
       }
	   
	   $self->exits_update();
    }
}


sub exits_hash {
  # returns hash of {'EXIT'}=ROOMobj
  my $self = shift;
  my (%a, $dir);
  if($self->{'EXITS'}) { 
    foreach $dir (@main::dirlist) {
        if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){ $a{$dir}=$main::map->[$self->{$dir}->[0]]; }
    }
  }
  return(%a);
}

sub room_str { "Cannot define room string for rockroom\n" }

sub cby_desc {
   # users contained by me see this:
   my ($self, $obj) = @_;
   # create room description
   my $room = $main::map->[$obj->{'ROOM'}]; # this should usually/always be the same as $self
   my $cap .= '{3}'.$room->{'NAME'}.($room->{'HINT'}?"*":"")."\n";
   if(!$obj->pref_get('brief room descriptions')) { $cap .= '{2}'.&rockobj::wrap('', '', $self->desc_hard)."\n"; }
   $cap .= join('', $self->room_inv_list($obj,0));
   $cap .= '{16}' . $self->exits_list($obj->{'FRM'});
   return(\$cap);
}

sub rooms_adj {
  # returns array of adjacent room objects
  my $self = shift;
  my (@a, $dir);
  if($self->{'EXITS'}) { 
    foreach $dir (@main::dirlist) {
        if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){ push(@a, $main::map->[$self->{$dir}->[0]]); }
    }
  }
  return(@a);
}

sub exits_adj {
  # returns array of adjacent room objects
  my $self = shift;
  my (@a, $dir);
  if($self->{'EXITS'}) { 
    foreach $dir (@main::dirlist) {
        if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){ push(@a, $dir); }
    }
  }
  return(@a);
}

sub exits_adjref {
  # returns array of adjacent room directions
  my $self = shift;
  my (@a, $dir);
  if(!$self->{'EXITS'}) { return undef; }
  
  foreach $dir (@main::dirlist) {
     # add direction if we can go that way to get to a room, and
     # that direction is not invisible
     if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){ push(@a, $dir); }
  }
  
  return(\@a);
}

sub exits_list {
    ## returns string listing the exits in each room.
    my $self = $_[0];
    if($self->{'EXITS'} == 0) { return("There is no escape.\n"); }
    my ($cap, $e);
    if($self->{'EXITS'}==1) { $cap = 'An exit lies to the'; }
    else { $cap = 'Exits lie to the'; }
    foreach my $dir (@main::dirlist) {
      if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){
	    $e = ($_[1] eq $dir);
        $cap .= "$main::camefrommap[$e] $main::dirlongmap{$dir}$main::camefrommapb[$e],";
      }
    }
    $cap = substr($cap, 0, length($cap)-1) . ".\n";
    return($cap);
}

sub web_exits_list {
    ## returns string listing the exits in each room.
    my $self = shift;
    if($self->{'EXITS'} == 0) { return("There is no escape.\n"); }
    my ($dir, $cap);
    if($self->{'EXITS'}==1) { $cap = 'An exit lies to the'; }
    else { $cap = 'Exits lie to the'; }
    foreach $dir (@main::dirlist) {
      if( ($self->{$dir}->[0] > 0) && !$self->{$dir}->[1]){ $cap .= ' '.&main::w2_link_cmd("$dir", $main::dirlongmap{$dir}, "Go $main::dirlongmap{$dir}!", '#3333FF').','; }
    }
    $cap = substr($cap, 0, length($cap)-1) . ".\n";
    return($cap);
}

sub room_assign {
 my ($self, $x, $y, $z, $m, $mn) = @_;
 #print "$self->{'NAME'} ($self->{'ROOM'}) Received call: $z, $x, $y, $m, $mn.\n";
 my ($key); # $mn means mapnumber..should change each time we define a new map
 if($self->{'MN'}==$mn) { return; }
 #if (!( ($self->{'MN'} != $mn) || ($self->{'X'} != $x) 
 #       || ($self->{'Y'} != $y) || ($self->{'Z'} != $z) || ($self->{'M'} != $m)
 #   )) { return; }
 # SET ROOM UP
 ($self->{'X'} = $x); ($self->{'Y'} = $y); ($self->{'Z'} = $z); ($self->{'MN'} = $mn); ($self->{'M'} = $m);
 $main::exitmap->{$self->{'M'}}->{$self->{'Z'}}->{$self->{'X'}}->{$self->{'Y'}}=$self->{'ROOM'};
 # SET MAX'S
 if($x > $main::maxx) { $main::maxx = $x; }
 elsif($x < $main::minx) { $main::minx = $x; }
 if($y > $main::maxy) { $main::maxy = $y; }
 elsif($y < $main::miny) { $main::miny = $y; }
 if($z > $main::maxz) { $main::maxz = $z; }
 elsif($z < $main::minz) { $main::minz = $z; }
 foreach $key (@main::dirlist) {
   # If that direction leads somewhere
   if ($self->{$key}->[0] && $main::map->[$self->{$key}->[0]]) { 
       $main::map->[$self->{$key}->[0]]->room_assign(&{$main::diroffset->{$key}} ($x,$y,$z), $m, $mn);
   } elsif ($self->{$key}->[0]) { 
       print "Error: $self->{'NAME'} ($self->{'ROOM'}) Has unconnectable link $key.\n";
   }
 }
 return;
}

sub can_enter ($playerobject) {
    # passed player/npc/item object. returns 1 if they can enter. 0 if not.
    #my $self = shift;
    #my $obj = shift;
    if($_[0]->{'NOMOB'} && ($_[1]->{'TYPE'} == 2)) { return(0); }
    if(("$_[0]->{'RACEONLY'}" ne "") && ($_[1]->{'RACE'} != $_[0]->{'RACEONLY'})) { $_[1]->log_append("{2}A genetic force prevents you from moving in that direction.\n"); return(0); }
    
    if ($_[1]->{'TYPE'} == 1) { # Let scryball in. Maybe NPCs shouldn't be let through?
        #if(($_[0]->{'MINLEV'}) && ($_[1]->{'LEV'} < $_[0]->{'MINLEV'})) { $_[1]->log_append("{2}You are not of high enough level to move in that direction.\n"); return(0); }
        if(($_[0]->{'MINLEV'}) && ($_[1]->get_real_level() < $_[0]->{'MINLEV'})) { $_[1]->log_append("{2}You are not of high enough level to move in that direction.\n"); return(0); }
        if(($_[0]->{'MAXLEV'}) && ($_[1]->{'LEV'} > $_[0]->{'MAXLEV'})) { $_[1]->log_append("{2}You are of too high a level to move in that direction.\n"); return(0); }
    }
    
    return(1);
}

sub can_exit($dir, $playerobject, [Player's Request]) {
    # passed player/npc/item object. returns 1 if they can enter. 0 if not.
    my ($self, $dir, $obj, $preq) = @_; $dir = uc($dir);
    return 0 if $obj->{'SENT'};

    if ( ($main::dirlongmap{$dir}) && ( (!$self->{$dir}->[0]) || $self->{$dir}->[1]>0 ) ){
        # can't exit if there's no room to go to :)
        $obj->log_append("{1}You smack into the $main::dirwall{$dir}!\n");
        $obj->room_sighttell("{1}$obj->{'NAME'} crashes into the $main::dirernmap{$dir} $main::dirwall{$dir}!\n");
        #$obj->log_suspicious_activity("Ran into wall.", 35)
            #unless $obj->{'GAME'};

        unless ($obj->{'TYPE'} != 1 || $obj->{'IMMORTAL'}) {
            $obj->{'HP'} = int ($obj->{'HP'} * .9)
                unless $obj->{'HP'} <= $obj->{'MAXH'}*.4;
            #$obj->make_tired(1 + int rand 2);
        }

        return 0;
    } elsif ($preq && defined($obj->{'CONTAINEDBY'}) && (&obj_lookup($obj->{'CONTAINEDBY'})->{'TYPE'} >= 0)) {
        $obj->log_append("{7}You cannot flee while ".$obj->{'NAME'}." has you!\n");
        return 0;
    } else { return 1; } # otherwise it's kew'
    return(1);
}

sub exit_make {
 # creates exit of dir (N, S, E, W, U, D, etc) leading to room roomnum. returns old roomnum or 0 if none existed.
 my ($self, $dir, $roomnum) = @_; $dir = uc($dir);
 my $oldroom = $self->{$dir}->[0];
 $self->{$dir}->[0]=$roomnum*1;
 if($oldroom == 0) { $self->{'EXITS'} += 1; }
 return($oldroom*1);
}

sub exits_update {
  # updates exit count. returns new count of exits.
  my $self = shift;
  $self->{'EXITS'} = ($self->{'SW'}->[0] > 0) + ($self->{'SE'}->[0] > 0) + ($self->{'NW'}->[0] > 0) + ($self->{'NE'}->[0] > 0) + ($self->{'U'}->[0] > 0);
  $self->{'EXITS'} += ($self->{'N'}->[0] > 0) + ($self->{'S'}->[0] > 0) + ($self->{'E'}->[0] > 0) + ($self->{'W'}->[0] > 0) + ($self->{'D'}->[0] > 0);
  $self->{'EXITS'} -= ($self->{'SW'}->[1]*1) + ($self->{'SE'}->[1]*1) + ($self->{'NW'}->[1]*1) + ($self->{'NE'}->[1]*1) + ($self->{'U'}->[1]*1);
  $self->{'EXITS'} -= ($self->{'E'}->[1]*1) + ($self->{'W'}->[1]*1) + ($self->{'S'}->[1]*1) + ($self->{'N'}->[1]*1) + ($self->{'D'}->[1]*1);
  return($self->{'EXITS'});
}

sub exit_leadsto {
    # returns the roomnum that the exit lead to. (otherwise -1)
    # $dir is the directional string (e.g. NE, W, S, whatever)
    my ($self, $dir) = @_;
    return defined($self->{uc($dir)}) ? int $self->{uc($dir)}->[0] : -1;
}

sub get_room_by_exit {
    # returns the *room object* the exit lead to. (otherwise undef)
    # $dir is the directional string (e.g. NE, W, S, whatever)
    my ($self, $dir) = @_;
    my $roomnum = $self->exit_leadsto($dir);
    return undef unless $roomnum >= 0;
    if ($roomnum < @$main::map) {
       return $main::map->[$roomnum];
    }
}
# evalll $_[0]->room->get_room_by_exit('D');

sub rockobj::room_inv_list ( dontmatchOBJ, [ALL] ){
   # Returns as little as 0 and up to 2 lines of text stating the lifeforms in the room (if any).
   # Args: ALL = sees everything in room, visible or not. (1 or 0)
   my $k;
   my ($self, $dontmatch, $all) = @_;
   my (@chars, @items, $name, $type, $vis, $chars, $items, @npcs, $npcs);

   $all = 1 if ($dontmatch->{'ADMIN'});
   my $some = 0;

   foreach my $item (values(%{$self->{'INV'}})) {
     ($type, $name, $vis) = ($item->{'TYPE'}, ($item->{'NICK'} || $item->{'NAME'}), $item->{'SENT'} || !$item->is_invis($dontmatch));
     
     next if ($dontmatch eq $item); # dont show what we dont wanna see
     
     if(!$vis && $dontmatch->skill_has(86) && $item->{'CAN_LIFT'} && $item->{'DLIFT'} ){
	     $some = 1
     }
     
     if( ($vis+$all+$some) ) {
	     if(!$vis && $some && $dontmatch->skill_has(86) && $item->{'CAN_LIFT'} && $item->{'DLIFT'}  ){$name = "{16}$name\{12}";}
	     
	     if($all){
		     $name = "$name (invisible)" unless $vis;
	     }
	     
        if($type == 0) { push(@items, $name); }
        elsif($type == 2) { push (@npcs, $name); }
        elsif($type > 0) {
            $name = "$name *dead*" if ($item->{'HP'} <= 0);
            
            if($self->{'SAFE'}) {
                # no formatting change for safe rooms
            } elsif ($main::allyfriend[$item->{'RACE'}]->[$dontmatch->{'RACE'}] && !$self->{'MONOLITH'} && !$self->{'PVPROOM'}) {
                $name = "{15}$name";
            } elsif (!$dontmatch->cant_aggress_against($item, 1)) { # dont care about which room we're in (remember peekiness?)
                $name = uc "{11}$name";
            } else {
                $name = "{1}$name";
            }
            push @chars, $name;
            if ($item->is_mirage_visible()) {
                # mirage
                push @chars, $name;
            }

        }
     }
   }
   if($self->{'CRYL'}) { push(@items, "$self->{'CRYL'} cryl");  }
   if(@chars) {
       $chars = '{5}Players in room: '.($self->{'SAFE'}?'{14}':'{15}') . join(', ',@chars)."{5}.\n";
   }
   if(@items) {
       $items = &rockobj::wrap('', '   ', '{12}Items in room: ' . join(', ',@items).'.')."\n";
   }
   if(@npcs) {
       $npcs = &rockobj::wrap('', '   ', '{6}NPCs in room: {17}' . join(', ',@npcs).'.')."\n";
   }
   return($chars, $npcs, $items);
}

sub web_room_inv_list ( dontmatchOBJ, [ALL] ){
   # Returns as little as 0 and up to 2 lines of text stating the lifeforms in the room (if any).
   # Args: ALL = sees everything in room, visible or not. (1 or 0)
   my $k;
   my ($self, $dontmatch, $all) = @_;
   my ($key, @chars, @items, $name, $type, $vis, $chars, $items, @npcs, $npcs);
   foreach $key (values(%{$self->{'INV'}})) {
     ($type, $name, $vis) = ($key->{'TYPE'}, ($key->{'NICK'} || $key->{'NAME'}), !$key->is_invis($dontmatch));
     if( ($vis || $all) && ($dontmatch ne $key) ) {
       # if($type == 0) { push(@items, &main::w2_link_cmd("g $name", $name, "Get $name!", 'GREEN')); }
       # elsif($type == 2) { push (@npcs, &main::w2_link_cmd("a $name", $name, "Attack $name!", '#6600CC')); }
       # elsif($type > 0) { if($key->{'RACE'}!=$dontmatch->{'RACE'}) { push(@chars, &main::w2_link_cmd("a $name", $name, "Attack $name!", '#990099')); } else { push(@chars, $name); } }
        if($type == 0) { 
            if($key->{'PORTAL'}) { push(@items, &main::w2_link_cmd("go $name", $name, "Enter $name!")); }
            else { push(@items, &main::w2_link_cmd("g $name", $name, "Get $name!")); }
        }
        elsif($type == 2) { push (@npcs, &main::w2_link_cmd("a $name", $name, "Attack $name!")); }
        elsif($type > 0) { if(!$main::allyfriend[$key->{'RACE'}]->[$dontmatch->{'RACE'}] && !$self->{'SAFE'}) { push(@chars, &main::w2_link_cmd("a $name", $name, "Attack $name!")); } else { push(@chars, $name); } }
     }
   }
   if($self->{'CRYL'}) { push(@items, &main::w2_link_cmd("loot", "$self->{'CRYL'} cryl", "Get $self->{'CRYL'} Cryl!", '#DD7700')); }
   if(@chars) {
       $chars = ($self->{'SAFE'}?'{14}':'{16}').'Players in room: ' . join(', ',@chars).'.'."\n";
   }
   if(@items) {
       $items = '{12}Items in room: ' . join(', ',@items).".\n";
   }
   if(@npcs) {
       $npcs = '{6}NPCs in room: ' . join(', ',@npcs).'.'."\n";
   }
   return($chars,$npcs,$items);
}

sub room_flatten {
   my $self = shift;
   my ($dir, $cap, $key, $kcount);
   # flatten exits
   foreach $dir (@main::dirlist) {
      if($self->{$dir}->[0] > 0){ $cap .= "$dir=".$self->{$dir}->[0].'&'; }
      for(my $n=1; $n<=10; $n++) { 
         if(defined $self->{$dir}->[$n])  { $self->{"$dir-$n"}=$self->{$dir}->[$n]; }
      }
   }
   # add all the regular ones
   foreach $key (keys(%{$self})) {
      #next if (!$self->{$key}); oops.. ROOM=0 sucks :-)
       if(!ref($self->{$key}) && (!$main::flatten_dont{$key})) { $cap .= $key . '=' . $self->{$key}.'&'; }
       elsif($main::flatten_mayberef{$key}) { $cap .= $key . '=' . ${$self->{$key}}.'&'; }
   }
   $cap = substr($cap,0,length($cap)-1);
   return($cap);
}

sub cleanup_inactive {
  my $self = shift;
  my (@objnames, $lastobj);
  foreach my $obj ($self->inv_objs) {
    #if(!$main::activeusers->{$obj->{'OBJID'}} && ($obj->{'TYPE'} != 1)) { $obj->room_tell('{16}'.$obj->{'NAME'}.'{6} is sucked into the warp of nonexistance.'."\n"); $obj->obj_dissolve; }
    if( (!$main::activeusers->{$obj->{'OBJID'}} || !$obj->{'IP'}) && (!$obj->{'PORTAL'})) { 
         push(@objnames, $obj->{'NAME'});
         $obj->obj_dissolve;
         $self->{'NULLIFIED'}++;
    }
  }
 # ONLY IF ITS BASED ON ROOM, NOT CBY $self->room_sighttell('{6}Cleaning Nullity: {16}'.join(', ')."\n");
  if($self->{'NULLIFIED'}>2) { &main::spawn_stuff; delete $self->{'NULLIFIED'}; }
  delete $self->{'CRYL'};
  return;
}

sub room_stamp {
  # stamps room with object.
  my ($self, $obj) = @_;
  $self->{'OWN'}=$obj->{'GRP'};
  return;
}

sub tracks_make {
  my ($self, $dir, $creator_obj) = @_;
  if(!$main::dirwall{uc($dir)}) { return; }
  my (@t, $obvious);
  # remove excess tracks; removes one more than the room should have,
  # 'cuz we're going to fill that one up with my new tracks.
  while ($#{$self->{'TRX'}} > 1) { shift(@{$self->{'TRX'}}); }
  # figure out how obvious the tracks'll be.
  $obvious = int rand(100) + 1;
  # assign new value to last set of track array.
  @{$self->{'TRX'}->[$#{$self->{'TRX'}}+1]}=(uc($dir), $creator_obj->{'OBJID'}, $obvious);
  return;
}

sub tracks_seen {
  # checks if it's seen $objid in its tracks. if so, returns (direction-travelled, obviousness of tracks)
  my ($self, $objid) = @_;
  my ($n, $maxn); $maxn = $#{$self->{'TRX'}};
  for ($n=0; ($n<=2 && $n <= $maxn); $n++) {
   if($self->{'TRX'}->[$n]->[1] == $objid) { return($self->{'TRX'}->[$n]->[0], $self->{'TRX'}->[$n]->[2]); }
  }
  return(undef);
}

sub tracks_random {
  # picks random track..if visible, returns track array (dir travelled, objid, obviousness)
  # pct is the pct accuracy in noticing the track.
  my ($self, $pct) = @_;
  my $rand = int rand($#{$self->{'TRX'}}+1);
  if($self->{'TRX'}->[$rand] && ($self->{'TRX'}->[$rand]->[2] > rand($pct+1)) ) { 
    # perhaps warn victim that his tracks were picked up?!
    #if($main::objs->{$objid})
    return(@{$self->{'TRX'}->[$rand]});
  }
  return(undef);
}

sub tracks_cover {
  # erases tracks created by $objid
  my ($self, $objid) = @_;
  my ($n, $maxn); $maxn = $#{$self->{'TRX'}};
  for ($n=0; ($n<=2 && $n <= $maxn); $n++) {
   if($self->{'TRX'}->[$n]->[1] == $objid) { $self->{'TRX'}->[$n] = undef; } # delete array
  }
  $self->array_rotate(\@{$self->{'TRX'}}); # get rid of unsightly undefined stuff.
  return;
}

sub tracks_list {
  # returns cap of tracks detected
  my ($self, $looker) = @_;
  my ($n, $cap, $o, $maxn); $maxn = $#{$self->{'TRX'}};
  for ($n=0; ($n<=2 && $n <= $maxn); $n++) {
   if( rand(1) > $looker->fuzz_pct_skill(7) ) { next; }
   $o = &rockobj::obj_lookup($self->{'TRX'}->[$n]->[1]);
   if($o->{'NAME'}) { $cap .= "{16}$o->{'NAME'}\'s {6}tracks trail off in the {2}$main::dirernmap{$self->{'TRX'}->[$n]->[0]} {6}direction.\n"; }
  }
  if(!$cap) { $cap = "{4}There are no noticible tracks on the ground.\n"; }
  return($cap);
}

sub tracks_rlist {
  # returns cap of tracks detected
  my ($self, $looker) = @_;
  my ($n, $cap, $o, $maxn); $maxn = $#{$self->{'TRX'}};
  for ($n=0; ($n<=2 && $n <= $maxn); $n++) {
   if( rand(1) > $looker->fuzz_pct_skill(8) ) { next; }
   $o = &rockobj::obj_lookup($self->{'TRX'}->[$n]->[1]);
   if($o->{'NAME'} || $main::races[$o->{'RACE'}]) { $cap .= "{16}A $main::races[$o->{'RACE'}]\'s {6}tracks trail off in the {2}$main::dirernmap{$self->{'TRX'}->[$n]->[0]} {6}direction.\n"; }
  }
  if(!$cap) { $cap = "{4}There are no noticible tracks on the ground.\n"; }
  return($cap);
}

sub safe_racially (asker object){
 # returns percent safety
 my ($self, $whoasked) = @_;
 my ($obj, $lfs, $fs);
 foreach $obj ($self->inv_objs) {
   if( ($obj->{'TYPE'}!=1) && ($obj->{'TYPE'}!=2) ) { next; }
   $lfs++; if($main::allyfriend[$obj->{'RACE'}]->[$whoasked->{'RACE'}]) { $fs++; }
 }
 if(!$lfs) { $lfs++; $fs=0; }
 return($fs/$lfs);
}

sub tell {
 ## Tells stuff to the objects in the room.
 my ($self, $type, $atk, $dec, $crossroom) = (shift, shift, shift, shift, shift); my @args = @_;
 ## type = [1..?]; HANDLES message while atk >= 1.
 ## (can be interpreted as 'first instance, second instance,' etc.. (attack)
 ## passes message to surrounding rooms at decay dec while dec >= 1.
 ## crossroom identifies room it came from. '' if crossroom, undef if no cross.
 
 
 # set up tellargs for speedity
 my ($obj, @tellargs); @tellargs = ($type, $atk, $dec, $crossroom, @args);

 # handle attack, decay.
 $atk += 1; $dec -= 1;

 if ($dec >= 1) {
    # pass to neighboring rooms if i should.
    if(defined($crossroom)) {
     my ($dir);
     foreach $dir (@main::dirlist) {
       if( ($self->{$dir}->[0] > 0) && ($dir ne $crossroom) ){ 
            $main::map->[$self->{$dir}->[0]]->tell($type, $atk, $dec, $main::diroppmap{$dir}, @args);
       }
     }
    }
 }

 # handle if [the] attack [passed to it] was at least 1
 if($atk >= 2) {
    
    # pass action onto inventory items.. ONLY If i'm a room (and I am)
    if($self->{'TYPE'} == -1) { 
      my @tellplayers;
      foreach $obj ($self->inv_objs) { 
        if($obj->{'TYPE'} == 1) { unshift(@tellplayers, $obj); }
        else { push(@tellplayers,$obj); }
      }
      foreach $obj (@tellplayers) {
        $obj->tell(@tellargs);
      }
    }
 }

 $self->SUPER::tell(@tellargs);
 
 return;
}

sub room_trailto_make {
  # triggers a plane-wide room map.
  my $self = shift;
  my ($msgid, $dir);
  $msgid = &main::msgid_new;
  # then spew it
  $self->room_trailto_carry($msgid, $self->{'ROOM'}, 0);
  return;
}

sub room_trailto_carry (msg_id, room_target, number_away_from_room){
  my ($self, $msgid, $r, $n, $dir) = @_;
  #print "$self->{'NAME'} (room $self->{'ROOM'}) received Msgid $msgid: Target $r, $n away.\n";
  $self->{'TRAILTO'}->{$r}=$n++;
  $self->{'MSGID'}=$msgid;
  foreach $dir (@main::dirlist) {
     if( ($self->{$dir}->[0] > 0) && ( ($main::map->[$self->{$dir}->[0]]->{'MSGID'} != $msgid) || ($main::map->[$self->{$dir}->[0]]->{'TRAILTO'}->{$r}>$n) ) ){ 
        $main::map->[$self->{$dir}->[0]]->room_trailto_carry($msgid, $r, $n);
     }
  }
  return;
}

sub inv_store_objs {
   # Returns array of objects in store's inventory.
   my $self = shift;
   if(!$self->{'STORE'}) { return(); }
   return( values %{$main::objs->{$self->{'STORE'}}->{'INV'}} );
}

sub players_here {
  my $self = shift;
  my ($o, $players);
  foreach $o ($self->inv_objs) {
    if($o->{'TYPE'}==1) { $players++; }
  }
  return(int $players);
}


sub mapme {
  my ($self, $player) = @_;
  
  my ($cap, @cap);
  
  if( ($self->{'NW'}->[0] > 0) && !$self->{'NW'}->[1] ){ $cap = ' ' } else { $cap .= '{16}/'; }
  if( ($self->{'N'}->[0] > 0) && !$self->{'N'}->[1] ){ $cap .= '   ' } else { $cap .= '{6}---'; }
  if( ($self->{'NE'}->[0] > 0) && !$self->{'NE'}->[1] ){ $cap .= ' ' } else { $cap .= '{16}\\'; }
  push(@cap, $cap);
  if( ($self->{'W'}->[0] > 0) && !$self->{'W'}->[1] ){ $cap = ' ' } else { $cap = '{6}|'; }
  if($player->{'ROOM'} == $self->{'ROOM'}) { $cap .= ' {1}o '; } else { $cap .= sprintf('{13}%3s', $self->{'ROOM'}); }
  if( ($self->{'E'}->[0] > 0) && !$self->{'E'}->[1] ){ $cap .= ' ' } else { $cap .= '{6}|'; }
  push(@cap, $cap);
  if( ($self->{'SW'}->[0] > 0) && !$self->{'SW'}->[1] ){ $cap = ' ' } else { $cap = '{16}\\'; }
  if( ($self->{'S'}->[0] > 0) && !$self->{'S'}->[1] ){ $cap .= '   ' } else { $cap .= '{6}___'; }
  if( ($self->{'SE'}->[0] > 0) && !$self->{'SE'}->[1] ){ $cap .= ' ' } else { $cap .= '{16}/'; }
  push(@cap, $cap);
  return(@cap);
}


sub mapsurrounding {
  my $self = shift;
  my (@concat, @temp);
  
  my $f = $self->{'Z'};
  
  my ($maxy, $minx) = ($self->{'Y'}+1, $self->{'X'}-1);
  my $miny = $maxy-2; my $maxx = $minx+2;

  ## iterate through ys
  for (my $n=$maxy; $n>=$miny; $n--) {
     ## iterate through x..
     for (my $m = $minx; $m<=$maxx; $m++) {
       my $roomid = $main::exitmap->{$self->{'M'}}->{$f}->{$m}->{$n};
       if ($roomid && $main::map->[$roomid]) { @temp = $main::map->[$roomid]->mapme($self); } else { @temp = @main::blankmap; }
       for(my $x = 0; $x<3; $x++) { $concat[abs($n-$maxy)*3+$x] .= $temp[$x]; }
     }
   #  for(my $x = 0; $x<3; $x++) { $concat[($n-$miny)*3+$x] .= "\n"; }
  }
  return(join("\n", @concat)."\n");
}



package armageddon_room;
@armageddon_room::ISA = qw( room );
use strict;

sub can_enter {
    if (!&room::can_enter(@_)) { return(0); }
    
    return $main::rock_stats{'armageddon_is_possible'};
}


package ozone_room;
@ozone_room::ISA = qw( room );
use strict;

sub enviro_idle {
    my $self = shift;
    
    foreach my $victim ($self->inv_spobjs()) { $self->c_scorch($victim); }
}

sub c_scorch {
    my ($self, $victim) = @_;
    return if ($victim->effect_has(50) || $victim->{'TYPE'} != 1);
    my $dam = int ($victim->{'MAXH'}*(.3 + rand .3));
    $victim->room_sighttell("{3}$victim->{'NAME'} is hit with a burst of scorching rays from the planet's twin suns.\n");
    $victim->log_append("{13}Scorching rays from the twin suns of the planet beat down upon you, causing $dam damage!\n");
    $self->attack_gen($victim, $dam);
}

sub can_enter($playerobject) {
    if(!&room::can_enter(@_)) { return(0); }
 
    # plan a scorching
    $main::eventman->enqueue(0, \&c_scorch, $_[0], $_[1]);
 
    return(1);
}


package course_class_room;
@course_class_room::ISA = qw( room );
use strict;

sub can_exit($dir, $playerobject, [Player's Request]) {
 # passed player/npc/item object. returns 1 if they can enter. 0 if not.
 my ($self, $dir, $obj, $preq) = @_; $dir = uc($dir);
 if(!&room::can_exit(@_)) { return(0); }
 if( $preq && defined($main::course_log{$self->{'ROOM'}}->{$obj->{'OBJID'}}) ) { 
   if(rand(10)<8) { 
    $obj->log_append(@main::classexit[int rand($#main::classexit + 1)]."\n");
    return(0);
   } else {
    delete $main::course_log{$self->{'ROOM'}}->{$obj->{'OBJID'}};
   }
 } else {
    delete $main::course_log{$self->{'ROOM'}}->{$obj->{'OBJID'}};
 }
 return(1);
}


package room_arena_control;
@room_arena_control::ISA = qw( room );
use strict;

sub can_enter() {
 if($_[1]->{'ADMIN'}) { return 1; }
 #if($_[0]->inv_pobjs() >= 1) { $_[1]->log_append("{1}Sorry, only one person can enter $_[0]->{'NAME'} at a time.\n"); return(0); }
 if(!$_[1]->inv_has_rec(337) && !$_[1]->inv_has_rec(363) && !$_[1]->inv_has_rec(580) && !$_[1]->inv_has_rec(1158)) { 
    $_[1]->log_append("{1}Sorry, but you need a ruler to enter $_[0]->{'NAME'}.\n"); return(0); }
 return(1);
}



package orc_treasure_room;
@orc_treasure_room::ISA = qw( room );
use strict;

sub orc_treasure_room::can_enter($playerobject) {
 if($_[1]->{'ISABOB'}) { return(1); }
 $_[1]->log_append("{12}## A huge forcefield prevents any chance of entrance. ##\n");
 return(0);
}



# evalll bless($main::map->[$_[0]->{'ROOM'}], "avalanche_zone_room");
package avalanche_zone_room;
@avalanche_zone_room::ISA = qw( tundra_room );
use strict;

$avalanche_zone_room::avalanche_in_progress = 0;

sub on_attack {
    # Some attackin' has happened in this room; let's 
    # trigger avalanche here.
    # NOTE: this is triggered once per round
    my ($self, $attacker, $victim, $weapon) = @_;
   $self->start_avalanche() if rand(100) < 10 && !$attacker->got_lucky();
#&main::rock_shout(undef, "Mooo :( :( :(\n");
}

sub on_action {
    my ($self, $who, $action_name, $target_name) = @_;
    $self->start_avalanche() if $action_name eq 'yodel';
}

sub on_shout {
    # someone shouted in this room!
    my ($self, $who, $shout_text) = @_;
    # Random chance of avalanche trigger
    $self->start_avalanche() if rand(100) < 10 && !$who->got_lucky();
}

sub on_say {
    my ($self, $who, $txt) = @_;
    $self->start_avalanche() if rand(100) < 10 && !$who->got_lucky();
}

sub get_players_in_all_avalanche_rooms {
    # returns objects for all players who are inside
    # an avalanche room
    return grep { ref($_->room()) eq 'avalanche_zone_room' } &main::get_players_logged_in();
}

sub avalanche_tell {
    my ($self, $msg) = @_;
    # sends $msg to every logged-in player who's in an avalanche room
    foreach my $player ($self->get_players_in_all_avalanche_rooms()) {
        $player->log_append($msg);
    }
}

sub delay_avalanche_tell {
   my $self = shift;
   my $delay = shift;
   $main::eventman->enqueue($delay, \&avalanche_zone_room::avalanche_tell, $self, @_);
}

sub avalanchize_all {
    my ($self) = @_;
    foreach my $player ($self->get_players_in_all_avalanche_rooms()) {
        $self->avalanchize_player($player);
    }

    # avalanche is done!
    $avalanche_zone_room::avalanche_in_progress = 0;
}

sub avalanchize_player {
    my ($self, $who) = @_;

    # note which room ID they started in (so we know if they moved when they died)
    my $before_room_id = $who->{'ROOM'};

    # 1) Lose 75% HP
    my $hp_lost = abs int ( $who->{'MAXH'} * 0.75 );
    $who->{'HP'} -= $hp_lost;
    $who->log_append("{1}You are inundated in a massive avalanche, burying you dozens of feet under the snow.\n{1}The force of the avalanche has caused $hp_lost damage.\n");

    # blind them
    $who->effect_add(22);

    # ooh ooh, did they die??
    $who->die() if $who->is_dead();

    # if they're still in the original room, then further the punishment
    if ($before_room_id == $who->{'ROOM'}) {
        # Move them to the below-land
#        if (my $below = $self->get_room_by_exit('D')) {
        if (my $below = $who->room()->get_room_by_exit('D')) {
            $who->realm_hmove($who->{'ROOM'}, $below->{'ROOM'});
            $who->room_sighttell("{3}A sudden wave of snow plunges $who->{'NAME'} into the hollow.\n");
            $self->room_sighttell("{3}A sudden wave of snow plunges $who->{'NAME'} into the hollow.\n");
        }
    }
}



# evalll $_[0]->room()->start_avalanche();
sub start_avalanche {
    my ($self) = @_;
    # Tries starting an avalanche unless one has already started.

    # An avalanche is already in progress, so don't go any
    # further.
    return if $avalanche_zone_room::avalanche_in_progress;

    # Note that an avalanche is starting
    $avalanche_zone_room::avalanche_in_progress = 1;

    
# now: 
$self->avalanche_tell("{3}You hear a slight rumbling emanating from the mountains above.\n");

# 10 sec later:
$self->delay_avalanche_tell(10, "{3}The rumbling grows louder, shaking the ground beneath you!\n");

# 15 sec later (from orig):
$main::eventman->enqueue(15, \&avalanche_zone_room::avalanchize_all, $self, @_);
    
}


sub on_player_logout {
    my ($self, $who) = @_;
# NO NEED TO DO THIS ANYMORE! We just keep the player logged in after they DC
# and evil things could happen or not.. it's all good.
#    # If a player logs out in a avalanche zone room, then we
#    # need to do a few things to be mean to them. This will typically
#    # only happen if they hard-disconnect anyway.
#    $self->avalanchize_player($who);
}



package tundra_room;
@tundra_room::ISA = qw( room );
use strict;

sub can_exit {
    # passed player/npc/item object. returns 1 if they can enter. 0 if not.
    my $self = shift;  # remove this for our SUPER call below
    my ($dir, $obj, $preq) = @_; 
    
    if (rand(100) < 40 && !$obj->aprl_rec_scan(591) && !$obj->effect_has(7) && !$obj->effect_has(32) && $preq) { # rand and w/o snowshoes or flight or repulse-grav
        $obj->log_error("The powdery snow underfoot prevents you from moving.");
        $obj->room_sighttell("{3}The deep snow prevents $obj->{'NAME'} from moving.\n");
        return 0;
    }
    
    return $self->SUPER::can_exit(@_);
}



package min_pool_room;
@min_pool_room::ISA = qw( room );
use strict;

# rvs CURRENT <upper-case direction, eg: NE>
# acknowledges terrain 18 (water-deep)

sub min_pool_room::can_enter($playerobject) {
 if(!&room::can_enter(@_)) { return(0); }

 # skill 1,4 is swimming
 my $racemono= 0;
 if( $_[1]->race_owns_monolith('monolith_vindicator') && $_[1]->{'TYPE'}==1 ){
	 $racemono = 1;
     }
     my $tube = 0;
 if($_[1]->aprl_rec_scan(1138)){ $tube = 1; }
 if($_[0]->{'TER'}==18 && !$tube && !$_[1]->{'FX'}->{'7'} && !$_[1]->skill_has(36) && $racemono==0 ) { 
	 $_[1]->log_append("{12}## Go there? Do you want to drown or something?! ##\n"); 
	 return(0); 
	 }
 
 # activate current
 if($_[0]->{'CURRENT'}) { $main::events{$_[0]->{'OBJID'}}=5 unless $main::events{$_[0]->{'OBJID'}}; }
 
 return(1);
}

sub on_event {
 my $self = shift;
 foreach my $o ($self->inv_objs) {
   if ( (($o->{'TYPE'}==1) || ($o->{'TYPE'}==2) || ($o->{'DLIFT'} && $o->{'CAN_LIFT'}) ) && !$o->{'FX'}->{'7'} ) { 
     my $tmpTurns = $o->{'T'};
     $o->log_append("{14}The current pushes you $main::dirlongmap{$self->{'CURRENT'}}.\n"); 
     $o->{'ENTMSG'}='is pulled in';
     $o->{'LEAMSG'}='is pulled out';
     $o->realm_move(uc($self->{'CURRENT'}));
     delete $o->{'ENTMSG'};
     delete $o->{'LEAMSG'};
     $o->{'T'} = $tmpTurns;
     if(!$o->skill_has(36) && (rand(100) < 40)) {
        $self->attack_gen($o, int rand($o->{'MAXH'}/4));
     }
   }
 }
 #my $nextroom;
# if($self->{$self->{'CURRENT'}}->[0] && ($nextroom = $main::map->[$self->{$self->{'CURRENT'}}->[0]]) && $nextroom->{'CURRENT'}) {
     
 #}
}

package room_forest_treetalking;
@room_forest_treetalking::ISA = qw( room );
use strict;

sub can_enter {
    if(!&room::can_exit(@_)) { return(0); }
    my ($self, $who) = @_;
    if($who->inv_has_rec(18)) {
        $who->log_append("{2}A soft whisper erupts from the pine barrier, as it parts to let you pass.\n");
        return 1;
    } else {
        $who->log_append("{2}You are unable to penetrate the thick barrier of pines. It seems as if they are actually moving around to block your passage.\n");
        return 0;
    }
}

package room_doyos;
@room_doyos::ISA = qw( room );
use strict;

sub can_enter {
    if(!&room::can_exit(@_)) { return(0); }
    my ($self, $who) = @_;
    if($who->inv_has_rec(608)) {
        $who->log_append("{2}The barrier erupts, as it parts to let you pass.\n");
        return 1;
    } else {
        $who->log_append("{2}You are unable to penetrate the thick barrier.\n");
        return 0;
    }
}

package bef_thro_room_ice;
@bef_thro_room_ice::ISA = qw( room );
use strict;

sub can_exit($dir, $playerobject, [Player's Request]) {
 # passed player/npc/item object. returns 1 if they can enter. 0 if not.
 my ($self, $dir, $obj, $preq) = @_; $dir = uc($dir);
 if(!&room::can_exit(@_)) { return(0); }
 if( ($dir eq 'U') && (!$obj->inv_has_rec(1290)) ) { $self->zap_dark($obj); return(0); }
 return(1);
}

sub zap_dark() {
 my ($self, $v, $pct) = @_;
 if(!$v->is_dead) {
   my $d = int ( $v->{'MAXH'}*($pct || $self->{'ZAP_PCT'} || .5) + rand(8));
   $v->log_append("{2}A horrible dark energy zaps you as you approach the northern exit, causing $d damage!\n");
   $v->room_sighttell("{2}A horrible dark energy zaps $v->{'NAME'} as $v->{'PRO'} approaches the northern exit, causing $d damage!\n");
   $self->log_append("{2}$v->{'NAME'} has been zapped.\n");
   $v->{'HP'}-=$d;
   if($v->{'HP'}<=0) { $v->die(); }
 }
}

package bef_thro_room;
@bef_thro_room::ISA = qw( room );
use strict;

sub can_exit($dir, $playerobject, [Player's Request]) {
 # passed player/npc/item object. returns 1 if they can enter. 0 if not.
 my ($self, $dir, $obj, $preq) = @_; $dir = uc($dir);
 if(!&room::can_exit(@_)) { return(0); }
 if( ($dir eq 'N') && (!$obj->inv_has_rec(213)) ) { $self->zap_dark($obj); return(0); }
 return(1);
}

sub zap_dark() {
 my ($self, $v, $pct) = @_;
 if(!$v->is_dead) {
   my $d = int ( $v->{'MAXH'}*($pct || $self->{'ZAP_PCT'} || .5) + rand(8));
   $v->log_append("{2}A horrible dark energy zaps you as you approach the northern exit, causing $d damage!\n");
   $v->room_sighttell("{2}A horrible dark energy zaps $v->{'NAME'} as $v->{'PRO'} approaches the northern exit, causing $d damage!\n");
   $self->log_append("{2}$v->{'NAME'} has been zapped.\n");
   $v->{'HP'}-=$d;
   if($v->{'HP'}<=0) { $v->die(); }
 }
}


####### MORBIS PACKAGES #######

package under_water_room;
@under_water_room::ISA = qw( room );
use strict;

# rvs CURRENT <upper-case direction, eg: NE>
# acknowledges terrain 18 (water-deep)

sub under_water_room::can_enter($playerobject) {
 if(!&room::can_enter(@_)) { return(0); }

 my $soldierdive = 0;
 if( $_[1]->race_owns_monolith('monolith_vindicator') && $_[1]->{'SOLDIER'} ){
	 $soldierdive = 1;
     }
 my $mask = 0;
 if($_[1]->aprl_rec_scan(970)){ $mask = 1; }
 if($_[0]->{'TER'}==21 && !$mask && !$_[1]->skill_has(65) && $soldierdive == 0)  { 
 # skill 1,4 is swimming 21
	 $_[1]->log_append("{12}## You hold your breath? HA! ##\n"); 
	 return(0); 
	 }
 
 # activate current
 if($_[0]->{'CURRENT'}) { $main::events{$_[0]->{'OBJID'}}=5 unless $main::events{$_[0]->{'OBJID'}}; }
 
 return(1);
}

sub on_event {
 my $self = shift;
 foreach my $o ($self->inv_objs) {
   if ( (($o->{'TYPE'}==1) || ($o->{'TYPE'}==2) || ($o->{'DLIFT'} && $o->{'CAN_LIFT'}) ) && !$o->{'FX'}->{'7'} ) { 
     my $tmpTurns = $o->{'T'};
     $o->log_append("{14}The current pushes you $main::dirlongmap{$self->{'CURRENT'}}.\n"); 
     $o->{'ENTMSG'}='is pulled in';
     $o->{'LEAMSG'}='is pulled out';
     $o->realm_move(uc($self->{'CURRENT'}));
     delete $o->{'ENTMSG'};
     delete $o->{'LEAMSG'};
     $o->{'T'} = $tmpTurns;
     if(!$o->skill_has(36) && (rand(100) < 40)) {
        $self->attack_gen($o, int rand($o->{'MAXH'}/4));
     }
   }
 }
 #my $nextroom;
# if($self->{$self->{'CURRENT'}}->[0] && ($nextroom = $main::map->[$self->{$self->{'CURRENT'}}->[0]]) && $nextroom->{'CURRENT'}) {
     
 #}
}

package room_ladys_shop;
@room_ladys_shop::ISA = qw( room );
use strict;

sub can_enter {
    if(!&room::can_exit(@_)) { return(0); }
    my ($self, $who) = @_;
    if($who->{'GENDER'} =~ /f/i) {
        $who->log_append("{2}The shop doors slide open as you approach.\n");
        return 1;
    } else {
        $who->log_append("{2}You are unable to enter this shop.\n");
        return 0;
    }
}

package flatlands_room;
@flatlands_room::ISA = qw( room );
use strict;

sub on_attack {
	
    my ($self, $attacker, $victim, $weapon) = @_;
    $attacker->log_append("{3}A Huge Tornado approaches.\n");
    $self->spell_tornado($attacker) if rand(100) < 50 && !$attacker->got_lucky();
    $victim->log_append("{3}A Huge Tornado approaches.\n");
    $self->spell_tornado($victim) if rand(100) < 30 && !$victim->got_lucky();
}

sub can_enter {
    if(!&room::can_exit(@_)) { return(0); }
    my ($self, $who) = @_;
    if(1) {
        $who->log_append("{2}This just in from the emergency broadcast system.\n{11}THIS IS NOT A TEST\n{2}THERE IS A {11}TORNADO {2}WARNING IN EFFECT\n");
        return 1;
    } else {
	    $who->log_append("{2}This just in from the emergency broadcast system.\n{11}THIS IS NOT A TEST\n{2}THERE IS A {11}TORNADO {2}WARNING IN EFFECT\n");
        return 0;
    }
}

package wind_room;
@wind_room::ISA = qw( room );
use strict;

# rvs CURRENT <upper-case direction, eg: NE>
# acknowledges terrain 18 (water-deep)

sub wind_room::can_enter($playerobject) {
 if(!&room::can_enter(@_)) { return(0); }

  
 # activate current
 if($_[0]->{'CURRENT'}) { $main::events{$_[0]->{'OBJID'}}=2 unless $main::events{$_[0]->{'OBJID'}}; }
 
 return(1);
}

sub on_event {
 my $self = shift;
 foreach my $o ($self->inv_objs) {
   if ( (($o->{'TYPE'}==1) || ($o->{'TYPE'}==2) || ($o->{'DLIFT'} && $o->{'CAN_LIFT'}) ) && !$o->{'FX'}->{'7'} ) { 
     my $tmpTurns = $o->{'T'};
     $o->log_append("{14}The wind pushes you $main::dirlongmap{$self->{'CURRENT'}}.\n"); 
     $o->{'ENTMSG'}='is pulled in';
     $o->{'LEAMSG'}='is pulled out';
     $o->realm_move(uc($self->{'CURRENT'}));
     delete $o->{'ENTMSG'};
     delete $o->{'LEAMSG'};
     $o->{'T'} = $tmpTurns;
     if(!$o->skill_has(36) && (rand(100) < 40)) {
        $self->attack_gen($o, int rand($o->{'MAXH'}/4));
     }
   }
 }
 #my $nextroom;
# if($self->{$self->{'CURRENT'}}->[0] && ($nextroom = $main::map->[$self->{$self->{'CURRENT'}}->[0]]) && $nextroom->{'CURRENT'}) {
     
 #}
}




1;
