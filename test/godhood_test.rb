# frozen_string_literal: true

require_relative "test_helper"

class GodhoodTest < Minitest::Test
  include TerraTest

  def test_nothing_can_be_made_in_the_void
    out, = capture_io { god.spawn :lake }
    assert_includes out, "void swallows"
    assert_empty world.features
  end

  def test_creatures_are_inert_clay_before_life
    lit_world!
    out, = capture_io { god.spawn :rabbit }
    assert_includes out, "let_there_be :life"
    assert_empty world.beings
  end

  def test_let_there_be_guards
    lit_world!
    out, = capture_io { god.let_there_be :light }
    assert_includes out, "already shines"
    out, = capture_io { god.let_there_be :dinner }
    assert_includes out, ":dinner"
  end

  def test_darkness_refuses_time_and_creation
    live_world!
    quietly { god.spawn :rabbit }
    quietly { god.let_there_be :darkness }
    quietly { god.pass 3 }
    assert_equal 0, world.day
    out, = capture_io { god.let_there_be :darkness }
    assert_includes out, "already absolute"
  end

  def test_smite_by_bare_coords_and_reference
    live_world!
    tile = quietly { god.smite 2, 2 }
    assert_equal :scorched, tile.terrain

    runner = quietly { god.spawn :rabbit, at: [0, 0] }
    quietly { god.pass 4 }
    quietly { god.smite runner }
    refute_includes world.animals, runner
  end

  def test_smite_by_kind_requires_a_unique_match
    live_world!
    quietly { god.spawn :tortoise, at: [1, 1] }
    quietly { god.smite :tortoise }
    assert_empty world.tortoises

    quietly { god.spawn :rabbit, count: 3 }
    out, = capture_io { god.smite :rabbit }
    assert_includes out, "hovers"
    assert_equal 3, world.rabbits.size
  end

  def test_smite_glances_off_landforms
    lit_world!
    lake = quietly { god.spawn :lake, at: [4, 4] }
    out, = capture_io { god.smite lake }
    assert_includes out, "glances off"
    assert_includes world.features, lake
  end

  def test_unmake_by_kind_name_and_ambiguity
    lit_world!
    quietly { god.spawn :forest, at: [3, 5], name: "Mirkwood" }
    quietly { god.unmake "mirkwood" } # case-insensitive
    assert_empty world.features

    quietly { god.spawn :lake, at: [2, 2] }
    quietly { god.spawn :lake, at: [8, 5] }
    out, = capture_io { god.unmake :lake }
    assert_includes out, "2 things answer"
    assert_equal 2, world.features.size
  end

  def test_ordain_animals_plants_and_validation
    quietly { god.ordain :wolf, emoji: "🐺", habitat: :land, speed: 3 }
    assert Terra::Animal::KINDS.key?(:wolf)
    quietly { god.ordain :bramble, emoji: "🌾", grows_on: [:sand], lifespan: 40 }
    assert Terra::Plant::KINDS.key?(:bramble)
    out, = capture_io { god.ordain :ghost, emoji: "👻", habitat: :ether }
    assert_includes out, "Habitat must be"
  ensure
    # Only remove what this test added — KINDS is global state shared by
    # every test, and built-ins (:cactus!) must survive us.
    Terra::Animal::KINDS.delete(:wolf)
    Terra::Plant::KINDS.delete(:bramble)
  end

  def test_big_bang_clamps_and_resets
    quietly { god.big_bang!(width: 999, height: 2) }
    assert_equal [40, 4], [world.width, world.height]
    assert_equal 0, world.day
    refute world.lit?
  end

  def test_eden_is_ready_made
    quietly { god.eden! }
    assert world.lit?
    assert world.life?
    refute_empty world.features
    refute_empty world.animals
    refute_empty world.plants
  end

  def test_frozen_worlds_refuse_everything_but_escape
    lit_world!
    quietly { god.great_freeze! }
    out, = capture_io { god.spawn :lake }
    assert_includes out, "Great Freeze"
    quietly { god.big_bang! }
    refute world.frozen?
  end

  def test_great_freeze_is_the_story_command_for_object_freeze
    lit_world!
    world.lightning!(world.at(2, 2))
    out, = capture_io { god.great_freeze! }
    assert world.frozen?
    assert_equal :great_freeze, world.ending
    assert_empty world.fires
    assert_includes out, "world.frozen?"
    assert_includes out, "Great Freeze"
  end

  def test_powers_shows_every_command_even_before_life
    out, = capture_io { god.powers }
    %w[sow pass terraform ordain chronicle inspire guide companion big_bang! great_freeze! winter! spring! eden! unmake smite].each do |cmd|
      assert_includes out, cmd
    end
    assert_includes out, "🔒 sleeping"
    live_world!
    out, = capture_io { god.powers }
    assert_includes out, "🔓"
  end

  def test_companion_opens_the_local_manual
    opened = nil
    out, = capture_io { god.companion(opener: ->(p) { opened = p; true }) }
    assert opened&.end_with?("companion.html"), "should hand the opener the manual"
    assert File.exist?(opened)
    assert_includes out, "browser"

    out, = capture_io { god.companion(opener: ->(_) { false }) }
    assert_includes out, "file://"
  end

  def test_help_surfaces_run_without_raising
    [proc { god.powers }, proc { god.guide }, proc { god.guide :smite },
     proc { god.guide :nonsense }, proc { god.inspire }, proc { god.inspire :all },
     proc { god.chronicle }].each { |command| capture_io(&command) }
  end

  def test_guide_reads_the_situation
    out, = capture_io { god.guide }
    assert_includes out, "let_there_be :light"

    live_world!
    quietly { god.spawn :rabbit }
    out, = capture_io { god.guide }
    assert_includes out, "pass 7"

    quietly { god.great_freeze! }
    out, = capture_io { god.guide }
    assert_includes out, "big_bang!"
  end
end
