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
      # `world.frozen?` is Object#frozen? — the real thing. If a god calls
      # `world.freeze` (Ruby's own immutability switch), time stops.
      if world.frozen? then "🧊 Terra — frozen in time by `freeze`. Even gods cannot undo it."
      elsif world.lit? then "#{World::WEATHER.fetch(world.weather)}  Terra — day #{world.day}"
      elsif world.day.zero? && world.features.empty?
        "🌑 The Void — darkness upon the face of the deep"
      else
        "🌑 Darkness covers Terra — day #{world.day}. The world waits beneath, unseen."
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
      return "🧊" if world.frozen?
      return "⬛" unless world.lit?

      occupied[[tile.x, tile.y]]&.last&.emoji || tile.emoji
    end

    def tally
      return nil unless world.lit? && world.beings.any?

      "    🐾 #{world.animals.count} animals · 🌱 #{world.plants.count} plants"
    end
  end
end
