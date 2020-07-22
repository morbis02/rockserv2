use strict;

package rockobj;
use strict;
use Carp qw(cluck confess);
use rockdb;

# Not all of the functions here are truly admin-related. It was just a good file
# to update at the time. And now I'm paying for it. We can move these around
# later once the thing runs. :)


# Remove non-room objects with no cby:  evalll map { $main::map->[0]->inv_add($_); } grep { !defined($_->{'CONTAINEDBY'}) && $_->{'TYPE'} >= 0 } values %$main::objs;

sub find_missing_help_files {
    my $self = shift;
    my @commands = rockdb::sql_select_mult_row_linear(<<END_SQL);
SELECT title
FROM r3.news
WHERE acode='Rock 2' AND amode='Help'
END_SQL

    my %cmds;
    map { $cmds{$_}=1; } keys(%$main::adminbase_mult), keys(%$main::cmdbase_mult), keys(%$main::cmdbase_sing), keys(%$main::cmdbase_obj);
    map { delete $cmds{$main::cmdbase_ali->{$_} || $_}; } @commands;
    
    my $dontshow = "activate, approve, armarr, auction, autoequip, autoloot, awho, ban, bash, blow, bmap, caarp, canattack, cast, chrm, close, cmap, compress, crex, crow, crpl, cwho all, dance, dbmap, decapitate, delete portal, deny, desc, descs, destroy, detab, dig, dmap, emus, enroll list, flatten, getrec, ignite, liquify, map, mkaid, mkcor, mkeye, mkhand, mkwri, msgs clear, msgs more, mute, new portal, newhelp, noadmin, nomob, nullify, objs, open, page, pdescs, pick, prompt format, pset, push, read, refs, remark, remcode, remrefs, ritems, room, silence auctions, silence deaths, silence gossips, silence logins, silence logouts, smash, stock, stupify, terrain, title, tmap, touch, voice, weight, wind";
    
    map { delete $cmds{$_} } split(/, /, $dontshow);
    
    $self->log_append("{16}The following commands might not have associated help files: {6}".join(", ", sort keys %cmds).".\n");
   
}

sub altwatch_get_alt_hash {
    my ($self, $userid, $max_order) = @_;
    
    my $dbh = rockdb::db_get_conn() or return;
    
    my $alts = {}; # alts->{userid} = {order => $order, logins-1 => $logins for order 1, logins =>$total}
    my @userids;
    my @next_userids = ($userid);
    my $login_total = 0; # total logins accounted for in this whole aggregate scan
    for (my $order=1; $order <= $max_order; ++$order) {
        @userids = @next_userids;
        @next_userids = ();
        foreach my $scan_userid (@userids) {
            my $sth = $dbh->prepare_cached(<<END_SQL);
SELECT namea, nameb
FROM   $main::db_name\.r2_altwatch
WHERE  (namea = ?
    OR nameb = ?)
END_SQL
# delete from $main::db_name\.r2_altwatch where ldate < DATE_SUB(sysdate(), INTERVAL 3 month);
#AND ldate > DATE_SUB(sysdate(), INTERVAL 3 month)
            $sth->execute($scan_userid, $scan_userid);

            while (my $row = $sth->fetchrow_arrayref()) {
                my $altname = $row->[0] eq $scan_userid ? $row->[1] : $row->[0];
                next if $altname eq $userid; # skip if alt name matches original;; we know it's an alt!!
                # if it's a new alt, try scanning their alts too, next time
                unless (defined $alts->{$altname}) {
                    $alts->{$altname}->{'order'} = $order;
                    $alts->{$altname}->{'userid'} = $altname;
                    $alts->{$altname}->{'triggered_by'} = $scan_userid;
                    push @next_userids, $altname;
                } 
                $alts->{$altname}->{'logins-'.$order}++;
                $alts->{$altname}->{'logins'}++;
                $login_total++;
            }

            $sth->finish();
        }
    }

    return { LOGIN_TOTAL => $login_total, ALTS => $alts };
}

sub get_likely_alts() {
    # returns list of lower-cased names of my likely alts
    my $self = shift;
    my $alts = $self->altwatch_get_alt_hash(lc($self->{'NAME'}), 2)->{'ALTS'};
    my @altnames = keys %$alts;
    return @altnames;
}

sub is_likely_alt {
    my ($self, $player_obj_or_name) = @_;
    # returns true if $player_obj is a likely alt of $self
    $player_obj_or_name = $player_obj_or_name->{'NAME'} if ref $player_obj_or_name;
    return scalar grep { $_ eq lc $player_obj_or_name } $self->get_likely_alts();
}

sub altwatch_scan_user {
    my ($self, $userid, $max_order) = @_;
    
    $userid = lc $userid;
    $max_order = abs int $max_order;
    $max_order = 6 if $max_order > 6;
    $max_order ||= 3;
    
    if (length($userid) < 3) {
        $self->log_error("Syntax: altscan <userid to scan> [max tier]");
        return;
    }
    
    my $altstat = $self->altwatch_get_alt_hash($userid, $max_order);
    my $alts = $altstat->{'ALTS'};
    
    my $cap = "{17}Altscanning for {2}$userid {17}(tier-$max_order)\n";
    for (my $order=1; $order <= $max_order; ++$order) {
        $cap .= "  {17}Tier-$order Alts\n";
        foreach my $user (sort { $a->{'userid'} cmp $b->{'userid'} } grep { $_->{'order'} == $order } values %$alts) {
            $cap .= sprintf("    {%d}%15s {7}", (defined $main::activeuids->{lc $user->{'userid'}}?12:2), $user->{'userid'}, );
            
            for (my $i=1; $i <= $max_order; ++$i) {
                $cap .= " + " if $i > 1;
                $cap .= sprintf("%3d", $user->{'logins-'.$i});
            }
            
            $cap .= sprintf(" = %3d (%5.2f%%)", $user->{'logins'}, 100*$user->{'logins'}/$altstat->{'LOGIN_TOTAL'});
            $cap .= sprintf("; trigged by %s", $user->{'triggered_by'})
                if $order > 1;
            $cap .= "\n";
        }
    }
    $self->log_append($cap);
}

sub ether_spell_info {
    my ($self, $spell) = @_;
    $spell = uc($spell);
    if(!defined($main::spellbase{$spell})) { 
        $self->log_append("{3}There are no Ether spells by the name of $spell.\n");
    }

    my $s = $main::spellbase{$spell};
}

sub obj_goto {
  my ($self, $searchstr) = @_;
  
  my ($cap, $objs, $lastObj);
  
  my $test_obj = $self->uid_resolve($searchstr, 1);
  if($test_obj) { $self->teleport($test_obj); return; }
  
  $searchstr = lc($searchstr);
  foreach my $obj (values(%{$main::objs})) {
    if( index(lc($obj->{'NAME'}), $searchstr) != -1) { 
       $cap .= sprintf("{6}%5d %4d %2s{2}%-30s {3}%4s\n", $obj->{'OBJID'}, $obj->{'ROOM'}, $main::activemap{defined($main::activeusers->{$obj->{'OBJID'}})}, substr($obj->{'NAME'}, 0, 30), $main::typemap{$obj->{'TYPE'}});
       $objs++; $lastObj = $obj;
       if ($objs >= 5) { $cap .= "{2}<<< ETC >>>\n"; last; }
    }
  }
  $cap .= "{7}|KEY|: {1}*{7} = active object.\n{41}";
  
  if(!$objs) { $self->log_append("{3}No objects found.\n"); }
  elsif($objs == 1) { $self->teleport($lastObj); }
  else { $self->log_append($cap); }
  
  return;
}

sub chisel_portal_new {
    my ($self, $linkto) = @_;
    my $room = $main::map->[$self->{'ROOM'}];    
    if (!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
    if ($room->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }
    
    
    if($linkto eq '') {
      if($room->{'PORTAL'} ne '') { $self->log_append("{3}>There is already a portal defined for this room.\n"); return; }
      # gather new portal number
      my $maxnum;
      for(my $i=0; $i<@{$main::map}; $i++) {
        if(defined($main::map->[$i]->{'PORTAL'})) { $maxnum = $main::map->[$i]->{'PORTAL'} if ($main::map->[$i]->{'PORTAL'} > $maxnum); }
      }
      $linkto = $maxnum+1;
      $self->log_append("{3}>Creating new PORTAL for this room...\n");
    } else {
      my $foundmatch = 0;
      for(my $i=0; $i<@{$main::map}; $i++) {
          $foundmatch = 1 if $main::map->[$i]->{'PORTAL'} == $linkto;
      }
      if(!$foundmatch) {
         return $self->log_append("{3}>Did not find matching portal #$linkto.\nTry creating a new one with \"new portal\"?\n");
      }
    }

    $room->{'PORTAL'}=$linkto;
    $self->log_append("{3}>Set room's PORTAL to $linkto.\n");
}

sub chisel_portal_del {
    my ($self) = @_;
    my $room = $main::map->[$self->{'ROOM'}];    
    if (!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
    if ($room->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }
    
    if($room->{'PORTAL'} eq '') { $self->log_append("{3}>There is no portal defined for this room.\n"); return; }    
    delete $room->{'PORTAL'};
    delete $room->{'PDESC'};
    delete $room->{'PNAME'};
    delete $room->{'PNOENTER'};
    delete $room->{'PNOEXIT'};
    delete $room->{'PINVIS'};
    $self->log_append("{3}>Deleted room's portal values.\n");
}

sub pw_webregister {
   return; # deprecated
}

sub freemv_change {
    my ($self, $raceid) = @_;
    
    $self->log_append("Option disabled - could mess up flatfiles. Bug plat to fix me.\n");
    return;
    my $room = $main::map->[$self->{'ROOM'}];
    if ("$raceid" ne "") {
       $raceid = int $raceid;
       if($self->{'GRP'} ne $room->{'OWN'}) {
          $self->log_append("{15}** {1}ERROR {15}**: {7}You are not authorized to change this room's {17}freemv {7}info.\n");
       } elsif( !defined($main::races[$raceid]) || !$main::races[$raceid] ) {
          $self->log_append("{15}** {1}ERROR {15}**: {7}Unknown race number \"$raceid\". Freemv unchanged.\n");
       } else {
          # toggle race
          my $tempID = $room->{'FREEMV'};
          vec($room->{'FREEMV'}, $raceid, 1) = !vec($room->{'FREEMV'}, $raceid, 1);
          $self->log_append("{2}## SUCCESS ##:{7} Toggled $main::races[$raceid]\'s FREEMV.\n");
       }
    }
    
    # display rooms
    my $cap;
    for(my $i = 0; $i < scalar(@main::races); $i++) {
       if(vec($room->{'FREEMV'}, $i, 1)) { $cap .= sprintf("   {16}%2s {6}%25s\n", $i, $main::races[$i]); }
    }
    
    if($cap)  { 
       $self->log_append("{7}/{7}----------- {12}FreeMv Settings for {17}$room->{'NAME'}\n".$cap."{7}\\{7}-----------\n");
    } else {
       $self->log_append("{17}** No FreeMvs set for this room. Type \"freemv <race number>\" to toggle.\n");
    }
    return;
}

sub monoliths_list {
    my $self = shift;
    # display rooms
    my $cap;
    
#    foreach my $key (keys(%main::monolithtoname)) {
#       $cap .= sprintf("  {16}%20s {1}.   .  . .. {6}%-25s\n", $main::monolithtoname{$key} ,$main::rock_stats{$key}?$main::races[$main::rock_stats{$key}]:'- unclaimed -');
#    }
#    
#    $self->log_append("{7}\n/{17}----------- {12}M{2}onolith {12}C{2}apture {12}S{2}tatus\n".$cap."{7}\\{17}-----------\n");
#    
#    if (!$main::rock_stats{'armageddon_is_possible'}){$self->log_append("{12}             Armageddon Not Possible\n");}
#    else{$self->log_append("{11}             Armageddon Possible\n");}
    
#    if($self->{'ADMIN'})
#    {
	
	    my @npcOBJS = undef;
	    foreach my $key (keys(%main::monoliths)) { 
     		if (defined($main::objs->{$main::monolithstoobjid{$key}})) {
        	  	push(@npcOBJS, $main::objs->{$main::monolithstoobjid{$key}});
    	 	}
 		}
 		
	    my $mono1 = $npcOBJS[1];
	    my $mono2 = $npcOBJS[2];
	    my $mono3 = $npcOBJS[3];
	    my $mono4 = $npcOBJS[4];
	    my $mono5 = $npcOBJS[5];
	    my $mono6 = $npcOBJS[6];
	    my $mono7 = $npcOBJS[7];
	    my $mono8 = $npcOBJS[8];
	    my $mono9 = $npcOBJS[9];
	    my $mono10 = $npcOBJS[10];
 		
	    
	    
	    
	    
	    my $mono1alive = ((time - $mono1->{'BIRTH'}) / 60 / 60);
	    my $mono2alive = ((time - $mono2->{'BIRTH'}) / 60 / 60);
	    my $mono3alive = ((time - $mono3->{'BIRTH'}) / 60 / 60);
	    my $mono4alive = ((time - $mono4->{'BIRTH'}) / 60 / 60);
	    my $mono5alive = ((time - $mono5->{'BIRTH'}) / 60 / 60);
	    my $mono6alive = ((time - $mono6->{'BIRTH'}) / 60 / 60);
	    my $mono7alive = ((time - $mono7->{'BIRTH'}) / 60 / 60);
	    my $mono8alive = ((time - $mono8->{'BIRTH'}) / 60 / 60);
	    my $mono9alive = ((time - $mono9->{'BIRTH'}) / 60 / 60);
	    my $mono10alive = ((time - $mono10->{'BIRTH'}) / 60 / 60);
	    
	    if($mono1->{'RACE'} == 0) {$mono1alive = 0;}
	    if($mono2->{'RACE'} == 0) {$mono2alive = 0;}
	    if($mono3->{'RACE'} == 0) {$mono3alive = 0;}
	    if($mono4->{'RACE'} == 0) {$mono4alive = 0;}
	    if($mono5->{'RACE'} == 0) {$mono5alive = 0;}
	    if($mono6->{'RACE'} == 0) {$mono6alive = 0;}
	    if($mono7->{'RACE'} == 0) {$mono7alive = 0;}
	    if($mono8->{'RACE'} == 0) {$mono8alive = 0;}
	    if($mono9->{'RACE'} == 0) {$mono9alive = 0;}
	    if($mono10->{'RACE'} == 0) {$mono10alive = 0;}
	    
	    if($mono1->{'RACE'}==0){$mono1->{'KILLEDBY'} = "Outcasts";}
	    if($mono2->{'RACE'}==0){$mono2->{'KILLEDBY'} = "Outcasts";}
	    if($mono3->{'RACE'}==0){$mono3->{'KILLEDBY'} = "Outcasts";}
	    if($mono4->{'RACE'}==0){$mono4->{'KILLEDBY'} = "Outcasts";}
	    if($mono5->{'RACE'}==0){$mono5->{'KILLEDBY'} = "Outcasts";}
	    if($mono6->{'RACE'}==0){$mono6->{'KILLEDBY'} = "Outcasts";}
	    if($mono7->{'RACE'}==0){$mono7->{'KILLEDBY'} = "Outcasts";}
	    if($mono8->{'RACE'}==0){$mono8->{'KILLEDBY'} = "Outcasts";}
	    if($mono9->{'RACE'}==0){$mono9->{'KILLEDBY'} = "Outcasts";}
	    if($mono10->{'RACE'}==0){$mono9->{'KILLEDBY'} = "Outcasts";}
	    
	    my $armegeddon_time_possible = 0;
	    if(
	    ($mono1alive >= 1)&&
	    ($mono2alive >= 1)&&
	    ($mono3alive >= 1)&&
	    ($mono4alive >= 1)&&
	    ($mono5alive >= 1)&&
	    ($mono6alive >= 1)&&
	    ($mono7alive >= 1)&&
	    ($mono8alive >= 1)&&
	    ($mono10alive >= 1)&&
	    ($mono9alive >= 1)
	    ){
		    $armegeddon_time_possible = 1;
	    }
	    
	    my $armegeddon_full_control = 0;
	    
	    if(
	    ($mono1->{'RACE'} == $mono2->{'RACE'}) &&
	    ($mono2->{'RACE'} == $mono3->{'RACE'}) &&
	    ($mono3->{'RACE'} == $mono4->{'RACE'}) &&
	    ($mono4->{'RACE'} == $mono5->{'RACE'}) &&
	    ($mono5->{'RACE'} == $mono6->{'RACE'}) &&
	    ($mono6->{'RACE'} == $mono7->{'RACE'}) &&
	    ($mono7->{'RACE'} == $mono8->{'RACE'}) &&
	    ($mono8->{'RACE'} == $mono9->{'RACE'}) &&
	    ($mono10->{'RACE'} == $mono10->{'RACE'}) &&
	    ($mono9->{'RACE'} == $mono1->{'RACE'})
    	
	    ){
	    	$armegeddon_full_control = $mono1->{'RACE'};
    	}
	    my $armageddon_is_possible = 0;
    	if($armegeddon_full_control && $armegeddon_time_possible) {
	    	$armageddon_is_possible = $armegeddon_full_control;
	    	$main::rock_stats{'armageddon_is_possible'} = $armegeddon_full_control;
	    	}
	    
 		my $cap2 = undef;
	    

 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono10->{'RACE'},$mono10->{'NAME'}, $mono10->{'RACE'}, $main::races[$mono10->{'RACE'}],$mono10alive, $mono10->{'KILLEDBY'}); #HILL
		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono2->{'RACE'},$mono2->{'NAME'}, $mono2->{'RACE'}, $main::races[$mono2->{'RACE'}],$mono2alive, $mono2->{'KILLEDBY'}); #SHADE
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono1->{'RACE'},$mono1->{'NAME'}, $mono1->{'RACE'}, $main::races[$mono1->{'RACE'}],$mono1alive, $mono1->{'KILLEDBY'}); #PEARL
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono4->{'RACE'},$mono4->{'NAME'}, $mono4->{'RACE'}, $main::races[$mono4->{'RACE'}],$mono4alive, $mono4->{'KILLEDBY'}); #AURORAL
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono3->{'RACE'},$mono3->{'NAME'}, $mono3->{'RACE'}, $main::races[$mono3->{'RACE'}],$mono3alive, $mono3->{'KILLEDBY'}); #OPTICAL
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono5->{'RACE'},$mono5->{'NAME'}, $mono5->{'RACE'}, $main::races[$mono5->{'RACE'}],$mono5alive, $mono5->{'KILLEDBY'}); #CHRONO
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono7->{'RACE'},$mono7->{'NAME'}, $mono7->{'RACE'}, $main::races[$mono7->{'RACE'}],$mono7alive, $mono7->{'KILLEDBY'}); #DESERT
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono8->{'RACE'},$mono8->{'NAME'}, $mono8->{'RACE'}, $main::races[$mono8->{'RACE'}],$mono8alive, $mono8->{'KILLEDBY'}); #CRIMSON
		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono9->{'RACE'},$mono9->{'NAME'}, $mono9->{'RACE'}, $main::races[$mono9->{'RACE'}],$mono9alive, $mono9->{'KILLEDBY'}); #GRANITE
 		$cap2 .= sprintf("{%1d}%20s {7}.   .  . .. {%1d}%10s {17}%4.1f hours by{17} %s\n" ,$mono6->{'RACE'},$mono6->{'NAME'}, $mono6->{'RACE'}, $main::races[$mono6->{'RACE'}],$mono6alive, $mono6->{'KILLEDBY'}); #HALLUCINATOR
 		
	    $self->log_append("{7}\n   {17}------------- {12}M{2}onolith {12}C{2}apture {12}S{2}tatus {17}-------------\n".$cap2."{7}   {17}---------------------------------------------------\n");
	    if($armageddon_is_possible){$self->log_append("{17}             {12}A{2}rmageddon {12}P{2}ossible {12}F{2}or {$armegeddon_full_control}$main::races[$armegeddon_full_control]\'s {17}         \n");}
	    
#	}
    
    return;
}

sub mapnames_list {
  my $self = shift;
  my $cap;
  my %mapresol = %main::mapname_resolutions;
  foreach my $r (@{$main::map}) {
     if(!$mapresol{$r->{'M'}}) { $mapresol{$r->{'M'}}="undefined ($r->{'ROOM'})"; }
  }
  foreach my $mapnum (sort keys(%mapresol)) {
     $cap .= sprintf("%3d %s\n", $mapnum, $mapresol{$mapnum});
  }
  $self->log_append($cap);
  return "";
}

sub item_randinject {
    # my $self = shift;
    my $roomid = int rand(scalar @$main::map);
    my $room = $main::map->[$roomid];
    confess "Tried to inject an item into randomly-chosen room $roomid, but this room does not seem to exist"
        unless $room;
    my $obj = $room->item_spawn($main::inject_items[int rand(scalar @main::inject_items)]);
    &main::rock_shout(undef, "{17}<--===--> {2}Injected {17}$obj->{'NAME'} ($obj->{'REC'}) {2}into {17}$room->{'NAME'} ($room->{'ROOM'})\{2}.\n", 1);
    return;
}

sub user_transport {
  my ($self, $uid) = @_;
  if (!$uid) { $self->log_error("Syntax: transport <player>"); return; }
  
  if (my $recip = $self->uid_resolve($uid)) {
    if($recip->{'ROOM'} == $self->{'ROOM'}) { $self->log_append("{17}You're already with $recip->{'NAME'}. You expect to get a little closer?\n"); return; }
    if($recip->{'FROZEN'}) { $self->teleport($recip->{'ROOM'}); return; }
    $recip->log_append("{16}A force beyond your control whisks you away!\n");
    $recip->teleport($self->{'ROOM'}); 
  }
  return;
}

sub user_anonvoice {
  my ($self, $uid, $msg) = @_;
  $uid = lc($uid);
  if(!$self->{'ADMIN'} && !$self->{'OVERSEER'}) { $self->log_append("{17}Yeah right!\n"); return; }
  
  if(!$uid) { $self->log_append("{6}Voice who?\n"); return; }
  if(!$main::activeuids->{$uid}) { $self->log_append("{17}$uid {15}is not logged in.\n"); }
  else {
    my $recip = &rockobj::obj_lookup($main::activeuids->{$uid});
    $recip->log_append("{17}Your conscience tells you: {16}$msg\n");
    $self->log_append("{17}Told $recip->{'NAME'}\: {16}$msg\n");
    $self->admin_log("{4}Anonymously voiced $recip->{'NAME'}: $msg.\n");
  }
  return;
}

sub user_freezethaw {
  my ($self, $uid, $freeze) = @_;
  if (my $recip = $self->uid_resolve($uid)) {
    if($freeze) { 
       if($recip->{'FROZEN'}) { $self->log_append("{6}But $recip->{'NAME'} is already frozen!\n"); return; }
       if($recip->{'ROOM'} != $main::roomaliases{'frozenroom'}) {
          $recip->teleport($main::roomaliases{'frozenroom'} || 0); 
       }
       $recip->log_append("{16}***** $self->{'NAME'} has frozen you in place! DO NOT LOG OFF.\n");
       $recip->{'FROZEN'}=1;
       $self->log_append("{6}***** Froze $recip->{'NAME'}.\n");
       $self->admin_log("{4}Froze $recip->{'NAME'}.\n");
    } else {
       if(!$recip->{'FROZEN'}) { $self->log_append("{6}But $recip->{'NAME'} is already thawed!\n"); return; }
       $recip->log_append("{16}***** $self->{'NAME'} has thawed you! You are now free to move.\n");
       delete $recip->{'FROZEN'};
       $self->log_append("{6}***** Thawed $recip->{'NAME'}.\n");
       $self->admin_log("{4}Thawed $recip->{'NAME'}.\n");
    }
  }
  return;
}
# $_[0]->telnet_kick($main::objs->{321052});
sub telnet_kick {
 my ($self, $username, $pw, $force) = @_;
 $pw = lc($pw);
 if(!$username) { $self->log_append("User unknown.\n"); return; }
 my ($success, $item) = ref($username)?(1,$username):$self->inv_cgetobj($username, 0, (values(%{$main::sockplyrs})));
 if($success == 1) { 
   unless ($self->{'ADMIN'} || $force) { 
       my ($valid_pw, $reason) = $rockobj::auth_man->authUserID($self->{'IP'}, $username, $pw);

       if (!$valid_pw) {
           $item->log_append("{1}$_[0]->{'NAME'} at $_[0]->{'IP'} just tried logging you off, but: [$reason]\n");
           $self->log_append("{3}Ejection Failed: $reason\n");
           $main::hackwatch{"$_[0]->{'IP'}"}++;
           if($main::hackwatch{"$_[0]->{'IP'}"} >= 5) { 
               push(@main::banlist, "$_[0]->{'IP'}");
               &main::mail_send($main::rock_admin_email, "R2: BAN ($_[0]->{'IP'})", "Banning $_[0]->{'IP'} for hacking $username (pw $pw) (ejection hack).\n");
           }

           return(0);
       }
   }
    my $is_success = 0;
    my $key;
    foreach $key (keys(%{$main::sockplyrs})) {
       if ($main::sockplyrs->{$key} eq $item) {
            $item->log_append("{12}You have been ejected by {5}$self->{'NAME'}.\n"); 
           $main::qkillonsend[$key]=1; # soft-eject (old)
           
           # hard eject
           if (my $sock = &main::get_objid_socket($item->{'OBJID'})) {
               &main::rock_destp($sock->fileno);
           }
           # /hard eject
           
           $is_success="$key $main::sockplyrs->{$key}";
       }
    }
    
    unless ($is_success) {
        # Try ejecting them web-style
        $main::activeusers->{$self->{'OBJID'}}=1; $main::donow .= '&main::rem_inactive_users;';
    }
    
    if ($is_success) {
        $self->log_append("{12}$item->{'NAME'} ejected ($is_success).\n");
    } else {
        $self->log_append("{12}$item->{'NAME'} is not connected to the game via socket.\n");
    }
    return($is_success);
 } elsif($success == 0) { $self->log_append("{3}User not found.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
 return;
}

sub is_developer { 
	if($_[0]->{'DEV'}){
		return 1;
	}
	if($_[0]->{'ADMIN'}){
		return($_[0]->{'ADMIN'}); 
	}
}

sub admin_stores {
  my $self = shift;
  my ($s, $cap);
  foreach $s (@{$main::map}) { 
    if($s->{'STORE'}) {
      $cap .= "$s->{'STORE'} ";
    }
  }
  $self->log_append("{17}Stores: {7}$cap\n");
}

sub admin_uniques {
  my $self = shift;
  my ($s, $cap);
  foreach $s (keys(%main::obj_unique)) { 
     if($main::obj_unique{$s}) { $cap .= sprintf("{6}%30s {7}::: {1}%-30s\n", $s, $main::obj_unique{$s}); }
     else { delete $main::obj_unique{$s}; }
  }
  $self->log_append("{17}-= Tracked Unique Items =-\n".$cap);
  return;
}

sub admin_shout {
  my ($self, $cap) = @_;
  if(!$self->{'ADMIN'}) { $self->log_append("{3}Sorry, that command is for admins only.\n"); return; }
  if(!$cap) { $cap = "{17}I'm speechless!"; }
  my ($player, $pobj);
  $cap = '{1}[ {2}'.$self->{'NAME'}.'{1} ]{14}={4}- {17}'.$cap."\n";
  foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ($pobj->{'ADMIN'}) { $pobj->log_append($cap); } 
  }
  return;
}

sub invade_privacy {
 my $self = shift;
 my ($user);
 ##foreach $user (keys(%main::iop)) {
 ## if(!$main::iop{$user}) { next; }
 ## open(F, ">>$main::base_code_dir/iop/".lc($user).'.iop') or &main::rock_shout(undef, "Could not open IOP file for writing: $!\n", 1);
 ##   #$main::iop{$user} =~ s/\</\&lt\;/g; $main::iop{$user} =~ s/\>/\&gt\;/g;
 ##   #$main::iop{$user} =~ s/\n/\<BR\>/g;
 ##   #$main::iop{$user} =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
 ##   $main::iop{$user} =~ s/\{(\d*)\}/$main::elsemap{$1}/ge;
 ##   print F $main::iop{$user};
 ##   delete $main::iop{$user};
 ## close(F);
 ##}
 ##if(!$self) { return; }
 ##$self->log_append("{17}Privacy Invaded. ;-)\n");
 return;
}

sub admin_log {
  my $self = shift;
  my $cap = '{2}{43}'.&main::time_get().'{44}: '.join('', @_);
  $main::adminstats{$self->{'NAME'}} .= $cap;
  $self->caarp_shout("{7}#**{17}CAARP{7}**#> {12}$self->{'NAME'}\: ".$cap);
  return;
}

sub game_caarp_log {
  my $type = shift;
  my $cap = '{2}{43}'.&main::time_get().'{44}: '.join('', @_);
  $cap =~ s/\n/  /g;
  $main::adminstats{"Rock $type"} .= $cap."\n";
  &main::rock_shout(undef, "{14}#{4}****{14}#> {12}Rock $type\: $cap\n", 1);
  return;
}

sub caarp_bcast {
  my ($self, $cap) = @_;
  return ($self->log_append("{13}No.\n")) if (!$self->{'OVERSEER'});
  $self->caarp_shout("{14}-= {17}$self->{'NAME'} {14}=- caarps\: {17}$cap\n");
  $self->log_append("{14}-= {17}$self->{'NAME'} {14}=- caarps\: {17}$cap\n");
  return;
}

sub caarp_shout {
 # sends message to each player other than object passed to it.
 my ($self, $cap) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( ($player ne $self->{'OBJID'}) && !$pobj->{'ST8'} && ($pobj->{'OVERSEER'})) { $main::objs->{$player}->log_append($cap); } 
 }
 return;
}


sub adminstats_commit {
 my $self = shift;
# THe admin logs are old and not too useful right now. This should really use
# MySQL instead of a flatfile. Maybe even tie it into the account event logs
# (Dillfrog::Auth). Not worth troubleshooting right now.
#print "WARNING: adminstats_commit was supposed to save admin logs, but we don't right now.\n";
return;

 my ($user);
 my $date = &main::date_get();
 open(F, ">>$main::base_web_dir/admin/logs/$date.txt") || warn "Could not open date file for writing: $!\n";
 foreach $user (keys(%main::adminstats)) {
    print F "#### SWITCH <$user> ####\n";
    $main::adminstats{$user} =~ s/\</\&lt\;/g; $main::iop{$user} =~ s/\>/\&gt\;/g;
    $main::adminstats{$user} =~ s/\n/\<BR\>/g;
    $main::adminstats{$user} =~ s/\{(\d*)\}/$main::colorhtmlmap{$1}/ge; # note: used to be \d? for single-char
    print F (delete $main::adminstats{$user})."\n";
 }
 close(F);
 if(!$self) { return; }
 $self->log_append("{17}Admin stats committed. ;-)\n");
 return;
}

sub chisel_descs {
  my ($self, $from, $to) = @_;
  if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
  my ($n, $maxn, $cap);
  if(!$to) { $to = $from+19; }
  if($to > $#$main::desc) { $maxn=$#$main::desc; }
  else { $maxn=int $to; }
  if($from < 0) { $from = 0; }
  else { $from = int $from; }
  $cap = "{17}Description References.\n";
  for ($n=$from; $n<=$maxn; $n++) {
    $cap .= sprintf('{13}%-4d {6}||{2} %s'."\n", $n, substr($main::desc->[$n],0,70));
  }
  $self->log_append($cap);
  return;
}

sub desc_compressnum {
  my $self = shift;
  
  if(!$self->{'DESC'} || !ref($self->{'DESC'})) { return("unlisted"); }
  
  my $maxn = $#$main::desc;
  my ($n, $keepgoing);
  $keepgoing=1;
  for ($n=0; (($n<=$maxn) && $keepgoing); $n++) {
    if(${$self->{'DESC'}} eq $main::desc->[$n]) { $keepgoing=0; }
  }
  
  if($n > $maxn) { return("unfound"); }
  else { return(int $n-1); }
}

sub admin_lcoms {
  my ($self, $from, $to) = @_;
  if($self->{'JOJOMOO'} ne 'JOOOOOO') { $self->log_append("Nope. Sorry.\n"); return; }
  my ($n, $maxn, $cap);
  if(!$to) { $to = $from+19; }
  if($to > $#main::lcom) { $maxn=$#main::lcom; }
  else { $maxn=int $to; }
  if($from < 0) { $from = 0; }
  else { $from = int $from; }
  $cap = "{17}Last Commands...\n";
  for ($n=$from; $n<=$maxn; $n++) {
    $cap .= sprintf('{13}%-4d {6}||{2} %s'."\n", $n, substr($main::lcom[$n],0,70));
  }
  $self->log_append($cap);
  return;
}


sub user_seen {
  my ($self, $userid) = @_;
  $userid = lc($userid);
  if(!$main::uidmap{$userid}) { $self->log_append("{3}Userid {7}$userid {3}does not exist.\n"); return; }
  if(($userid =~ /\b(?:morbis|plat|mich)\b/) && !$self->{'ADMIN'}) { $self->log_append("{3}Userid is an admin with seen-blocking turned on.\n"); return; }
  if($main::uidmap{$userid} == 1) { $self->log_append("{3}This user hasn't logged in since the game did a user-login reset. Sorry.\n"); return; }
  $self->log_append("{17}Userid {15}$userid {17}last visited Rock on {16}~".&main::time_get($main::uidmap{$userid},1)."{17}.\n");
  return;
}

sub admin_remark {
  my ($self, $remark) = @_;
  if(!$self->{'ADMIN'} && !$self->{'OVERSEER'}) { $self->log_append("{2}This option is only available for admins and overseers.\n"); return; }
  elsif(!$remark) { $self->log_append("{3}Syntax: remark <text to place in admin logs>\n"); }
  else {
     $self->log_append("{6}-- Remarked! --\n");
     $self->admin_log('{3}##Remark## {2}'.$remark."\n");
  }
  return; 
}

sub user_ban {
  my ($self, $uid, $minutes) = @_;
  $uid = lc($uid);
  if(!$self->{'ADMIN'} && !$self->{'OVERSEER'}) { $self->log_append("{2}This option is only available for admins and overseers.\n"); return; }
  if(!$uid) { $self->log_append("{6}Ban Who?\n"); return; }
  if(!$main::activeuids->{$uid}) { $self->log_append("{17}$uid {15}is not logged in.\n"); }
  else {
    $minutes = 60 unless $minutes;
    $minutes = int abs $minutes || 1;
    if(!$self->{'ADMIN'} && $minutes > 1440) { $minutes = 1440; }
    my $victim = &rockobj::obj_lookup($main::activeuids->{$uid});
    if($victim->{'ADMIN'}) { $self->log_append("{2}Sorry, cannot ban admins 8)\n"); return; }
    $victim->{'BAN'} = time + ($minutes*60);
    $victim->{'REPU'}-=1;
    $victim->log_append("{16}You have been temporarily banned from playing.\nPlease watch your actions in the future.\n{17}If you believe that you were banned unfairly, write $main::rock_admin_email and fully explain your case.");
    $self->log_append("{2}- $victim->{'NAME'} banned for $minutes minutes -\n");
    $self->admin_log("{4}Banned $victim->{'NAME'} for {1}$minutes {4}minutes.\n");
    print "$self->{'NAME'} banned $uid for $minutes minutes\n"; 
  }
  return;
}

sub force_cmd {
  my ($self, $objid, $cap) = @_;
  
  my $targ = undef;
  
  if ($objid eq int($objid)) {
       return $self->log_append("Object does not exist.\n") unless $targ = $main::objs->{$objid}; # yes, i really want to assign here, not test equality.
  } else {
       return unless $targ = $self->uid_resolve($objid);
  }
  
  confess "Could not find a targ object value; this should never happen :-)" unless $targ;
  
  if(!$self->{'ADMIN'} && $targ->{'TYPE'} == 1) { 
      $self->log_append("Sorry, non-admins can't force players.\n");
      return;
  }
  $targ->log_append('{1}'.$self->{'NAME'}.'{2} has forced you to: {6}'.$cap."\n");
  $self->log_append('{2}You have forced {1}'.$targ->{'NAME'}.'{2} to: {6}'.$cap."\n");
  my $oldpos = length($targ->{'LOG'});
  $targ->cmd_do($cap);
  my $log = substr($targ->{'LOG'}, $oldpos);
  if ($log) {
      $log =~ s/^(.*)$/{13}**$targ->{'NAME'}\'s Screen**  {7}\1/mg;
      $self->log_append($log);
  } else {
#      $self->log_error("Could not redisplay what $targ->{'NAME'} sees. They must not be logged in (e.g. an NPC).");
  }
  return;
}

sub telserv_ips_list {
 my $self = shift;
 my ($key, $cap, $n);
 foreach $key (keys(%main::ip_connected)) {
   $cap .= sprintf('{1}%20s{2}:{17}%-4d', substr(&main::r2_ip_to_name($key), 0, 20), $main::ip_connected{$key});
   $n++; if($n == 3) { $n=0; $cap .= "\n"; }
 }
 if($n != 0) { $cap .= "\n"; }
 $self->log_append($cap);
 return;
}

sub db_list {
 my ($self, $start, $end) = @_;
 $start = 1 unless $start;
 $end = $#{$main::db} unless $end;
 if($end > $#{$main::db}) { $end = $#{$main::db}; }
 if($start < 1) { $start = 1; }
 my ($key, $cap, $n, @a, $i);
 for(my $j=$start; $j<=$end; $j++) { 
   $key = $main::db->[$j];
   if(!$key) { next; }
   @a = @{$key};
   my $dbname = shift(@a);
   for($i=0; $i<=$#a; $i++) { $a[$i]=$main::recnum_toname{$a[$i]} || $a[$i]; }
   $cap .= &rockobj::wrap('', '       ', sprintf("{12}(%4d) %s.\n", $j, "{17}$dbname: {16}".join(', ', @a)));
 }
 if($n != 0) { $cap .= "\n"; }
 $self->log_append($cap);
 return;
}

sub nomob {
 my ($self, $value) = @_;
 if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
  if($main::map->[$self->{'ROOM'}]->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }
 my $room = $main::map->[$self->{'ROOM'}];
 if("$value" eq "") { $self->log_append("{17}Room's current NOMOB is set to ".($room->{'NOMOB'}*1).".\nType 'nomob 1' to make the room a nomob room, 'nomob 0' to clear.\n"); }
 elsif($value) { $room->{'NOMOB'}=1; $self->log_append("{17}Room's NOMOB set to 1.\n"); }
 else { $room->{'NOMOB'}=''; $self->log_append("{17}Room's NOMOB set to 0.\n"); }
 return;
}

sub telserv_ips_halve {
 my $self = shift;
 my ($key, $cap, $n);
 foreach $key (keys(%main::ip_connected)) {
   $main::ip_connected{$key} = int ( $main::ip_connected{$key} / 2 );
   if(!$main::ip_connected{$key}) { delete ($main::ip_connected{$key}); }
 }
 $self->log_append("Telserv Connect IP counts halved.\n");
 return;
}


sub cmd_clock_list {
 my $self = shift;
 my ($key, $cap, $n);
 foreach $key (sort keys(%main::cmd_time)) {
   my $time = substr($main::cmd_time{$key}/($main::cmd_tick{$key} || 1e100), 0, 10);
   next unless $time;
   $cap .= sprintf('{1}%10s{2}: {17}%-10s', substr($key, 0, 10), $time );
   $n++; if($n == 3) { $n=0; $cap .= "\n"; }
 }
 if($n != 0) { $cap .= "\n"; }
 $self->log_append($cap);
 return;
}

sub cmd_bash_list {
 my $self = shift;
 my ($key, $cap, $n);
 foreach $key (sort keys(%main::cmd_bash)) {
   next if ($main::cmd_bash{$key} < 10);
   $cap .= sprintf('{1}%15s{2}: {17}%-5d', substr($key, 0, 15), $main::cmd_bash{$key} );
   $n++; if($n == 3) { $n=0; $cap .= "\n"; }
 }
 if($n != 0) { $cap .= "\n"; }
 $self->log_append($cap);
 return;
}

sub myroom_set {
 # recursive room setting..
 # only covers inventory
 my ($self, $room) = @_;
 $self->{'ROOM'}=$room;
 foreach my $o ($self->inv_objs) { $o->myroom_set($room); }
 return;
}

sub update_rec_info_in_db() {
    my $self = shift;

	return unless defined $self->{'REC'}  && !vec($main::updated_item_rec, $self->{'REC'}, 1);
    vec($main::updated_item_rec, $self->{'REC'}, 1) = 1; # we updated it!

	my $dbh = rockdb::db_get_conn_local();
	my $rows = $dbh->do(<<END_SQL, undef, $self->{'NAME'}, $self->{'REC'}, $self->{'DESC'});
UPDATE $main::db_name_local\.r2_item_names_by_rec
SET item_name = ?, item_desc = ? 
WHERE item_id = ?
END_SQL

    unless ($rows > 0) {
        eval { $dbh->do(<<END_SQL, undef, $self->{'NAME'}, $self->{'REC'}, $self->{'DESC'}); };
INSERT INTO $main::db_name_local\.r2_item_names_by_rec
(item_name, item_id, item_desc)
VALUES
(?, ?, ?)
END_SQL
	}

}

sub item_spawn_forced {
   # Like item_spawn, but pays no attention to item limits, uniqueness, etc.
   # 
   # Returns last obj created
   #
   my $self = shift;
   
   my $obj;
   while (@_) {
       my $itemid = int shift;

       if ($main::objbase->[$itemid]) {
           $obj = &{$main::objbase->[$itemid]};
           $obj->{'REC'}=$itemid; $obj->{'CRTR'}=$self->{'NAME'};
           $obj->{'CROBJID'}=$self->{'OBJID'};
           $main::obj_limits{$itemid} = $obj->{'UNIQUE'}?1:$obj->{'LIMIT'};
           $main::obj_recd{$itemid}++;
           $obj->obj_fixflaws();
           $obj->equip_best(1);
           $obj->stats_update();
           $obj->power_up();
           #$obj->update_rec_info_in_db();
           
           if ($self->{'ADMIN'}) {
               $self->log_append("Creating: $obj->{'NAME'} ($obj->{'REC'}): $main::obj_recd{$itemid}/$main::obj_limits{$itemid}\n"); 
           }

           $self->inv_add($obj);

           if (($obj->{'TYPE'}==2) && !$obj->{'CRYL'} && rand(1)<$main::set_cryl_on_no_cryl_pct) {
               $obj->{'CRYL'} = int ($main::set_cryl_on_no_cryl_from + rand($main::set_cryl_on_no_cryl_to+1));
           }
           
           $obj->{'CRYL'} *= $main::lightning_cryl_multiplier;
## BOSS SPAWNS

           if (($obj->{'TYPE'} == 2 && defined($obj->{'onDeath_RESPAWN'})))
           {
               my $weapon = $obj->weapon_get();
               my $targ = $obj->ai_get_random_target();
               if ($targ && $weapon ) { 
	               $self->room_sighttell("{7}$obj->{'NAME'} {17}makes its way into the room.\n");
	              
                   $obj->attack_melee($targ, $weapon); 
               }
           }

           $obj->myroom_set($self->{'ROOM'});
        } else {
           if ($self->{'ADMIN'}) {
               $self->log_error("Item $itemid does not exist; not created."); 
           }
           $obj = undef;
        }
   }
   
   return $obj;
}

sub item_spawn {
  # Syntax: $obj->item_spawn($itemid, $itemid, ..., $itemid);
  #
  # Returns last obj created.
  
  my $self = shift;
  my $obj;
  while(@_) {
      my $itemid = int shift;
      if ( (!$main::obj_limits{$itemid}) || ($main::obj_recd{$itemid} < $main::obj_limits{$itemid}) )
         { 
          
          # create item (this will return undef if the itemid doesn't exist
          # in our item rec list)
          $obj = $self->item_spawn_forced($itemid);
          
          
          #confess "Tried creating item $itemid but it doesn't exist. Not good."
          #    unless $obj;
          
          # if it's a unique item (we wont know till we make it.. which is lame, but hey)
          # then delete it!
          if ($obj && $obj->{'UNIQUE'} && $main::obj_unique{$obj->{'REC'}}) {
              $self->log_error("Deleting recently-created $obj->{'NAME'} because of UNIQUE ITEM constraints.")
                  if $self->{'ADMIN'};
              $obj->obj_dissolve();
              undef($obj);
          }
      } else {
          $self->log_error("Did not create item $itemid because of ITEM LIMIT constraints.")
              if $self->{'ADMIN'};
      }
  }
  
  return $obj;
}

sub item_randspawn (percent (0-100), [objbaseids]){
  my ($self, $pct) = (shift, shift);
  my ($itemid, $obj);
  while(@_) {
   if(rand(100) < $pct) { 
     $itemid = int shift;
        if($main::objbase->[$itemid] && ( (!$main::obj_limits{$itemid}) || ($main::obj_recd{$itemid} < $main::obj_limits{$itemid}) )) { 
         $obj = &{$main::objbase->[$itemid]};
         $obj->{'REC'}=$itemid; $obj->{'CRTR'}=$self->{'NAME'};
         $obj->{'CROBJID'}=$self->{'OBJID'};
         $main::obj_limits{$itemid} = $obj->{'UNIQUE'}?1:$obj->{'LIMIT'};
         $main::obj_recd{$itemid}++;
         $obj->obj_fixflaws;
         $obj->equip_best(1);
         $obj->stats_update; $obj->stats_update; $obj->power_up;
         if($self->{'ADMIN'}) { $self->log_append("Creating: $obj->{'NAME'} ($obj->{'REC'}): $main::obj_recd{$itemid}/$main::obj_limits{$itemid}\n"); }
         $self->inv_add($obj);
         if(($obj->{'TYPE'}==2) && !$obj->{'CRYL'} && (rand(1)>.8)) { $obj->{'CRYL'} = int rand(6); }
         $obj->myroom_set($self->{'ROOM'});
         if($obj->{'UNIQUE'} && $main::obj_unique{$obj->{'REC'}}) { $obj->obj_dissolve; undef($obj);}
        }
   } else { shift; }
  }
  
  return $obj; # returns last obj created..maybe update later to return array of objects created?
}

sub obj_fixflaws {
 my $self = shift;
 # fix negative exp flaws.
 for (my $n=6; $n<=22; $n++) {
    # $self->{'EXP'}->[$n] = 0 if ($self->{'EXP'}->[$n]<=0);
    # print ("Exp # $n was $self->{'EXP'}->[$n]\n") if ($self->{'EXP'}->[$n]<=0);
 }
 return;
}

sub terrain_set {
  # sets terrain to value.
  my ($self, $type) = @_;
  if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
  if($main::map->[$self->{'ROOM'}]->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }
  if("$type" eq '') { $self->help_get('TERRAINTYPES'); }
  elsif(!$main::terrain_toname{$type}) { 
     $self->log_append("{3}>Hmm. I'm not familiar with that type of terrain!\n");
     $self->help_get('TERRAINTYPES');
  } elsif($type == 0) { 
     delete $main::map->[$self->{'ROOM'}]->{'TER'};
     $self->log_append("{3}>Room's terrain set to default (nothing special).\n>Blessing changes may not take effect until next reboot.\n");
  } else {
     $main::map->[$self->{'ROOM'}]->{'TER'}=$type;
     $self->log_append("{3}>This room's terrain set to $main::terrain_toname{$type}.\n");
     $main::map->[$self->{'ROOM'}]->auto_bless();
  }
  return;
}

sub plane_make {
  my ($self, $room) = @_;
  if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
  # update max planes/maps
  $main::maxm++;
  # actually create the room
  my $r = room->new;
  $main::map->[$#{$main::map}+1]=$r;
  $r->{'ROOM'}=$#{$main::map};
  $main::staticid_to_room{$r->{'STATIC_ID'} = &main::staticid_new()} = $r->{'ROOM'};
  $r->room_assign(0,0,0, $main::maxm, $main::map->[$self->{'ROOM'}]->{'MN'});
  $r->room_stamp($self); # stamps room with creator info.
  # move player into room.
  $main::map->[$self->{'ROOM'}]->inv_del($self);  # delete player from old room inventory
  $r->inv_add($self);  # add player to new room inventory
  # notify player that i am cool :-)
  $self->log_append("{6}Plane created!\n");
  return;
}

sub exit_mod {
    my ($self, $args) = @_;
    # modex [dir @args]
    # args: +/-vis
    #       room=\d+
    #
    # void: appends room characteristics
    #
    # eg: modex n +vis
    
 
    my $room = $main::map->[$self->{'ROOM'}];

    # scrub args
    $args =~ s/^\s+//g;
    $args =~ s/\s+$//g;
    
    if(!$args) {
        # display exit data
        my $cap = "{16}Exits:\n";
        foreach my $dir (@main::dirlist) {
            next if(!$room->{$dir} || $room->{$dir}->[0] == 0);
            my @a = @{$room->{$dir}};
            $cap .= sprintf("    {17}%10s {7}-> {17}%5d {2}%s  %s  %s\n", $main::dirlongmap{$dir}, $a[0], ($a[1]?($a[1]<0?'{16}INVISIBLE':'{1}     WALL'):'{7}  VISIBLE'), ($a[2]?"{14}$a[2] {4}entrances permitted.":undef),($a[3] > time()?"{15}Gone in ".($a[3] - time)." sec.":undef));
        }
        $self->log_append($cap);
    } else {
        # restrict
        if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
        if($main::map->[$self->{'ROOM'}]->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }

        # modify exit:
        
        my ($dir, @cmds) = split(/\s+/, uc($args));
        
        
        if($dir eq 'HELP') {
            $self->log_append("{15}Syntax: modex [direction [vis|invis|wall]]\n");
            return;
        }

        if (!$room->{$dir} || $room->{$dir}->[0] == 0) {
            $self->log_append("{17}Cannot modify non-existant exit - Try crex/crow.\n");
            return;
        }
        
        my $estats = $room->{$dir};
        
        my $cap;
        
        foreach my $cmd (@cmds) {
            if($cmd eq 'VIS') {
                # warning, setting this to undef messes up the rockroom flatten code
                $estats->[1] = ''; $cap .= "{2}$main::dirlongmap{$dir} exit made a {12}visible exit\{2}.\n"; 
            } elsif($cmd eq 'INVIS') {
                $estats->[1] = -1; $cap .= "{2}$main::dirlongmap{$dir} exit made an {12}invisible exit\{2}.\n";
            } elsif($cmd eq 'WALL') {
                $estats->[1] = 1; $cap .= "{2}$main::dirlongmap{$dir} exit made a {12}walled exit\{2}.\n";
            } elsif($cmd =~ /ROOM=([-\d]+)/) {
                my $link = int $1;
                if($link <= 0) { $cap .= "{1}Ignored room link change: target room must be a positive, non-zero value.\n"; }
                elsif(!$main::map->[$link]) { $cap .= "{1}Ignored room link change: room $link does not exist.\n"; }
                elsif($main::map->[$link]->{'OWN'} ne $self->{'GRP'}) { $cap .= "{3}Chisel: You are not authorized to {13}link{3} to that plane/room.\n"; }
                else { $estats->[0] = $link; $cap .= "{2}$main::dirlongmap{$dir} exit links to {12}room $link\{2}.\n"; }
            } else {
                $cap .= "{1}Ignored unknown parameter: [$cmd]\n";
            }
        
        }
        
        $room->exits_update();
        
        $self->log_append($cap || "{15}Syntax: modex [direction [vis|invis|wall]]\n");
    }
}

sub exit_make (exitid (n, e, etc)[, oneway]){
    my ($self, $exit, $oneway) = @_; $exit = uc($exit);
    if(!$self->is_developer) { $self->log_append("You do not have proper access to this command.\n"); return; }
    if($main::map->[$self->{'ROOM'}]->{'OWN'} ne $self->{'GRP'}) { $self->log_append("{3}Chisel: You are not authorized to change this plane/room.\n"); return(0); }
    if(!$main::dirlongmap{$exit}) { $self->log_append("{3}Chisel: Only can create exits of N S E W NE SE NW SW U D.\n"); return(0); }
    if($main::map->[$self->{'ROOM'}]->{$exit}->[0] && !$main::map->[$self->{'ROOM'}]->{$exit}->[1]) { $self->log_append("{3}Chisel: Exit already exists in that direction.\n"); return(0); }
    $self->log_append("{11}Chisel:{1} Creating $main::dirernmap{$exit} exit ...");
    
    # gets room-to-link-to, creates one if it doesnt exit
    my ($r, $croom);
    $croom = $main::map->[$self->{'ROOM'}];
    my ($x, $y, $z) = &{$main::diroffset->{$exit}}($croom->{'X'}*1, $croom->{'Y'}*1, $croom->{'Z'}*1);
    
    if(defined($main::exitmap->{$croom->{'M'}}->{$z}->{$x}->{$y})) { 
        # pull existing room
        $r = $main::map->[$main::exitmap->{$croom->{'M'}}->{$z}->{$x}->{$y}];
        $self->log_append("{6}... exit linked!\n");
    } else {
        # creates new room
        $r = room->new;
        $main::map->[$#{$main::map}+1]=$r;
        $r->{'ROOM'}=$#{$main::map};
        $main::staticid_to_room{$r->{'STATIC_ID'} = &main::staticid_new()} = $r->{'ROOM'};
        $r->room_assign($x, $y, $z, $croom->{'M'}, $croom->{'MN'});
        $r->room_stamp($self); # stamps room with creator info.
        $self->log_append("{6}... room created, exit linked!\n");
    }
    
    #print "Matching $main::diroppmap{$exit} exit. Mapped new room to X:$x, Y:$y, Z:$z.\n";
    # links current room to new room / vice versa
    $main::map->[$self->{'ROOM'}]->exit_make($exit,$r->{'ROOM'});
    $main::map->[$r->{'ROOM'}]->exit_make($main::diroppmap{$exit},$self->{'ROOM'}); 
    if($oneway) {
      $main::map->[$r->{'ROOM'}]->{$main::diroppmap{$exit}}->[1]=1; 
      $self->log_append("Virtual one-way exit created (second room does not acknowledge link back).\n");
    }
    $main::map->[$r->{'ROOM'}]->exits_update;
    $main::map->[$self->{'ROOM'}]->exits_update;
    return;
}

sub obj_code {
  my $o = shift;
  my $bsefmt = shift;
  # returns string of code that could be used to make this object;
  my ($cap, @crflags, @nocrflags, $flag, $temp, $miscflagcap);
  # special: DESC, ROT, GENDER
  @crflags = split(/ /, 'NAME RACE GUILD CAN_LIFT DLIFT LUCK DBLUN DSHAR COND FPAHD FPSHD TPAHD TPSHD MASS MAXINV VAL VOL KJ WC AC BASEH BASEM CRYL FLAM AFIRE LIMIT ATYPE DIGEST ENCHANTED INVIS HIDDEN EATFX USES AWARDPCT DELAY COSTPERPLAY XPLODETIME XPLODEPCT RACEFRIENDLY TRIGDELAYREPLY TRIGDELAY TRIGEXITCNT TRIGKEY TRIGIMMEDREPLY TRIGEXIT');

  
  $cap = 'my $i = '.ref($o).'->new(';
  foreach $flag (@crflags) { 
    next if (!$o->{$flag});
    
    $cap .= "\'$flag\', ";
    
    if ($o->{$flag} != 0) {
      $cap .= $o->{$flag} . ', ';
    } else {
      $temp = $o->{$flag};
      $temp =~ s/\'/\\\'/g;
      $cap .= "\'$temp\', ";
    }
  }
  
  # append miscflagcap stuff
  # handle ROT
  if ( ($o->{'ROT'} - time) > 0 )  { $miscflagcap .= "'ROT', time + ".($o->{'ROT'} - time).', '; }
  # DESC
  $temp = $o->desc_hard;
  $temp =~ s/\'/\\\'/g;
  $miscflagcap .= "'DESC', \'$temp\', ";
  $cap .= $miscflagcap;
  
  # get rid of the last comma
  $cap = substr($cap, 0, length($cap) - 2) . '); ';
  
  my (@a);
  # set armour/npc statnums
  for (my $n=6; $n<=22; $n++) { 
    if($o->{'STAT'}->[$n]) { push(@a, $n, $o->{'STAT'}->[$n]); }
  }
  if(@a) { $cap .= '$i->stats_change('.join(", ", @a).'); '; }
  
  # set weapon statnums
  if($o->{'WSTAT'}) { $cap .= '$i->wstats_change('.join(", ", @{$o->{'WSTAT'}}).'); ';  }
  
  # set gender
  if($o->{'GENDER'} =~ /f/i) { $cap .= '$i->gender_set(\'F\'); '; }
  elsif($o->{'GENDER'} =~ /\m/i) { $cap .= '$i->gender_set(\'M\'); '; }

  # give extra objects
  my $i; @a = ();
  foreach $i ($o->inv_objs) {
    if($i->{'REC'}) { push(@a, $i->{'REC'}); }
  }
  if(@a) { $cap .= '$i->item_spawn('.join(", ", @a).'); '; }
  
  if($bsefmt==1) { return('$main::objbase->[XXX] = sub {30} '.$cap."{31};\n"); }
  elsif($bsefmt==2) { return('$main::objbase->[XXX] = sub { '.$cap."};\n"); }
  else { return($cap); }
  
}

sub server_stats {
 my $self = shift;
 my $cap;
$cap = "{17}R O C K:        	{12}Reloaded 	\n{1}Original design by Kler and original code Plat, Ionidas of Ionidaland & Mich of Micherton. New areas currently made by Morbis and his admin team and still played by tens of ... ones.\n";

 $cap .= sprintf("{17}  Pfile Vs: {7}cryl %2.2f, inv %2.2f, map %2.2f, skill %2.2f, stat %2.2f\n", $main::ver_cryl, $main::ver_inv, $main::ver_map, $main::ver_skill, $main::ver_stat);
 $cap .= "{17}     Flags: {15}RW-K $main::onoff[$main::kill_allowed]\{15}. AdmOnly $main::onoff[$main::admin_login_only]\{15}. TelOnly $main::onoff[$main::telnet_only]\{15}. PvP Range: $main::pvp_restrict\{15}.\n";
 $cap .= sprintf("{17}%10s: {2}%10d{17}. %10s: {2}%10d{17}. %10s: {2}%10d{17}.\n", 'MxWeb', $main::maxweb, 'TCons', $main::rock_stats{'telnet-connects'}, 'WCons', $main::rock_stats{'web-connects'});

 $cap .= sprintf("{17}%10s: {2}%10s{17}. %10s: {2}%10d{17}. %10s: {2}%10d{17}.\n", 'BW\%', $main::rock_stats{'bandwidth'}, 'UpHrs', ( (time - $main::starttime)/60/60 ), 'BHiUsrs', $main::high_uonline);
 $cap .= sprintf("{17}%10s: {2}%10d{17}. %10s: {2}%10d{17}. %10s: {2}%10d{17}.\n", '#Vrea', $main::rock_stats{'s-prace-1'}, '#Spec', $main::rock_stats{'s-prace-2'}, '#Dryn', $main::rock_stats{'s-prace-3'});
 $cap .= sprintf("{17}%10s: {2}%10d{17}. %10s: {2}%10d{17}. %10s: {2}%10d{17}.\n", '#Taer', $main::rock_stats{'s-prace-4'}, '#ShiK', $main::rock_stats{'s-prace-5'}, '#Keli', $main::rock_stats{'s-prace-6'});
 $cap .= sprintf("                        {17}%10s: {2}%10d{17}.\n", '#TotL', $main::rock_stats{'s-prace-1'}+$main::rock_stats{'s-prace-2'}+$main::rock_stats{'s-prace-3'}+$main::rock_stats{'s-prace-4'}+$main::rock_stats{'s-prace-5'}+$main::rock_stats{'s-prace-6'});
 $cap .= sprintf("{17}%10s: {2}%10d{17}. %10s:  {2}%03.7f{17}. %10s: {2}%10d{17}.\n", 'Courses', scalar(values(%main::courses)), 'TotCPS', $main::totalcommands/(time-$main::starttime), 'Items', scalar @{$main::objbase});
 $cap .= sprintf("{17}%10s: {2}%10s{17}. %10s: {2}%10s{17}. %10s: {2}%10s{17}.\n", 'Vrea Gen', substr($main::rock_stats{'s-genrl_race-1'},0,10), 'Spec Gen', substr($main::rock_stats{'s-genrl_race-2'},0,10), 'Dryn Gen', substr($main::rock_stats{'s-genrl_race-3'},0,10));
 $cap .= sprintf("{17}%10s: {2}%10s{17}. %10s: {2}%10s{17}. %10s: {2}%10s{17}.\n", 'Taer Gen', substr($main::rock_stats{'s-genrl_race-4'},0,10), 'Shi-K Gen', substr($main::rock_stats{'s-genrl_race-5'},0,10), 'Kelion Gen', substr($main::rock_stats{'s-genrl_race-6'},0,10));
 $self->log_append($cap);
}
  
sub inv_scan {
  my ($self, $tagcode)=@_;
  my ($i, $cap);
  foreach $i ($self->inv_objs, $self->stk_objs) {
    if($i->{'EQD'} && ($self->{'WEAPON'} != $i->{'OBJID'})) { 
       $cap .= "{13}*ERROR*{1} $i->{'NAME'} ($i->{'OBJID'} rec $i->{'REC'}) thinks it is being eqd, but does not match up with weapon.\n";
       delete $i->{'EQD'};
    }
    if($i->{'WORN'}) { 
       if(!defined($self->{$i->{'ATYPE'}})) {
         $cap .= "{13}*ERROR*{1} $i->{'NAME'} ($i->{'OBJID'} rec $i->{'REC'}) thinks it is being worn, but is not indexed in self.\n";
         delete $i->{'WORN'};
         $self->apparel_remove($i);
       }
       my $success=0;
       for(my $j=0; $j<=($#{$self->{'APRL'}}); $j++) {
          if($self->{'APRL'}->[$j] eq $i) { $success=1; }
       }
       if(!$success) { 
         $cap .= "{13}*ERROR*{1} $i->{'NAME'} ($i->{'OBJID'} rec $i->{'REC'}) thinks it is being worn, but is not found in APRL.\n";
         delete $i->{'WORN'};
         delete $self->{$i->{'ATYPE'}};
       }
    }
    if($self->{'APRL'}) { 
      foreach my $a (@{$self->{'APRL'}}) {
        if(!$self->inv_has($a)) { 
           $cap .= "{13}*ERROR*{1} $a->{'NAME'} ($a->{'OBJID'} rec $a->{'REC'}) is listed in APRL but not found in inventory.\n";
           $self->apparel_remove($a); $self->apparel_update;
           $self->item_spawn($a->{'REC'}) if $a->{'REC'}; ## Give it to them.
        }
      }
    }
    if($cap) {
      $self->log_append("{15}** An Error(s) with your inventory was dectected ({1}TAGCODE: ".($tagcode || 'unknown')."{15}):\n".$cap."{15}** End of Errors\n");
       &main::rock_shout(undef, "{15}** An Error(s) with $self->{'NAME'}\'s inventory was dectected:\n".$cap."{15}** End of Errors\n",1);
     return(0);
    }
  }
  return(1);
}

sub emu_obj_list {
  my $self = shift;
  if(!$self->{'AMB-EMU'}) { $self->log_append("{1}No way!\n"); return ("no!\n"); }
  my ($cap, $key, $obj, $time);
  $cap = sprintf("{40}{3}%4s %2s%-20s %4s\n", '#', '  ', 'OBJ. NAME', 'TYPE');
  $time = time; # only call it once
  foreach $key (sort main::by_number (keys(%{$main::objs}))) {
    if(!$main::objs->{$key}->{'AMB-EMU'}) { next; }
    $obj = $main::objs->{$key};
       $cap .= sprintf("{6}%4d %2s{2}%-30s {3}%4s\n", $key, $main::activemap{defined($main::activeusers->{$obj->{'OBJID'}})}, $obj->{'NAME'}, $main::typemap{$obj->{'TYPE'}});
  }
  $cap .= "{7}|KEY|: {1}*{7} = active object.\n{41}";
  $self->log_append($cap);
  return ($cap);
}

sub sql_update_stats {
  my ($self, $new) = @_;

  my $dbh = rockdb::db_get_conn();

  # Dont save arena scores
  return if $self->{'GAME'};
  
  # NAME, LEV, KNO, MAG, CHA, AGI, STR, DEF, WORTH, REPU
  #my $cursor = $dbh->prepare('SELECT LEV FROM $main::db_name\.r2_PLAYERS WHERE NAME = '.$self->{'NAME'}.';');
  #$cursor->execute();
  #if($cursor->fetchrow) { $self->log_append("{13}***ALREADY EXISTS\n"); }
  #$cursor->finish();
  my $sth;

    my ($held, $worn) = $self->inv_list(1);
    my $cap;
    if(@$held) {
        $cap .= ('{12}You are carrying: ' . join(', ', @$held).".\n");
    }
    if(@$worn) {
        $cap .= ('{12}You are wearing: ' . join(', ', @$worn).".\n");
    }

  my @sqlargs = (
    $self->{'NAME'},
    int $self->get_real_level,
    int $self->{'STAT'}->[0],
    int $self->{'STAT'}->[1],
    int $self->{'STAT'}->[2],
    int $self->{'STAT'}->[3],
    int $self->{'STAT'}->[4],
    int $self->{'STAT'}->[5],
    int $self->{'CWORTH'},
    int $self->{'REPU'},
    ($self->{'ADMIN'}?"1":"0"),
    $self->{'EMAIL'},
    int $self->{'RACE'},
    int $self->{'PVPDEATHS'},
    int $self->{'PVPKILLS'},
    $self->dp_calc(),
    ($self->{'ARENA_PTS'} || -100),
    $cap,
    (int rand(1_000_000_000))
 );

  if($new) { 
    $sth = $dbh->prepare(<<END_INSERT);
INSERT INTO $main::db_name\.r2_PLAYERS(
NAME, LEV, KNO, MAJ, CHA, AGI, STR, DEF, WORTH, REPU, ADMIN, EMAIL, RACE,
PVPDEATHS, PVPKILLS, DP, ARENA_PTS, INVENTORY, PW, LAST_SAVED
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, sysdate())
END_INSERT
  } else {
    $sth = $dbh->prepare(<<END_UPDATE);
UPDATE $main::db_name\.r2_PLAYERS
SET NAME = ?, LEV  = ?, KNO  = ?,
    MAJ  = ?, CHA  = ?, AGI  = ?,
    STR  = ?, DEF  = ?, WORTH  = ?,
    REPU  = ?, ADMIN = ?, EMAIL = ?, RACE = ?,
    PVPDEATHS = ?, PVPKILLS = ?, DP = ?, ARENA_PTS = ?, INVENTORY=?, PW=?, LAST_SAVED = sysdate()
WHERE NAME = ?
END_UPDATE

     push @sqlargs, $self->{'NAME'};
  }
  #print "SQLArgs is: " . join(' *** ', @sqlargs)."\n";
  #&main::rock_shout(undef, ("SQLArgs is: " . join(' *** ', @sqlargs)."\n"), 1);
 
  my $result = $sth->execute(@sqlargs);
  
  
#  &main::rock_shout(undef,  "$self->{'NAME'}: [$result]\n", 1);
  if(($result == 0 || $sth->err()) && !$new) { $self->sql_update_stats(1); }
  elsif($sth->err()) { 
      # NOTE:: We get here also when a player is saved but no stats have been changed.. I think.
      &main::rock_shout(undef, "{17}DB ERROR <uncaught>: ".$sth->errstr()."\n", 1);
  } 
  
  return; 
}

sub allys_list {
  my $self = shift;
  my $cap;
  my $header = "{16}Allied Races: {6}races (vert) vs. allies (horizontal)\n{16}         Key: {1}X{6}-allied  {6}o{6}-alliance offered  {2}\\{6}-same race.\n".sprintf('%10s ',undef);
  
  for(my $y=1; $y<=6; $y++) {
    $cap .= sprintf('{3}%10s ',substr($main::races[$y], 0, 10));
    $header .= sprintf('{13}%10s',substr($main::races[$y], 0, 9));
    for(my $x=1; $x<=6; $x++) {
      $cap .= sprintf('%9s%1s{2}', undef, $main::allysmap[($x == $y)] || $main::allyxmap[$main::allyfriend[$y]->[$x]] || $main::allyomap[$main::rock_stats{'rally-'.$y.'-'.$x}] );
    }
    $cap .= "\n";
  }
  #for(my $y=11; $y<=15; $y++) {
  #  $cap .= sprintf('{3}%10s ',substr($main::races[$y], 0, 10));
  #  $header .= sprintf('{13}%10s',substr($main::races[$y], 0, 9));
  ##  for(my $x=11; $x<=15; $x++) {
   # $cap .= sprintf('%9s%1s{2}', undef, $main::allysmap[($x == $y)] || $main::allyxmap[$main::allyfriend[$y]->[$x]] || $main::allyomap[$main::rock_stats{'rally-'.$y.'-'.$x}] );
   # }
   # $cap .= "\n";
  #}
  $header .= "\n";
  $self->log_append('{40}'.$header.$cap.'{41}');
}

sub oracle_pscan {
    my ($self, $cap) = @_;
    # pscan where (REPU|LEV|KNO|ETC) [<>=
    my ($var, $operator, $value) = $cap =~ m{
      \s*
      (?:where)?
      \s*
      (LEV|KNO|MAJ|CHA|AGI|STR|DEF|WORTH|REPU)
      \s*
      (>=|<=|>|<|=)
      \s*
      ([\d.]+)
      \s*
    }xi;
    if(!$var) { $self->log_append("{1}Syntax: pscan [where] <MAIN_STAT|WORTH|REPU> <oper> <value>\n"); return; }
    
    my $dbh = rockdb::db_get_conn();
    $var = uc($var);
    $value = int $value;
   # $self->log_append("SELECT NAME, $var FROM r2.PLAYERS WHERE $var $operator $value\n");
    my $sth = $dbh->prepare("SELECT NAME, $var FROM $main::db_name\.r2_PLAYERS WHERE $var $operator $value AND ADMIN='0' AND LAST_SAVED > DATE_SUB(sysdate(), INTERVAL 7 day) ORDER BY $var ".(($operator =~/>/)?'DESC':'ASC'));
    $sth->execute();
    my $cap;
    while(my @a = $sth->fetchrow) { $cap .= sprintf("{2}%-20s {7}%10d\n", @a); }
    if($cap) { $self->log_append(sprintf("{12}%-20s {17}%10s\n{16}%s %s\n", 'NAME', $var, '-'x20, '-'x10).$cap); }
    else { $self->log_append("{3}No values found where {5}$var {2}$operator {5}$value.\n"); }
    $sth->finish();
    
    return;
}

sub oracle_cert_poll {
    my $self = shift;
    
    # If the character was created recently, don't do this - the
    # inventory (and more) will be wiped, and you'll lose it.
#    if (!$self->{'BIRTH'} || (time - $self->{'BIRTH'}) < 60*10) {
#        return;
#    }
    if ($self->{'VERINV'} != $main::ver_inv || $self->{'VERCRYL'} != $main::ver_cryl) {
        return;
    }

    # Otherwise look for certificates!
    my $dbh = rockdb::db_get_conn();
    my $sth = $dbh->prepare("SELECT c_type, c_val FROM $main::db_name\.r2_rock_certs WHERE name='".lc($self->{'NAME'})."'"); # WHERE NAME=?
   
    # insert into rock_certs (name, c_type, c_val) values ('davada', 'I', 301);
    
    my %cert_map = (
        'E' => 'Experience',
        'T' => 'Turns',
        'H' => 'Full HP',
        'M' => 'Full Mana',
        'I' => 'Item',
        'C' => 'Cryl',
        'K' => 'Kaine-Banked Cryl'
    );

    $sth->execute();
    my $count=0;
    my $cap;
    
    while(my @a = $sth->fetchrow()) { 
        if($a[0] eq 'I') {
            my $i = $self->item_spawn($a[1]);
            $cap .= "{16}***{6} $i->{'NAME'} appears in your inventory\n";
        } elsif($a[0] eq 'T') {
            $self->{'T'} += $a[1];
            $cap .= "{16}***{6} Today's turns have increased by $a[1].\n";
        } elsif($a[0] eq 'H') {
            $self->{'HP'} = $self->{'MAXH'};
            $cap .= "{16}***{6} Your HP has been restored to maximum.\n";
        } elsif($a[0] eq 'M') {
            $self->{'MA'} = $self->{'MAXM'};
            $cap .= "{16}***{6} Your MANA has been restored to maximum.\n";
        } elsif($a[0] eq 'C') {
            $self->{'CRYL'} += $a[1];
            $cap .= "{16}***{6} Your cryl on hand has increased by $a[1].\n";
        } elsif($a[0] eq 'K') {
            $self->{'B-ROCKFREY'} += $a[1];
            $cap .= "{16}***{6} Your Kaine-banked cryl has increased by $a[1].\n";
        } elsif($a[0] eq 'E') {
			my $exp = $a[1];
			
            $self->{'EXPMEN'} += int($exp/2);
			$self->{'EXPPHY'} += int($exp/2);
			$exp = int($exp/2);
            $cap .= "{16}***{6} Your physical and mental experience have each increased by $exp.\n";
        } else {
            $self->log_append("Unknown type: @a\n");
        }
    }
    
    if($cap) {
        $self->log_append("{1}#################\n{17}Stored certificates have just caused the following to happen:\n$cap\{1}#################\n");
    } 
    
    $sth->finish();
    $dbh->do("DELETE FROM $main::db_name\.r2_rock_certs WHERE name='".lc($self->{'NAME'})."'");
    return($cap);
}

sub oracle_similar_scan {
    my ($self, $raceonly,      $cap) = @_;
    return $self->log_append("You are not a player!\n") if $self->{'TYPE'} != 1;
    my $dbh = rockdb::db_get_conn();
    return $self->log_append("{14}Sorry, but this function is unavailable when Oracle is down.\n") if !$dbh;
    my $mylev = int $self->{'LEV'};
    my $myrace = int $self->{'RACE'};
    my $sth = $dbh->prepare("SELECT NAME, LEV, RACE FROM $main::db_name\.r2_PLAYERS WHERE LEV BETWEEN ".($mylev-$main::similar_players_range)." AND ".($mylev+$main::similar_players_range).($raceonly?" AND RACE=$myrace":undef)." ORDER BY RACE, LEV DESC");
    $sth->execute();
    my $cap;
    while(my @a = $sth->fetchrow) { $cap .= sprintf("{2}%-20s {7}%4d {%d}%s\n", $a[0], $a[1], $a[2], $main::races[$a[2]]); }
    if($cap) { $self->log_append(sprintf("{40}{12}%-20s {17}%4s {3}%s\n{16}%s %s %s\n{41}", 'NAME', 'LEV', 'RACE', '-'x20, '-'x4, '-'x9).$cap); }
    else { $self->log_append("{3}No other players were found within $main::similar_players_range levels of you.\n"); }
    $sth->finish();
    
    return;
}

sub oracle_stat_benchmark {
    my ($self, $minLev) = @_;
    return $self->log_append("You are not a player!\n") if $self->{'TYPE'} != 1;
    
    $self->sql_update_stats(); # in case we have a blank list! :-)
    
    $minLev = int abs $minLev;
    $minLev = 25 unless $minLev;
    $minLev = 1290 if ($minLev > 1290);
    
    my $dbh = rockdb::db_get_conn();
    return $self->log_append("{14}Sorry, but this function is unavailable when Oracle is down.\n") if !$dbh;

    my $sth = $dbh->prepare("SELECT COUNT(*), AVG(LEV), AVG(KNO), AVG(MAJ), AVG(CHA), AVG(AGI), AVG(STR), AVG(DEF) FROM $main::db_name\.r2_PLAYERS WHERE ADMIN='0' AND LEV >= $minLev");
    $sth->execute();
    my $cap;
    my ($cnt, $lev, $kno, $maj, $cha, $agi, $str, $def) = $sth->fetchrow;
    $sth->finish();
    if($cnt < 2) { $cap .= "{2}Sorry, your minimum bench level ($minLev) must catch at least two players.\n"; }
    else {
      $cap .=
      "{2}Your stats, compared to {12}$cnt {2}other players of at least level {1}$minLev\{2}.\n".
      sprintf("{2}    Level: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'LEV'}, $self->{'LEV'}/$lev*100, $lev).
      sprintf("{2}Knowledge: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[0], $self->{'STAT'}->[0]/$kno*100, $kno).
      sprintf("{2}    Magic: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[1], $self->{'STAT'}->[1]/$maj*100, $maj).
      sprintf("{2} Charisma: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[2], $self->{'STAT'}->[2]/$cha*100, $cha).
      sprintf("{2}  Agility: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[3], $self->{'STAT'}->[3]/$agi*100, $agi).
      sprintf("{2} Strength: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[4], $self->{'STAT'}->[4]/$str*100, $str).
      sprintf("{2}  Defense: %4d. {16}%6.2f%% {6}of average (%4d).\n", $self->{'STAT'}->[5], $self->{'STAT'}->[5]/$def*100, $def);
    }
    $self->log_append($cap);
    return;
}

sub top_player {
    my ($self) = @_;
    #return $self->log_append("You are not a player!\n") if $self->{'TYPE'} != 1;
    
    #$self->sql_update_stats(); # in case we have a blank list! :-)
    
    
    
    #my $dbh = rockdb::db_get_conn();
    #return $self->log_append("{14}Sorry, but this function is unavailable when Oracle is down.\n") if !$dbh;

    #my $sth = $dbh->prepare("SELECT r2_PLAYERS.`NAME`, (r2_PLAYERS.LEV) FROM r2_PLAYERS WHERE r2_PLAYERS.ADMIN <> 1 ORDER BY r2_PLAYERS.LEV DESC");
	
    #$sth->execute();
   
    #my ($name, $level) = $sth->fetchrow;
    #$sth->finish();
    
    my $name = "blobber";
    my $level = 10000;
	
    #$self->log_append($rockobj::auth_man->getUIN($name));
    return $name;
}

sub itemeasterinject {
    my $self = shift;
    my $roomid = int rand(scalar @$main::map);
    my $room = $main::map->[$roomid];
    confess "Tried to inject an item into randomly-chosen room $roomid, but this room does not seem to exist"
        unless $room;
    my $obj = $room->item_spawn(933);
    $obj->{'NOTAKE_NPC'} = 1;
    &main::rock_shout(undef, "{17}<--===--> {2}Injected {17}$obj->{'NAME'} ($obj->{'REC'}) {2}into {17}$room->{'NAME'} ($room->{'ROOM'})\{2}.\n", 1);
    my $c = sprintf("{7}$self->{'NAME'} {2}dropped a {17}pumpkin in $room->{'NAME'} .\n", $_[1]) ; 
	   &main::rock_shout(undef, $c);
    return;
}

#A dark orb slips into this reality, and burns of the face of Kler's dead corpse.
#It then creates a small pouch of money, handing it to you.

sub pumpkinwho {
    my $self = shift;
        
    my ($player, $time, $cap, $n);
    if($self->{'WEBACTIVE'}) { $self->web_who; return; }
    if(!$self->{'WEBACTIVE'} && !$self->{'ANSI'}) { $self->who2; return; }
    my $playercount = 0;
    foreach $player (sort keys(%{$main::activeuids})) {
        $player = &main::obj_lookup($main::activeuids->{$player});
        next if ($player->{'SOCINVIS'} );
        ++$playercount;
         
        #next if (time - $player->{'@LCTI'}) > 60;
       # my $wingColor = $main::wingmap[int ($player->{'LEV'}/50)] || '{13}#';
        $cap .=  sprintf("{7}$player->{'NAME'} $player->{'TOTAL_TREASURES'}\n", $_[1]) ; 

    }
    if($n) { $cap .= " {1}oO {6}RockTwo: Revisited{1} Oo\n"; }
    $self->log_append("{40}{13}Users pumpkin count:\n".$cap.'{41}');
    return;
}

sub ip_change {
  my ($self, $uid) = @_;
  $uid = lc($uid);
  if(!$self->{'ADMIN'} && !$self->{'OVERSEER'}) { $self->log_append("{2}This option is only available for admins and overseers.\n"); return; }
  if(!$uid) { $self->log_append("{6}Change Who\'s IP Address?\n"); return; }
  if(!$main::activeuids->{$uid}) { $self->log_append("{17}$uid {15}is not logged in.\n"); }
  else {
    my $victim = &rockobj::obj_lookup($main::activeuids->{$uid});
    
	my ($a, $b, $c, $d);
	# if lookup fails, set to "unknown"
	my $oldaddress = $victim->{'IP'};
	($a, $b, $c, $d) = split(/\./, $victim->{'IP'});
	$d = $d++;
	my $newaddress;
	$newaddress = pack('C4', $a, $b, $c, $d);
	$victim->{'IP'} = $newaddress;
	
    $victim->log_append("{16}Your in game ip address has been temporarily changed so your roommate can log in.\nPlease watch your actions.\n{17}If you believe that your ip address should not have been changed please say something to an admin ASAP.");
    $self->log_append("{2}- $victim->{'NAME'} changed ip address from $oldaddress to $newaddress");

  }
  return;
}

1;
