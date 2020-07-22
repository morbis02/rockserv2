### PREFS, to be configured for use with Rock 2 upon startup.
#
#
package main;
use strict;

# TODO: Explain what each of these constants means and how it
#       affects the game.

#####################################################
# Directories
#####################################################
$main::base_code_dir = 'c:/rockserv2/dillfrog/src'; # NOTE: no trailing /.
$main::base_web_dir = '/var/www/html/games/r2';
$main::base_web_url = 'http://www.dillfrog.com/games/r2';

#####################################################
# E-mail and Contact Information
#####################################################
$main::mail_program = "/usr/lib/sendmail -t";
$main::rock_admin_email = $main::rock_support ='support@UPDATEYOURROCK_PREFSFILE.com';
$main::rock_serv_email = $main::rock_serv ='support@UPDATEYOURROCK_PREFSFILE.com';
$main::pop_mail_server = 'localhost';
$main::owner_name = "UpdateYourRock_PrefsFile.com";

#####################################################
# Ddatabase (currently localhost and MySQL are assumed)
#####################################################
$main::db_username = 'rockserv';
$main::db_password = 'password';
$main::db_name = 'r2_dillfrog';

# LAST, override stuff (you wont usually use this, but .. it's here for the one guy who does)
do "$main::base_code_dir/rock_prefslocal.pm" if -e "$main::base_code_dir/rock_prefslocal.pm";

1;
