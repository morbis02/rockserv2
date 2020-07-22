package rockobj;
@player::ISA = qw( rockobj );
use strict;

sub item_stock {
  # note: the item receiving the call is the object being stocked.
  my ($self, $stocker) = @_;
  my ($store, $containedby);
  # figure out who I'm contained by
  $containedby = &rockobj::obj_lookup($self->{'CONTAINEDBY'});
  # get objid of store
  $store = $main::map->[$stocker->{'ROOM'}]->{'STORE'};
  if($containedby ne $stocker) { $stocker->log_append("{3}...So I said, Stock it? You don't even own it!\n"); return; }
  if(!$store) { $stocker->log_append("{3}Do you think you can just stock stuff anywhere? This isn't a store!\n"); return; }
  # convert store from objid to obj
  $store = &rockobj::obj_lookup($store);
  if(ref($store) eq "HASH") { # or maybe if $store eq {} ? 
    $stocker->log_append("{11}Error! That store no longer exists! :( Fixed it for next time.\n");
    delete $main::map->[$self->{'ROOM'}]->{'STORE'};
  } elsif($store->inv_free() < 1) { $stocker->log_append("{3}Yes, yes, but there's no room left to stock it.\n");
  } elsif($store->{'OWN'} ne lc($stocker->{'NAME'})) { $stocker->log_append("{3}This here store ain't yours, sonny boy!\n"); return; 
  } else {
    # unwield/unequip self from container as needed
    if( ($self->{'WORN'}) && (!$containedby->item_hremove($self)) ){ return; }
    if( ($self->{'EQD'}) && (!$containedby->item_hunequip) ){ return; }
    # remove self from container's inventory
    $containedby->inv_del($self);
    # add self to store inventory
    $store->inv_add($self);
    # tell user that the item was added
    $stocker->log_append("{5}$self->{'NAME'} stocked into $store->{'NAME'}.\n"); 
    return(1);
  }
}

sub store_list {
  my $self = shift;
  my $store = $main::map->[$self->{'ROOM'}]->{'STORE'};
  if(!$store) { $self->log_append("{3}You must be in a store in order to list items.\n"); return; }
  $self->cmd_do('look '.$main::objs->{$store}->{'NAME'});
  return;
}

sub item_sell {
  # note: the item receiving the call is the object being stocked.
  my ($self, $stocker) = @_;
  my ($store, $containedby);
  # figure out who I'm contained by
  $containedby = &rockobj::obj_lookup($self->{'CONTAINEDBY'});
  # get objid of store
  $store = $main::map->[$stocker->{'ROOM'}]->{'STORE'};
  if ($containedby ne $stocker) {
      $stocker->log_append("{3}...So I said, Sell it? You don't even own it!\n");
      return;
  }
  if (!$store) {
      $stocker->log_append("{3}Do you think you can just sell stuff anywhere? This isn't a store!\n");
      return;
  }
  
  # convert store from objid to obj
  $store = &rockobj::obj_lookup($store);
  if (ref($store) eq "HASH") { # or maybe if $store eq {} ? 
      $stocker->log_append("{11}Error! That store no longer exists! :( Fixed it for next time.\n");
      delete $main::map->[$self->{'ROOM'}]->{'STORE'};
  } elsif ($store->inv_free < 1) {
      $stocker->log_append("{3}The storekeeper has no room for your item, try again in a few minutes.\n");
      $store->{'MAXINV'}++;
  } elsif ($self->{'NOSAVE'}) {
      $stocker->log_append("{3}The storekeeper has no interest in that item.\n");
  } else {
      my $price = (int $self->{'VAL'}*$store->{'MARKDOWN'});
      if($store->wont_buy($self)) {  $stocker->log_append("{3}The store has no interest in your $self->{'NAME'}.\n"); 
      return(0);
    } elsif (defined($store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}}) && ($store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}} > time)) {
        $self->log_append("{3}$store->{'NAME'} wants not to buy a thing from the likes of you.\n");
        return (0);
    } elsif ($store->{'CRYL'} < $price) { 
       $stocker->log_append("{3}The store does not have enough cryl to justly pay for your $self->{'NAME'}.\n");
       return(0);
    } else {
      # unwield/unequip self from container as needed
      if($self->{'WORN'} || $self->{'EQD'}) {
        $containedby->log_error('You\'re using that!');
        return 0;
      }
      #if( ($self->{'WORN'}) && (!$containedby->item_hremove($self)) ){ return; }
      #if( ($self->{'EQD'}) && (!$containedby->item_hunequip) ){ return; }
      # remove self from container's inventory
      $containedby->inv_del($self);

      # add self to store inventory
      $store->inv_add($self);
      $store->{'CRYL'} -= $price; $stocker->{'CRYL'} += $price;
      $stocker->log_append('{2}You hand over {13}'.$self->{'NAME'}.' {2}to receive {13}'.$price."{2} cryl.\n");
      $stocker->room_sighttell('{2}'.$stocker->{'NAME'}.' hands over {13}'.$self->{'NAME'}.' {2}to receive {13}'.$price."{2} cryl.\n");
      my $room = $store->room();
      &main::log_event("Sell Item", "$stocker->{'NAME'} sold $stocker->{'PPOS'} $self->{'NAME'} to $room->{'NAME'} for $price cryl.", $stocker->{'UIN'}, undef, $self->{'REC'}, $price);
      $self->on_sell;
      return(1);
    }
    return(1);
  }
  return;
}

sub item_buy {
    # buys item of iname.
    my ($self, $iname) = @_;
    my ($store, $price);
    
    $store = $main::map->[$self->{'ROOM'}]->{'STORE'};
    if(!$store) {
        $self->log_error("There's no store here to buy from!");
        return 0;
    }
    elsif(!$iname) {
        $self->log_error("You've got to decide on something to buy.");
        return 0;
    }
    
    # convert store from objid to obj
    $store = &rockobj::obj_lookup($store);
    if(ref($store) eq "HASH") { # or maybe if $store eq {} ? 
        $self->log_append("{11}Error! That store no longer exists! :( Fixed it for next time.\n");
        delete $main::map->[$self->{'ROOM'}]->{'STORE'};
        return 0;
    } 
    
   my ($success, $item) = $store->inv_cgetobj($iname, 0);
    if($success == 1) {
        if($item->{'MINLEV'} > $self->{'LEV'}) {
            $self->log_error("Planar law regulates that you are too young to buy this item.");
            return 0;
        }
        $price = (int $item->{'VAL'}* $store->{'MARKUP'});
        if($self->{'CRYL'} < $price) { 
            $self->log_error("You don't have enough money to buy $item->{'NAME'}.");
            return 0;
        } elsif (!$self->can_lift($item) || !$item->can_be_lifted($self)) {
            $self->log_error("You wouldn't be able to carry $item->{'NAME'}.");
            return 0; 
        } elsif (!$self->inv_free) {
            $self->log_error("You don't have any room in your inventory for it.");
            return 0; 
        } elsif (defined($store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}}) && ($store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}} > time)) {
            $self->log_error("The store wouldn't sell it to the likes of you even if you paid THRICE the amount.");
            return 0; 
        } else {
            delete $store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}};
            $store->{'CRYL'} += $price; $self->{'CRYL'} -= $price;
            $self->log_append('{2}You hand over {13}'.$price.' {2}cryl to receive '.$item->{'NAME'}.".\n");
            $self->room_sighttell('{2}'.$self->{'NAME'}.' hands over {13}'.$price.' {2}cryl to receive '.$item->{'NAME'}.".\n");
            $store->inv_del($item); $self->inv_add($item);
            $item->on_buy($self, $store);
            return 1;
        }
    } elsif($success == 0) {
        $self->log_error("You don't see any $iname to purchase.");
        return 0;
    }
    elsif($success == -1) {
        $self->log_append($item);
        return 0;
    }
}

sub item_haggle {
 # buys item of iname.
 my ($self, $cap) = @_;
 my ($store, $offer, $iname);
 
 ($offer, $iname) = split(/ /, $cap, 2);
 
 $offer = int abs($offer);
 
 if(index(lc($iname), 'for ') == 0) { $iname = substr($iname, 4); } 
 elsif(index(lc($iname), 'fo ') == 0) { $iname = substr($iname, 3); } 
 elsif(index(lc($iname), 'f ') == 0) { $iname = substr($iname, 2); } 

 $store = $main::map->[$self->{'ROOM'}]->{'STORE'};
 if(!$store) { $self->log_append("{3}There's no store here to buy from!\n"); return; }
 elsif(!$iname) { $self->log_append("{3}You've got to decide on something to haggle for.\n{7}Format: offer {6}<price> <itemname>{7}.\n"); return; }
 
 # convert store from objid to obj
 $store = &rockobj::obj_lookup($store);
 if(ref($store) eq "HASH") { # or maybe if $store eq {} ? 
    $self->log_append("{11}Error! That store no longer exists! :( Fixed it for next time.\n");
    delete $main::map->[$self->{'ROOM'}]->{'STORE'};
    return;
 } 
 
 my ($success, $item) = $store->inv_cgetobj($iname, 0);
 if($success == 1) { 
 
    my $price = (int $item->{'VAL'}*$store->{'MARKUP'});
    # calc haggle abillity
    my $ha = (.1 + .9*$self->skill_has(29)) * $self->fuzz_pct_skill(2); 
    
    # create new haggle info if necessary
    if(!$self->{'HAGGLE'} || 
       ($self->{'HAGGLE'}->[0] != $item->{'OBJID'}) ||
       ($self->{'HAGGLE'}->[1] != $store->{'OBJID'})
      ) { 
           $self->{'HAGGLE'} = [ $item->{'OBJID'}, $store->{'OBJID'} ];
        }
        
    # fuzz_pct_skill
    if( ($offer/$price) < (.9 - $ha*.5) ) { 
       if(rand(100) < 70) {
          $self->log_append("{3}Your pitiful offer of $offer cryl for $store->{'NAME'}\'s fine $item->{'NAME'} has been refused.\n{7}The manager REFUSES to do any more business with the LIKES of YOU.\n");
          $self->room_sighttell("{13}$self->{'NAME'} {3}had the audacity to offer {13}$offer {3}cryl for {2}$item->{'NAME'}\{3}, only to get banned trying.\n");
          $store->{'AI'}->{'BANUSER'}->{$self->{'NAME'}}=time+60*10; # ban the user
       }
    }
    
    
    
    
 } elsif($success == 0) { $self->log_append("{3}You don't see any $iname to haggle for.\n"); return(0); }
 elsif($success == -1) { $self->log_append($item); return(0); }
}

sub wont_buy {
    return 1 if $_[1]->{'NOPSELL'};
    return ((int $_[1]->{'VAL'}*$_[0]->{'MARKDOWN'})<=0);
}
