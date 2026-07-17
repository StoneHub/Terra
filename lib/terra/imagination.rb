# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tempfile"
require "timeout"

module Terra
  # Content generation lives behind this boundary. Providers may write words,
  # but Ruby remains the only authority over world state and commands.
  module Imagination
    class Error < StandardError; end
    class ProviderUnavailable < Error; end
    class InvalidContent < Error; end

    class Myth
      MAX_NAME_LENGTH = 60
      MAX_LORE_LENGTH = 280

      attr_reader :name, :lore, :source, :fallback_reason

      def initialize(name:, lore:, source:, fallback_reason: nil)
        @name = normalize(name, field: "name", maximum: MAX_NAME_LENGTH)
        @lore = normalize(lore, field: "lore", maximum: MAX_LORE_LENGTH)
        @source = source
        @fallback_reason = fallback_reason
      end

      def with_fallback(reason)
        self.class.new(name: name, lore: lore, source: source, fallback_reason: reason)
      end

      def inspect = %(#{name.inspect} — #{lore} (#{source}))

      private

      def normalize(value, field:, maximum:)
        raise InvalidContent, "#{field} must be text" unless value.is_a?(String)

        text = value.strip.gsub(/\s+/, " ")
        raise InvalidContent, "#{field} cannot be blank" if text.empty?
        raise InvalidContent, "#{field} is longer than #{maximum} characters" if text.length > maximum
        raise InvalidContent, "#{field} contains control characters" if text.match?(/\p{Cc}/)

        text
      end
    end

    class Prose
      LIMITS = { omen: 220 }.freeze

      attr_reader :kind, :text, :source, :fallback_reason

      def initialize(kind:, text:, source:, fallback_reason: nil)
        maximum = LIMITS.fetch(kind)
        raise InvalidContent, "#{kind} must be text" unless text.is_a?(String)

        normalized = text.strip.gsub(/\s+/, " ")
        raise InvalidContent, "#{kind} cannot be blank" if normalized.empty?
        raise InvalidContent, "#{kind} is longer than #{maximum} characters" if normalized.length > maximum
        raise InvalidContent, "#{kind} contains control characters" if normalized.match?(/\p{Cc}/)
        raise InvalidContent, "omen is longer than 30 words" if normalized.split.size > 30
        endings = normalized.scan(/[.!?](?:\s|\z)/).size
        raise InvalidContent, "omen must be one sentence" if endings > 1

        @kind = kind
        @text = normalized
        @source = source
        @fallback_reason = fallback_reason
      end

      def with_fallback(reason)
        self.class.new(kind: kind, text: text, source: source, fallback_reason: reason)
      end

      def inspect = %(#{kind}: #{text.inspect} (#{source}))
    end

    class StaticProvider
      LORE = {
        lake: "Still water keeps the sky's oldest secret beneath its silver face.",
        mountain: "The peak remembers the first thunder and answers only in stone.",
        forest: "Every root shares one dream, and every leaf whispers a different ending.",
        desert: "The wind erases each road so pilgrims must choose their purpose again.",
        grassland: "Green waves carry the names of small lives farther than kings ever travel."
      }.freeze
      OMENS = {
        frozen: "The last warmth hides in a story not yet written.",
        winter: "When the thaw comes, count the footprints that lead beneath the ice.",
        storm: "The next bolt will spare what the god has finally learned to name.",
        living: "Something small will outlive the monument raised above it.",
        quiet: "Shape the empty earth carefully; it is already dreaming of roots."
      }.freeze
      def mythologize(context:)
        Myth.new(
          name: context.dig(:feature, :current_name) || context.dig(:style_anchors, :names).first,
          lore: context.dig(:style_anchors, :lore),
          source: :static
        )
      end

      def omen(context:)
        world = context.fetch(:world)
        key = if world[:ending] == "great_freeze"
                :frozen
              elsif world[:season] == "winter"
                :winter
              elsif world[:weather] == "storm"
                :storm
              elsif world.fetch(:being_counts).values.sum.positive?
                :living
              else
                :quiet
              end
        Prose.new(kind: :omen, text: OMENS.fetch(key), source: :static)
      end

    end

    # Builds the Swift bridge once into a content-addressed macOS cache. The
    # key includes both source bytes and Swift compiler identity, so editing the
    # helper or changing Xcode naturally creates a fresh executable.
    class SwiftHelperCache
      CACHE_FORMAT = 1
      COMPILE_ARGS = [].freeze
      DEFAULT_ROOT = File.join(Dir.home, "Library", "Caches", "Terra", "foundation-models")
      MAX_ERROR_LENGTH = 500

      def initialize(source:, cache_root: DEFAULT_ROOT, compiler_identity: nil, compiler: nil,
                     build_timeout: 60, lock_timeout: 65)
        @source = source
        @cache_root = cache_root
        @compiler_identity = compiler_identity || method(:default_compiler_identity)
        @compiler = compiler || method(:default_compile)
        @build_timeout = build_timeout
        @lock_timeout = lock_timeout
      end

      def executable_path
        raise ProviderUnavailable, "Swift helper is missing at #{@source}" unless File.file?(@source)

        key, source_bytes = fingerprint
        directory = File.join(@cache_root, key)
        FileUtils.mkdir_p(directory)
        File.chmod(0o700, directory)
        executable = File.join(directory, "terra-foundation-models")

        File.open("#{executable}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
          begin
            Timeout.timeout(@lock_timeout) { lock.flock(File::LOCK_EX) }
          rescue Timeout::Error
            raise ProviderUnavailable, "Swift helper cache lock exceeded #{@lock_timeout} seconds"
          end
          compile(executable, source_bytes) unless usable?(executable)
        end

        executable
      rescue Error
        raise
      rescue SystemCallError => e
        raise ProviderUnavailable, "Foundation Models helper cache failed: #{e.message}"
      end

      private

      def fingerprint
        source_bytes = File.binread(@source)
        identity = Timeout.timeout(@build_timeout) { @compiler_identity.call.to_s.strip }
        raise ProviderUnavailable, "Swift compiler identity is unavailable" if identity.empty?

        key = Digest::SHA256.hexdigest(
          [CACHE_FORMAT, COMPILE_ARGS.join(" "), source_bytes, identity,
           ENV.fetch("MACOSX_DEPLOYMENT_TARGET", "")].join("\0")
        )
        [key, source_bytes]
      rescue Timeout::Error
        raise ProviderUnavailable, "Swift compiler probe exceeded #{@build_timeout} seconds"
      rescue Error
        raise
      rescue SystemCallError => e
        raise ProviderUnavailable, "Swift compiler is unavailable: #{e.message}"
      end

      def compile(executable, source_bytes)
        directory = File.dirname(executable)
        source_file = Tempfile.new(["terra-foundation-models-source-", ".swift"], directory)
        source_file.binmode
        source_file.write(source_bytes)
        source_file.flush
        source_file.fsync
        source_path = source_file.path
        source_file.close

        output_file = Tempfile.new(["terra-foundation-models-output-", ".tmp"], directory)
        output_path = output_file.path
        output_file.close

        begin
          Timeout.timeout(@build_timeout) { @compiler.call(source_path, output_path) }
        rescue Timeout::Error
          raise ProviderUnavailable, "Swift helper build exceeded #{@build_timeout} seconds"
        end
        unless File.file?(output_path) && File.size(output_path).positive?
          raise ProviderUnavailable, "Swift compiler produced no Foundation Models helper"
        end

        File.chmod(0o700, output_path)
        File.rename(output_path, executable)
      ensure
        FileUtils.rm_f(source_path) if defined?(source_path) && source_path
        FileUtils.rm_f(output_path) if defined?(output_path) && output_path
      end

      def usable?(path)
        File.file?(path) && File.executable?(path) && File.size(path).positive?
      end

      def default_compiler_identity
        compiler = tool_output("/usr/bin/xcrun", "--find", "swiftc")
        compiler = File.realpath(compiler) if File.exist?(compiler)
        version = tool_output("/usr/bin/xcrun", "swiftc", "--version")
        sdk = tool_output("/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-version")
        [compiler, version, sdk].join("\n")
      end

      def default_compile(source, output)
        stdout, stderr, status = Open3.capture3(
          "/usr/bin/xcrun", "swiftc", *COMPILE_ARGS, source, "-o", output
        )
        return if status.success?

        detail = bounded(stderr.strip.empty? ? stdout.strip : stderr.strip)
        raise ProviderUnavailable, detail.empty? ? "Swift helper compilation failed" : detail
      end

      def tool_output(*command)
        stdout, stderr, status = Open3.capture3(*command)
        return stdout.strip if status.success?

        detail = bounded(stderr.strip.empty? ? stdout.strip : stderr.strip)
        raise ProviderUnavailable, detail.empty? ? "Swift compiler is unavailable" : detail
      end

      def bounded(text)
        text.to_s[0, MAX_ERROR_LENGTH]
      end
    end

    class AppleFoundationModelsProvider
      HELPER = File.expand_path("../../support/terra_foundation_models.swift", __dir__)

      def initialize(helper_cache: SwiftHelperCache.new(source: HELPER),
                     runner: Open3.method(:capture3), timeout: 60)
        @helper_cache = helper_cache
        @runner = runner
        @timeout = timeout
      end

      def mythologize(context:)
        payload = generate(:mythologize, context)
        myth = Myth.new(name: payload["name"], lore: payload["lore"], source: :apple_foundation_models)
        validate_novelty!(myth, context)
        myth
      end

      def omen(context:)
        payload = generate(:omen, context)
        passage = Prose.new(kind: :omen, text: payload["text"], source: :apple_foundation_models)
        validate_passage_novelty!(passage, context)
        passage
      end

      private

      def generate(task, context)
        executable = @helper_cache.executable_path
        stdout, stderr, status = Timeout.timeout(@timeout) do
          @runner.call(
            executable,
            stdin_data: JSON.generate({ task: task }.merge(context))
          )
        end

        unless status.success?
          detail = failure_detail(stdout, stderr)
          raise ProviderUnavailable, detail.empty? ? "Foundation Models helper failed" : detail
        end

        parse(stdout)
      rescue JSON::ParserError => e
        raise ProviderUnavailable, "Foundation Models helper returned invalid JSON: #{e.message}"
      rescue SystemCallError => e
        raise ProviderUnavailable, "Foundation Models helper could not run: #{e.message}"
      rescue Timeout::Error
        raise ProviderUnavailable, "Foundation Models helper exceeded #{@timeout} seconds"
      end

      def parse(output)
        JSON.parse(output)
      end

      def failure_detail(output, error_output)
        payload = JSON.parse(output)
        (payload["error"] || error_output.strip || output.strip).to_s[0, 500]
      rescue JSON::ParserError
        (error_output.strip.empty? ? output.strip : error_output.strip)[0, 500]
      end

      def validate_novelty!(myth, context)
        world_names = context.dig(:world, :features).map { |feature| feature[:name] }
        forbidden_names = [context.dig(:feature, :current_name), *context.dig(:style_anchors, :names),
                           *world_names]
          .compact.map(&:downcase)
        if forbidden_names.include?(myth.name.downcase)
          raise InvalidContent, "Foundation Models repeated an existing static name"
        end

        anchor = context.dig(:style_anchors, :lore).to_s.strip.downcase
        if myth.lore.downcase == anchor
          raise InvalidContent, "Foundation Models repeated the static lore fixture"
        end
      end

      def validate_passage_novelty!(passage, context)
        anchors = context.dig(:style_anchors, :omens)
        copied = anchors.compact.any? { |anchor| passage.text.downcase.include?(anchor.downcase) }
        raise InvalidContent, "Foundation Models repeated a static #{passage.kind} fixture" if copied
      end

    end

    class PrimaryWithFallback
      def initialize(primary:, fallback:)
        @primary = primary
        @fallback = fallback
      end

      def mythologize(context:)
        generate(:mythologize, context)
      end

      def omen(context:)
        generate(:omen, context)
      end

      private

      def generate(operation, context)
        @primary.public_send(operation, context: context)
      rescue Error => e
        @fallback.public_send(operation, context: context).with_fallback(e.message)
      end
    end

    # Providers receive a deeply frozen data snapshot, never the live World or
    # Feature objects. The model process has no route back into simulation APIs.
    def self.context_for(feature, world)
      context = context_for_world(world)
      context.merge(
        feature: {
          kind: immutable_text(feature.kind),
          current_name: immutable_text(feature.name, maximum: 120),
          size: feature.size
        }.freeze,
        style_anchors: context.fetch(:style_anchors).merge(
          names: feature.class.default_names.map { |name| immutable_text(name) }.freeze,
          lore: immutable_text(StaticProvider::LORE.fetch(feature.kind))
        ).freeze
      ).freeze
    end

    def self.context_for_world(world)
      features = world.features.map do |feature|
        {
          kind: immutable_text(feature.kind),
          name: immutable_text(feature.name, maximum: 120),
          size: feature.size
        }.freeze
      end.freeze
      being_counts = world.beings.group_by { |being| immutable_text(being.kind) }
        .transform_values(&:size).freeze
      canonical_history = world.history.reject do |entry|
        note = entry.fetch(:note)
        note.start_with?("🔮", "☄️", "📜") || note.include?(" forms — ")
      end
      recent_history = canonical_history.last(8).map do |entry|
        immutable_text(entry.fetch(:note), maximum: 320)
      end.freeze

      {
        world: {
          day: world.day,
          weather: immutable_text(world.weather),
          season: immutable_text(world.respond_to?(:season) ? world.season : :temperate),
          ending: world.respond_to?(:ending) && world.ending && immutable_text(world.ending),
          lit: world.lit?,
          life: world.life?,
          features: features,
          being_counts: being_counts,
          recent_history: recent_history
        }.freeze,
        style_anchors: {
          omens: StaticProvider::OMENS.values.map { |omen| immutable_text(omen) }.freeze
        }.freeze
      }.freeze
    end

    def self.immutable_text(value, maximum: nil)
      text = value.to_s
      text = text[0, maximum] if maximum
      text.dup.freeze
    end

    def self.default_provider
      @default_provider ||= PrimaryWithFallback.new(
        primary: AppleFoundationModelsProvider.new,
        fallback: StaticProvider.new
      )
    end
  end
end
