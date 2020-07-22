 use strict;
   use Net::SMTP;
 push (@INC, substr($0, 0, rindex($0, '/')));
 use Net::POP3;
1;


sub check_pop {   
   #This code is horribly out of date.. probably not used anymore, or rather
   # probably SHOULD NOT be used anymore.

   my ($pop, $msg, $line, $msglist, $subject, $replyto, $from, $undel, $boxsize, $admincap);
   $pop = Net::POP3->new($main::pop_mail_server);
   if(!$pop) { &rock_shout(undef, "{1}Pop connection failed: {4}$! {1}Will try again next time.\n", 1); return; }
   $pop->login('HARDCODEDPOPLOGINID', 'HARDCODEDPOPPASSWORD'); # || (warn("Could not log into POP3 server!")&&return);
   
   ($undel, $boxsize) = $pop->popstat;
   if($undel == 0) { 
     $admincap = "{14}Mailbox was empty.\n";
   } else {
     $admincap = "{1}Rockserv received {14}$undel {1}messages!\n";
     $msglist = $pop->list; #|| (warn("Could not list pop message!")&&return);
     foreach $msg (sort bynumasc (keys(%{$msglist}))) {
       my $msg_top = $pop->top($msg);
       foreach $line (@{$msg_top}) {
         if ($line =~ /Subject: (.+?)\n/) { $subject = $1; }
         elsif ($line =~ /Reply-To: (.+?)\n/) { $replyto = $1; }
         elsif ($line =~ /From: (.+?)<(.+?)>\n/) { $from = $2; }
         elsif ($line =~ /From: (.+?)\n/) { $from = $1; }
       }
       $replyto = $from unless $replyto;
       if($replyto) { 
          $admincap .= sprintf('{6}%3d{7}: {1}%-29s {13}|{6} %43s'."\n", $msg, $replyto, $subject);
          if( ($subject =~ /\[RV\]/) && !($subject =~ /returned|unknown/i) ){
             &verify_subj($subject, $replyto, 1);
          }
          elsif($subject =~ /R2STAT/i) { 
             &mail_send($replyto, 'R2 Status!', &r2_statcap);
          }
          elsif($subject =~ /MANUAL|DEVELOPER/i) { 
             &mail_send($replyto, 'Rock ][ DevManual', &main::kill_color_codes(&rockobj::help_get(undef,'CRE8ITEM')));
          }
          elsif($subject =~ /PRETEXT/i) { 
             &mail_send($replyto, 'Rock ][ Pretext', &main::kill_color_codes(&rockobj::help_get(undef,'PRETEXT')));
          } else {
             my $a = $pop->get($msg);
        #     splice(@{$a}, scalar @{$msg_top});
             for (my $i=0; $i<@{$a}; $i++) { if(substr($a->[$i],0,1) eq '.') { $a->[$i] = ' '.$a->[$i]; } }
             &mail_send($main::rock_support, $subject, join('', @{$a}), $replyto);
          }
       }
       # and delete it too.
       $pop->delete($msg) || warn "Couldn't delete message $msg: $!\n";

       ($subject, $replyto, $from) = ();
     }
 
}
    &rock_shout(undef, $admincap, 1);
$pop->quit;
}

sub r2_statcap() {
my $cap  = "===--------------> Rock ][ Status ... ( current as of ".&time_get(0,0).". )\n\n";
   $cap .= &map_list."\n";
   $cap .= &obj_list('')."\n";
   $cap .= &rock_telnetters."\n";
   $cap .= &rock_activeusers."\n";
   $cap .= "===--------------> Have a nice day.\n";
   $cap =~ s/\{.*?\}//g; # kills all color codes
   return($cap);
}

sub verify_subj(subject, recipient [, no_reverify]) {
return -2; ### VERIFICATION IS DEPRECATED ##  
}

sub send_reciept {
   my ($recipient, $msg) = @_;
   print "Sending reciept to: $recipient\n";
   if(!$recipient) { return; }
   my $subject = "Subject: ( Rock 2 ) Welcome to the Game!";
   # import/append standard message
   my ($line, $cap);
   open (WFILE, 'rockwelcome.mail'); my @weltext = <WFILE>; close(WFILE);
   foreach $line (@weltext) { $cap .= $line; }
   $cap .= $msg;
   # send msg
   &mail_send($recipient, $subject, $cap);
   return;
}


sub mail_send
 {
   my ($recipient, $subject, $xtracap, $replyto) = @_;

   ##
   # Short-circuit this for now.. I dont want to spam anyone, or get spammed for that matter. :)
   ##
   print "WOULD HAVE, but DIDNT, SEND MAIL\n    To: $recipient\n    Subject: $subject\n    Body: $xtracap\n";
   return;

   $replyto = $main::rock_serv unless $replyto;
   if(!open(MAIL, "|$main::mail_program")) {
     print "ERROR: Could not send:\nRecip: $recipient\nSubj: $subject\n\nExtracap:\n$xtracap\n";
     return; 
   }
   # form header
   my $cap = "To: $recipient\n"
           . "From: $replyto\n"
           . "Reply-to: $replyto\n"
           . "Subject: $subject"
           . "\n\n";
           
   print MAIL ($cap.$xtracap);
   close(MAIL);
   return;
 }

sub handle_newplayer (object) {
  my $self = shift;
  return unless $self->{'DILLFROG_AUTHED'};
  my ($uid) = ($self->{'NAME'});
  my ($cap, $code);

  $main::uidmap->{lc($self->{'NAME'})}=time; # marked last login/signup time
  $self->obj_dump; # save it of course

  print "Saving new character: $self->{'NAME'}, $self->{'EMAIL'}.\n";
  &main::log_event("New Character", "$self->{'NAME'} created a new $main::races[$self->{'RACE'}].", $self->{'UIN'}, $self->{'RACE'});
  &rock_shout(undef, "{13}### NEW SIGNUP: $self->{'NAME'} ($self->{'EMAIL'}).\n", 1);
  return;
}

sub bynumasc { $a <=> $b }
sub bynumdec { $b <=> $a }

# PRINTS EACH MESSAGE:

#  foreach $msg (keys(%{$msglist})) {
#    print "Message $msg:\n";
#    foreach $line (@{$pop->get($msg)}) {  print $line;  }
#  }
