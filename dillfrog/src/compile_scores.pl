#!/usr/bin/perl -I/usr/dillfrog/r2/

#
# Compiles scores out-of-game (2002-09-15, RTG)
#

use ora_scores;
require "mainconsts.bse";
use strict;

&ora_scores::compile_all();
