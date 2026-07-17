# frozen_string_literal: true

require_relative "test_helper"

class LifeTest < Minitest::Test
  include TerraTest

  def setup
    super
    live_world!
  end

  def test_land_animals_stay_out_of_water
    quietly { god.spawn :lake, at: [5, 4], size: 3 }
    rabbits = quietly { god.spawn :rabbit, count: 3 }
    world.advance!(15)
    rabbits.each { |r| refute_equal :water, r.tile.terrain }
  end

  def test_fish_stay_in_water_and_cannot_cross_ice
    lake = quietly { god.spawn :lake, at: [5, 4], size: 2 }
    fish = quietly { god.spawn :fish }
    world.advance!(10)
    assert_equal :water, fish.tile.terrain

    lake.tiles.each { |t| t.terrain = :ice }
    spot = fish.pos
    world.advance!(5)
    assert_equal spot, fish.pos, "fish should be trapped under ice"
  end

  def test_a_divine_brain_replaces_instinct
    quietly { god.spawn :lake, at: [2, 4], size: 2 }
    pilgrim = quietly { god.spawn(:rabbit, at: [11, 8]) { |r| r.hop_toward :water } }
    assert pilgrim.brain
    world.advance!(20)
    dist = world.tiles.select { |t| t.terrain == :water }
                .map { |t| (t.x - pilgrim.x).abs + (t.y - pilgrim.y).abs }.min
    assert_operator dist, :<=, 1
  end

  def test_do_end_brains_bind_too
    homing = quietly do
      god.spawn :hawk, at: [11, 0] do |h|
        h.hop_toward [0, 8]
      end
    end
    world.advance!(5)
    assert_operator homing.x, :<, 11
  end

  def test_plants_green_the_land_permanently
    quietly { god.spawn :fern, at: [4, 4] }
    assert_equal :meadow, world.at(4, 4).terrain

    world.advance!(30)
    meadows = world.tiles.select { |t| t.terrain == :meadow }
    assert_operator meadows.size, :>, 1, "spread should green more land"
    orphaned = meadows.any? { |t| world.plants.none? { |p| p.pos == [t.x, t.y] } }
    assert orphaned, "meadow should outlive the plant that made it"
  end

  def test_plants_die_on_schedule
    quietly { god.spawn :flower, at: [4, 4] }
    world.advance!(30)
    assert(world.plants.all? { |p| p.age <= p.lifespan + 1 })
  end

  def test_one_seed_can_only_fill_its_finite_colony_budget
    Terra::Plant.ordain(:test_vine, emoji: "🫛", grows_on: %i[plains meadow],
                        spread: 1.0, spread_limit: 3, lifespan: 100)
    root = quietly { god.spawn :test_vine, at: [4, 4] }

    10.times { world.plants.dup.each(&:tick) }

    assert_equal 4, world.test_vines.size, "the root plus three descendants is the hard ceiling"
    assert_equal 0, root.spread_remaining
    assert(world.test_vines.all? { |plant| plant.spread_remaining.zero? })
  ensure
    Terra::Plant::KINDS.delete(:test_vine)
  end

  def test_separate_root_seeds_have_separate_colony_budgets
    Terra::Plant.ordain(:test_clover, emoji: "☘️", grows_on: %i[plains meadow],
                        spread: 1.0, spread_limit: 2, lifespan: 100)
    # breathe, not god.spawn — spawn's charged day would tick both plants
    # (spread: 1.0 seeds on every tick) and spoil the exact budget counts.
    first = world.breathe(:test_clover, at: [2, 2], record: false).first
    second = world.breathe(:test_clover, at: [9, 6], record: false).first

    first.send(:seed_neighbor)

    assert_equal 1, first.spread_remaining
    assert_equal 2, second.spread_remaining
  ensure
    Terra::Plant::KINDS.delete(:test_clover)
  end

  def test_smite_leaves_remains_that_fade
    victim = quietly { god.spawn(:tortoise, at: [2, 2]) { |t| t.stay } }
    quietly { god.smite victim }
    skull = world.beings.grep(Terra::Remains).first
    assert skull
    assert_equal [2, 2], skull.pos
    assert_includes world.render, "💀"

    # smite's own charged day already aged the skull once (LINGER is 2).
    world.advance!(2)
    assert_empty world.beings.grep(Terra::Remains)
  end

  def test_bones_leave_no_bones
    quietly { god.spawn :tortoise, at: [2, 2] }
    quietly { god.smite 2, 2 }
    quietly { god.smite 2, 2 } # hit the skull itself
    world.advance!(3)
    assert_empty world.beings.grep(Terra::Remains)
  end

  def test_near_accepts_beings_features_and_coords
    lake = quietly { god.spawn :lake, at: [5, 4] }
    # a stay brain: spawn's charged day must not wander the beast off-spot
    beast = quietly { god.spawn(:tortoise, at: [5, 6]) { |t| t.stay } }
    assert beast.near?(lake)
    assert beast.near?([5, 5], range: 1)
    assert beast.near?(beast, range: 0)
    refute beast.near?([0, 0])
  end
end
