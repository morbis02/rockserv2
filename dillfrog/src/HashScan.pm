package OBJSHashScan;
use Tie::Hash;
use strict;

@OBJSHashScan::ISA = qw(Tie::StdHash);

sub DELETE {
    my ($self, $key) = @_;
#    my $val = $self->FETCH($key);
#    
#    if (defined $val) {
#        # They deleted something legitimate. 
#        &main::rock_shout(undef, "{1}main::objs, DELETE $val in key $key.\n", 1)
#            if defined $val;
#        
#        # Remove it from our array flavor of main::objs (linear, expensive)
#        my $deleted_it = 0;
#        for (my $i=0; $i<@main::objs; ++$i) {
#            if ($main::objs[$i] eq $val) {
#                # found it, so trash it
#                splice(@main::objs, $i, 1);
#                $deleted_it = 1;
#                last;
#                # evalll @main::objs = values %$main::objs
#                # evalll @main::objs = ();
#            }
#        }
#        
#        # we couldnt find it in our magic list, so complain
#        &main::rock_shout(undef, "{1}Tried DELETEing object of key $key (val $val) from \@main::objs, but could not find it.\n", 1) unless $deleted_it;
#
#    }
#    
    return Tie::StdHash::DELETE(@_);
}

sub STORE {
    my ($self, $key, $val) = @_;
    
#    unless (defined $self->FETCH($key)) {
#        # Add value to our array flavor, to keep it in synch
##        &main::rock_shout(undef, "{1}main::objs, STORE $val in key $key.\n", 1);
#        push @main::objs, $val;
#    }
    
    my $r = ref($val);
    if($r eq uc($r)  ||  $key =~ /=/ || !$val->{'CONTAINEDBY'} && $val->{'TYPE'}>=0 && !$val->{'DONTDIE'}) {
        my $c=0;
        my @a;

        my $cap = "";
		while(@a = caller($c)) {
            last if "@a" =~ /new/;
			$cap .= "@a\n";
            $c++;
        }
        &main::rock_shout(undef, "{11}#########################################\n{17}Bad OBJS store of $key   =>   $val\n$cap\{11}#########################################\n", 1);       
		&main::mail_send($main::rock_admin_email, "- rockserv - HELP ME - HASHSCAN!!", "OBJSHashScan;\n\nBad OBJS store of $key   =>   $val\n$cap\n");
		
		return; # don't do anything
    }
    return Tie::StdHash::STORE(@_);
}


package AUIDSHashScan;
use Tie::Hash;
use strict;

@AUIDSHashScan::ISA = qw(Tie::StdHash);

sub STORE {
    my ($self, $key, $val) = @_;
    my $r = ref($val);
    if($val ne int($val) || $key =~ /=/) {
        # WIG OUT!
        my $c=0;
        my @a;
        &main::rock_shout(undef, "{1}### AUIDSHashScan DETECTED AN ERROR!! (save or die!) ###\n");
        print "######### Bad Insert (Key: $key. Value: $val) #####\n";
        while( @a = caller($c)) { print "    Trace $c: @a\n"; $c++; }
    }
    return Tie::StdHash::STORE(@_);
}

# evalll tie %{$_[0]}, 'playerHashScan'

package playerHashScan;
use Tie::Hash;
use strict;
use Carp;

@playerHashScan::ISA = qw(Tie::StdHash);

##
## TO use this with the game, SVS SHOULD_HASHSCAN 1
## ... and then re-login to the game. Turning it off is
## as easy as SVS SHOULD_HASHSCAN
## Don't use this unless you know what you're doing (talk to plat
## please, or else things might suck, especially before doing this
## to a player or other object).
##

sub STORE {
    my ($self, $key, $val) = @_;
#	print "STORE: @_\n";
	if ($key eq 'CRYL' && $self->FETCH('DEBUG_CRYL')  ||
#	    $key eq 'CONTAINEDBY' && 
        ($key eq 'EXPMEN' || $key eq 'EXPPHY') && $self->FETCH('DEBUG_EXP')  
	) {
	    my $old_val = $self->FETCH($key);
		eval { confess; };
		my $traceback = $@;
		$traceback =~ s/^.+?\n.+?\n//s;
		$traceback =~ s/^\s+//mg;
        &main::rock_shout(undef, "{12}---- {7}$self->{'NAME'}\'s {17}$key {7}set from \"{17}$old_val\{7}\" to \"{17}$val\{7}\"\n{2}$traceback\{12}----\n", 1)
		    unless $key eq 'LOG'; # avoid recursion here ;-)
		
	}
    return Tie::StdHash::STORE(@_);
}

sub FETCH {
    my ($self, $key) = @_;
#	print "FETCH KEY [@_]\n";
	return Tie::StdHash::FETCH(@_);
}

sub TIEHASH {
    my ($proto, $player_obj) = @_;
	print "TIEHASH: @_ PLAYER OBJECT IS FUCKING $player_obj\n";
	return bless {PLAYER => $player_obj}, $proto;
}

1;
