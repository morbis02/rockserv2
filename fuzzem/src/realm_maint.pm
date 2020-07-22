package main;
use DB_File;
use strict;
use const_stats;
use rockdb;
use Carp;
use rock_prefs;

sub get_players_logged_in {
    # Returns array of all players who are logged in right
    # now.
    return &rock::player_objs();
}

sub log_event {
    # Log an event into 
    my ($type, $desc, $uin_by, $arga, $argb, $argc) = @_;
    die "no type passed" unless $type;
    die "no desc passed" unless $desc;
    confess "no uin_by passed" unless $uin_by;
    for ($arga, $argb, $argc) {
        die "Arg val '$_' must either be undefined or integer."
           unless !defined($_) || ($_ eq int($_));
    }
    
    my $dbh = rockdb::db_get_conn();
    # &main::rock_shout(undef, "localhost log event.\n", 1); 
    $dbh->do(<<END_SQL, undef, $type, $desc, $uin_by, $arga, $argb, $argc);
INSERT INTO $main::db_name\.r2_event_log
(entry_type, entry_desc, uin_by, arg_a, arg_b, arg_c, entry_date)
VALUES
(?, ?, ?, ?, ?, ?, sysdate())
END_SQL
    
}


#use Lingua::Ispell qw( spellcheck );
#Lingua::Ispell::allow_compounds(1);
#Lingua::Ispell::use_personal_dictionary("/opt/rs2/src/dict/rock_dictionary.dat");
#sub get_spellcheck_str {
#    my $text = shift;#
#	$text =~ s/\n/ /g;
#	$text =~ s/\s+/ /g;
#	$text =~ s/'s\b//g;
#	my $error_str = '';
#	
#	foreach my $r (spellcheck($text)) {
#		 if ( $r->{'type'} eq 'ok' ) {
 #   		 # as in the case of 'hello'
  #  		 $error_str .= "    {17}$r->{'term'} {7}was found in the dictionary.\n";
#		 } elsif ( $r->{'type'} eq 'root' ) {
    		 ## as in the case of 'hacking'
#    		 $error_str .= "    {17}$r->{'term'} {7}can be formed from root '$r->{'root'}'\n";
#		 } elsif ( $r->{'type'} eq 'miss' ) {
#    		 # as in the case of 'perl'
#    		 $error_str .= "    {17}$r->{'term'} {7}was not found in the dictionary;\n";
#    		 $error_str .= "        {6}Near misses: @{$r->{'misses'}}\n";
#		 } elsif ( $r->{'type'} eq 'guess' ) {
#    		 # as in the case of 'salmoning'
#    		 $error_str .= "    {17}$r->{'term'} {7}was not found in the dictionary;\n";
#    		 $error_str .= "        {6}Root/affix Guesses: @{$r->{'guesses'}}\n";
#		 } elsif ( $r->{'type'} eq 'compound' ) {
#    		 # as in the case of 'fruithammer'
#    		 $error_str .= "    {17}$r->{'term'} {7}is a valid compound word.\n";
#		 } elsif ( $r->{'type'} eq 'none' ) {
#    		 # as in the case of 'shrdlu'
#    		 $error_str .= "    {7}No match for term {17}$r->{'term'}\n";
#		 } #else {
##    	     print "$r->{'type'}: " . join(', ', values(%$r))."\n";
##		 }
#		 # and numbers are skipped entirely, as in the case of 42.
#	}
	
#	return $error_str; # empty string if no errors
#}

sub commify_join_with_and {
    # returns commified list of whatever strings we are passed.
    # the only magic here is that the word "and" is placed between the
    # second-to-last and last entries.
    my @arr = @_;
    my $last = pop @arr;
    if (@arr) {
        return join(', ', @arr)." and ".$last;
    } else {
        return $last;
    }
}

sub get_an_str {
    my $str = shift;
    return "an" if $str =~ /^[aeiouAEIOU]/;
    return "a";
}


# evalll &main::get_item_name_by_rec(0);
sub get_item_name_by_rec {
    # GIven an item's $item_rec, returns one possible name
    # for that object. If the item has multiple possible names,
    # only ONE is chosen. Pisser, eh?
    my $item_rec = shift;
    my ($name) = sql_select_mult_row_linear_local("SELECT item_name FROM $main::db_name\.r2_item_names_by_rec WHERE item_id = ?", abs int $item_rec);
    return $name;
}

sub spawn_stuff {
    foreach my $room (keys(%main::spawn_db_lists)) {
        # randomly spawn item in the room
        # maybe have a DBRAND percent chance, too.
        $room = $main::objs->{$room};
        next if (!$room);
        if( (rand(100) > 50) && ($room->inv_free > 3) && $room->{'DB'}) { 
            #mich - i think this may help npc problem
#			&rock_shout(undef, join(', ', map { $_->{'NAME'} } $room->inv_snobjs)."\n", 1) if $room->{'TYPE'}==-1;
            if($room->{'TYPE'} == -1 && $room->inv_spobjs > 3)
            {
                next;
            }
            #endmich
            my $spawnee = $room->db_spawn();
            if(!$spawnee || $spawnee->is_invis()) { next; }
            elsif($room->{'TYPE'} == -1) { 
              if($spawnee->{'TYPE'}==0) { $spawnee->room_sighttell("{17}$spawnee->{'NAME'} {7}materializes into the room.\n"); }
              else { $room->room_sighttell("{17}$spawnee->{'NAME'} {7}makes $spawnee->{'PPOS'} way into the room.\n"); }
            } else {
              $room->log_append("{17}$spawnee->{'NAME'} {7}appears in your inventory.\n");
            }
        }
    }
    return;
}


sub check_new_turns {
   if (&main::day_get($main::rock_stats{'newturns'} || 10) ne &main::day_get(0)) {
       $main::rock_stats{'newturns'} = time;
       $main::rock_stats{'pvprestrict'} = $main::pvp_restrict = int rand 15;
       &main::rock_shout(undef, "{1}### Caution: PvP level range has been altered.\n### You may now pvp anyone within $main::pvp_restrict levels of you.\n");
   }
   $main::eventman->enqueue(90, \&main::check_new_turns);
}

sub obj_list {
    my ($cap, $key, $obj, $time, $searchstr);
    $searchstr = lc($_[0]);
    $cap = sprintf("{40}{3}%5s %4s %6s %2s%-30s %4s\n", 'OBJID', 'ROOM', 'NUMBER' ,undef, 'OBJ. NAME', 'TYPE');
    $time = time; # only call it once
    foreach $key (sort by_number (keys(%{$main::objs}))) {
        $obj = $main::objs->{$key};
        if (index(lc($obj->{'NAME'}),$searchstr) != -1) { 
            $cap .= sprintf("{6}%5d %4d %6d %2s{2}%-30s {3}%4s\n", $key, $obj->{'ROOM'}, $obj->{'REC'},$main::activemap{defined($main::activeusers->{$obj->{'OBJID'}})}, substr($obj->{'NAME'}, 0, 30), $main::typemap{$obj->{'TYPE'}});
        }
    }
    $cap .= "{7}|KEY|: {1}*{7} = active object.\n{41}";
    return ($cap);
}


sub rock_shout (cap, adminonly) {
    # sends message to each player other than object passed to it.
    my ($self, $cap, $adminonly) = @_;
    my ($player, $pobj);
    foreach $player (keys(%{$main::activeusers})) { 
        $pobj = &main::obj_lookup($player);
        if ( ($player != $self->{'OBJID'}) && !$pobj->{ST8} && ($pobj->{'ADMIN'} || !$adminonly) ) { $main::objs->{$player}->log_append($cap); } 
    }
    return;
}

sub rock_talkshout {
 # exactly the same as rock_shout only it checks for deafness, and doesnt do adminonly
 my ($self, $cap, $ignore_code) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( 
       ($ignore_code?!$pobj->pref_get($ignore_code):1) &&
         ($player != $self->{'OBJID'}) &&
         !$pobj->{'ST8'} &&
         !defined($pobj->{'FX'}->{'25'}) &&
         (!$self || !defined($pobj->{'IGNORE'}->{$self->{'NAME'}}))
         
       ) { $main::objs->{$player}->log_append($cap); } 
 }
 return;
}

sub rock_bshout (cap) {
 # sends message to each player other than object passed to it.
 # BLOOD shout..attacking messages
 my ($self, $cap, $adminonly) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( ($player ne $self->{'OBJID'}) && !$pobj->{'ST8'} && $pobj->{'GAME'} ) { $pobj->log_append($cap); } 
 }
 return;
}

sub rock_rshout (cap) {
 # sends message to each player other than object passed to it.
 # RACIAL shout..
 my ($self, $cap, $ignore_code) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( 
       ($ignore_code?!$pobj->pref_get($ignore_code):1) &&
       ($player ne $self->{'OBJID'}) && 
       !$pobj->{ST8} &&
        ($pobj->{'RACE'} == $self->{'RACE'} || $pobj->{'ADMIN'}) &&
         !defined($pobj->{'FX'}->{'25'}) &&
          (!$self || !defined($pobj->{'IGNORE'}->{$self->{'NAME'}})) 
      ) { 
	  
	      $pobj->log_append(ref($cap) eq "censored_message" ? $cap->get_for($pobj) : $cap); 
	  
	  
	  } 
 }
 return;
}

sub rock_hrshout (cap) {
 # WARNING: hrshout means hardcopy!
 # sends message to each player of race $n
 # RACIAL shout..
 my ($n, $cap) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( !$pobj->{ST8} && ($pobj->{'RACE'}==$n) ) { $pobj->log_append($cap); } 
 }
 return;
}

sub rock_hbcastshout (cap) {
 # WARNING: hbcastshout means hardcopy!
 # sends message to each player of broadcast $n
 my ($n, $name, $cap, $uncensored_cap) = @_;
 my ($player, $pobj);
 foreach $player (keys(%{$main::activeusers})) { 
    $pobj = &main::obj_lookup($player);
    if ( !$pobj->{ST8} && 
	      ($pobj->{'BCASTCH'}==$n || ($n <= 10 && $pobj->{'ADMIN'})) &&
		  !defined($pobj->{'IGNORE'}->{$name})
	   ) {
           $pobj->log_append("{13}<$n>") if $pobj->{'ADMIN'};
	      $pobj->log_append(ref($cap) eq "censored_message" ? $cap->get_for($pobj) : $cap); 
	   }
 }
 return;
}

# deprecated
sub web_pws_register {
  return;
}

sub pw_register (username, pw, pwfile) {
  my ($username, $pw, $file) = @_;
  $username = lc($username); $pw = lc($pw);
  my (@a, $success, $n, $line);
  open (F, "$main::base_code_dir/pws-web/$file") || warn "Error opening pw file $file: $!\n";
  @a = <F>;
  close(F);
  for ($n=0; (($n<=$#a) && !$success); $n++) {
    if( index($a[$n], "$username:") == 0 ) { $success=1; } 
  }
  $n-=$success;
  #print "Username is [$username]\n";
  # now we update item n of the array..
  $a[$n]=$username.':'.crypt($pw,substr($pw,0,1).time.substr($pw,1,2))."\n";
  # and then save it back
  open (F, ">$main::base_code_dir/pws-web/$file") || warn "Error opening pw file $file: $!\n";
  foreach $line (@a) { print F $line; }
  close(F);
  return;
}

sub pfiles_deleteold {
   opendir(DIR, 'saved') || die "Cannot open saved-file directory: $!\n";
   my @files = readdir(DIR); rewinddir(DIR); closedir(DIR);
   my ($uid, @user_objs, @cap);
   my $time = time;
   my $fname;
   foreach $uid (@files) {
     if ($uid =~ /(.+?)\.r2/) {
        $fname = "$main::base_code_dir/saved/".lc($uid);
         if( (!(-e $fname)) || ((-M $fname)<30) ) { next; } # dont bother if file doesn't exist or hasnt been modified in at least 14 days
         my @c = &character_load(lc($1));
         if ($c[0]->{'CODE'} && (($time - $c[0]->{'LASTSEEN'}) < 604800) ) { unlink($fname); } # (cuz we dont want fists, now, do we? :-)) (we dont want blank ones either)
     }
   }
   return;
}


sub racemult_gen {
  my ($x, $s, $rnum);
  $rnum = -1;
  foreach $s (@main::racestats) {
   $rnum++;
   next if (!$s);
   #print "S is $s.\n";
    # figure out max, min.
    my ($max, $min, $diff);
    for ($x=6; $x<=22; $x++) {
     if(!$max || ($s->[$x] > $max)) { $max = $s->[$x]; }
     if(!$min || ($s->[$x] < $min)) { $min = $s->[$x]; }
    }
    $diff = $max - $min;
    #print "Max is $max. Min is $min. Diff is $diff.\n";
    # for(my $i=1; $i<=5; $i++) { my $sum; for (my $x=6; $x<=22; $x++) { $sum += $main::race_mult[$i]->[$x]; } $_[0]->log_append("{1}$main::races[$i]\: {5}$sum\n"); }
    
    for ($x=6; $x<=22; $x++) {
     $main::race_mult[$rnum]->[$x] =  (($s->[$x]-$min)/$diff*.7) + .35;
     #print "Set $s->[0]'s stat $x to $main::race_mult[0]->[$x].\n";
    }
  }
  return;
}

sub web_character_make {
  return; # DONT LET THEM DO IT
}

sub web_character_verify {
  my ($input) = shift;
  my ($result) = &main::verify_subj('[RV] ['.$input->{'uid'}.'|'.$input->{'code'}.']', undef, 1);
  if($result == 1) { 
    return("<HTML><HEAD><TITLE>Character Verification: Success</TITLE></HEAD><BODY BGCOLOR=#CCCCFF><FONT SIZE=+3 FACE=\"Comic Sans MS,Comic Sans\" COLOR=GREEN>Awesome! You're Verified!</FONT><BR><BR><FONT SIZE=+1 FACE=\"Comic Sans MS,Comic Sans\" COLOR=BLACK>You're verified! Voila!<BR>All set to play the game now?<BR>Just head over to the <A HREF=$main::base_web_url/enter.shtml>entry</A> page and log in! (That's how you'll enter the game from now on)<BR><BR>Thanks!<BR><BR>- R2 People<BR></BODY></HTML>");
  } elsif ($result == -1) { 
    return("<HTML><HEAD><TITLE>Character Verification: What?!</TITLE></HEAD><BODY BGCOLOR=#CCCCFF><FONT SIZE=+3 FACE=\"Comic Sans MS,Comic Sans\" COLOR=BLACK>You're already verified!</FONT><BR><BR><FONT SIZE=+1 FACE=\"Comic Sans MS,Comic Sans\" COLOR=BLACK>Give it a break, kid, you're verified! Seriously! You are! You can play the game and all that fun stuff already. Just head over to the <A HREF=$main::base_web_url/enter.shtml>entry</A> page!</BODY></HTML>");
  } elsif ($result == -2) { 
    return("<HTML><HEAD><TITLE>Character Verification: Failure</TITLE></HEAD><BODY BGCOLOR=#CCCCFF><FONT SIZE=+3 FACE=\"Comic Sans MS,Comic Sans\" COLOR=RED>Invalid User ID</FONT><BR><BR><FONT SIZE=+1 FACE=\"Comic Sans MS,Comic Sans\" COLOR=#330000>Please hit \"back\", make sure your information is correct, and try submitting again!</FONT><BR><BR></BODY></HTML>");
  } elsif ($result == -3) { 
    return("<HTML><HEAD><TITLE>Character Verification: Failure</TITLE></HEAD><BODY BGCOLOR=#CCCCFF><FONT SIZE=+3 FACE=\"Comic Sans MS,Comic Sans\" COLOR=RED>Invalid Verification Code</FONT><BR><BR><FONT SIZE=+1 FACE=\"Comic Sans MS,Comic Sans\" COLOR=#330000>Please hit \"back\", make sure your information is correct, and try submitting again!</FONT><BR><BR></BODY></HTML>");
  }
}



sub other_text_filter {
  my ($cap, $player) = @_;
  if($player && $player->{'ADMIN'}) { return($cap); } # dont filter admins
  if(defined($player->{'FX'}->{29})) { $cap = $player->str_insane(); }
  if(uc($cap) eq $cap) { $cap = lc($cap); }

  
  my ($finalcap, $soundex);
  foreach my $word (split(/ /, $cap)) {
    if(defined($main::badword{$soundex = &main::soundex($word)})) {
       $finalcap .= $main::badword{$soundex}.' ';
    } else {
       $finalcap .= $word.' ';
    }
  }
 
  if(!$player->{'ADMIN'}) {
    $cap =~ s/\{/\{30\}/g;
    $cap =~ s/\}/\{31\}/g;
  }

  return(substr($finalcap, 0, length($finalcap)-1));
}

#mich
#this is a helper function for text_filter
sub text_drunk {
    my ($cap, $drunklevel) = @_;
    $cap =~ s{([a-z])}{
        my $replacements = $main::DRUNK_LETTER_LOOKUP{lc $1};
        my $replacestring = lc $1;
        if($drunklevel > $replacements->[0]) {
            $replacestring = $replacements->[int rand(@$replacements - 1) + 1]
        }
        $replacestring
    }xgei;

    $cap =~ s{[0-9]}{
        int rand(9)
    }xgei;
    return $cap;
}


sub text_filter_censor {
    my ($cap, $player) = @_;
    # NOTE: $player is not always passed!!
#    if($player && $player->{'ADMIN'} && !$player->{'CENSOR'}) { return($cap); } # dont filter admins

  eval {  
#    $cap =~ s/\b(h[8a@]t[3e]|suck|bite|h8)/love/gi;
    $cap =~ s/[\$s]+\W*?[l1]+\W*?u+h?\W*?[t7]+|(f|p\W*?h)+?\W*?[vuw]+\W*?(c|k|[\|\]\[][<{]){2,}\W*?([e3]*?\W*?r+?)?|b[1i7]t[c\(](h|\|-\||\]-\[)|v[\@a]g[1i]n[\@a]|p[e3]n[1i]s|boob|cock|d[1il]+do|sh[1!i][7t]|n[1!li]g+er|\bfag+([eoi0]?t?s?)?|wh[o0]r[3e]|cunt|masturbate?/randWord()/ige;
    $cap =~ s/\bass(hol)?(es?)?\b|\bgod\s*dam[^ ]*\b|\bfuk\b|\brap(e|ing)\b|\bho\s*bag\b|\b(pussy|p[i1]+[s\$]+([i1]ng)?\b|h[0o]m[0o]s?|pansy|cum\b|fag|rap(e|[1i]ng))\b|a[\$s]+hole|b[1l][o0]wj[o0]b|\bg[a@]y\b|\bfuq\b|\bgh[ae]y\b|\bst[fh]u\b|\bfu?kin\b|\bnigg(?:ah?|er)s?\b|\bfuq(?:ing?)?\b/randWord()/gie;
  } if $main::swear_filter;

    return $cap;
}

sub text_filter_game {
    my ($cap, $player) = @_;
  if($player && defined($player->{'FX'}->{29})) { $cap = $player->str_insane(); }
  if(uc($cap) eq $cap) { $cap = lc($cap); }

  $cap = substr($cap,0, 270) if $player && $player->{'TYPE'} == 1; # players truncated

#  $cap = ucfirst $cap;
  $cap =~ s/!+/!/g;
  $cap =~ s/\?+/\?/g;

  if ($player->{'STUPID'}) {
     # STupid people are ALWAYS censored
     $cap = &text_filter_censor($cap, $player);
     
     #  $cap =~ s/[aeiou]+//gi if $player->{'STUPID'};
     # $cap =~ s/[^bcdfghjklmnpqrstvwxyz<>() '.?_*$#!,;:-]+//gi;
	 
	 $cap = join ' ', sort { lc($a) cmp lc($b) } split(/\s+/, $cap);
     
     for (my $i=0; $i<length($cap)/7; $i++) {
         my $lindex = int rand length($cap);
         my $let = substr($cap, $lindex, 1);
         next unless $let =~ /^[a-zA-Z0-9]$/;
         $let = uc $let if rand(10) < 3;
         if (rand(10) < 7 && $lindex != 0 && $lindex != length($cap)-1) {
             # Transpose
             if (rand(10) < 5 && substr($cap, $lindex-1, 1) ne ' ') {
                # &main::rock_shout(undef, "blah!!\n", 1);
                 ( substr($cap, $lindex - 1, 1), substr($cap, $lindex, 1) ) =
                     ( $let, substr($cap, $lindex - 1, 1) );
             } elsif (substr($cap, $lindex+1, 1) ne ' ') { 
                 ( substr($cap, $lindex + 1, 1), substr($cap, $lindex, 1) ) =
                     ( $let, substr($cap, $lindex + 1, 1) );
             }
         } else {
             # Sticky Key
             substr($cap, $lindex, 1) = $let x 2;
         }
     }
#	 $cap = join ' ', sort { int(rand(3)) - 1 } split(/\s+/, $cap);
  }
  if($player->{'DRUNK_LEV'}) { $cap = &main::text_drunk($cap, $player->{'DRUNK_LEV'}); }

  # [\@a]\W*r\W*[3e]\W*n\W*[\@a]

  my %brackHash = ('{' => '{30}', '}' => '{31}');
  $cap =~ s/\{|\}/$brackHash{$&}/g;
  
#  $cap .= "." if $cap !~ /[!.?,]$/;
#  &main::rock_shout(undef, sprintf("{4}| %15s | {7}%s\n", $player->{'NAME'}, $cap), 1);
  return $cap;
}

sub text_filter {
  my ($cap, $player) = @_;
  $cap = &text_filter_censor($cap, $player); # censor it.
  $cap = &text_filter_game($cap, $player);
  return $cap;
}

#@main::randSwearWord = qw(wanton ascetic coquette circe virago futilitarian egoist esthete demagoguemartinet sycophant philatelist numismatist);
@main::randSwearWord = qw(cloud bubbles paperback cool neat spiffy awesome rockin' super-neato fuzzem dillfrog plane taco jojo kumquat polo horsefeathers beef pizza broccoli shirt shoe corn);
push(@main::randSwearWord, 'fluffy pillow', 'double-decker chocolate fudge');
#@main::randSwearWord = qw(French American USA freedom Bush Blair Iraq Saddam);
sub randWord() {
  $main::randSwearWord[int rand scalar @main::randSwearWord];
}

sub is_banned(ip) {
 my $ip = shift;
 my $i;
 foreach $i (@main::banlist) {
  if (index($ip, $i) == 0) { return(1); }
 }
 return(0);
}

sub index_count (string, searchstr) {
 my ($cap, $sub) = @_;
 my ($n, $l, $c) = (-1, length($cap), 0);
 
 $n = index($cap, $sub, $n+1);
 $c++;
 while ( ( $n<$l ) && ($n!=-1) ) {
   $n = index($cap, $sub, $n+1);
   $c++
 }
 $c--;
 return($c);
}


sub object_report_generate {
 my ($o, $maxitem, @req_flags, @opt_flags, $i, $susp, @attk_flags, @unq_flags);
 @req_flags = sort ('NAME', 'DESC', 'VAL', 'VOL', 'MASS');
 @attk_flags = sort ('FPAHD', 'FPSHD', 'TPAHD', 'TPSHD', 'WC', 'AC');
 @opt_flags = sort ('PORTAL', 'CONTAINER', 'CRYL', 'KJ', 'FLAM', 'AFIRE', 'LIMIT', 'ATYPE', 'DIGEST', 'ENCHANTED', 'INVIS', 'HIDDEN', 'ROT', 'EATFX');
 @unq_flags = sort ('AWARDPCT', 'DELAY', 'COSTPERPLAY', 'XPLODETIME', 'XPLODEPCT', 'RACEFRIENDLY', 'TRIGDELAYREPLY', 'TRIGDELAY', 'TRIGEXITCNT', 'TRIGKEY', 'TRIGIMMEDREPLY', 'TRIGEXIT');
 open(REP, '>objectreport.html') || return("Could not open Object Report file.\n");
 # header
 print REP '<HTML><HEAD><TITLE>R2: Object Report - '.&main::time_get(0,1).'</TITLE></HEAD><BODY BGCOLOR=WHITE>';
 print REP "\n\n<H2>Object Report - ".&main::time_get(0,1)."</H2>\n\n<FONT COLOR=BLACK>Key: standard | <FONT COLOR=BLUE>optional</FONT> | <FONT COLOR=#990000>optional combat-related</FONT> | <FONT COLOR=PURPLE>optional item-unique flags</FONT></FONT><BR>\n\n<TABLE BGCOLOR=BLACK CELLPADDING=2 BORDER=0 WIDTH=98%><TR VALIGN=MIDDLE ALIGN=CENTER><TD>";
 print REP "<TABLE BGCOLOR=#FFFFCC CELLPADDING=3 CELLSPACING=3 BORDER=0 WIDTH=98%>\n";
 $maxitem = (scalar @{$main::objbase}) - 1;
 for(my $n=0; $n<=1298; $n++) {
   $o = &{$main::objbase->[$n]};
   $susp='';
   print REP ' <TR><TD>';
   print REP '<FONT COLOR=BLACK>';
   print REP '<B>Item Number</B>: ('.$n.') <B>Type</B>: ('.ref($o).')<BR>';
   foreach $i (@req_flags) {
     print REP "<B>$i</B>: ";
     if($o->{$i}) { print REP $o->{$i}.'<BR>'; }
     else { print REP '<I>unlisted</I><BR>'; $susp .= "Flag <B>$i</B> left blank.<BR>"; }
   }
   print REP '</FONT><FONT COLOR=BLUE>';
   foreach $i (@opt_flags) {
     if($o->{$i}) { print REP "<B>$i</B>: ".$o->{$i}.'<BR>'; }
   }
   print REP '</FONT><FONT COLOR=#990000>';
   foreach $i (@attk_flags) {
     if($o->{$i}) { print REP "<B>$i</B>: ".$o->{$i}.'<BR>'; }
   }
   print REP '</FONT><FONT COLOR=PURPLE>';
   foreach $i (@unq_flags) {
     if($o->{$i}) { print REP "<B>$i</B>: ".$o->{$i}.'<BR>'; }
   }
   print REP '</FONT>';
   if($susp) { print REP "<FONT COLOR=BROWN>Some flags were missed, that may be critical to the game. Suspicious settings are noted below:<BR><FONT COLOR=BLACK><BLOCKQUOTE>$susp</BLOCKQUOTE></FONT></FONT><BR>"; }
   print REP " </TD></TR>\n";
   $o->obj_dissolve;
 }
 print REP "\n</TABLE></TD></TR></TABLE>";
 close(REP);
 $main::map->[1]->cleanup_inactive;
 return("Object Report file Created.\n");
}

sub oBriefTitle {
   my $n = shift;
   if( (($n/20) == int($n/20)) ) { 
      return sprintf("\n%8s %20s %4s %4s %5s\n", '| cre8 |', '| name |', '|wc|', '|ac|', '|val|');
   }
   return undef;
}
sub object_briefing {
 my ($o, $cap, $maxitem);
 $cap .= "o o o -=- R2 Object Report: ".&main::time_get(0,1)."\n\n";
 
 #$cap .= sprintf("%8s %20s %4s %4s %5s\n", '| cre8 |', '| name |', '|wc|', '|ac|', '|val|');
 my (@npcs, @armour, @weapons, @etc);
 $maxitem = (scalar @{$main::objbase}) - 1;
 #$maxitem = 769 - 1;
 for(my $n=0; $n<=$maxitem; $n++) {
   next if !defined($main::objbase->[$n]);
   $o = &{$main::objbase->[$n]};
   my $booststr;
   
   if($o->{'TYPE'}==0) {
     $o->stats_update();
     for(my $n=6; $n<=22; $n++) { 
         if($o->{'STAT'}->[$n]) { $booststr .= "$main::rparr{$n}\($o->{'STAT'}->[$n]) "; }
     }
     #if($booststr) { $booststr = "*Worn*: $o->{'ATYPE'}, $booststr"; }
     if($o->{'ATYPE'}) { $booststr = "*Worn*: $o->{'ATYPE'} $o->{'LEV'}, $booststr"; }
     
     if(defined($o->{'WSTAT'})) { 
         $booststr .= '*Wielded*: ';
         for (my $n=0; $n<=$#{$o->{'WSTAT'}}; $n+=2) { $booststr .= "$main::rparr{$o->{'WSTAT'}->[$n]}\($o->{'WSTAT'}->[$n+1]) "; }
     }
     if(defined($o->{'ATYPE'})) { 
         #$booststr .= '*Worn*: ';
         for (my $n=0; $n<=$#{$o->{'WSTAT'}}; $n+=2) { 
	         $booststr .= "$main::rparr{$o->{'STAT'}->[$n]}\($o->{'STAT'}->[$n+1]) "; 
	         }
     }
    
     
   }
    if($o->{'TYPE'}==2) { 
         $booststr .= "*LEVEL*: $o->{'LEV'}";
         #for (my $n=0; $n<=$#{$o->{'WSTAT'}}; $n+=2) { $booststr .= "$main::rparr{$o->{'STAT'}->[$n]}\($o->{'STAT'}->[$n+1]) "; }
     }
   #if($o->{'BASEH'}) { $booststr .= "*BASEH*: $o->{'BASEH'} "; }
   my $itemcap = sprintf("( %4d ), %20s, %4d, %4d, %5d, %s\n", $n, substr($o->{'NAME'},0,20), $o->{'WC'}, $o->{'AC'}, $o->{'VAL'}, $booststr);
   
   if($o->{'TYPE'} == 2) { push(@npcs, &oBriefTitle(scalar @npcs).$itemcap); }
   elsif($o->{'ATYPE'}) { push(@armour, &oBriefTitle(scalar @armour).$itemcap); }
   elsif($o->{'WC'} && ($o->{'WC'}> 5) || ($o->{'WC'}<1)  ) { push(@weapons, &oBriefTitle(scalar @weapons).$itemcap); }
   else { push(@etc, &oBriefTitle(scalar @etc).$itemcap); }
   
   $main::recnum_toname{$n}=$o->{'NAME'};
   $o->obj_dissolve;
 }
 $cap .= "#*#          ARMOUR:\n".join('', @armour)
        ."\n\n#*#         WEAPONS:\n".join('', @weapons)
        ."\n\n#*#            NPCS:\n".join('', @npcs)
        ."\n\n#*#            MISC:\n".join('', @etc);
        
 $cap .= "\n(c) 1998 Delta Engineering.\nDo not copy this document or send to others without express permission.\nInformation in this document is to be considered extremely confidential.\n";

 open(REP, ">$main::base_web_dir/admin/object_brief.txt") || return("Could not open Object Report file.\n");
 print REP $cap;
 close(REP);

 $main::map->[1]->cleanup_inactive;
 return("Object Report file Created.\n");
}

#sub uidsRegister {
#   open(regFile, '>./pws-web/.htgroup');
#   print regFile 'rock-players:'.join(' ', keys(%{$main::uidmap}))."\n";
#   close(regFile);
#}

sub get_socket {
  my ($sockno, $sock) = (shift);
  for $sock ($main::sock_sel->handles) {
      next if ($sock==$main::listen);
      if($sock->fileno == $sockno) { return($sock); }
  }
  return(undef);
}

# my $objid = 179499; my $sock = &main::get_objid_socket($objid); if($sock) { &main::rock_destp($sock->fileno); }
sub get_objid_socket {
  my ($objid, $sock, $sockno) = (shift);
  for $sock ($main::sock_sel->handles) {
      next if ($sock==$main::listen);
      if(defined($main::sockplyrs->{$sock->fileno}) && ($main::sockplyrs->{$sock->fileno}->{'OBJID'} == $objid)) { return($sock); }
  }
  return(undef);
}

sub enviro_idle {
  # Get next event in 45-60 seconds.
  $main::eventman->enqueue(45+int rand(16), \&main::enviro_idle);
  #print "Enviro-Idle: \n";
  my %rooms_to_enviro;
  foreach my $player (values %$main::activeuids ) {
     # print "    Uid Vals: ".join(', ', values %$main::activeuids)."\n";
      # resolve id to object
      $rooms_to_enviro{ $main::objs->{$player}->{'ROOM'} } = 1;      
  }
 # print "    Scanning...\n";
    #&main::scan_crappy_objects;

  # print "    Room hit.\n";
  foreach my $room (keys %rooms_to_enviro) {
      # idle it
      $main::map->[$room]->enviro_idle();
  }
}

# This is done out-of-game now
#sub main::timed_score_update {
#   $main::eventman->enqueue(60 * 60 * 12, \&main::timed_score_update);
#   &ora_scores::compile_all();
#}

sub main::timed_item_injection {
  $main::eventman->enqueue(60*60*.5, \&main::timed_item_injection);
  
  &rockobj::item_randinject();
}

sub main::timed_repu_fun {
  $main::eventman->enqueue(60 * (rand(4)+6), \&main::timed_repu_fun);
  
  foreach my $player (sort keys(%{$main::activeuids})) {
     next if (rand(10) < 8.5);
     $player = $main::objs->{$main::activeuids->{$player}};
     if ($player->{'REPU'} < $main::badrepborder) {
        $player->inv_rand_lose_unequipped();
        if (rand(3) < 2 && !$main::map->[$player->{'ROOM'}]->{'SAFE'} && !$main::map->[$player->{'ROOM'}]->{'PVPROOM'}) {
            $player->assassin_haunt();
            $player->assassin_haunt();
        }
     } elsif ($player->{'REPU'} > $main::goodrepborder) {
        my $amt = int (($player->{'LEV'}/2 + rand($player->{'LEV'}/2)) / 2);
        return if !$amt;
        $player->log_append("{13}A cheerful leprechaun wanders into the room. He flashes you a bright white smile and tosses you a bag containing $amt cryl.\n");
        $player->room_sighttell("{13}A cheerful leprechaun wanders into the room. He flashes $player->{'NAME'} a bright white smile and tosses $player->{'PPRO'} a bag containing $amt cryl.\n");
        $player->{'CRYL'} += $amt;
     } 
	 if ($player->{'TOP_PLAYER'}) {
        my $amt = int (($player->{'LEV'} + rand($player->{'LEV'}*2)) / 2);
        return if !$amt;
        $player->log_append("{13}A cheerful leprechaun wanders into the room. He flashes you a bright white smile and tosses you a bag containing $amt cryl.\n");
        $player->room_sighttell("{13}A cheerful leprechaun wanders into the room. He flashes $player->{'NAME'} a bright white smile and tosses $player->{'PPRO'} a bag containing $amt cryl.\n");
        $player->{'CRYL'} += $amt;
     }
  }
  #inv_rand_lose_unequipped

}


sub clean_idle_sockets {
  my ($objid, $sock, $sockno) = (shift);
  for $sock ($main::sock_sel->handles) {
      next if ($sock==$main::listen);
      if(defined($main::sockplyrs->{$sock->fileno}) &&
         ((time - $main::sockplyrs->{$sock->fileno}->{'@LCTI'}) > (60*30) )
        ) { &rock_destp($sock->fileno); }
  }
  return(undef);
}

sub rand_ele { $_[int rand(scalar @_)]; }

sub check_auto_cleanup {

  return unless $main::do_cleanup;  

  my $users = scalar keys(%{$main::activeuids}); # NOTE: %{$main::act..}?
  if($_[0] || ($users < 15 && (time - $main::rock_stats{'lastautocleanup'} > 3600*6))) {  # every 6 hours


     &rock_shout(undef, "{1}*** ATTENTION ***\n{1}*** {2}Rock will be automatically rebooting for routine cleanup in 5 minutes.\n{1}*** {2}Please finish up what you are doing and log off.\n{1}*** {2}Items on the floor will not be saved.\n{1}***\n");


     $main::admin_login_only = 1;


     $main::eventman->enqueue(60 * 5, \&main::auto_cleanup);



     $main::eventman->enqueue(60 * 5 + 30, sub { $main::admin_login_only=0; } );


     $main::eventman->enqueue(60 * 50 - 1, \&main::rock_shout, undef, "{1}*** {16}Maintainance Routine Beginning...\n");


     for(my $i=4; $i>0; $i--) { 
        $main::eventman->enqueue(60 * (5-$i), \&main::rock_shout, undef, "{1}*** {16}WARNING: {1}$i {6}minute".($i==1?undef:'s')." until reboot.\n");
     }
     $main::eventman->enqueue(60 * 4.5, \&main::rock_shout, undef, "{1}*** {16}WARNING: {1}30 seconds until reboot!!\n");
  } else {
     # do other cleanuppy type stuff?

  }

  $main::eventman->enqueue(60 * 15, \&main::check_auto_cleanup);
}

sub auto_cleanup {
     return unless $main::do_cleanup;
     &main::rock_shout(undef, "{17}*** ROCK Maintainance ***\n");
     $main::rock_stats{'lastautocleanup'} = time; # leave footprint

     # clean up
     #&main::rock_shout(undef, "  {7}o{17} Compressing in-game data\n");
     #$main::map->[0]->cleanup_inactive;
     #&main::rem_inactive_users;
     #&main::cleanup_rooms;
     #&main::compress_descs;
     #&main::cleanup_objs;
     #&main::rock_shout(undef, "  {7}o{17} Saving map file\n");
     #&main::rock_flatten_realm();
     #&main::rock_shout(undef, "  {7}o{17} Backing up map file\n");
     #&main::rock_shout(undef, "  {7}o{17} Saving player files\n");
     #&rock_maint::users_save(); 
     #&main::rock_shout(undef, "  {7}o{17} Backing up player/code files\n");
     # sort scores
     #&main::rock_shout(undef, "  {7}o{17} Compiling scores\n");
# -- this is done out-of-game now     &ora_scores::compile_all(); # compile scores
     #&main::rock_shout(undef, "  {7}o{17} Generating object reports\n");
     # ORG
     #&main::object_report_generate();
     # ORS
     #&main::object_briefing();
     # delete old players
     #&main::pfiles_deleteold;
     # ditch players
     &main::kill_all_socks("Auto-restarting Server for maintainance. Try coming back in about a minute.\n");
     
     &main::dbs_untie; 
     system('perl rockserv2.pl &');
     exit;
     return;
}

sub shutdown_game {
    print "Flattening realm\n";
    &main::rock_flatten_realm();
    print "Saving User Profiles\n";
	&rock_maint::users_save();
    print "Removing inactive users\n";
	$main::map->[0]->cleanup_inactive;
    print "Saving profiles again\n";
	&rock_maint::users_save();
    print "Removing more inactive users\n";
	&main::rem_inactive_users;
    print "Cleaning up rooms\n";
	&main::cleanup_rooms;
    print "Compressing descs\n";
	&main::compress_descs;
    print "Cleaning up objects\n";
	&main::cleanup_objs;
    print "Killing all socks\n";
	&main::kill_all_socks("SHUTTING SERVER DOWN. Try coming back later (the fix may take a second, or an hour). Sorry for any inconvenience.\n");
    print "Untying DB\n";
	&main::dbs_untie;
    print "Done with shutdown sequence.\n";
}

sub pw_find {
return;
}

sub backup_descs {
  my (%descs);
  tie %descs, "DB_File", "./dbs/pdescs.rdb", O_RDWR|O_CREAT, 0775, $DB_HASH or die "Cannot tie [pdescs.rdb]: $!\n";
  # test first
  foreach my $key (keys(%descs)) { $key = $descs{$key}; }
  
  # now save backup if it's still intact
  open(F,">pdescs.rdb.flat");
  foreach my $key (keys(%descs)) { print F pack("A30A*", $key, $main::pdescs{$key})."\n"; }
  close(F);
  untie(%descs);
  
  print "** Backed up desc flatfile.\n";
  return;
}

sub write_course_html() { 
    # TODO: Generify this so that other non-Dillfrog sites can make use of it.
    #       Maybe export XML instead, and have sites write their own XSLT?
    my $c = "<!--#include virtual=\"/include/header.asp\"-->\n\n";
    $c .= "<TABLE WIDTH=100% BORDER=0 CELLPADDING=3 COLS=3 CELLSPACING=0>\n";
    foreach my $course (sort keys(%main::courses)) { 
        my $a = $main::courses{$course};
        $c .= "<TR><th NOWRAP>$course</th><th>$a->[3] Training Points</th><th>".&rockobj::commify($a->[2])." cryl</th></TR>";
        my $tmp = $a->[6];
        $tmp =~ s/\</\&lt\;/g; $tmp =~ s/\>/\&gt\;/g;
        $tmp =~ s/\n/\<BR\>/g;
        $tmp =~ s/\{(\d*)\}/$main::colorhtmlmap{$1}/ge; # note: used to be \d? for single-char
        $c .= "<TR><TD COLSPAN=3>$tmp</TD></TR>";
        $c .= "<TR><TD COLSPAN=3>&nbsp;</TD></TR>";
    }
    $c .= "</TABLE>\n";
    $c .= "<br><B>&copy; 1999-2004 Dillfrog. All Rights Reserved. DO NOT COPY WITHOUT WRITTEN PERMISSION. However, you may link to this document without consent.</B><BR>\n";
    $c .= "<br><B>&copy; 2005 RockReloaded. All Rights Reserved. DO NOT COPY WITHOUT WRITTEN PERMISSION. However, you may link to this document without consent.</B><BR>\n";
    $c .= "<!--#include virtual=\"/include/footer.asp\"-->";

    my $index_filepath = "$main::base_web_dir/help/courses/index.html";
    if (open(F, ">$index_filepath")) {
        print F $c;
        close(F);
    } else {
       # This used to be a hard death; we'll just warn it out, since it's not
       # critical for the game's success right now. :)
       warn "WARNING: Could not open $index_filepath for writing: $!";
    }
 
    return 1;
}

sub write_playerotm_html() { 
    my @users = grep { !$_->{'SOCINVIS'} } map { &main::obj_lookup($_) } values %{$main::activeuids};
    my $player = $users[int rand @users];
	my $playername = $player ? $player->{'NAME'} : "Kler";
    open(F, ">$main::base_web_dir/potm.txt");
    print F "<A HREF=\"/slaw-bin/rock/redir-score-player.pl?player=$playername\">$playername</A>";
    close(F);
    &main::rock_hbcastshout(1, undef, "{4}>>> {14}$playername {4}is the new player of the moment!\n");
    
### UNCOMMENT THIS PLEASE -- I HAD TO COMMENT IT TEMPORARILY #    $main::eventman->enqueue(60*4, \&main::write_playerotm_html);
    return 1;
}

sub ip_is_free {
 return 1 unless $main::one_player_per_ip; # SHORT CIRCUIT
 my ($player, %ips);
 my ($ip, $istelnetting) = @_;

 if($main::bbss{$ip} || $main::bbss{substr($ip, 0, rindex($ip, '.')+1)}) { return(1); }

 my @plist = keys(%{$main::activeusers});
 foreach $player (@plist) {
    $player = &obj_lookup($player);
    $ips{$player->{'IP'}}++ if $player->{'NAME'} ne 'Untitled Player';
 }

 my $bbs;

 if($ips{$ip}>0) { &main::rock_shout(undef,"{17}".&r2_ip_to_name($ip)." {7}tried logging in twice ($ips{$ip} already active){17}.\n",1); }
 return($ips{$ip}<=0);
}


1;
