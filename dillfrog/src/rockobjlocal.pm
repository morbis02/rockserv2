package rockobj;
use strict;

sub dam_defense {
    ## passed attacker object. returns defense value (the higher the better)
    my ($self, $attacker) = @_;
    return int(
                3 / 2 *
                ( defined($self->{'FX'}->{7}) * $self->{'LEV'} / 8) +
                ( $self->{'VIGOR'} + 0.3 ) *
                (
                    rand( $self->{'STAT'}->[DEF] / 5 ) +
                    rand( ($self->{'STAT'}->[DPHY] * 1.5 + $self->{'STAT'}->[AGI] * 0.5) / 6) +
                    rand( $self->{'AOFFSET'} ) +
                    ( $self->{'AOFFSET'} / 6 )
                )
            ); # AOFFSET is the total AC of all armour
}

sub dam_offense {
    # (victim, [weapon])
    ## passed victim and weapon objects. returns offense value (the higher the better)
    my ($self, $victim, $weapon) = @_;
    my $dam = int ( ( rand($self->{'LEV'}*1/3) + rand($self->{'LEV'}*.5) + rand($self->{'STAT'}->[STR]/2) * (rand(3)+1) ) * ($self->{'VIGOR'}+.5)  );

    # then add weapon bonus if the user has a weapon
    if($weapon) {
        $dam += int($weapon->dam_bonus($victim, $self));
    }
    # was: if(ref($weapon))

    # then double it and add a random of 2 (to keep chance of odd) if offender is holding victim :)
    if($self->inv_has($victim)) {
        $dam += $dam + int rand(3);
    }

    # put it on a percentile based on attacker's hp (could be as low as 1/3)

    $dam += ($self->{'HP'} > 0) ? int( $dam * ( (100+($self->{'HP'} / $self->{'MAXH'}*100)) / 300 ) ) : int rand(5);

    return $dam;
}


sub get_help_on {
    my ($self, $topic) = @_;
# This won't work very well for non-Dillfrog machines    
    
    $topic = lc $topic;
#    $topic = $main::cmdbase_ali->{$topic} || $topic;
    
    # if we have it cached, no problem!
    if (defined $rockobj::help_topics{$topic}) {
        $self->log_append("$rockobj::help_topics{$topic}") ;
        return;
    }
    
    # otherwise, make sure it exists first
    my ($exists) = sql_select_mult_row_linear(<<END_SQL, $topic);
SELECT '?'
FROM r3.news
WHERE acode='Rock 2' AND amode='Help' AND title=?
END_SQL
   
   if ($exists) {
       # get it from web site and cache it, and display it
       my $topic_encoded = $topic;
       $topic_encoded =~ s/([^a-zA-Z])/sprintf("%%%x",ord($1))/ge;
       
       my $url = $exists ? "http://www.dillfrog.com/games/r2/help/commands/display_help.asp?style=plain\\&aid=$topic_encoded" : "http://www.dillfrog.com/games/r2/help/commands/?style=plain";
       my $txt = `links -dump $url`;
       
       my %brackHash = ('{' => '{30}', '}' => '{31}');
       $txt =~ s/\{|\}/$brackHash{$&}/g;
       
       $txt =~ s/^[ \t]+//gm;
#debug       $txt =~ s/([^a-zA-Z0-9\n ])/sprintf("%%%x",ord($1))/ge;
       $txt =~ s/^Abstract:/{12}Abstract:{2}/gm;
       $txt =~ s/^>>(.+)/\{2\}>>\{12\}\1\{7\}/gm;
       $txt =~ s/^(Syntax|Example|See Also|Description)$/\{16\}\1\{7\}/gm;
       $self->log_append($rockobj::help_topics{$topic} = "{7}+================================ {17}$topic {7}================================+\n{17}".$txt."{7}+================================ {17}$topic {7}================================+\n");
   } else {
       # invalid topic
       $self->log_error("Sorry, there is no help available for the topic of \"$topic\".");
   }
    
}



1;
