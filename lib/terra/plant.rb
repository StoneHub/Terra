module Terra
  # Rooted life. A plant never moves; each day it ages, maybe seeds a
  # neighboring tile, and withers when its lifespan runs out. Populations
  # find their own equilibrium — no god required.
  class Plant < Being
    # Deliberately NOT frozen: gods add species at runtime via `ordain`.
    KINDS = {
      fern:   { emoji: "🌿", grows_on: %i[plains forest], spread: 0.20, lifespan: 12 },
      flower: { emoji: "🌼", grows_on: %i[plains],        spread: 0.15, lifespan: 8  },
      lily:   { emoji: "🪷", grows_on: %i[water],         spread: 0.15, lifespan: 10 },
    }

    def self.ordain(kind, emoji:, grows_on:, spread: 0.15, lifespan: 10)
      KINDS[kind] = { emoji: emoji, grows_on: Array(grows_on), spread: spread, lifespan: lifespan }
      kind
    end

    def self.cradle(world:, kind:)
      grows_on = KINDS.fetch(kind)[:grows_on]
      taken = world.plants.map { |p| [p.x, p.y] }
      spot = world.tiles.select { |t| grows_on.include?(t.terrain) && !taken.include?([t.x, t.y]) }.sample
      spot && [spot.x, spot.y]
    end

    def emoji    = KINDS.fetch(kind)[:emoji]
    def grows_on = KINDS.fetch(kind)[:grows_on]
    def lifespan = KINDS.fetch(kind)[:lifespan]

    def act
      return die! if age > lifespan
      seed_neighbor if rand < KINDS.fetch(kind)[:spread]
    end

    def inspect
      "#{emoji} #{kind.to_s.capitalize} at (#{x}, #{y}) — age #{age} of #{lifespan}"
    end

    private

    def seed_neighbor
      taken = world.plants.map { |p| [p.x, p.y] }
      spot = neighbors.select { |t| grows_on.include?(t.terrain) && !taken.include?([t.x, t.y]) }.sample
      return unless spot

      world.beings << Plant.new(world: world, x: spot.x, y: spot.y, kind: kind)
    end
  end
end
