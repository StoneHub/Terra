# frozen_string_literal: true

module Terra
  # The god's art-supply cabinet: every emoji worth building with, hardcoded
  # and grouped. Pure data — nothing here touches the world. Tile::EMOJI stays
  # the authority on what terrain LOOKS like; Palette is the raw material you
  # reach into when inventing new things (`ordain`, custom features, marks).
  #
  # A note on color: emoji colors are baked into the font. There are exactly
  # nine colored squares and nine colored circles in Unicode — no #FFFAFA
  # variant exists, and none ever will. This closed set IS the palette.
  module Palette
    # The nine square tiles. This is the complete set Unicode offers.
    TILES = {
      red:    "🟥", orange: "🟧", yellow: "🟨",
      green:  "🟩", blue:   "🟦", purple: "🟪",
      brown:  "🟫", black:  "⬛", white:  "⬜",
    }.freeze

    # Same nine colors as circles — good for creatures, markers, resources.
    DOTS = {
      red_dot:    "🔴", orange_dot: "🟠", yellow_dot: "🟡",
      green_dot:  "🟢", blue_dot:   "🔵", purple_dot: "🟣",
      brown_dot:  "🟤", black_dot:  "⚫", white_dot:  "⚪",
    }.freeze

    # Diamonds and small squares — accents, ores, half-tiles.
    GEMS = {
      gem_orange: "🔶", gem_blue: "🔷", spark_orange: "🔸", spark_blue: "🔹",
      rosette: "💠", small_black: "◾", small_white: "◽",
    }.freeze

    # Raw material for `ordain :wolf, emoji: palette(:wolf), habitat: :land`.
    CREATURES = {
      wolf: "🐺", fox: "🦊", bear: "🐻", deer: "🦌", boar: "🐗",
      goat: "🐐", horse: "🐎", duck: "🦆", owl: "🦉", bat: "🦇",
      frog: "🐸", snake: "🐍", snail: "🐌", butterfly: "🦋", bee: "🐝",
      ladybug: "🐞", spider: "🕷️", scorpion: "🦂", crab: "🦀",
      octopus: "🐙", shark: "🦈", whale: "🐋", dolphin: "🐬",
      seal: "🦭", penguin: "🐧", dragon: "🐉", unicorn: "🦄", ghost: "👻",
    }.freeze

    # For plant species (`ordain :palm, emoji: palette(:palm), grows_on: [:desert]`).
    PLANTS = {
      palm: "🌴", oak: "🌳", sprout: "🌱", clover: "🍀", wheat: "🌾",
      sunflower: "🌻", tulip: "🌷", rose: "🌹", blossom: "🌸", hyacinth: "🪻",
    }.freeze

    # Things a civilization might raise — future world objects.
    STRUCTURES = {
      hut: "🛖", house: "🏠", castle: "🏰", tower: "🗼", shrine: "⛩️",
      moai: "🗿", bridge: "🌉", tent: "⛺", door: "🚪", brick: "🧱",
      rock: "🪨", log: "🪵", lantern: "🏮", fountain: "⛲", anchor: "⚓",
    }.freeze

    # The sky and the heavens.
    SKY = {
      sun: "☀️", rain: "🌧️", snowfall: "❄️", storm: "⛈️", tornado: "🌪️",
      rainbow: "🌈", fog: "🌫️", comet: "☄️", star: "⭐", moon: "🌙",
    }.freeze

    # Punctuation for the world: hazards, treasures, omens.
    MARKS = {
      fire: "🔥", skull: "💀", bolt: "⚡", boom: "💥", hole: "🕳️",
      sparkle: "✨", crown: "👑", gem: "💎", key: "🗝️", scroll: "📜",
      hourglass: "⏳", flag: "🚩", question: "❓", bang: "❗",
    }.freeze

    GROUPS = {
      tiles: TILES, dots: DOTS, gems: GEMS, creatures: CREATURES,
      plants: PLANTS, structures: STRUCTURES, sky: SKY, marks: MARKS,
    }.freeze

    # Every name in one flat hash. Group keys are kept globally unique so
    # this merge can never silently swallow an entry (the test suite checks).
    ALL = GROUPS.values.reduce(:merge).freeze

    # `extend Enumerable` + a class-level `each` makes the MODULE ITSELF
    # enumerable: Palette.count, Palette.select { … }, Palette.group_by { … }.
    # In Kotlin you'd need a companion object implementing Iterable; in Ruby
    # any object with `each` earns all ~50 Enumerable methods for free.
    # This is the doorway to Level 3.
    extend Enumerable

    def self.each(&block) = ALL.each(&block)

    # Palette[:wolf] → "🐺". Fetch raises on a miss — with the full menu.
    def self.[](name)
      ALL.fetch(name) do
        raise KeyError, "No #{name.inspect} in the palette. Try Palette.find(#{name.to_s.inspect}) or Palette.swatch"
      end
    end

    # Substring search over names: Palette.lookup("dot") → the nine circles.
    # (Not named `find` — Enumerable already owns `find`, and ours would
    # shadow it with a different meaning.)
    def self.lookup(text)
      ALL.select { |name, _| name.to_s.include?(text.to_s) }
    end

    # The whole cabinet, printed as swatches. A group Symbol narrows it.
    def self.swatch(group = nil)
      groups = group ? GROUPS.slice(group) : GROUPS
      return puts "No #{group.inspect} drawer. Drawers: #{GROUPS.keys.map(&:inspect).join(' ')}" if groups.empty?

      groups.each do |title, entries|
        puts "━━━ #{title.upcase} ━━━"
        entries.each_slice(4) do |row|
          puts row.map { |name, emoji| "#{emoji} #{name}".ljust(18) }.join
        end
      end
      nil
    end
  end
end
