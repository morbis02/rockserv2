use strict;

# (note: player in #1 position is on the right side).
sub by_npc_deaths_least { $a->{'NPCDEATHS'} <=> $b->{'NPCDEATHS'} }
sub by_pvp_deaths_least { $a->{'PVPDEATHS'} <=> $b->{'PVPDEATHS'} }
sub by_npc_kills { $b->{'NPCKILLS'} <=> $a->{'NPCKILLS'} }
sub by_pkills { $b->{'PVPKILLS'} <=> $a->{'PVPKILLS'} }
sub by_reputation_good { $b->{'REPU'} <=> $a->{'REPU'} }
sub by_reputation_bad { $a->{'REPU'} <=> $b->{'REPU'} }
sub by_knowledge { $b->{'STAT'}->[0] <=> $a->{'STAT'}->[0] }
sub by_magic { $b->{'STAT'}->[1] <=> $a->{'STAT'}->[1] }
sub by_charisma { $b->{'STAT'}->[2] <=> $a->{'STAT'}->[2] }
sub by_agility { return $b->{'STAT'}->[3] <=> $a->{'STAT'}->[3] }
sub by_strength { $b->{'STAT'}->[4] <=> $a->{'STAT'}->[4] }
sub by_defense { $b->{'STAT'}->[5] <=> $a->{'STAT'}->[5] }
sub by_cryl { $b->{'CWORTH'} <=> $a->{'CWORTH'} }
sub by_level { $b->{'LEV'} <=> $a->{'LEV'} }

sub scores_obj_sort {
  my ($players, @sorted);
  undef(%main::telnetscores); # since we're gonna add our own now..
  $players = &scores_load_pfiles(); # get ref to object array
  %main::pscoreinfo = (); # set up hash
  %main::telnetscores = (); # ditto
  
  &lev_list($players);
  # compile pages
  &top_compile("Agility", {'STAT'}->[3], (sort by_agility (@$players)) ); # sort reference
  &top_compile("Charisma", {'STAT'}->[2], (sort by_charisma (@$players)) ); # sort reference
  &top_compile("Cryl", {'CWORTH'}, (sort by_cryl (@$players)) ); # sort reference
  &top_compile("Defense", {'STAT'}->[5], (sort by_defense (@$players)) ); # sort reference
  &top_compile("Level", {'LEV'}, (sort by_level (@$players)) ); # sort reference
  &top_compile("Knowledge", {'STAT'}->[0], (sort by_knowledge (@$players)) ); # sort reference
  &top_compile("Magic", {'STAT'}->[1], (sort by_magic (@$players)) ); # sort reference
  &top_compile("NPCDeaths-Least", '', (sort by_npc_deaths_least (@$players)) ); # sort reference
  &top_compile("NPCKills", {'NPCKILLS'}, (sort by_npc_kills (@$players)) ); # sort reference
  &top_compile("PKills", {'PVPKILLS'}, (sort by_pkills (@$players)) ); # sort reference
  &top_compile("PVPDeaths-Least", '', (sort by_pvp_deaths_least (@$players)) ); # sort reference
  &top_compile("Reputation-Bad", {'REPU'}*-1, (sort by_reputation_bad (@$players)) ); # sort reference
  &top_compile("Reputation-Good", {'REPU'}, (sort by_reputation_good (@$players)) ); # sort reference
  &top_compile("Strength", {'STAT'}->[4], (sort by_strength (@$players)) ); # sort reference
  &racial_compile;  # compile race tables
  &player_compile;  # compile race tables
  &race_count($players);
  &scores_playerfile_format($players); # extra stuff for telnet scores
# DEPRECATED  &mk_iop_ssi($players);  # iop!
  &form_index_top_compile($players);
  &drawLevelDistribution();
  undef(%main::pscoreinfo);
  undef(%main::rscoreinfo);
  return;
}


sub lev_list {
  my $players = shift;
  my %lev;
  foreach my $player (@$players) {
     $lev{$player->{'LEV'}}++;
  }
  
  open(LEV_STAT, '>rock_lvls.dat');
  foreach my $l (sort { $a <=> $b } keys(%lev)) {
     print LEV_STAT "$l $lev{$l}\n";
  }
  close(LEV_STAT);
}

sub race_count {
  my $a = shift;
  $main::rock_stats{'s-players'}=@{$a};
  my (@r);
  foreach my $p (@{$a}) {
    $r[$p->{'RACE'}]++;
  }
  for (my $n=0; $n<=$#r; $n++) { 
    $main::rock_stats{'s-prace-'.$n}=$r[$n];
  }
  return;
}


sub scores_playerfile_format {
  my ($players, $o, $oname, $n) = @_;
  foreach $o (@$players) {
     $oname = lc($o->{'NAME'});
     if(!$o->{'PVPKILLS'}) { $n='hasn\'t PvP\'d'; }
     else { $n= ((int($o->{'NPCKILLS'}/$o->{'PVPKILLS'}*1000))/1000)." ( $o->{'NPCKILLS'} :: $o->{'PVPKILLS'} )"; }
     $main::telnetscores{$oname} .= sprintf("{7}%35s {4}:{14}:{4}: {6}%-35s\n", 'NPC::Player Kill Ratio', $n);
     if(!$o->{'PVPDEATHS'}) { $n='hasn\'t P-Died'; }
     else { $n= ((int($o->{'NPCDEATHS'}/$o->{'PVPDEATHS'}*1000))/1000)." ( $o->{'NPCDEATHS'} :: $o->{'PVPDEATHS'} )"; }
     $main::telnetscores{$oname} .= sprintf("{7}%35s {4}:{14}:{4}: {6}%-35s\n", 'NPC::Player Death Ratio', $n);
     $main::telnetscores{$oname} .= sprintf("{7}%35s {4}:{14}:{4}: {6}%-35s\n", 'Misc Deaths', $o->{'MISCDEATHS'}*1);
  }
 return;
}

sub mk_iop_ssi {
  my $players = shift;
  my $p;
  foreach $p (@$players) {
    if(-e "$main::base_web_dir/admin/iop/".lc($p->{'NAME'}).'.shtml') { next; }
    open(F, ">$main::base_web_dir/admin/iop/".lc($p->{'NAME'}).'.shtml');
    print F '<!--#include virtual="header.html"-->'."\n";
    print F '<!--#include virtual="'.lc($p->{'NAME'}).'.iop"-->';
    print F '<!--#include virtual="footer.html"-->'."\n";
    close(F);
  }
  return;
}

sub form_index_top_compile {
  my ($players) = shift;
  my (@itypes) = ('Agility', 'Cryl', 'Charisma', 'Defense', 'Knowledge', 'Level', 'Magic', 'NPCKills', 'PKills', 'Reputation-Good', 'Reputation-Bad', 'Strength');
  my ($cap, $info);
  $cap .= "<FORM METHOD=POST ACTION=http://$main::rock_host/slaw-bin/redir-clip.pl>";
  $cap .= '<CENTER><TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0 WIDTH=100%><TR ALIGN=LEFT VALIGN=MIDDLE><TD ALIGN=RIGHT><FONT FACE=Arial SIZE=-1>View Ability Ranks by: ';
  $cap .= "<INPUT TYPE=HIDDEN NAME=1 VALUE=\"$main::base_web_url/scores/top-\">";
  $cap .= '<SELECT NAME=2>';
  foreach $info (@itypes) { $cap .= '<OPTION VALUE="'.lc($info)."-\">$info"; }
  $cap .= '</SELECT>';
  $cap .= '<BR>Listing: ';
  $cap .= '<SELECT NAME=3>';
  for (my $n=1; $n <= scalar (@$players); $n+=$main::usersperpage) { 
     $cap .= '<OPTION VALUE="'.$n.'-'.($n+$main::usersperpage-1).".shtml\">$n - ".($n+$main::usersperpage-1);
  }
  $cap .= '<OPTION VALUE="racial.shtml">Racial';
  $cap .= '</SELECT>';
  $cap .= "</TD><TD><INPUT TYPE=IMAGE VALUE=\"View\" WIDTH=123 HEIGHT=30 ALIGN=ABSMIDDLE SRC=\"$main::base_web_url/images/view.gif\" BORDER=0>";
  $cap .= '</TD></TR></TABLE></CENTER></FONT></FORM>';
  
  # SAVE TO DISK
  open (F, ">$main::base_web_dir/scores/".'top-index.html') || warn "Cannot open r2 scorefile: $!\n";
  print F $cap;
  close(F);

  return;
}


sub racial_compile {
   my ($race, $header, $footer);
   $header = '<!--#include virtual="../rocktmpl1.html"-->';
   $footer = '<!--#include virtual="../rocktmpl2.html"-->';
   foreach $race (sort keys(%main::rscoreinfo)) {
      open (F, ">$main::base_web_dir/scores/".'racial-'.lc($race).'.shtml') || warn "Cannot open r2 scorefile: $!\n";
      print F $header;
      print F "<FONT COLOR=RED SIZE=+1><FONT COLOR=#9966CC>scores</FONT>:<FONT COLOR=#6666CC>racial</FONT>:<FONT COLOR=#3366CC>".lc($race)."</FONT></FONT><BR><BR>";
      print F "Racial Progress Overview for <FONT COLOR=MAGENTA>$race</FONT> (compared to/polled from all races):<BR><BR>\n";
      print F "<TABLE BORDER=0 CELLPADDING=3 ALIGN=CENTER WIDTH=100%>";
      print F $main::rscoreinfo{$race};
      print F "</TABLE>";
      print F $footer;
      close(F);
   }
  return;
}

sub player_compile {
   my ($player, $header, $footer);
   $header = '<!--#include virtual="../rocktmpl1.html"-->';
   $footer = '<!--#include virtual="../rocktmpl2.html"-->';
   foreach $player (sort keys(%main::pscoreinfo)) {
      open (F, ">$main::base_web_dir/scores/".'player-'.lc($player).'.shtml') || warn "Cannot open r2 scorefile: $!\n";
      print F $header;
      print F "<FONT COLOR=RED SIZE=+1><FONT COLOR=#9966CC>scores</FONT>:<FONT COLOR=#6666CC>player</FONT>:<FONT COLOR=#3366CC>".lc($player)."</FONT></FONT><BR><BR>";
      print F "Player Standings for <FONT COLOR=MAGENTA>$player</FONT></FONT>:<BR><BR>\n";
      print F "<TABLE WIDTH=100% BORDER=0 CELLPADDING=3 ALIGN=CENTER>";
      print F $main::pscoreinfo{$player};
      print F "</TABLE>";
      print F $footer;
      close(F);
   }
  return;
}

sub top_compile {
 my ($type, $eval_val, @players) = @_;
 my ($player, %racevals, $header, $footer, $n, $pagerankid, $othn, $prevnumset, $currnumset);

 
 # prefs
 my $usersperpage = $main::usersperpage; # *** ! SHOULD be an even number.
 my (@colorarray) = ('#9966CC', '#6666CC', '#3366CC', '#0066CC', '#0066FF', '#0066CC', '#3366CC', '#6666CC');
 my $telnetusers = 20;
 
 # define header/footer:
 $header = '<!--#include virtual="../rocktmpl1.html"-->';
 $footer = '<!--#include virtual="./top-index.html"--><!--#include virtual="../rocktmpl2.html"-->';
 unshift (@players, undef); # cuz it counts from 1-x, not 0-x..
 $pagerankid=99999;
 for ($n=1; $n<=$#players; $n++) {
    #print "N is $n. Player name is $players[$n]->{'NAME'}. F is ".(F)."\n";
    if($pagerankid >= $usersperpage) { 
      if(-e F) {
        #print "Closing table at $n.\n";
        $n += ($usersperpage/2); # so we dont overlap.
        print F "<TR VALIGN=CENTER><TD ALIGN=RIGHT>";
        if($prevnumset) { print F '<A HREF=top-'.lc($type).'-'.$prevnumset.".shtml><FONT FACE=Arial SIZE=-1>Previous $usersperpage</FONT></A>"; }
        print F "</TD><TD></TD><TD></TD><TD ALIGN=LEFT>";
        if($n<=$#players) { print F '<A HREF=top-'.lc($type).'-'.($n).'-'.($usersperpage+$n-1).".shtml><FONT FACE=Arial SIZE=-1>Next $usersperpage</FONT></A>"; }
        print F "</TD></TR></TABLE>";
        print F $footer;
        close(F);
        if(!($n<=$#players)) { next; }
      }
      $prevnumset = $currnumset;
      $currnumset = $n.'-'.($usersperpage+$n-1);
      open (F, ">$main::base_web_dir/scores/".'top-'.lc($type).'-'.$currnumset.'.shtml') || warn "Cannot open r2 scorefile: $!\n";
      print F $header;
      print F "<FONT COLOR=RED SIZE=+1><FONT COLOR=#9966CC>scores</FONT>:<FONT COLOR=#6666CC>top</FONT>:<FONT COLOR=#3366CC>".lc($type)."</FONT>:<FONT COLOR=#0066CC>$n-".($usersperpage+$n-1)."</FONT></FONT><BR><BR>";
      print F "<TABLE WIDTH=100% HEIGHT=100% BORDER=0 COLS=4 CELLPADDING=3 ALIGN=CENTER>";
      $pagerankid=0;
    }
    
    $othn = ($usersperpage/2 + $n);
    print F "<TR ALIGN=RIGHT><TD>";
    if($players[$n]) { 
       # web
       print F "<B><FONT FACE=Impact SIZE=+1>$n</FONT></B>";
       $main::pscoreinfo{$players[$n]->{'NAME'}}.="<TR><TD ALIGN=RIGHT><FONT FACE=Arial>"
       ."<A HREF=top-".lc($type).'-'.( (int($n/$usersperpage))*$usersperpage + 1).'-'.( (int($n/$usersperpage))*$usersperpage + $usersperpage).'.shtml>'
       ."$type</A></TD><TD ALIGN=LEFT><FONT COLOR=MAGENTA FACE=Arial>\#$n</FONT></TD></TR>";
       # telnet
       $main::telnetscores{lc($players[$n]->{'NAME'})} .= sprintf("{7}%35s {4}:{14}:{4}: {6}%-35s\n", $type, "#$n");
       if($eval_val && $players[$n]->{'RACE'} && $main::races[$players[$n]->{'RACE'}]) { 
         $racevals{$main::races[$players[$n]->{'RACE'}]} += eval('$players[$n]->'.$eval_val);
       }
    }
    print F "</TD><TD ALIGN=LEFT>";
    if($players[$n]) { 
       print F "<A HREF=player-".lc($players[$n]->{'NAME'}).".shtml><FONT FACE=Arial COLOR=".$colorarray[($n % ($#colorarray+1))].">$players[$n]->{'NAME'}</FONT></A><BR><FONT COLOR=#660066 FACE=Arial SIZE=-1>( $main::races[$players[$n]->{'RACE'}] $main::webnewbiemap[$players[$n]->{'NEWBIE'}] )</FONT>"; 
    }
    print F "</TD><TD>";
    if($players[$othn]) { 
       # web
       print F "<B><FONT FACE=Impact SIZE=+1>$othn</FONT></B>";
       $main::pscoreinfo{$players[$othn]->{'NAME'}}.="<TR><TD ALIGN=RIGHT><FONT FACE=Arial>"
       ."<A HREF=top-".lc($type).'-'.( (int($othn/$usersperpage))*$usersperpage + 1).'-'.( (int($othn/$usersperpage))*$usersperpage + $usersperpage).'.shtml>'
       ."$type</A></TD><TD ALIGN=LEFT><FONT COLOR=MAGENTA FACE=Arial>\#$othn</FONT></TD></TR>";
       # telnet
       $main::telnetscores{lc($players[$othn]->{'NAME'})} .= sprintf("{7}%35s {4}:{14}:{4}: {6}%-35s\n", $type, "#$othn");
       if($eval_val && $players[$othn]->{'RACE'} && $main::races[$players[$othn]->{'RACE'}]) { 
         $racevals{$main::races[$players[$othn]->{'RACE'}]} += eval('$players[$othn]->'.$eval_val);
       }
    }
    print F "</TD><TD ALIGN=LEFT>";
    if($players[$othn]) { print F "<A HREF=player-".lc($players[$othn]->{'NAME'}).".shtml><FONT FACE=Arial COLOR=".$colorarray[($othn % ($#colorarray+1))].">$players[$othn]->{'NAME'}</FONT></A><BR><FONT COLOR=#660066 FACE=Arial SIZE=-1>( $main::races[$players[$othn]->{'RACE'}] $main::webnewbiemap[$players[$othn]->{'NEWBIE'}] )</FONT>"; }
    print F "</TD></TR>";
    $pagerankid += 2; # there's 2 per column
  }

 if(-e F) {
  #print "did last close of file.\n";
  print F "<TR VALIGN=CENTER><TD ALIGN=RIGHT>";
  if($prevnumset) { print F '<A HREF=top-'.lc($type).'-'.$prevnumset.".shtml><FONT FACE=Arial SIZE=-1>Previous $usersperpage</FONT></A>"; }
  print F "</TD><TD></TD><TD></TD><TD ALIGN=LEFT>";
  # wont happen.. if($n<=$#players) { print F '<A HREF=top-'.lc($type).'-'.($n).'-'.($usersperpage+$n-1).".shtml><FONT FACE=Arial>Next $usersperpage</FONT></A>"; }
  print F "</TD></TR></TABLE>";
  print F $footer;
  close(F);
 }
 
 # do the same, for telnet
 for ($n=1; $n<=$telnetusers; $n += 2) { 
   if(!$players[$n]) { next; }
   elsif(!$players[$n+1]) { $main::telnetscores{'top-'.lc($type)} .= sprintf("{7}%4d. {%d}%-32s\n", $n, $players[$n]->{'RACE'}, $players[$n]->{'NAME'}); }
   else { 
     $main::telnetscores{'top-'.lc($type)} .= sprintf("{7}%4d. {%d}%-32s {7}%4d. {%d}%-32s\n", $n, $players[$n]->{'RACE'}, $players[$n]->{'NAME'}, $n+1, $players[$n+1]->{'RACE'}, $players[$n+1]->{'NAME'});
   }
 }
 # then flick a topic on it
 $main::telnetscores{'top-'.lc($type)} = "{1}||{11}] {13}Top $type {14}at {4}".&main::time_get(0,1)."{14}.\n".$main::telnetscores{'top-'.lc($type)};
 
 # HANDLE RACE INFORMATION.
 my ($race, $val, $tot);
 # determine highest/lowest values for each race
 foreach $val (values(%racevals)) {
   $tot += $val;
 }
 open (F, ">$main::base_web_dir/scores/".'top-'.lc($type).'-racial.shtml') || warn "Cannot open r2 scorefile: $!\n";
 print F $header;
 print F "<FONT COLOR=RED SIZE=+1><FONT COLOR=#9966CC>scores</FONT>:<FONT COLOR=#6666CC>top</FONT>:<FONT COLOR=#3366CC>".lc($type)."</FONT>:<FONT COLOR=#0066CC>racial</FONT></FONT><BR><BR>";
 print F "Racial Progress Overview for <FONT COLOR=MAGENTA>$type</FONT> <FONT COLOR=CYAN>(compared to/polled from all races)</FONT>:<BR><BR>\n";
 print F "<TABLE BORDER=0 CELLPADDING=3 ALIGN=CENTER>";
 foreach $race (sort keys(%racevals)) {
     # update value
     if($tot) { $racevals{$race}= ( int ($racevals{$race}/$tot*10000)) / 100; }
     if($racevals{$race}<0) { $racevals{$race}=0; } # in case reputation goes negative.
     # add it to the scorefile:
     print F "<TR VALIGN=CENTER><TD ALIGN=RIGHT><A HREF=racial-".lc($race).".shtml><FONT FACE=Arial COLOR=#FF0033>$race</FONT></A></TD>"
      . "<TD><IMG SRC=$main::base_web_url/images/animbar.gif HEIGHT=14 WIDTH=".(int $racevals{$race}*3)."></TD><TD><FONT COLOR=#00FF00 FACE=Arial>"
      . "$racevals{$race}\%</FONT></TD></TR>\n";
     
     # then add the code to rscoreinfo *** REMEMBER: IT'S 3 COLS WIDE
     $main::rscoreinfo{$race} .= "<TR VALIGN=CENTER><TD ALIGN=RIGHT><A HREF=top-".lc($type)."-racial.shtml><FONT FACE=Arial COLOR=#FF0033>$type</FONT></A></TD>"
      . "<TD><IMG SRC=$main::base_web_url/images/animbar.gif HEIGHT=14 WIDTH=".(int $racevals{$race}*3)."></TD><TD><FONT COLOR=#00FF00 FACE=Arial>"
      . "$racevals{$race}\%</FONT></TD></TR>\n";
 }
 print F "</TABLE>".$footer;
 close(F);
 
 return;
}

sub scores_load_pfiles {
  # returns REFERENCE TO array of all loaded characters.
  # note: this is major cpu-age
   opendir(DIR, 'saved') || die "Cannot open saved-file directory: $!\n";
   my @files = readdir(DIR); rewinddir(DIR); closedir(DIR);
   # update uidmap :)
   my ($uid, @user_objs);
   my $time = time;
   my $fname;
   foreach $uid (@files) {
     if ($uid =~ /(.+?)\.r2/) {
        $fname = "$main::base_code_dir/saved/".lc($uid);
         if( (!(-e $fname)) || ((-M $fname)>1.2) ) { next; } # dont bother if file doesn't exist or hasnt been modified in at least 14 days
         my @c = &character_load(lc($1));
         if ($c[0] && !$c[0]->{'ADMIN'} && !$c[0]->{'CODE'} && (($time - $c[0]->{'LASTSEEN'}) < 604800) ) { push ( @user_objs, $c[0] ); } # (cuz we dont want fists, now, do we? :-)) (we dont want blank ones either)
     }
   }
   &main::rock_shout(undef, "{16}Score compilation: DT of {1}".(time-$time)."\n", 1);
   return(\@user_objs);
}

sub pwfiles_regen {
  # returns REFERENCE TO array of all loaded characters.
  # note: this is major cpu-age
   opendir(DIR, 'pws-web') || die "Cannot open web-pw directory: $!\n";
   my @files = readdir(DIR); rewinddir(DIR); closedir(DIR);
   my $file;
   foreach $file (@files) { unlink('./pws-web/'.$file); } # clear the file.
   opendir(DIR, 'saved') || die "Cannot open saved-file directory: $!\n";
   @files = readdir(DIR); rewinddir(DIR); closedir(DIR);
   # update uidmap :)
   my ($uid, @user_objs);
   foreach $uid (@files) {
     if ($uid =~ /(.+?)\.r2/) {
         my @c = &character_load(lc($1));
         if($c[0]) { &main::web_pws_register($c[0]);  if(!$main::email_addrs{lc($c[0]->{'EMAIL'})}) { $main::email_addrs{lc($c[0]->{'EMAIL'})}++; }  } # register their pw information.
     }
   }
   return(\@user_objs);
}

sub drawLevelDistribution {
   &plotIt('Number of Players vs. Level', 'Number of Players', 'Level', 'rock_lvls.dat');
}

sub plotIt {
   my ($title, $ylabel, $xlabel, $fname, $graphtype) = @_;
   $graphtype = 'lines' unless $graphtype;
   my $ppm = "$fname.ppm";
   open (myPLOT, "|gnuplot") || return ("Could not open gnuplot!\n");
   print myPLOT <<endPLOT;
set title '$title'
set size .7,.7
set ylabel '$ylabel'
set xlabel '$xlabel'
set terminal pbm small color
set grid
set output '$ppm'
plot '$fname' with $graphtype
quit
endPLOT
   sleep(2);
   close(myPLOT);
   $fname =~ /(.+?)\.[^.]/;
   open (Y, "|ppmtogif $ppm >$main::base_web_dir/images/$1.gif");
   sleep(2);
   unlink($ppm);
   close(Y);
}

1;
