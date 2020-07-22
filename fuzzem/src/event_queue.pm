package event_queue;
use strict;

sub new {
    my $proto = shift;
    my $self = { };
    bless ($self, $proto);
    
    $self->{'ETIME'} = time - 1;
    $self->{'EVENTS'} = { };
    
    return $self;
}

sub toString() {
    # returns a color-coded string listing events and the times they
	# go super-crazy
	my $self = shift;
	
	my $cap = '';
	
	foreach my $etime (sort keys %{$self->{'EVENTS'}}) {
	    $cap .= "{12}" . localtime($etime) . "{2}\n";
		foreach my $arglist (@{$self->{'EVENTS'}->{$etime}}) {
		    my (undef, @args) = map {
			    my $ostr = $_;
				if (ref($ostr) eq 'objid') { $ostr = $ostr->toString(); }
				elsif ($ostr eq \&rockobj::item_spawn) { $ostr = "CODE=rockobj::item_spawn"; }
				
				$ostr
			} @$arglist;
		    $cap .= join(', ', @args)."\n";
		}
	}
	
	return $cap;
}

sub enqueue {
    my ($self, $delay, @args) = @_;
    # 0: funct ref
    # 1+: Real_args
    my $time = time;
    if(!$self->{$time}) { $self->{$time} = [ ]; }
    for(my $i=0; $i<@args; $i++) {
       $args[$i] = objid->new($args[$i]); # will only be an objid if applicable
    }
    ### DEBUG
    my @a = caller(1);
    unshift(@args, "@a");
    ######
    push(@{$self->{'EVENTS'}->{$time+abs int$delay}}, \@args);
    #&main::rock_shout(undef, "{2}#### {1}ENQUEUED with delay $delay.\n", 1);
}

sub catchup {
    my $self = shift;
    
    use integer;
    my $beginTime = time;
    while ($self->{'ETIME'} < $beginTime) {
        while (defined($self->{'EVENTS'}->{$self->{'ETIME'}})) { 
             my $elist = delete $self->{'EVENTS'}->{$self->{'ETIME'}};
             foreach my $event (@$elist) {
                 eval {
                   my $calledBy = shift(@{$event});
                   for (my $i=1; $i<@$event; $i++) {
                     if(ref($event->[$i]) eq 'objid') { $event->[$i]->resolve(); }
                   }
                   my $codeRef = shift(@{$event});
                   no integer;
                  # &main::rock_shout(undef, "Doing event: $event (args @$event; called by $calledBy)\n", 1);
                   &{$codeRef}(@$event);
                   use integer;
                 };
                # if($@) { &main::rock_shout(undef, "{2}#### {7}Dropped event $event: $@\n", 1); }
             }
        }
        $self->{'ETIME'}++;
    }
    no integer;
    
sub toStringPlayer() {
    # returns a color-coded string listing events and the times they
	# go super-crazy
	my $self = shift;
	
	my $cap = '';
	
	foreach my $etime (sort keys %{$self->{'EVENTS'}}) {
	    #$cap .= "{12}" . localtime($etime) . "{2}";
		foreach my $arglist (@{$self->{'EVENTS'}->{$etime}}) {
		    my (undef, @args) = map {
			    my $ostr = $_;
				if (ref($ostr) eq 'objid') { 
					$cap .= "{12}" . localtime($etime) . "{2}";
					$ostr = $ostr->toStringPlayer(); 
					$cap .= " $ostr "."\n";
					}
				elsif ($ostr eq \&rockobj::item_spawn) { $ostr = ""; }
				
			#	$ostr
			} @$arglist;
			
		    #$cap .= "@args"."\n";
	   
		}
	}
	
	return $cap;
}
}

package objid;
use strict;

sub new {
    my $proto = shift;
    if( eval { defined($_[0]->{'OBJID'}) && $_[0]->{'OBJID'} } ) { 
         my $self = \(my $a = $_[0]->{'OBJID'});
         bless($self, $proto);   
         return $self;
    } else { return $_[0]; }
}

sub resolve {
    if (defined($main::objs->{${$_[0]}})) {
       $_[0] = $main::objs->{${$_[0]}};
    } else {
       die "Couldn't resolve OBJID ".${$_[0]};
    }
}

sub toString() {
    my $str = "ObjectID #" . ${$_[0]}. " ";
    if (defined($main::objs->{${$_[0]}})) {
       $str .= "($main::objs->{${$_[0]}}->{'NAME'})";
    } else {
       $str .= "(no longer in game)";
    }
	return $str;
}

sub toStringPlayer() {
    my $str = "" . "";
    if (defined($main::objs->{${$_[0]}})) {
       $str .= "($main::objs->{${$_[0]}}->{'NAME'})";
    } else {
       $str .= "(no longer in game)";
    }
	return $str;
}

1;
