#!/usr/bin/perl
require 5.005;
BEGIN { $| = 1; }
use strict;
use bytes;
#open (EL, '>>rocklog.txt') || die "Can't open rocklog.txt: $!\n"; select(EL); $|=1;
require('r2inter.pl');
use webinter;
use IO::Socket;
use IO::Select;
use Data::Dumper;
use Benchmark;


# So old... so ugly.. 


local $SIG{__WARN__} = sub { die $_[0] };

sub route {
  print STDOUT "OK\n";
  return;
}

#### OTHER PREFS
  my $listeners = 10; # number of listeners, should be at least 1.

####

# create a socket to listen to a port
my ($listen, $listenb);
$main::cantbind=0;

print "Trying to bind to *listen*\n";
while (!($listen = IO::Socket::INET->new(Proto => 'tcp', LocalPort => 2331, Listen => 50, Reuse => 1))) { print "Couldn't bind: ($!). Trying again in a sec.\n"; $main::cantbind++; if($main::cantbind>30) { exit; } sleep(1); }
print "Trying to bind to *listenb*\n";
while (!($listenb = IO::Socket::INET->new(Proto => 'tcp', LocalPort => 4000, Listen => 20, Reuse => 1))) { print "Couldn't bind: ($!). Trying again in a sec.\n"; $main::cantbind++; if($main::cantbind>30) { exit; }  sleep(1); }
print "Bound to listen!\n";
#  LocalAddr => 'localhost'

# to start with, $select contains only the socket we're listening on
$main::listener_sel = IO::Select->new($listen, $listenb);
$main::sock_sel = IO::Select->new();

my (@ready, @outq, @inq, $bytespersend, @qkillonsend);
$main::charspersend=1000;
$main::idlestart=-25;
$main::idle = $main::idlestart;
# wait until there's something to do 
$main::sleepint=.2; # .05 sleep interval
my $idleme;
my $socktime;
my $subsocktime;
while(1) {
    $idleme=0;
    if($main::donow) { eval($main::donow); undef($main::donow); }
    select(undef, undef, undef, $main::sleepint);
    @ready = $main::listener_sel->can_read(0.01); # Checks list of places it can read from, timeout of 1/4 of a second.
    my ($socket, $sock);
    if(@ready) {

      # handle each socket that's ready (if any)
      for $socket (@ready) {
          # if the listening socket is ready, accept a new connection
          if($socket eq $listen) {
              my $new = $listen->accept;
              if($new) {
                $main::qkillonsend[$new->fileno] = 0;
                $outq[$new->fileno] = ''; # reset text, if not already
                $main::sock_sel->add($new);
                print $new->fileno . ": web. (".$new->peerhost.")\n";
           #    eval { if(!defined($main::ip_resolved{$new->peerhost})) { system('nslookup '.quotemeta($new->peerhost()).' &'); } };
                $main::rock_stats{'web-connects'}++;
                if(&main::is_banned($new->peerhost)) { print "####### BAN KILL..(disconnect to follow).\n"; &main::server_kill($new); }
                else { $new->timeout(1); }
              } # otherwise the user quit trying to contact.
          } else {
              my $new = $listenb->accept;
              if($new) {
                $main::sock_sel->add($new);
                $main::qkillonsend[$new->fileno] = 0;
                print $new->fileno . ": telnet. (".$new->peerhost.")\n";
            #    eval { if(!defined($main::ip_resolved{$new->peerhost})) { system('nslookup '.quotemeta($new->peerhost()).' &'); } };
                $main::rock_stats{'telnet-connects'}++;
                $outq[$socket->fileno] .= &cmd_make_telnet(&TELNET_IAC, &TELNET_WONT, &TELOPT_ECHO, &TELNET_IAC, &TELNET_DO, &TELOPT_ECHO, &TELNET_IAC, &TELNET_WONT, &TELOPT_BINARY, &TELNET_IAC, &TELNET_DO, &TELNET_GMCP);
                # || !&ip_is_free($new->peerhost, 1)
                if(&main::is_banned($new->peerhost) ) { print "####### BAN/IP-NOT-FREE KILL..(disconnect to follow).\n"; &main::server_kill($new); }
                else { 
                 # $outq[$new->fileno] .= &cmd_make_telnet(&TELNET_IAC, &TELNET_DONT, &TELOPT_ECHO, &TELNET_IAC, &TELNET_WILL, &TELOPT_ECHO);
                  &r2_login($new);   $new->timeout(1);
                }
              } # otherwise the user quit trying to contact.
          }
      } 
    } else { $idleme++; }
    
    @ready = $main::sock_sel->can_read(0.5); # Checks list of places it can read from, timeout of 1/2 of a second.
    if(@ready){
         for $socket (@ready) {
              # read a line of text.
              # close the connection if recv() fails.
              my $line;
              my $fileno = $socket->fileno;
              eval { $socket->recv($line,80); }; # can fail
			 
              if (my $err = $@) { print "## EVAL ERR post-recv: $@\n"; }
              if(length($line)) { 
                  while($line =~ s/$main::iackey(.)(.)//) {
                    printf ("Got a stupid telnet code (%s, %s).\n", ord($1), ord($2) );
                    &main::rock_shout(undef, "Telnet Code!\n", 1);
                    # handle telnet codes.
                    if(&telnet_replace($1,$2)) { 
#                       print "Yep had second argument..\n";
                       $outq[$fileno] .= $main::telnetmsgs{ord($1).'-'.ord($2)};
                    } else { $outq[$fileno] .= $main::telnetmsgs{ord($1)}; }
                  }
                  $line =~ s/\177/\b/g;
                  $inq[$fileno] .= $line; # Add $line to incoming queue.
                #  if(defined($main::sockplyrs->{$fileno})) { $outq[$fileno] .= "$line"; }
              } else {  &server_kill($socket); } # kill socket if you cant read from it
          }
     } else { $idleme++; } 
    
    
    # broadcast to everyone.  Close connections where send() fails.
   # $socktime = time;
    for $sock ($main::sock_sel->can_write(.5)) {
        my $fileno = $sock->fileno;
# &main::server_kill($main::sockplyrs->{55});
        if( $main::qkillonsend[$fileno] && !$outq[$fileno] ) { &server_kill($sock); next;}
        
        $subsocktime=time;
        # handle query
        # spew telnet log if applicable
        if(defined($main::sockplyrs->{$fileno})) { 
            if (length($inq[$fileno])) { 
               # backspace handling. This is really gross though. Maybe we should steal r3 code?
               while( $inq[$fileno] =~ s/[^\010]\010//) {};
               $inq[$fileno] =~ s/\010//g;
               if($inq[$fileno] =~ /\012|\015\012/) { &handle_query($sock); }
            }
            $outq[$fileno] .= $main::sockplyrs->{$fileno}->log_spew()
                if defined $main::sockplyrs->{$fileno}; #undef if player ejects his own socket
        } else {
            if (length($inq[$fileno]) && $inq[$fileno] =~ /\012|\015\012/) { &handle_query($sock); }
        }    
        
        if( (time - $subsocktime)>10 ) { 
           print "####### CMD-handling LAG! (".(time - $subsocktime)." secs) #########\n";
           &rockobj::game_caarp_log('LAG', "Major lag during a cmd handling.\n"."Lagtime: ".(time-$subsocktime)." sec.\n");
        };
        
        next if(!length($outq[$fileno]));

        $subsocktime=time;
    
        if($sock->peername){
        	$sock->send(substr($outq[$fileno], 0, $main::charspersend)); # send text
	        $outq[$fileno]=substr($outq[$fileno], $main::charspersend);  # clear text
        }else
        {
        	shutdown($sock, 2);
        }
        if( (time - $subsocktime)>10 ) { 
          eval { &rockobj::game_caarp_log('LAG', "Major lag during a send to socket ".$sock->peerhost."\n"."Lagtime: ".(time-$subsocktime)." sec.\n"); }
        };

    } 

    use integer;
    if($main::idle != time) { 
        
        eval {
             $main::maintained++;
             if($main::maintained > 2) { 
               $main::maint_friend->update;    
               $main::maintained=$main::maintainstart;
             }

             if(scalar %main::events) { &events_update; }
             no integer;
             $main::eventman->catchup();

             &main::cleanup_effects;

            # $main::idle = $main::idlestart;
            $main::idle = time;
        };

#TODO: Check whether this is actually dying out even when there's just
#      a warning (how do we trap only the death errors here? Is there an RC
#      we can look at?)
        if($@){ 
            &main::rock_shout(undef, "{17}BAD IDLE STUFF; {5}Error: \[$@\]\n", 1);
            &main::mail_send($main::rock_admin_email, "- rockserv - HELP ME!!", "BAD IDLE STUFF; Error: [$@]\n");
        }
    }


}

# NOTE: Socket programming: \015\012 is really a sockety-newline
1;

sub telnet_replace {
  if (ord($_[0]) > 250) { return $_[1]; }
  return;
}

sub kill_all_socks (message) {
   $main::restarting = 1;
   my $sock;
   for $sock ($main::sock_sel->handles) {
     if($_[0]) { eval { $sock->send($_[0]); } }
     &main::server_kill($sock);
   }
   for $sock ($main::listener_sel->handles) { &main::server_kill($sock); }
   $main::restarting = 0;
}

sub server_kill($socket) {
   ## KILLS PASSED SOCKET.
   my ($socket, $soft) = @_; 
   print $socket->fileno . ": d.\n";
   $outq[$socket->fileno]=''; $inq[$socket->fileno]=''; # Clear queue of closed socket.
   $main::qkillonsend[$socket->fileno]=''; # Clear queue-kill-on-send
   if(!$soft && $main::sockplyrs->{$socket->fileno}) {
     &rock_destp($socket->fileno);
   }
   $main::sock_sel->remove($socket);
   $socket->close;
   return;
}

sub handle_query($socket) {
 #my $t0 = new Benchmark; ### BMARK
 ### Get passed info.
 my $socket = $_[0];
 my $fileno = $socket->fileno;
 ### Config Query/QWords
 my $query;
 
 #print "Query ($fileno): $inq[$fileno]\n";
 #print "Query (ordinal): "; my @a = split('',$inq[$fileno]); my $letter;
 #foreach $letter(@a) { print ("\\",ord($letter)); } print "\n";
 
 #while($inq[$fileno] =~ /.$main::delkey|.\010/) { $inq[$fileno] =~ s/.$main::delkey|.\010//; }
 #$inq[$socket->fileno] =~ s/$main::delkey|\010//g;
 #print "QueryAFT ($fileno): $inq[$fileno]\n";
 ( $query, $inq[$fileno]) = split (/\015?\012/, $inq[$fileno], 2);
 #print "POSTSPLIT: QUERY: $query. INQ: $inq[$fileno]\n";
 ##################################################################print "handling [$query]\n";
 ### Handle Qwords cases..
 if ($main::sockplyrs->{$fileno}) { # if they're telnetting in, then cater to them.
    my $p = $main::sockplyrs->{$fileno};
    if($p->{'SAFECMD'} || $main::safe_cmds) { 
       eval { $p->cmd_do($query, $fileno); };
       if($@){ 
         &main::rock_shout(undef, "{17}BAD CMD_DO: {6}$p->{'NAME'} submitted args $query\. {5}Error: \[$@\]\n", 1);
         &main::mail_send($main::rock_admin_email, "- rockserv - HELP ME!!", "BAD CMD_DO:\n $p->{'NAME'} submitted args @_. Error: [$@]\n");
         if($main::safe_cmds) { $main::safe_cmds--; }
       }
    } else {  $p->cmd_do($query, $fileno); }
    #$outq[$fileno].="\n\r";
 } else {
   print "WEBQUERY: $query\n";
   my @qwords = split(/ /,$query);
   if(uc($qwords[0]) eq 'GET') { 
       my @gs;
       eval { @gs = &server_get($socket->peerhost,@qwords->[1]); }; # can fail on ->peerhost
       
       if (my $evalerr = $@) {
	       print "Gotta kill\n";
           &server_kill($socket);
       } else {
	       print "Nokill\n";
             $outq[$fileno]=$gs[0];
###### 2003-01-04       #    $main::qkillonsend[$fileno]=1;
       }
   } elsif(!$main::qkillonsend[$fileno] && $query eq '') { print "######## SERVER-KILLED AFTER DOUBLE NEWLINE: $fileno. (kill to follow)\n"; &server_kill($socket); }
 }
 #my $t1 = new Benchmark; my $td = timediff($t1, $t0); print "rockserv2 handle_query took: ",timestr($td),"\n";
 return;
}

sub r2_login {
  my $socket = shift;
  my $fileno = $socket->fileno;
  #  if(!defined($main::sockplyrs->{$fileno})) {
        # give'em a new player if they dont have one already
        #$outq[$fileno].="Creating New Player..\n\r";
        &rock_newp($fileno);
        for ($main::sockplyrs->{$fileno}) { 
          # set his ip
          $_->{'IP'}=$socket->peerhost;
          # give'em the login state
          $_->{ST8}->[0]='LOGIN';
          $_->{ST8}->[1]=0;
          $_->interp_st_command;
        }
        # if he's 'preferred'
        if($main::bbss{$socket->peerhost}) {
          $main::sockplyrs->{$fileno}->{'ANSI'}=1;
        }
  #  }
  return;
}

#### SET UP REFERRING URLS
my (%refer, $hits);
$refer{'/'}="$main::base_web_url/main.shtml";
$refer{'/rock.pl'}="$main::base_web_url/main.shtml";
$refer{'/rocklog.pl'}="$main::base_web_url/main.shtml";
$hits = 0;

sub server_get(@files) {
 # Handles and returns corresponding filegets..made to handle more than one file at once.
 my ($loc, $cap, $loccount, @replies, $header, $statecode, $contenttype, $query, %index);
 my ($ip, @files) = @_;
 $loccount=0; $contenttype="text/html"; # default
 foreach $loc (@files) {
  # $loc = lc($loc); # make loc lowercase;
   $loc =~ s/\+/ /g;
   $loc =~ s/%(..)/pack("c",hex($1))/ge;
   #$loc =~ tr/a-zA-Z0-9\/%\?@\.:\n-_\&/ /cs; # Strip the unwebly
   ($loc, $query) = split(/\?/,$loc,2);
   print "  L: $loc\n";
   if($query) { &main::ReadParse($query,\%index); }
   #### THIS PART CALLS SUBROUTINES DEPENDING ON THE FILE REQUESTED
  # if($loc eq "/test") { $cap="Hello There"; }
   if($loc eq "/rock.pl") { ($contenttype, $cap)=&w2_interp($ip, %index); }
   elsif($loc eq "/objlogmon.pl") { $cap=&obj_log_monitor(\%index); }
   elsif($loc eq "/rockchar.pl") { $cap=&web_character_make(\%index); }
# OBSOLETE   elsif($loc eq "/verify.pl") { $cap=&web_character_verify(\%index); }
   elsif($loc eq "/password.pl") { $cap=&pw_find(\%index); }
   elsif($loc eq "/rs/status.js") { ($contenttype, $cap)=&status_getjs(%index); }
   elsif($loc eq "/rs/status.txt") { ($contenttype, $cap)=&status_gethtml(%index); }
   elsif($loc eq "/rs/rockcam.js") { ($contenttype, $cap)=&status_rockcam(%index); }
   elsif($loc eq "/rs/rockcam.txt") { ($contenttype, $cap)=&status_rockcam(%index); }
  # elsif($loc eq "/longone") { $cap= ("whateverwhateeeveerrreweroooooooooooooooooooooooo\n") x $index{'len'}; }
   #### DETERMINE ERROR CODE (IF ANY)
   if(defined($cap)) { $statecode = 'HTTP/1.0 200 OK'; }
#   elsif(exists($refer{$loc})) { $statecode = "HTTP/1.0 302 Moved Temporarily\015\012Location: $refer{$loc}"; }
   else {  
     $statecode = 'HTTP/1.1 404 File Not Found'; 
     $cap = "<HTML><HEAD><TITLE>File Not Found</TITLE></HEAD><BODY><H1 ALIGN=CENTER>404 - File Not Found</H1><H3 ALIGN=CENTER>Could not find file [<I>$loc</I>]. Are you sure you are not possessed by wild rabbits?</H3></BODY></HTML>";
   }
   # Pragma: no-cache\015\012Expires: Monday 01-Jan-80 12:00:00 GMT\015\012
   $header = "Connection: close\015\012Server: RockServ/1.0\015\012Content-Type: $contenttype\015\012Cache-control: private\015\012Content-Length: " . length($cap) . "\015\012\015\012";
#   $header = "Server: RockServ/1.0\015\012Content-Type: $contenttype\015\012\015\012";
   $replies[$loccount] = $statecode ."\015\012". $header . $cap . "\015\012\015\012";
   $loccount++;
   $hits++;
 }
 return(@replies);
}

sub obj_log_monitor {
 my $input = shift;
 if(!defined($main::objs->{$input->{'uobj'}})) { return("<HTML><BODY BGCOLOR=BLACK><SCRIPT>parent.window.location='$main::base_web_url/enter.shtml';</SCRIPT></BODY></HTML>"); } 
 if( defined($main::activeusers->{$input->{'uobj'}}) ) { $main::activeusers->{$input->{'uobj'}}=time; }
 if($main::objs->{$input->{'uobj'}}->{'LOG'}) { return('<HTML><HEAD><META HTTP-EQUIV="Refresh" CONTENT="5;URL=objlogmon.pl?uobj='.$input->{'uobj'}.'"></HEAD><BODY BGCOLOR=#003300 LINK=#0000FF VLINK=#330000 ALINK=#330000>'."<P ALIGN=CENTER><form><input type=button value=\"refresh\" onClick=\"parent.gamescreen.window.location=(parent.gamescreen.location + '&action=%20&fix=".time."');\"></form>".'</P></BODY></HTML>'); }
 else { return('<HTML><HEAD><META HTTP-EQUIV="Refresh" CONTENT="10;URL=objlogmon.pl?uobj='.$input->{'uobj'}.'&fix='.time.'"></HEAD><BODY BGCOLOR=#330000>&nbsp;</BODY></HTML>'); }
 return;
}

sub status_getjs {
  my ($cap, $pobj, @values, $name);
  $cap .= "document.write('<TABLE BORDER=0 CELLPADDING=3 CELLSPACING=1>');\n";
  $cap .= "document.write('<TR BGCOLOR=#000033 VALIGN=CENTER ALIGN=CENTER><TD><FONT COLOR=RED FACE=Arial SIZE=-1>RockServ Handled <B>$hits</B> [web] hits since startup.</FONT></TD></TR>');\n";
  @values = values(%{$main::sockplyrs});
  if($#values != -1){
      $cap .= "document.write('<TR BGCOLOR=#000033 VALIGN=CENTER><TD><FONT COLOR=CYAN FACE=Arial SIZE=-1><CENTER>- <B>Players Online</B> -</CENTER></FONT></TD></TR>');\n";
    foreach $pobj (@values) {
      $name = $pobj->{'NAME'};
      $name =~ s/\'/\\\'/g;
      $cap .= "document.write('<TR BGCOLOR=#000033 VALIGN=CENTER ALIGN=CENTER><TD><FONT COLOR=ORANGE SIZE=-1><TT>$name</TT></FONT></TD></TR>');\n";
    }
  }
  $cap .= "document.write('</TABLE>');\n";
  return('application/x-javascript', $cap);
}

#  <SCRIPT language="JavaScript" SRC="http://$main::rock_host\:2331/rs/status.js">

sub status_rockcam {
  my ($cap, @vals, $obj);
  my $jsit = shift;
  @vals = keys(%{$main::objs});
  while(!$obj || $obj->{'TYPE'}<0) {
      $obj = $main::objs->{$vals[int rand($#vals+1)]};
  }
  $cap = '<TT><B>RockCAM</B> is on <B>'.$obj->{'NAME'}.'</B>:<BR>';
  $cap .= $obj->room_str;
  $cap =~ s/\n/\<BR\>/g;
  $cap =~ s/\{(\d*)\}/$main::htmlmap{$1}/ge; # note: used to be \d? for single-char
  if($jsit) {
      $cap =~ s/\'/\\\'/g;
      $cap = "document.write('$cap');";
     return('application/x-javascript', $cap);
  } else {
      return('text/plain', $cap);
  }
}

sub rock_objdump { return; }

sub rock_dump {
 #&main::realmvardump;
 &rock_objdump;
 print "Saving realm...\n";
 my ($r2dump);
 $r2dump = Data::Dumper->new([$main::realm], [qw(main::realm)]); $r2dump->Indent(0); $r2dump->Purity(1);
 open (WFILE, '>realm.r2') || die "Cannot open objdump file: $!\n";
 print WFILE $r2dump->Dumpxs . "\n\n1;"; close(WFILE);
 return;
}

sub ReadParse {
  my ($loc, $in) = @_ if @_;
  my ($i, $key, $val, @in);

  # Convert plus's to spaces
  @in = split(/&/,$loc);
  
  foreach $i (0 .. $#in) {
    # Split into key and value.  
    ($key, $val) = split(/=/,$in[$i],2); # splits on the first =.
    $in->{$key} .= $val;
  }
  return;
}

sub cmd_make_telnet {
  my ($cmd, @cmds);
  foreach $cmd (@_) {
     push(@cmds, chr($cmd));
  }
  return(join('',@cmds));
}

# tcb sends: DO SUPPRESS_GOAHEAD, DO ECHO, DO ECHO, DO BINARY, IWILL BINARY.
# constants, taken from Net::Telnet


sub TELNET_IAC ()        {255}; # interpret as command:
sub TELNET_DONT    ()        {254}; # you are not to use option
sub TELNET_DO ()        {253}; # please, you use option
sub TELNET_WONT ()        {252}; # I won't use option
sub TELNET_WILL ()        {251}; # I will use option
sub TELNET_SB ()        {250}; # interpret as subnegotiation
sub TELNET_GA ()        {249}; # you may reverse the line
sub TELNET_EL ()        {248}; # erase the current line
sub TELNET_EC ()        {247}; # erase the current character
sub TELNET_AYT ()        {246}; # are you there
sub TELNET_AO ()        {245}; # abort output--but let prog finish
sub TELNET_IP ()        {244}; # interrupt process--permanently
sub TELNET_BREAK ()        {243}; # break
sub TELNET_DM ()        {242}; # data mark--for connect. cleaning
sub TELNET_NOP ()        {241}; # nop
sub TELNET_SE ()        {240}; # end sub negotiation
sub TELNET_EOR ()        {239}; # end of record (transparent mode)
sub TELNET_ABORT ()        {238}; # Abort process
sub TELNET_SUSP ()        {237}; # Suspend process
sub TELNET_EOF ()        {236}; # End of file
sub TELNET_SYNCH ()        {242}; # for telfunc calls
sub TELNET_GMCP ()         {201}; # Generic MUD Protocol

sub TELOPT_BINARY ()          {0}; # Binary Transmission
sub TELOPT_ECHO ()          {1}; # Echo
sub TELOPT_RCP ()          {2}; # Reconnection
sub TELOPT_SGA ()          {3}; # Suppress Go Ahead
sub TELOPT_NAMS ()          {4}; # Approx Message Size Negotiation
sub TELOPT_STATUS ()          {5}; # Status
sub TELOPT_TM ()          {6}; # Timing Mark
sub TELOPT_RCTE ()          {7}; # Remote Controlled Trans and Echo
sub TELOPT_NAOL ()          {8}; # Output Line Width
sub TELOPT_NAOP ()          {9}; # Output Page Size
sub TELOPT_NAOCRD ()         {10}; # Output Carriage-Return Disposition
sub TELOPT_NAOHTS ()         {11}; # Output Horizontal Tab Stops
sub TELOPT_NAOHTD ()         {12}; # Output Horizontal Tab Disposition
sub TELOPT_NAOFFD ()         {13}; # Output Formfeed Disposition
sub TELOPT_NAOVTS ()         {14}; # Output Vertical Tabstops
sub TELOPT_NAOVTD ()         {15}; # Output Vertical Tab Disposition
sub TELOPT_NAOLFD ()         {16}; # Output Linefeed Disposition
sub TELOPT_XASCII ()         {17}; # Extended ASCII
sub TELOPT_LOGOUT ()         {18}; # Logout
sub TELOPT_BM ()         {19}; # Byte Macro
sub TELOPT_DET ()         {20}; # Data Entry Terminal
sub TELOPT_SUPDUP ()         {21}; # SUPDUP
sub TELOPT_SUPDUPOUTPUT ()   {22}; # SUPDUP Output
sub TELOPT_SNDLOC ()         {23}; # Send Location
sub TELOPT_TTYPE ()         {24}; # Terminal Type
sub TELOPT_EOR ()         {25}; # End of Record
sub TELOPT_TUID ()         {26}; # TACACS User Identification
sub TELOPT_OUTMRK ()         {27}; # Output Marking
sub TELOPT_TTYLOC ()         {28}; # Terminal Location Number
sub TELOPT_3270REGIME ()     {29}; # Telnet 3270 Regime
sub TELOPT_X3PAD ()         {30}; # X.3 PAD
sub TELOPT_NAWS ()         {31}; # Negotiate About Window Size
sub TELOPT_TSPEED ()         {32}; # Terminal Speed
sub TELOPT_LFLOW ()         {33}; # Remote Flow Control
sub TELOPT_LINEMODE ()         {34}; # Linemode
sub TELOPT_XDISPLOC ()         {35}; # X Display Location
sub TELOPT_OLD_ENVIRON ()    {36}; # Environment Option
sub TELOPT_AUTHENTICATION () {37}; # Authentication Option
sub TELOPT_ENCRYPT ()         {38}; # Encryption Option
sub TELOPT_NEW_ENVIRON ()    {39}; # New Environment Option
sub TELOPT_EXOPL ()        {255}; # Extended-Options-List
