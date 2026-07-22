# frozen_string_literal: true

module Terra
  # The fire system as a collaborator World OWNS instead of behavior World
  # IS. Composition over inheritance: World holds one Wildfire and forwards
  # to it — like a Kotlin class delegating to a constructor-injected field.
  #
  # WIRING CHECKLIST:
  #   1. Cut from world.rb: FIRE_DURATION, FIRE_BRANCH_CHANCE,
  #      FIRE_SPREAD_LIMIT, FLAMMABLE_TERRAINS, the Blaze/Fire Structs,
  #      and the methods burning?, fires, ignite!, advance_fires!,
  #      fire_neighbors. Paste them here (constants lose their World::
  #      prefix; methods use @world where they used self).
  #   2. In World#initialize:  @wildfire = Wildfire.new(self)
  #      (replaces @fires = {})
  #   3. World keeps thin delegations so nothing outside notices:
  #        def burning?(tile) = @wildfire.burning?(tile)
  #        def fires          = @wildfire.fires
  #        def ignite!(tile, blaze:) = @wildfire.ignite!(tile, blaze: blaze)
  #      lightning! and advance! then call @wildfire instead of themselves.
  #      (Later, look up stdlib Forwardable's def_delegators — three lines
  #      become one. Do it by hand first so the sugar means something.)
  #   4. winter! clears fires — that call becomes @wildfire.extinguish_all!
  #      (a nicer name than reaching into someone else's hash: give the
  #      collaborator verbs, don't grab its ivars).
  #   5. Add `require_relative "terra/wildfire"` to lib/terra.rb ABOVE world.
  #   6. rake. weather_test pokes world.send(:advance_fires!) — decide:
  #      keep a private delegation for it, or (better) update the test to
  #      drive the public seam it actually cares about.
  #   7. Two tests reference World::FIRE_SPREAD_LIMIT — point them at
  #      Wildfire::FIRE_SPREAD_LIMIT.
  class Wildfire
    def initialize(world)
      @world = world
    end

    # ... constants, Structs, and methods paste in here ...

    private

    attr_reader :world
  end
end
