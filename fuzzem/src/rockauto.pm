use strict;

package rockobj;
use strict;

sub item_secureaccept {
    my ($self, $iname, $price) = @_;
    
    $price = int abs($price);
    
    if( (ref($self->{'SGIVE_OFFER'}) ne 'ARRAY') || !$self->{'SGIVE_OFFER'}->[0]){ 
        $self->log_append("{17}..but nobody even offered you anything!\n");
        return;
    }

    my ($fromObj, $iObj, $oPrice) = @{$self->{'SGIVE_OFFER'}};
    
    $self->pref_set('gift-acceptance', 1, 1);
    
    # load objs
    if( !defined($main::objs->{$fromObj}) || !($fromObj = $main::objs->{$fromObj}) ) { $self->log_append("{17}Sorry, that user is no longer in the game.\n"); }
    elsif( !defined($main::objs->{$iObj}) || !($iObj = $main::objs->{$iObj}) ) { $self->log_append("{17}Sorry, that item no longer exists.\n"); }
    
    elsif( !$fromObj->inv_has($iObj) ) { $self->log_append("{17}$fromObj->{'NAME'} no longer has $iObj->{'NAME'} in $fromObj->{'PPOS'} inventory.\n"); }
    elsif( $fromObj->{'ROOM'} != $self->{'ROOM'} ) { $self->log_append("{17}You must be in the same room to do business.\n"); }
    elsif( (lc($iObj->{'NAME'}) ne lc($iname)) || $price != $oPrice ) { $self->log_append("{17}Syntax: {1}accept {7}$iObj->{'NAME'} {1}for {7}$oPrice\n"); }
    elsif( $self->{'CRYL'} < $oPrice ) { $self->log_append("{17}You only have $self->{'CRYL'} cryl - you need $oPrice!\n"); }
    elsif( $self->is_dead() ) { $self->log_append("{17}...but you're dead!\n"); }
    elsif( $fromObj->is_dead() ) { $self->log_append("{17}...what did mother always tell you about buying from dead men?!\n"); }
    else {
        if(!$fromObj->item_hgive($iObj, $self)) { $self->log_append("{17}$fromObj->{'NAME'} {1}was unable to give you the $iObj->{'NAME'} - sorry!\n"); }
        else {
            my $tempT = $self->{'T'}; $self->{'T'}=100;
            $self->cryl_give($oPrice, $fromObj);
            $self->{'T'} = $tempT;
            delete $self->{'SGIVE_OFFER'};

            &main::log_event("Sell Item", "$fromObj->{'NAME'} sold $fromObj->{'PPOS'} $iObj->{'NAME'} to $self->{'NAME'} for $oPrice cryl.", $fromObj->{'UIN'}, $self->{'UIN'}, $iObj->{'REC'}, $oPrice);

            return 1;
        }
    }
    return 0;
}

sub item_hsecuregive {
    my ($self, $to, $item, $price) = @_;
    # accept [itemname] for [price]
    
    $price = int abs($price);
    
    if($price == 0) { $self->log_append("{17}Selling for 0 cryl? Some vendor you aspire to be!\n"); }
    elsif($to->{'CRYL'}<$price) { $self->log_append("{17}$to->{'NAME'} does not have $price cryl on them right now.\n"); }
    elsif($self eq $to) { $self->log_append("{17}You want to sell to yourself? Are you really in that much need of business?\n"); }
    elsif($item->{'WORN'}) { $self->log_append("{17}But you're wearing that item right now!\n"); }
    elsif($self->{'WEAPON'}==$item->{'OBJID'}) { $self->log_append("{17}But you're wielding that item right now!\n"); }
    elsif($self->{'ROOM'} != $to->{'ROOM'}) { $self->log_append("{17}You must be in the same room to make the transaction.\n"); }
    elsif(!$to->pref_get('gift-acceptance')) { $self->log_append("{3}$to->{'NAME'} is not accepting gifts from other players.\n"); }
    elsif($to->{'SGIVE_OFFER'}->[0] == $self->{'OBJID'} &&
          $to->{'SGIVE_OFFER'}->[1] == $item->{'OBJID'} &&
          $to->{'SGIVE_OFFER'}->[2] == $price ) { $self->log_append("{3}But you just made that offer!\n"); }
    elsif($self->can_do(0,0,2)) {
	   my $worth_str = '';
	   if ($to->skill_has(16)) {
	       $worth_str = "{13} (appraised at ~".$item->get_appraised_value($to)." cryl)";
	   }
       $to->log_append("{12}***\n***{2} $self->{'NAME'} has offered to sell you {14}$item->{'NAME'}$worth_str {2}for {13}$price\{2} cryl.\n{12}***     {17}Type \"{7}accept $item->{'NAME'} for $price\{17}\" to accept $self->{'PPOS'} offer.\n{12}*** {2}Type {7}accept {2}to stop receiving items/offers from players.\n{12}***\n");
       $to->{'SGIVE_OFFER'} = [ $self->{'OBJID'}, $item->{'OBJID'}, $price, lc($item->{'NAME'}) ];
       $self->log_append("{17}Offered $item->{'NAME'} to $to->{'NAME'} for $price cryl.\n");
       return 1;
    }
    return 0;
}


sub auto_move {
  my ($self, $hard) = @_;
  # don't move if youre not on the ground, buddy.
  #$self->say_rand('Let go!', 'Wahhhh!', 'I want my mommy!', 'Could ya put me down?', 'Where\'s the ground!?', 'The sky is falling! The sky is falling!', 'Where are you taking me?');
  if(  !$main::map->[$self->{'ROOM'}]->inv_has($self)
     || $self->{'SENT'}
     || (!$hard && (scalar($main::map->[$self->{'ROOM'}]->inv_pobjs) <= 1))
    ) { return; }
  
  # [default] move self to a room i didn't come from (preferrably)
  
  #return $self->ai_move(
  #     $self->ai_suggest_norecurse(
  #       &rockobj::ai_suggest_move_random(undef, &rockobj::remove_nomobrooms_hash($main::map->[$self->{'ROOM'}]->exits_hash),'',$main::map->[$self->{'ROOM'}])
  #     )
  #   );
  
#  my %exits = $main::map->[$self->{'ROOM'}]->exits_hash();
#  # delete where i used to be
#  if($self->{'FRM'} && $exits{$self->{'FRM'}}) { delete $exits{$self->{'FRM'}}; }
#  # delete large rooms
#  foreach my $k (keys(%exits)) {
#     if(scalar $exits{$k}->inv_pobjs() > 3) { delete $exits{$k}; }
#  }
#  my @a = keys(%exits);
#  if (scalar(@a)) {
#     my $dir = $a[int rand(scalar @a)];
#     $self->realm_move($dir);
#  }

  # RECENTLY WAS:
#  if (my $exits = $main::map->[$self->{'ROOM'}]->exits_adjref()) {
#     $self->realm_move($exits->[int rand @$exits]);
#  }

  if (my $exits = $main::map->[$self->{'ROOM'}]->exits_adjref()) {
     $self->realm_move($exits->[int rand @$exits]);
#	 $self->say($exits->[0]);
#     scalar($main::map->[$self->{$dir}->[0]]->inv_pobjs)
  }

  return;
}

sub auto_move_targ {
 my $self = shift;
 if("$self->{'ROAMTARG'}" ne "") { return $self->ai_move_to($self->{'ROAMTARG'}); }
 return undef;
}

1;

