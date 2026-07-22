# frozen_string_literal: true

module Terra
  # Rooted life. A plant never moves; each day it ages, maybe seeds a
  # neighboring tile, and withers when its lifespan runs out. Every root seed
  # owns a finite colony budget shared by all its descendants, so one lucky
  # sprout cannot branch forever and swallow the map.
  class Plant < Being
    DEFAULT_SPREAD_LIMIT = 4
    SpreadBudget = Struct.new(:remaining)

    # Deliberately NOT frozen: gods add species at runtime via `ordain`.
    # Every walkable terrain has a native — that's what `sow` leans on.
    KINDS = {
      fern:     { emoji: "🌿", grows_on: %i[plains meadow forest], spread: 0.20, spread_limit: 4, lifespan: 12 },
      flower:   { emoji: "🌼", grows_on: %i[plains meadow],        spread: 0.15, spread_limit: 3, lifespan: 8  },
      lily:     { emoji: "🪷", grows_on: %i[water],                spread: 0.15, spread_limit: 3, lifespan: 10 },
      cactus:   { emoji: "🌵", grows_on: %i[desert],                spread: 0.05, spread_limit: 2, lifespan: 40 },
      mushroom: { emoji: "🍄", grows_on: %i[forest],               spread: 0.18, spread_limit: 3, lifespan: 6  },
    }

    def self.ordain(kind, emoji:, grows_on:, spread: 0.15, spread_limit: DEFAULT_SPREAD_LIMIT, lifespan: 10)
      KINDS[kind] = {
        emoji: emoji,
        grows_on: Array(grows_on),
        spread: spread,
        spread_limit: spread_limit,
        lifespan: lifespan,
      }
      kind
    end

    def self.cradle(world:, kind:)
      grows_on = KINDS.fetch(kind)[:grows_on]
      taken = world.plants.map { |p| [p.x, p.y] }
      spot = world.tiles.select { |t| grows_on.include?(t.terrain) && !taken.include?([t.x, t.y]) }.sample
      spot && [spot.x, spot.y]
    end

    # The land remembers life: barren earth a plant takes root in turns to
    # meadow, and stays green after the plant is gone.
    def initialize(world:, x:, y:, kind:, brain: nil, colony: nil)
      super(world: world, x: x, y: y, kind: kind, brain: brain)
      @colony = colony || SpreadBudget.new(spread_limit)
      tile.terrain = :meadow if tile.terrain == :plains
    end

    def emoji            = KINDS.fetch(kind)[:emoji]
    def grows_on         = KINDS.fetch(kind)[:grows_on]
    def lifespan         = KINDS.fetch(kind)[:lifespan]
    def spread_limit     = KINDS.fetch(kind).fetch(:spread_limit, DEFAULT_SPREAD_LIMIT)
    def spread_remaining = @colony.remaining

    # Weather matters to rooted things: rain doubles the urge to spread,
    # snow stills it entirely.
    def act
      return die! if age > lifespan
      return if world.sky.stills_plants?

      chance = KINDS.fetch(kind)[:spread]
      chance *= world.sky.growth_bonus
      seed_neighbor if rand < chance
    end

    def inspect
      "#{emoji} #{kind.to_s.capitalize} at (#{x}, #{y}) — age #{age} of #{lifespan}, colony can spread #{spread_remaining} more"
    end

    private

    def seed_neighbor
      return if spread_remaining <= 0

      taken = world.plants.map { |p| [p.x, p.y] }
      spot = neighbors.select { |t| grows_on.include?(t.terrain) && !taken.include?([t.x, t.y]) }.sample
      return unless spot

      @colony.remaining -= 1
      world.beings << Plant.new(world: world, x: spot.x, y: spot.y, kind: kind, colony: @colony)
    end
  end
end
