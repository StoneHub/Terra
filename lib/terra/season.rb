# frozen_string_literal: true

module Terra
  # State pattern: World holds ONE Season object and swaps it —
  # no @season symbol, no `if winter?` checks. Base class = temperate.
  class Season
    def kind    = :temperate
    def winter? = false

    def lock_sky?(_kind) = false # _name = "param required by the contract, unused here"
    def hold_weather?    = false
    def end!             = nil
  end

  class Winter < Season
    # Class-side constructor wrapper ("factory method"): find water,
    # remember it, ice it, hand back the Winter that did it.
    def self.begin!(world)
      water_tiles = world.tiles.select { |tile| tile.terrain == :water }
      water_tiles.each { |tile| tile.terrain = :ice }
      new(water_tiles) # `new` = Winter.new — self is the class here
    end

    def initialize(claimed_tiles)
      @claimed = claimed_tiles # the memory that makes spring possible
    end

    def kind    = :winter
    def winter? = true

    def lock_sky?(kind) = kind != :snow
    def hold_weather?   = true

    def claimed_count = @claimed.size

    # Thaw only what this winter iced (tiles scorched since stay scorched).
    # Returns the thaw count for World's chronicle note.
    def end!
      thawed = @claimed.select { |tile| tile.terrain == :ice }
      thawed.each { |tile| tile.terrain = :water }
      thawed.size
    end
  end
end
