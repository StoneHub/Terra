module Terra
  # The grid, plus everything alive on it. Starts as void; `illuminate!` is
  # the big-bang switch, `bestow_life!` wakes Level 2. Time only moves when
  # `advance!` is called — between calls the world is a photograph.
  class World
    # Default canvas. Worlds are born with their size — there is no resizing
    # a live one. A god who wants more room asks big_bang! for it.
    DEFAULT_WIDTH  = 12
    DEFAULT_HEIGHT = 9

    attr_reader :width, :height, :features, :beings, :day

    def initialize(width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT)
      @width = width
      @height = height
      @lit = false
      @life = false
      @day = 0
      @features = []
      @beings = []
      @grid = Array.new(height) do |y|
        Array.new(width) { |x| Tile.new(x: x, y: y, world: self) }
      end
    end

    def lit?  = @lit
    def life? = @life

    def illuminate!
      @lit = true
      each_tile { |t| t.terrain = :plains if t.terrain == :void }
      self
    end

    def bestow_life!
      @life = true
      self
    end

    # Returns nil when off-map — callers use `if tile = world.at(...)`.
    def at(x, y)
      return nil unless x.between?(0, width - 1) && y.between?(0, height - 1)
      @grid[y][x]
    end

    def each_tile
      @grid.each { |row| row.each { |tile| yield tile } }
    end

    def tiles = @grid.flatten

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

    # `world.rabbits`, `world.lilies`, `world.wolves` — the plural of any
    # species is a method. This is `method_missing`: Ruby's last stop before
    # NoMethodError, and how Rails once conjured find_by_name. Pair it with
    # respond_to_missing? or tooling (and IRB completion) won't believe you.
    def method_missing(name, *args, &blk)
      kind = species_from_plural(name)
      return beings.select { |b| b.kind == kind } if kind && args.empty?
      super
    end

    def respond_to_missing?(name, include_private = false)
      !species_from_plural(name).nil? || super
    end

    # Bring `count` creatures of `kind` into the world. Returns the newborns
    # (empty when the world has no hospitable ground for them).
    def breathe(kind, at: nil, count: 1, brain: nil)
      klass = Animal::KINDS.key?(kind) ? Animal : Plant
      Array.new(count) do
        x, y = at || klass.cradle(world: self, kind: kind)
        next unless x

        being = klass.new(world: self, x: x, y: y, kind: kind, brain: brain)
        @beings << being
        being
      end.compact
    end

    # One day per step: every being acts, then the dead are collected.
    def advance!(days = 1)
      days.times do
        @day += 1
        @beings.dup.each(&:tick) # dup: plants seed children mid-walk
        @beings.reject!(&:dead?)
      end
      self
    end

    def render
      # `frozen?` here is Object#frozen? — the real thing. If a god calls
      # `world.freeze` (Ruby's own immutability switch), time stops.
      header = if frozen? then "🧊 Terra — frozen in time by `freeze`. Even gods cannot undo it."
               elsif lit? then "☀️  Terra — day #{@day}"
               else "🌑 The Void — darkness upon the face of the deep"
               end
      cols = "    " + (0...width).map { |x| x.to_s.ljust(2) }.join
      occupied = @beings.group_by { |b| [b.x, b.y] }
      rows = @grid.map.with_index do |row, y|
        format("%2d  ", y) + row.map do |t|
          next "🧊" if frozen?
          occupied[[t.x, t.y]]&.last&.emoji || t.emoji
        end.join
      end
      lines = [header, cols] + rows
      lines << "    🐾 #{animals.count} animals · 🌱 #{plants.count} plants" if @beings.any?
      lines.join("\n")
    end

    def behold! = puts(render)

    # `world` typed at the prompt echoes the whole map. See Tile#inspect for why.
    def inspect = render

    private

    # rabbits → rabbit, lilies → lily, wolves → wolf, tortoises → tortoise.
    # Naive English, good enough for a bestiary.
    def species_from_plural(name)
      n = name.to_s
      return nil unless n.end_with?("s")

      [n.chomp("s"), n.chomp("es"), n.sub(/ies\z/, "y"), n.sub(/ves\z/, "f")]
        .map(&:to_sym)
        .find { |k| Animal::KINDS.key?(k) || Plant::KINDS.key?(k) }
    end
  end
end
