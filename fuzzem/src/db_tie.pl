# sets up db stuff..
use DB_File;
use strict;

print "BEGAN Tying DB_File/MLDBM databases.\n";

unlink(&insure_filename("./dbs/help.r2")); 

tie(%{$main::help}, "DB_File",
	&insure_filename("./dbs/help.r2"),
	O_RDWR|O_CREAT, 0775, $DB_HASH)
		or die "Cannot tie help file [help.r2]: $!\n";

print "help.r2 tied.\n";

tie(%main::ip_resolved, "DB_File",
	&insure_filename("./dbs/ips_resolved.r2"),
	O_RDWR|O_CREAT, 0775, $DB_HASH)
		or die "Cannot tie [ips_resolved.r2]: $!\n";

print "ips_resolved.r2 tied.\n";

tie(%main::ip_connected, "DB_File",
	&insure_filename("./dbs/ips_connected.r2"),
	O_RDWR|O_CREAT, 0775, $DB_HASH)
		or die "Cannot tie [ips_connected.r2]: $!\n";

print "ips_connected.r2 tied.\n";

tie(%main::pdescs_req, "DB_File",
	&insure_filename("./dbs/pdesc_req.rdb"),
	O_RDWR|O_CREAT, 0775, $DB_HASH)
		or die "Cannot tie [pdesc_req.rdb]: $!\n";

print "pdescs_req tied.\n";

tie(%main::pdescs, "DB_File",
	&insure_filename("./dbs/pdescs.rdb"),
	O_RDWR|O_CREAT, 0775, $DB_HASH)
		or die "Cannot tie [pdescs.rdb]: $!\n";

print "pdescs.rdb tied .\n";

while (!(tie(%main::email_addrs, "DB_File",
		&insure_filename("./userinfo/email_addrs.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./userinfo/email_addrs.r2"));
}



while (!(tie(%main::mailing_list, "DB_File",
		&insure_filename("./userinfo/mailing_list.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./userinfo/mailing_list.r2"));
}

unlink(&insure_filename("./dbs/obj_recd.r2"));
unlink(&insure_filename("./dbs/obj_limits.r2"));

tie(%main::rock_mdim, 'MLDBM',
	&insure_filename("./dbs/rock_mdim.db"),
	O_CREAT|O_RDWR, 0640)
		or warn $!;

while (!(tie(%main::obj_unique, "DB_File",
		&insure_filename("./dbs/obj_unique.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/obj_unique.r2"));
}

while (!(tie(%main::recnum_toname, "DB_File",
		&insure_filename("./dbs/recnum_toname.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/recnum_toname.r2"));
}

while (!(tie(%main::obj_recd, "DB_File",
		&insure_filename("./dbs/obj_recd.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/obj_recd.r2"));
}

while (!(tie(%main::obj_limits, "DB_File",
		&insure_filename("./dbs/obj_limits.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/obj_limits.r2"));
}

while (!($main::rockstats_handle =
		tie(%main::rock_stats, "DB_File",
		&insure_filename("./dbs/rock_stats.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/rock_stats.r2"));
}

while (!(tie(%main::bounties, "DB_File",
		&insure_filename("./dbs/player_bounties.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/player_bounties.r2"));
}

while (!(tie(%main::bounty_codes, "DB_File",
		&insure_filename("./dbs/bounty_codes.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/bounty_codes.r2"));
}

while (!($main::genvotes_handle =
		tie(%main::general_votes, "DB_File",
		&insure_filename("./dbs/general_votes.r2"),
		O_RDWR|O_CREAT, 0775, $DB_HASH))) {
	unlink(&insure_filename("./dbs/general_votes.r2"));
}

print "DONE Tying DB_File/MLDBM databases.\n";


sub dbs_untie {
	untie %main::telnetscores;
	return;
}

1;
