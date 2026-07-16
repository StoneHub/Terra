#!/usr/bin/env ruby
# frozen_string_literal: true
# RubyMine-friendly entry point: a plain Ruby script the play button can run.
# (bin/terra is a shell script that execs irb; Ruby run configurations want
# a .rb file, so this one boots the game and then starts IRB itself —
# IRB is just a library, and IRB.start is all the `irb` binary does.)

Dir.chdir(File.expand_path("..", __dir__)) # chronicle! writes into Terra/
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "terra/session" # genesis + banner
require "irb"

IRB.start(__FILE__)
