package rockdb;
use strict;
use Carp qw(confess);
use DBI;
use rock_prefs;

sub db_get_conn() {

#   confess "Probably want to supply db name" unless $db_name;

   my $id = $main::db_username;
   my $pass = $main::db_password;
   my $db_name = $main::db_name;

   #
   # Tries connecting to oracle. Returns 0 if failure, 1 if connection successful.
   # Will disconnect from oracle if already connected, before trying to reconnect.
   #
  # &main::rock_shout(undef, "Connection to Database @ localhost.\n", 1);
  # print "localhost\n";
  # &main::rock_shout(undef, "Connection to Database @ localhost.\n", 1); 
   return DBI->connect_cached("DBI:mysql:$db_name:localhost", $id, $pass, {'RaiseError' => 1, 'ChopBlanks' => 1, 'AutoCommit' => 1});
}


sub sql_select_mult_row_linear {
    #
    # performs multiple row select and returns reference to **ONE** array of values.
    #

    my $dbh = db_get_conn() or confess "Could not connect to database!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my @a;

    while(my $b = $sth->fetchrow_arrayref()) { push @a, @$b; }

    $sth->finish();

    return wantarray?@a:\@a;
}



sub sql_select_hashref {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $ref;

    eval {
        my $dbh = db_get_conn() or confess "Could not connect to database!\n";

        my $sth = $dbh->prepare(shift(@_));  #caching here was getting yicky

        $sth->execute(@_);
        $ref = $sth->fetchrow_hashref();
        $sth->finish();
    };

    if($@) {
         my @c = caller(0);
         confess "FAILURE: [$@] \@file: $c[1]. package: $c[0]. line: $c[2].\n";
    }

    return undef unless $ref;

    # fix colnames to be UC'd
    my $newref = {};
    foreach my $key (keys %$ref) { $newref->{uc $key} = length($ref->{$key})?$ref->{$key}:undef; }

    return $newref;
}



sub sql_select_mult_row {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $dbh = db_get_conn() or confess "Could not connect to database!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my @a;

    while(my $b = $sth->fetchrow_arrayref()) { push @a, [@$b]; }

    $sth->finish();

    return \@a;
}


sub sql_select_row {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $dbh = db_get_conn() or confess "Could not connect to oracle!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my $b = $sth->fetchrow_arrayref();

    $sth->finish();

    return undef if !defined($b);

    return wantarray?@$b:$b->[0];
}


sub db_get_conn_local() {

#   confess "Probably want to supply db name" unless $db_name;

   my $id = $main::db_local_username;
   my $pass = $main::db_local_password;
   my $db_name = $main::db_local_name;

   #
   # Tries connecting to oracle. Returns 0 if failure, 1 if connection successful.
   # Will disconnect from oracle if already connected, before trying to reconnect.
   #
   #&main::rock_shout(undef, "Connection to Database @ localhost.\n", 1); 
   return DBI->connect_cached("DBI:mysql:$db_name:localhost", $id, $pass, {'RaiseError' => 1, 'ChopBlanks' => 1, 'AutoCommit' => 1});
}


sub sql_select_mult_row_linear_local {
    #
    # performs multiple row select and returns reference to **ONE** array of values.
    #

    my $dbh = db_get_conn_local() or confess "Could not connect to database!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my @a;

    while(my $b = $sth->fetchrow_arrayref()) { push @a, @$b; }

    $sth->finish();

    return wantarray?@a:\@a;
}



sub sql_select_hashref_local {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $ref;

    eval {
        my $dbh = db_get_conn_local() or confess "Could not connect to database!\n";

        my $sth = $dbh->prepare(shift(@_));  #caching here was getting yicky

        $sth->execute(@_);
        $ref = $sth->fetchrow_hashref();
        $sth->finish();
    };

    if($@) {
         my @c = caller(0);
         confess "FAILURE: [$@] \@file: $c[1]. package: $c[0]. line: $c[2].\n";
    }

    return undef unless $ref;

    # fix colnames to be UC'd
    my $newref = {};
    foreach my $key (keys %$ref) { $newref->{uc $key} = length($ref->{$key})?$ref->{$key}:undef; }

    return $newref;
}



sub sql_select_mult_row_local {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $dbh = db_get_conn_local() or confess "Could not connect to database!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my @a;

    while(my $b = $sth->fetchrow_arrayref()) { push @a, [@$b]; }

    $sth->finish();

    return \@a;
}


sub sql_select_row_local {
    #
    # performs multiple row select and returns reference to an array, containing references to each row.
    #

    my $dbh = db_get_conn_local() or confess "Could not connect to oracle!\n";

    my $query = shift(@_);
    my $sth = $dbh->prepare_cached($query);

    eval {
        $sth->execute(@_);
    };
    confess "DB Error: ($@).\nTried preparing query [$query] with args (@_)\n" if $@;

    my $b = $sth->fetchrow_arrayref();

    $sth->finish();

    return undef if !defined($b);

    return wantarray?@$b:$b->[0];
}


1;

