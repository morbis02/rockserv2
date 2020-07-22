## UPDATES/LOADS FLAT ACTION DATABASE FILE
use strict;
&up_actions;
return 1;

sub up_actions {
  my (@acts, $act, @aa, $n, $acts, $nextact);
  $nextact = 0;
  @main::gestures = (); # clear gesture array.
  opendir(ACTDIR, 'act') || die "Cannot open action directory: $!\n";
  @acts = readdir(ACTDIR); rewinddir(ACTDIR); close(ACTDIR);
  $acts = 0;
  foreach $act (@acts) {
   if (! ($act =~ /(.+?)\.act/) ) { next; }
   $act = &main::insure_filename('./act/'.$act);
   open(A, $act) || die "Could not open file $act: $!\n"; @aa = <A>; close(A);
   grep { s/\n//g; } @aa;
   if ($#aa != 6) { print "Abnormal line count on file $act: ".($#aa+1)."\n"; next; }
   $main::amap->{lc($1)}=$nextact;
   for ($n=0; $n<=6; $n++) {
     $main::gestures[$nextact]=$aa[$n]; $nextact++;
   }
   $acts++;
   }
  print "Loaded $acts Actions into Database.\n";
  return;
}

sub action_validate(actionname) {
  my $aname = lc(shift);
  my ($type) = @_; # type 0: validate. type 1: view only.
  my $filepath = '/home/ftp/pub/rock/incoming/'.$aname.'.act';
  if(!(-e $filepath)) { return("That file does not exist.\n"); }
  open (AFILE, $filepath) || return("Could not open action: $!\n");
  my (@act, $cap, $errors, $i);
  @act = <AFILE>;
  $cap = "{11}===- file\n{17}";
  for ($i=0; $i<=$#act; $i++) { $cap .= ($i-1).': '.$act[$i]; } #>
  $cap .= "{11}===- EOF\n";
  if ($#act != 6) { $errors .= "   Abnormal line count on file $aname.act: ".($#act+1)."\n"; }
  if(!($act[1] =~ /%S/)) { $errors .= "   Sender \%S not listed on line 2.\n"; }
  if(!($act[2] =~ /%R/)) { $errors .= "   Receiver \%R not listed on line 3.\n"; }
  if(!($act[3] =~ /%S/)) { $errors .= "   Sender \%S not listed on line 4.\n"; }
  if(!($act[4] =~ /%S/)) { $errors .= "   Sender \%S not listed on line 5.\n"; }
  if(!($act[4] =~ /%R/)) { $errors .= "   Receiver \%R not listed on line 5.\n"; }
  if(!($act[6] =~ /%S/)) { $errors .= "   Sender \%S not listed on line 7.\n"; }
  close(AFILE);
  if($errors) { 
    $cap .= "{1}The following errors were found:\n{11}$errors";
   # $cap .= "{6}The file {16}$aname.act {6}was removed from the queue due to errors.\n";
   # unlink($filepath);
  } else {
    $cap .= "{12}It looks okay!\n";
    if($type==0) { 
      # add it
      open(AFILE, ">$main::base_code_dir/act/".$aname.'.act') || return("$cap\nError writing file: $!\n");
      print AFILE @act;
      close(AFILE);
      $cap .= "{12}Action added. Don't forget to 'upact' to make it available to players.\n";
    }
  }
  return($cap);  
}

#print '[ '.$main::gestures[$realm->{'ACTMAP'}->{'smile'}].' ]'."\n";

#untie %gestures;

