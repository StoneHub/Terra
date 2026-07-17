# frozen_string_literal: true

module Terra
  # The grid, plus everything alive on it. Starts as void; `illuminate!` is
  # the big-bang switch, `bestow_life!` wakes Level 2. Time only moves when
  # `advance!` is called — between calls the world is a photograph.
  #
  # Presentation lives in Cartographer; plural lookups (world.rabbits) come
  # from the SpeciesLookup mixin. This class is only simulation state.
  class World
    include SpeciesLookup

    # Default canvas. Worlds are born with their size — there is no resizing
    # a live one. A god who wants more room asks big_bang! for it.
    DEFAULT_WIDTH  = 12
    DEFAULT_HEIGHT = 9

    # The sky's moods and their map-header glyphs. Weather shifts on its own
    # as days pass (sticky — most days the sky stays as it was), or a god
    # sets it directly with let_there_be :storm etc.
    WEATHER = { clear: "☀️", rain: "🌧️", snow: "❄️", storm: "⛈️" }.freeze

    FIRE_DURATION = 2
    FIRE_BRANCH_CHANCE = 0.45
    FIRE_SPREAD_LIMIT = 8
    FLAMMABLE_TERRAINS = %i[plains meadow forest].freeze
    Blaze = Struct.new(:remaining)
    Fire = Struct.new(:days, :blaze, :has_spread)

    attr_reader :width, :height, :features, :beings, :day, :history, :tiles, :weather, :season, :ending

    def initialize(width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT)
      @width = width
      @height = height
      @lit = false
      @life = false
      @day = 0
      @weather = :clear
      @season = :temperate
      @ending = nil
      @features = []
      @beings = []
      @history = []
      @fires = {}
      @wintered_tiles = []
      @grid = Array.new(height) do |y|
        Array.new(width) { |x| Tile.new(x: x, y: y, world: self) }
      end
      # Computed eagerly: the tile set never changes (only terrain does),
      # and a lazy ||= would raise FrozenError on a frozen world.
      @tiles = @grid.flatten
    end

    def lit?  = @lit
    def life? = @life
    def winter? = season == :winter

    def illuminate!
      @lit = true
      tiles.each { |t| t.terrain = :plains if t.terrain == :void }
      record!("And there was light. 🌅")
      self
    end

    def bestow_life!
      @life = true
      record!("🌱 The world drew breath — life stirs.")
      self
    end

    # A god may command the sky directly.
    def weather=(kind)
      raise ArgumentError, "the sky knows only #{WEATHER.keys.map(&:inspect).join(', ')}" unless WEATHER.key?(kind)
      if winter? && kind != :snow
        raise ArgumentError, "winter holds the sky at :snow — call spring! before commanding another sky"
      end

      @weather = kind
      record!("#{WEATHER.fetch(kind)} The sky turns to #{kind} at a word.")
    end

    # Reversible world climate. Only water that this winter turned to ice is
    # restored by spring; a lake deliberately iced over beforehand stays ice.
    def winter!
      return self if winter?

      @season = :winter
      @weather = :snow
      @wintered_tiles = tiles.select { |tile| tile.terrain == :water }
      @wintered_tiles.each { |tile| tile.terrain = :ice }
      extinguished = @fires.size
      @fires.clear
      record!("❄️ Winter takes the world — #{@wintered_tiles.size} water tiles ice over#{", #{extinguished} fires go dark" if extinguished.positive?}")
      self
    end

    def spring!
      return self unless winter?

      thawed = @wintered_tiles.count { |tile| tile.terrain == :ice }
      @wintered_tiles.each { |tile| tile.terrain = :water if tile.terrain == :ice }
      @wintered_tiles.clear
      @season = :temperate
      @weather = :clear
      record!("🌱 Spring answers — #{thawed} frozen water tiles thaw")
      self
    end

    # Natural lightning starts a small, finite blaze, kills whatever stands
    # there, and leaves remains. Divine smites reuse this same bolt.
    def lightning!(tile)
      ignite!(tile, blaze: Blaze.new(FIRE_SPREAD_LIMIT))
    end

    # Active flame is separate from permanent scorched terrain: burned-out
    # tiles remain ash, while Cartographer can render only live fire as 🔥.
    def burning?(tile) = @fires.key?(tile)
    def fires = @fires.keys

    def ignite!(tile, blaze:)
      tile.scorch!
      @fires[tile] ||= Fire.new(FIRE_DURATION, blaze, false)
      victims = beings.select { |b| b.x == tile.x && b.y == tile.y }
      victims.each(&:die!)
      beings.reject!(&:dead?)
      victims.reject { |v| v.is_a?(Remains) }.each do |v|
        beings << Remains.new(world: self, x: v.x, y: v.y)
      end
      victims
    end

    # The chronicle: every act appends a dated entry with a map snapshot.
    # Appending works even on a frozen world — freeze is shallow, and
    # @history points at an ordinary (unfrozen) Array.
    def record!(note)
      history << { day: day, note: note, map: render }
      nil
    end

    # The Great Freeze is also a small inheritance lesson. World adds its
    # ending, then `super` deliberately invokes Object#freeze — the real Ruby
    # operation, shallow and irreversible. The mutable history Array can still
    # receive the final chronicle entry after its owner is frozen.
    def freeze
      return self if frozen?

      @ending = :great_freeze
      @fires.clear
      super
      record!("🥶 The Great Freeze — usable energy gutters out. Time ends with this world.")
      self
    end

    # Returns nil when off-map — callers use `if tile = world.at(...)`.
    def at(x, y)
      return nil unless x.between?(0, width - 1) && y.between?(0, height - 1)

      @grid[y][x]
    end

    # Diamond of tiles within Manhattan distance `radius`, clipped to the map.
    def tiles_near(x, y, radius)
      (-radius..radius).flat_map do |dy|
        r = radius - dy.abs
        (-r..r).map { |dx| at(x + dx, y + dy) }
      end.compact
    end

    # `grep` on an Array selects by ===, so a class picks its instances —
    # tidier than select { |b| b.is_a?(Animal) }.
    def animals = beings.grep(Animal)
    def plants  = beings.grep(Plant)

    # Bring `count` creatures of `kind` into the world. Returns the newborns
    # (empty when the world has no hospitable ground for them). Fails loudly
    # on unknown kinds — this is a public boundary; don't trust the caller.
    def breathe(kind, at: nil, count: 1, brain: nil, record: true)
      klass = if Animal::KINDS.key?(kind) then Animal
              elsif Plant::KINDS.key?(kind) then Plant
              else raise ArgumentError, "unknown species #{kind.inspect} — ordain it first"
              end

      Array.new(count) do
        x, y = at || klass.cradle(world: self, kind: kind)
        next unless x

        being = klass.new(world: self, x: x, y: y, kind: kind, brain: brain)
        beings << being
        being
      end.compact.tap do |born|
        record!("#{born.first.emoji} #{born.size} × #{kind} arrive#{' (divine brain)' if brain}") if record && born.any?
      end
    end

    # One day per step: the sky shifts, every being acts, existing fires move
    # and burn out, then storms may strike.
    def advance!(days = 1)
      before = beings.size
      days.times do
        @day += 1
        @weather = WEATHER.keys.sample if !winter? && rand > 0.6 # winter holds; other skies are sticky
        beings.dup.each(&:tick) # dup: plants seed children mid-walk
        beings.reject!(&:dead?)
        spread = advance_fires!
        record!("🔥 Fire spreads to #{spread} new #{spread == 1 ? 'tile' : 'tiles'}") if spread.positive?
        if @weather == :storm && rand < 0.25
          struck = lightning!(tiles.sample)
          record!("⛈️ Wild lightning finds the world#{" — it takes the #{struck.first.kind}" if struck.any?}")
        end
      end
      drift = beings.size - before
      passage = days == 1 ? "1 day passes" : "#{days} days pass"
      record!("⏳ #{passage}#{format(' (%+d souls)', drift) unless drift.zero?} — #{WEATHER.fetch(weather)} #{weather} skies")
      self
    end

    def render = Cartographer.new(self).render

    def behold! = puts(render)

    # `world` typed at the prompt echoes the whole map. See Tile#inspect for why.
    def inspect = render

    private

    # Each active tile gets one chance per day to ignite one cardinal neighbor.
    # Every lightning bolt shares a finite budget across the whole resulting
    # blaze, and newly lit tiles wait until tomorrow before they can spread.
    def advance_fires!
      spread = 0
      @fires.to_a.each do |tile, fire|
        # The first spread is guaranteed when fuel is adjacent, so a fire never
        # merely looks broken. Its second-day branch remains a roll.
        if fire.blaze.remaining.positive? && (!fire.has_spread || rand < FIRE_BRANCH_CHANCE)
          target = fire_neighbors(tile).sample
          if target
            fire.blaze.remaining -= 1
            ignite!(target, blaze: fire.blaze)
            fire.has_spread = true
            spread += 1
          end
        end

        fire.days -= 1
        @fires.delete(tile) if fire.days <= 0
      end
      spread
    end

    def fire_neighbors(tile)
      [[tile.x + 1, tile.y], [tile.x - 1, tile.y], [tile.x, tile.y + 1], [tile.x, tile.y - 1]]
        .filter_map { |x, y| at(x, y) }
        .select { |neighbor| FLAMMABLE_TERRAINS.include?(neighbor.terrain) && !burning?(neighbor) }
    end
  end
end
