# frozen_string_literal: true

require_relative "test_helper"

class PaletteTest < Minitest::Test
  include TerraTest

  Palette = Terra::Palette

  # ALL is built by merging the drawers; a duplicate key across drawers
  # would be silently swallowed by that merge. This test is the guard.
  def test_names_are_globally_unique_across_drawers
    names = Palette::GROUPS.values.flat_map(&:keys)
    assert_equal names.uniq, names
    assert_equal names.size, Palette::ALL.size
  end

  def test_every_entry_is_a_frozen_nonempty_emoji_string
    Palette::ALL.each do |name, emoji|
      assert_kind_of Symbol, name
      assert_kind_of String, emoji
      refute_empty emoji
    end
    assert Palette::ALL.frozen?
    assert Palette::GROUPS.each_value.all?(&:frozen?)
  end

  def test_bracket_lookup_hits_and_misses_helpfully
    assert_equal "🐺", Palette[:wolf]
    error = assert_raises(KeyError) { Palette[:balrog] }
    assert_match(/swatch/, error.message)
  end

  def test_lookup_searches_by_substring
    dots = Palette.lookup("dot")
    assert_equal 9, dots.size
    assert_equal "🔴", dots[:red_dot]
  end

  def test_the_module_itself_is_enumerable
    assert_equal Palette::ALL.size, Palette.count
    assert_equal %i[red_dot], Palette.select { |_, e| e == "🔴" }.map(&:first)
  end

  def test_godhood_palette_prints_swatches_and_returns_emoji
    assert_nil quietly { god.palette }
    assert_nil quietly { god.palette :creatures }
    assert_equal "🐻", god.palette(:bear)
  end
end
