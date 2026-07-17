# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class ImaginationTest < Minitest::Test
  include TerraTest

  FakeProvider = Struct.new(:myth, :omen_passage, :calls, keyword_init: true) do
    def mythologize(context:)
      self.calls ||= []
      calls << [:mythologize, context]
      myth
    end

    def omen(context:)
      self.calls ||= []
      calls << [:omen, context]
      omen_passage
    end

  end

  FailingProvider = Class.new do
    def mythologize(context:)
      raise Terra::Imagination::ProviderUnavailable, "model is still downloading"
    end

    def omen(context:)
      raise Terra::Imagination::ProviderUnavailable, "model is still downloading"
    end
  end

  def setup
    super
    lit_world!
    @lake = quietly { god.spawn :lake, at: [4, 4], name: "Stillwater" }
  end

  def test_mythologize_applies_generated_content_without_mutating_simulation_rules
    provider = FakeProvider.new(
      myth: Terra::Imagination::Myth.new(
        name: "The Moon's Cup",
        lore: "At dusk, the lake gathers every reflection the sky has forgotten.",
        source: :fake
      )
    )
    center = @lake.center
    terrains = @lake.tiles.map(&:terrain)

    myth = quietly { god.mythologize(@lake, provider: provider) }

    assert_equal "The Moon's Cup", myth.name
    assert_equal "The Moon's Cup", @lake.name
    assert_equal center, @lake.center
    assert_equal terrains, @lake.tiles.map(&:terrain)
    assert_includes world.history.last[:note], "The Moon's Cup"
    assert_includes world.history.last[:note], "every reflection"
  end

  def test_primary_provider_falls_back_explicitly
    provider = Terra::Imagination::PrimaryWithFallback.new(
      primary: FailingProvider.new,
      fallback: Terra::Imagination::StaticProvider.new
    )

    out, = capture_io { @myth = god.mythologize(@lake, provider: provider) }

    assert_equal :static, @myth.source
    assert_equal "model is still downloading", @myth.fallback_reason
    assert_includes out, "Static fallback"
    assert_includes world.history.last[:note], @myth.lore
  end

  def test_invalid_provider_content_never_reaches_the_chronicle
    provider = Class.new do
      def mythologize(context:)
        Terra::Imagination::Myth.new(name: "", lore: "Valid lore.", source: :fake)
      end
    end.new
    history_size = world.history.size

    out, = capture_io { @result = god.mythologize(@lake, provider: provider) }

    assert_nil @result
    assert_includes out, "name cannot be blank"
    assert_equal history_size, world.history.size
  end

  def test_ambiguous_or_missing_targets_do_not_generate
    quietly { god.spawn :lake, at: [8, 4] }
    provider = Object.new
    def provider.mythologize(context:) = flunk("provider should not run")

    out, = capture_io { @result = god.mythologize(:lake, provider: provider) }

    assert_nil @result
    assert_includes out, "Choose one existing landform"
  end

  def test_content_validation_collapses_whitespace_and_limits_size
    myth = Terra::Imagination::Myth.new(
      name: "  The   Quiet   Crown  ",
      lore: "A mountain\nkeeps watch.",
      source: :fake
    )
    assert_equal "The Quiet Crown", myth.name
    assert_equal "A mountain keeps watch.", myth.lore

    assert_raises(Terra::Imagination::InvalidContent) do
      Terra::Imagination::Myth.new(name: "x" * 61, lore: "Fine.", source: :fake)
    end
  end

  def test_provider_receives_only_a_frozen_data_snapshot
    provider = Class.new do
      attr_reader :context

      def mythologize(context:)
        @context = context
        Terra::Imagination::Myth.new(name: "Witness Water", lore: "It watches.", source: :fake)
      end
    end.new

    quietly { god.mythologize(@lake, provider: provider) }

    assert provider.context.frozen?
    assert provider.context[:feature].frozen?
    assert provider.context.dig(:feature, :current_name).frozen?
    assert provider.context.dig(:world, :features).frozen?
    assert_equal "lake", provider.context.dig(:feature, :kind)
    refute provider.context.values.any? { |value| value.equal?(world) || value.equal?(@lake) }
  end

  def test_omen_reads_world_state_and_only_adds_story
    live_world!
    quietly { god.pass 2 }
    passage = Terra::Imagination::Prose.new(
      kind: :omen,
      text: "The smallest footprint will remain when the storm forgets every road.",
      source: :fake
    )
    provider = FakeProvider.new(omen_passage: passage)
    season = world.respond_to?(:season) ? world.season : :temperate
    before = [world.day, world.weather, season, world.features.dup,
              world.beings.dup, world.tiles.map(&:terrain)]
    history_size = world.history.size

    result = quietly { god.omen(provider: provider) }

    assert_equal passage, result
    assert_equal history_size + 1, world.history.size
    assert_includes world.history.last[:note], "smallest footprint"
    current_season = world.respond_to?(:season) ? world.season : :temperate
    assert_equal before, [world.day, world.weather, current_season, world.features,
                          world.beings, world.tiles.map(&:terrain)]
    context = provider.calls.last.last
    assert_equal world.day, context.dig(:world, :day)
    assert_equal 8, context.dig(:world, :recent_history).size if world.history.size >= 8
  end

  def test_world_context_is_bounded_and_deeply_frozen
    12.times { |index| world.record!("memory #{index}") }
    world.record!("☄️ Omen (story only) — this must not become canonical input")

    context = Terra::Imagination.context_for_world(world)

    assert context.frozen?
    assert context[:world].frozen?
    assert context.dig(:world, :recent_history).frozen?
    assert context.dig(:world, :recent_history).all?(&:frozen?)
    assert_equal 8, context.dig(:world, :recent_history).size
    assert_equal "memory 4", context.dig(:world, :recent_history).first
    refute context.dig(:world, :recent_history).any? { |note| note.include?("must not become") }
    refute context.dig(:world, :recent_history).any? { |note| note.include?(" forms — ") }
  end

  def test_prose_validation_and_fallback_cover_omen
    assert_raises(Terra::Imagination::InvalidContent) do
      Terra::Imagination::Prose.new(kind: :omen, text: "", source: :fake)
    end
    assert_raises(Terra::Imagination::InvalidContent) do
      Terra::Imagination::Prose.new(kind: :omen, text: "One sign appears. Another follows.", source: :fake)
    end

    provider = Terra::Imagination::PrimaryWithFallback.new(
      primary: FailingProvider.new,
      fallback: Terra::Imagination::StaticProvider.new
    )
    context = Terra::Imagination.context_for_world(world)

    omen = provider.omen(context: context)
    assert_equal :static, omen.source
    assert_includes omen.fallback_reason, "downloading"
  end

  def test_powers_and_guide_surface_every_imagination_command
    out, = capture_io { god.powers }
    assert_includes out, "mythologize"
    assert_includes out, "omen"

    out, = capture_io { god.guide :omen }
    assert_includes out, "prophecy"
  end

  def test_apple_provider_rejects_copied_static_fixtures
    status = Struct.new(:success?).new(true)
    runner = lambda do |*args, **kwargs|
      payload = { name: "Stillwater", lore: Terra::Imagination::StaticProvider::LORE.fetch(:lake) }
      [JSON.generate(payload), "", status]
    end
    helper_cache = Struct.new(:executable_path).new("/mock/terra-foundation-models")
    provider = Terra::Imagination::AppleFoundationModelsProvider.new(
      helper_cache: helper_cache,
      runner: runner
    )
    context = Terra::Imagination.context_for(@lake, world)

    error = assert_raises(Terra::Imagination::InvalidContent) do
      provider.mythologize(context: context)
    end

    assert_includes error.message, "static name"
  end

  def test_apple_provider_sends_the_two_structured_tasks
    status = Struct.new(:success?).new(true)
    tasks = []
    runner = lambda do |*args, stdin_data:, **kwargs|
      request = JSON.parse(stdin_data)
      tasks << request.fetch("task")
      payload = if request["task"] == "mythologize"
                  { name: "Moonwell", lore: "It gathers the stars that daylight leaves behind." }
                else
                  { text: "The world remembers what the light almost forgot." }
                end
      [JSON.generate(payload), "", status]
    end
    helper_cache = Struct.new(:executable_path).new("/mock/terra-foundation-models")
    provider = Terra::Imagination::AppleFoundationModelsProvider.new(
      helper_cache: helper_cache,
      runner: runner
    )

    provider.mythologize(context: Terra::Imagination.context_for(@lake, world))
    world_context = Terra::Imagination.context_for_world(world)
    provider.omen(context: world_context)

    assert_equal %w[mythologize omen], tasks
  end

  def test_swift_helper_cache_compiles_once_and_reuses_the_executable
    Dir.mktmpdir("terra-helper-cache-test") do |directory|
      source = File.join(directory, "helper.swift")
      File.write(source, "print(\"hello\")")
      builds = 0
      compiler = lambda do |_input, output|
        builds += 1
        File.write(output, "compiled helper")
      end
      options = {
        source: source,
        cache_root: File.join(directory, "cache"),
        compiler_identity: -> { "Swift 6.3.3 arm64" },
        compiler: compiler
      }

      first_cache = Terra::Imagination::SwiftHelperCache.new(**options)
      first_path = first_cache.executable_path
      assert_equal first_path, first_cache.executable_path

      second_cache = Terra::Imagination::SwiftHelperCache.new(**options)
      assert_equal first_path, second_cache.executable_path
      assert_equal 1, builds
      assert File.executable?(first_path)
    end
  end

  def test_swift_helper_cache_invalidates_for_source_or_compiler_changes
    Dir.mktmpdir("terra-helper-cache-test") do |directory|
      source = File.join(directory, "helper.swift")
      cache_root = File.join(directory, "cache")
      builds = 0
      compiler = lambda do |_input, output|
        builds += 1
        File.write(output, "compiled helper #{builds}")
      end
      identity = "Swift 6"
      cache = Terra::Imagination::SwiftHelperCache.new(
        source: source,
        cache_root: cache_root,
        compiler_identity: -> { identity },
        compiler: compiler
      )

      File.write(source, "version one")
      first_path = cache.executable_path
      File.write(source, "version two")
      second_path = cache.executable_path
      identity = "Swift 7"
      third_path = cache.executable_path

      refute_equal first_path, second_path
      refute_equal second_path, third_path
      assert_equal 3, builds
    end
  end

  def test_failed_swift_compile_leaves_no_executable_and_retries_cleanly
    Dir.mktmpdir("terra-helper-cache-test") do |directory|
      source = File.join(directory, "helper.swift")
      cache_root = File.join(directory, "cache")
      File.write(source, "invalid swift")
      attempts = 0
      cache = Terra::Imagination::SwiftHelperCache.new(
        source: source,
        cache_root: cache_root,
        compiler_identity: -> { "Swift 6" },
        compiler: lambda do |_input, output|
          attempts += 1
          File.write(output, "partial helper")
          raise Terra::Imagination::ProviderUnavailable, "compile failed" if attempts == 1
        end
      )

      error = assert_raises(Terra::Imagination::ProviderUnavailable) { cache.executable_path }

      assert_equal "compile failed", error.message
      assert_empty Dir.glob(File.join(cache_root, "**", "terra-foundation-models"))
      assert_empty Dir.glob(File.join(cache_root, "**", "*.tmp"))

      executable = cache.executable_path
      assert File.executable?(executable)
      assert_equal 2, attempts
    end
  end

  def test_compile_failure_reaches_the_explicit_static_fallback
    helper_cache = Class.new do
      def executable_path
        raise Terra::Imagination::ProviderUnavailable, "Swift compile rejected the helper"
      end
    end.new
    runner = ->(*) { flunk("runtime should not launch after a compile failure") }
    provider = Terra::Imagination::PrimaryWithFallback.new(
      primary: Terra::Imagination::AppleFoundationModelsProvider.new(
        helper_cache: helper_cache,
        runner: runner
      ),
      fallback: Terra::Imagination::StaticProvider.new
    )

    myth = provider.mythologize(context: Terra::Imagination.context_for(@lake, world))

    assert_equal :static, myth.source
    assert_includes myth.fallback_reason, "compile rejected"
  end

  def test_non_json_runtime_failure_preserves_bounded_stderr
    helper_cache = Struct.new(:executable_path).new("/mock/terra-foundation-models")
    status = Struct.new(:success?).new(false)
    runner = ->(*) { ["", "dyld could not load FoundationModels", status] }
    provider = Terra::Imagination::AppleFoundationModelsProvider.new(
      helper_cache: helper_cache,
      runner: runner
    )

    error = assert_raises(Terra::Imagination::ProviderUnavailable) do
      provider.mythologize(context: Terra::Imagination.context_for(@lake, world))
    end

    assert_includes error.message, "dyld could not load"
  end
end
