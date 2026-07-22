# frozen_string_literal: true

module Terra
  # The ✍️ mentor, split out of Godhood. This module is `include`d INTO
  # Godhood — study the difference from what genesis does:
  #
  #   include  → methods join the module's ancestor chain (instances get them)
  #   extend   → methods land on ONE object (how Godhood reaches IRB's main)
  #
  # Because Mentor sits in Godhood's ancestry, extending Godhood onto main
  # carries these methods along for free. Chain: main → Godhood → Mentor.
  #
  # WIRING CHECKLIST:
  #   1. Cut from godhood.rb: hush!, mentor!, and mentor_note (keep the
  #      class << self mentor accessor in Godhood — it's Godhood's state;
  #      this module only READS Godhood.mentor?).
  #   2. Paste below. mentor_note was private in Godhood — keep it under a
  #      `private` line here; private-ness survives inclusion.
  #   3. Add `require_relative "terra/mentor"` to lib/terra.rb above godhood.
  #   4. Inside `module Godhood`, near the top:  include Mentor
  #   5. rake — mentor_test.rb should pass untouched (the methods still
  #      answer on god; only their home changed). If a test DID break,
  #      that would mean it was testing structure, not behavior.
  module Mentor
    # def hush!
    #   ...
    # end

    # def mentor!
    #   ...
    # end

    # private

    # def mentor_note(power)
    #   ...
    # end
  end
end
