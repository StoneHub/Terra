# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "terra"
require "minitest/autorun"

# Shared helpers for Terra tests.
#
# Godhood.world is module-level state (one world per session), so tests
# build a fresh one in setup and must not run in parallel across worlds.
module TerraTest
  def setup
    srand 42 # wander/placement are random; a fixed seed makes runs repeatable
    @god = new_god
  end

  attr_reader :god

  def world = Terra::Godhood.world

  def new_god(width: 12, height: 9)
    Terra::Godhood.world = Terra::World.new(width: width, height: height)
    Object.new.extend(Terra::Godhood)
  end

  # Most god commands narrate + reprint the map; tests usually want silence.
  # capture_io comes from Minitest::Assertions. Returns the block's value.
  def quietly
    result = nil
    capture_io { result = yield }
    result
  end

  def lit_world!  = quietly { god.let_there_be :light }
  def live_world! = quietly { god.let_there_be(:light); god.let_there_be(:life) }
end
