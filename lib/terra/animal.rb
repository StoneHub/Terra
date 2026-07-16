# frozen_string_literal: true

module Terra
  # Moving life. Each day an animal follows its instinct (wander) unless a
  # god handed it a brain — a block that runs once per day in its place.
  class Animal < Being
    # Deliberately NOT frozen: gods add species at runtime via `ordain`.
    KINDS = {
      rabbit:   { emoji: "🐇", habitat: :land,  speed: 2 },
      tortoise: { emoji: "🐢", habitat: :land,  speed: 1 },
      fish:     { emoji: "🐟", habitat: :water, speed: 1 },
      hawk:     { emoji: "🦅", habitat: :air,   speed: 3 },
    }

    # A new species is just a new entry in the book. Session-only — copy the
    # line into KINDS above when it earns permanence.
    def self.ordain(kind, emoji:, habitat:, speed: 1)
      KINDS[kind] = { emoji: emoji, habitat: habitat, speed: speed }
      kind
    end

    # What each habitat can walk on. Note fish cannot cross :ice — freeze a
    # lake and everything in it waits for a thaw that may never come.
    PASSABLE = {
      land:  %i[plains meadow forest sand],
      water: %i[water],
      air:   %i[plains meadow forest sand water ice mountain volcano scorched],
    }.freeze

    attr_accessor :brain

    def initialize(world:, x:, y:, kind:, brain: nil)
      super
      @brain = brain
    end

    # Where a newborn can appear; nil when the world has no such ground.
    def self.cradle(world:, kind:)
      habitat = KINDS.fetch(kind)[:habitat]
      spot = world.tiles.select { |t| PASSABLE.fetch(habitat).include?(t.terrain) }.sample
      spot && [spot.x, spot.y]
    end

    def emoji   = KINDS.fetch(kind)[:emoji]
    def habitat = KINDS.fetch(kind)[:habitat]
    def speed   = KINDS.fetch(kind)[:speed]

    def act
      if brain
        brain.call(self) # divine brain: full control, once per day
      else
        speed.times { wander }
      end
    end

    # ---- verbs available inside divine brains ----

    def wander
      spot = neighbors.select { |t| passable?(t) }.sample
      move_to(spot) if spot
      self
    end

    def stay = self

    # One step toward the nearest tile of a terrain (:water) or exact [x, y].
    def hop_toward(target)
      gx, gy = case target
               when Symbol
                 g = nearest(target) or return stay
                 [g.x, g.y]
               when Array
                 target
               else
                 return stay
               end
      steps = [world.at(x + (gx <=> x), y), world.at(x, y + (gy <=> y))]
      steps.reverse! if (gy - y).abs > (gx - x).abs
      spot = steps.compact.find { |t| passable?(t) }
      move_to(spot) if spot
      self
    end

    def nearest(terrain)
      world.tiles.select { |t| t.terrain == terrain }
           .min_by { |t| (t.x - x).abs + (t.y - y).abs }
    end

    def passable?(t) = PASSABLE.fetch(habitat).include?(t.terrain)

    def inspect
      mind = brain ? "divine brain" : "instinct"
      "#{emoji} #{kind.to_s.capitalize} at (#{x}, #{y}) — age #{age}, #{mind}"
    end
  end
end
