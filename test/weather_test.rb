# frozen_string_literal: true

require_relative "test_helper"

class WeatherTest < Minitest::Test
  include TerraTest

  def setup
    super
    live_world!
  end

  def test_worlds_are_born_clear
    assert_equal :clear, world.weather
  end

  def test_a_god_can_command_the_sky
    quietly { god.let_there_be :storm }
    assert_equal :storm, world.weather
    assert_includes world.render, "⛈️"
    assert(world.history.any? { |e| e[:note].include?("sky turns") })
  end

  def test_the_sky_rejects_nonsense
    assert_raises(ArgumentError) { world.weather = :frogs }
  end

  def test_weather_shifts_as_days_pass
    seen = []
    30.times do
      world.advance!(1)
      seen << world.weather
    end
    assert_operator seen.uniq.size, :>, 1, "thirty days should see more than one sky"
    assert(seen.all? { |w| Terra::World::WEATHER.key?(w) })
  end

  def test_snow_stills_the_plants
    quietly { god.sow 6 }
    # Tick plants directly with the sky pinned — advance! reshuffles the
    # weather at dawn, so it can't hold a note for five straight days.
    world.instance_variable_set(:@weather, :snow)
    before = world.plants.size
    5.times { world.plants.dup.each(&:tick) }
    assert_equal before, world.plants.size, "nothing should spread under snow"
  end

  def test_winter_ices_water_extinguishes_fire_and_holds_snow_until_spring
    lake = quietly { god.spawn :lake, at: [5, 4], size: 2 }
    world.lightning!(world.at(0, 0))

    quietly { god.winter! }
    assert world.winter?
    assert_equal :snow, world.weather
    assert lake.iced_over?
    assert_empty world.fires

    world.advance!(10)
    assert_equal :snow, world.weather

    quietly { god.spring! }
    refute world.winter?
    assert_equal :clear, world.weather
    refute lake.iced_over?
  end

  def test_spring_only_thaws_water_claimed_by_that_winter
    old_ice = quietly { god.spawn :lake, at: [2, 2], size: 1 }
    winter_water = quietly { god.spawn :lake, at: [9, 6], size: 1 }
    quietly { old_ice.ice_over! }

    quietly { god.winter! }
    quietly { god.spring! }

    assert old_ice.iced_over?, "deliberate ice from before winter should remain"
    refute winter_water.iced_over?, "seasonal ice should thaw in spring"
  end

  def test_winter_refuses_a_different_commanded_sky
    quietly { god.winter! }
    out, = capture_io { god.let_there_be :rain }
    assert_includes out, "spring!"
    assert_equal :snow, world.weather
  end

  def test_storms_eventually_throw_lightning
    quietly { god.let_there_be :storm }
    60.times do
      world.advance!(1)
      world.instance_variable_set(:@weather, :storm)
    end
    assert(world.tiles.any? { |t| t.terrain == :scorched }, "a held storm should scorch something in 60 days")
  end

  def test_lightning_fire_spreads_to_flammable_ground_then_burns_out
    center = world.at(5, 4)
    target = world.at(6, 4)
    [world.at(4, 4), world.at(5, 3), world.at(5, 5)].each { |tile| tile.terrain = :water }
    victim = quietly { god.spawn :rabbit, at: [target.x, target.y] }

    world.lightning!(center)
    assert world.burning?(center)
    assert_equal "🔥", center.emoji

    assert_equal 1, world.send(:advance_fires!)
    assert world.burning?(target)
    refute_includes world.animals, victim

    20.times { world.send(:advance_fires!) }
    assert_empty world.fires
    assert_equal :scorched, target.terrain
    assert_equal "◾", target.emoji
  end

  def test_one_lightning_blaze_has_a_hard_spread_limit
    world.lightning!(world.at(5, 4))
    30.times { world.send(:advance_fires!) }

    burned = world.tiles.count { |tile| tile.terrain == :scorched }
    assert_operator burned, :<=, Terra::World::FIRE_SPREAD_LIMIT + 1
    assert_empty world.fires
  end

  def test_sow_grows_natives_of_each_terrain
    quietly { god.spawn :desert, at: [5, 4], size: 3 }
    sown = quietly { god.sow 10, on: :sand }
    refute_empty sown
    assert(sown.all? { |p| p.kind == :cactus })
  end

  def test_sow_reports_seeds_lost_on_stone
    quietly { god.spawn :mountain, at: [5, 4], size: 4 }
    out, = capture_io { god.sow 5, on: :mountain }
    assert_includes out, "none take root"
  end

  def test_sow_records_once_not_per_seed
    entries_before = world.history.size
    quietly { god.sow 10 }
    assert_equal entries_before + 1, world.history.size
  end
end
