-- phpMyAdmin SQL Dump
-- version 5.0.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jul 22, 2020 at 01:57 PM
-- Server version: 8.0.20
-- PHP Version: 7.4.8

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `r2_dillfrog`
--
CREATE DATABASE IF NOT EXISTS `r2_dillfrog` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `r2_dillfrog`;
-- --------------------------------------------------------

--
-- Table structure for table `accounts`
--

CREATE TABLE `accounts` (
  `id_member` int NOT NULL,
  `member_name` varchar(255) NOT NULL DEFAULT '',
  `email` varchar(255) NOT NULL,
  `passwd` varchar(255) NOT NULL DEFAULT '',
  `active` varchar(255) NOT NULL,
  `userid_formatted` varchar(255) NOT NULL,
  `prefer_censor` varchar(255) NOT NULL,
  `gender` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `accounts`
--

INSERT INTO `accounts` (`id_member`, `member_name`, `email`, `passwd`, `active`, `userid_formatted`, `prefer_censor`, `gender`) VALUES
(1, 'admin', 'admin@admin.com', '5f4dcc3b5aa765d61d8327deb882cf99', '1', 'admin', '0', 'N'),
(2, 'player', 'player@player.com', '5f4dcc3b5aa765d61d8327deb882cf99', '1', 'player', '', 'N');

-- --------------------------------------------------------

--
-- Table structure for table `altwatch`
--

CREATE TABLE `altwatch` (
  `ip` varchar(15) NOT NULL DEFAULT '',
  `namea` varchar(20) NOT NULL DEFAULT '',
  `nameb` varchar(20) NOT NULL DEFAULT '',
  `ldate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `auctions`
--

CREATE TABLE `auctions` (
  `auction_id` int UNSIGNED NOT NULL,
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `min_price` int UNSIGNED NOT NULL DEFAULT '0',
  `bid_increment` int UNSIGNED NOT NULL DEFAULT '0',
  `seller_uin` int UNSIGNED NOT NULL DEFAULT '0',
  `item_name` varchar(128) NOT NULL DEFAULT '',
  `item_desc` varchar(255) NOT NULL DEFAULT '',
  `item_data` longblob NOT NULL,
  `high_bid_uin` int UNSIGNED DEFAULT NULL,
  `high_bid` int UNSIGNED DEFAULT NULL,
  `claimed_item` char(1) DEFAULT 'N',
  `returned_cryl` char(1) DEFAULT 'N'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `auction_bids`
--

CREATE TABLE `auction_bids` (
  `bid_id` int UNSIGNED NOT NULL,
  `auction_id` int UNSIGNED NOT NULL DEFAULT '0',
  `bidder_uin` int UNSIGNED NOT NULL DEFAULT '0',
  `max_bid` int UNSIGNED NOT NULL DEFAULT '0',
  `bid_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `bad_passwords`
--

CREATE TABLE `bad_passwords` (
  `ipc` varchar(11) NOT NULL DEFAULT '',
  `pdate` date NOT NULL DEFAULT '0000-00-00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `daily_scores`
--

CREATE TABLE `daily_scores` (
  `score_id` int UNSIGNED NOT NULL,
  `score_date` date NOT NULL DEFAULT '0000-00-00',
  `uin` int UNSIGNED NOT NULL DEFAULT '0',
  `max_hp` int UNSIGNED DEFAULT NULL,
  `max_mana` int UNSIGNED DEFAULT NULL,
  `dp` float NOT NULL DEFAULT '0',
  `exp_gained` int UNSIGNED NOT NULL DEFAULT '0',
  `level` int UNSIGNED NOT NULL DEFAULT '0',
  `min_online` int UNSIGNED NOT NULL DEFAULT '0',
  `pvpdeaths` int UNSIGNED NOT NULL DEFAULT '0',
  `pvpkills` int UNSIGNED NOT NULL DEFAULT '0',
  `race` int UNSIGNED NOT NULL DEFAULT '0',
  `repu` int NOT NULL DEFAULT '0',
  `turns_max` int UNSIGNED NOT NULL DEFAULT '0',
  `turns_used` int UNSIGNED NOT NULL DEFAULT '0',
  `worth` int UNSIGNED NOT NULL DEFAULT '0',
  `kno` int UNSIGNED NOT NULL DEFAULT '0',
  `maj` int UNSIGNED NOT NULL DEFAULT '0',
  `cha` int UNSIGNED NOT NULL DEFAULT '0',
  `agi` int UNSIGNED NOT NULL DEFAULT '0',
  `str` int UNSIGNED NOT NULL DEFAULT '0',
  `def` int UNSIGNED NOT NULL DEFAULT '0',
  `kmec` int UNSIGNED NOT NULL DEFAULT '0',
  `ksoc` int UNSIGNED NOT NULL DEFAULT '0',
  `kmed` int UNSIGNED NOT NULL DEFAULT '0',
  `kcom` int UNSIGNED NOT NULL DEFAULT '0',
  `moff` int UNSIGNED NOT NULL DEFAULT '0',
  `mdef` int UNSIGNED NOT NULL DEFAULT '0',
  `mele` int UNSIGNED NOT NULL DEFAULT '0',
  `mmen` int UNSIGNED NOT NULL DEFAULT '0',
  `dphy` int UNSIGNED NOT NULL DEFAULT '0',
  `dene` int UNSIGNED NOT NULL DEFAULT '0',
  `dmen` int UNSIGNED NOT NULL DEFAULT '0',
  `capp` int UNSIGNED NOT NULL DEFAULT '0',
  `catt` int UNSIGNED NOT NULL DEFAULT '0',
  `aupp` int UNSIGNED NOT NULL DEFAULT '0',
  `alow` int UNSIGNED NOT NULL DEFAULT '0',
  `supp` int UNSIGNED NOT NULL DEFAULT '0',
  `slow` int UNSIGNED NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `event_log`
--

CREATE TABLE `event_log` (
  `entry_id` int UNSIGNED NOT NULL,
  `entry_type` enum('New Character','Sell Item','PKill','Suspicious','Monolith Capture','First Kill','Become General','Become Soldier','Complete Quest','Make Alliance','Manage Alliance','Complete Course','Change PVP Level Restirction','Give Item','Give Cryl','Daily Win','Idea','Bug') NOT NULL DEFAULT 'New Character',
  `entry_desc` varchar(255) NOT NULL DEFAULT '',
  `uin_by` int UNSIGNED DEFAULT NULL,
  `arg_a` int DEFAULT NULL,
  `arg_b` int DEFAULT NULL,
  `arg_c` int DEFAULT NULL,
  `entry_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `game_server_settings`
--

CREATE TABLE `game_server_settings` (
  `name` varchar(255) NOT NULL DEFAULT '',
  `value` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `game_server_settings`
--

INSERT INTO `game_server_settings` (`name`, `value`) VALUES
('armageddon_started_by_race', ''),
('armageddon_started_by_race', ''),
('armageddon_started_by_race', '');

-- --------------------------------------------------------

--
-- Table structure for table `item_names_by_rec`
--

CREATE TABLE `item_names_by_rec` (
  `item_id` int NOT NULL DEFAULT '0',
  `item_name` varchar(255) NOT NULL DEFAULT '',
  `item_desc` text NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `lottery`
--

CREATE TABLE `lottery` (
  `name` varchar(20) NOT NULL DEFAULT '',
  `edate` date NOT NULL DEFAULT '0000-00-00',
  `won` varchar(20) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `mailing_list`
--

CREATE TABLE `mailing_list` (
  `email` varchar(80) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `members`
--

CREATE TABLE `members` (
  `id_member` int NOT NULL,
  `member_name` varchar(255) NOT NULL DEFAULT '',
  `email` varchar(255) NOT NULL,
  `passwd` varchar(255) NOT NULL DEFAULT '',
  `active` varchar(255) NOT NULL,
  `userid_formatted` varchar(255) NOT NULL,
  `prefer_censor` varchar(255) NOT NULL,
  `gender` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `body` varchar(255) NOT NULL,
  `id_topic` int NOT NULL,
  `subject` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `monolith_capture_status`
--

CREATE TABLE `monolith_capture_status` (
  `name` varchar(100) NOT NULL DEFAULT '',
  `owned_by_race` int NOT NULL DEFAULT '0',
  `date_captured` datetime DEFAULT NULL,
  `date_contested` datetime DEFAULT NULL,
  `captured_by_uin` int UNSIGNED DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `monolith_capture_status`
--

INSERT INTO `monolith_capture_status` (`name`, `owned_by_race`, `date_captured`, `date_contested`, `captured_by_uin`) VALUES
('shadow', 4, '2020-07-10 19:29:13', NULL, 124),
('spectral', 1, '2020-07-03 06:47:23', NULL, 121),
('pearled', 1, '2020-06-27 15:03:31', NULL, 121),
('temporal', 6, '2020-06-27 11:33:45', NULL, 22),
('vindicator', 2, '2020-07-17 21:08:32', NULL, 32),
('advocate', 1, '2020-07-10 20:11:44', NULL, 121),
('granite', 4, '2020-07-12 18:24:19', NULL, 124),
('optical', 1, '2020-07-02 22:31:22', NULL, 121),
('hallucination', 0, NULL, NULL, NULL),
('protector', 1, '2020-07-02 22:26:45', NULL, 121),
('shadow', 4, '2020-07-10 19:29:13', NULL, 124),
('spectral', 1, '2020-07-03 06:47:23', NULL, 121),
('pearled', 1, '2020-06-27 15:03:31', NULL, 121),
('temporal', 6, '2020-06-27 11:33:45', NULL, 22),
('vindicator', 2, '2020-07-17 21:08:32', NULL, 32),
('advocate', 1, '2020-07-10 20:11:44', NULL, 121),
('granite', 4, '2020-07-12 18:24:19', NULL, 124),
('optical', 1, '2020-07-02 22:31:22', NULL, 121),
('hallucination', 0, NULL, NULL, NULL),
('protector', 1, '2020-07-02 22:26:45', NULL, 121),
('shadow', 4, '2020-07-10 19:29:13', NULL, 124),
('spectral', 1, '2020-07-03 06:47:23', NULL, 121),
('pearled', 1, '2020-06-27 15:03:31', NULL, 121),
('temporal', 6, '2020-06-27 11:33:45', NULL, 22),
('vindicator', 2, '2020-07-17 21:08:32', NULL, 32),
('advocate', 1, '2020-07-10 20:11:44', NULL, 121),
('granite', 4, '2020-07-12 18:24:19', NULL, 124),
('optical', 1, '2020-07-02 22:31:22', NULL, 121),
('hallucination', 0, NULL, NULL, NULL),
('protector', 1, '2020-07-02 22:26:45', NULL, 121);

-- --------------------------------------------------------

--
-- Table structure for table `on_ask_responses`
--

CREATE TABLE `on_ask_responses` (
  `trigger_id` int UNSIGNED NOT NULL,
  `item_id` int NOT NULL DEFAULT '0',
  `response_match` varchar(255) NOT NULL DEFAULT '',
  `response_type` enum('Say','Echo','Command') NOT NULL DEFAULT 'Say',
  `response_text` longtext NOT NULL,
  `match_order` int UNSIGNED NOT NULL DEFAULT '0',
  `is_visible` char(1) NOT NULL DEFAULT 'Y'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `on_ask_responses`
--

INSERT INTO `on_ask_responses` (`trigger_id`, `item_id`, `response_match`, `response_type`, `response_text`, `match_order`, `is_visible`) VALUES
(1, -1, 'frog', 'Say', 'Frogs are yucky little motherfathers.\nI like frogs sometimes.\nFrogs make me happy.\nWill you be my froggy friend?', 0, 'Y'),
(7, -1, 'jello', 'Command', 'laugh\r\nsay Jello makes jiggles!\r\nemote squiggles around like a jellofish.', 5, 'Y'),
(8, 20, 'tasty|yummy', 'Say', 'I\'m tasty. Eat me.\nI taste like fresh roasted peanuts.\nDon\'t eat me.. it\'s \"Don\'t Eat Droids\" Week! (again!)', 0, 'Y'),
(9, 58, 'being gay', 'Command', 'That my dear, is none of your business.\nslap %ASKER\necho Clucky straddles %ASKER, \"Wouldn\'t you like to know.\"', 0, 'N'),
(15, 675, 'ghtheen craft|ghtheen|hide|sew', 'Say', 'For the small fee of 150 cryl, and if you provide me with the hide of three frost ghtheens, I can make you a warm and protective mantle.', 0, 'Y'),
(14, 58, 'Ker\'el', 'Echo', 'Clucky smiles, clucks loudly and begins her tale, \"Ker\'el, the king, I know him well. He was so kind, I\'d call him swell. He built an alliance of many races. Combining people of different faces. He erected the monoliths to secure the alliance. Unfortunately all he got was some nasty defiance. They overthrew his rule and shot him dead. Now the thought of those monoliths only fill me with dread. Whatever could someone do if they got them all? They would have so much power, they could cause us all to fall.\"', 0, 'Y'),
(16, 650, 'chemicals|chemistry', 'Command', 'Chemistry is all about the elements. It\'s like, if peanut butter were an element, and bread were an element, you could make peanut butter sandwiches. That\'d be like, a PB2 compound, right?\nChemistry\'s an amazing thing.. it\'s uncontrollable.. you can\'t control it!', 0, 'Y'),
(17, 650, 'kler', 'Say', 'Kler was my worst student.', 10, 'Y'),
(18, 674, 'ferrite presses|press|machine|ferrite', 'Say', 'This press? We use it to stamp our shields. It compacts together several layers of ferrite, producing a shield second to none. It\'s a shame the machine\'s broken down.', 0, 'Y'),
(19, 674, 'repairs|fix|broken', 'Command', 'Ah, well, you see, the drive system for the hydraulic pump is out of commission. I\'d need a sprocket, a chain link to fix the chain, and a crankshaft for the pump. Oh, and a nice, big wrench to reassemble the system.', 0, 'Y'),
(20, 676, 'the war|war', 'Say', 'We have been fighting for over a dozen years. When our enemies first emerged, they crushed us on all fronts. We had to retreat into our fortresses, like this one. Eventually, we learned how to fight them, and we thought we could defeat them once and for all in one great battle.', 0, 'Y'),
(32, 676, 'battle', 'Say', 'A month ago, we summoned battalions from all of our fortresses, to end the war with one great battle. Thousands of Troitians massed along a huge battle front, and we were very nearly successful. Our garrison commander, Elthros, led the charge, sabre upraised. Then, all of the sudden, a pulse of dark magic swept through our ranks. I watched young soldiers age hundreds of years instantly, turning to bones, and then dust. Elthros himself collapsed into a heap of dust at the feet of Garron.', 25, 'Y'),
(21, 676, 'commanders|commander|sword|elthros', 'Say', 'Once I recover, I intend to hunt Garron to either his death or my own. I feel I owe Elthros\' family a debt; I wish to return his sword to his family.', 0, 'Y'),
(22, 676, 'doyos|enemy|eldar|garron', 'Say', 'We don\'t know exactly where the Eldars came from. We do know that there are three of them. Most likely, they were outcast from the Eldar home plane, only to arrive on our doorstep.', 0, 'Y'),
(23, 676, 'hourglass|cracked hourglass', 'Say', 'An envoy from the Eldar plane presented the Troitians with this cracked hourglass. According to their scholars, it neutralizes temporal magic. It\'s the only reason I was able to escape the battle.', 0, 'N'),
(24, -1, 'sex|reproduction', 'Say', 'How do you think we NPCs spawn anyway? Magic?\nWhen a mommy NPC loves a daddy NPC, they do some special hugging, and out pops a baby NPC!', 10, 'Y'),
(25, 58, 'plat', 'Say', 'Plat\'s a guy who\'s very naughty. Ignores his builders, acts very haughty.', 5, 'Y'),
(26, 491, 'sadness', 'Say', 'My love is lost, from long ago.. she left this world and me behind. I miss her dearly. If you could track down something that would remind me of her, I\'d truly appreciate it. There was this flower that she really loved. It had blue petals, as blue as her beautiful eyes, and a stem of silvery white. I\'m not sure where they grow. If only we had some sort of flower expert here in town. But alas, there is no one of that sort here in Westland City. I once heard rumor of a place far away on a distant world that houses a multitude of scholars and beings of science. An academy on an extra-dimensional level. Perhaps there you would find such a person.', 0, 'Y'),
(27, 689, 'darplant', 'Echo', '{12}The botanist thinks for a moment then nods, \"Yes.. the darplant is a very common sort. It is closely related to the desert dwelling cacti. Very friendly, once you get to know them. They have a wonderful intoxicating scent. If it wasn\'t for their thick thorny stems, there would be no darplants left. Everyone would be picking them to extinction. I believe we have a few specimens sold here in the academy shop.\"', 0, 'Y'),
(28, 689, 'vi-plant', 'Echo', '{12}The Shivaen giggles a bit and nods, \"I love the flowering vi-plants. They really a cranky bunch. Slithering through the forest, eatting those silly enough to get in the way. Not too dangerous, though, if you know what your doing. Don\'t be to harsh on them, the vi-plants aren\'t evil, they are just a bit hungry. You can find them on the Plane of Vastis.\"', 0, 'Y'),
(29, 58, 'westland bard', 'Say', 'The Westland Bard is kind of blue, but I\'m not sure if thats truly true. Go and check, make it speedy. From what\'s been said, he\'s really needy.', 0, 'Y'),
(30, 689, 'nightsky flower', 'Echo', '{12}\"The nightsky flower is rare indeed. It lives in the dark swamplands of only a few scattered planes.\" The Shivaen twirls her hair a bit, and whispers something to a nearby rosebush. \"They have dark blue petals and a stem the color of a shining star. Not the most conversational of flowers. Very quiet and reserved. I like them though. If you need to find one, look very carefully around swamplands. If you don\'t take your time, I am sure the little sweeties will be able to avoid you.\"', 0, 'Y'),
(31, 702, 'new district', 'Say', 'Isn\'t she a beautiful thing? This district lets me organize my items in a very organizable, organization of organized items.', 0, 'Y');

-- --------------------------------------------------------

--
-- Table structure for table `players`
--

CREATE TABLE `players` (
  `NAME` varchar(20) DEFAULT NULL,
  `LEV` int DEFAULT NULL,
  `KNO` int DEFAULT NULL,
  `MAJ` int DEFAULT NULL,
  `CHA` int DEFAULT NULL,
  `AGI` int DEFAULT NULL,
  `STR` int DEFAULT NULL,
  `DEF` int DEFAULT NULL,
  `WORTH` int DEFAULT NULL,
  `REPU` int DEFAULT NULL,
  `ADMIN` char(1) DEFAULT NULL,
  `EMAIL` varchar(80) DEFAULT NULL,
  `RACE` int DEFAULT NULL,
  `PVPKILLS` int DEFAULT NULL,
  `PVPDEATHS` int DEFAULT NULL,
  `DP` float DEFAULT NULL,
  `ARENA_PTS` float DEFAULT NULL,
  `INVENTORY` text,
  `PW` varchar(60) DEFAULT NULL,
  `LAST_SAVED` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `rock_certs`
--

CREATE TABLE `rock_certs` (
  `name` varchar(30) NOT NULL DEFAULT '',
  `c_type` char(1) NOT NULL DEFAULT '',
  `c_val` int NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `accounts`
--
ALTER TABLE `accounts`
  ADD PRIMARY KEY (`id_member`),
  ADD UNIQUE KEY `username` (`member_name`);

--
-- Indexes for table `altwatch`
--
ALTER TABLE `altwatch`
  ADD KEY `idx_altwatch_namea` (`namea`),
  ADD KEY `idx_altwatch_nameb` (`nameb`);

--
-- Indexes for table `auctions`
--
ALTER TABLE `auctions`
  ADD PRIMARY KEY (`auction_id`);

--
-- Indexes for table `auction_bids`
--
ALTER TABLE `auction_bids`
  ADD PRIMARY KEY (`bid_id`);

--
-- Indexes for table `daily_scores`
--
ALTER TABLE `daily_scores`
  ADD PRIMARY KEY (`score_id`);

--
-- Indexes for table `event_log`
--
ALTER TABLE `event_log`
  ADD PRIMARY KEY (`entry_id`);

--
-- Indexes for table `item_names_by_rec`
--
ALTER TABLE `item_names_by_rec`
  ADD PRIMARY KEY (`item_id`);

--
-- Indexes for table `lottery`
--
ALTER TABLE `lottery`
  ADD PRIMARY KEY (`name`,`edate`);

--
-- Indexes for table `mailing_list`
--
ALTER TABLE `mailing_list`
  ADD PRIMARY KEY (`email`);

--
-- Indexes for table `members`
--
ALTER TABLE `members`
  ADD PRIMARY KEY (`id_member`),
  ADD UNIQUE KEY `username` (`member_name`);

--
-- Indexes for table `on_ask_responses`
--
ALTER TABLE `on_ask_responses`
  ADD PRIMARY KEY (`trigger_id`);

--
-- Indexes for table `players`
--
ALTER TABLE `players`
  ADD UNIQUE KEY `NAME_IDX` (`NAME`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `accounts`
--
ALTER TABLE `accounts`
  MODIFY `id_member` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `auctions`
--
ALTER TABLE `auctions`
  MODIFY `auction_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auction_bids`
--
ALTER TABLE `auction_bids`
  MODIFY `bid_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `daily_scores`
--
ALTER TABLE `daily_scores`
  MODIFY `score_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `event_log`
--
ALTER TABLE `event_log`
  MODIFY `entry_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `members`
--
ALTER TABLE `members`
  MODIFY `id_member` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `on_ask_responses`
--
ALTER TABLE `on_ask_responses`
  MODIFY `trigger_id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;


-- phpMyAdmin SQL Dump
-- version 5.0.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jul 22, 2020 at 01:58 PM
-- Server version: 8.0.20
-- PHP Version: 7.4.8

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `r2_fuzzem`
--
CREATE DATABASE IF NOT EXISTS `r2_fuzzem` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `r2_fuzzem`;
-- --------------------------------------------------------

--
-- Table structure for table `r2_accounts`
--

CREATE TABLE `r2_accounts` (
  `uin` int UNSIGNED NOT NULL,
  `userid` varchar(40) NOT NULL,
  `userid_formatted` varchar(40) NOT NULL,
  `gender` char(1) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(40) NOT NULL,
  `prefer_censor` tinyint NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_altwatch`
--

CREATE TABLE `r2_altwatch` (
  `ip` varchar(15) NOT NULL DEFAULT '',
  `namea` varchar(20) NOT NULL DEFAULT '',
  `nameb` varchar(20) NOT NULL DEFAULT '',
  `ldate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_auctions`
--

CREATE TABLE `r2_auctions` (
  `auction_id` int UNSIGNED NOT NULL,
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `min_price` int UNSIGNED NOT NULL DEFAULT '0',
  `bid_increment` int UNSIGNED NOT NULL DEFAULT '0',
  `seller_uin` int UNSIGNED NOT NULL DEFAULT '0',
  `item_name` varchar(128) NOT NULL DEFAULT '',
  `item_desc` varchar(255) NOT NULL DEFAULT '',
  `item_data` longblob NOT NULL,
  `high_bid_uin` int UNSIGNED DEFAULT NULL,
  `high_bid` int UNSIGNED DEFAULT NULL,
  `claimed_item` char(1) DEFAULT 'N',
  `returned_cryl` char(1) DEFAULT 'N'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_auction_bids`
--

CREATE TABLE `r2_auction_bids` (
  `bid_id` int UNSIGNED NOT NULL,
  `auction_id` int UNSIGNED NOT NULL DEFAULT '0',
  `bidder_uin` int UNSIGNED NOT NULL DEFAULT '0',
  `max_bid` int UNSIGNED NOT NULL DEFAULT '0',
  `bid_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_bad_passwords`
--

CREATE TABLE `r2_bad_passwords` (
  `ipc` varchar(11) NOT NULL DEFAULT '',
  `pdate` date NOT NULL DEFAULT '0000-00-00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_daily_scores`
--

CREATE TABLE `r2_daily_scores` (
  `score_id` int UNSIGNED NOT NULL,
  `score_date` date NOT NULL DEFAULT '0000-00-00',
  `uin` int UNSIGNED NOT NULL DEFAULT '0',
  `max_hp` int UNSIGNED DEFAULT NULL,
  `max_mana` int UNSIGNED DEFAULT NULL,
  `dp` float NOT NULL DEFAULT '0',
  `exp_gained` int UNSIGNED NOT NULL DEFAULT '0',
  `level` int UNSIGNED NOT NULL DEFAULT '0',
  `min_online` int UNSIGNED NOT NULL DEFAULT '0',
  `pvpdeaths` int UNSIGNED NOT NULL DEFAULT '0',
  `pvpkills` int UNSIGNED NOT NULL DEFAULT '0',
  `race` int UNSIGNED NOT NULL DEFAULT '0',
  `repu` int NOT NULL DEFAULT '0',
  `turns_max` int UNSIGNED NOT NULL DEFAULT '0',
  `turns_used` int UNSIGNED NOT NULL DEFAULT '0',
  `worth` int UNSIGNED NOT NULL DEFAULT '0',
  `kno` int UNSIGNED NOT NULL DEFAULT '0',
  `maj` int UNSIGNED NOT NULL DEFAULT '0',
  `cha` int UNSIGNED NOT NULL DEFAULT '0',
  `agi` int UNSIGNED NOT NULL DEFAULT '0',
  `str` int UNSIGNED NOT NULL DEFAULT '0',
  `def` int UNSIGNED NOT NULL DEFAULT '0',
  `kmec` int UNSIGNED NOT NULL DEFAULT '0',
  `ksoc` int UNSIGNED NOT NULL DEFAULT '0',
  `kmed` int UNSIGNED NOT NULL DEFAULT '0',
  `kcom` int UNSIGNED NOT NULL DEFAULT '0',
  `moff` int UNSIGNED NOT NULL DEFAULT '0',
  `mdef` int UNSIGNED NOT NULL DEFAULT '0',
  `mele` int UNSIGNED NOT NULL DEFAULT '0',
  `mmen` int UNSIGNED NOT NULL DEFAULT '0',
  `dphy` int UNSIGNED NOT NULL DEFAULT '0',
  `dene` int UNSIGNED NOT NULL DEFAULT '0',
  `dmen` int UNSIGNED NOT NULL DEFAULT '0',
  `capp` int UNSIGNED NOT NULL DEFAULT '0',
  `catt` int UNSIGNED NOT NULL DEFAULT '0',
  `aupp` int UNSIGNED NOT NULL DEFAULT '0',
  `alow` int UNSIGNED NOT NULL DEFAULT '0',
  `supp` int UNSIGNED NOT NULL DEFAULT '0',
  `slow` int UNSIGNED NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_event_log`
--

CREATE TABLE `r2_event_log` (
  `entry_id` int UNSIGNED NOT NULL,
  `entry_type` enum('New Character','Sell Item','PKill','Suspicious','Monolith Capture','First Kill','Become General','Become Soldier','Complete Quest','Make Alliance','Manage Alliance','Complete Course','Change PVP Level Restirction','Give Item','Give Cryl','Daily Win','Idea','Bug') NOT NULL DEFAULT 'New Character',
  `entry_desc` varchar(255) NOT NULL DEFAULT '',
  `uin_by` int UNSIGNED DEFAULT NULL,
  `arg_a` int DEFAULT NULL,
  `arg_b` int DEFAULT NULL,
  `arg_c` int DEFAULT NULL,
  `entry_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_game_server_settings`
--

CREATE TABLE `r2_game_server_settings` (
  `name` varchar(255) NOT NULL DEFAULT '',
  `value` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `r2_game_server_settings`
--

INSERT INTO `r2_game_server_settings` (`name`, `value`) VALUES
('armageddon_started_by_race', '');

-- --------------------------------------------------------

--
-- Table structure for table `r2_item_names_by_rec`
--

CREATE TABLE `r2_item_names_by_rec` (
  `item_id` int NOT NULL DEFAULT '0',
  `item_name` varchar(255) NOT NULL DEFAULT '',
  `item_desc` text NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_lottery`
--

CREATE TABLE `r2_lottery` (
  `name` varchar(20) NOT NULL DEFAULT '',
  `edate` date NOT NULL DEFAULT '0000-00-00',
  `won` varchar(20) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_mailing_list`
--

CREATE TABLE `r2_mailing_list` (
  `email` varchar(80) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_members`
--

CREATE TABLE `r2_members` (
  `id_member` int NOT NULL,
  `member_name` varchar(255) NOT NULL DEFAULT '',
  `email` varchar(255) NOT NULL,
  `passwd` varchar(255) NOT NULL DEFAULT '',
  `active` varchar(255) NOT NULL,
  `userid_formatted` varchar(255) NOT NULL,
  `prefer_censor` varchar(255) NOT NULL,
  `gender` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `r2_members`
--

INSERT INTO `r2_members` (`id_member`, `member_name`, `email`, `passwd`, `active`, `userid_formatted`, `prefer_censor`, `gender`) VALUES
(1, 'admin', 'admin@admin.com', '5f4dcc3b5aa765d61d8327deb882cf99', '1', 'admin', '0', 'N'),
(2, 'player', 'player@player.com', '5f4dcc3b5aa765d61d8327deb882cf99', '1', 'player', '', 'N');

-- --------------------------------------------------------

--
-- Table structure for table `r2_messages`
--

CREATE TABLE `r2_messages` (
  `body` varchar(255) NOT NULL,
  `id_topic` int NOT NULL,
  `subject` varchar(255) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `r2_monolith_capture_status`
--

CREATE TABLE `r2_monolith_capture_status` (
  `name` varchar(100) NOT NULL DEFAULT '',
  `owned_by_race` int NOT NULL DEFAULT '0',
  `date_captured` datetime DEFAULT NULL,
  `date_contested` datetime DEFAULT NULL,
  `captured_by_uin` int UNSIGNED DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `r2_monolith_capture_status`
--

INSERT INTO `r2_monolith_capture_status` (`name`, `owned_by_race`, `date_captured`, `date_contested`, `captured_by_uin`) VALUES
('shadow', 0, '2020-07-21 12:50:50', NULL, 1),
('spectral', 0, '2020-07-21 12:51:29', NULL, 1),
('pearled', 0, '2020-07-21 12:51:11', NULL, 1),
('temporal', 0, '2020-07-21 12:52:01', NULL, 1),
('vindicator', 0, '2020-07-21 12:50:26', NULL, 1),
('advocate', 1, '2020-07-10 20:11:44', NULL, 121),
('granite', 0, '2020-07-21 12:52:32', NULL, 1),
('optical', 0, '2020-07-21 12:51:50', NULL, 1),
('hallucination', 0, NULL, NULL, NULL),
('protector', 0, '2020-07-21 12:52:15', NULL, 1);

-- --------------------------------------------------------

--
-- Table structure for table `r2_on_ask_responses`
--

CREATE TABLE `r2_on_ask_responses` (
  `trigger_id` int UNSIGNED NOT NULL,
  `item_id` int NOT NULL DEFAULT '0',
  `response_match` varchar(255) NOT NULL DEFAULT '',
  `response_type` enum('Say','Echo','Command') NOT NULL DEFAULT 'Say',
  `response_text` longtext NOT NULL,
  `match_order` int UNSIGNED NOT NULL DEFAULT '0',
  `is_visible` char(1) NOT NULL DEFAULT 'Y'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `r2_on_ask_responses`
--

INSERT INTO `r2_on_ask_responses` (`trigger_id`, `item_id`, `response_match`, `response_type`, `response_text`, `match_order`, `is_visible`) VALUES
(1, -1, 'frog', 'Say', 'Frogs are yucky little motherfathers.\nI like frogs sometimes.\nFrogs make me happy.\nWill you be my froggy friend?', 0, 'Y'),
(7, -1, 'jello', 'Command', 'laugh\r\nsay Jello makes jiggles!\r\nemote squiggles around like a jellofish.', 5, 'Y'),
(8, 20, 'tasty|yummy', 'Say', 'I\'m tasty. Eat me.\nI taste like fresh roasted peanuts.\nDon\'t eat me.. it\'s \"Don\'t Eat Droids\" Week! (again!)', 0, 'Y'),
(9, 58, 'being gay', 'Command', 'That my dear, is none of your business.\nslap %ASKER\necho Clucky straddles %ASKER, \"Wouldn\'t you like to know.\"', 0, 'N'),
(15, 675, 'ghtheen craft|ghtheen|hide|sew', 'Say', 'For the small fee of 150 cryl, and if you provide me with the hide of three frost ghtheens, I can make you a warm and protective mantle.', 0, 'Y'),
(14, 58, 'Ker\'el', 'Echo', 'Clucky smiles, clucks loudly and begins her tale, \"Ker\'el, the king, I know him well. He was so kind, I\'d call him swell. He built an alliance of many races. Combining people of different faces. He erected the monoliths to secure the alliance. Unfortunately all he got was some nasty defiance. They overthrew his rule and shot him dead. Now the thought of those monoliths only fill me with dread. Whatever could someone do if they got them all? They would have so much power, they could cause us all to fall.\"', 0, 'Y'),
(16, 650, 'chemicals|chemistry', 'Command', 'Chemistry is all about the elements. It\'s like, if peanut butter were an element, and bread were an element, you could make peanut butter sandwiches. That\'d be like, a PB2 compound, right?\nChemistry\'s an amazing thing.. it\'s uncontrollable.. you can\'t control it!', 0, 'Y'),
(17, 650, 'kler', 'Say', 'Kler was my worst student.', 10, 'Y'),
(18, 674, 'ferrite presses|press|machine|ferrite', 'Say', 'This press? We use it to stamp our shields. It compacts together several layers of ferrite, producing a shield second to none. It\'s a shame the machine\'s broken down.', 0, 'Y'),
(19, 674, 'repairs|fix|broken', 'Command', 'Ah, well, you see, the drive system for the hydraulic pump is out of commission. I\'d need a sprocket, a chain link to fix the chain, and a crankshaft for the pump. Oh, and a nice, big wrench to reassemble the system.', 0, 'Y'),
(20, 676, 'the war|war', 'Say', 'We have been fighting for over a dozen years. When our enemies first emerged, they crushed us on all fronts. We had to retreat into our fortresses, like this one. Eventually, we learned how to fight them, and we thought we could defeat them once and for all in one great battle.', 0, 'Y'),
(32, 676, 'battle', 'Say', 'A month ago, we summoned battalions from all of our fortresses, to end the war with one great battle. Thousands of Troitians massed along a huge battle front, and we were very nearly successful. Our garrison commander, Elthros, led the charge, sabre upraised. Then, all of the sudden, a pulse of dark magic swept through our ranks. I watched young soldiers age hundreds of years instantly, turning to bones, and then dust. Elthros himself collapsed into a heap of dust at the feet of Garron.', 25, 'Y'),
(21, 676, 'commanders|commander|sword|elthros', 'Say', 'Once I recover, I intend to hunt Garron to either his death or my own. I feel I owe Elthros\' family a debt; I wish to return his sword to his family.', 0, 'Y'),
(22, 676, 'doyos|enemy|eldar|garron', 'Say', 'We don\'t know exactly where the Eldars came from. We do know that there are three of them. Most likely, they were outcast from the Eldar home plane, only to arrive on our doorstep.', 0, 'Y'),
(23, 676, 'hourglass|cracked hourglass', 'Say', 'An envoy from the Eldar plane presented the Troitians with this cracked hourglass. According to their scholars, it neutralizes temporal magic. It\'s the only reason I was able to escape the battle.', 0, 'N'),
(24, -1, 'sex|reproduction', 'Say', 'How do you think we NPCs spawn anyway? Magic?\nWhen a mommy NPC loves a daddy NPC, they do some special hugging, and out pops a baby NPC!', 10, 'Y'),
(25, 58, 'plat', 'Say', 'Plat\'s a guy who\'s very naughty. Ignores his builders, acts very haughty.', 5, 'Y'),
(26, 491, 'sadness', 'Say', 'My love is lost, from long ago.. she left this world and me behind. I miss her dearly. If you could track down something that would remind me of her, I\'d truly appreciate it. There was this flower that she really loved. It had blue petals, as blue as her beautiful eyes, and a stem of silvery white. I\'m not sure where they grow. If only we had some sort of flower expert here in town. But alas, there is no one of that sort here in Westland City. I once heard rumor of a place far away on a distant world that houses a multitude of scholars and beings of science. An academy on an extra-dimensional level. Perhaps there you would find such a person.', 0, 'Y'),
(27, 689, 'darplant', 'Echo', '{12}The botanist thinks for a moment then nods, \"Yes.. the darplant is a very common sort. It is closely related to the desert dwelling cacti. Very friendly, once you get to know them. They have a wonderful intoxicating scent. If it wasn\'t for their thick thorny stems, there would be no darplants left. Everyone would be picking them to extinction. I believe we have a few specimens sold here in the academy shop.\"', 0, 'Y'),
(28, 689, 'vi-plant', 'Echo', '{12}The Shivaen giggles a bit and nods, \"I love the flowering vi-plants. They really a cranky bunch. Slithering through the forest, eatting those silly enough to get in the way. Not too dangerous, though, if you know what your doing. Don\'t be to harsh on them, the vi-plants aren\'t evil, they are just a bit hungry. You can find them on the Plane of Vastis.\"', 0, 'Y'),
(29, 58, 'westland bard', 'Say', 'The Westland Bard is kind of blue, but I\'m not sure if thats truly true. Go and check, make it speedy. From what\'s been said, he\'s really needy.', 0, 'Y'),
(30, 689, 'nightsky flower', 'Echo', '{12}\"The nightsky flower is rare indeed. It lives in the dark swamplands of only a few scattered planes.\" The Shivaen twirls her hair a bit, and whispers something to a nearby rosebush. \"They have dark blue petals and a stem the color of a shining star. Not the most conversational of flowers. Very quiet and reserved. I like them though. If you need to find one, look very carefully around swamplands. If you don\'t take your time, I am sure the little sweeties will be able to avoid you.\"', 0, 'Y'),
(31, 702, 'new district', 'Say', 'Isn\'t she a beautiful thing? This district lets me organize my items in a very organizable, organization of organized items.', 0, 'Y');

-- --------------------------------------------------------

--
-- Table structure for table `r2_players`
--

CREATE TABLE `r2_players` (
  `NAME` varchar(20) DEFAULT NULL,
  `LEV` int DEFAULT NULL,
  `KNO` int DEFAULT NULL,
  `MAJ` int DEFAULT NULL,
  `CHA` int DEFAULT NULL,
  `AGI` int DEFAULT NULL,
  `STR` int DEFAULT NULL,
  `DEF` int DEFAULT NULL,
  `WORTH` int DEFAULT NULL,
  `REPU` int DEFAULT NULL,
  `ADMIN` char(1) DEFAULT NULL,
  `EMAIL` varchar(80) DEFAULT NULL,
  `RACE` int DEFAULT NULL,
  `PVPKILLS` int DEFAULT NULL,
  `PVPDEATHS` int DEFAULT NULL,
  `DP` float DEFAULT NULL,
  `ARENA_PTS` float DEFAULT NULL,
  `INVENTORY` text,
  `PW` varchar(60) DEFAULT NULL,
  `LAST_SAVED` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `r2_players`
--

INSERT INTO `r2_players` (`NAME`, `LEV`, `KNO`, `MAJ`, `CHA`, `AGI`, `STR`, `DEF`, `WORTH`, `REPU`, `ADMIN`, `EMAIL`, `RACE`, `PVPKILLS`, `PVPDEATHS`, `DP`, `ARENA_PTS`, `INVENTORY`, `PW`, `LAST_SAVED`) VALUES
('Admin', 16, 14, 17, 14, 21, 22, 16, 0, 0, '1', NULL, 1, 0, 0, 2.53571, -100, '{12}You are carrying: {6}{17}(c) {17}shortsword{2}.\n{12}You are wearing: {6}{17}(c) {6}leather belt {7}[waist]{2}, {6}{17}(c) {6}foibly skin {7}[torso]{2}, {6}{17}(c) {6}small wooden shield {7}[off-hand]{2}, {6}{17}(c) {6}petrobeads {7}[neck]{2}.\n', '908142089', '2020-07-22 07:07:20'),
('Player', 1, 1, 1, 2, 1, 1, 2, 0, 0, '0', '', 6, 0, 0, 0.392857, -100, '{12}You are carrying: {6}{17}(c) {17}shortsword{2}.\n{12}You are wearing: {6}{17}(c) {6}foibly skin {7}[torso]{2}, {6}{17}(c) {6}leather belt {7}[waist]{2}, {6}{17}(c) {6}small wooden shield {7}[off-hand]{2}, {6}{17}(c) {6}petrobeads {7}[neck]{2}.\n', '947601318', '2020-07-21 13:12:12');

-- --------------------------------------------------------

--
-- Table structure for table `r2_rock_certs`
--

CREATE TABLE `r2_rock_certs` (
  `name` varchar(30) NOT NULL DEFAULT '',
  `c_type` char(1) NOT NULL DEFAULT '',
  `c_val` int NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `r2_accounts`
--
ALTER TABLE `r2_accounts`
  ADD PRIMARY KEY (`uin`);

--
-- Indexes for table `r2_altwatch`
--
ALTER TABLE `r2_altwatch`
  ADD KEY `idx_altwatch_namea` (`namea`),
  ADD KEY `idx_altwatch_nameb` (`nameb`);

--
-- Indexes for table `r2_auctions`
--
ALTER TABLE `r2_auctions`
  ADD PRIMARY KEY (`auction_id`);

--
-- Indexes for table `r2_auction_bids`
--
ALTER TABLE `r2_auction_bids`
  ADD PRIMARY KEY (`bid_id`);

--
-- Indexes for table `r2_daily_scores`
--
ALTER TABLE `r2_daily_scores`
  ADD PRIMARY KEY (`score_id`);

--
-- Indexes for table `r2_event_log`
--
ALTER TABLE `r2_event_log`
  ADD PRIMARY KEY (`entry_id`);

--
-- Indexes for table `r2_item_names_by_rec`
--
ALTER TABLE `r2_item_names_by_rec`
  ADD PRIMARY KEY (`item_id`);

--
-- Indexes for table `r2_lottery`
--
ALTER TABLE `r2_lottery`
  ADD PRIMARY KEY (`name`,`edate`);

--
-- Indexes for table `r2_mailing_list`
--
ALTER TABLE `r2_mailing_list`
  ADD PRIMARY KEY (`email`);

--
-- Indexes for table `r2_members`
--
ALTER TABLE `r2_members`
  ADD PRIMARY KEY (`id_member`),
  ADD UNIQUE KEY `username` (`member_name`);

--
-- Indexes for table `r2_on_ask_responses`
--
ALTER TABLE `r2_on_ask_responses`
  ADD PRIMARY KEY (`trigger_id`);

--
-- Indexes for table `r2_players`
--
ALTER TABLE `r2_players`
  ADD UNIQUE KEY `NAME_IDX` (`NAME`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `r2_accounts`
--
ALTER TABLE `r2_accounts`
  MODIFY `uin` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `r2_auctions`
--
ALTER TABLE `r2_auctions`
  MODIFY `auction_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `r2_auction_bids`
--
ALTER TABLE `r2_auction_bids`
  MODIFY `bid_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `r2_daily_scores`
--
ALTER TABLE `r2_daily_scores`
  MODIFY `score_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `r2_event_log`
--
ALTER TABLE `r2_event_log`
  MODIFY `entry_id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `r2_members`
--
ALTER TABLE `r2_members`
  MODIFY `id_member` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `r2_on_ask_responses`
--
ALTER TABLE `r2_on_ask_responses`
  MODIFY `trigger_id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;


CREATE USER 'rockserv'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON `r2_dillfrog`.* TO 'rockserv'@'localhost';
GRANT ALL PRIVILEGES ON `r2_fuzzem`.* TO 'rockserv'@'localhost';
