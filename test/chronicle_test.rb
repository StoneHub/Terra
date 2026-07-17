# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class ChronicleTest < Minitest::Test
  include TerraTest

  def write_chronicle
    Dir.mktmpdir do |dir|
      path = File.join(dir, "chronicle.html")
      Terra::Chronicle.write(world, path: path)
      return File.read(path, encoding: "UTF-8")
    end
  end

  def test_acts_are_recorded_in_order
    quietly { god.eden!; god.pass 3; god.smite 2, 2 }
    days = world.history.map { |e| e[:day] }
    assert_equal days.sort, days
    assert(world.history.any? { |e| e[:note].start_with?("⚡") })
  end

  def test_html_contains_every_entry_with_maps_deduped
    quietly { god.eden!; god.pass 5 }
    html = write_chronicle
    assert html.start_with?("<!doctype html>")
    assert_equal world.history.size, html.scan('class="entry"').size
    assert_operator html.scan('class="map"').size, :<, world.history.size
  end

  def test_notes_are_html_escaped
    lit_world!
    world.record!("<script>alert(1)</script>")
    refute_includes write_chronicle, "<script>alert"
  end

  def test_frozen_worlds_can_still_be_memorialized
    quietly { god.eden! }
    quietly { god.great_freeze! }
    assert_includes write_chronicle, "Great Freeze"
  end
end
