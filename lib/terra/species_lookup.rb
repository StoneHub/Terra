# frozen_string_literal: true

module Terra
  # `world.rabbits`, `world.lilies`, `world.wolves` — the plural of any
  # species is a method. Implemented with `method_missing` (Ruby's last stop
  # before NoMethodError, and how Rails once conjured find_by_name), always
  # paired with respond_to_missing? so tooling and IRB completion believe us.
  #
  # A mixin like this is Ruby's answer to a Kotlin interface with default
  # methods: World `include`s it and gains the behavior, no ceremony.
  # It expects its host to respond to #beings.
  module SpeciesLookup
    def method_missing(name, *args, &blk)
      kind = species_from_plural(name)
      return beings.select { |b| b.kind == kind } if kind && args.empty?

      super
    end

    def respond_to_missing?(name, include_private = false)
      !species_from_plural(name).nil? || super
    end

    private

    # rabbits → rabbit, lilies → lily, wolves → wolf, tortoises → tortoise.
    # Naive English, good enough for a bestiary.
    def species_from_plural(name)
      n = name.to_s
      return nil unless n.end_with?("s")

      [n.chomp("s"), n.chomp("es"), n.sub(/ies\z/, "y"), n.sub(/ves\z/, "f")]
        .map(&:to_sym)
        .find { |k| Animal::KINDS.key?(k) || Plant::KINDS.key?(k) }
    end
  end
end
