# frozen_string_literal: true

module Terra
  # The god powers. Terra.genesis `extend`s this onto IRB's top-level object,
  # so everything here is callable bare at the prompt: `spawn :lake`, `pass`.
  module Godhood
    # `class << self` opens the module's own singleton — this is a module-level
    # accessor (Godhood.world), the game's one piece of global state.
    class << self
      attr_accessor :world
    end

    def world = Godhood.world

    # The illustrated HTML manual that ships next to the game.
    COMPANION = File.expand_path("../../companion.html", __dir__)

    # Open the companion in the default browser. The opener is injectable
    # (a lambda default!) so tests can spy on it without launching Safari.
    def companion(opener: ->(path) { system("open", path) })
      return puts("📖 The companion is missing — expected at #{COMPANION}") unless File.exist?(COMPANION)

      if opener.call(COMPANION)
        puts "📖 The companion opens in your browser."
      else
        puts "📖 Open it yourself:  file://#{COMPANION}"
      end
      nil
    end

    # Complete, copy-paste-safe vignettes for gods who are stuck.
    GRIMOIRE = [
      { title: "The Pilgrimage", lore: "A rabbit with divine purpose.",
        lines: ['pilgrim = spawn(:rabbit) { |r| r.hop_toward :water }',
                'pass 10',
                'pilgrim   # where did faith take it?'] },
      { title: "Fimbulwinter", lore: "Call winter across the world. The fish wait, patient, trapped.",
        lines: ['winter!',
                'pass 5    # nothing swims',
                'spring!'] },
      { title: "Mirkwood Rising", lore: "Plant one wood, let it swallow the map.",
        lines: ['woods = spawn :forest, name: "Mirkwood"',
                '3.times { woods.grow! }'] },
      { title: "The Census", lore: "A god should know what it governs.",
        lines: ['world.beings.group_by(&:kind).transform_values(&:count)',
                'world.animals.max_by(&:age)   # the elder'] },
      { title: "The Reckoning", lore: "Judgment day for everything past its fifth year.",
        lines: ['elders = world.animals.select { |a| a.age > 5 }',
                'smite elders'] },
      { title: "Nightfall", lore: "Darkness is a pause; the Great Freeze is an ending. Feel the difference.",
        lines: ['let_there_be :darkness',
                'pass 3    # refused — time needs light',
                'let_there_be :light   # everything exactly as it was'] },
      { title: "The Long Silence", lore: "Walk away. See what the world does without you.",
        lines: ['pass 30',
                'chronicle'] },
      { title: "A New Predator", lore: "Ordain it, arm it, aim it at the woods.",
        lines: ['ordain :wolf, emoji: "🐺", habitat: :land, speed: 3',
                'spawn(:wolf, count: 2) { |w| w.hop_toward :forest }',
                'pass 7'] },
      { title: "Doomsday", lore: "End a world properly: memorialize it, invoke the Great Freeze, move on.",
        lines: ['great_freeze!',
                'chronicle!   # includes the final Great Freeze',
                'big_bang! width: 20, height: 12'] },
      # ---- Great Works: multi-step builds ----
      { title: "The Prairie World", lore: "A living grassland from nothing, in seven lines.",
        lines: ['big_bang! width: 20, height: 12',
                'let_there_be :light',
                'terraform :meadow',
                'spawn :lake, size: 3',
                'let_there_be :life',
                'sow 20',
                'pass 30'] },
      { title: "The Archipelago", lore: "Drown the world, then raise islands in it.",
        lines: ['big_bang! width: 20, height: 12',
                'let_there_be :light',
                'terraform :water',
                'spawn :grassland, size: 2   # an island',
                'spawn :grassland, size: 2   # another',
                'let_there_be :life',
                'spawn :fish, count: 4',
                'spawn :hawk',
                'pass 20'] },
      { title: "The Wolf Winter", lore: "Predators in the pines while nothing grows.",
        lines: ['eden!',
                'ordain :wolf, emoji: "🐺", habitat: :land, speed: 3',
                'spawn(:wolf, count: 3) { |w| w.hop_toward :forest }',
                'let_there_be :snow',
                'pass 15',
                'chronicle'] },
      { title: "The Rain Garden", lore: "Wet skies, green scars — then have the world write it down.",
        lines: ['eden!',
                'sow 20',
                'let_there_be :rain',
                'pass 20',
                'chronicle!'] },
    ].freeze

    # Chapters for `guide :topic`. (Named `guide`, not `help` — IRB claims
    # `help` as its own REPL command before our method ever gets a look.)
    GUIDEBOOK = {
      spawn: <<~TXT,
        spawn — bring things into being. Returns the thing; hold it.
          spawn :lake, at: [4, 3], size: 3, name: "Mirrormere"   (all kwargs optional)
          spawn :river, at: [0, 4], length: world.width, width: 2
          landforms: :lake :river :mountain :forest :desert :grassland (🌾 = green grass)
          spawn :rabbit, count: 5              creatures need `let_there_be :life`
          spawn(:rabbit) { |r| r.wander }      a block becomes its brain (parens!)
        terraform :meadow — repaint every barren 🟫 tile at once (:sand, :water, …)
      TXT
      smite: <<~TXT,
        smite — by place or by thing. Starts a small fire; leaves 💀 remains for ~2 days.
          smite at: [3, 4]  /  smite 3, 4      the tile; splash damage; can miss
          smite wolf  /  smite herd            a reference never misses
          smite :tortoise                      by kind — only if exactly one matches
      TXT
      unmake: <<~TXT,
        unmake — removal without wrath. Land reverts to barren 🟫 plains.
          unmake :forest / unmake "Mirkwood"   kind or name; one match only
          unmake world.features.last           references are always precise
          unmake herd                          arrays work
      TXT
      pass: <<~TXT,
        pass — the only clock. Nothing moves while you watch.
          pass          one day       pass 7        a week
          world.day     the calendar  chronicle     what happened
      TXT
      sow: <<~TXT,
        sow — scatter seeds; the terrain decides what grows.
          sow 12                     🌿🌼 grassland · 🍄 forest · 🌵 sand · 🪷 water
          sow 6, on: :sand           only the desert
        Seeds on stone (or on another plant) are lost — the note says how many.
        Each root seed has a finite colony budget shared by all its descendants.
      TXT
      weather: <<~TXT,
        weather — the sky shifts as days pass; the map header IS the forecast.
          ☀️ clear   🌧️ rain (plants spread ×2)   ❄️ snow (plants pause)
          ⛈️ storm — lightning starts a finite spreading fire; ◾ marks cooled ash
          let_there_be :rain / :snow / :storm / :clear     command it yourself
          world.weather                                    ask it
      TXT
      brains: <<~TXT,
        brains — a block replaces instinct, runs once per creature-day.
          spawn(:rabbit) { |r| r.hop_toward :water }        brace form NEEDS parens
          spawn :hawk do |h| h.hop_toward [0, 0] end        do…end doesn't
          verbs: wander · hop_toward(:forest / [x, y]) · stay · nearest(:water) · age · tile
      TXT
      ordain: <<~TXT,
        ordain — invent a species (session-only; edit animal.rb/plant.rb to keep it).
          ordain :wolf, emoji: "🐺", habitat: :land, speed: 3
          ordain :cactus, emoji: "🌵", grows_on: [:sand], spread: 0.05, spread_limit: 2, lifespan: 40
      TXT
      targeting: <<~TXT,
        targeting — the REPL is your radar; every echo shows coords.
          world.animals / world.rabbits        collections (plural of any species)
          world.at(5, 1)                       who's standing there
          world.animals.select { |a| a.near?(lake) }        Enumerable is the aim
          lost a reference?  world.features.find { |f| f.name == "Mirkwood" }  or  _
      TXT
      chronicle: <<~TXT,
        chronicle — the world writes its own scripture.
          chronicle           recent acts       chronicle!    the illuminated HTML
          world.history       raw entries: { day:, note:, map: }
      TXT
      darkness: <<~TXT,
        darkness — the reversible night. let_there_be :darkness hides the world
        (all ⬛) and time refuses to pass; let_there_be :light restores it exactly.
        Compare :great_freeze — a boolean pauses, a frozen object ends.
      TXT
      winter: <<~TXT,
        winter — reversible world climate, ordinary mutable game state.
          winter!      water ices, fire dies, snow holds, fish wait
          spring!      only water frozen by that winter thaws again
          lake.ice_over! / lake.thaw!     change one lake instead
      TXT
      great_freeze: <<~TXT,
        great_freeze — the universe runs out of usable energy. Permanent.
          great_freeze!     the story command
          world.frozen?     Ruby's real Object#frozen? answers true
          big_bang!         bind a newly created World; nothing was unfrozen
        Under the hood World#freeze sets the ending, then `super` invokes
        Object#freeze. That is the teaching example: extend behavior, preserve
        the superclass contract. Ruby has no unfreeze.
      TXT
      eden: <<~TXT,
        eden! — a ready-made world: light, land, life, day 0. Then edit it:
        unmake what displeases you, spawn what's missing, pass to let it live.
        Takes width:/height: like big_bang!.
      TXT
    }.freeze

    # Interactive help: bare `guide` reads the world and says where you
    # stand; `guide :smite` opens a chapter.
    def guide(topic = nil)
      return puts(GUIDEBOOK[topic] || "No chapter on #{topic.inspect}. Chapters: #{GUIDEBOOK.keys.map(&:inspect).join(' ')}") if topic

      puts "━━━ WHERE YOU STAND ━━━"
      situation.each { |line| puts line }
      puts
      puts "━━━ CHAPTERS ━━━"
      puts "guide #{GUIDEBOOK.keys.map(&:inspect).join(' · guide ')}"
      puts "(powers = the full sheet · inspire = a ritual to copy)"
      nil
    end

    # One vignette at random; inspire :all for the whole grimoire.
    def inspire(which = nil)
      if which == :all
        GRIMOIRE.each { |v| print_vignette(v) }
      else
        print_vignette(GRIMOIRE.sample)
        puts "\n(inspire again for another · inspire :all for the whole grimoire)"
      end
      nil
    end

    def let_there_be(what)
      return frozen_lament if world.frozen?

      case what
      when :light
        return puts("The light already shines.") if world.lit?
        world.illuminate!
        puts "And there was light. 🌅"
        world.behold!
      when :darkness
        return puts("The dark is already absolute.") unless world.lit?
        world.benight!
        puts "You withdraw the light. The world is not gone — only unseen."
        world.behold!
      when :life
        summon_life
      when :rain, :snow, :storm, :clear
        return puts("The sky needs a world beneath it. First: let_there_be :light") unless world.lit?
        if world.winter? && what != :snow
          return puts("Winter holds the sky at :snow. Speak `spring!` before commanding another sky.")
        end
        world.weather = what
        puts "The sky obeys. #{World::WEATHER.fetch(what)}"
        world.behold!
      else
        puts "The void does not understand #{what.inspect}. " \
             "It knows :light, :darkness, :life — and the skies: :rain, :snow, :storm, :clear."
        nil
      end
    end

    # Repaint every remaining tile of barren earth (:plains) as the given
    # terrain. Claimed and grown land is untouched — this fills the empty
    # spaces between your works.
    def terraform(terrain)
      return frozen_lament if world.frozen?
      return puts("Terraforming needs light. First: let_there_be :light") unless world.lit?
      return puts("Barren ground is already its own nature.") if terrain == :plains

      unless Tile::EMOJI.key?(terrain) && terrain != :void
        return puts("The land refuses #{terrain.inspect}. It knows: " \
                    "#{(Tile::EMOJI.keys - %i[void plains]).map(&:inspect).join(', ')}")
      end

      barren = world.tiles.select { |t| t.terrain == :plains }
      return puts("No barren ground remains — every tile is claimed or grown.") if barren.empty?

      barren.each { |t| t.terrain = terrain }
      world.record!("#{Tile::EMOJI.fetch(terrain)} The god terraforms — #{barren.size} barren tiles become #{terrain}")
      world.behold!
      puts "#{barren.size} tiles of barren earth become #{terrain}."
      nil
    end

    # Scatter seeds across the world; each takes root as whatever species is
    # native to the terrain it lands on — cactus on sand, lily on water.
    # Seeds landing on stone (or on another plant) are simply lost.
    def sow(count = 8, on: nil)
      return frozen_lament if world.frozen?
      return puts("Seeds need light. First: let_there_be :light") unless world.lit?
      return puts("Seeds need life itself. First: let_there_be :life") unless world.life?

      field = on ? world.tiles.select { |t| t.terrain == on } : world.tiles
      return puts("No #{on.inspect} anywhere to sow.") if field.empty?

      sown = Hash.new(0)
      lost = 0
      count.times do
        tile = field.sample
        natives = Plant::KINDS.select { |_, spec| spec[:grows_on].include?(tile.terrain) }.keys
        taken = world.plants.any? { |p| p.pos == [tile.x, tile.y] }
        if natives.empty? || taken
          lost += 1
          next
        end
        kind = natives.sample
        world.breathe(kind, at: [tile.x, tile.y], record: false)
        sown[kind] += 1
      end

      tally = sown.map { |kind, n| "#{Plant::KINDS.fetch(kind)[:emoji]}×#{n}" }.join(" ")
      note = "🌱 The god scatters #{count} seeds — #{tally.empty? ? 'none take root' : tally}"
      note += " (#{lost} fall on stone)" if lost.positive?
      world.record!(note)
      world.behold!
      puts note
      world.plants.last(sown.values.sum)
    end

    # Keyword args with defaults — Ruby's version of Kotlin named/default
    # params. The &brain slurps an attached block into a Proc; note that a
    # brace block needs parens — spawn(:rabbit) { |r| ... } — while do…end
    # works without them. NB: this shadows Kernel#spawn (process launching)
    # at the prompt, which is exactly what we want.
    def spawn(kind, at: nil, size: 2, name: nil, count: 1, length: nil, width: nil, &brain)
      return frozen_lament if world.frozen?

      unless world.lit?
        puts "🌑 The void swallows your creation. First: let_there_be :light"
        return
      end

      if kind != :river && (!length.nil? || !width.nil?)
        return puts("`length:` and `width:` shape rivers only. Try: spawn :river, length: world.width, width: 2")
      end

      if (klass = Feature::REGISTRY[kind])
        shape = { world: world, at: at, size: size, name: name }
        shape[:length] = length unless length.nil?
        shape[:width] = width unless width.nil?
        feature = klass.create(**shape)
        world.behold!
        feature
      elsif Animal::KINDS.key?(kind) || Plant::KINDS.key?(kind)
        breathe_creature(kind, at: at, count: count, brain: brain)
      else
        puts "You know no #{kind.inspect}."
        puts "Landforms: #{Feature::REGISTRY.keys.map(&:inspect).join(', ')}"
        puts "Creatures (after let_there_be :life): " \
             "#{(Animal::KINDS.keys + Plant::KINDS.keys).map(&:inspect).join(', ')}"
        puts %(Or invent it: ordain #{kind.inspect}, emoji: "…", habitat: :land)
        nil
      end
    end

    # Time is a verb. Nothing in Terra moves except through here.
    def pass(days = 1)
      return frozen_lament if world.frozen?
      return puts("Time cannot pass in a world without light.") unless world.lit?
      return puts("Time flows forward only.") unless days.is_a?(Integer) && days >= 1

      world.advance!(days)
      world.behold!
      nil
    end

    # Two ways to aim. Coordinates smite a PLACE — splash damage, and it can
    # miss if the creature moved since you looked. A reference smites the
    # THING and never misses: IRB hands you live objects, so hold onto them.
    #   smite at: [5, 1]   ·   smite 5, 1          the tile
    #   smite wolf         ·   smite world.animals.select { … }
    def smite(*targets, at: nil)
      return frozen_lament if world.frozen?

      targets = targets.flatten
      if at.nil? && targets.size == 2 && targets.all?(Integer)
        at = targets
        targets = []
      end
      if at.nil? && targets.empty?
        return puts("Aim first: smite at: [3, 4] · smite 5, 1 · smite wolf · smite herd")
      end

      epitaphs = []
      if at
        tile = world.at(*at)
        return puts("Your wrath sails off the edge of the world.") unless tile
        epitaphs.concat(strike_tile(tile))
      end
      targets.each do |t|
        case t
        when Being
          epitaphs.concat(strike_tile(t.tile)) if world.beings.include?(t)
        when Feature
          epitaphs << "Your lightning glances off #{t.title}. (`unmake` removes landforms.)"
        when Symbol, String
          matches = resolve_by_name(t)
          creatures = matches.grep(Being)
          if creatures.size == 1
            epitaphs.concat(strike_tile(creatures.first.tile))
          elsif creatures.size > 1
            epitaphs << "The bolt hovers — #{creatures.size} answer to #{t.inspect}. Pick one:"
            epitaphs.concat(creatures.map { |c| "  #{c.inspect}" })
          elsif matches.any?
            epitaphs << "Your lightning glances off landforms. (`unmake` removes those.)"
          else
            epitaphs << "No #{t.inspect} to strike."
          end
        else
          epitaphs << "The bolt fizzles at #{t.inspect} — smite takes creatures, or at: [x, y]."
        end
      end

      note = at ? "⚡ Lightning strikes (#{at.join(', ')})" : "⚡ Lightning falls"
      note += " — #{epitaphs.join(' · ')}" if epitaphs.any?
      world.record!(note)
      world.behold!
      puts epitaphs.join("\n") unless epitaphs.empty?
      at ? world.at(*at) : nil
    end

    def behold = world

    # The story so far, in the terminal.
    def chronicle(last: 12)
      entries = world.history.last(last)
      return puts("Nothing has happened yet. Make something.") if entries.empty?

      puts "…#{world.history.size - entries.size} earlier acts…" if world.history.size > entries.size
      entries.each { |e| puts "Day #{e[:day].to_s.rjust(3)} — #{e[:note]}" }
      puts "(chronicle! writes the illuminated HTML version)"
      nil
    end

    # The story so far, as a page. Works even on a frozen world — the
    # history Array was never frozen, only the world holding it.
    def chronicle!(path: "terra-chronicle.html")
      return puts("Nothing has happened yet. Make something worth recording.") if world.history.empty?

      file = Chronicle.write(world, path: path)
      puts "📜 The chronicle is written: #{File.expand_path(file)}"
      puts "   open it:  open #{file}"
      nil
    end

    # Reversible climate powers. These mutate simulation state and are not
    # Ruby Object#freeze; their seasonal names keep that distinction visible.
    def winter!
      return frozen_lament if world.frozen?
      return puts("Winter needs a world beneath it. First: let_there_be :light") unless world.lit?
      return puts("Winter already holds the world.") if world.winter?

      world.winter!
      world.behold!
      puts "❄️ Winter takes the world. Water ices, fires fail, and snow holds."
      nil
    end

    def spring!
      return frozen_lament if world.frozen?
      return puts("There is no winter to thaw.") unless world.winter?

      world.spring!
      world.behold!
      puts "🌱 Spring answers. The waters claimed by winter run again."
      nil
    end

    # The narrative doorway to Ruby's actual freeze semantics. World#freeze
    # adds Terra's ending and calls `super`, which reaches Object#freeze.
    def great_freeze!
      return frozen_lament if world.frozen?

      world.freeze
      world.behold!
      puts "🥶 No gradients remain. No fire burns. This universe has reached the Great Freeze."
      puts "   `world.frozen?` is true. Only `big_bang!` can begin another universe."
      nil
    end

    # The only escape from a frozen world: abandon it. Rebinding
    # Godhood.world orphans the old World object entirely — frozen objects
    # can't be thawed, only left for the garbage collector. Also the only
    # way to a bigger canvas: worlds are born with their size.
    def big_bang!(width: World::DEFAULT_WIDTH, height: World::DEFAULT_HEIGHT)
      birth!(width: width, height: height)
      puts "The old universe collapses behind you. A new void awaits. ✨"
      world.behold!
    end

    # A ready-made world: light, land, life — then it's yours to edit.
    # Everything here goes through the same paths your own commands use.
    def eden!(width: World::DEFAULT_WIDTH, height: World::DEFAULT_HEIGHT)
      birth!(width: width, height: height)
      world.illuminate!
      world.bestow_life!

      scale = (world.width * world.height) / 108.0 # relative to the 12×9 default
      n = ->(base) { [(base * scale).round, 1].max }

      n.(2).times { Feature::REGISTRY[:lake].create(world: world, size: 2) }
      n.(1).times { Feature::REGISTRY[:mountain].create(world: world, size: 3) }
      n.(1).times { Feature::REGISTRY[:forest].create(world: world, size: 2) }
      n.(1).times { Feature::REGISTRY[:desert].create(world: world, size: 2) }

      { rabbit: 3, tortoise: 1, fish: 2, hawk: 1, fern: 4, flower: 3, lily: 2 }
        .each { |kind, base| world.breathe(kind, count: n.(base)) }

      world.behold!
      puts "🌏 A world, ready-made — and yours to edit. `unmake` what displeases you;"
      puts "   `pass 7` to see it live. (`powers` for everything else.)"
      nil
    end

    # Remove things you've made — by reference (precise), by kind (:lake),
    # or by name ("Mirkwood"). Kind and name only act when exactly one thing
    # matches; ambiguity lists the candidates instead of guessing.
    # Unmade land reverts to plains — water lives only where lakes do.
    def unmake(*things)
      return frozen_lament if world.frozen?

      targets = things.flatten
      if targets.empty?
        return puts(%(Point at a thing: unmake :lake · unmake "Mirkwood" · unmake world.animals.first))
      end

      resolved = []
      notes = []
      targets.each do |t|
        case t
        when Feature, Being
          resolved << t
        when Symbol, String
          matches = resolve_by_name(t)
          case matches.size
          when 0 then notes << "No #{t.inspect} in this world."
          when 1 then resolved.concat(matches)
          else
            notes << "#{matches.size} things answer to #{t.inspect}:"
            notes.concat(matches.map { |m| "  #{m.inspect}" })
            notes << "Names are ambiguous; references are not. Try world.features or the plural (world.lakes)."
          end
        else
          notes << "You cannot unmake #{t.inspect}."
        end
      end

      epitaphs = resolved.filter_map { |t| unmake_one(t) }
      world.record!("🕳️ #{epitaphs.join(' · ')}") if epitaphs.any?
      world.behold! if epitaphs.any?
      puts (epitaphs + notes).join("\n") if epitaphs.any? || notes.any?
      nil
    end

    # Invent a species: an animal (habitat: + speed:) or a plant (grows_on:
    # + spread:/spread_limit:/lifespan:). Just data in an open hash — no new
    # classes needed.
    def ordain(kind, emoji: nil, habitat: nil, speed: 1, grows_on: nil, spread: 0.15,
               spread_limit: Plant::DEFAULT_SPREAD_LIMIT, lifespan: 10)
      return frozen_lament if world.frozen?
      unless kind.is_a?(Symbol) && emoji
        puts %(Name and mark it: ordain :wolf, emoji: "🐺", habitat: :land, speed: 3)
        puts %(Plants take root:  ordain :cactus, emoji: "🌵", grows_on: [:sand], spread_limit: 2, lifespan: 40)
        return
      end

      known = Animal::KINDS.key?(kind) || Plant::KINDS.key?(kind)
      if habitat
        unless Animal::PASSABLE.key?(habitat)
          return puts("Habitat must be one of: #{Animal::PASSABLE.keys.map(&:inspect).join(', ')}")
        end
        Animal.ordain(kind, emoji: emoji, habitat: habitat, speed: speed)
        puts "#{emoji} #{known ? 'You reshape' : 'Into the book of species goes'} the #{kind} — #{habitat}, speed #{speed}."
      elsif grows_on
        Plant.ordain(kind, emoji: emoji, grows_on: grows_on, spread: spread,
                    spread_limit: spread_limit, lifespan: lifespan)
        puts "#{emoji} #{known ? 'You reshape' : 'Into the book of species goes'} the #{kind} — roots in #{Array(grows_on).join('/')}, each seed may spread #{spread_limit} cells."
      else
        return puts("Give it a nature: habitat: :land/:water/:air (animal) or grows_on: [:plains] (plant).")
      end
      puts "   spawn #{kind.inspect} awaits. (Session-only — edit lib/terra/animal.rb or plant.rb to make it eternal.)"
      world.record!("📖 #{emoji} The #{kind} is ordained into the book of species")
      nil
    end

    def powers
      puts <<~SHEET
        ━━━ THE LAWS OF TERRA ━━━
        ⚡ The echo is the UI — every value draws itself. `world` IS the map.
        ⏳ Time passes only when you `pass`. Between commands, a photograph.
        🥶 `great_freeze!` calls Ruby's real Object#freeze through `super`. No undo.

        ━━━ LEVEL 1: GENESIS ━━━
        let_there_be :light                              begin creation
        let_there_be :darkness                           withdraw it — a reversible night
        winter! / spring!                                reversible world climate
        spawn :lake, at: [4, 3], size: 2, name: "…"      also :mountain :forest :desert
        spawn :river, at: [0, 4], length: 12, width: 2   🌊 connected water across the map
        spawn :grassland                                 🌾 green grass (:meadow) on demand
        terraform :meadow                                repaint ALL barren 🟫 — any terrain
        smite at: [x, y] / smite 5, 1                    🔥 the place — starts a small fire
        smite wolf / smite herd                          🔥 the thing — never misses
        unmake :lake / unmake "Mirkwood"                 by kind or name (one match only)
        unmake world.features.last                       by reference — always precise
        big_bang! width: 20, height: 12                  begin again — bigger, if you ask
        great_freeze!                                    heat death — this World ends forever
        eden! width: 16, height: 10                      a ready-made world, yours to edit
        world / behold      the map                      world.at(x, y)   one tile
        world.features      everything you have made     world.history    every recorded act
        chronicle / chronicle!                           the story so far / written as HTML
        inspire / inspire :all                           a worked example when you're stuck
        guide / guide :smite                             where you stand + chapters of help
        companion                                        open the illustrated HTML manual

        Every spawn RETURNS the thing — hold it and poke it:
          lake = spawn :lake        lake.name = "Mirrormere"
          lake.ice_over!  lake.thaw!  mountain.erupt!  forest.grow!
      SHEET

      status = world.life? ? "🔓" : "🔒 sleeping — wake it: let_there_be :life"
      puts <<~SHEET
        ━━━ LEVEL 2: LIFE #{status} ━━━
        let_there_be :life          wake the world; everything below needs it
        spawn :rabbit, count: 5     🐇 land, speed 2     spawn :fern     🌿 finite colony
        spawn :tortoise             🐢 land, speed 1     spawn :flower   🌼 plains, blooms
        spawn :fish                 🐟 water only        spawn :lily     🪷 water
        spawn :hawk                 🦅 flies anywhere    spawn :cactus   🌵 :mushroom 🍄 too
        sow 12 / sow 6, on: :sand   scatter seeds; each grows what its terrain allows
                                    (🌿🌼 grassland · 🍄 forest · 🌵 sand · 🪷 water)
        pass / pass 7               let days happen — animals roam, plants live & die
        let_there_be :rain          command the sky: :rain :snow :storm :clear
                                    (it also shifts on its own as days pass — the map
                                     header IS the forecast; rain feeds plants, snow
                                     stills them, storm lightning spreads fire briefly)
        world.animals / world.plants                 everything alive, as arrays
        world.rabbits / world.lilies / world.wolves  the plural of any species works

        Divine brains — a block replaces instinct, runs once per day:
          spawn(:rabbit) { |r| r.hop_toward :water }
          verbs: r.wander · r.hop_toward(:forest) · r.hop_toward([x, y]) · r.stay

        Invent species — new entries in an open registry:
          ordain :wolf, emoji: "🐺", habitat: :land, speed: 3
          ordain :bramble, emoji: "🌾", grows_on: [:sand], spread: 0.05, spread_limit: 3, lifespan: 40

        🔒 Level 3: Providence — Enumerable as divine power
      SHEET
      nil
    end

    private

    # A Symbol finds things by kind; a String finds features by their name.
    def resolve_by_name(ref)
      case ref
      when Symbol
        world.features.select { |f| f.kind == ref } +
          world.beings.select { |b| b.kind == ref }
      when String
        world.features.select { |f| f.name.casecmp?(ref) }
      end
    end

    # Reads world state and suggests the next sensible act.
    def situation
      return ["🥶 The Great Freeze has ended this world. Write chronicle!, then big_bang!."] if world.frozen?

      if !world.lit?
        return ["🌑 Darkness. The world waits beneath, intact.", "   → let_there_be :light"] if world.day.positive? || world.features.any?
        return ["🌑 The void. Nothing exists yet.", "   → let_there_be :light   (or eden! to skip ahead)"]
      end

      lines = ["☀️  Day #{world.day} — #{world.features.size} landforms, " \
               "#{world.animals.count} animals, #{world.plants.count} plants."]
      lines << "   → spawn :lake / :mountain / :forest — shape the land" if world.features.empty?
      lines << "   → let_there_be :life — the world is ready to breathe" unless world.life?
      lines << "   → spawn :rabbit, count: 3 — life is unlocked but nothing lives" if world.life? && world.beings.empty?
      lines << "   → pass 7 — you have creatures, but time has never moved" if world.beings.any? && world.day.zero?
      lines << "   → all is well; pass some days, or inspire for mischief" if lines.one?
      lines
    end

    def print_vignette(v)
      puts "\n— #{v[:title]} —  #{v[:lore]}"
      v[:lines].each { |l| puts "  #{l}" }
    end

    # Divine smites and natural storms share one bolt (World#lightning!);
    # only the god's version gets epitaphs.
    def strike_tile(tile)
      world.lightning!(tile).map { |v| "#{v.emoji} The smite claims the #{v.kind}." }
    end

    def birth!(width:, height:)
      w = width.clamp(4, 40)
      h = height.clamp(4, 30)
      puts "(The fabric of space stretches only so far: #{w}×#{h}.)" if [w, h] != [width, height]
      Godhood.world = World.new(width: w, height: h)
      world.record!("✨ A universe is born — #{w} × #{h} of patient void")
    end

    def unmake_one(thing)
      case thing
      when Feature
        return nil unless world.features.delete(thing)
        # Only tiles still owned by this feature revert — later features may
        # have claimed some of them (equal? is identity, not ==).
        thing.tiles.each do |t|
          next unless t.feature.equal?(thing)
          t.feature = nil
          t.terrain = :plains
        end
        "#{thing.title} is unmade; the plains forget it ever was."
      when Being
        return nil unless world.beings.delete(thing)
        "#{thing.emoji} The #{thing.kind} returns to dust."
      end
    end

    def summon_life
      return puts("Life needs light. First: let_there_be :light") unless world.lit?
      return puts("Life already stirs in this world.") if world.life?

      world.bestow_life!
      puts <<~LIFE
        🌱 And the world drew breath. New forms answer your call:
          spawn :rabbit, count: 3    🐇 land, fast      spawn :fern     🌿 spreads on land
          spawn :tortoise            🐢 land, slow      spawn :flower   🌼 blooms on plains
          spawn :fish                🐟 water-locked    spawn :lily     🪷 floats on water
          spawn :hawk                🦅 goes anywhere

        ⏳ Time is yours too: `pass` advances one day, `pass 7` a week.
           Nothing moves while you are looking. (`powers` for the details.)
      LIFE
      nil
    end

    def breathe_creature(kind, at:, count:, brain:)
      unless world.life?
        puts "The #{kind} is inert clay. Life itself is missing: let_there_be :life"
        return
      end
      if brain && Plant::KINDS.key?(kind)
        puts "🌱 Plants have no will of their own — your block drifts away on the wind."
        brain = nil
      end

      born = world.breathe(kind, at: at, count: count, brain: brain)
      return puts("No hospitable ground for #{kind.inspect} anywhere in this world.") if born.empty?

      world.behold!
      puts "⏳ Nothing will move until you `pass`." if world.day.zero? && born.first.is_a?(Animal)
      born.one? ? born.first : born
    end

    # Shown when any power is used after the Great Freeze.
    def frozen_lament
      puts <<~MSG
        🥶 The Great Freeze has ended this world. Nothing answers you.
        World#freeze called `super`, reaching Ruby's Object#freeze: permanent,
        shallow immutability. There is no unfreeze; there never has been.
        Speak `big_bang!` to abandon this universe and begin again.
      MSG
    end
  end
end
