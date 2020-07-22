 ##################
 # STAT CONSTANTS #
 ##################
 use constant KNO => 0;
 use constant MAJ => 1;
 use constant CHA => 2;
 use constant AGI => 3;
 use constant STR => 4;
 use constant DEF => 5;
 
 use constant KMEC => 6;
 use constant KSOC => 7;
 use constant KMED => 8;
 use constant KCOM => 9;
 
 use constant MOFF => 10;
 use constant MDEF => 11;
 use constant MELE => 12;

 use constant CAPP => 13;
 use constant CATT => 14;
 
 use constant AUPP => 15;
 use constant ALOW => 16;

 use constant SUPP => 17;
 use constant SLOW => 18;
 
 use constant DPHY => 19;
 use constant DENE => 20;
 use constant DMEN => 21;
 
 use constant MMEN => 22;


 # hostilities
 use constant HOS_NONE => 0;
 use constant HOS_OFFENSIVE => 1;
 use constant HOS_DEFENSIVE => 2;
 use constant HOS_ALL => 3;

#aggression error codes
use constant AGGRESS_SUCCESS                => 0;
use constant AGGRESS_FAILED_ROOM_SAFE       => 1;   #implemented
use constant AGGRESS_FAILED_ROOM_SAFEDETAIN => 2;   #implemented
use constant AGGRESS_FAILED_ROOM_SEMISAFE   => 3;   #not implemented
use constant AGGRESS_FAILED_ROOM_NOPVP      => 4;   #implemented
use constant AGGRESS_FAILED_SELF_IMMORTAL   => 5;   #implemented
use constant AGGRESS_FAILED_VICT_IMMORTAL   => 6;   #implemented
use constant AGGRESS_FAILED_SELF_NEWBIE     => 7;   #implemented
use constant AGGRESS_FAILED_VICT_NEWBIE     => 8;   #implemented
use constant AGGRESS_FAILED_PVP_RANGE       => 9;   #implemented
use constant AGGRESS_FAILED_PVP_LAST        => 10;  #implemented
use constant AGGRESS_FAILED_PVP_LIMIT       => 11;  #implemented
use constant AGGRESS_FAILED_VICT_DEAD       => 12;  #implemented
use constant AGGRESS_FAILED_VICT_NOTPRESENT => 13;  #implemented
use constant AGGRESS_FAILED_VICT_SELF       => 14;  #implemented
use constant AGGRESS_FAILED_RACE            => 15;  #implemented
use constant AGGRESS_FAILED_ALLIED          => 16;  #implemented
use constant AGGRESS_FAILED_SAME_GROUP      => 17;  #implemented

#it's generic cuz there could be specific ones!
@main::AGGRESS_GENERIC_ERROR = (
    undef,                                              #AGGRESS_SUCCESS has no error
    'This room is a sanctuary, not meant for combat.',  #AGGRESS_FAILED_ROOM_SAFE
    'It would not be polite to attack in this room.',                                              #AGGRESS_FAILED_ROOM_SAFEDETAIN has no error
    'Plat can implement me later',                      #AGGRESS_FAILED_ROOM_SEMISAFE    
    'You may not combat other players in this room.',   #AGGRESS_FAILED_ROOM_NOPVP
    'Immortals may not aggress.',                       #AGGRESS_FAILED_SELF_IMMORTAL
    '%s is immortal, and may not be attacked.',         #AGGRESS_FAILED_VICT_IMMORTAL
    'Newbies are not allowed to PvP.',                  #AGGRESS_FAILED_SELF_NEWBIE
    'Newbies are not allowed to PvP.',                  #AGGRESS_FAILED_VICT_NEWBIE
    '%s is out of your range of combat honor.',         #AGGRESS_FAILED_PVP_RANGE
    'You killed this player in your last PvP. Pick on someone else.', #AGGRESS_FAILED_PVP_LAST
    'You have no more PVP fights allotted for you today. Please try again tomorrow. Did you ever consider becoming a soldier?', #AGGRESS_FAILED_PVP_LIMIT
    'Attack a dead corpse? Sicko!',                     #AGGRESS_FAILED_VICT_DEAD
    'No lifeforms here are named %s.',                  #AGGRESS_FAILED_VICT_NOTPRESENT
    'Attack yourself? Are you nuts?',                   #AGGRESS_FAILED_VICT_SELF
    'But %s is the same race as you!',                  #AGGRESS_FAILED_RACE
    'But your races are allied (for now)!',             #AGGRESS_FAILED_ALLIED
    'But you are in the same group as %s!',             #AGGRESS_FAILED_SAME_GROUP
);

#object types
use constant OTYPE_ROOM    => -1;
use constant OTYPE_ITEM    =>  0;
use constant OTYPE_PLAYER  =>  1;
use constant OTYPE_NPC     =>  2;
 
#the first number is how many it takes to gain effects of that letter
%main::DRUNK_LETTER_LOOKUP = (
    'a' => [3, 'a', 'a', 'A', 'aa', 'ah', 'Ah', 'ao', 'aw', 'oa', 'ahhhh'],
    'b' => [8, 'b', 'b', 'b', 'B', 'B', 'vb'],
    'c' => [3, 'c', 'c', 'C', 'cj', 'sj', 'zj'],
    'd' => [5, 'd', 'd', 'D'],
    'e' => [3, 'e', 'e', 'eh', 'E'],
    'f' => [4, 'f', 'f', 'ff', 'fff', 'fFf', 'F'],
    'g' => [8, 'g', 'g', 'G'],
    'h' => [9, 'h', 'h', 'hh', 'hhh', 'Hhh', 'HhH', 'H'],
    'i' => [7, 'i', 'i', 'Iii', 'ii', 'iI', 'Ii', 'I'],
    'j' => [9, 'j', 'j', 'jj', 'Jj', 'jJ', 'J'],
    'k' => [7, 'k', 'k', 'K'],
    'l' => [3, 'l', 'l', 'L'],
    'm' => [5, 'm', 'm', 'mm', 'mmm', 'mmmm', 'mmmmm', 'MmM', 'mM', 'M'],
    'n' => [6, 'n', 'n', 'nn', 'Nn', 'nnn', 'nNn', 'N'],
    'o' => [3, 'o', 'o', 'ooo', 'ao', 'aOoo', 'Ooo', 'ooOo'],
    'p' => [3, 'p', 'p', 'P'],
    'q' => [5, 'q', 'q', 'Q', 'ku', 'ququ', 'kukeleku'],
    'r' => [4, 'r', 'r', 'R'],
    's' => [2, 's', 'ss', 'zzZzssZ', 'ZSssS', 'sSzzsss', 'sSss'],
    't' => [5, 't', 't', 'T'],
    'u' => [3, 'u', 'u', 'uh', 'Uh', 'Uhuhhuh', 'uhU', 'uhhu'],
    'v' => [4, 'v', 'v', 'V'],
    'w' => [4, 'w', 'w', 'W'],
    'x' => [5, 'x', 'x', 'X', 'ks', 'iks', 'kz', 'xz'],
    'y' => [3, 'y', 'y', y', 'Y'],
    'z' => [2, 'z', 'z', 'z', 'ZzzZz', 'Zzz', 'Zsszzsz', 'szz', 'sZZz', 'ZSz', 'zZ', 'Z']
);

# item -> effect
# item -> effect
%main::FUSE_EFFECT_LOOKUP = (
    633 => 57,  # chunk of iron
    634 => 56,  # chunk of stone
    635 => 55,  # chunk of ice
    269 => 58,  # pile of muck
    405 => 59,  # amethyst shard
    406 => 61,  # chunk of sapphire
    407 => 60,  # emerald shard
    408 => 63,  # rounded diamond
    409 => 62,  # small quartz
    899 => 73,  # rough piece of obsidian
    822 => 76,  # dragons scale
    823 => 77,  # sparkling topaz
    847 => 78,   # shark tooth
    268 => 79,   # intestines of a demon
    978 => 84   # intestines of a demon
);

# clan stuffs

use constant RACE_COUNT         => 7; #plat don't you dare add something retarded after skullduggers
use constant LEADER_NONE        => 0;
use constant LEADER_GENERAL     => 1;
use constant LEADER_WARLORD     => 2;
use constant FOLLOWER_NONE      => 0;
use constant FOLLOWER_SOLDIER   => 1;
use constant FOLLOWER_REBEL     => 2;

use constant STAT_LEVEL_START_TODAY     => 0;
use constant STAT_HP_START_TODAY        => 1;
use constant STAT_MN_START_TODAY        => 2;
use constant STAT_NPC_KILLS             => 3;
use constant STAT_NPC_KILLS_TODAY       => 3;
use constant STAT_NPC_KILLS_TOTAL       => 4;
use constant STAT_NPC_DEATHS             => 5;
use constant STAT_NPC_DEATHS_TODAY      => 5;
use constant STAT_NPC_DEATHS_TOTAL      => 6;
use constant STAT_PLR_KILLS             => 7;
use constant STAT_PLR_KILLS_TODAY       => 7;
use constant STAT_PLR_KILLS_TOTAL       => 8;
use constant STAT_PLR_DEATHS            => 9;
use constant STAT_PLR_DEATHS_TODAY      => 9;
use constant STAT_PLR_DEATHS_TOTAL      => 10;
use constant STAT_SWINGS                => 11;
use constant STAT_SWINGS_TODAY          => 11;
use constant STAT_SWINGS_TOTAL          => 12;
use constant STAT_BESTHIT               => 13;
use constant STAT_BESTHIT_TODAY         => 13;
use constant STAT_BESTHIT_OVERALL       => 14;
use constant STAT_MISSES                => 15;
use constant STAT_MISSES_TODAY          => 15;
use constant STAT_MISSES_TOTAL          => 16;
use constant STAT_EXPERTS               => 17;
use constant STAT_EXPERTS_TODAY         => 17;
use constant STAT_EXPERTS_TOTAL         => 18;
use constant STAT_CASTS                 => 19;
use constant STAT_CASTS_TODAY           => 19;
use constant STAT_CASTS_TOTAL           => 20;
use constant STAT_FAILS                 => 21;
use constant STAT_FAILS_TODAY           => 21;
use constant STAT_FAILS_TOTAL           => 22;
use constant STAT_NPCHIGH               => 23;
use constant STAT_NPCHIGH_TODAY         => 23;
use constant STAT_NPCHIGH_OVERALL       => 24;
use constant STAT_NPCEXP                => 25;
use constant STAT_NPCEXP_TODAY          => 25;
use constant STAT_NPCEXP_TOTAL          => 26;
use constant STAT_BESTROUND             => 27;
use constant STAT_BESTROUND_TODAY       => 27;
use constant STAT_BESTROUND_OVERALL     => 28;



 1;
