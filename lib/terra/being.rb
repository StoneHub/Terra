# frozen_string_literal: true

module Terra
  # Anything alive: it has a place, an age, and one action per day.
  # Subclasses (Animal, Plant) define `act`; the world calls `tick` on
  # every being each time a day passes.
  class Being
    attr_reader :world, :x, :y, :age, :kind

    def initialize(world:, x:, y:, kind:, brain: nil)
      @world = world
      @x = x
      @y = y
      @kind = kind
      @age = 0
      @dead = false
    end

    def tick
      @age += 1
      act
    end

    def act; end

    def die! = @dead = true
    def dead? = @dead
    def tile = world.at(x, y)
    def pos = [x, y]

    # Within `range` (Manhattan) of a creature, a feature, or bare coords.
    def near?(other, range: 2)
      dist = case other
             when Being then (other.x - x).abs + (other.y - y).abs
             when Feature
               other.tiles.map { |t| (t.x - x).abs + (t.y - y).abs }.min
             when Array then (other[0] - x).abs + (other[1] - y).abs
             else return false
             end
      dist <= range
    end

    private

    def move_to(t)
      @x = t.x
      @y = t.y
    end

    def neighbors
      [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]
        .filter_map { |nx, ny| world.at(nx, ny) }
    end
  end

  # What a smite leaves behind: a skull that lingers a couple of days, then
  # fades. It's a Being like any other — time is what removes it.
  class Remains < Being
    LINGER = 2

    def initialize(world:, x:, y:)
      super(world: world, x: x, y: y, kind: :remains)
    end

    def emoji = "💀"

    def act = (die! if age >= LINGER)

    def inspect = "💀 Remains at (#{x}, #{y}) — fading"
  end
end
