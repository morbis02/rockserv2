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
$main::base_code_dir = '/opt/rs2/src'; # NOTE: no trailing /.
$main::base_web_dir = '/var/www/html/games/rs2';
$main::base_web_url = 'http://localhost/games/rs2';

#####################################################
# E-mail and Contact Information
#####################################################
$main::mail_program = "/usr/sbin/sendmail -t";
$main::rock_admin_email = $main::rock_support ='support@support.com';
$main::rock_serv_email = $main::rock_serv ='support@support.com';
$main::pop_mail_server = 'localhost';
$main::owner_name = "owner_name"; #EXAMPLE fuzzem.com

#####################################################
# Ddatabase (currently localhost and MySQL are assumed)
#####################################################
$main::db_username = 'username';
$main::db_password = 'password';
$main::db_name = 'dbname';

my $data_source = "DBI:mysql:$main::db_name:localhost";

$main::db_datasource = $data_source;

# LAST, override stuff (you wont usually use this, but .. it's here for the one guy who does)
do "$main::base_code_dir/rock_prefslocal.pm" if -e "$main::base_code_dir/rock_prefslocal.pm";

1;
