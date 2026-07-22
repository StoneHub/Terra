# frozen_string_literal: true

require_relative "test_helper"
require "unicode/display_width"

class CartographerTest < Minitest::Test
  include TerraTest

  # ◾ and · are 1 column, emoji are 2 — cell() must pad every glyph to
  # exactly 2 so a scorched tile can't shear the rows below it.
  def test_map_rows_stay_aligned_whatever_the_glyphs
    lit_world!
    quietly { god.spawn :lake, at: [8, 5] }
    quietly { god.smite 2, 2 } # scorched + fire + remains in one map

    assert_uniform_row_width world.render
  end

  def test_frozen_map_rows_stay_aligned
    lit_world!
    quietly { god.great_freeze! }
    assert_uniform_row_width world.render
  end

  private

  def assert_uniform_row_width(render)
    rows = render.lines.map(&:chomp).grep(/\A\s?\d+\s{2}/) # just the map rows
    widths = rows.map { |row| Unicode::DisplayWidth.of(row, 2) }
    assert_equal 1, widths.uniq.size, "rows drifted: #{widths.inspect}"
  end
end
