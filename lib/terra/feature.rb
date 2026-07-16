# frozen_string_literal: true

module Terra
  # A named landform occupying a blob of tiles: Lake, Mountain, Forest, Desert.
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

    def frozen? = tiles.all? { |t| t.terrain == :ice }

    # Trailing `!` signals "mutates / has teeth". (No relation to
    # Object#freeze, which locks a Ruby object against modification.)
    def freeze!
      tiles.each { |t| t.terrain = :ice }
      world.behold!
      self
    end

    def thaw!
      tiles.each { |t| t.terrain = :water }
      world.behold!
      self
    end

    def emoji = frozen? ? "🧊" : super
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
