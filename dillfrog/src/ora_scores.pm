package ora_scores;
use rockdb;
use realm_maint;
use rock_prefs;
use strict;
no strict 'subs';
use Dillfrog; # htmlencode

# scores 
$ora_scores::usersperpage = 24;
$ora_scores::columns = 4;

# &ora_scores::ora_players_count;
sub ora_players_count {
    
    my $dbh = rockdb::db_get_conn();
    my $sth = $dbh->prepare("select count(*) as player_count, race from $main::db_name\.PLAYERS where LAST_SAVED > SUBDATE(Now(), INTERVAL 5 day) group by race");
    $sth->execute();
    my $total_count = 0;
    while (my $row = $sth->fetchrow_hashref()) {
        $main::rock_stats{'s-prace-'.$row->{'race'}} = $row->{'player_count'};
	$total_count += $row->{'player_count'};
    }
    $sth->finish();
    $main::rock_stats{'s-players'} = $total_count;
    return;
}

# evalll &ora_scores::compile_all();
sub ora_players_load_where {
    my $where = shift;
    
    my $dbh = rockdb::db_get_conn();
    my $sth = $dbh->prepare("SELECT NAME, RACE FROM $main::db_name\.PLAYERS WHERE $where");
    $sth->execute();
    my $pdata = $sth->fetchall_arrayref();
   # &main::rock_shout(undef, "Size: ".scalar(@$pdata)."\n", 1);
    $sth->finish();
    return $pdata;
}


sub ELE_LEV { 0; }
sub ELE_MAJ { 1; }
sub ELE_KNO { 2; }
sub ELE_AGI { 3; }
sub ELE_STR { 4; }
sub ELE_CHA { 5; }
sub ELE_DEF { 6; }
sub ELE_REPU { 7; }
sub ELE_WORTH { 8; }
sub ELE_DP { 9; }
sub ELE_PKD { 10; }
sub ELE_SUBGAME { 11; }

sub compile_all {
    my ($self) = shift;
    
    &ora_players_count();
    
    %ora_scores::player_stats = ();
#    my $smart_req = "1=1";
    my $smart_req = "ADMIN='0' AND LAST_SAVED > SUBDATE(Now(), INTERVAL 5 day)";
#    my $smart_req = "LEV > 25 AND ADMIN='0'";
    &sdata_format('Top Level', &ora_players_load_where("$smart_req ORDER BY LEV DESC"), 'level', ELE_LEV);
    &sdata_format('Top Magic', &ora_players_load_where("$smart_req ORDER BY MAJ DESC"), 'magic', ELE_MAJ);
    &sdata_format('Top Knowledge', &ora_players_load_where("$smart_req ORDER BY KNO DESC"), 'knowledge', ELE_KNO);
    &sdata_format('Top Agility', &ora_players_load_where("$smart_req ORDER BY AGI DESC"), 'agility', ELE_AGI);
    &sdata_format('Top Strength', &ora_players_load_where("$smart_req ORDER BY STR DESC"), 'strength', ELE_STR);
    &sdata_format('Top Charisma', &ora_players_load_where("$smart_req ORDER BY CHA DESC"), 'charisma', ELE_CHA);
    &sdata_format('Top Defense', &ora_players_load_where("$smart_req ORDER BY DEF DESC"), 'defense', ELE_DEF);
   
    &sdata_format('Top Good Reputation', &ora_players_load_where("$smart_req ORDER BY REPU DESC"), 'repu', ELE_REPU);
    &sdata_format('Top Worth', &ora_players_load_where("$smart_req ORDER BY WORTH DESC"), 'worth', ELE_WORTH);
    &sdata_format('Top Dedication Points', &ora_players_load_where("$smart_req ORDER BY DP DESC"), 'dp', ELE_DP);
    &sdata_format('Player Kill/Death Ratio', &ora_players_load_where("$smart_req AND PVPKILLS > 0 AND PVPDEATHS > 0 ORDER BY (PVPKILLS / PVPDEATHS) DESC"), 'pkd', ELE_PKD);
    &sdata_format('Subgame Score', &ora_players_load_where("$smart_req ORDER BY (ARENA_PTS) DESC"), 'subgame', ELE_SUBGAME);

    &pdata_write(); # write player data
    &sdata_write_form(); # write index form
    
	
	# Okay, so we've written all these files out. Great. Now we need to delete the OLD files (ie the ones we didn't just update)
    # find and delete'em ! (one-liner -- wooo!) THis actually waits a few min to delete them, but it's close
	map { unlink($_); } grep { -M $_ > 1/24/60*4 }  glob "$main::base_web_dir/scores/player-*.shtml";
##    &main::rock_shout(undef, "{16}*** Web-based Scores have been recompiled.\n*** Visit {2}$main::base_web_url/scores/ {16}to see where you stand.\n");
    return;
}



sub sdata_format {
    my ($title, $sdata, $toptype, $ele_num) = @_;
    #top-agility-1-40.shtml
    
    # 0] Player Name
    # 1] Player Race #
    # (Change/add order via ora_players_load_where)
    my $pages = @$sdata / $ora_scores::usersperpage;
    $pages = int($pages + 1) unless ($pages == int $pages);
    my $prev_page;
    
    @ora_scores::page_num = ();  # page_num[rank/usersperpage]
    $ora_scores::pages = $pages;    # number of pages built
    for (my $page = 0; $page<$pages; $page++) { 
         my $start_rank = $page * $ora_scores::usersperpage + 1;
         my $end_rank = ($page+1) * $ora_scores::usersperpage;
         
         $ora_scores::page_num[$page] = "$start_rank-$end_rank";
         
         open(F, $_ = ">$main::base_web_dir/scores/top-$toptype-$start_rank-$end_rank.shtml")
		     or warn "Could not open $_: $!\n";
         
         # HEADER
		 my $pagetitle = HTMLEncode("Top " . ucfirst($toptype) . " (Ranks $start_rank - $end_rank)");
		 print F "<!--#set var=\"page_title\" value=\"$pagetitle\" -->";
         print F '<!--#include virtual="/include/header.asp"-->'."\n";
         print F "<CENTER><TABLE CELLSPACING=0 CELLPADDING=2 WIDTH=100%>\n";
         print F "<CENTER><FONT SIZE=+2 FACE=Verdana COLOR=#000066><B>$title</B> <I>($start_rank - $end_rank)</I></FONT></CENTER>\n";

         my $column = 0;
         my @row_colors = ('#eeeeee', '#dddddd');
         my $row_num = 0;
         for (my $i=$start_rank-1; $i<$end_rank; $i++) {
             last if !$sdata->[$i];
             # cycle through player listings, print to web page
             if($column == 0) { print F "<TR BGCOLOR=$row_colors[++$row_num % @row_colors] VALIGN=MIDDLE>"; }
             
             my ($pname) = $sdata->[$i]->[0] =~ /(\w+)\s*/;
             print F  "<TD BGCOLOR=#aaaaaa ALIGN=CENTER><IMG SRC=".lc($main::races[$sdata->[$i]->[1]]).".gif WIDTH=33 HEIGHT=33></TD>"
                     ,"<TD ALIGN=RIGHT><B><FONT SIZE=+1>".($i+1)."</FONT></B></TD>"
                     ,"<TD ALIGN=LEFT><TT><B><A HREF=\"player-".lc($pname).".shtml\">$pname</A></B></TT></TD>";
             
             # save player info
             $ora_scores::player_stats{$pname}->[$ele_num] = $i+1;
             
             if( ($column == $ora_scores::columns-1) || ($i == ($end_rank - 1))  ) { print F "</TR>\n"; }
             
             # next rowpart!
             $column = ($column+1) % $ora_scores::columns;
         }
         
         # FOOTER
         print F "</TABLE></CENTER>\n";
         #    -    next / previous
         print F "<TABLE WIDTH=100%><TR><TD ALIGN=LEFT>";
         if($prev_page) { print F "<FONT SIZE=+1 FACE=Impact><A HREF=$prev_page>Previous $ora_scores::usersperpage</A></FONT>"; }
         print F "</TD><TD ALIGN=RIGHT>";
         if($page < ($pages-1)) { print F  "<FONT SIZE=+1 FACE=Impact><A HREF=top-$toptype-"
                                          .(($page+1) * $ora_scores::usersperpage + 1)
                                          .'-'
                                          .(($page+2) * $ora_scores::usersperpage)
                                          .".shtml>Next $ora_scores::usersperpage</A></FONT>"; }
         print F "</TD></TABLE>\n";
         #    -    shtml includes
         print F '<!--#include virtual="./top-index.html"--><!--#include virtual="/include/footer.asp"-->'."\n";
         close(F);
         
         $prev_page = "top-$toptype-$start_rank-$end_rank.shtml";
    }
    
}


sub pdata_write {
    #player-name.shtml
    
    foreach my $pname (keys %ora_scores::player_stats) {
         my $lc_name = lc $pname; 
         my $stats = $ora_scores::player_stats{$pname};
		 

### LOAD ABSOLUTE STATS FOR MORE FUNNESS ###
    my $dbh = rockdb::db_get_conn(); 
    my $sth = $dbh->prepare("SELECT * FROM $main::db_name\.PLAYERS WHERE lower(name)=?");
    $sth->execute($lc_name);
    my $sqlstats = $sth->fetchrow_hashref();
    $sth->finish();
	my $stattotal = 0;
	my $maxstatwidth = 0;
	map { $sqlstats->{$_} += int rand (6); $stattotal += $sqlstats->{$_} } qw(AGI CHA STR DEF KNO MAJ);
    foreach my $stat (qw(AGI CHA STR DEF KNO MAJ)) {
	    $sqlstats->{$stat.'PCT'} = int ( $sqlstats->{$stat}/$stattotal * 153.12345); # really * 100, but we want to confuse people :)
        $maxstatwidth = $sqlstats->{$stat.'PCT'} if $maxstatwidth < $sqlstats->{$stat.'PCT'};	
 	}

###############

		 # Write telnet stuff
		 $main::telnetscores{$lc_name} = sprintf(<<END_CAP, $stats->[ELE_LEV], $stats->[ELE_MAJ], $stats->[ELE_KNO], $stats->[ELE_AGI], $stats->[ELE_STR], $stats->[ELE_CHA], $stats->[ELE_DEF], $stats->[ELE_REPU], $stats->[ELE_WORTH], $stats->[ELE_DP], $stats->[ELE_PKD], $stats->[ELE_SUBGAME]);
{17}Level{7}:    %4d  {17}Magic{7}:    %4d  {17}Knowledge{7}: %4d  {17}Agility{7}:    %4d
{17}Strength{7}: %4d  {17}Charisma{7}: %4d  {17}Defense{7}:   %4d  {17}Reputation{7}: %4d
{17}Worth{7}:    %4d  {17}DP{7}:       %4d  {17}PK/Death{7}:  %4d  {17}Subgames{7}:   %4d   
END_CAP
		 
         open(F, ">$main::base_web_dir/scores/player-$lc_name.shtml");
         
         # HEADER
         print F <<END_HTML;
<!--#set var="page_title" value="$pname" -->
<!--#include virtual="/include/header.asp"-->
<CENTER>
<TABLE CELLSPACING=0 CELLPADDING=3 WIDTH=100% COLS=4>
<TR><TD></TD><TD></TD><TD></TD><TD></TD></TR>
<TR BGCOLOR=#000066><TD COLSPAN="5"><FONT COLOR=WHITE FACE=Verdana SIZE=+1><B>$pname</B></FONT></TD></TR>
<TR BGCOLOR=#eeeeee>
   <TD><B>Agility:</B></TD>
   <TD width="50"><TT><A HREF=top-agility-$ora_scores::page_num[($stats->[ELE_AGI]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_AGI]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'AGIPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#cccccc><B>Level:</B></TD>
   <TD BGCOLOR=#cccccc><TT><A HREF=top-level-$ora_scores::page_num[($stats->[ELE_LEV]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_LEV]</A></TT></TD>
</TR>
<TR BGCOLOR=#dddddd>
   <TD><B>Charisma:</B></TD>
   <TD width="50"><TT><A HREF=top-charisma-$ora_scores::page_num[($stats->[ELE_CHA]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_CHA]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'CHAPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#dddddd><B>Reputation:</B></TD>
   <TD BGCOLOR=#dddddd><TT><A HREF=top-repu-$ora_scores::page_num[($stats->[ELE_REPU]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_REPU]</A></TT></TD>
</TR>
<TR BGCOLOR=#cccccc>
   <TD><B>Defense:</B></TD>
   <TD width="50"><TT><A HREF=top-defense-$ora_scores::page_num[($stats->[ELE_DEF]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_DEF]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'DEFPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#eeeeee><B>Worth:</B></TD>
   <TD BGCOLOR=#eeeeee><TT><A HREF=top-worth-$ora_scores::page_num[($stats->[ELE_WORTH]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_WORTH]</A></TT></TD>
</TR>
<TR BGCOLOR=#cccccc>
   <TD><B>Knowledge:</B></TD>
   <TD width="50"><TT><A HREF=top-knowledge-$ora_scores::page_num[($stats->[ELE_KNO]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_KNO]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'KNOPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#eeeeee><B>PKill / Death Ratio:</B></TD>
   <TD BGCOLOR=#eeeeee><TT><A HREF=top-pkd-$ora_scores::page_num[($stats->[ELE_PKD]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_PKD]</A></TT></TD>
</TR>
<TR BGCOLOR=#dddddd>
   <TD><B>Magic:</B></TD>
   <TD width="50"><TT><A HREF=top-magic-$ora_scores::page_num[($stats->[ELE_MAJ]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_MAJ]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'MAJPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#dddddd><B>DP:</B></TD>
   <TD BGCOLOR=#dddddd><TT><A HREF=top-dp-$ora_scores::page_num[($stats->[ELE_DP]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_DP]</A></TT></TD>
</TR>
<TR BGCOLOR=#eeeeee>
   <TD><B>Strength:</B></TD>
   <TD width="50"><TT><A HREF=top-strength-$ora_scores::page_num[($stats->[ELE_STR]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_STR]</A></TT></TD>
   <td width="$maxstatwidth"><table border="0" bgcolor="red" cellpadding="0" cellspacing="0"><tr><td><img src="spacer.gif" height="10" width="$sqlstats->{'STRPCT'}"></td></tr></table></td>
   <TD BGCOLOR=#cccccc><B>Subgame Scores:</B></TD>
   <TD BGCOLOR=#cccccc><TT><A HREF=top-subgame-$ora_scores::page_num[($stats->[ELE_SUBGAME]-1)/$ora_scores::usersperpage].shtml>#$stats->[ELE_SUBGAME]</A></TT></TD>
</TR>
</TABLE>
</CENTER>
<br><i style="font-size: 80%; color: #009;">Note: Red bar above signifies player's average concentration of a stat, compared to his/her other stats.</i>
END_HTML
         #    -    shtml includes
         print F '<!--#include virtual="./top-index.html"--><!--#include virtual="/include/footer.asp"-->'."\n";
         close(F);
		 
		 chmod 0644, "$main::base_web_dir/scores/player-$lc_name.shtml";
    }
    
}

sub sdata_write_form {
  open (F, ">$main::base_web_dir/scores/top-index.html") || warn "Cannot open r2 scorefile: $!\n";
  my $rank_opts;
  for(my $i=0; $i<@ora_scores::page_num; $i++) {
     (my $page_range = $ora_scores::page_num[$i]) =~ /(\d+)-(\d+)/;
     
     $rank_opts .= "<OPTION VALUE=\"-$page_range.shtml\">$1 - $2\n";
  }
  
  print F <<END_HTML;
<CENTER>
<TABLE WIDTH=100%>
<TR><TD>
<FORM METHOD=POST ACTION=$main::base_web_url/cgi-bin/redir-clip.pl>
<INPUT TYPE=HIDDEN NAME=1 VALUE="$main::base_web_url/scores/top-">
<FONT FACE=Arial>View Ability Ranks By:</FONT>
<SELECT NAME=2>
<OPTION VALUE="agility">Agility
<OPTION VALUE="charisma">Charisma
<OPTION VALUE="defense">Defense
<OPTION VALUE="dp">DP
<OPTION VALUE="knowledge">Knowledge
<OPTION VALUE="level">Level
<OPTION VALUE="magic">Magic
<OPTION VALUE="pkd">PKill/Death
<OPTION VALUE="repu">Reputation (Good)
<OPTION VALUE="strength">Strength
<OPTION VALUE="subgame">Subgame Scores
<OPTION VALUE="worth">Worth (Cryl)
</SELECT>
</TD><TD ROWSPAN=2>
<INPUT TYPE=IMAGE VALUE="View" WIDTH=123 HEIGHT=30 ALIGN=ABSMIDDLE SRC="$main::base_web_url/images/view.gif" BORDER=0>
</TD></TR>
<TR><TD>
<FONT FACE=Arial>Range:</FONT>
<SELECT NAME=3>$rank_opts</SELECT>
</FORM>
</TD></TR>
</TABLE>
</CENTER>
END_HTML

  close(F);
}

1;
