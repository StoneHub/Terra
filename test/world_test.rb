# frozen_string_literal: true

require_relative "test_helper"

class WorldTest < Minitest::Test
  include TerraTest

  def test_default_and_custom_dimensions
    assert_equal [12, 9], [world.width, world.height]
    new_god(width: 20, height: 6)
    assert_equal [20, 6], [world.width, world.height]
  end

  def test_at_returns_nil_off_map
    assert_nil world.at(-1, 0)
    assert_nil world.at(12, 0)
    assert_nil world.at(0, 9)
    refute_nil world.at(11, 8)
  end

  def test_tiles_is_memoized_and_complete
    assert_equal 108, world.tiles.size
    assert_same world.tiles, world.tiles
  end

  def test_illuminate_turns_void_to_plains
    assert(world.tiles.all? { |t| t.terrain == :void })
    world.illuminate!
    assert world.lit?
    assert(world.tiles.all? { |t| t.terrain == :plains })
  end

  def test_advance_moves_the_calendar_and_records
    lit_world!
    world.advance!(5)
    assert_equal 5, world.day
    assert(world.history.any? { |e| e[:note].include?("5 days pass") })
  end

  def test_history_entries_carry_day_note_and_map
    world.illuminate!
    entry = world.history.last
    assert_equal 0, entry[:day]
    assert_kind_of String, entry[:map]
    assert_includes entry[:note], "light"
  end

  def test_freeze_calls_rubys_real_freeze_and_records_the_great_freeze
    lit_world!
    world.freeze
    assert world.frozen?
    assert_equal :great_freeze, world.ending
    assert_includes world.history.last[:note], "Great Freeze"
    assert_includes world.render, "no usable energy"
    assert_includes world.render, "·"
    world.record!("post-freeze") # history Array itself is not frozen
    assert_equal "post-freeze", world.history.last[:note]
  end

  def test_freeze_is_idempotent
    lit_world!
    world.freeze
    entries = world.history.size
    world.freeze
    assert_equal entries, world.history.size
  end

  def test_world_has_no_fake_unfreeze
    refute_respond_to world, :unfreeze
  end

  def test_breathe_rejects_unknown_species
    live_world!
    err = assert_raises(ArgumentError) { world.breathe(:unicorn) }
    assert_includes err.message, ":unicorn"
  end

  def test_breathe_returns_empty_when_no_habitat
    live_world! # no water anywhere
    assert_empty world.breathe(:fish)
  end

  def test_plural_species_lookup
    live_world!
    quietly do
      god.spawn :rabbit, count: 2
      god.spawn :lily # needs water
      god.spawn :lake, at: [4, 4]
      god.spawn :lily
      god.ordain :wolf, emoji: "🐺", habitat: :land, speed: 3
      god.spawn :wolf
    end
    assert_equal 2, world.rabbits.size
    assert_equal 1, world.wolves.size
    assert(world.lilies.all? { |p| p.kind == :lily })
    assert_respond_to world, :tortoises
    assert_raises(NoMethodError) { world.unicorns }
  end
end
