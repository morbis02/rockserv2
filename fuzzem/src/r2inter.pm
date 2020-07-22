package main;
use strict;
use news_man;
use HashScan;

package main;

# Set up our fun signals

#foreach my $key (keys %SIG) { $SIG{$key} = \&sig_tell; }
$SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'SEGV'} = \&sig_kill;
#$SIG{'PIPE'} = "IGNORE";

$main::already_shut_down_game = 0;
sub sig_kill {
    return if $main::already_shut_down_game++;
	
	    &main::rock_shout(undef, "{17}*** Forced to be Killed (dying gracefully)! ***\n", 1);

    print "#######      Caught sig; dying gracefully.      ##########\n";
    
	&main::shutdown_game;    
    exit;
}

sub sig_tell {
    &main::rock_shout(undef, "{16}### GOT SIG: @_\n", 1);
}

sub load_libs {
 # loads other things that r2interp would just love to have.
 #if($^X eq 'MacPerl') { print "LIB LOADING SKIPPED - YOU HAVE MACPERL.\n"; return; }

# docs
undef($main::telnet_welcome);
open(F,"./rocklib/telnetwelcome.txt"); while(!eof(F)) { $main::telnet_welcome .= <F>; } close F;

print "Loading rocklib files...\n";
 opendir(DIR, 'rocklib') or die "Cannot open 'rocklib' directory: $!\n";
 my @files = readdir(DIR); rewinddir(DIR); closedir(DIR);
 my ($file);
 foreach $file (@files) { 
      if($file =~ /(.+?)\.rl/){ # load rocklibs (.pl scripts)
           print "## Loading [$file]...\n";
           do ('./rocklib/'.$file);
      } elsif($file =~ /(.+?)\.st8/){ # load states
           open (F, './rocklib/'.$file) || die "Can't open st8 file: $!\n";
           @{$main::state->{uc($1)}}=<F>;
           print "## Set up ST8file [$1]...\n";
           close(F);
      } elsif($file =~ /(.+?)\.hlp/){ # load states
           open (F, './rocklib/'.$file) || die "Can't open hlp file: $!\n";
		   $main::help->{uc($1)} = '';
           while(!eof(F)) { $main::help->{uc($1)} .= <F>; }
           print "## o HELP [$1]...\n";
           close(F);
      } elsif($file =~ /(.+?)\.frame/){ # load states
           open (F, './rocklib/'.$file) || die "Can't open frame file: $!\n";
		   $main::r2_frames{uc($1)} = '';
           while(!eof(F)) { $main::r2_frames{uc($1)} .= <F>; }
           print "## o FrameType [$1]...\n";
           close(F);
      } elsif($file =~ /(.+?)\.skl/){ # load skillz
           open (F, './rocklib/'.$file) || die "Can't open skl file: $!\n";
           my $count = 0;
           while(!eof(F)) { my $c=<F>; chomp($c); my @a = split(/\|/, $c);  $main::skillinfo[$count++] = [@a];}
           print "## o SkillList [$1]...\n";
           close(F);
      }
 }
 &help_set_topics;
 return;
}


sub objs_idle {
    my @objs = values %$main::objs;
    
    my $cycles = 100;
    $cycles = $main::next_obj_idle_index + 1 if $main::next_obj_idle_index + 1 < $cycles;
     
#    while ($cycles-- > 0 && $main::next_obj_idle >= 0) {
#        $objs[$main::next_obj_idle_index--]->on_idle();
#    }
    
    $main::next_obj_idle_index = @objs - 1 unless $main::next_obj_idle_index >= 0;

    return;
}

sub character_load (uid/name) {
	# returns character object
	# note that this does not change objid information.
	my ($self, $dweap);
	my $p = &character_file_load($_[0]);
	if(!$p) { return; }
	eval($$p);
	
	# Magic tie for debugging -- 
	# DON'T MESS WITH THIS UNLESS YOU KNOW WHAT YOU'RE DOING
	# IT COULD MAKE PLAYER CHARACTERS SUCK BIGTIME!!!
	if ($self->{'SHOULD_HASHSCAN'}) {
		my %image;
		my $tmp_image = tie %image, 'playerHashScan', 
	    	or &main::rock_shout(undef, "Couldn't tie playerHashScan\n", 1);
		%image = %$self;
		$self = bless (\%image, ref($self));
	}
	
	return($self, $dweap);
}

sub web_help_generate {
  my ($key, $cap);
  # static (hopefully) prefs.
  my $helpdir = "$main::base_web_dir/telnethelp/";
  
  # declare, declare, declare.
  my ($header, $footer, $n, $links, $title);
  
  # load header, footer

  $footer = &rocklib_file('helpfooter.txt'); 
  
  # generate html links to other help files
  $links = "<CENTER><FONT FACE=Arial>"; 
  
  foreach $key (sort (keys(%{$main::help}))) {

	  $key = lc($key);
	  my $keyurl = $key; $keyurl =~ s/ /+/g;

	  $links .= '<A HREF='.$keyurl.'.shtml>'.$key.'</A>'; 
	  $n++;
	  
	  if($n == 6) { $n=0; $links .= '<BR>'; }
	  else { $links .= ' / '; }
  }
  if($n != 0) { $cap = substr($cap,0,length($cap)-3); } # get rid of that extra slash
  $links .= '</FONT></CENTER>';
  
  ### write the help files ###
  foreach $key (keys(%{$main::help})) {
      my $pretty_key = join (' ', map { ucfirst $_ } split(/\s+/, lc $key));
      my $header = <<END_HTML;
<!--#set var="page_title" value="$pretty_key" -->
<!--#include virtual="/include/header.asp" -->
END_HTML

    $title = "<FONT SIZE=+2 FACE=\"Arial\" COLOR=#999999>command-line help<B>:</B>//<FONT COLOR=#FFFFFF>".lc($key)."</FONT>/</FONT><BR><BR><TT>";
    open(F, '>'.$helpdir.lc($key).'.shtml') || warn "Couldn't create html file for $key: $!\n";
    print F ($header,"\n\n",$title,"\n\n",&w2_str_teltoweb($main::help->{$key}),"</TT>\n\n<BR><BR>",$links,"\n\n",$footer);
    close(F);
  }
  
  # and make an index file while you're at it
  $title = "<FONT SIZE=+2 FACE=\"Arial\" COLOR=#999999>command-line help<B>:</B>//</FONT><BR><BR><TT>";
  my $header = <<END_HTML;
<!--#set var="page_title" value="Main" -->
<!--#include virtual="/include/header.asp" -->
END_HTML
  open(F, '>'.$helpdir.'index.shtml');
  print F ($header,"\n\n",$title,"</TT>\n\n<BR><BR>",$links,"\n\n",$footer);
  close(F);
  return;
}

sub rock_flatten_realm {
  my ($room, $cap);
  foreach $room (@{$main::map}) {
    $cap .= $room->room_flatten . "\n";
  }
  open (RFILE, '>r-allrooms.txt') || return(&main::rock_shout(undef, "{16}*** {11}!! ERROR !!{2} COULD NOT FLATTEN TO {17}r-allrooms.txt\n{16}*** {7}TYPE {17}restart{7} to restart the server and try again.\n{16}*** Sorry! All unflattened changes will be lost.\n", 1));
  print RFILE $cap;
  close(RFILE);
  # flatten each individual map.
  for (my $n = 0; $n<=$main::maxm; $n++) { &main::rock_flatten_map($n); }
  &main::rock_shout(undef, "{16}*** {1}realm flattening successful!\n", 1);
  return;
}

sub rock_flatten_map {
  my $mapnum = shift;
  my ($room, $cap);
  
  foreach $room (@{$main::map}) {
    if($room->{'M'} == $mapnum) { $cap .= $room->room_flatten . "\n"; }
  }
  
  open (RFILE, sprintf('>./maps/map-%02d.txt', $mapnum)) or
      &main::mail_send($main::rock_admin_email, 'RockSERV ERROR!', "Error: Cannot open /maps/ directory for flattening ($mapnum): $!\n");
  print RFILE $cap;
  close RFILE;
  return;
}


sub make_oddnountable {
  # sets up hash table of abnormal nouns.
  my (@nfrom, @nto);
  @nfrom = split (/ /,'sheep deer chinese fish alumnus alumna data medium crisis index appendix man woman loaf child mouse ox die tooth cod salmon bass staff calf hoof person foot watch wife knife shelf bus leaf half life loaf kiss glass potato cactus focus fungus nucleus syllabus analysis diagnosis oasis thesis crisis phenomenon criterion');
    @nto = split (/ /,'sheep deer chinese fish alumni alumnae datum media crises indicies appendicies men women loaves children mice oxen dice teeth cod salmon bass staves calves hooves people feet watches wives knives shelves buses leaves halves lives loaves kisses glasses potatoes cacti foci fungi nuclei syllabi analyses diagnoses oases theses crises phenomena criteria');
  while ($#nfrom > -1) {
    $main::oddnouns{ shift(@nfrom) }=shift(@nto);
  }
  return;
}

sub make_plural($noun) {
  # Some grammar rules used were learned from:
  # http://www.grammarlady.com/spelling_rules.html - Thanks!
  my ($noun, $lastchar, $seclastchar);

  $noun = lc($_[0]); # It's not a proper noun, so who cares if it's lower-cased?

  # Get last and second-to-last letters of noun.
  $lastchar = substr($noun, length($noun)-1, 1);
  $seclastchar = substr($noun, length($noun)-2, 1);

  # Return the pre-decided plural form if it's a weird one.
  if("$main::oddnouns{$noun}" ne "") { return($main::oddnouns{$noun}); }

  # if the noun ends in y preceded by a consonant, change y to i and add es.
  if( ($lastchar eq 'y') && (index('aeiou', $seclastchar) == -1) ) {
    return( substr($noun, 0, length($noun)-1) . 'ies' );
  }

  # add es if the word ends in s/sh/ch/x.
  if( (index('sx', $lastchar) != -1) || (index('sh ch', $seclastchar.$lastchar) != -1) ) {
    return($noun . 'es');
  }
  
  # otherwise just add an s.
  return($noun . 's');
}

sub rock_import_commands {
 # imports command aliases.
 open (F, 'commands.ali') || die "Cannot open commands.ali: $!\n";
 my @a = <F>; close(F);
 my ($line, $key, $val, $n);
 $n = 0;
 foreach $line (@a) {
   ($key, $val) = split(/\:/,lc($line));
   $val =~ s/\n//g;
   $main::cmdbase_ali->{$key}=$val;# unless $main::cmdbase_ali->{$key};
   $n++;
 }
 &main::rock_shout(undef, "{17}## Imported $n command aliases.\n", 1);
 return;
}

sub rock_change_obj {
  my ($sockno, $newno) = @_;
  if (!defined($sockno) || !defined($newno)) { return; }      # return if undefined
  elsif (!$main::objs->{$newno}) { $main::sockplyrs->{$sockno}->log_append("{3}Non-existant Obj# ({4} $newno {3}).\n"); return; }# return if objnum doesnt exist
  elsif (defined($main::activeusers->{$newno})) { $main::sockplyrs->{$sockno}->log_append("{3}Error: Active OBJ#.\n"); return; }
  elsif ($main::objs->{$newno}->{'TYPE'}<0) { $main::sockplyrs->{$sockno}->log_append("{3}Error: Ahh, You can't be that object!\n"); return; }
  else {
     my $oldno = $main::sockplyrs->{$sockno}->{'OBJID'};
     delete $main::activeusers->{$main::sockplyrs->{$sockno}->{'OBJID'}}; # someone else can control it, 'sokay!
     $main::sockplyrs->{$sockno}=$main::objs->{$newno};
     $main::activeusers->{$main::sockplyrs->{$sockno}->{'OBJID'}}=time; #in case obj normally doesnt log
     $main::objs->{$newno}->{'IP'}=&get_socket($sockno)->peerhost;
     $main::objs->{$newno}->log_append("{3}You are now $main::objs->{$newno}->{'NAME'}.\n{1}NOTE: You may not receive log info if anyone else is logged in as the same object.\n");
     $main::objs->{$newno}->room_log;
     $main::objs->{$oldno}->obj_logout;
	 # let user see their texto again, in case they didn't before.
	 # this could probably go in the player_login sub instead
	 $main::objs->{$newno}->log_append(chr(255).chr(252).chr(1).chr(255).chr(253).chr(1));
     return;
  }
  return;
}

sub rock_activeusers {
   # Returns colorized string of all players in the game (whether
   # they're connected through telnet or not (?)).
   my $player;
   my @plist = sort { lc $a->{'NAME'} cmp lc $b->{'NAME'} } map { &obj_lookup($_) } keys %{$main::activeusers};
   
   return "{1}No players are active. What?! =)\n"
       unless @plist;
	   
   ## otherwise..
   my $cap = "{17}---------------- Active Users:\n";
   
   foreach $player (@plist) {
      $cap .=  sprintf ("{17}%7s {2}%4s {12}%-20s {11}%-20s\n",
	      $player->{'OBJID'}, $player->{'ROOM'},
		  substr($player->{'NAME'},0,20), 
#		  $player->{'IP'});
		  &r2_ip_to_name($player->{'IP'}));
   }
   
   return $cap;
}


sub kick_all_users {
    # ejects all non-admin telnetters (??) from the game
	my @p = map { $main::objs->{$_} } keys(%{$main::activeusers});
	foreach my $p (@p) {
		next if $p->{'ADMIN'}; # if &main::ip_is_free($p->{'IP'},1);
		if(!$_[0]->telnet_kick($p->{'NAME'}, $p->{'EJPW'})) {
		    $main::donow .= '$main::objs->{'.$p->{'OBJID'}.'}->logout;';
		}
	}
}

sub ip_hto_name {
	my $ip = shift;
	if(!$main::ip_resolutions) { return($ip); }
	## for now
	my ($a, $b, $c, $d, $name, $aliases, $addrtype, $length, @serveraddr, $name, $address, $char, @a);
	# if lookup fails, set to "unknown"
	($a, $b, $c, $d) = split(/\./, $ip);
	$address = pack('C4', $a, $b, $c, $d);
	($name, $aliases, $addrtype, $length, @serveraddr) =
	gethostbyaddr($address, 2);
	$name =~ tr/A-Z/a-z/;   # convert dns name to lowercase
	if ($name eq '') { 
       # FOR ANONYMITY:
       @a = split (quotemeta'.',$ip);   #######3pop(@a);
       $name = join('.',@a) . '*';
       $name=$ip;
	} else {
       # FOR ANONYMITY:
#       ($char, $name) = split (quotemeta'.',$name,2);
#       $name = '*.'.$name;
	}
	$main::ip_resolved{$ip} = $name;
	return($name);
}

sub r2_ip_to_name {
	my $ip = shift;
	return $ip unless $main::ip_resolutions;

    return $main::ip_resolved{$ip} || &main::ip_hto_name($ip);	
}

sub time_get(){
#  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(($_[0] || time) + ($main::gmTimeMod * 3600));
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(($_[0] || time));
  my $ampm;
  if($hour == 12) { $ampm = "pm"; }
  elsif ($hour > 12) { $hour = $hour-12;   $ampm = "pm"; }
  else {  $ampm = "am";   }
  if ($min < 10) { $min = "0$min"; }
  if ($sec < 10) { $sec = "0$sec"; }
  if($_[1]) { return("$main::days[$wday], $main::months[$mon] $mday ($hour\:$min\:$sec$ampm)"); }
  return(sprintf("$hour\:$min\:$sec$ampm, %d-%02d-%02d", $year+1900, $mon+1, $mday));
}

sub day_get(){
#  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(($_[0] || time) + ($main::gmTimeMod * 3600));
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(($_[0] || time));
  return $main::days[$wday];
}

sub date_get(){
#  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(($_[0] || time) + ($main::gmTimeMod * 3600));
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(($_[0] || time));
  return sprintf('%04d%02d%02d', $year + 1900, $mon+1, $mday);
}

sub get_rooms_by_db {
    # Returns an array of all rooms whose DB matches any of the DB
	# numbers you pass. Currently not cached, so there's an O(total_rooms)
	# penalty for each call.
	#
	# Syntax:  &main::get_rooms_by_db($db1, $db2, ..., $dbn);
	#
	return grep {
	    my $room_db = $_->{'DB'};
		scalar grep { $_ == $room_db } @_
	} @$main::map;
}

1;  # so the require or use succeeds
