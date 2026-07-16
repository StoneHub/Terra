# frozen_string_literal: true

# Terra — a god game played entirely from IRB.
#
# `require "terra"` loads the engine; `require "terra/session"` also boots
# a world and grants you godhood (that's what bin/terra does).

require_relative "terra/tile"
require_relative "terra/species_lookup"
require_relative "terra/cartographer"
require_relative "terra/world"
require_relative "terra/feature"
require_relative "terra/being"
require_relative "terra/animal"
require_relative "terra/plant"
require_relative "terra/chronicle"
require_relative "terra/godhood"

void = nil
world = void

module Terra
  VERSION = "0.1.0"

  # Wires a fresh world to the Godhood powers and grafts those powers onto
  # `main`, the object you're "inside" at the IRB prompt. `extend` adds
  # methods to one object only — like a Kotlin extension function scoped to
  # a single instance — so `spawn`, `smite` etc. work bare at the prompt.
  def self.genesis
    world = World.new
    Godhood.world = world
    TOPLEVEL_BINDING.receiver.extend(Godhood)
    world
  end
end
