# frozen_string_literal: true

module Terra
  # Simulation state only. Presentation → Cartographer; plurals (world.rabbits)
  # → SpeciesLookup; time is charged by Godhood (TIME_COSTS) or spent via pass.
  class World
    include SpeciesLookup

    DEFAULT_WIDTH  = 12
    DEFAULT_HEIGHT = 9

    FIRE_DURATION = 2
    FIRE_BRANCH_CHANCE = 0.45
    FIRE_SPREAD_LIMIT = 8
    FLAMMABLE_TERRAINS = %i[plains meadow forest].freeze # %i[] = array of symbols
    # Struct.new returns a Class — lightweight value types. (look into OpenStruct)
    Blaze = Struct.new(:remaining)
    Fire = Struct.new(:days, :blaze, :has_spread)

    attr_reader :width, :height, :features, :beings, :day, :history, :tiles, :ending

    def weather = @weather.kind # symbol out — callers compare == :storm
    def sky     = @weather      # the object — .emoji, .stills_plants?, .daily_event
    def season  = @season.kind
    def winter? = @season.winter?

    def initialize(width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT)
      @width = width
      @height = height
      @lit = false
      @life = false
      @day = 0
      @weather = Weather.summon(:clear)
      @season = Season.new
      @ending = nil
      @features = []
      @beings = []
      @history = []
      @fires = {}
      @grid = Array.new(height) do |y|
        Array.new(width) { |x| Tile.new(x: x, y: y, world: self) }
      end
      # Eager, not lazy ||= — a memoizing write would raise FrozenError post-freeze.
      @tiles = @grid.flatten
    end

    def lit?  = @lit # endless method: def name = expression
    def life? = @life

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

    def weather=(kind) # `def name=` defines the setter `world.weather = x` calls
      if @season.lock_sky?(kind)
        raise ArgumentError, "winter holds the sky at :snow — call spring! before commanding another sky"
      end

      @weather = Weather.summon(kind) # summon raises on unknown skies
      record!("#{@weather.emoji} The sky turns to #{kind} at a word.")
    end

    # The Winter object ices the water and remembers what it claimed.
    def winter!
      return self if winter?

      @season = Winter.begin!(self)
      @weather = Weather.summon(:snow)
      extinguished = @fires.size
      @fires.clear
      record!("❄️ Winter takes the world — #{@season.claimed_count} water tiles ice over#{", #{extinguished} fires go dark" if extinguished.positive?}")
      self
    end

    # Spring = asking the current winter to end itself.
    def spring!
      return self unless winter?

      thawed = @season.end!
      @season = Season.new
      @weather = Weather.summon(:clear)
      record!("🌱 Spring answers — #{thawed} frozen water tiles thaw")
      self
    end

    def lightning!(tile)
      ignite!(tile, blaze: Blaze.new(FIRE_SPREAD_LIMIT))
    end

    # Live flame (🔥) vs permanent scorched terrain (◾) — separate state.
    def burning?(tile) = @fires.key?(tile)
    def fires = @fires.keys

    def ignite!(tile, blaze:)
      tile.scorch!
      @fires[tile] ||= Fire.new(FIRE_DURATION, blaze, false) # ||= assign only if nil/absent
      victims = beings.select { |b| b.x == tile.x && b.y == tile.y }
      victims.each(&:die!)
      beings.reject!(&:dead?)
      victims.reject { |v| v.is_a?(Remains) }.each do |v|
        beings << Remains.new(world: self, x: v.x, y: v.y)
      end
      victims
    end

    # Works on a frozen world: freeze is shallow, @history's Array stays mutable.
    def record!(note)
      history << { day: day, note: note, map: render }
      nil
    end

    # Overrides Object#freeze; `super` does the real (irreversible) freezing.
    def freeze
      return self if frozen?

      @ending = :great_freeze
      @fires.clear
      super
      record!("🥶 The Great Freeze — usable energy gutters out. Time ends with this world.")
      self
    end

    # nil when off-map — callers use `if tile = world.at(...)`.
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

    # Array#grep selects by === , so a Class picks its instances.
    def animals = beings.grep(Animal)
    def plants  = beings.grep(Plant)

    # Returns the newborns; empty when no hospitable ground. Raises on unknown kinds.
    def breathe(kind, at: nil, count: 1, brain: nil, record: true)
      klass = if Animal::KINDS.key?(kind) then Animal # if is an EXPRESSION — it returns a value
              elsif Plant::KINDS.key?(kind) then Plant
              else raise ArgumentError, "unknown species #{kind.inspect} — ordain it first"
              end

      Array.new(count) do
        x, y = at || klass.cradle(world: self, kind: kind) # destructure [x, y]; nil-safe via ||
        next unless x # nil from the block; .compact sweeps them

        being = klass.new(world: self, x: x, y: y, kind: kind, brain: brain)
        beings << being
        being
      end.compact.tap do |born|
        # .tap: run the block, return the receiver unchanged
        record!("#{born.first.emoji} #{born.size} × #{kind} arrive#{' (divine brain)' if brain}") if record && born.any?
      end
    end

    # quiet: true — days an act charges; sky holds, no "days pass" entry.
    def advance!(days = 1, quiet: false)
      before = beings.size
      days.times do
        @day += 1
        @weather = Weather.summon(Weather::REGISTRY.keys.sample) if !quiet && !@season.hold_weather? && rand > 0.6 # sticky skies
        beings.dup.each(&:tick) # dup: plants seed children mid-iteration
        beings.reject!(&:dead?)
        spread = advance_fires!
        record!("🔥 Fire spreads to #{spread} new #{spread == 1 ? 'tile' : 'tiles'}") if spread.positive?
        @weather.daily_event(self)
      end
      return self if quiet

      drift = beings.size - before
      passage = days == 1 ? "1 day passes" : "#{days} days pass"
      # "#{x if cond}" — a failed modifier-if yields nil, which interpolates as ""
      record!("⏳ #{passage}#{format(' (%+d souls)', drift) unless drift.zero?} — #{@weather.emoji} #{weather} skies") # %+d = always-signed int
      self
    end

    def render = Cartographer.new(self).render

    # IRB echoes inspect — so typing `world` draws the map.
    def inspect = render

    private

    # Per day: each fire may ignite one cardinal neighbor; the whole blaze
    # shares one spread budget; new fires wait a day before spreading.
    def advance_fires!
      spread = 0
      @fires.to_a.each do |tile, fire| # hash pairs destructure into |key, value|
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
        .filter_map { |x, y| at(x, y) } # map + drop nils, one pass
        .select { |neighbor| FLAMMABLE_TERRAINS.include?(neighbor.terrain) && !burning?(neighbor) }
    end
  end
end
