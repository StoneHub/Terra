# frozen_string_literal: true

module Terra
  # The sky as objects. Each kind declares itself with `manifest_as`, the
  # same class-macro pattern Feature uses — a registry fills at load time,
  # and behavior that used to be `if world.weather == :storm` checks lives
  # on the kind that owns it instead.
  class Weather
    REGISTRY = {} # kind Symbol => subclass

    class << self
      attr_reader :kind, :emoji

      def manifest_as(kind, emoji:)
        @kind = kind
        @emoji = emoji
        REGISTRY[kind] = self
      end
    end

    # Loud on unknown skies — this replaces World#weather='s validation.
    def self.summon(kind)
      klass = REGISTRY.fetch(kind) do
        raise ArgumentError, "the sky knows only #{REGISTRY.keys.map(&:inspect).join(', ')}"
      end
      klass.new
    end

    def kind  = self.class.kind
    def emoji = self.class.emoji

    def inspect = "#{emoji} #{kind}"

    # -- the polymorphic surface: calm defaults; kinds override what makes
    # them different. Template method pattern — the base promises the hooks,
    # advance! calls them blindly, subclasses fill in the drama.
    def stills_plants?     = false
    def growth_bonus       = 1
    def daily_event(world) = nil
  end

  class Clear < Weather
    manifest_as :clear, emoji: "☀️"
  end

  class Rain < Weather
    manifest_as :rain, emoji: "🌧️"

    def growth_bonus = 2

    # TODO(Monroe): rain douses fires — your feature, the Storm pattern in reverse.
    #
    #   DOUSE_CHANCE = 0.5   # your call: 1.0 = instant, <1 = a blaze can survive a shower
    #
    #   def daily_event(world)
    #     1. collect the burning tiles (world.fires — it returns the tile keys)
    #     2. douse each with rand < DOUSE_CHANCE (or all at once, your design)
    #        — world has no "extinguish one fire" verb yet; give it one rather
    #          than reaching into @fires from out here (Winter#begin! set the
    #          precedent: collaborators get verbs, not ivar access)
    #     3. world.record! how many hissed out ("🌧️ The rain takes N fires")
    #   end
    #
    # Wire-up you get FREE because advance! already calls daily_event on
    # whatever sky is up: commanding rain during a blaze costs a day (enact)
    # and the douse happens inside that charged day. No other code changes.
    #
    # Sweep when done: guide :weather chapter (rain line), LIFE_SHEET's
    # weather note in lore.rb, companion.html's weather row.
    # Un-skip test_rain_douses_fires in weather_test.rb — make it pass.
  end

  class Snow < Weather
    manifest_as :snow, emoji: "❄️"

    def stills_plants? = true # plant.rb's `return if == :snow` moves here
  end

  class Storm < Weather
    manifest_as :storm, emoji: "⛈️"

    STRIKE_CHANCE = 0.25

    def daily_event(world)
      return unless rand < STRIKE_CHANCE

      struck = world.lightning!(world.tiles.sample)
      world.record!("⛈️ Wild lightning finds the world#{" — it takes the #{struck.first.kind}" if struck.any?}")
    end
  end
end
