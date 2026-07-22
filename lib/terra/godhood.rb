# frozen_string_literal: true

module Terra
  # The god powers. Terra.genesis `extend`s this onto IRB's top-level object,
  # so everything here is callable bare at the prompt: `spawn :lake`, `pass`.
  module Godhood
    # `class << self` opens the module's own singleton (≈ Kotlin companion
    # object) — Godhood.world / Godhood.mentor? are module-level state.
    class << self
      attr_accessor :world
      attr_writer :mentor

      def mentor? = @mentor != false # never-set @ivar is nil, and nil != false → defaults on
    end

    def world = Godhood.world

    # THE LAW OF COST — acting IS spending time. Every successful act below
    # charges days from this table the moment it completes; a refused act
    # charges nothing. Observations (guide, powers, chronicle…) are
    # free: looking at the world never moves it. Costs live here as data so
    # the game can be re-balanced without touching any mechanic.
    TIME_COSTS = {
      let_there_be: 1, spawn: 1, sow: 1, smite: 1, unmake: 1, ordain: 1,
      terraform: 3,           # reshaping a continent is slow work
      winter!: 2, spring!: 2, # the seasons turn on their own schedule
    }.freeze

    # Sentinel refuse! throws and enact swallows. A plain Object: all it
    # needs is an identity nothing else shares (compare Kotlin's `object`).
    REFUSED = Object.new

    # The mentor's private RNG — sample(random:) draws from it so hints
    # never nudge the simulation's global rand (or srand-seeded tests).
    MENTOR_RNG = Random.new

    # The illustrated HTML manual that ships next to the game.
    COMPANION = File.expand_path("../../companion.html", __dir__)

    # Injectable opener — tests pass a spy lambda instead of launching Safari.
    def companion(opener: ->(path) { system("open", path) }) # ->(x) { } is a lambda literal; a DEFAULT can be one
      return puts("📖 The companion is missing — expected at #{COMPANION}") unless File.exist?(COMPANION)

      if opener.call(COMPANION)
        puts "📖 The companion opens in your browser."
      else
        puts "📖 Open it yourself:  file://#{COMPANION}"
      end
      nil
    end

    # Interactive help: bare `guide` reads the world and says where you
    # stand; `guide :smite` opens a chapter.
    def guide(topic = nil)
      return puts(Lore::GUIDEBOOK[topic] || "No chapter on #{topic.inspect}. Chapters: #{Lore::GUIDEBOOK.keys.map(&:inspect).join(' ')}") if topic

      puts "━━━ WHERE YOU STAND ━━━"
      situation.each { |line| puts line }
      puts
      puts "━━━ CHAPTERS ━━━"
      puts "guide #{Lore::GUIDEBOOK.keys.map(&:inspect).join(' · guide ')}"
      puts "(powers = the full sheet · inspire = a ritual to copy)"
      nil
    end

    # One vignette at random; inspire :all for the whole grimoire.
    def inspire(which = nil)
      if which == :all
        Lore::GRIMOIRE.each { |v| print_vignette(v) }
      else
        print_vignette(Lore::GRIMOIRE.sample)
        puts "\n(inspire again for another · inspire :all for the whole grimoire)"
      end
      nil
    end

    def let_there_be(what)
      enact(:let_there_be) do
        case what
        when :light
          refuse!("The light already shines.") if world.lit?
          world.illuminate!
          puts "And there was light. 🌅"
        when :life
          refuse!("Life needs light. First: let_there_be :light") unless world.lit?
          refuse!("Life already stirs in this world.") if world.life?
          world.bestow_life!
          puts(Lore::LIFE)
        else
          # The sky path asks the registry, not a hardcoded list — a newly
          # added Weather kind is commandable with zero changes here.
          unless Weather::REGISTRY.key?(what)
            refuse!("The void does not understand #{what.inspect}. It knows :light, :life — " \
                    "and the skies: #{Weather::REGISTRY.keys.map(&:inspect).join(', ')}.")
          end
          refuse!("The sky needs a world beneath it. First: let_there_be :light") unless world.lit?
          begin
            world.weather = what # World enforces the winter lock and raises
          rescue ArgumentError => e
            refuse!(e.message) # rescue…=> e captures it; its words become the refusal
          end
          puts "The sky obeys. #{world.sky.emoji}"
        end
        nil
      end
    end

    # Repaint every remaining tile of barren earth (:plains) as the given
    # terrain. Claimed and grown land is untouched — this fills the empty
    # spaces between your works.
    def terraform(terrain)
      enact(:terraform) do
        refuse!("Terraforming needs light. First: let_there_be :light") unless world.lit?
        refuse!("Barren ground is already its own nature.") if terrain == :plains

        unless Tile::EMOJI.key?(terrain) && terrain != :void
          refuse!("The land refuses #{terrain.inspect}. It knows: " \
                  "#{(Tile::EMOJI.keys - %i[void plains]).map(&:inspect).join(', ')}")
        end

        barren = world.tiles.select { |t| t.terrain == :plains }
        refuse!("No barren ground remains — every tile is claimed or grown.") if barren.empty?

        barren.each { |t| t.terrain = terrain }
        world.record!("#{Tile::EMOJI.fetch(terrain)} The god terraforms — #{barren.size} barren tiles become #{terrain}")
        puts "#{barren.size} tiles of barren earth become #{terrain}."
        nil
      end
    end

    # Scatter seeds; the terrain each lands on decides the species —
    # cactus on desert, lily on water. Stone (or an occupied tile) loses the seed.
    def sow(count = 8, on: nil)
      enact(:sow) do
        refuse!("sow takes a number of seeds — sow 12, or sow 6, on: :desert") unless count.is_a?(Integer)
        refuse!("Seeds need light. First: let_there_be :light") unless world.lit?
        refuse!("Seeds need life itself. First: let_there_be :life") unless world.life?

        # on: speaks terrain, landform kind (:lake → :water), or a held
        # reference — `sow 10, on: field` seeds only that landform's tiles.
        field = case on
                when nil     then world.tiles
                when Feature then on.tiles
                else
                  terrain = Feature::REGISTRY[on]&.terrain || on # &. — nil-safe: unknown kinds fall through as-is
                  world.tiles.select { |t| t.terrain == terrain }
                end
        if field.empty?
          refuse!("No #{on.inspect} ground to sow. This world has: " \
                  "#{world.tiles.map(&:terrain).uniq.sort.map(&:inspect).join(', ')}")
        end

        sown = Hash.new(0) # Hash.new(default) — missing keys read 0, so `sown[kind] += 1` just works
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
        puts note
        world.plants.last(sown.values.sum)
      end
    end

    # Spawn a landform, animal, or plant. Returns the thing; hold it.
    # &brain reifies an attached block into a Proc we can pass along.
    def spawn(kind, at: nil, size: 2, name: nil, count: 1, length: nil, width: nil, &brain)
      enact(:spawn) do
        refuse!("🌑 The void swallows your creation. First: let_there_be :light") unless world.lit?

        if kind != :river && (!length.nil? || !width.nil?)
          refuse!("`length:` and `width:` shape rivers only. Try: spawn :river, length: world.width, width: 2")
        end

        if (klass = Feature::REGISTRY[kind]) # assign-and-test in one: truthy hash hit enters the branch
          shape = { world: world, at: at, size: size, name: name }
          shape[:length] = length unless length.nil?
          shape[:width] = width unless width.nil?
          klass.create(**shape) # ** double-splat: the hash spreads into keyword args
        elsif Animal::KINDS.key?(kind) || Plant::KINDS.key?(kind)
          breathe_creature(kind, at: at, count: count, brain: brain)
        else
          puts "You know no #{kind.inspect}."
          puts "Landforms: #{Feature::REGISTRY.keys.map(&:inspect).join(', ')}"
          puts "Creatures (after let_there_be :life): " \
               "#{(Animal::KINDS.keys + Plant::KINDS.keys).map(&:inspect).join(', ')}"
          refuse!(%(Or invent it: ordain #{kind.inspect}, emoji: "…", habitat: :land))
        end
      end
    end

    # The deliberate clock. Acts spend days on their own (TIME_COSTS);
    # `pass` is for when you want nothing but time itself to happen.
    def pass(days = 1)
      return frozen_lament if world.frozen?
      return puts("Time cannot pass in a world without light.") unless world.lit?
      return puts("Time flows forward only.") unless days.is_a?(Integer) && days >= 1

      world.advance!(days)
      puts world.render
      mentor_note(:pass)
      nil
    end

    # Two ways to aim. Coordinates smite a PLACE — splash damage, and it can
    # miss if the creature moved since you looked. A reference smites the
    # THING and never misses: IRB hands you live objects, so hold onto them.
    #   smite at: [5, 1]   ·   smite 5, 1          the tile
    #   smite wolf         ·   smite world.animals.select { … }
    def smite(*targets, at: nil)
      enact(:smite) do
        targets = targets.flatten
        if at.nil? && targets.size == 2 && targets.all?(Integer) # all?(pattern) tests with === — Class matches instances
          at = targets
          targets = []
        end
        if at.nil? && targets.empty?
          refuse!("Aim first: smite at: [3, 4] · smite 5, 1 · smite wolf · smite herd")
        end

        epitaphs = []
        if at
          tile = world.at(*at)
          refuse!("Your wrath sails off the edge of the world.") unless tile
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
        puts epitaphs.join("\n") unless epitaphs.empty?
        at ? world.at(*at) : nil
      end
    end

    # Silence the mentor's signature hints, or summon them back.
    def hush!
      Godhood.mentor = false
      puts "🤫 The mentor falls silent. (`mentor!` summons it back.)"
      nil
    end

    def mentor!
      Godhood.mentor = true
      puts "✍️  The mentor returns."
      nil
    end

    # The art-supply cabinet, at the prompt. Observing is free.
    #   palette              every drawer, as swatches
    #   palette :creatures   one drawer
    #   palette :wolf        one emoji, returned — feed it straight to ordain:
    #                        ordain :wolf, emoji: palette(:wolf), habitat: :land
    def palette(name = nil)
      return Palette.swatch if name.nil?
      return Palette.swatch(name) if Palette::GROUPS.key?(name)

      Palette[name]
    end

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
      enact(:winter!) do
        refuse!("Winter needs a world beneath it. First: let_there_be :light") unless world.lit?
        refuse!("Winter already holds the world.") if world.winter?

        world.winter!
        puts "❄️ Winter takes the world. Water ices, fires fail, and snow holds."
        nil
      end
    end

    def spring!
      enact(:spring!) do
        refuse!("There is no winter to thaw.") unless world.winter?

        world.spring!
        puts "🌱 Spring answers. The waters claimed by winter run again."
        nil
      end
    end

    # The narrative doorway to Ruby's actual freeze semantics. World#freeze
    # adds Terra's ending and calls `super`, which reaches Object#freeze.
    def great_freeze!
      return frozen_lament if world.frozen?

      world.freeze
      puts world.render
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
      puts world.render
    end

    # A ready-made world: light, land, life — then it's yours to edit.
    # Everything here goes through the same paths your own commands use.
    def eden!(width: World::DEFAULT_WIDTH, height: World::DEFAULT_HEIGHT)
      birth!(width: width, height: height)
      world.illuminate!
      world.bestow_life!

      scale = (world.width * world.height) / 108.0 # relative to the 12×9 default
      n = ->(base) { [(base * scale).round, 1].max } # a lambda held in a local; called below as n.(2)

      n.(2).times { Feature::REGISTRY[:lake].create(world: world, size: 2) } # n.(2) is sugar for n.call(2)
      n.(1).times { Feature::REGISTRY[:mountain].create(world: world, size: 3) }
      n.(1).times { Feature::REGISTRY[:forest].create(world: world, size: 2) }
      n.(1).times { Feature::REGISTRY[:desert].create(world: world, size: 2) }

      { rabbit: 3, tortoise: 1, fish: 2, hawk: 1, fern: 4, flower: 3, lily: 2 }
        .each { |kind, base| world.breathe(kind, count: n.(base)) }

      puts(world.render)
      puts(Lore::EDEN)
      nil
    end

    # Remove things you've made — by reference (precise), by kind (:lake),
    # or by name ("Mirkwood"). Kind and name only act when exactly one thing
    # matches; ambiguity lists the candidates instead of guessing.
    # Unmade land reverts to plains — water lives only where lakes do.
    def unmake(*things)
      enact(:unmake) do
        targets = things.flatten
        if targets.empty?
          refuse!(%(Point at a thing: unmake :lake · unmake "Mirkwood" · unmake world.animals.first))
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
        puts (epitaphs + notes).join("\n") if epitaphs.any? || notes.any?
        refuse! if epitaphs.empty? # nothing was unmade — no day is owed

        world.record!("🕳️ #{epitaphs.join(' · ')}")
        nil
      end
    end

    # Invent a species: an animal (habitat: + speed:) or a plant (grows_on:
    # + spread:/spread_limit:/lifespan:). Just data in an open hash — no new
    # classes needed.
    def ordain(kind, emoji: nil, habitat: nil, speed: 1, grows_on: nil, spread: 0.15,
               spread_limit: Plant::DEFAULT_SPREAD_LIMIT, lifespan: 10)
      enact(:ordain) do
        unless kind.is_a?(Symbol) && emoji
          puts %(Name and mark it: ordain :wolf, emoji: "🐺", habitat: :land, speed: 3)
          refuse!(%(Plants take root:  ordain :cactus, emoji: "🌵", grows_on: [:desert], spread_limit: 2, lifespan: 40))
        end

        known = Animal::KINDS.key?(kind) || Plant::KINDS.key?(kind)
        if habitat
          unless Animal::PASSABLE.key?(habitat)
            refuse!("Habitat must be one of: #{Animal::PASSABLE.keys.map(&:inspect).join(', ')}")
          end
          Animal.ordain(kind, emoji: emoji, habitat: habitat, speed: speed)
          puts "#{emoji} #{known ? 'You reshape' : 'Into the book of species goes'} the #{kind} — #{habitat}, speed #{speed}."
        elsif grows_on
          Plant.ordain(kind, emoji: emoji, grows_on: grows_on, spread: spread,
                      spread_limit: spread_limit, lifespan: lifespan)
          puts "#{emoji} #{known ? 'You reshape' : 'Into the book of species goes'} the #{kind} — roots in #{Array(grows_on).join('/')}, each seed may spread #{spread_limit} cells."
        else
          refuse!("Give it a nature: habitat: :land/:water/:air (animal) or grows_on: [:plains] (plant).")
        end
        puts "   spawn #{kind.inspect} awaits. (Session-only — edit lib/terra/animal.rb or plant.rb to make it eternal.)"
        world.record!("📖 #{emoji} The #{kind} is ordained into the book of species")
        nil
      end
    end

    def powers
      puts Lore::GENESIS_SHEET
      status = world.life? ? "🔓" : "🔒 sleeping — wake it: let_there_be :life"
      puts format(Lore::LIFE_SHEET, status: status) # format fills the %{status} hole
      nil
    end

    private

    # The one gate every act passes through. A frozen world refuses
    # everything; a refuse! anywhere in the body aborts without charging;
    # success spends the act's TIME_COSTS days, then shows the world.
    #
    # catch/throw is Ruby's non-exception early exit: the throw inside
    # refuse! unwinds straight to this catch even when it happens several
    # method calls deep (see breathe_creature). Kotlin's labeled
    # returns can't cross method boundaries like that; exceptions could,
    # but a refusal isn't exceptional — it's a normal answer.
    def enact(power)
      return frozen_lament if world.frozen?

      result = catch(:refused) do
        value = yield
        # Time is the price of action. The void has no days to spend yet,
        # so pre-light acts (an early `ordain`) are free.
        world.advance!(TIME_COSTS.fetch(power), quiet: true) if world.lit?
        puts world.render
        mentor_note(power)
        value
      end
      result.equal?(REFUSED) ? nil : result
    end

    # One line of live signature + one example. `method(power).parameters`
    # is Ruby introspection: it returns [[:req, :kind], [:key, :at], …] —
    # the REAL parameter list of the method, so this line can never drift
    # out of date. (Kotlin needs kotlin-reflect for the same trick.)
    # Only the names survive to runtime; defaults are compiled into the
    # method body, hence the "= …" placeholder.
    def mentor_note(power)
      return unless Godhood.mentor?

      sig = method(power).parameters.map do |kind, name|
        case kind
        when :req     then name.to_s
        when :opt     then "#{name} = …"
        when :rest    then "*#{name}"
        when :key     then "#{name}:"
        when :keyrest then "**#{name}"
        when :block   then "&#{name}"
        end
      end.join(", ")
      puts "✍️  #{power}#{sig.empty? ? '' : " #{sig}"}"
      # sample(random:) draws from OUR private RNG, not the global one the
      # simulation shares — otherwise every hint would nudge where the next
      # rabbit wanders (and break any srand-seeded test).
      example = Lore::EXAMPLES[power]&.sample(random: MENTOR_RNG)
      puts "   ↳ try: #{example}" if example
    end

    # Abort the current act: say why (if there's anything to say), charge
    # nothing. Only meaningful inside an enact block.
    def refuse!(message = nil)
      puts message if message
      throw :refused, REFUSED
    end

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

      unless world.lit?
        return ["🌑 The void. Nothing exists yet.", "   → let_there_be :light   (or eden! to skip ahead)"]
      end

      lines = ["☀️  Day #{world.day} — #{world.features.size} landforms, " \
               "#{world.animals.count} animals, #{world.plants.count} plants."]
      lines << "   → spawn :lake / :mountain / :forest — shape the land" if world.features.empty?
      lines << "   → let_there_be :life — the world is ready to breathe" unless world.life?
      lines << "   → spawn :rabbit, count: 3 — life is unlocked but nothing lives" if world.life? && world.beings.empty?
      lines << "   → pass 7 — let the days deepen what you've made" if world.beings.any? && world.day < 7
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

    def breathe_creature(kind, at:, count:, brain:)
      refuse!("The #{kind} is inert clay. Life itself is missing: let_there_be :life") unless world.life?
      if brain && Plant::KINDS.key?(kind)
        puts "🌱 Plants have no will of their own — your block drifts away on the wind."
        brain = nil
      end

      born = world.breathe(kind, at: at, count: count, brain: brain)
      refuse!("No hospitable ground for #{kind.inspect} anywhere in this world.") if born.empty?

      born.one? ? born.first : born
    end

    def frozen_lament = puts(Lore::FROZEN_LAMENT)
  end
end
