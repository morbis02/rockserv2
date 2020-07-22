# dummy_auth.pm
# Primative replacement for Dillfrog::Auth
# Initial version by EnsignYu on 31 Dec 2004

use strict;
package Dillfrog::Auth;

use vars qw($users_db); # global variables for this package

# Static array of users, by uin. UINs start at 1.
# Remember to remove any sensitive info when redistributing
# Todo: move to a separate file?
# Change the userid/password values before uncommenting
$users_db = [];
$users_db->[1] = {userid => "admin", userid_formatted => "Admin", password => "password", email => "", gender => 'F', prefer_censor => 'N'};
$users_db->[2] = {userid => "player", userid_formatted => "Player", password => "password", email => "", gender => 'M', prefer_censor => 'Y'};

# Function: new()
# Returns: a new instance of this object
sub new {
    my $proto = shift;
    my $self = {};
    bless($self, $proto);
    return $self;
}

# Function: authUserID($ip, $username, $cleartext_password)
# Returns: array of ($login_success, $reason, $uin)
# $login_success is true if the user could auth, false if not.
# $reason has a textual reason why auth failed, if failure
# $uin is the UIN of the username if the auth succeeded
# NOTE: If login fails here, it is up to this authUserID code to do any back-end recording of the failure, and/or enforce account lockouts, disabled accounts, etc.
sub authUserID {
    my ($self, $ip, $username, $cleartext_password) = @_;
    my $uin;

    $uin = $self->getUIN($username);

    if(!defined $uin) {
        return (0, "No such username", 0);
    }

    if(! $self->authUIN($ip, $uin, $cleartext_password)) {
        return (0, "Wrong password", 0);
    }

    return (1, "", $uin);
}

# Function: getUIN($username)
# Returns: the UIN for a given userid
sub getUIN {
    my ($self, $username) = @_;
    my ($key, $uin);

    # find the account
    for ($key = 1; $key < @$users_db; ++$key) {
        next if !defined $users_db->[$key]; # skip if account does not exist
        $uin = $key if $username eq $users_db->[$key]->{userid};
    }

    return $uin;
}

# Function: authUIN($ip, $uin, $cleartext_password)
# returns true if correct password, false otherwise
sub authUIN {
    my ($self, $ip, $uin, $cleartext_password) = @_;

    return ($users_db->[$uin]->{password} eq $cleartext_password)
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
    return $users_db->[$uin]->{email};
}

# Function: getGender($uin)
# Returns: that UIN's gender (either M for male, N for neuter or F for female)
sub getGender {
    my ($self, $uin) = @_;
    return $users_db->[$uin]->{gender};
}

# Function: getUserID($uin)
# Returns: the lower-cased userid for that UIN (e.g. "plat")
sub getUserID {
    my ($self, $uin) = @_;
    return $users_db->[$uin]->{userid};
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
    return $users_db->[$uin];
}

# Function: setCensorByUIN($uin, $censor)
# Sets the censor preference for a user
# $uin is the UIN of the user
# $censor is true if the user wants the filter to be on.
sub setCensorByUIN {
    my ($self, $uin, $censor) = @_;
    $users_db->[$uin]->{prefer_censor} = $censor ? 'Y' : 'N';
}

1;
