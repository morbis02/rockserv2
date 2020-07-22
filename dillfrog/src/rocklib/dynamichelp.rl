# sets up help files that are constant but could change every time rockserv is loaded
# (for development reasons)

&help_set_terrain_types;
&help_set_actions;
1;


sub help_set_terrain_types {
 my ($key, $cap);
 $cap = "{13}--=====-- {16}Terrain Types{13} --=====--\n";
 foreach $key (sort by_number (keys(%main::terrain_toname))) {
   $cap .= sprintf("  {2}%2d   {12}%s\n", $key, $main::terrain_toname{$key});
 }
 $main::help->{'TERRAINTYPES'}=$cap;
 return;
}

sub help_set_actions {
 my ($key, $cap, $n, $flash);
 $cap = "{2}Action Help: Type {7}<actionname> {17}<user>{2} to do an action\n";
 $cap .= "{2}to a user. Look at all the actions you can do!\n";
 $flash = 11;
 foreach $key (sort (keys(%{$main::amap}))) {
   $cap .= sprintf('{%d}%18s', $flash, $key);
   $flash++; if($flash > 17) { $flash=11; }
   $n++; if($n == 4) { $n=0; $cap .= "\n"; }
 }
 if($n != 0) { $cap .= "\n"; }
 $main::help->{'ACTIONS'}=$cap;
 return;
}

# evalll &main::help_set_topics();

sub help_set_topics {
 my ($key, $cap, $n, $flash);
 $cap = "{2}Command Help: Type {7}help {17}<command>{2} for help on any\n";
 $cap .= "{2}particular command. A list of commands appears below.\n";
 #$flash = 11;
 #foreach $key (sort (keys(%{$main::help}))) {
 #  $cap .= sprintf('{%d}%18s', $flash, $key);
 #  $flash++; if($flash > 17) { $flash=11; }
 #  $n++; if($n == 4) { $n=0; $cap .= "\n"; }
 #}
 #if($n != 0) { $cap .= "\n"; }
 foreach my $key (sort keys %main::helpmap) {
    $cap .= sprintf("{6}%14s{7}] {2}%s\n", $key, join (', ', sort @{$main::helpmap{$key}}));
 }
 $main::help->{'TOPICS'}=$cap;
 return;
}

