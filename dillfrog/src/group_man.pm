package group_man;
use strict;
use Carp;

# $rock::group_man->{$group_id} = { group stats }
# $player->{'group'} = { player stats }
# looks like .. nothing yet :)

# $rock::group_man->{5} =
# {
#    $playerOBJID => bitstring
#    
# }
#
# Bitstring:
#
#    0: JOIN
#    1: INVITE
#    2: FOLLOW/STAY (0/1)
#    3: LEADER

sub new {
    my $proto = shift;
    
    my $self = {};
    
    bless($self, $proto);

    ## set up
    #$self->populate();
    ## 
    return $self;
}

sub toString {
    my $self = shift;
    my $cap;
    foreach my $gid (keys %$self) {
        $cap .= "{7}-====== Group ($gid) =======-\n"
             .  $self->{$gid}->toString();
    }
    return $cap;
}

sub get_group {
    # returns group object given a particular group id
    my ($self, $gid) = @_;
    
    return $self->{$gid};
}

sub create_group {
    # creates and returns a new group
    my ($self, $leader) = @_;
    die "Groups must be created by some leader!\n" if !$leader;
    
    my $id = ++$group_man::CURR_GROUP_ID;
    my $group = $self->{$id} = rockgroup->new($id);
    
    $group->make_invited($leader);
    $group->make_joined($leader);
    $group->make_leader($leader);
    $leader->{'groupid'} = $id;
    
    return $group;
}

sub remove_from_all_groups {
    my ($self, $player) = @_;
    foreach my $gid (keys %$self) {
        $self->{$gid}->remove($player);
    }
}

package rockgroup;
use strict;
use Carp;

use constant ki_players => 0;
use constant ki_group_id => 1;
use constant ki_color => 2;

use constant ki_max_players_per_group => 20;

use constant ki_join   => 0;
use constant ki_invite => 1;
use constant ki_follow => 2;
use constant ki_leader => 3;

$rockgroup::colormap ||= '';

sub new {
    my ($proto, $id) = @_;
    die "You must supply an ID when creating a group!\n" if !$id;
        
    return bless( [ {}, $id, &choose_new_color() ], $proto);
}

sub get_color { $_[0]->[ki_color]; }
sub get_ansi_color { '{'.$_[0]->[ki_color].'}'; }

sub choose_new_color {
    # 1-7 => 1-7
    # 8->14 => 11->17
    for(my $i=1; $i<=7*14; $i++) {
        next if $i == 6; # skip {6} as default color
        unless(vec($rockgroup::colormap, $i, 1)) {
            vec($rockgroup::colormap, $i, 1) = 1;
            return $i;
        }
    }
    
    return undef;
}

sub delete {
    my $self = shift;
    # deletes a group!
    foreach my $player ($rock::rock->player_objs()) {
        delete $player->{'groupid'} if $self->is_member($player);
    }
    delete $rock::group_man->{$self->get_id()};
    vec($rockgroup::colormap, $self->[ki_color], 1) = 0;
}

sub get_id {
    # my $id = $group->get_id();
    return $_[0]->[ki_group_id];
}

sub is_full {
    # $group->is_full()
    # returns true if no more members can be added.
    return keys(%{$_[0]->[ki_players]}) >= ki_max_players_per_group;
}

sub is_member {
    # $group->is_member($pobj);
    # is the player a member of the group?
    my $stats = $_[0]->[ki_players]->{$_[1]->get_objid()};
    return    vec($stats, ki_join, 1)
           && vec($stats, ki_invite, 1);
}

sub methtrace {
    my $calltrace;
    my $n=0;
    while(my @a = caller($n)) { $calltrace .= "    ".($n++).": @a\n"; }
    print $calltrace;
}

sub remove {
    my ($self, $pobj) = @_;
    return if !$self->[ki_players]->{$pobj->get_objid()};
    
    # Do we need a new leader?

    if ($pobj->{'groupid'} == $self->get_id()) {
        # tell the group
        $pobj->group_tell("{14}*** {17}".$pobj->get_name()." has left your group.\n");
        
        delete $pobj->{'groupid'};
    }
    
    my $need_new_leader = $self->is_leader($pobj);

    # remove info from group and player data
    delete $self->[ki_players]->{$pobj->get_objid()};

    if(!$self->try_dissolving_group() && $need_new_leader) {
        my ($objid) = keys %{$self->[ki_players]};
        

        my $newplayer = SimpleChatter->load($objid);
        $self->make_leader($newplayer);
        $newplayer->log_append("{14}*** {17}YOU ARE THE NEW GROUP LEADER\n");
        $newplayer->group_tell("{14}*** {17}".$newplayer->get_name()." is the new group leader by default.\n");
    }

}

# need to handle logouts and 'leave group's.

sub change_leader_to {
    my ($self, $to) = @_;
    
    die "Cannot change leader if recipient is not a member." unless $self->is_member($to);
    
    my $from = $self->get_leader();
    
    $self->make_not_leader($from);
    $self->make_leader($to);
}

sub get_leader{
    # returns object of the leader of the group
    my $self = shift;
    
    foreach my $objid (keys %{$self->[ki_players]}) {
        return SimpleChatter->load($objid) if
              vec($self->[ki_players]->{$objid}, ki_leader, 1);
    }

    die "NO LEADER OF GROUP FOUND!!";
    return undef;
}

sub is_invited {
    # $group->is_invited($pobj);
    # has the player been invited to the group?
    my $stats = $_[0]->[ki_players]->{$_[1]->get_objid()};
    return    vec($stats, ki_invite, 1);
}

sub is_joined {
    # $group->is_invited($pobj);
    # has the player been invited to the group?
    my $stats = $_[0]->[ki_players]->{$_[1]->get_objid()};
    return    vec($stats, ki_join, 1);
}

sub is_leader {
    # $group->is_leader($pobj);
    # is the player the group leader?
    my $stats = $_[0]->[ki_players]->{$_[1]->get_objid()};
    return    vec($stats, ki_leader, 1);
}

sub make_joined {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_join, 1) = 1;
}

sub make_not_joined {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_join, 1) = 0;
}

sub is_following {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_follow, 1);
}

sub make_following {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_follow, 1) = 1;
}

sub make_not_following {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_follow, 1) = 0;
}

sub make_invited {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_invite, 1) = 1;
}

sub make_not_invited {
    my ($self, $pobj) = @_;    
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_invite, 1) = 0;
}

sub make_leader {
    my ($self, $pobj) = @_;
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_leader, 1) = 1;
}

sub make_not_leader {
    my ($self, $pobj) = @_;    
    vec( $self->[ki_players]->{$pobj->get_objid()} , ki_leader, 1) = 0;
}

sub try_dissolving_group {
    my $self = shift;
    if ($self->get_member_count() <= 1) {  # was get_player_count, but changed to get_member_count
        $self->delete();
        return 1;
    }
    return 0;
}

sub asked_to_join {
    # $group->asked_to_join($pobj);
    # has the player asked to join the group?
    my $stats = $_[0]->[ki_players]->{$_[1]->get_objid()};
    return    vec($stats, ki_join, 1);
}

sub get_member_count {
    # returns a count of members of the group. NOT those only invited/join'd.
    #
    my $count;
    foreach my $objid (keys %{$_[0]->[ki_players]}) {        
        my $stats = $_[0]->[ki_players]->{$objid};
        $count++ if
              vec($stats, ki_join, 1)
           && vec($stats, ki_invite, 1);
    }
    
    return $count;
}

sub get_player_count {
    # returns a count of all players in the group, including those only invited/joined.
    #    
    return scalar keys %{$_[0]->[ki_players]};
}

sub get_all_players_involved {
    # returns an array of members of the group. NOT those only invited/join'd.
    #
    my @members;
    foreach my $objid (keys %{$_[0]->[ki_players]}) {
        push(@members, $rock::rock->get_pobj($objid));
    }
    return @members;
}

sub get_members {
    # returns an array of members of the group. NOT those only invited/join'd.
    #
    my @members;
    foreach my $objid (keys %{$_[0]->[ki_players]}) {
        my $stats = $_[0]->[ki_players]->{$objid};
        
        push(@members, $rock::rock->get_pobj($objid)) if
              vec($stats, ki_join, 1)
           && vec($stats, ki_invite, 1);
    }
    
    return @members;
}

sub toString {
    my $self = shift;
    my $cap;
    foreach my $objid (sort  keys %{$self->[ki_players]}) {        
        my $stats = $self->[ki_players]->{$objid};
        my $player = SimpleChatter->load($objid);
        if (!$player) {
            $cap .= "** ERROR, player objid #$objid doesn't exist.\n";
            return $cap;
        }
        if($self->is_member($player)) {
            my $hp = $player->get_hp_pct()*100;
            my $color;
            if ($hp < 30) { $color = 1; }
            elsif($hp < 60) { $color = 17; }
            else { $color = 7; }
            
            $cap .= sprintf("{%d}%20s {%d}<%3d%%> {7}[%3s] {6}%6d\n",
                       ($self->is_leader($player)?17:2), ($self->is_leader($player)?"*".$player->get_name()."*":$player->get_name()), $color, $hp,
                       ($self->is_following($player)?'Fol':''),
                       $player->get_turns()
                   );
        } else {
            $cap .= sprintf("{2}%20s                        {17}[{7}%s{17}]\n",
                       $player->get_name(),
                       ($self->is_joined($player)?'Type "invite <name>" to add.':'Invited.'), ($self->is_invited($player)?'Invite':'')
                   );
        }
    }
    
    return $cap;
}

sub is_full { $_[0]->get_player_count() > ki_max_players_per_group; }

######################
package o_group;
use strict;
use Carp;


sub remove_from_all_groups {
    my $self = shift;
    $rock::group_man->remove_from_all_groups($self);
    return;
}

sub leave_current_group {
    my $self = shift;
    if(my $group = $self->get_group()) {
        $group->remove($self);
    }
    return;
}

sub group_invite {
    my ($self, $member) = @_;
    # invites $member to our group.   
    # returns 1 on success, 0 on failure.
    
    return $self->log_append("{3}<<  You cannot invite yourself, silly!  >>\n")
        if($self == $member);

    my $group;
    if($group = $self->get_group()) {
        return $self->log_append("{3}<<  Only leaders may invite new members.  >>\n") && 0
            if !$group->is_leader($self);
    } else {
        $group = $rock::group_man->create_group($self);
      #  $self->log_append("{14}You have created a new group.\n");
    }
    
    #
    # is the group full?
    #
    return $self->log_append("{3}<<  The group is at its maximum capacity. Try dropping some members.  >>\n")
        if($group->is_full());
    
    # 
    # now, invite the member.
    #
    if ($group->is_invited($member)) {
        $self->log_append("{3}<<  ".$member->get_name()." is already invited!  >>\n");
    } else {
        $group->make_invited($member);
        $group->make_following($self);
        
        if($group->is_member($member)) {
            
            if(my $oldgroup = $member->get_group()) {  $oldgroup->remove($member); }
            $member->{'groupid'} = $group->get_id();

            $member->log_append("{7}You have joined ".$self->get_name()."'s group.\n");
            $member->group_tell("{14}*** {17}".$member->get_name()." has joined your group.\n");
        } else {
            $self->log_append("{7}You have invited ".$member->get_name()." to join your group.\n");
            $self->group_tell("{14}*** {17}".$self->get_name()." has invited ".$member->get_name()." to join our group.\n");
            $member->log_append("{14}*** {17}".$self->get_name()." has invited you to join $rock::genderposmap{$self->get_gender()} group. To join it, type \"join ".$self->get_name()."\".\n");
            $member->log_append("{14}*** {17}Type \"join ".$self->get_name()."\" to join $rock::genderpromap{$self->get_gender()}.\n")
                if $self->pref_get('newbie');
        }
    }
    
    return 1;
}

sub group_tell {
    my ($self, $msg, @except) = @_;
    # $self->group_tell($msg, [@except_pobjs]);
    # Will not send same message to sender.
    
    my $objid = $self->get_objid();
    my $group = $self->get_group();

    return if !$group;
    
	LOG_GROUP_EXCEPT_LOOP: foreach my $player ($group->get_members()) {

	    if (!$player->{'ST8'} && $player->{'OBJID'} != $objid) {
	       
	        # skip player if already listed
	        foreach my $p (@except) {
	            next LOG_GROUP_EXCEPT_LOOP if($p->{'OBJID'} == $player->{'OBJID'});
	        }
	        
	        # otherwise..
 	        $player->log_append(ref($msg) eq "censored_message" ? $msg->get_for($player) : $msg); 
	    }
    }
}

#sub group_tell_censored {
#    my ($self, $msg, @except) = @_;
#    # $self->group_tell($msg, [@except_pobjs]);
#    # Will not send same message to sender.
#    
#    my $objid = $self->get_objid();
#    my $group = $self->get_group();
#
#    return if !$group;
#    
#    # filter it
#    my $censored_msg = $self->censor_msg($msg);
#    
#	LOG_GROUP_EXCEPT_LOOP: foreach my $player ($group->get_members()) {
#
#	    if (!$player->{'ST8'} && $player->{'OBJID'} != $objid) {
#	       
#	        # skip player if already listed
#	        foreach my $p (@except) {
#	            next LOG_GROUP_EXCEPT_LOOP if($p->{'OBJID'} == $player->{'OBJID'});
#	        }
#	        
#	        # otherwise..
#   	        $player->log_append($player->pref_get('censor filter')?$censored_msg:$msg);
#	    }
#    }
#}

sub get_group {
    my $self = shift;
    
    return undef if !$self->{'groupid'};
    
    return $rock::group_man->get_group($self->{'groupid'});
}

#sub room_tell {
#    $_[0]->{'GAME_MAN'}->log_group(@_);
#}

sub is_in_a_group {
    my $self = shift;
    return $self->{'groupid'};
}

sub is_in_same_group_as {
    return $_[0]->{'groupid'} && $_[0]->{'groupid'} == $_[1]->{'groupid'};
}

sub group_uninvite {
    my ($self, $member) = @_;
    # invites $member to our group.   
    # returns 1 on success, 0 on failure.
    
    return $self->log_append("{3}<<  You cannot uninvite yourself, silly!  >>\n")
        if($self == $member);
    
    my $group;
    if($group = $self->get_group()) {
        return $self->log_append("{3}<<  Only leaders may uninvite members.  >>\n") && 0
            if !$group->is_leader($self);
    } else {
        $self->log_append("{3}<<  What? You are not even in a group!  >>\n");
        return 0;
    }
    
    # 
    # now, uninvite the member.
    #
    if (!$group->is_invited($member)) {
        $self->log_append("{3}<<  ".$member->get_name()." isn't even invited!  >>\n");
    } else {
        $group->remove($member);
        
        $self->log_append("{7}You have removed ".$member->get_name()." from your group.\n");
        $member->log_append("{14}*** {17}".$self->get_name()." has removed you from $rock::genderposmap{$self->get_gender()} group.\n");
        $self->group_tell("{14}*** {17}".$member->get_name()." has been removed from our group.\n", $self, $member)
            if $self->is_in_a_group();
        
        $group->try_dissolving_group();
    }
    
    return 1;
}

sub follow_group {
    my $self = shift;
    
    if(my $group = $self->get_group()) {
        if($group->is_following($self)) {
            $group->make_not_following($self);
            $self->log_append("{7}You are no longer following your group.\n");
            $self->group_tell("{14}*** {17}".$self->get_name()." is no longer following us.\n");
        } else {
            $group->make_following($self);
            $self->log_append("{7}You are now following your group.\n");
            $self->group_tell("{14}*** {17}".$self->get_name()." is now following us.\n");
        }            
    
    } else {
        $self->log_append("{3}<<  You must be in a group in order to follow one.  >>\n");
    }

}
sub group_join {
    my ($self, $leader) = @_;
    # invites $member to our group.   
    # returns 1 on success, 0 on failure.
    
    return $self->log_append("{3}<<  You cannot join yourself, silly!  >>\n") && 0
        if($self == $leader);

    my $group;
    unless($group = $leader->get_group()) {
        $group = $rock::group_man->create_group($leader);
      #  $leader->log_append("{14}You have created a new group by inference.\n");
    }
    
    return $self->group_join($group->get_leader()) unless $group->is_leader($leader);
    
    #
    # is the group full?
    #
    return $self->log_append("{3}<<  Sorry, the group is at its maximum capacity.  >>\n")
        if($group->is_full());

    # 
    # now, invite the member.
    #
    if ($group->is_joined($self)) {
        $self->log_append("{3}<<  ..but you have already joined!  >>\n");
    } else {
        
        $group->make_joined($self);
        $group->make_following($self);

        if($group->is_member($self)) {
            
            if(my $oldgroup = $self->get_group()) {  $oldgroup->remove($self); }
            
            $self->{'groupid'} = $group->get_id();
            
            $self->log_append("{7}You have joined ".$leader->get_name()."'s group.\n");
            $self->group_tell("{14}*** {17}".$self->get_name()." has joined your group.\n");
            
        } else {
            $self->log_append("{7}You have asked to join ".$leader->get_name()."'s group.\n");
            $leader->group_tell("{14}*** {17}".$self->get_name()." has asked to join your group.\n");
            $leader->log_append("{14}*** {17}".$self->get_name()." has asked to join your group.\n");
        }
    }
    
    return 1;
}

sub group_leave {
    my ($self, $leader) = @_;
    # invites $member to our group.   
    # returns 1 on success, 0 on failure.
    
    my $group;
    
    # Figure out which group we're talking about, and if it even makes sense.
    if($leader) {
        if($group = $leader->get_group()) {
            return $self->log_append("{3}<<  You haven't even joined that group!  >>\n")
                if !$group->is_joined($self);
        } else {
            return $self->log_append("{3}<<  ".$leader->get_name()." is not even in a group!  >>\n");
        }
    } else {
        $group = $self->get_group()
           or return $self->log_append("{3}<<  You are not even in a group!  >>\n");
    }   
         
    # 
    # now, unjoin the member.
    #
    
    print "Self: $self\n";

    if($group->is_member($self)) {
        $self->log_append("{7}You have left the group.\n");
    } else {
        my $glead = $group->get_leader();
        $glead->group_tell("{14}*** {17}".$self->get_name()." has retracted $rock::genderposmap{$self->get_gender()} request to join the group.\n");
        $glead->log_append("{14}*** {17}".$self->get_name()." has retracted $rock::genderposmap{$self->get_gender()} request to join the group.\n");
        $self->log_append("{7}You have retracted your request to join ".$glead->get_name()."'s group.\n");
    }
    
    $group->remove($self);
        
    return 1;
}

sub change_leader_to {
    my ($self, $to) = @_;
    
    if (my $group = $self->get_group()) {
        return $self->log_append("{3}<<  You are not the leader.  >>\n") if !$group->is_leader($self);
        return $self->log_append("{3}<<  ".$to->get_name()." is not a member of the group.  >>\n") if !$group->is_member($to);
        $self->group_tell("{14}*** {17}".$self->get_name()." has appointed ".$to->get_name()." as our new leader.\n");
        $self->log_append("{7}You have appointed ".$to->get_name()." as the new leader.\n");
        $group->change_leader_to($to);
    } else {
        $self->log_append("{3}<<  You are not in a group.  >>\n");
    }
}

sub is_following {
    # returns 1 if i'm following an object, 0 if not
    my ($self, $obj) = @_;
    
    return 0 if !$self->{'groupid'}
             ||  $self->{'groupid'} != $obj->{'groupid'};
             
    my $group = $rock::group_man->get_group($self->{'groupid'});
    confess "Group cannot be undef" unless $group;
    return $group->is_following($self) && $group->is_leader($obj);
}
1;
