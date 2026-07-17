# frozen_string_literal: true

module Terra
  # A named landform occupying tiles: blob-shaped Lakes/Mountains/Forests/
  # Deserts/Grasslands, plus River's long connected band.
  #
  # Each subclass declares itself with the `manifest_as` class macro below —
  # the same pattern Rails uses for `has_many` etc.: a class method that runs
  # at load time and configures the class.
  class Feature
    REGISTRY = {} # kind Symbol => subclass

    class << self
      attr_reader :kind, :emoji, :terrain, :default_names

      def manifest_as(kind, emoji:, terrain:, names:)
        @kind = kind
        @emoji = emoji
        @terrain = terrain
        @default_names = names
        REGISTRY[kind] = self
      end

      def create(world:, at: nil, size: 2, name: nil)
        radius = size - 1
        x, y = at || random_center(world, radius)
        new(world: world, center: [x, y], radius: radius,
            name: name || default_names.sample)
      end

      # Random spot with the blob fully on the map; center of a world too
      # small to fit it.
      def random_center(world, radius)
        xs = radius...(world.width - radius)
        ys = radius...(world.height - radius)
        return [world.width / 2, world.height / 2] if xs.size.zero? || ys.size.zero?

        [rand(xs), rand(ys)]
      end
    end

    attr_reader :world, :tiles, :center
    attr_accessor :name

    def initialize(world:, center:, radius:, name:)
      @world = world
      @center = center
      @radius = radius
      @name = name
      @tiles = world.tiles_near(*center, radius)
      claim(@tiles)
      world.features << self
      world.record!("#{title} forms — #{size} tiles near (#{center.join(', ')})")
    end

    def size = tiles.count

    def kind    = self.class.kind
    def emoji   = self.class.emoji
    def terrain = self.class.terrain

    def title = %(#{emoji} #{self.class.name.split("::").last} "#{name}")

    def inspect
      "#{title} — #{size} tiles centered near (#{center[0]}, #{center[1]})"
    end

    private

    def claim(new_tiles)
      new_tiles.each do |tile|
        tile.feature = self
        tile.terrain = terrain
      end
    end
  end

  class Lake < Feature
    manifest_as :lake, emoji: "🌊", terrain: :water,
                names: ["Stillwater", "Mirrormere", "Lake Umber"]

    # Ice is terrain state the seasons own (winter!/spring!), never Ruby's
    # Object#freeze — a `?` predicate is all the Lake itself needs.
    def iced_over? = tiles.all? { |t| t.terrain == :ice }

    def emoji = iced_over? ? "🧊" : super
  end

  # A river is water like a Lake, but its shape is a connected, meandering
  # band instead of a diamond. `length` follows the x-axis across the map;
  # `width` paints that many water rows perpendicular to the centerline.
  class River < Lake
    manifest_as :river, emoji: "🌊", terrain: :water,
                names: ["Silverrun", "The Long Water", "Wayfinder"]

    attr_reader :length, :width

    def self.create(world:, at: nil, size: 2, name: nil, length: nil, width: 1)
      start = at || [0, world.height / 2]
      x, y = start
      raise ArgumentError, "river start must be on the map" unless world.at(x, y)

      length ||= world.width - x
      unless length.is_a?(Integer) && length.between?(1, world.width - x)
        raise ArgumentError, "river length must be between 1 and #{world.width - x}"
      end
      unless width.is_a?(Integer) && width.between?(1, world.height)
        raise ArgumentError, "river width must be between 1 and #{world.height}"
      end

      new(world: world, start: start, length: length, width: width,
          name: name || default_names.sample)
    end

    def initialize(world:, start:, length:, width:, name:)
      @world = world
      @center = start
      @radius = 0
      @name = name
      @length = length
      @width = width

      x, y = start
      # A one-wide river stays straight so every x-column remains exactly one
      # tile and cardinally connected. Wider bands may shift by one row because
      # consecutive columns still overlap without exceeding the chosen width.
      bends = width == 1 ? [0] : [0, 0, 1, 1, 0, 0, -1, -1]
      centerline = length.times.map do |step|
        [x + step, (y + bends[step % bends.length]).clamp(0, world.height - 1)]
      end
      @tiles = centerline.flat_map { |river_x, river_y| river_band(river_x, river_y) }.uniq

      claim(@tiles)
      world.features << self
      world.record!("#{title} forms — length #{length}, width #{width}, from (#{start.join(', ')})")
    end

    def inspect
      "#{title} — length #{length}, width #{width}, #{size} water tiles from (#{center.join(', ')})"
    end

    private

    def river_band(x, center_y)
      top = center_y - ((width - 1) / 2)
      top = top.clamp(0, world.height - width)
      width.times.filter_map { |offset| world.at(x, top + offset) }
    end
  end

  class Mountain < Feature
    manifest_as :mountain, emoji: "⛰️", terrain: :mountain,
                names: ["Grumblepeak", "The Old Tooth", "Mount Doubt"]

    def erupted? = !!@erupted

    def erupt!
      @erupted = true
      world.at(*center)&.terrain = :volcano
      ring = world.tiles_near(*center, @radius + 1) - tiles
      ring.each(&:scorch!)
      world.behold!
      self
    end

    def emoji = erupted? ? "🌋" : super
  end

  class Forest < Feature
    manifest_as :forest, emoji: "🌲", terrain: :forest,
                names: ["The Whisperwood", "Fernholm", "Tanglewild"]

    # Spreads one ring outward onto open plains. The select/flat_map chain is
    # a taste of the Enumerable pipelines Level 3 is built on.
    def grow!
      frontier = tiles
        .flat_map { |t| [[t.x + 1, t.y], [t.x - 1, t.y], [t.x, t.y + 1], [t.x, t.y - 1]] }
        .filter_map { |x, y| world.at(x, y) }
        .uniq
        .select { |t| %i[plains meadow].include?(t.terrain) }
      frontier.each do |tile|
        tile.feature = self
        tile.terrain = :forest
        tiles << tile
      end
      world.behold!
      self
    end
  end

  class Desert < Feature
    manifest_as :desert, emoji: "🏜️", terrain: :sand,
                names: ["The Dry Quiet", "Sunscar", "The Glass Flats"]
  end

  # Green grass on demand — paints :meadow, the same terrain life leaves
  # behind, so sown/spreading plants treat it as home ground.
  class Grassland < Feature
    manifest_as :grassland, emoji: "🌾", terrain: :meadow,
                names: ["The Greensward", "Longmeadow", "The Rolling Sea"]
  end
end
