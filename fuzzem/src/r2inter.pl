### Contains interface for Rock II ###

#####################################################################
use rock_prefs; # MUST BE FIRST TO FUNCTION PROPERLY. NO EXCEPTIONS #
#####################################################################

use MLDBM qw(DB_File);

require('db_tie.pl');
use r2inter;

use event_queue;
$main::eventman = new event_queue;
$main::eventman->enqueue(60, \&rock_maint::Dillfrog_WritePlayerList);
$main::eventman->enqueue(60, \&rock_maint::auction_reimburse);

use bytes;

use ora_scores;
use const_stats;
use rockobj;
use rockroom; 
use rockunit;
use rockitem; 
use rockspell; 
use rockmons;
use rockadmin;
use rockstock;
use rockcryl;
use rockracial;
use rockai;
use rockauto;
use rockmaint;
use realm_maint;


use Benchmark;
use strict;

    &set_pointers; # SET UP POINTERS.

# Note: mainconsts.bse MUST BE LOADED AFTER db_tie.pl
my @files_to_load = qw(effects.bse commands.bse objcustcmd.bse spells.bse mainconsts.bse courses.bse recipes.bse mapper.pl dumpvar.pl scores.pl);
push @files_to_load, glob("items*.bse"); # add the items*.bse files that you see
foreach my $fname (@files_to_load) {
    print "Loading $fname\n";
    require $fname;
}


# take care of startup maintenance.
&update_uidmap();

#&uidsRegister;

&racemult_gen();


if (!$main::rock_dont_load){
    print "Loading..\n";
    &rock_init();
    print "Loaded..\n";
}


# version control
if ($main::rock_stats{'ver_mili'} < $main::ver_mili) { 
    $main::rock_stats{'ver_mili'} = $main::ver_mili;
    %main::general_votes = ();
    &rock_maint::votes_tally();
}

if ($main::rock_stats{'ver_stat'} < $main::ver_stat) { 
    $main::rock_stats{'ver_stat'} = $main::ver_stat;
    delete $main::rock_mdim{'dp_scores'};
}

if ($main::rock_stats{'ver_cryl'} < $main::ver_cryl) { 
    $main::rock_stats{'ver_cryl'} = $main::ver_cryl;
    %main::bounties = ();
}

#&main::write_course_html();

# INIT TIMERS
&main::timed_item_injection();
&main::timed_repu_fun();
#&main::timed_score_update();
&main::enviro_idle();
$main::eventman->enqueue(60 * 15, \&main::check_auto_cleanup);
$main::eventman->enqueue(45, \&main::write_playerotm_html);
&main::check_new_turns();
$main::pvp_restrict = $main::rock_stats{'pvprestrict'} unless !defined($main::rock_stats{'pvprestrict'});

# LAST
&main::commands_soundex();
# schedule pistol spawning time
$main::eventman->enqueue(int rand(60*60*8), \&rockobj::item_spawn, $main::map->[$main::roomaliases{'bandit-storage-room'}], 46);

1;


sub set_pointers {
 # SET UP POINTERS.
 $main::objs = \%{$main::realm->{'OBJS'}};
 $main::map = \@{$main::realm->{'MAP'}};
 $main::uidmap = \%main::uidmap;
 $main::desc = \@{$main::realm->{'DESC'}};
 
 use HashScan;
 tie %$main::objs, 'OBJSHashScan';
 $main::activeuids = {};
 tie %$main::activeuids, 'AUIDSHashScan';
 # prepare main::objs buckets for lots-o-keys
 keys(%{$main::objs}) = 15000;
 return;
}

sub item_spawn {
  foreach my $r (@{$main::map}) { 
      if($r->{'ITEMSPAWN'}) {
         $r->item_spawn(split(/\,/, $r->{'ITEMSPAWN'})); # item_spawn already has all the error-checking built in
      }
  }
  return;
}

sub rock_init {
   # initializes game
   &entropy_generate; # creates/modifies entropy vars
   print "Import manually? ";
   $main::highobj = -1; # was <> (next line) instead of 'Y'
   if (1 =~ /y|Y|yes|YES|1/) { &rock_import_realm; &rock_init_items; }
   else { &rock_load; } 
   #&rock_import_realm; &rock_init_items;
   #&rock_load;
   &rock_coordinit;
   &rock_import_commands;
   &load_libs;
   $main::dual_friend = rock_dualchar->new;
   $main::maint_friend = rock_maint->new;
   $main::msg_friend = rock_message->new;
   &item_spawn;
   &fill_aliases;
   print "cleaning up objects..\n";
   &cleanup_rooms; &cleanup_objs;
   &main::help_set_actions;
 #  print "ORS'ing..\n";
 #  &main::object_briefing;
   print "spawning objects / idle x 3\n";
  # &spawn_stuff; &objs_idle; &spawn_stuff;
   print "done importing.\n";
}

sub entropy_generate {
  my @a; # temp
  
  # Volrath
  $main::entropy{'banditanalyzer'} = 10000 + int rand(90000);
  $main::entropy{'padlocktrigger'} = 1000 + int rand(9000); 
  # 

  
  @main::parch_codes = ();
  @a = ('The foul air rises', 'The dark air blows', 'The black air engulfs', 'The doomed air gusts', 'The polluted air sings', 'The tainted air howls', 'The fallen air wails', 'The air is still', 'The air is wild');
  $main::entropy{'parch_air'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The fire burns', 'The fire consumes', 'The fire purifies', 'The fire destroys', 'The raging fire dances', 'The calm fire dies', 'The fire scorches', 'The tainted fire pollutes', 'The darkened fire burns eternal');
  $main::entropy{'parch_fire'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The earth shakes', 'The earth crumbles', 'The earth rattles', 'The earth quakes', 'The cracked earth wails', 'The earth booms', 'The scorched earth dies', 'The earth stands fast', 'The earth splits asunder');
  $main::entropy{'parch_earth'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The water flows', 'The water heals', 'The water reshapes', 'The water slides', 'The tainted water poisons', 'The poisoned water taints', 'The clear water sustains', 'The water submits', 'The darkened water fades');
  $main::entropy{'parch_water'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  ##
  @a = ('The foul snow rises', 'The dark snow blows', 'The black snow engulfs', 'The doomed snow gusts', 'The polluted snow sings', 'The tainted snow howls', 'The fallen snow wails', 'The snow is still', 'The snow is wild');
  $main::entropy{'parch_snow'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The fire burns', 'The ice consumes', 'The ice purifies', 'The ice destroys', 'The raging ice dances', 'The calm ice dies', 'The ice scorches', 'The tainted ice pollutes', 'The darkened ice frezes eternal');
  $main::entropy{'parch_ice'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The sleet shakes', 'The sleet crumbles', 'The sleet rattles', 'The sleet quakes', 'The cracked sleet wails', 'The sleet booms', 'The frozen sleet dies', 'The sleet stands fast', 'The sleet splits asunder');
  $main::entropy{'parch_sleet'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @a = ('The slush flows', 'The slush heals', 'The slush reshapes', 'The slush slides', 'The tainted slush poisons', 'The poisoned slush taints', 'The clear slush sustains', 'The slush submits', 'The darkened slush fades');
  $main::entropy{'parch_slush'} = $a[(int rand($#a+1))];
  for(my $n=0; $n<=$#a; $n++) { $a[$n]=lc($a[$n]); } push(@main::parch_codes, @a);
  @main::parch_codes = sort(@main::parch_codes);
  
  
  @a = &entropy_orcSecurityPhrases(); 
  $main::entropy{'orc_security1'} = ["@a", @a];
  @a = &entropy_orcSecurityPhrases(); 
  $main::entropy{'orc_security2'} = ["@a", @a];
  @a = &entropy_orcSecurityPhrases(); 
  $main::entropy{'orc_security3'} = ["@a", @a];
  
  
  $main::entropy{'tree_c_fir'} = &main::rand_ele(qw(wooden rusty bloated old new funky glittery used short tall thick smelly wicked corny white flourescent tasty));
  $main::entropy{'tree_c_rosewood'} = &main::rand_ele(qw(nails denominations people numbers pasts fevers ladies men chickens golds clothes fish worlds signs butters));
  $main::entropy{'tree_c_greenwood'} = &main::rand_ele(qw(ridicule help love hurt smolder burn rust decompose rebuild grow simplify condescend revoke tenderize hold break));
  $main::entropy{'tree_c_willow'} = &main::rand_ele(qw(your melting my world green fiber plastic puny sliding smelly vegetarian));
  $main::entropy{'tree_c_maple'} = &main::rand_ele(qw(earths relations cheeses neons fun distaste fever dressings vegetarians cows grasses oats milks));
  $main::entropy{'tree_c_master'} = "$main::entropy{'tree_c_fir'} $main::entropy{'tree_c_rosewood'} $main::entropy{'tree_c_greenwood'} $main::entropy{'tree_c_willow'} $main::entropy{'tree_c_maple'}";
  
  return;
}

sub entropy_orcSecurityPhrases {
  return(substr(&main::pw_generate(),0,4), substr(&main::pw_generate(),0,4), substr(&main::pw_generate(),0,4));
}

sub rock_coordinit {
  # init max/mins.
  $main::maxx = $main::maxy = $main::maxz = 0;
  $main::minx = $main::miny = $main::minz = 0;
  print "    Renumbering...\n";
  my ($r, $m, $totrooms, $mn);
  $main::maxm=0;  $totrooms = @$main::map; $mn = time; # $mn = !$main::map->[0]->{'MN'}*1;
  for ($r=0; $r<$totrooms; $r++) {
    if( ($main::map->[$r]->{'MN'} != $mn)) { 
      print "Assigning map $main::maxm to room $r ($main::map->[$r]->{'NAME'})....\n";
      $main::map->[$r]->room_assign(0,0,0,$main::maxm,$mn);
      $main::maxm++;
    }
  }
  print "    MAX: X=$main::maxx. Y=$main::maxy. Z=$main::maxz...\n";
  print "    MIN: X=$main::minx. Y=$main::miny. Z=$main::minz...\n";
  print "    Creating map reference...\n";
  &map_gencoords;
  return;
}


sub rock_init_items {
   my $currobj;
   my $n = 1;
   return;
}

sub rock_newp (fileno, Name, uid, pw, [ email ]) {
  my ($fileno, $name, $uid, $pw, $email) = @_;
  ### Set up Player
  my $player = player->new; 
  $player->{'NAME'}='Untitled Player';
  #$player->{'NAME'}=$name;
  $player->{'RACE'}=0;
  $player->{'TELNET'}=1;
  $main::activeusers->{$player->{'OBJID'}}=time;
  $main::sockplyrs->{$fileno} = $player; # sets up plat's info.
  $main::map->[1]->inv_add($player);
  #$main::sockplyrs->{$fileno}->room_log;
  #$player->room_tell('{12}'.$player->{'NAME'}.' {16}materializes from out of the ether.'."\n");
  return;
}


sub rock_destp (socket){
  my ($fileno, $quiet) = @_;
  return if !defined($main::sockplyrs->{$fileno});
  my $obj   = $main::sockplyrs->{$fileno};
  my $objid = $obj->{'OBJID'};
  delete $main::sockplyrs->{$fileno}; # delete socket object
  
  if($obj->canLogoutOnTelDiscon(1)) { $obj->obj_logout; }

  return;
}

sub rock_import_realm {
  use strict;
  print "Interpreting rooms..please hold..\n";
  my (@cap, $capline, $key, $val, $rline, @rnamestomap, $scrap, %conv_store_ids); # ra = room array
  my (%roomstoi);
  open (RFILE, '<r-allrooms.txt') or die "Could not load r-allrooms.txt for reading: $!";
  @cap = <RFILE>;
  close(RFILE);

  ## make changes to vars as needed.
  map { s/\n//g; s/room=/ROOM=/g; s/name=/null=/g; s/db=/DB=/g; s/roomdesc=/DESC=/g; s/title=/NAME=/g; s/northwest=/NW=/g; s/northeast=/NE=/g; s/southeast=/SE=/g; s/southwest=/SW=/g; s/north=/N=/g; s/south=/S=/g; s/east=/E=/g; s/west=/W=/g; s/down=/D=/g; s/up=/U=/g; } @cap;
  
  ## make rooms for the new guys
  #$main::map->[0]=new room; 
  $roomstoi{""}=0;# don't use.

  
  ## registers already-numbered rooms.
  #my ($roomid, $i);
  #foreach $capline (@cap) {
  #   $capline = '&'.$capline.'&';
  #   $i = index($capline, '&ROOM=');
  #   if($i != -1) {
  #      $roomid = substr($capline, $i+6, index($capline, '&', $i+6)-$i-6);
  #      if(($roomid <= 0) && ("$roomid" ne '0')) { next; }
  #      $roomid = int $roomid;
  #      if( !defined($roomstoi{"$roomid"}) ) { $roomstoi{$roomid}=$roomid; }
  #      
  #   }
  #}
  
  my %room_referrers; # hash of roomid -> [text from room(s) that refers to that room]
  
  # the regular stuff
  my @roomsdefined;

  my $baseroomnum = 0;

  foreach $capline (@cap) {
     my %rh; # I think this stood for "Room Hash" way back, since it represents a room
	         # as a hash (instead of the flat serialized data). How lame is that :-).
	 
	 # Build hash values
	 map {
         $_ =~ /^(.+?)=(.*)$/ or die "Bad KVPair: $_ for room data $capline";
		 $rh{uc($1)}=$2;
	 } split(/\&/, $capline);
     
	 
     @rnamestomap = ('ROOM', 'N', 'S', 'E', 'W', 'SE', 'NE', 'SW', 'NW', 'D', 'U');
	 #foreach $scrap (@rnamestomap) { if(defined($rh{$scrap}) && ($rh{$scrap}>0)) { print "Rerouting from $rh{$scrap} to t$rh{$scrap}.\n"; $rh{$scrap} = 't'.$rh{$scrap}; } }
	 
     if (defined $rh{'ROOM'}) {
#       print "Rh Room is $rh{'ROOM'} ";

       foreach my $room_token (@rnamestomap) {
         if( (!defined($roomstoi{$rh{$room_token}})) && ("$rh{'ROOM'}" ne "") ){ 
            $baseroomnum++ while $roomsdefined[$baseroomnum];
			
            $roomstoi{$rh{$room_token}}=$baseroomnum;
            $roomsdefined[$baseroomnum]=1;
			$room_referrers{$baseroomnum} .= "r-allrooms' room $rh{'ROOM'} pointing through $room_token of $rh{$room_token}.  ";
            #print "$rh{'ROOM'} leads to $rh{$scrap}. Verified: [$roomstoi{$rh{$scrap}}]\n";
         } # add rnames to lookup table.
       }

       # update roomnos in this room's hash to point to the new numbers
	   map { $rh{$_} = $roomstoi{$rh{$_}} } @rnamestomap;
	   
#       print "  ==>   $rh{'ROOM'}.\n";
	   
       $main::map->[$rh{'ROOM'}]=room->new;
       $main::map->[$rh{'ROOM'}]->{'ROOM'}=$rh{'ROOM'};
       shift(@rnamestomap);
       foreach $key (@rnamestomap) {
         if ( $rh{$key} > 0 ) { 
            $main::map->[$rh{'ROOM'}]->exit_make($key,$rh{$key}); delete($rh{$key}); 
         }
         for(my $n=1; $n<=10; $n++) { 
           if($rh{$key.'-'.$n}) { $main::map->[$rh{'ROOM'}]->{$key}->[$n]=$rh{$key.'-'.$n}; }
         }
       }
       foreach $key (keys(%rh)) {
         # the commented-out stuff was meant for the original rock-conversion to r2.
        # if ( defined( $main::map->[$rh{'ROOM'}]->{$key} ) ) { 
         if (!$main::map_interp_dont{$key}) { 
            #   print "setting $key to $rh{$key}\n";
                $main::map->[$rh{'ROOM'}]->{$key}=$rh{$key};
         }
       }
       if($rh{'STORE'}) {
          if($conv_store_ids{$rh{'STORE'}}) {
            $main::map->[$rh{'ROOM'}]->inv_add(&obj_lookup($conv_store_ids{$rh{'STORE'}}));
            $main::map->[$rh{'ROOM'}]->{'STORE'}=$conv_store_ids{$rh{'STORE'}};
            if($rh{'SNAME'}) { &obj_lookup($conv_store_ids{$rh{'STORE'}})->{'NAME'}=$rh{'SNAME'}; }
            if($rh{'SDB'}) { &obj_lookup($conv_store_ids{$rh{'STORE'}})->{'DB'}=$rh{'SDB'}; }
            if($rh{'SMAXDBINV'}) { &obj_lookup($conv_store_ids{$rh{'STORE'}})->{'MAXDBINV'}=$rh{'SMAXDBINV'}; }
            if($rh{'SMARKUP'}) { &obj_lookup($conv_store_ids{$rh{'STORE'}})->{'MARKUP'}=$rh{'SMARKUP'}; }
            if($rh{'SMARKDOWN'}) { &obj_lookup($conv_store_ids{$rh{'STORE'}})->{'MARKDOWN'}=$rh{'SMARKDOWN'}; }
          } else {
            # create store, add to room.
            confess "The default item for a store doesn't seem to exist. Did items.bse get loaded?"
                unless $main::objbase->[6];
            my $store = &{$main::objbase->[6]};
            $store->{'NAME'}=$rh{'SNAME'} if $rh{'SNAME'};
            $store->{'MARKUP'}=$rh{'SMARKUP'} if $rh{'SMARKUP'};
            $store->{'MARKDOWN'}=$rh{'SMARKDOWN'} if $rh{'SMARKDOWN'};
            $store->{'DB'}=$rh{'SDB'} if $rh{'SDB'};
            $store->{'MAXDBINV'}=$rh{'SMAXDBINV'} if $rh{'SMAXDBINV'};
            $main::map->[$rh{'ROOM'}]->inv_add($store);
            $main::map->[$rh{'ROOM'}]->{'STORE'}=$store->{'OBJID'};
            $conv_store_ids{$rh{'STORE'}}=$store->{'OBJID'};
          }
       }
	   
       if($rh{'PORTAL'}) {
          my $i = item->new('SENT', 1, 'NAME', $rh{'PNAME'},'DESC', $rh{'PDESC'},'PORTAL', $rh{'PORTAL'}, 'NOENTER', $rh{'PNOENTER'}, 'NOEXIT', $rh{'PNOEXIT'});
          $i->{'DLIFT'}=$i->{'CAN_LIFT'}=undef;
          $i->{'INVIS'} = 1 unless $rh{'PINVIS'} eq '0';
          $main::map->[$rh{'ROOM'}]->inv_add($i);
       }
	   
      ## DONE IN DIFF PROCESS LATER ON
      ## if($rh{'ITEMSPAWN'}) {
      ##    $main::map->[$rh{'ROOM'}]->item_spawn(split(/\,/, $rh{'ITEMSPAWN'})); # item_spawn already has all the error-checking built in
      ## }
	  
       if($rh{'RALIAS'}) { 
          $main::roomaliases{lc($rh{'RALIAS'})} = $rh{'ROOM'};
       }
	   
       if($rh{'BLESS'}) { 
          bless($main::map->[$rh{'ROOM'}], $rh{'BLESS'});
       } else {
          # handle terrain-keyed blessing
          $main::map->[$rh{'ROOM'}]->auto_bless();
       }
	   
       if($rh{'BOOTCRYL'} && ($main::map->[$rh{'ROOM'}]->{'CRYL'}<$rh{'BOOTCRYL'})) { 
          $main::map->[$rh{'ROOM'}]->{'CRYL'}=$rh{'BOOTCRYL'};
       }
	   
       if($rh{'MAPNAME'}) { 
          $main::mapname_resolutions{$rh{'M'}}=$rh{'MAPNAME'};
       }
	   
       if($rh{'MONOLITH'}) {
          my ($mlith, $race) = split(/\|/, $rh{'MONOLITH'});
          $mlith = lc($mlith);
          $main::rock_stats{$mlith} = $race;
          $main::map->[$rh{'ROOM'}]->item_spawn($main::monoliths{$mlith});
       }
	   
       # register static id to prevent planar shifting
       $main::map->[$rh{'ROOM'}]->{'STATIC_ID'} ||= &main::staticid_new();
       $main::staticid_to_room{$main::map->[$rh{'ROOM'}]->{'STATIC_ID'}} = $rh{'ROOM'};
       
       $main::map->[$rh{'ROOM'}]->exits_update();
     } else { print "Did not create room for $capline\n"; }
     #print "\n";
  }
  print "Rooms Created.\n";
  for (my $i=0; $i<@$main::map; ++$i) {
      next if $main::map->[$i];
	  print "EVIL MAP $i, referred to through:  $room_referrers{$i}\n\n";
  }
  return;
}

sub staticid_new {
  # generate new (unclaimed) static id for rooms
  my ($n, $pre);
  for (my $i=0; $i<5; $i++) { $pre .= 97 + int rand(26); }
  # linear search for static id
  for($n=1; defined($main::staticid_to_room{$pre.$n}); $n++) { }
  return($pre.$n);
}




sub map_list {
 my ($from, $to) = @_;
 if($from<=0) { $from=0; }
 $from = abs(int $from);
 $to = abs(int $to);
 if( ($to > $#{$main::map}) || !$to ) { $to = $#{$main::map}; }
 # returns list'o'rooms on map
 my ($cap, $n) = ('{40}                      {11}MAP IDs'."\n");
 for ($n=$from; $n<=$to; $n++) {
   #if(!ref($main::map->[$n])) { next; }
   $cap .= sprintf('{17}%5d {16}%-10s {2}( {1}%2d{2} )',$n,substr($main::map->[$n]->{'NAME'},0,10),$main::map->[$n]->inv_objsnum);
   if( (($n+1)/3) == (int (($n+1)/3) ) ) { $cap .= "\n"; }
 }
 if( (($n)/3) != (int (($n)/3) ) ) { $cap .= "\n{41}"; }
 return($cap);
}


sub by_number { $a <=> $b; }

sub by_number_descending { $b <=> $a; }

sub obj_lookup {
  # takes objid and returns object
  return($main::objs->{$_[0]});
}

sub update_uidmap {
   # remember, $main::uidmap->{'lc_uid'} = time stamp.
   # load the dir
   opendir(DIR, 'saved') || die "Cannot open saved-file directory: $!\n"; 
   rewinddir(DIR); my @files = readdir(DIR); closedir(DIR);
   #print "Files: ".scalar(@files)."\n";
   # update uidmap :)
   my ($uid, %validfiles);
   foreach $uid (@files) {
       if ($uid =~ /^(.+?)\.r2$/) {
            $validfiles{lc($1)}=1;
       } else { 
            print "Weird file: $uid\n";
       }
   }
   %main::uidmap = %validfiles;
   #$main::uidmap{'plat'}=1;
   #print "#### UPDATED UIDMAP 1: ".scalar(keys %main::uidmap)." names! #####\n";
   #print "Valid users: ".join(', ', sort keys %main::uidmap).".\n";
   return;
}

sub insure_filename {
  # converts filename if necessary (for MacPerl users), returns it.
  if($^X ne 'MacPerl') { return($_[0]); }
  my $p = $_[0];
  if(index($p, './') == 0) { $p = ':'.substr($p,2); }
  $p =~ s/\//\:/g;
  return($p);
}

sub rem_inactive_users {
 my ($o, $oid, %sobjids, @cap, $last, $cap);
 # make hash of objects that are connected via telnet
 foreach $o (values(%{$main::sockplyrs})) { $sobjids{$o->{'OBJID'}}=1; }
 # make objs inactive which are not connected via telnet and have been inactive
 foreach $oid (keys(%{$main::activeusers})) {
  if ( ( ((time - $main::activeusers->{$oid}) > 200) || !$main::objs->{$oid}->{'IP'}) && (!$sobjids{$oid}) ){ 
      delete ($main::activeusers->{$oid});
   #   print "$main::objs->{$oid}->{'NAME'} was inactive.\n";
      push(@cap, $main::objs->{$oid}->{'NAME'});
      $main::objs->{$oid}->obj_logout;
  }
 }
 $last = pop(@cap);
 if(@cap) { $cap .= join(', ',@cap).' {1}and{6} '; }
 if($last) { &main::rock_shout(undef, '{6}'.$cap.$last.' {1}logged out due to inactivity.'."\n", 1); }
 return;
}


sub events_update {
  my ($key);
  #print "EVENTS_UPDATE hit.\n";
  foreach $key (keys(%main::events)) {
    $main::events{$key}--;
    if(!$main::events{$key}) { 
          if(defined($main::objs->{$key})) { delete $main::events{$key}; if($main::objs->{$key}) { $main::objs->{$key}->on_event; } }
          elsif(ref($main::events{$key}) eq 'CODE') { &{$main::events{$key}}; delete $main::events{$key};  }
    }
  }
  return;
}

  # cleans up the room objects, so that they're more maintainable.
  # Includes:
  #   o erasing tracks
sub main::cleanup_rooms {
  my ($room, $cap);
  foreach $room (@{$main::map}) {
    $room->{'GOR'} = ( (int ($room->{'GOR'}*4/5)) || undef );  # decay gore
    $room->exits_update; # recount exits.
    if ( ( (scalar keys(%{$room->{'INV'}})) >= 10 ) && ($room->{'ROOM'} != $main::roomaliases{'arenahall'})){ $main::garbage_rooms->{$room->{'ROOM'}}=$room; }
    delete $room->{'TRAILTO'};
  }
  return;
}
  #&rock_shout(undef, "{12}A planar wash has occurred!\n");

sub cleanup_objs {
  # cleans up all objects, so that they're more maintainable.
  # Includes:
  #   o getting rid of undef keys
  #   o rewriting the portal lookup table.
  delete $main::objs->{''}; # temp fix for the stupidity of this program
  undef($main::portals);  # clear portals since they'll be updated by the end of this cleanup.
  undef(%main::obj_recd);
  undef(%main::spawn_db_lists);
  print "## Cleanup!\n";
  my ($obj, $cap, $key);
  foreach $obj (values(%{$main::objs})) {
    if(!ref($obj) || (ref($obj) eq 'HASH') ) { print "Error looking up object $obj. ($obj->{'NAME'}, $obj->{'OBJID'}) on cleanup.\n"; next; }
    if(!$obj->{'CONTAINEDBY'} && ($obj->{'TYPE'}>=0) && ("$obj->{'CONTAINEDBY'}" eq "") )     { 
	    print "Object $obj: $obj->{'NAME'} ($obj->{'OBJID'}) w/undef cby: $obj->{'CONTAINEDBY'}\n"; 
	    &rock_shout(undef, "{1}Object $obj: $obj->{'NAME'} ($obj->{'OBJID'}) w/undef cby: $obj->{'CONTAINEDBY'}\n", 1);
	    #$obj->dissolve; 
	    }

    #print "     o $obj: $obj->{'NAME'} ($obj->{'OBJID'})\n";
    
    ## OBJECT REGISTRATION ##
    # register object if it's a portal.
    if ($obj->{'PORTAL'} && ($obj->{'TYPE'} != -1)) {
        push ( @{$main::portals->{$obj->{'PORTAL'}}}, $obj->{'OBJID'} );
    }
    # if it's got a recipe, log it as a generic item.
    if($obj->{'REC'}) { $main::obj_recd{$obj->{'REC'}}++; }
    # register item on spawn lists
    if($obj->{'DB'}) { $main::spawn_db_lists{$obj->{'OBJID'}} = 1; }
    ##                     ##
    
    # get rid of it's GATE information..
    # THIS WAS TURNED OFF CUZ WE AVOID GATING RIGHT NOW
    # delete $obj->{'GATE'};
  }
  
  return;
}

sub badobj_scan {
  my $obj;
  foreach $obj (keys(%{$main::objs})) {
    if(!ref($main::objs->{$obj}) || (ref($main::objs->{$obj}) eq 'HASH') ) { 
      my $o = $main::objs->{$obj};
      &main::rock_shout(undef, "{17}!!!!! {2}Error looking up objectid [$obj] ($o->{'OBJID'}, $o->{'NAME'}, $o->{'ROOM'}).\n", 1);
      print "!!!!! Error looking up objectid [$obj] ($o->{'OBJID'}, $o->{'NAME'}, $o->{'ROOM'}).\n";
      delete $main::objs->{$obj};
    }
  }
  return;
}



sub cleanup_effects {
  my $o;
  foreach $o (keys(%main::effectors)) {
    if ($main::objs->{$o}) { $main::objs->{$o}->effects_update; }
  }
  return;
}

sub compress_descs {
  my ($obj, $n, $tot, $go, %refsused, $bytessaved, $key); # go = "keep going"
  # update objects
  foreach $obj (values(%{$main::objs})) {
    # if it's already a ref, who cares?
    if (ref($obj->{'DESC'})) { $refsused{"$obj->{'DESC'}"}=1; next; }
    if(!$obj->{'DESC'}) { next; }
    $tot = $#{$main::desc}; $go=1;
    for ($n=0; (($n<=$tot) && $go); $n++) {
      # scan to see if that description is already in the db
      if($main::desc->[$n] eq $obj->{'DESC'}) {
  #      print "Object $obj->{'OBJID'} ($obj->{'NAME'}): ref'd description to number $n.\n";
        $obj->{'DESC'} = \$main::desc->[$n]; $go=0; $bytessaved += length($main::desc->[$n]);
        $refsused{"$obj->{'DESC'}"}=1;
      }
    }
    if($go) {
      # create a new desc.
      $tot++;
      for ($n=0; (($n<=$tot) && $go); $n++) {
         if($main::desc->[$n] eq undef) { 
   #        print "Object $obj->{'OBJID'} ($obj->{'NAME'}): created new description, ref'd to number $n.\n";
           $main::desc->[$n]=$obj->{'DESC'};
           # and reference it.
           $obj->{'DESC'} = \$main::desc->[$n];
           $refsused{"$obj->{'DESC'}"}=1;
           $go=0;
         }
      }
    }
  }
  # clean up, undef descriptions that aren't referenced.
  $tot = $#$main::desc;
  for ($n=0; ($n<=$tot); $n++) {  if(!$refsused{\$main::desc->[$n]}) { $bytessaved += length($main::desc->[$n]); $main::desc->[$n]=undef; } }
  # chop off last values of array if they're undef.
  while( ($main::desc->[$#$main::desc] eq undef) && ($#$main::desc > -1) ) { pop(@$main::desc); }
  &main::rock_shout(undef, '{6}Compressed descs: {17}~'.($bytessaved*1).'{6} characters saved due to compression!'."\n", 1);
  return;
}

sub realmvardump {
  open (D, '>DUMPFILE');
  my $fd = select; select(D); &dumpvar('main::'); select($fd); close(D); #'main::','realm'
 return;
}

sub ref_hier (ref, hier) {
 my ($cap, $otype, $key, $spacing, $tab, $n);
 $spacing = 16;
 $tab = (' ' x 16).'{11}-{13}> ' unless (!$_[1]);
 if($main::recurshashes{ref($_[0])} || (($_[1] == 0) && ((%{$_[0]}))) ) {
   foreach $key (sort (keys(%{$_[0]}))) {
     $otype = ref($_[0]->{$key});
     if($otype) { 
       $cap .= 
       $tab . 
       sprintf('{13}%'.$spacing.'s{11}: {1}%-'.$spacing."s\n", substr($key,0,$spacing), substr($otype,0,$spacing)) . 
       &main::ref_hier($_[0]->{$key},$_[1]+1, $_[2]);
     } elsif(($_[2] =~ /h/) && $_[0]->{$key}) {
       $cap .= 
       $tab . 
       sprintf('{12}%'.$spacing.'s{13}: {16}%-'.$spacing."s\n", substr($key,0,50), substr($_[0]->{$key},0,50));
     }
   }
 }
 if(ref($_[0]) eq 'ARRAY') {
   for ($n=0; $n<=$#{$_[0]}; $n++) {
     $otype = ref($key);
     if($otype) { 
       $cap .= 
       $tab . 
       sprintf('{13}[%'.$spacing.'d]{11}: {1}%-'.$spacing."s\n", $n, substr($otype,0,$spacing)) . 
       &main::ref_hier($key,$_[1]+1, $_[2]);
     } elsif( ($_[2] =~ /a/) && $_[0]->[$key]) {
       $cap .= 
       $tab . 
       sprintf('{12}%'.$spacing.'s{13}: {16}%-'.$spacing."s\n", $n, substr($_[0]->[$key],0,$spacing));
     }
   }
 }
 return($cap);
}

sub kill_color_codes {
  my $cap = shift;
  $cap =~ s/\{.*?\}//g;
  return $cap;
}

sub email_is_valid {
 my $email = lc(shift);
 $email =~ tr/a-z0-9_\.\@\:\-//cds;
 if(!($email =~ /(.+)\@(.+)\.(.+)/)) { return(0, "$email is not a valid email address."); }
 my ($user, $host, $dom) = ($1, $2, $3);
 if($main::email_addrs{lc($email)}>0) { return(0, "Someone already has a character at the address: $email."); }
 #if(($host.$dom) =~ /hotmail/) { return (0, "We cannot accept hotmail accounts as valid email addresses, sorry."); }
 return(1, $email);
}

sub uid_is_valid {
   my $uid = lc(shift);
   $uid =~ tr/a-z0-9//cds; $uid = uc(substr($uid,0,1)).substr($uid,1);

   if ($main::uidmap->{lc($uid)}) { return(0, "That name is already in use."); }
   elsif (length($uid) < 4){ return(0, "Your name is too short."); }
   elsif (length($uid) > 16){ return(0, "Your name is too long."); }
   elsif ($uid =~ /^\d+/){ return(0, "Your name cannot begin with a number."); }
   elsif ($uid =~ /69|pussy|piss|pansy|cum|crap|fuk|fuck|bitch|vagina|penis|boob|cock|dildo|shit|nigger|faggot|fagget|whore|cunt|masturbate|masturbat/i) {
       return (0, "Name contains potentially vulgar language.");
   }
   return(1, $uid);
}

sub rocklib_file (filename) {
  my $file = shift;
  my $cap;
  open (F, &main::insure_filename('./rocklib/'.$file)) || die "Can't open test file: $!\n";
  while(!eof(F)) { $cap .= <F>; }
  close(F);
  return($cap);
}


sub character_file_load {
  # NOTE!!!!! THIS RETURNS A *POINTER* TO THE SCALAR, NOT THE FILE ITSELF
  my $uid = shift;
  #print "Was asked to load character $uid.\n";
  my $charinfo;
  open(F, &insure_filename('./saved/'.lc($uid).'.r2')) || return;
  while (!eof(F)) { $charinfo .= <F>; } close(F);
  return(\$charinfo);
}


sub rm_whitespace {
  #my @a = @_;
  #grep { s/^\s+//; s/\s+$//; } @a;
  $a = shift;
  for ($a) { s/^\s+//; s/\s+$//; }
  return($a);
}

sub msgid_new {
  # creates unique msg code and returns it
  return($main::msgids++);
}

sub val_pct (value, percent success) {
 # returns value if success.
 if(rand(100)<$_[1]) { return($_[0]); }
 else { return(0); }
}

sub scan_crappy_objects {
  my ($obj, $onum);
  foreach $onum (keys %{$main::objs}) {
     my $ref = ref $main::objs->{$onum};
     if(!$ref || $ref eq uc($ref)) {
    #if(!$main::objs->{$onum}->{'NAME'}) { 
       $obj = $main::objs->{$onum};
       print "Object key $onum ($main::objs->{$onum}) is faulty!\n";
       print &main::ref_hier($obj,0,'h');
    }
  }
 #$main::donow .= '&{$main::adminbase_sing->{\'restart\'}};';
  return;
}

sub dice(rolls, sides) {
 my $t;
 for (my $n=1; $n<=$_[0]; $n++) { $t += int rand($_[1]) + 1; }
 return($t);
}

sub main::pw_generate {
  my $code;
  $code = $main::WordCombos[(1+int rand($#main::WordCombos))];
  $code =~ s/1/$main::BeginCons[1+int rand($#main::BeginCons)]/ge;
  $code =~ s/2/$main::MidVow[1+int rand($#main::MidVow)]/ge;
  $code =~ s/3/$main::EndCons[1+int rand($#main::EndCons)]/ge;
  $code =~ s/4/$main::MidCons[1+int rand($#main::MidCons)]/ge;
  $code =~ s/5/$main::SylEnding[1+int rand($#main::SylEnding)]/ge;
  $code =~ s/6/$main::FullSyllab[1+int rand($#main::FullSyllab)]/ge;
  $code =~ s/9/$main::SillySuffix[1+int rand($#main::SillySuffix)]/ge;
  return($code);
}
