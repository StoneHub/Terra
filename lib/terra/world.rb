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

    attr_reader :width, :height, :features, :beings, :day, :history, :tiles, :weather

    def unfreeze # anything is possible for God!
      puts "A new creation!"
      world = dup # a new creation. take that!
    end

    def initialize(width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT)
      @width = width
      @height = height
      @lit = false
      @life = false
      @day = 0
      @weather = :clear
      @features = []
      @beings = []
      @history = []
      @grid = Array.new(height) do |y|
        Array.new(width) { |x| Tile.new(x: x, y: y, world: self) }
      end
      # Computed eagerly: the tile set never changes (only terrain does),
      # and a lazy ||= would raise FrozenError on a frozen world.
      @tiles = @grid.flatten
    end

    def lit?  = @lit
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

    # The reversible opposite of illuminate! — @lit is just a boolean, so
    # darkness HIDES the world without destroying it. Compare `freeze`,
    # the permanent version. Mutable state pauses; frozen state ends.
    def benight!
      @lit = false
      record!("🌑 The light is withdrawn. Darkness covers the world.")
      self
    end

    # A god may command the sky directly.
    def weather=(kind)
      raise ArgumentError, "the sky knows only #{WEATHER.keys.map(&:inspect).join(', ')}" unless WEATHER.key?(kind)

      @weather = kind
      record!("#{WEATHER.fetch(kind)} The sky turns to #{kind} at a word.")
    end

    # Natural lightning: scorch a tile, kill whatever stands there, leave
    # remains. Returns the victims (divine smites reuse this and add the
    # epitaphs; storms call it wordlessly).
    def lightning!(tile)
      tile.scorch!
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

    # Override the real Object#freeze so the moment enters the chronicle;
    # `super` does the actual freezing, then we snapshot the icy result.
    def freeze
      super
      record!("🧊 The god spoke `freeze`. Time stopped, forever.")
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

    # One day per step: the sky shifts, every being acts, storms may strike,
    # then the dead are collected.
    def advance!(days = 1)
      before = beings.size
      days.times do
        @day += 1
        @weather = WEATHER.keys.sample if rand > 0.6 # sticky skies
        beings.dup.each(&:tick) # dup: plants seed children mid-walk
        beings.reject!(&:dead?)
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
  end
end
