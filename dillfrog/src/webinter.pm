package main;
use strict;


sub status_gethtml {
  my ($cap, $pobj, @values);
  $cap .= "<TABLE BORDER=0 CELLPADDING=3 CELLSPACING=1 STYLE=\"border: 1px ridge black\">\n";
  @values = values(%{$main::sockplyrs});
  if($#values != -1){
      $cap .= "<TR BGCOLOR=#ffffcc VALIGN=CENTER><TD><FONT COLOR=BLACK FACE=Arial SIZE=-1><CENTER>- <B>Players Online</B> -</CENTER></FONT></TD></TR>\n";
    foreach $pobj (sort {$a->{'NAME'} cmp $b->{'NAME'}} @values) {
      $cap .= <<END_CAP;
<TR BGCOLOR=#eeeeff VALIGN=MIDDLE ALIGN=LEFT>
 <TD align=right><b><FONT COLOR=#000066 FACE=Verdana SIZE=-1>$pobj->{'NAME'}</FONT></b></TD>
 <TD><FONT COLOR=#000066 FACE=Verdana SIZE=-2>$main::map->[$pobj->{'ROOM'}]->{'NAME'}</FONT></TD>
</TR>
END_CAP
    }
  }
  $cap .= "</TABLE>";
  return('text/plain', $cap);
}

sub w2header ([player obj]) {
  my ($player, $input, $cap) = @_;
  if(ref($player) eq 'player') { 
     $cap = "<HTML><HEAD><TITLE>Rock: $player->{'NAME'} - $main::map->[$player->{'ROOM'}]->{'NAME'}</TITLE></HEAD>";
     if($input->{'pr'}) { $cap .= "<BODY LINK=#880000 BGCOLOR=#".($input->{'bg'} || 'FFFFFF')." TEXT=#000033 onLoad=\"parent.gamescreen.window.location=('http://$main::rock_host\:2331/rock.pl?uobj=$input->{'uobj'}&pw=$input->{'pw'}&s=1&rl=1&bg=110011' + '&action=%20&fix=".time."');\">"; }
     else { $cap .= '<BODY LINK=#880000 BGCOLOR=#'.($input->{'bg'} || 'FFFFFF').' TEXT=#000033>'; }
   #  $cap .= '<TABLE ALIGN=CENTER BGCOLOR=#000033 WIDTH=80% HEIGHT=30><TR><TD ALIGN=CENTER><FONT FACE="Comic Sans" SIZE=+1>'.
    # "There are ".((scalar keys(%{$main::activeusers})) - 1).' other users online.</FONT></TD></TR></TABLE>';

  } else { $cap = '<HTML><HEAD><TITLE>Rock</TITLE></HEAD><BODY BGCOLOR=BLACK TEXT=WHITE LINK=#6600CC >'; } # BACKGROUND=$main::base_web_url/images/beta.gif
  $cap .= '<FONT FACE="Comic Sans">';
  return ($cap);
}

sub w2footer {
  return ('</BODY></HTML>');
}

sub w2_gen_error {
    my ($msg) = @_;
    #return('<SCRIPT> if(parent) { parent.window.location=\'$main::base_web_url/enter.shtml\'; } else { window.location=\'$main::base_web_url/enter.shtml\'; } </SCRIPT>');
    return(<<END_HTML);
<b>Rock Error:</b> $msg<br><br>
Try <a href="$main::base_web_url/enter.asp">logging in again</a>. If you continue to have problems, please write <a href="http://www.dillfrog.com/contact/">Dillfrog Support</a> at <a href=mailto:$main::rock_admin_email>$main::rock_admin_email</a>.
END_HTML
}

sub w2_obj_room {
 # returns object's room.
 my (%index) = @_;
 $index{'obj'} *= 1;
 if(!defined($index{'obj'})) { return(&w2_gen_error('No object defined (&obj=objid).')); }
 if(!defined($main::objs->{$index{'obj'}})) { return(&w2_gen_error('That object id does not exist - You probably logged out or timed out.')); }
 if ($main::objs->{$index{'obj'}}->{'TYPE'}<0) { return(&w2_gen_error('You cannot be that object.')); }
 my $cap = '<TT>Scanning <B>'.$main::objs->{$index{'obj'}}->{'NAME'}.'</B>:<BR>';
 $cap .= $main::objs->{$index{'obj'}}->room_str;
 $cap =~ s/\n/\<BR\>/g;
 $cap =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
 $cap =~ s/\'//g;
 return($cap);
}

sub web_room_str {
 my $self = shift;
 my ($cap, $capa, $capb, $desc);
   $cap .= '{3}'.$main::map->[$self->{'ROOM'}]->{'NAME'}."\n";
   $cap .= '{2}'.$main::map->[$self->{'ROOM'}]->desc_hard."\n";
   ($capa, $capb) = $main::map->[$self->{'ROOM'}]->room_inv_list($self,0);
   $cap .= $capa . $capb . '{16}' . $main::map->[$self->{'ROOM'}]->exits_list;
 return($cap);
}

sub w2_obj_do {
 # returns object's room.
 my ($player, %index) = @_;
 # parse together additional commands (from radio buttons)
 my ($x, @a) = (1);
 while (defined($index{$x})) { push(@a, $index{$x}); delete $index{$x}; print "$x"; $x++; }
 $x=1;
 while (defined($index{'_'.$x})) { push(@a, $index{'_'.$x}); delete $index{'_'.$x}; print "_$x"; $x++; }
 print "\n";
 if(@a) { $index{'cmd'} .= join(' ',@a); }
 # handle it
 #$player->log_append('{4}>>{16}'.$index{'cmd'}."\n");
 $player->cmd_do($index{'cmd'});
 return;
}

sub w2_commandform {
   my (%input) = @_;
   my $cap;
   $cap .= "<FORM NAME=doform ACTION=rock.pl><INPUT TYPE=HIDDEN NAME=uobj VALUE=\"$input{'uobj'}\">\n";
   $cap .= "<INPUT ALIGN=ABSMIDDLE TYPE=HIDDEN NAME=pw VALUE=\"$input{'pw'}\"><INPUT TYPE=HIDDEN NAME=action VALUE=\"do\">\n";
   $cap .= "Command: <INPUT TYPE=TEXT SIZE=$input{'fc'} NAME=\"cmd\" maxlength=1024><INPUT TYPE=HIDDEN NAME=pr VALUE=\"$input{'pr'}\"><INPUT TYPE=HIDDEN NAME=bg VALUE=\"$input{'bg'}\"><INPUT TYPE=HIDDEN NAME=fc VALUE=\"$input{'fc'}\"><INPUT TYPE=HIDDEN NAME=s VALUE=\"$input{'s'}\"><INPUT TYPE=HIDDEN NAME=rl VALUE=\"$input{'rl'}\">";
   $cap .= " <INPUT TYPE=SUBMIT VALUE=\"Do It!\" ALIGN=ABSMIDDLE></FORM>";
   $cap .= "<SCRIPT>document.doform.cmd.focus();</SCRIPT>";
   return($cap);
}


sub w2_link_cmd {
  # assumes link goes to rock.pl, since that's um the game. :-).
  my ($cmd, $name, $desc, $color, $endtag) = @_;
  $cmd =~ s/ /\%20/g; $desc =~ s/\'/\\\'/g;
  if($color) { $color="<FONT COLOR=$color>"; $endtag="</FONT>"; }
  # onmouseover=\"window.status='$desc';return true\"
  return("<A HREF=\"rock.pl?action=do\&cmd=$cmd$main::websuffix\">$color$name$endtag</A>");
}

sub w2_charinterp {
 my $cap = shift;
 $cap =~ s/\n/\<BR\>/g;
 $cap =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
 return($cap);
}

sub w2_str_teltoweb {
 my $cap = shift;
 $cap =~ s/\&/\&amp\;/g; $cap =~ s/\</\&lt\;/g; $cap =~ s/\>/\&gt\;/g; 
 $cap =~ s/\n/\<BR\>/g;
 $cap =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
 return($cap);
}

sub w2_interp {
  my ($ip, %input) = @_;
  my $action = $input{'action'};
  my ($cap, $player, $header);

  ### FIX IP if it's coming from us.. we can forge it from localhost
  $ip = $input{'ip'} if $ip eq "127.0.0.1" && $input{'ip'};

$main::websuffix="\&uobj=$input{'uobj'}\&pw=$input{'pw'}\&rl=$input{'rl'}\&fc=$input{'fc'}\&s=$input{'s'}\&bg=$input{'bg'}\&fix=".time;

  if ($input{'login'}) {
      delete $input{'login'};
      return(&w2_rockchar($ip, %input));
  }
  
  if (!defined($input{'uobj'})) {
      $cap .= &w2_gen_error('No user defined! (&uobj=objid).');
  } elsif (!defined($main::objs->{$input{'uobj'}})) {
      $cap .= &w2_gen_error('That character is no longer in the game. Please log in again.');
  } elsif ($main::objs->{$input{'uobj'}}->{'TYPE'} != 1) {
      $cap .= (&w2_gen_error('You cannot be that object.'));
  } elsif ( ($main::objs->{$input{'uobj'}}->{'TEMPPW'} ne $input{'pw'}) ){
      $cap .= (&w2_gen_error('Invalid Password.'));
  } else { 
      $player = $main::objs->{$input{'uobj'}};
      #if( ($player->{'IP'} ne $ip) && ($main::activeusers->{$player->{'OBJID'}}) ) { $cap .= &w2_gen_error('Someone is already using this character at the moment. Please try again later.'); }
      #else {
        $header = &w2header($player, \%input);
        $player->{'WEBACTIVE'}=1;
        $main::activeusers->{$player->{'OBJID'}}=time; $player->{'IP'}=$ip;
        if($action eq 'objroom') { $cap .= &w2_obj_room(%input); }
        elsif($action eq 'do') { $cap .= &w2_obj_do($player, %input); }
        # or maybe "if($input{'s'})"?
       # else { $cap .= &w2_gen_error('Unknown command.'); }
        # room_list, form_cmd, spew
        if($input{'s'}==2) { $cap .= &w2_oldrockform($player, \%input); }
        else {
         if($input{'fc'}) { $cap .= '<CENTER>'.&w2_commandform(%input).'</CENTER>'; }
         if($input{'s'}) { $cap .= $player->log_spew(1) . '<SCRIPT>if(parent.contentwatch) { parent.contentwatch.refreshRate=7; }</SCRIPT>'; }
         if($input{'rl'}) { $cap = $cap.'<HR>'.&main::w2_charinterp($player->web_room_str).'<HR>'; }
         if($input{'v'}) { $cap .= '<SCRIPT> if(parent) { parent.window.location = \'javascript:void(0)\'; } else { document.location = \'javascript:void(0)\'; } </SCRIPT>'; }
        }
        delete $player->{'WEBACTIVE'};
      #}
  }
  
  if(!$header) { $header = &w2header; }
  
  return('text/html', $header.$cap.&w2footer);
}

sub w2_oldrockform {
 my ($player, $input) = @_;
 my $cap;
 my ($loglen) = (length($player->{'LOG'})+length($player->{'WEBLOG'}));
 $cap = '</FONT>'.$player->{'WEBLOG'} .'<FONT FACE="Comic Sans,Comic Sans MS">'. $player->log_spew(1) . '<HR>' . &main::w2_charinterp($player->web_room_str) . '<HR>';
 undef($player->{'WEBLOG'});
 $player->{'CRYL'}*=1;
 $cap .= "<CENTER><FONT COLOR=#660000><B>[</B> <B>HP</B>: $player->{'HP'}/$player->{'MAXH'} <B>MANA</B>: $player->{'MA'}/$player->{'MAXM'} <B>TURNS</B>: $player->{'T'}/$player->{'MT'} <B>CRYL</B>: $player->{'CRYL'} <B>]</B><BR><B>[</B> Options: | ";
   if($player->{'HP'} < $player->{'MAXH'} && $player->{'HP'} > 0) { $cap .= &main::w2_link_cmd('rest', 'Take a Breather', 'Regains some HP.'); }
   elsif($player->{'HP'}<=0) { $cap .= ' <I>'.&main::w2_link_cmd('life', 'Come Back To Life', 'Makes your character live again.', 'RED').'</I>'; }
   if($main::map->[$player->{'ROOM'}]->{'HINT'}) { $cap .= ' <I>'.&main::w2_link_cmd('hint', 'View Hint', 'Displays a hint for this room.').'</I>'; }
   $cap .= ' '.&main::w2_link_cmd("eplayers", "Examine Players", "Look at everyone else in the room.");
 $cap .= ' <B>]</B></CENTER><BR>';
 ## options
 ## the text field
 $cap .= "<TABLE ALIGN=CENTER WIDTH=95%><FORM NAME=doform ACTION=rock.pl><INPUT TYPE=HIDDEN NAME=uobj VALUE=\"$input->{'uobj'}\">\n";
 $cap .= "<INPUT ALIGN=ABSMIDDLE TYPE=HIDDEN NAME=pw VALUE=\"$input->{'pw'}\"><INPUT TYPE=HIDDEN NAME=action VALUE=\"do\">\n";
 $cap .= '<TR VALIGN=TOP><TD>Command:</TD><TD><SELECT NAME="_1"><OPTION VALUE="">command-line';
 
 # standard
 $cap .= '<OPTION VALUE="say">Say [text]<OPTION VALUE="shout">Shout [text]<OPTION VALUE="i">Inventory<OPTION VALUE="peek">Peek [direction]<OPTION VALUE="">Move [direction]<OPTION VALUE="drop">Drop [item]<OPTION VALUE="look">Look [item]<OPTION VALUE="help">Help [topic]<OPTION VALUE="who">Who\'s Online?<OPTION VALUE="stat">View Stats<OPTION VALUE="exit">Exit Game';

 # special
 if($main::map->[$player->{'ROOM'}]->{'BANK'}) { $cap .= '<OPTION VALUE="">-- bank options --<OPTION VALUE="bank">View Account<OPTION VALUE="deposit">Deposit [amount]<OPTION VALUE="withdraw">Withdraw [amount]'; }
 if($main::map->[$player->{'ROOM'}]->{'STORE'}) { $cap .= '<OPTION VALUE="">-- store options --<OPTION VALUE="list">List Items<OPTION VALUE="buy">Buy [item]<OPTION VALUE="sell">Sell [item]'; }
 
 $cap .= "</SELECT></TD><TD><INPUT TYPE=\"TEXT\" AUTOCOMPLETE=\"off\" SIZE=\"35\" NAME=\"_2\" maxlength=\"1024\"></TD><INPUT TYPE=HIDDEN NAME=pr VALUE=\"$input->{'pr'}\"><INPUT TYPE=HIDDEN NAME=bg VALUE=\"$input->{'bg'}\"><INPUT TYPE=HIDDEN NAME=fc VALUE=\"$input->{'fc'}\"><INPUT TYPE=HIDDEN NAME=s VALUE=\"$input->{'s'}\"><INPUT TYPE=HIDDEN NAME=rl VALUE=\"$input->{'rl'}\"><INPUT TYPE=HIDDEN NAME=fix VALUE=\"".time.'">';
 $cap .= "<TD><INPUT TYPE=SUBMIT VALUE=\"Do It!\"></TD></FORM></TR></TABLE>";
 # <INPUT TYPE=SUBMIT NAME=1 VALUE=\"Say\" ALIGN=ABSMIDDLE><INPUT TYPE=SUBMIT NAME=1 VALUE=\"Yell\" ALIGN=ABSMIDDLE>
 if($loglen < 500) { $cap .= "<SCRIPT>document.doform._2.focus();</SCRIPT>"; }
 
# if($player->inv_objs) {
# # items
# #<CAPTION ALIGN=BOTTOM>Select the item and what you want to do with it, then click the nearest Do It! button.</CAPTION>
# $cap .= '<TABLE BGCOLOR=BLACK CELLSPACING=0 ALIGN=CENTER><TR><TD><TABLE BGCOLOR=#FFCC66 BORDER=0 CELLPADDING=5 CELLSPACING=5>';
# $cap .= "<FORM NAME=itemform ACTION=rock.pl><INPUT TYPE=HIDDEN NAME=action VALUE=\"do\"><INPUT TYPE=HIDDEN NAME=uobj VALUE=\"$input->{'uobj'}\"><INPUT ALIGN=ABSMIDDLE TYPE=HIDDEN NAME=pw VALUE=\"$input->{'pw'}\"><INPUT TYPE=HIDDEN NAME=pr VALUE=\"$input->{'pr'}\"><INPUT TYPE=HIDDEN NAME=bg VALUE=\"$input->{'bg'}\"><INPUT TYPE=HIDDEN NAME=fc VALUE=\"$input->{'fc'}\"><INPUT TYPE=HIDDEN NAME=s VALUE=\"$input->{'s'}\"><INPUT TYPE=HIDDEN NAME=rl VALUE=\"$input->{'rl'}\"><INPUT TYPE=HIDDEN NAME=fix VALUE=\"".time.'">';
# my ($n, $item, %idef) = (1);
# foreach $item ($player->inv_objs) {
#   if($n==1) { $cap .= '<TR ALIGN=RIGHT>'; }
#   $cap .= '<TD><FONT COLOR=BLUE FONT=Arial><INPUT TYPE="radio" NAME="2" VALUE="'.$item->{'NAME'}.' '.($idef{$item->{'NAME'}}+1).'"> '.$item->{'NAME'}.'</TD>';
#   if($n==3) { $cap .= '</TR>'; $n=0; }
#   $idef{$item->{'NAME'}}++;
#   $n++;
# }
# $cap .= '</TABLE></TD></TR></TABLE>';
# # options
# $cap .= '<TABLE BGCOLOR=#000033 BORDER=0 ALIGN=CENTER WIDTH=70%><TR ALIGN=RIGHT VALIGN=CENTER><TD><INPUT TYPE="radio" NAME="1" VALUE="drop">Drop</TD><TD><INPUT TYPE="radio" NAME="1" VALUE="wear">Wear</TD><TD><INPUT TYPE="radio" NAME="1" VALUE="wield">Wield</TD>';
# if($main::map->[$player->{'ROOM'}]->{'STORE'}) { $cap .= '<TD><INPUT TYPE="radio" NAME="1" VALUE="sell">Sell</TD>'; }
# $cap .= '<TD><INPUT TYPE=SUBMIT VALUE="Do It!" ALIGN=ABSMIDDLE></TD>';
# $cap .= '</TR></TABLE>';
# }
 return($cap);
}


sub w2_rockchar {
  my ($ip, %input) = @_;
  my ($cap, $error, $msg);
  if(!$input{'uid'}) {  $cap .= 'You must input a userid.<BR>'; $error=1; }
  elsif(!$main::uidmap{lc($input{'uid'})}) {  $cap .= 'That is not a valid userid. Try typing it in again or sign up for a new character.<BR>'; $error=1; }
  elsif(!$input{'pw'}) {  $cap .= 'You must input a password.<BR>'; $error=1; }
  else { $msg = &main::kill_color_codes(&rockobj::player_login(undef, $input{'uid'}, $input{'pw'}, undef, $ip, 1)); }
  if($msg) { $cap .= "$msg<BR>"; $error=1; }
  if($error) { $cap = '<b>We were unable to log you in:</b><BR><BR>' . $cap; }
  if($cap) { return('text/html', '<HTML><HEAD><TITLE>Login Failure</TITLE></HEAD><BODY BGCOLOR=BLACK TEXT=WHITE>'.$cap.'</BODY></HTML>'); }
  elsif( $input{'client'} && ($main::r2_frames{uc($input{'client'})}) ) { my $temp = $main::r2_frames{uc($input{'client'})}; $temp =~ s/\~uobj/$main::activeuids->{lc($input{'uid'})}/ge; $temp =~ s/\~pw/$main::objs->{$main::activeuids->{lc($input{'uid'})}}->{'TEMPPW'}/ge;  $temp =~ s/\~fix/time/ge; return('text/html', $temp); }
  else { return(&w2_interp($ip,%input,'uobj',$main::activeuids->{lc($input{'uid'})},'fc',60,'s',2,'rl',1,'pw',$main::objs->{$main::activeuids->{lc($input{'uid'})}}->{'TEMPPW'})); }
  return;
}

1;

# .'<SCRIPT> if(parent.contentwatch) { parent.contentwatch.bgColor=\'BLACK\'; parent.contentwatch.linkColor=\'YELLOW\'
