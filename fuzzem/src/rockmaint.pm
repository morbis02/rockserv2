######
###### Dual Character Module
######
push(@INC, 'lib');
package rock_dualchar;
use strict;
use rockdb;

# load: returns saved database
# hsave: saves args of $dualchar
# !! save: saves data to file
# !! on_login (ip, userid) logs entry

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = [];
    # nickname registry,  ip registry.
    $self->[0] = {};      $self->[1] = {};
    bless ($self, $class);
    return $self;
}

sub cant_login() {
    my ($self, $ip, $who) = @_;
    $who = lc($who);
    
    #return 0 if $main::arena_starting;
    return 0 unless $main::make_alts_wait;
    
    if( ((time() - $self->[1]->{$ip}->[0]) < $main::make_alts_wait) && ($self->[1]->{$ip}->[1] ne $who)) {
        &main::rock_shout(undef, sprintf("{3}#### %s\n", "{17}AltWatch: {13}$who ($ip) tried logging in, but $self->[1]->{$ip}->[1] logged off recently."), 1);
		return ($main::make_alts_wait - (time() - $self->[1]->{$ip}->[0]));
    } 
    return 0;
}

sub on_login () {
    # Called when a player logs into the game
    # $ip is the string IP address they were connected from
    # $who is the mixed-case string name of the character (e.g. "Plat")
	my ($self, $ip, $who) = @_;
	$who = lc($who);
	if ( ((time() - $self->[1]->{$ip}->[0]) < 600) && ($self->[1]->{$ip}->[1] ne $who)) {
		# make note to self
		$self->[0]->{$self->[1]->{$ip}->[1]}->{$who}++;
		$self->[0]->{$who}->{$self->[1]->{$ip}->[1]}++;
		&main::rock_shout(undef, sprintf("{3}#### %s\n", "{17}AltWatch: {13}$who = $self->[1]->{$ip}->[1]\{3}?"), 1);
		
		# try logging it in our altwatch table
		my $dbh = rockdb::db_get_conn();
		if ($dbh) {
			$dbh->do(<<END_SQL, undef, $ip, lc $who, lc $self->[1]->{$ip}->[1]);
INSERT INTO $main::db_name\.r2_altwatch
(ip, namea, nameb, ldate)
VALUES
(?, ?, ?, sysdate())
END_SQL
        }
	}
	
#	open(DUALCHARMON, ">>$main::base_code_dir/logonoff.txt");
#	printf DUALCHARMON "Login (%9d):  [%s]  %14s  %15s\n", time(), scalar localtime(time), $who, $ip;
#	close(DUALCHARMON);

	return(1);
}

sub on_logoff () {
    # Called when a player logs out of the game
    # $ip is the string IP address they were connected from
    # $who is the mixed-case string name of the character (e.g. "Plat")

    my ($self, $ip, $who) = @_;
    $who = lc($who);

    # identify last caller
    @{$self->[1]->{$ip}} = ( time, $who );

    # open(DUALCHARMON, ">>$main::base_code_dir/logonoff.txt");
    # printf DUALCHARMON "Logout(%9d):  [%s]  %14s  %15s\n", time(), scalar localtime(time), $who, $ip;
    # close(DUALCHARMON);
    return(1);
}


sub save {
    # merges current info into database and saves
    my $self = shift;
    my $dualchar = $self->[0];
    my $mergeto = $self->load();
    foreach my $i (keys(%{$dualchar})) {
        foreach my $j (keys(%{$dualchar->{$i}})) {
            $mergeto->{$i}->{$j} += $dualchar->{$i}->{$j};
        }
    }
    $self->hsave($mergeto);
    $self->[0] = {}; # reset suspicions, as they are saved now.
    return($mergeto);
}

sub scan {
  # merges current info into database and saves
  my ($self, $min, $cap, @temp) = @_;
  my $dualchar = $self->save();
  foreach my $i (keys(%{$dualchar})) {
    undef(@temp);
    foreach my $j (keys(%{$dualchar->{$i}})) {
      if($dualchar->{$i}->{$j} >= $min) { push(@temp, $j.' ('.$dualchar->{$i}->{$j}.' times)'); }
    }
    if(@temp) { $cap .= sprintf("%20s: %s.\n", $i, join(', ', @temp)); }
  }
  return($cap);
}

sub load {
     my ($dualchar, $cap, $subj, @a, $i, $lineLen);
     print "Loading DNK...\n";
     open (INF, 'dualnicks.dnk');
     binmode INF;
     while(!(eof INF)) {
         # file would have to be over 2 gigs to roll over :)
         read(INF, $lineLen, 4);
         read(INF, $cap, unpack('V', $lineLen));
         $subj = unpack('A20', substr($cap, 0, 20));
         $cap = substr($cap, 20);
         @a = unpack('A20V' x (int (length($cap)/24)), $cap);
         for($i=0; $i<$#a; $i+=2) {
             $dualchar->{$subj}->{$a[$i]}=$a[$i+1];
         }
     }
     close(INF);
     print "Finished Loading DNK...\n";
     return($dualchar);
}

sub hsave {
 my ($cap, $j, $printCap);
 my ($self, $dualchar) = @_;
 open (INF, '>dualnicks.dnk');
 binmode INF;
 foreach my $i (keys(%{$dualchar})) {
    $printCap = pack('A20', $i);
    foreach $j (keys(%{$dualchar->{$i}})) {
      next if (!$dualchar->{$i}->{$j});
      $printCap .= pack('A20L', $j, $dualchar->{$i}->{$j});
    }
    $printCap = pack('L', length($printCap)).$printCap;
    syswrite(INF, $printCap, length($printCap) );
 }
 close(INF);
 return($dualchar);
}

package multi_feedback;
use strict;
#class to make it easy to send a first person string and a third person string
#usage: 
# new_recip("%name %verb %his brick at %name2.", $attacker, $victim, "swing", "swings");
# ->get_for_sender(); # returns You swing your brick at Plat.
# ->get_for_recip(); # returns Mich swings his brick at you.
# ->get_for_room(); # returns Mich swings his brick at Plat.

sub new {
    my ($proto, $fmt, $sender, $verbp, $verbt) = @_;
    my $self = bless ([], $proto);
    $self->[0] = $fmt;
    $self->[0] =~ s/\%he/you/g;
    $self->[0] =~ s/\%his/your/g;
    $self->[0] =~ s/\%him/you/g;
    $self->[0] =~ s/\%name/you/g;
    $self->[0] =~ s/\%verb/$verbp/g;
    $self->[0] = ucfirst $self->[0];

    $self->[1] = $fmt;
    $self->[1] =~ s/\%he/$sender->{'PRO'}/g;
    $self->[1] =~ s/\%his/$sender->{'PPOS'}/g;
    $self->[1] =~ s/\%him/$sender->{'PPRO'}/g;
    $self->[1] =~ s/\%name/$sender->{'NAME'}/g;
    $self->[1] =~ s/\%verb/$verbt/g;

    return $self;
}



sub new_recip {
    my ($proto, $fmt, $sender, $recip, $verbp, $verbt) = @_;
	my $self = bless ([], $proto);

    $self->[0] = $fmt;
    $self->[0] =~ s/\%he2/$recip->{'PRO'}/g;
    $self->[0] =~ s/\%his2/$recip->{'PPOS'}/g;
    $self->[0] =~ s/\%him2/$recip->{'PPRO'}/g;
    $self->[0] =~ s/\%name2/$recip->{'NAME'}/g;
    $self->[0] =~ s/\%he/you/g;
    $self->[0] =~ s/\%his/your/g;
    $self->[0] =~ s/\%him/you/g;
    $self->[0] =~ s/\%name/you/g;
    $self->[0] =~ s/\%verb/$verbp/g;
    $self->[0] = ucfirst $self->[0];

    $self->[1] = $fmt;
    $self->[1] =~ s/\%he2/$recip->{'PRO'}/g;
    $self->[1] =~ s/\%his2/$recip->{'PPOS'}/g;
    $self->[1] =~ s/\%him2/$recip->{'PPRO'}/g;
    $self->[1] =~ s/\%name2/$recip->{'NAME'}/g;
    $self->[1] =~ s/\%he/$sender->{'PRO'}/g;
    $self->[1] =~ s/\%his/$sender->{'PPOS'}/g;
    $self->[1] =~ s/\%him/$sender->{'PPRO'}/g;
    $self->[1] =~ s/\%name/$sender->{'NAME'}/g;
    $self->[1] =~ s/\%verb/$verbt/g;

    $self->[2] = $fmt;
    $self->[2] =~ s/\%he2/you/g;
    $self->[2] =~ s/\%his2/your/g;
    $self->[2] =~ s/\%him2/you/g;
    $self->[2] =~ s/\%name2/you/g;
    $self->[2] =~ s/\%he/$recip->{'PRO'}/g;
    $self->[2] =~ s/\%his/$recip->{'PPOS'}/g;
    $self->[2] =~ s/\%him/$recip->{'PPRO'}/g;
    $self->[2] =~ s/\%name/$recip->{'NAME'}/g;
    $self->[2] =~ s/\%verb/$verbt/g;
    $self->[2] = ucfirst $self->[2];

    return $self;
}

sub get_for_sender { return $_[0]->[0]; }
sub get_for_recip { return $_[0]->[2]; }
sub get_for_room { return $_[0]->[1]; }


######
###### Censored/uncensored message obj
######
package censored_message;
use strict;

sub new {
    my ($proto, $msg, $owner) = @_;
	my $self = bless ([], $proto);
	$self->[0] = $owner; # 0 is owner
	$self->[1] = &main::text_filter_game($msg, $owner); # 1 is explicit
	$self->[2] = &main::text_filter_censor($self->[1], $owner); # 2 is censored!
	
	return $self;
}

sub new_prefiltered {
    my ($proto, $msg, $owner) = @_;
	my $self = bless ([], $proto);
	$self->[0] = $owner; # 0 is owner
	$self->[1] = $msg; # 1 is explicit
	$self->[2] = &main::text_filter_censor($self->[1], $owner); # 2 is censored!
	
	return $self;
}

sub get_censored { return $_[0]->[2]; }
sub get_explicit { return $_[0]->[1]; }
sub get_owner { return $_[0]->[0]; }
sub get_for { return !$_[1]->pref_get('censor filter')?$_[0]->[1]:$_[0]->[2]; }


######
###### Message Handler Module
######
package rock_message;
use strict;
use Dillfrog;
use Dillfrog::Mail;
use Dillfrog::Auth;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);

    return $self;
}

sub msgs_disp {
    my $self = shift;
    my ($cap);

    # should print all messages..er return as cap
    return($cap);
}

sub msg_count {
    my ($self, $uin) = @_;
    return 0 unless $uin;
    
    my $mail = Dillfrog::Mail->new();
    my $message_count = $mail->get_inbox_count_by_uin($uin);
    return $message_count;
}

sub msg_retrieve {
    my ($self, $uin) = @_;

    my $mail = Dillfrog::Mail->new();
    return $mail->get_inbox_oldest_message_by_uin($uin, { 'delete' => 1 });    
}

sub msgs_clear {
    my ($self, $uin) = @_;
    my $mail = Dillfrog::Mail->new();
    $mail->clear_all_inbox_messages_by_uin($uin);
    return;
}

sub msg_send {
    my ($self, $to, $msg, $from, $from_ip, $subject) = @_;
  
    # Normalize the recipient to a text name (not their player object)
    if(ref($to)) { $to = lc($to->{'NAME'}); }
  

    my $auth = Dillfrog::Auth->new();
    my $to_uin = $auth->getUIN(lc $to);
    unless ($to_uin) { return 0; }

    my $from_uin = (abs int $from) || undef;
  
    my $mail = Dillfrog::Mail->new();
    return 0 unless $mail->send_local_mail(
        from_trusted => 'Y',
        from_uin => $from_uin,
        from_label => $from,
        to_uin => $to_uin,
        body => $msg,
        subject => $subject,
        from_ip => $from_ip,
        transport_type => 'Rock 2',
    );

    ## *** Alert the player that they've got a new message! They'll like you more.
    if ($from =~ /Kaine De/) { # can you smell the hard code?
        if (my $objid = $main::activeuids->{$to}) {
            my $recip = &rockobj::obj_lookup($objid);
            $recip->log_append("{12}<<  You've received a new message! {2}Type 'msgs more' for more info. {12} >>\n");
        }
    }

    return 1;
}

######
###### Maintainance Module
######

# 
package rock_maint;
#@rock_maint::ISA = qw( rockobj );
use strict;
use Dillfrog;
use Dillfrog::Mail;
# idle_part: tells some objects in the game to idle. USES 'EACH'.
# idle_full: tells all objects in the game to idle.

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    # schedule events
    $self->{'IDLE'}=time;      $self->{'CLOBJS'}=time;
    $self->{'REMACTIVE'}=time; $self->{'SPAWN'}=time;
    $self->{'INVADE'}=time;
    $self->{'COMPRESS'}=time;  $self->{'CLROOMS'}=time;
    $self->{'@HIT'}=time;      $self->{'USAVE'}=time;
    $self->{'@SYNC'}=30;       $self->{'DUALCHAR'}=time;
    $self->{'COURSEAWARD'}=time; $self->{'PMANA'}=time;
    $self->{'GENVOTES'}=time;
    bless ($self, $class);
    return $self;
}
# $main::maint_friend->update();
# $main::maint_friend->idle_full();
# $main::maint_friend->{'@SYNC'}=40;
#&rock_shout(undef, "{2}:: {1}rokamaint{2} :: {17}Synching idlestart to $main::idlestart...\n", 1);

#use LWP::Simple;
#use LWP::Protocol::https;
#use LWP::UserAgent;
#use Math::Round qw(:all);
#use Math::BigInt;

sub update {
    my $self = shift;
    my $t = time;
    # partial idle
    print "Update Called!\n";
    $self->maint_part();
    if( ($t - $self->{'@HIT'}) < $self->{'@SYNC'} ) {
        $main::maintainstart -= 1;
        print "$main::maintainstart \n";
# This message can get annoying.. there's really no purpose to it. Actually
# I'm not a huge fan of the whole maintainstart idea anymore either.
# So at least let's quit blabbing about it to the admins
#        &main::rock_shout(undef, "{2}:: {1}rokamaint{2} :: {17}Synching maintainstart to $main::maintainstart.\n", 1);
    } elsif( ($t - $self->{'@HIT'}) > ($self->{'@SYNC'}+10) )
    {
      $main::maintainstart += 1;
      &main::rock_shout(undef, "{2}:: {1}rokamaint{2} :: {17}Synching maintainstart to $main::maintainstart.\n", 1);
      print "$main::maintainstart \n";
      
     }
    # if full idle scheduled, do it.
    if ($self->{'IDLE'}<$t) {
     $self->idle_full(); $self->{'IDLE'}= time + 10*60   * 12;
     print "IDLE\n";
     }
    # if rem_active_users scheduled, do it.
    if ($self->{'REMACTIVE'}<$t) {
     &main::rem_inactive_users; $self->{'REMACTIVE'}= time + 30;
     print "REMOVOE INACTIVE\n";
     }
    # if spawn scheduled, do it.
    if($self->{'SPAWN'}<$t) {
     &users_ahist_cleanup;
     &main::spawn_stuff;
     $self->{'SPAWN'}= time + 1.5*60;
     print "SPAWN\n";
     }
    # if user saving scheduled, do it.
    if($self->{'USAVE'}<$t) {
     $self->users_save;
     $self->{'USAVE'}= time + 14.3*60;
     print "SAVES\n";
     }
    # check for privacy invasion every 3 min
    if($self->{'INVADE'}<$t) {
     &rockobj::invade_privacy;
     &rockobj::adminstats_commit;
     $self->{'INVADE'}= time + 2*60;
     print "INVADE\n";
     }
    # compress descs
    if($self->{'COMPRESS'}<$t) {
     &main::compress_descs;
     $self->{'COMPRESS'}= time + 20*60;
     print "COMPRESS\n";
     }
    # cleanup rooms
    if($self->{'CLROOMS'}<$t) {
     &main::cleanup_rooms;
     $self->{'CLROOMS'}= time + 2*60;
     print "CLEAN ROOMS\n";
     }
    # cleanup rooms
    if($self->{'CLOBJS'}<$t) {
     &main::badobj_scan;
     &main::cleanup_objs();
     $self->{'CLOBJS'}= time + 5*60;
     print "CLEAN OBJS\n";
     }
    # dual chars
    if($self->{'DUALCHAR'}<$t) {
     $main::dual_friend->save();
     $self->{'DUALCHAR'}= time + 5.25*60;
     print "DAUL CHARS\n";
     }
    # courses
    if($self->{'COURSEAWARD'}<$t) {
     &courses_award();
     $self->{'COURSEAWARD'}= int( time + (int rand 10)+10 );
     print "COURSES\n";
     }
    # players' mana
    if($self->{'PMANA'}<$t) { 
		&rooms_uncrowd; 
		&mana_disperse(); 
		&vigor_disperse();
		$self->{'PMANA'}= int( time + (rand(1)+1.5)*60 );
  print "DISPERSAL\n";
	}
    # "general" votes
    if($self->{'GENVOTES'}<$t) { &ora_scores::ora_players_count; 
    &votes_tally(); 
    #&ora_scores::compile_all();
    $self->{'GENVOTES'}= int( time + (rand(10)+60)*60*3 );
    print "VOTAGE\n";
    } # every 3 hours or so

    
    if ($self->{'ARMAGEDDON'}<$t) {
     &rock_maint::update_armageddon_status();
     $self->{'ARMAGEDDON'} = int ($t + (rand(1)+1.5)*60);
     print "ARAMAGEDDON\n";
     }
    
    # &main::rock_flatten_realm;
    # clean up nullity
    #$main::map->[0]->cleanup_inactive;
    if(scalar %main::events) {
     &main::events_update;
     print "EVENTS\n";
     }
    
    # mark hit
    $self->{'@HIT'}=$t;
    print "$self->{'@HIT'}\n";
      
    # check for idled lag
    if((time - $t) > 10) { &main::mail_send($main::rock_admin_email, "R2: LAG!", "Maintenance lagged the game!\n"); }
    print "Update Returned!\n";
    return;
}

sub rooms_uncrowd {
   my $rcount=0;
   my @rooms_affected;
   for(my $i=0; $i<1; $i++) {
      foreach my $r (@{$main::map}) { 
	    next unless $r->{'ROOM'} > 1;
        my @pobjs = grep { !$_->{'SENT'} && $_->{'TYPE'}!=1 } $r->inv_pobjs; 
        if(@pobjs > 2) { 
#           foreach my $n ($r->inv_pobjs) { $n->on_idle(); }
 	       push @rooms_affected, $r->{'ROOM'};
		   $pobjs[int rand @pobjs]->on_idle();
		   $rcount++;
        }
      }
   }
   # &main::rock_shout(undef, "{17}$rcount TRT\n ", 1);# affected $rcount rooms (@rooms_affected).\n", 1);
}


#&rock_maint::update_armageddon_status();
sub update_armageddon_status {
    # WARNING: DON'T RETURN EARLY FROM THIS FUNC WITHOUT LETTING THE 'ARMAGEDDON IS POSSIBLE' VAR SET
    my $dbh = rockdb::db_get_conn();
    
    # TODO: delegate this to the $game_stats hash or something, and have it mirror out to the db so it's
    # instantatnaennanenousup
    $dbh->do("UPDATE $main::db_name\.r2_game_server_settings SET value=? WHERE name='armageddon_started_by_race'", undef, $main::rock_stats{'armageddon_started_by_race'});
    $dbh->do("UPDATE $main::db_name\.r2_game_server_settings SET value=? WHERE name='armageddon_is_possible'", undef, $main::rock_stats{'armageddon_is_possible'});
    
    my %monoliths_owned = rockdb::sql_select_mult_row_linear("select owned_by_race, COUNT(*) from $main::db_name\.r2_monolith_capture_status GROUP BY owned_by_race");
    
    
    # This used to be 12 when we wanted the game to end sooner :)
    my $capture_hours = 24;
    
    if (keys(%monoliths_owned) == 1) {
        # Ooh, someone owns all the 'liths
        # but did they hold control for 24 hours?
        my @partial_control_monoliths = rockdb::sql_select_mult_row_linear("select name from $main::db_name\.r2_monolith_capture_status where date_captured > DATE_ADD(sysdate(), INTERVAL -$capture_hours HOUR)");
        if (@partial_control_monoliths) {
            # The race doesn't have full control over all monoliths yet.  
        } else {
            my ($winning_race) = keys %monoliths_owned;
            if ($winning_race != 0) {
                # THE GAME IS READY TO BE WON
                if (!$main::rock_stats{'armageddon_is_possible'}) {
                    &main::rock_shout(undef, <<END_CAP);
{3}/---================================================---\
{3}(                {17}ARMAGEDDON IS NEAR                   {3}(
{3}\---================================================---/
{3}   >
{3}   >  {7}The {17}$main::races[$winning_race] {7}race has maintained 
{3}   >  {7}full and absolute control of the monoliths,
{3}   >  {7}giving them the power to change the world.
{3}   >
{3}   >  {7}Will they complete the spell that Ker'el couldn't?
{3}   >
{3}   >  {7}Will another race claim the monoliths as their own?
{3}   >
{3}/---================================================---\
{3}(  (   (   (   (   (   (   (   (   (   (   (   (   (   ( 
{3}\------------------------------------------------------/
END_CAP
                    $main::rock_stats{'armageddon_is_possible'} = $winning_race;
                }
                return;
            }
        }
    }

    $main::rock_stats{'armageddon_is_possible'} = 0;

}


sub dp_list {
 my $board = shift;
 $board ||= $main::rock_mdim{'dp_scores'} || []; # Pull it ourselves if they didn't apss it
 $main::dp_high = "{4}---------------------- {14}Top Dedication Points {4}====================-\n";
 for(my $i=0; $i<scalar(@{$board}); $i++) {
   $main::dp_high .= sprintf('{6}%2d{16}) %18s {7}({17}%6.1f{7})', $i+1, @{$board->[$i]});
   if(($i % 2) || $i == $#{$board}) { $main::dp_high .= "\n"; }
   else { $main::dp_high .= " {4}| "; }
 }
 $main::dp_high .= "{4}---------------------- {14}                      {4}====================-\n";
 return;
}

#&rock_maint::dp_add($_[0]); $main::dp_high
sub dp_add {
	my ($targ) = @_;
	
	# load board
	my $board = $main::rock_mdim{'dp_scores'} || [];

	return if $targ->{'ADMIN'};
	$targ = [$targ->{'NAME'}, $targ->dp_calc()];

	# check if already listed
	my $alreadyListed;

	for(my $i=0; $i<scalar(@{$board}); $i++) {
	   if($targ->[0] eq $board->[$i]->[0]) { 
    	   $alreadyListed = 1;
    	   $board->[$i] = $targ;
    	   last;
	   }
	}

	# if not listed, try adding
	unless ($alreadyListed) {
	   if( (scalar(@{$board}) < 20) ||
    	   ($targ->[1] > $board->[19]->[1])
    	 ) { push(@{$board}, $targ); }
	   else {
    	   return;
	   }
	}

	# sort listings
	@{$board} = sort byDP @{$board};

	# clip if too long
	splice @{$board}, 20;
	
	# save board
	$main::rock_mdim{'dp_scores'} = $board;

	# generate dp list
	&dp_list($board);

	return;
}

sub byDP { $b->[1] <=> $a->[1] };

 # scans all active classes and awards them learning points if applicable
  # room -> objid -> course name = ending time
sub courses_award {
 my $time = time;
 foreach my $room (keys(%main::course_log)) {
    foreach my $objid (keys(%{$main::course_log{$room}})) {
       if(!defined($main::objs->{$objid})) {
         delete $main::course_log{$room}->{$objid};
       } else { 
         if($main::objs->{$objid}->{'ROOM'} != $room) {
           delete $main::course_log{$room}->{$objid};
         } else {
            foreach my $cname (keys(%{$main::course_log{$room}->{$objid}})) {
               if($main::course_log{$room}->{$objid}->{$cname} <= $time) {
                   $main::objs->{$objid}->todaycourse_add($main::courses{$cname}->[0]);
                   $main::objs->{$objid}->course_update($cname);
                   delete $main::course_log{$room}->{$objid}->{$cname};
                   $main::objs->{$objid}->log_append("{17}The teacher mutters, \"{16}$cname class DISMISSED!{17}\"\n");
                   $main::objs->{$objid}->course_inv();
                   if(scalar(keys(%{$main::course_log{$room}->{$objid}})) == 0) { 
                      delete $main::course_log{$room}->{$objid};
                   }
               }
            }
         }
       }
    }
 }

}

sub users_ahist_cleanup {
 # saves all users currently logged in
 foreach my $p (values(%$main::activeuids)) {
    my $user = &main::obj_lookup($p);
    foreach my $oid (keys %{$user->{'A_HIST'}}) {
      if(!defined($main::objs->{$oid}) || $main::objs->{$oid}->{'ROOM'} != $user->{'ROOM'}) {
         delete $user->{'A_HIST'}->{$oid};
      } 
    }
 }
}


# clean activeuids
#foreach my $key (keys %{$main::activeuids}) { delete $main::activeuids{$key} unless $main::activeuids{$key}; }

sub users_save {
 # saves all users currently logged in
 foreach my $saveusr (values(%{$main::activeuids})) {
    print "Dumping $saveusr...\n";
    my $p = &main::obj_lookup($saveusr);
    $p->obj_dump() if $p;
 }
}


sub maint_part {
 my ($a, $b);
 for(my $n=0; $n<250; $n++) { 
     ($a, $b) = each(%{$main::objs});
     if(ref($b) ne uc(ref($b))){ 
        $b->on_idle;
        # make the item decay away if it's rotting
        if($b->{'ROT'} && (time > int($b->{'ROT'}))) { $b->rot; }
        # if store, cleanup
        $b->inv_cleanup;
        $b->on_cleanup; # let object do its own cleanup thang.
        # delete keys w/ undefined values
        foreach $a (keys(%{$b})) { 
          if("$b->{$a}" eq '') {  delete $b->{$a}; }
        } 
     } elsif($a) {
        print "RockMaint ERROR!! main::objs key $a does not have a blessed value.\n";
        &main::rock_shout(undef, "{11}RockMaint ERROR!! main::objs key $a does not have a blessed value.\n", 1);
        delete $main::objs->{$a};
     }
 }
}

sub idle_full {
   &main::rock_shout(undef, "{2}:: {1}rokamaint{2} :: {17}Executing Full Idle...\n", 1);
   ### WEIRD
   foreach my $o (values %$main::objs) {  
       next unless $o;
       if ($o->{'ROT'}  &&  time > int $o->{'ROT'}) { $o->rot; }
       else {   
           eval {
               $o->on_idle;
           };
           &main::rock_shout(undef, "{1}########\n####### Error idling object $o: $@\n#######\n", 1) if($@);
       }
   }
}

sub mana_disperse {
  # mana
  my $dam;
  foreach my $uid (values(%{$main::activeuids})) {
    my $self = $main::objs->{$uid};
    if($self->{'MA'} >= $self->{'MAXM'}){$self->on_idle(); } 
    next if ($self->{'MA'} == $self->{'MAXM'});
    
    $dam = int (((rand($self->{'MAXM'}/4))+($self->{'MAXM'}/10)));
    $dam = 1 if $dam <= 0;

    $self->log_append("{14}You gain some of your mana back.\n");

    # Bonuses
    my $i;
    if(($i = $self->inv_rec_scan(418)) && $i->{'EQD'}) { $dam *= 2; } # zeode staff
    # /Bonuses
    
    if(($self->{'MA'} + $dam) > $self->{'MAXM'}) { $dam = $self->{'MAXM'}-$self->{'MA'}; }
    $self->{'MA'} += $dam;
  	
    }
	

}

sub vigor_disperse {
  # mana
  my $dam;
  foreach my $uid (values(%{$main::activeuids})) {
    my $self = $main::objs->{$uid};
    if($self->{'VIGOR'} >= 1.2){$self->on_idle(); } 
    next if ($self->{'VIGOR'} >= 1);
    
    $dam = rand(rand(1.5))/2;

    $self->log_append("{11}You gain some of your vigor back.\n");

    # Bonuses
    #my $i;
    #if(($i = $self->inv_rec_scan(418)) && $i->{'EQD'}) { $dam *= 2; } # zeode staff
    # /Bonuses
    
    if(($self->{'VIGOR'} + $dam) > 1.5) { $dam = 1.5-$self->{'VIGOR'}; }
    $self->{'VIGOR'} += $dam;
  	
    }
	

}

# %main::general_votes = (); &rock_maint::votes_tally();
# evalll my @dude = %main::general_votes; "@dude"
# evalll map { my $val = "$main::general_votes{$_}"; $_[0]->log_append("Val [$val]\n"); if ($val eq "hongkong") { $_[0]->log_append("\"Dlete!\n"); $main::general_votes{$_} = undef; } } keys %main::general_votes;
#evalll %main::general_votes = qw(kitzue kitzue azur azur juggernaut maulgher baonguyen maulgher akinoth icarus poohbear maulgher coldeath icarus hydro maulgher logic icarus telemro icarus phaderus fear mister fear destroyer3 andruin99 ravendeath fear ronin fear joejoe fear daruka icarus nede icarus astroblack destroyer3 implasticruler andruin99 indon zeus disturbed zeus goldengear disturbed tekki icarus foamer icarus flyer maulgher thugline maulgher wisepoet maulgher keghorn maulgher pyrex maulgher esmarelda zeus nectum nectum trite nectum snoopyrule nectum trouser nectum fear fear manniefresh fear metaltiger fear grndillfrog fear ybjealous andruin99 boggyman nectum lyndin nectum bettyboop andruin99 ohno fear uhoh fear mandorallen andruin99 andruin99 andruin99 livak andruin99 noone andruin99 scaryguy andruin99 tharkun fear bigbob andruin99 grockto destroyer3 slave destroyer3 maulgher icarus toxic maulgher darkxacid darkxacid ares maulgher infection kitzue escobar destroyer3 khorton fear newstorage fear neptune maulgher lordvenant kitzue kaitoukage maulgher nettles maulgher kodiak icarus headbasher icarus baron69 andruin99 madbomber fear slotplaya fear halflunatic fear hawkens fear default andruin99 alakayonk icarus warknight destroyer3 vlar dwollen dwollen dwollen hades destroyer3 kuruption zeus disciple zeus traveller maulgher demineo zeus killa maulgher ishan zeus zeus zeus lowball zeus apexi zeus hardhitter hardhitter gwenyvar nectum whitacre nectum vindris nectum volqar fear xavier fear layla fear jackle23 fear blackheart andruin99 nariva andruin99 cola fear storage zeus thecook nectum cyborman maulgher);



sub votes_tally {
  my $debug;
  %main::votee = ();
  foreach my $v (values(%main::general_votes)) {
     $main::votee{$v}++;
  }
  my @generals;
  my $col=0;
  my $scans=0;
  $main::votage_cap = "{13}Last Votage Count was as follows:\n";
  foreach my $v (sort by_votes(keys(%main::votee))) {
    
    my ($race, $name) = unpack('LA*', $v);
    if(!$generals[$race]) { $generals[$race]=$name; $debug .= "     {16}$name: {6}$main::votee{$v} {7}votes\n"; }
    if($scans<10) { 
        $main::votage_cap .= sprintf('{%d}%15s: {17}%3d. ', $race, substr($name,0,15), $main::votee{$v}); $col++;
        if($col==3) { $col=0; $scans++; $main::votage_cap .= "\n"; }
    }
  }
  if($col!=0) { $main::votage_cap .= "\n"; }
  
  my $changed = '';
  my $max = 6;
  if($#generals > 6 ) { $max = $#generals; }
  for (my $v=0; $v<=$max; $v++) {
    my $txt = ($generals[$v] || '-none-');
    if($main::rock_stats{'s-genrl_race-'.$v} ne $txt) { $main::rock_stats{'s-genrl_race-'.$v}=$txt; $changed=1; }
  }
  undef(%main::votee);
  &main::rock_shout(undef, "{1}RockMaint: {2}Votage yields: \n$debug", 1);
  
  $main::genvotes_handle->sync(); # sync to disk
  $main::rockstats_handle->sync();
  
  if($changed) { &main::rock_shout(undef, "{17}Votes for Racial Generals have been tallied and updated - and {1}power has changed hands{17}. Type {7}gamestat{17} for more info, and {7}votage{17} for the breakdown.\n"); }
  else { &main::rock_shout(undef, "{17}Votes for Racial Generals have been tallied. Power didn't change hands, but you can still type {7}votage{17} for the breakdown.\n"); }
}

sub by_votes { $main::votee{$b} <=> $main::votee{$a} }
# evalll &rock_maint::auction_reimburse();


sub auction_reimburse() {

    my $dbh = rockdb::db_get_conn();

	my $auctions = rockdb::sql_select_mult_row(<<END_SQL);
SELECT auction_id, high_bid, high_bid_uin, item_name, SELLER.member_name, SELLER.id_member
FROM $main::db_name\.r2_auctions A, $main::db_name\.r2_members SELLER
WHERE end_date < sysdate()
   AND returned_cryl = 'N'
   AND SELLER.id_member = A.seller_uin
END_SQL
    
	return unless $auctions;
	
    # foreach auction that's finished
    foreach my $auction (@$auctions) {
	    my $bidders = rockdb::sql_select_mult_row(<<END_SQL, $auction->[0]);
SELECT B.bid_id, B.max_bid, B.bidder_uin, A.member_name 
FROM $main::db_name\.r2_auction_bids B, $main::db_name\.r2_members A
WHERE auction_id = ?
    AND B.bidder_uin = A.id_member
END_SQL

		my $high_bid = $auction->[1];
		my $seller_uid = $auction->[4];
		my $winner_uin = $auction->[2];
		my $seller_uin = $auction->[5];

		my $winner_name = $winner_uin ? ucfirst((rockdb::sql_select_row("SELECT member_name FROM $main::db_name\.r2_members WHERE id_member=?", $winner_uin))[0])
		                  : undef;
		
		

	
		# foreach bidder of that auction
		foreach my $bidder (@$bidders) {
			my $money_back = 0;
			my $bidder_name = lc $bidder->[3];
			my $msg;
			if ($auction->[2] == $bidder->[2]) {
  		        # if they won, give them back all but their bid money
			    $money_back = $bidder->[1] - $auction->[1]; # max bid - high bid
			    $msg = "Hey, congratulations on winning that $auction->[3] we auctioned off. Come on back and 'claim' it!";
				$msg .= "\n\nOh, and since the autobidding didn't suck up all your cash, I've put the remaining $money_back cryl in your bank account down here.";
			} else {
		        # if they didn't win, give them all their money back
			    $money_back = $bidder->[1]; # all of max bid
			    $msg = "Sorry you didn't win the $auction->[3] - maybe next time, eh? I mean, it's not like \"$winner_name\" can bid on ALL of them! All $money_back of your cryl is back in my bank.. all nice and safe!";
			}
			
			
			my $msgtime = time;
			my $subject = "R2 Item Auction Completed";
			$dbh->do(<<END_SQL,undef,$seller_uin,$seller_uid,$msgtime,$subject,$msg);
INSERT INTO $main::db_name\.r2_personal_messages
(id_member_from, deleted_by_sender, from_name, msgtime, subject, body)
VALUES
(?,1,?,?,?,?)
END_SQL

			
			my $pm_id = rockdb::sql_select_row("SELECT id_pm FROM $main::db_name\.r2_personal_messages ORDER BY id_pm DESC LIMIT 1");
			
			
			$dbh->do(<<END_SQL,undef,$pm_id,$winner_uin);
INSERT INTO $main::db_name\.r2_pm_recipients
(id_pm, id_member, labels, bcc, is_read, is_new, deleted)
VALUES
(?,?,-1,0,0,1,0)
END_SQL
			
            #$main::msg_friend->msg_send($bidder_name, "$msg", 'Kaine DeBanker', undef, 'R2 Item Auction Completed' . ($auction->[2] == $bidder->[2] ? '; ** YOU WON **' : ''));
			
			
			$dbh->do(<<END_SQL, undef, $bidder_name, $money_back);
INSERT INTO $main::db_name\.r2_rock_certs
(name, c_type, c_val)
VALUES
(?, 'K', ?)
END_SQL

		    &main::rock_shout(undef, "{7}Gave $money_back cryl back to $bidder_name for auction $auction->[0] on $auction->[3].\n", 1);
			
            if( my $recip = &getObjByPlayerName($bidder_name)) {
                $recip->obj_dump;
            }
		}
		
		# the seller should be given money too
		if ($winner_name) {
			my $money_back = int($high_bid * .90);
        	my $msg = "$seller_uid, $winner_name won the auction of your $auction->[3], with a high bid of $high_bid. I've kept a 10% transaction fee, and your $money_back cryl is in your account at my bank.";
        	#$main::msg_friend->msg_send($seller_uid, "\"$winner_name\" won the auction of your $auction->[3], with a high bid of $high_bid. I've kept a 10% transaction fee, and your $money_back cryl is in your account at my bank.", 'Kaine DeBanker', undef, 'R2 Item Auction Completed');
        	#####
			my $msgtime = time;
			my $subject = "R2 Item Auction Completed";
			$dbh->do(<<END_SQL,undef,1,"rockserv",$msgtime,$subject,$msg);
INSERT INTO $main::db_name\.r2_personal_messages
(id_member_from, deleted_by_sender, from_name, msgtime, subject, body)
VALUES
(?,1,?,?,?,?)
END_SQL

			
			my $pm_id = rockdb::sql_select_row("SELECT id_pm FROM $main::db_name\.r2_personal_messages ORDER BY id_pm DESC LIMIT 1");
			
			
			$dbh->do(<<END_SQL,undef,$pm_id,$seller_uin);
INSERT INTO $main::db_name\.r2_pm_recipients
(id_pm, id_member, labels, bcc, is_read, is_new, deleted)
VALUES
(?,?,-1,0,0,1,0)
END_SQL
			
			#####
			&main::rock_talkshout($_[0], "{14}$winner_name {16}won the auction of {12}$auction->[3], {16}with a high bid of {13}$high_bid.\n");
        	$dbh->do(<<END_SQL, undef, $seller_uid, $money_back);
INSERT INTO $main::db_name\.r2_rock_certs
(name, c_type, c_val)
VALUES
(?, 'K', ?)
END_SQL
		&main::rock_shout(undef, "{7}Gave $money_back cryl back to SELLER $seller_uid for auction $auction->[0] on $auction->[3].\n", 1);
            if( my $recip = &getObjByPlayerName($seller_uid)) {
                $recip->obj_dump;
            }
		} else {
        	#$main::msg_friend->msg_send($seller_uid, "I see nobody bid on the $auction->[3] you tried auctioning off. It's still here.. just come and claim it back, I guess.", 'Kaine DeBanker', undef, 'R2 Item Auction Ended; No Bidders');
        	my $msg = "$seller_uid, I see nobody bid on the $auction->[3] you tried auctioning off. It's still here.. just come and claim it back, I guess.";
			######
			my $msgtime = time;
			my $subject = "R2 Item Auction Completed";
			$dbh->do(<<END_SQL,undef,1,"rockserv",$msgtime,$subject,$msg);
INSERT INTO $main::db_name\.r2_personal_messages
(id_member_from, deleted_by_sender, from_name, msgtime, subject, body)
VALUES
(?,1,?,?,?,?)
END_SQL

			
			my $pm_id = rockdb::sql_select_row("SELECT id_pm FROM $main::db_name\.r2_personal_messages ORDER BY id_pm DESC LIMIT 1");
			
			
			$dbh->do(<<END_SQL,undef,$pm_id,$seller_uin);
INSERT INTO $main::db_name\.r2_pm_recipients
(id_pm, id_member, labels, bcc, is_read, is_new, deleted)
VALUES
(?,?,-1,0,0,1,0)
END_SQL
			
			
			
			######
			
			
		&main::rock_shout(undef, "{7}Nobody wanted $seller_uid\'s $auction->[3] in auction $auction->[0] (letting them re-claim).\n", 1);
		&main::rock_talkshout($_[0], "{7}Nobody wanted $seller_uid\'s $auction->[3].\n");
		}
		
		# okay they got their moneys back..don't do it again :)
		$dbh->do(<<END_SQL, undef, $auction->[0]);
UPDATE $main::db_name\.r2_auctions
SET returned_cryl = 'Y'
WHERE auction_id = ?
END_SQL
#		$dbh->do(<<END_SQL, undef, $auction->[0]);
#DELETE FROM $main::db_name\.r2_auction_bids
#WHERE auction_id = ?
#END_SQL
		
	}
	
	# and check again in another minute!
    $main::eventman->enqueue(60, \&rock_maint::auction_reimburse);
}

sub getObjByPlayerName {
    my $playername = shift;

    return undef unless defined $main::activeuids->{$playername};
	return &rockobj::obj_lookup($main::activeuids->{$playername});
}

sub Dillfrog_WritePlayerList {
    # list all players
    my $onlineplayers = 0;
	my $txtout = '';
	my %races;
    foreach my $player (sort keys(%{$main::activeuids})) {
       $player = &main::obj_lookup($main::activeuids->{$player});
       next if($player->{'SOCINVIS'} || ((time - $player->{'@LCTI'}) > 60 ) );
	   next unless $main::races[$player->{'RACE'}];
	   $races{$main::races[$player->{'RACE'}]} ||= [];
	   push @{$races{$main::races[$player->{'RACE'}]}}, HTMLEncode($player->{'NAME'});
	   $onlineplayers++;
    }

    foreach my $race (sort keys(%races)) {
      $txtout .= sprintf <<END_HTML, HTMLEncode($race), join(', ', sort @{$races{$race}});
<tr valign="top">
    <td class="channelName" width="30">%s</td>
	<td class="playerList">
    %s.
	</td>
</tr>
END_HTML
	}

    open F, ">/var/www/html/games/rs2/currplayers.shtml"
	    or  die "Could not open currplayer file: $!";
	my $frogs = $onlineplayers == 1 ? "frog is" : "frogs are";
    print F <<END_CAP;
<tr valign="top">
    <td colspan="2" align="center" class="title"><b>$onlineplayers</b> $frogs playing <a href="/games/rs2/">Rock II</a>.
	</td>
</tr>
END_CAP
	print F $txtout;
	close F;

    $main::eventman->enqueue(60, \&rock_maint::Dillfrog_WritePlayerList);

}



#&rock_maint::votes_tally();
#&rock_maint::auction_reimburse();




1;
