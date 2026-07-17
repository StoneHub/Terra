# frozen_string_literal: true

module Terra
  # `world.rabbits`, `world.lilies`, `world.wolves`, `world.lakes` — the
  # plural of any creature or landform is a method. Implemented with
  # `method_missing` (Ruby's last stop before NoMethodError, and how Rails once
  # conjured find_by_name), always paired with respond_to_missing? so tooling
  # and IRB completion believe us.
  #
  # A mixin like this is Ruby's answer to a Kotlin interface with default
  # methods: World `include`s it and gains the behavior, no ceremony.
  # It expects its host to respond to #beings and #features.
  module SpeciesLookup
    def method_missing(name, *args, &blk)
      kind = kind_from_plural(name)
      if kind && args.empty?
        collection = Feature::REGISTRY.key?(kind) ? features : beings
        return collection.select { |thing| thing.kind == kind }
      end

      super
    end

    def respond_to_missing?(name, include_private = false)
      !kind_from_plural(name).nil? || super
    end

    private

    # rabbits → rabbit, lilies → lily, wolves → wolf, tortoises → tortoise.
    # Naive English, good enough for a bestiary.
    def kind_from_plural(name)
      n = name.to_s
      return nil unless n.end_with?("s")

      [n.chomp("s"), n.chomp("es"), n.sub(/ies\z/, "y"), n.sub(/ves\z/, "f")]
        .map(&:to_sym)
        .find { |k| Feature::REGISTRY.key?(k) || Animal::KINDS.key?(k) || Plant::KINDS.key?(k) }
    end
  end
end
