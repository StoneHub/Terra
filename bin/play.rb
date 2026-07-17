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

# Ruby 3.4 warns that IRB becomes an external gem in Ruby 4. bin/setup checks
# for (and installs) it, so the warning is noise on the pinned runtime.
deprecated_warnings = Warning[:deprecated]
Warning[:deprecated] = false
begin
  require "irb"
ensure
  Warning[:deprecated] = deprecated_warnings
end

IRB.start(__FILE__)
