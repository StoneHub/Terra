# frozen_string_literal: true

module Terra
  # Draws a World as terminal text. All presentation lives here — headers,
  # glyph choices, layout — so the model never changes when the look does.
  # World#render is a one-line delegation to this class.
  class Cartographer
    def initialize(world)
      @world = world
    end

    def render
      ([header, column_ruler] + map_rows + [tally].compact).join("\n")
    end

    private

    attr_reader :world

    def header
      # `world.frozen?` is Object#frozen? — the real thing. Great Freeze calls
      # World#freeze, whose `super` reaches Object#freeze.
      if world.frozen? then "🥶 The Great Freeze — no usable energy remains. Only a new `big_bang!` can follow."
      elsif world.lit? then "#{World::WEATHER.fetch(world.weather)}  Terra — day #{world.day}"
      else "🌑 The Void — darkness upon the face of the deep"
      end
    end

    def column_ruler
      "    " + (0...world.width).map { |x| x.to_s.ljust(2) }.join
    end

    def map_rows
      occupied = world.beings.group_by { |b| [b.x, b.y] }
      world.tiles.each_slice(world.width).map.with_index do |row, y|
        format("%2d  ", y) + row.map { |tile| glyph(tile, occupied) }.join
      end
    end

    def glyph(tile, occupied)
      return "· " if world.frozen?
      return "⬛" unless world.lit?

      occupied[[tile.x, tile.y]]&.last&.emoji || tile.emoji
    end

    def tally
      return nil if world.frozen?
      return nil unless world.lit? && world.beings.any?

      "    🐾 #{world.animals.count} animals · 🌱 #{world.plants.count} plants"
    end
  end
end
