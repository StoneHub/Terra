#!/usr/bin/env ruby
# frozen_string_literal: true

major, minor = RUBY_VERSION.split(".").map(&:to_i)
unless major > 3 || (major == 3 && minor >= 1)
  warn "Terra requires Ruby 3.1 or newer; this is #{RUBY_DESCRIPTION}."
  warn "On a Mac, run bin/setup instead of using Apple's /usr/bin/ruby."
  exit 1
end

# RubyMine-friendly entry point: a plain Ruby script the play button can run.
# (bin/terra is a shell script that execs irb; Ruby run configurations want
# a .rb file, so this one boots the game and then starts IRB itself —
# IRB is just a library, and IRB.start is all the `irb` binary does.)

Dir.chdir(File.expand_path("..", __dir__)) # chronicle! writes into Terra/
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "terra/session" # genesis + banner

# On Ruby 4.0 irb is an ordinary gem (declared in the Gemfile), so this is
# a plain require — the 3.4-era deprecation shuffle is gone with the pin.
require "irb"

IRB.start(__FILE__)
