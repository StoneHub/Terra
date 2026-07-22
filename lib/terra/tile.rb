# frozen_string_literal: true

module Terra
  # One square of the world. Dumb data: a terrain symbol, coordinates, and a
  # back-reference to whatever Feature claimed it (nil for wilderness).
  class Tile
    # Symbols (`:void`, `:water`) are Ruby's lightweight enum-ish values —
    # interned, compared by identity. Idiomatic for closed sets like this.
    EMOJI = {
      void:     "⬛",
      plains:   "🟫", # barren earth — what light makes
      meadow:   "🟩", # greened land — what life leaves behind
      water:    "🌊",
      ice:      "🧊",
      mountain: "⛰️",
      volcano:  "🌋",
      forest:   "🌲",
      desert:   "🟨",
      scorched: "◾",
    }.freeze

    attr_reader :x, :y, :world
    attr_accessor :terrain, :feature

    def initialize(x:, y:, world: nil)
      @x = x
      @y = y
      @world = world
      @terrain = :void
      @feature = nil
    end

    def emoji = world&.burning?(self) ? "🔥" : EMOJI.fetch(terrain)

    def scorch! = self.terrain = :scorched

    # IRB prints `inspect` of every expression's return value — so a custom
    # inspect is literally the game's UI. You'll see this trick everywhere here.
    def inspect
      owner = feature ? " — part of #{feature.title}" : ""
      standing = world ? world.beings.select { |b| b.x == x && b.y == y } : []
      here = standing.any? ? " · standing here: #{standing.map(&:inspect).join('; ')}" : ""
      "#{emoji} (#{x}, #{y}) #{terrain}#{owner}#{here}"
    end
  end
end
