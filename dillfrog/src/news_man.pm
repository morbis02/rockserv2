package news_man;
use strict;
use rockdb;

# looks like
# $rock::state_man->{'hug'} = [@msgs];

sub new {
    my $proto = shift;
    
    my $self = {};
    
    bless($self, $proto);

    ## set up
    # no cachin'
    #$self->populate();
    ## 
    return $self;
}

sub get_recent_news {
    
    #
    # Returns string of most recent N articles in the news database.
    #
    
    my ($self, $acode, $article_id) = @_;
    
    $acode ||= 'Rock 2';  # default to r3 news
    
    my $cap;
    
    my $dbh = rockdb::db_get_conn() or return "Could not connect to oracle!\n";
    
    my $sth = $dbh->prepare(<<END_CAP);
SELECT aid, DATE_FORMAT(N.adate, '%b %D %l:%i') as article_date, N.title, N.amode, N.acode
FROM   r3.news N, dillfrog.accounts U
WHERE  body IS NOT NULL
   AND U.uin = N.uin
   AND N.amode <> "Help"
ORDER BY adate desc
LIMIT 10
END_CAP
# acode=? AND
#    $sth->execute($acode);
    $sth->execute();
    
    my $maxnews = 3;
    my $newsno = 1;
    while(my $art = $sth->fetchrow_hashref()) {
	    my ($month, $day, $time) = $art->{'article_date'} =~ /^([^ ]+)\s+([^ ]+)\s+([^ ]+)$/;
        $cap = sprintf("{12}%4d {7}|{2} %3s %4s {7}| {2}%7s %-4s {7}| {2}%s\n", $art->{'aid'}, $month, $day, substr($art->{'acode'},0,7), substr($art->{'amode'},0,4), $art->{'title'}) . $cap;
    }
   
    $sth->finish();
    
    $cap = sprintf("{17}%5s{7}|{17} %8s {7}| {17}%7s      {7}| {17}%s\n", "ArtID", "Date", "Type", "Title") . $cap;
    return '{17}'.$cap."{3}<<  Syntax: news <article id>  >>\n";
}



sub get_article {
    
    #
    # Returns string of most recent N articles in the news database.
    #
    
    my ($self, $article_id) = @_;
        
    my $cap;
    $article_id = int $article_id;
    my $dbh = rockdb::db_get_conn() or return "Could not connect to oracle!\n";
    
    my $sth = $dbh->prepare(<<END_CAP);
SELECT DATE_FORMAT(N.adate, '%M %D %l:%i %p'), N.title, N.body, U.userid, N.markup_type
FROM   r3.news N, dillfrog.accounts U
WHERE  aid=?
   AND U.uin = N.uin
LIMIT 1
END_CAP

    $sth->execute($article_id);
    
    while(my $art = $sth->fetchrow_arrayref()) {
        if ($art->[4] eq "Frogcode") {
            $art->[2] =~ s/\n/<br>/g;
        }
    
        $art->[0] =~ s/\s+/ /g;
        $art->[2] =~ s/\s+/ /g;
		$art->[2] =~ s/<BR>/\n/ig;
		$art->[2] =~ s/&lt;/</g;
		$art->[2] =~ s/&gt;/>/g;
		$art->[2] =~ s/&amp;/&/g;
		$art->[2] =~ s/<[^>]+>//g;
		$art->[2] =~ s/^\s+/\n/gm;
		
        $cap .= "\n" if $cap;
        $cap .= sprintf("{2}==//{12}%s{2}//==\n{2}(%s / %s)\n{7}%s\n", $art->[1], $art->[3], $art->[0], $art->[2]);
    }
    
    $sth->finish();
    
	$cap = "$article_id is an invalid article id.\n" unless $cap;
    return '{14}'.('-=-' x int(8/3*10))."\n$cap".'{14}'.('-=-' x int(8/3*10))."\n";
}

1;
