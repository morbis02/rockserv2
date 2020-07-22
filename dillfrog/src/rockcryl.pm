use strict;
1;

package rockobj;
use strict;

# mich made this to centralize the "some" vs "amount" stuff
sub cryl_obfuscate {
    my ($self, $amt) = @_;
    if ( rand(($self->pct_skill(7)+$self->pct_skill(15))/2) > rand(100) ) {
        return $amt;
    }
    return "some";
}

sub cryl_get (amount [, from_object ]){
    # picks [amount] cryl off the floor.
    my ($self, $amt, $from) = @_;
    $from = $main::objs->{$self->{'CONTAINEDBY'}} unless $from;
    $amt = int abs($amt);
    if(!$amt) { 
        $amt=$from->{'CRYL'};
        if(!$amt) {
            $self->log_error("There aren't any cryl to loot!");
            return 0;
        }
    }

    if($from->{'CRYL'} < $amt) {
        $self->log_error("There aren't $amt cryl there!");
        return 0;
    }

    return 0 if(!$self->can_do(0,0,3));

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{13}$self->{'NAME'} picks {3}$samt {13}cryl off the ground.\n");

    $self->log_append("{13}You pick up {3}$amt {13}cryl.\n");
    $self->{'CRYL'} += $amt;
    $from->{'CRYL'} -= $amt;
    
    $self->log_suspicious_activity("Got significant cryl within 60 seconds of logging in.")
    if  $self->{'TYPE'} == 1 && $amt > 300 && (time - $self->get_login_time()) < 60;
 
    return 1;
}

sub cryl_drop (amount [, to_object ]){
    # picks [amount] cryl off the floor.
    my ($self, $amt, $to) = @_;
    $to = $main::objs->{$self->{'CONTAINEDBY'}} unless $to;
    $amt = int abs($amt);
    if(!$amt) { 
        $amt = $self->{'CRYL'};
        if(!$amt) {
            $self->log_append("{3}You don't have any cryl to drop!");
            return 0;
        }
    }
    if($self->{'CRYL'} < $amt) {
        $self->log_error("You only wish you had $amt cryl!");
        return 0;
    }

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{13}$self->{'NAME'} drops {3}$samt {13}cryl.\n");

    $self->log_append("{13}You drop {3}$amt {13}cryl.\n");
    $self->{'CRYL'} -= $amt;
    $to->{'CRYL'} += $amt;
    $main::map->[$self->{'ROOM'}]->tell(13, 1, 0, undef, $self, $amt);
    
    if($self->{'TYPE'} == 1) {
        $self->{'LASTDROP'} = time;
    }
 
    return 1;
}

sub on_cryl_dropped { }

sub cryl_give {
    my ($self, $amt, $to) = @_;
    if($self eq $to) {
        $self->log_append("{3}Now why would you want to give cryl to yourself?\n");
        return 0;
    }

    $amt = int abs($amt);
    if(!$amt) {
        $amt = $self->{'CRYL'};
        if(!$amt) {
            $self->log_error("You don't have any cryl to give!");
            return;
        }
    }
    if($self->{'CRYL'} < $amt) {
        $self->log_error("You only wish you had $amt cryl!");
        return 0;
    }

    return 0 if(!$self->can_do(0,0,2));

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{7}$self->{'NAME'} {3}hands $samt cryl to {7}$to->{'NAME'}.\n", $to);

	my $afar_clause = $self->{'ROOM'}==$to->{'ROOM'}?"":" from afar";

    $self->log_append("{3}You hand {13}$amt {3}cryl to $to->{'NAME'}$afar_clause.\n");
    $to->log_append("{3}$self->{'NAME'} hands you {13}$amt {3}cryl$afar_clause.\n");

	# Log it before it happens (we might lose some objects) if we can.
    &main::log_event("Give Cryl", "$self->{'NAME'} gave $amt cryl to $to->{'NAME'}.", $self->{'UIN'}, $to->{'UIN'}, undef, $amt) if $self->{'UIN'} && $to->{'UIN'};

    # actually handle it
    $self->{'CRYL'} -= $amt;
    $to->{'CRYL'} += $amt;  
    $to->on_cryl_receive($amt, $self);

    # suspicious activity log
    $self->{'LASTGIVE'} = time if $self->{'TYPE'} == 1;
    $to->{'LASTRECEIVE'} = time if $to->{'TYPE'} == 1;
    $self->log_suspicious_activity("Gave significant cryl within 60 seconds of logging in.")
    if  $self->{'TYPE'} == 1 && $amt > 200 && (time - $self->get_login_time()) < 60;
    
    $to->log_suspicious_activity("Received significant cryl within 60 seconds of logging in.")
    if  $to->{'TYPE'} == 1 && $amt > 200 && (time - $to->get_login_time()) < 60;

    return 1;
}

sub cryl_put {
    my ($self, $amt, $to) = @_;
    $amt = int abs($amt);
    if(!$amt) { 
        $amt = $self->{'CRYL'};
        if(!$amt) {
            $self->log_error("You don't have any cryl to place!");
            return 0;
        }
    }

    if($self->{'CRYL'} < $amt) {
        $self->log_error("You only wish you had $amt cryl!");
        return 0
    }

    if(!$to->{'CONTAINER'}) {
        $self->log_error("There is no way for you to put anything into $to->{'NAME'}.");
        return 0;
    }

    return 0 if(!$self->can_do(0,0,4));

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{7}$self->{'NAME'} {3}puts $samt cryl into {7}$to->{'NAME'}.\n", $to);

    $self->log_append("{7}You put {13}$amt cryl {7}into{3} $to->{'NAME'}\{7\}.\n");
    $to->log_append("{3}$self->{'NAME'} {7}puts {13}$amt cryl {7}inside you.\n");

    # actually handle it
    $self->{'CRYL'} -= $amt; $to->{'CRYL'} += $amt;  
    $to->on_cryl_receive($amt, $self);

    return 1;
}

sub cryl_withdraw (amount){
    my ($self, $amt) = @_;
    if (!$main::map->[$self->{'ROOM'}]->{'BANK'}) {
        $self->log_error("You must be in a bank in order to withdraw cryl.");
        return 0;
    }
    $amt = int abs($amt);
    if(!$amt) { 
        $amt = $self->{'B-' . uc($main::map->[$self->{'ROOM'}]->{'BANK'})};
        if(!$amt) {
            $self->log_error("You have no money in your account!");
            return 0;
        }
    }
    if($self->{'B-' . uc($main::map->[$self->{'ROOM'}]->{'BANK'})} < $amt) {
        $self->log_error("There aren't $amt cryl in your account!");
        return 0;
    }
    return 0 if ( ($self->{'TYPE'} == 1) && (!$self->can_do(0,0,2)) );

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{14}$self->{'NAME'} withdraws {3}$samt {14}cryl.\n");

    $self->log_append("{14}You withdraw {3}$amt {14}cryl.\n");
    $self->{'CRYL'} += $amt;
    $self->{'B-' . uc($main::map->[$self->{'ROOM'}]->{'BANK'})} -= $amt;

    return 1;
}

sub cryl_deposit (amount){
    my ($self, $amt) = @_;
    if (!$main::map->[$self->{'ROOM'}]->{'BANK'}) {
        $self->log_error("You must be in a bank in order to deposit cryl.");
        return 0;
    }
    $amt = int abs($amt);
    if(!$amt) { 
        $amt = $self->{'CRYL'};
        if(!$amt) {
            $self->log_error("You don't have any cryl to deposit!");
            return 0;
        }
    }
    if($self->{'CRYL'} < $amt) {
        # i almost didn't have the heart to change this to an error
        #$self->log_append("{14}You only {13}wish{14} you had $amt cryl!\n");
        $self->log_error("You only wish you had $amt cryl!");
        return 0;
    }

    return 0 if(($self->{'TYPE'} == 1) && (!$self->can_do(0,0,2)));

    my $samt = $self->cryl_obfuscate($amt);
    $self->room_sighttell("{14}$self->{'NAME'} deposits {3}$samt {14}cryl.\n");

    $self->log_append("{14}You deposit {3}$amt {14}cryl.\n");
    $self->{'CRYL'} -= $amt;
    $self->{'B-' . uc($main::map->[$self->{'ROOM'}]->{'BANK'})} += $amt;



    return 1;
}

sub cryl_account {
    my ($self, $amt) = @_;
#    if ($main::map->[$self->{'ROOM'}]->{'BANK'}) {
#    	$amt = int $self->{'B-' . uc($main::map->[$self->{'ROOM'}]->{'BANK'})};
#    	if(!$amt) {
#        	$self->log_append("{14}You don't have any cryl deposited in this bank.\n");
#    	}
#    	else {
#        	$self->log_append("{14}You have {13}$amt {14}cryl deposited in this bank.\n");
#    	}
#    }
    $self->cryl_account_global;

    return;  
}

sub cryl_account_global {
    my ($self) = @_;
    my ($key, $temp, $cap);
    foreach $key (keys(%{$self})) {
        if(index($key, 'B-') == 0) {
            next if(!$self->{$key});
            $temp = lc(substr($key,2));
            $cap .= "    {6}$temp: {13}$self->{$key}";
			$cap .= "    {16}<--- You are here." if lc($main::map->[$self->{'ROOM'}]->{'BANK'}) eq $temp;
			$cap .= "\n";
        }
    }
    if(!$cap) {
        $self->log_append("{14}You don't have any cryl deposited. Anywhere.\n");
    }
    else {
        $self->log_append("{17}Banks currently holding your deposit:\n" . $cap);
    }
    return;  
}

sub cryl_autoloot {
    my ($self, $n) = @_;
    if($self->{'GIFT'}->{'CRYL'} < 40) {
        $self->log_error("You are not skilled enough in cryl management to do so.");
        return 0;
    }
    $n = int $n;
    if($n<=0) {
        $self->log_append("{6}AutoLoot turned off.\n");
        delete $self->{'ALOOT'};
    }
    else {
        $self->log_append("{6}AutoLoot turned on: minimum of {13}$n {6}cryl.\n");
        $self->{'ALOOT'} = $n;
    }
    return 1;
}
