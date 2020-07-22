package rockobj;
use strict;
use rockdb;
use Dillfrog::Auth;

#sub dam_defense {
#    ## passed attacker object. returns defense value (the higher the better)
#    my ($self, $attacker) = @_;
#    return int(
#                3 / 2 *
#                ( defined($self->{'FX'}->{7}) * $self->{'LEV'} / 8) +
#                ( $self->{'VIGOR'} + 0.3 ) *
#                (
#                    rand( $self->{'STAT'}->[DEF] / 5 ) +
#                    rand( ($self->{'STAT'}->[DPHY] * 1.5 + $self->{'STAT'}->[AGI] * 0.5) / 6) +
#                    rand( $self->{'AOFFSET'} ) +
#                    ( $self->{'AOFFSET'} / 6 )
#                )
#            ); # AOFFSET is the total AC of all armour
#}

#sub dam_offense {
#    # (victim, [weapon])
#    ## passed victim and weapon objects. returns offense value (the higher the better)
#    my ($self, $victim, $weapon) = @_;
#    my $dam = int ( ( rand($self->{'LEV'}*1/3) + rand($self->{'LEV'}*.5) + rand($self->{'STAT'}->[STR]/2) * (rand(3)+1) ) * ($self->{'VIGOR'}+.5)  );#
#
#    # then add weapon bonus if the user has a weapon
#    if($weapon) {
#        $dam += int($weapon->dam_bonus($victim, $self));
#    }
#    # was: if(ref($weapon))#
#
#    # then double it and add a random of 2 (to keep chance of odd) if offender is holding victim :)
#    if($self->inv_has($victim)) {
#        $dam += $dam + int rand(3);
#    }##

    ## put it on a percentile based on attacker's hp (could be as low as 1/3)
#
 #   $dam += ($self->{'HP'} > 0) ? int( $dam * ( (100+($self->{'HP'} / $self->{'MAXH'}*100)) / 300 ) ) : int rand(5);
#
 #   return $dam;
#}


sub get_help_on {
    my ($self, $topic) = @_;
# This won't work very well for non-Dillfrog machines    
    
    $topic = lc $topic;
#    $topic = $main::cmdbase_ali->{$topic} || $topic;
    
    # if we have it cached, no problem!
    #if (defined $rockobj::help_topics{$topic}) {
    #    $self->log_append("$rockobj::help_topics{$topic}") ;
    #    return;
    #}
    
	my $db_name = "r2";
    my $data_source = "DBI:mysql:$db_name:localhost";
    my $username = "rockserv";
    my $password = 'password';
    my $dbh = DBI->connect_cached($data_source, $username, $password, {'RaiseError' => 1, 'ChopBlanks' => 1, 'AutoCommit' => 1});


  #  my $dbh = rockdb::db_get_conn_smf1() or return "Could not connect to oracle!\n";
    my $row = $dbh->selectrow_arrayref("SELECT body, id_topic FROM r2_messages WHERE subject=?", undef, lc($topic));
    
    # otherwise, make sure it exists first
   
   if (defined($row)) {
       # get it from web site and cache it, and display it
       my $topic_encoded = $row->[0];
       #$topic_encoded =~ s/([^a-zA-Z])/sprintf("%%%x",ord($row->[0]))/ge;
       $topic_encoded =~ s/<br \/>/\n/g; #<br />
       $topic_encoded =~ s/&lt;/</g; #<
       $topic_encoded =~ s/&gt;/>/g; #>
       $topic_encoded =~ s/&nbsp;/ /g; #>#&nbsp;
       $topic_encoded =~ s/&#039;/'/g; #
       $topic_encoded =~ s/&quot;/"/g; #&quot;
       $self->log_append($rockobj::help_topics{$topic_encoded} = "{7}+================================ {17}$topic {7}================================+\n{7}".$topic_encoded."\n{7}+================================ {17}$topic {7}================================+\n");
   } else {
       # invalid topic
       $self->log_error("Sorry, there is no help available for the topic of \"$topic\".");
   }
    
}



1;
