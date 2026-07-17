# frozen_string_literal: true

require_relative "test_helper"

class FeatureTest < Minitest::Test
  include TerraTest

  def setup
    super
    lit_world!
  end

  def test_spawn_paints_a_diamond_blob
    lake = quietly { god.spawn :lake, at: [5, 4], size: 2 }
    assert_instance_of Terra::Lake, lake
    assert_equal 5, lake.size
    assert_equal :water, world.at(5, 4).terrain
    assert_equal :water, world.at(4, 4).terrain
    assert_equal :plains, world.at(3, 3).terrain
  end

  def test_names_default_from_the_kind_list_and_are_assignable
    lake = quietly { god.spawn :lake }
    assert_includes ["Stillwater", "Mirrormere", "Lake Umber"], lake.name
    lake.name = "Custom"
    assert_equal "Custom", lake.name
  end

  def test_lake_ices_over_and_thaws_without_ruby_freezing
    lake = quietly { god.spawn :lake, at: [5, 4] }
    quietly { lake.ice_over! }
    assert lake.iced_over?
    refute lake.frozen?, "physical ice must not shadow Object#frozen?"
    assert_equal "🧊", lake.emoji
    assert(lake.tiles.all? { |t| t.terrain == :ice })
    quietly { lake.thaw! }
    refute lake.iced_over?
  end

  def test_ice_over_and_thaw_do_not_heal_non_water_tiles
    lake = quietly { god.spawn :lake, at: [5, 4], size: 2 }
    burned = lake.tiles.first
    claimed_elsewhere = lake.tiles.last
    burned.scorch!
    claimed_elsewhere.terrain = :sand

    quietly { lake.ice_over! }
    quietly { lake.thaw! }

    assert_equal :scorched, burned.terrain
    assert_equal :sand, claimed_elsewhere.terrain
  end

  def test_river_is_connected_lake_water_with_length_and_width
    river = quietly do
      god.spawn :river, at: [0, 4], length: world.width, width: 3, name: "The Silver Run"
    end

    assert_kind_of Terra::Lake, river
    assert_equal "🌊", river.emoji
    assert_equal world.width, river.length
    assert_equal 3, river.width
    assert_equal (0...world.width).to_a, river.tiles.map(&:x).uniq.sort
    assert river.tiles.group_by(&:x).values.all? { |column| column.size == 3 }
    assert river.tiles.all? { |tile| tile.terrain == :water && tile.feature.equal?(river) }
    assert_equal [river], world.rivers
    assert_includes river.inspect, "length 12, width 3"

    connected = [river.tiles.first]
    connected.each do |tile|
      neighbors = [[tile.x + 1, tile.y], [tile.x - 1, tile.y],
                   [tile.x, tile.y + 1], [tile.x, tile.y - 1]]
        .filter_map { |x, y| world.at(x, y) }
        .select { |neighbor| river.tiles.include?(neighbor) }
      connected.concat(neighbors - connected)
    end
    assert_equal river.tiles.sort_by { |tile| [tile.x, tile.y] },
                 connected.sort_by { |tile| [tile.x, tile.y] }

    quietly { river.ice_over! }
    assert river.iced_over?
    quietly { river.thaw! }
    assert river.tiles.all? { |tile| tile.terrain == :water }
  end

  def test_river_rejects_impossible_dimensions
    assert_raises(ArgumentError) { quietly { god.spawn :river, width: 0 } }
    assert_raises(ArgumentError) { quietly { god.spawn :river, at: [world.width, 4] } }
    assert_raises(ArgumentError) do
      quietly { god.spawn :river, at: [2, 4], length: world.width }
    end
  end

  def test_landforms_are_queryable_by_plural_kind
    lake = quietly { god.spawn :lake, at: [3, 3] }
    mountain = quietly { god.spawn :mountain, at: [8, 5] }

    assert_respond_to world, :lakes
    assert_respond_to world, :mountains
    assert_equal [lake], world.lakes
    assert_equal [mountain], world.mountains
  end

  def test_mountain_erupts_with_a_scorched_ring
    mtn = quietly { god.spawn :mountain, at: [6, 4], size: 2 }
    quietly { mtn.erupt! }
    assert mtn.erupted?
    assert_equal :volcano, world.at(6, 4).terrain
    assert_equal :scorched, world.at(6, 2).terrain
  end

  def test_forest_grows_onto_open_ground
    woods = quietly { god.spawn :forest, at: [5, 4], size: 1 }
    quietly { woods.grow! }
    assert_operator woods.size, :>, 1
  end

  def test_unmake_reverts_owned_tiles_to_plains
    lake = quietly { god.spawn :lake, at: [5, 4] }
    owned = lake.tiles.select { |t| t.feature.equal?(lake) }
    quietly { god.unmake lake }
    refute_includes world.features, lake
    assert(owned.all? { |t| t.terrain == :plains && t.feature.nil? })
  end

  def test_unmake_leaves_overlapping_features_their_tiles
    lake = quietly { god.spawn :lake, at: [5, 4], size: 2 }
    quietly { god.spawn :desert, at: [5, 4], size: 1 }
    quietly { god.unmake lake }
    assert_equal :sand, world.at(5, 4).terrain
    assert_equal :plains, world.at(4, 4).terrain
  end

  def test_grassland_paints_living_meadow
    field = quietly { god.spawn :grassland, at: [5, 4], size: 2 }
    assert_instance_of Terra::Grassland, field
    assert_equal :meadow, world.at(5, 4).terrain
    assert_equal "🌾", field.emoji
  end

  def test_terraform_fills_only_barren_ground
    quietly { god.spawn :lake, at: [2, 2], size: 1 }
    quietly { god.spawn :grassland, at: [8, 5], size: 1 }
    quietly { god.terraform :sand }
    assert_equal :water, world.at(2, 2).terrain, "claimed land untouched"
    assert_equal :meadow, world.at(8, 5).terrain, "grown land untouched"
    assert_equal :sand, world.at(0, 0).terrain
    assert(world.tiles.none? { |t| t.terrain == :plains })
  end

  def test_terraform_validates_terrain_and_emptiness
    out, = capture_io { god.terraform :lava }
    assert_includes out, "refuses"
    quietly { god.terraform :meadow }
    out, = capture_io { god.terraform :sand }
    assert_includes out, "No barren ground"
  end

  def test_placement_survives_a_world_too_small_for_the_blob
    new_god(width: 4, height: 4)
    lit_world!
    lake = quietly { god.spawn :lake, size: 3 }
    assert_instance_of Terra::Lake, lake
  end
end
