# sql_auth.pm
# Primative SQL replacement for Dillfrog::Auth

# work-in-progress

package Dillfrog::Auth;

use strict;
use DBI;
use Carp;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use Digest::MD5 qw(md5 md5_hex md5_base64);

# Function: new()
# Returns: a new instance of this object
sub new {
    my $proto = shift;
    my $self = {};
    bless($self, $proto);
    return $self;
}

# FIXME: doc
sub db_get_conn {
    #FIXME
    my $db_name = $main::db_name ;
    my $data_source = $main::db_datasource;
    my $username = $main::db_username;
    my $password = $main::db_password;
    my $dbh = DBI->connect_cached($data_source, $username, $password, {'RaiseError' => 1, 'ChopBlanks' => 1, 'AutoCommit' => 1}) or confess "Could not connect to database!\n";
    return $dbh;
}


sub db_get_conn_local {
    #FIXME
    my $db_name = "rockserv";
    my $data_source = "DBI:mysql:$db_name:localhost";
    my $username = "rockserv";
    my $password = 'password';
    my $dbh = DBI->connect_cached($data_source, $username, $password, {'RaiseError' => 1, 'ChopBlanks' => 1, 'AutoCommit' => 1}) or confess "Could not connect to database!\n";
    return $dbh;
}

# Function: authUserID($ip, $username, $cleartext_password)
# Returns: array of ($login_success, $reason, $uin)
# $login_success is true if the user could auth, false if not.
# $reason has a textual reason why auth failed, if failure
# $uin is the UIN of the username if the auth succeeded
# NOTE: If login fails here, it is up to this authUserID code to do any back-end recording of the failure, and/or enforce account lockouts, disabled accounts, etc.
sub authUserID {
    my ($self, $ip, $username, $cleartext_password) = @_;
	#$sha_passwd = sha1(strtolower($user_settings['member_name']) . un_htmlspecialchars($_POST['passwrd']));
    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT id_member, passwd, member_name FROM r2_members WHERE member_name=?", undef, lc($username));

    if(!defined $row) {
        return (0, "No such username", 0);
    }
	#'&' (ampersand) becomes '&amp;'
    #'"' (double quote) becomes '&quot;' when ENT_NOQUOTES is not set.
    #"'" (single quote) becomes '&#039;' only when ENT_QUOTES is set.
    #'<' (less than) becomes '&lt;'
    #'>' (greater than) becomes '&gt;'

	my $member_name = $row->[2];
	my $passwd = md5_hex($cleartext_password);
	my $sha1passwd = $row->[1];
    if($sha1passwd ne $passwd) {
		
		return (0, "Invalid Password", 0);
    }

    return (1, "Successful Password", $row->[0]);
}

# Function: getUIN($username)
# Returns: the UIN for a given userid
sub getUIN {
    my ($self, $username) = @_;

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT id_member FROM r2_members WHERE member_name=?", undef, lc($username));

    return 0 unless defined($row);

    return $row->[0];
}

# Function: authUIN($ip, $uin, $cleartext_password)
# returns true if correct password, false otherwise
sub authUIN {
    my ($self, $ip, $uin, $cleartext_password) = @_;

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT passwd, member_name FROM r2_members WHERE id_member=?", undef, $uin);
	
    return 0 unless defined($row);
	
	my $member_name = $row->[1];
	my $passwd = md5_hex($cleartext_password);
	my $sha1passwd = $row->[0];
    if($sha1passwd ne $passwd) {
		
		return (0, "Invalid Password", 0);
    }else {
		return (1, "Successful Password", 0);
	}

}

# Function: logMessage($site_code, $event_code, $uin, $ip)
# $site_code is the site string the event belongs to (R1, R2, R3, FROGJAM, etc)
# $event_code is the event string (the type of event). E.g. "LOU" is logout, "LIN" is login, "NPW" is password change, "IDEA" is an idea, "BUG" is a bug, "NAC" is a new account
# $uin is the UIN of the account whose event we are logging
# $ip is the string IP address the user was connected from when the event occurred (e.g. "1.2.3.4")
# Returns: undefined  (this code adds the event to that UIN's event log)
sub logMessage {
    my ($self, $site_code, $event_code, $uin, $ip) = @_;

    print "[$site_code] $uin $event_code by $ip at " . localtime() . "\n";
}

# Function: getEmail($uin)
# Returns: the string e-mail address of that UIN.
# Behavior is undefined if the UIN does not exist
sub getEmail {
    my ($self, $uin) = @_;

    return ""; # FIXME

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT email_address FROM r2_members WHERE id_member=?", undef, $uin);

    return $row->[0];
}

# Function: getGender($uin)
# Returns: that UIN's gender (either M for male, N for neuter or F for female)
sub getGender {
    my ($self, $uin) = @_;

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT gender FROM r2_members WHERE id_member=?", undef, $uin);

    return $row->[0];
}

# Function: getUserID($uin)
# Returns: the lower-cased userid for that UIN (e.g. "plat")
sub getUserID {
    my ($self, $uin) = @_;

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT member_name FROM r2_members WHERE id_member=?", undef, $uin);

    return $row->[0];
}

# Function: getAccountData($uin)
# Returns: a reference to an anonymous hash containing all the (lower-case) column names/values in the "dillfrog.account" table.
# E.g. my $data = $auth->getAccountData(1);
# Though a bunch of keys/values are returned, here are the important ones that RS2 seems to care about:
# prefer_censor  ('Y' if the user wants censoring on, or 'N' if they don't)
# userid (the account's *lower-cased* userid)
# userid_formatted (The user's userid, with possibly mixed case. For example, the userid might be 'Plat' but the userid_formatted  might be 'PLaT')
# (Actually as far as I can tell, RS2 ignores the userid/userid_formatted info, but it's good to know)
sub getAccountData {
    my ($self, $uin) = @_;

    my $dbh = $self->db_get_conn();

    my $sth = $dbh->prepare_cached("SELECT * FROM r2_members WHERE id_member=?");
    $sth->execute($uin);
    my $hash_ref = $sth->fetchrow_hashref();
    $sth->finish();

    # FIXME: make a copy of the hash, map names appropriately?

    return $hash_ref;
}

# Function: setCensorByUIN($uin, $censor)
# Sets the censor preference for a user
# $uin is the UIN of the user
# $censor is true if the user wants the filter to be on.
sub setCensorByUIN {
    my ($self, $uin, $censor) = @_;

    my $dbh = $self->db_get_conn();
    $dbh->do("UPDATE r2_members SET prefer_censor=? WHERE id_member= ?", undef, $censor ? 'Y' : 'N', $uin, );
}

# FIXME: doc
sub isValidName {
    my ($self, $name) = @_;

    return (0,"Invalid characters.\n") unless ($name =~ m/^[A-Za-z0-9]+$/);
    return (0,"Name too long.\n") unless length($name) < 25;

    return (1,"");
}

# FIXME: doc
sub isValidEmail {
    my ($self, $email) = @_;

    my $dbh = $self->db_get_conn();
    my $row = $dbh->selectrow_arrayref("SELECT email_address FROM r2_members WHERE email_address=?", undef, $email);

    return (0, "Another account is using that email address.\n") if($row);

    # TODO: need more checks

    return (1,"");
}

# Function: createAccount
# Creates an account
# Returns ($new_uid, $error_message)
sub createAccount {
    my ($self, $ip, $userid, $cleartext_password, $fields) = @_;
    my $uin;

    # assumes $userid does not already exist

    # ugly...
    my $passwd = md5($cleartext_password);
    my $dbh = $self->db_get_conn();
    $dbh->do("INSERT INTO r2_members (userid,passwd,userid_formatted,gender,email,prefer_censor) VALUES (?,?,?,?,?,?)", undef, $userid, $passwd, $userid, $fields->{'gender'}, $fields->{'email'}, 0);

    my $row = $dbh->selectrow_arrayref("SELECT LAST_INSERT_ID()");

    return ($row->[0], "");
}

1;
