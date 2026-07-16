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

    def let_there_be(what)
      return frozen_lament if world.frozen?

      case what
      when :light
        world.illuminate!
        puts "And there was light. 🌅"
        world.behold!
      when :life
        summon_life
      else
        puts "The void does not understand #{what.inspect}. Perhaps :light? Or, later, :life?"
        nil
      end
    end

    # Keyword args with defaults — Ruby's version of Kotlin named/default
    # params. The &brain slurps an attached block into a Proc; note that a
    # brace block needs parens — spawn(:rabbit) { |r| ... } — while do…end
    # works without them. NB: this shadows Kernel#spawn (process launching)
    # at the prompt, which is exactly what we want.
    def spawn(kind, at: nil, size: 2, name: nil, count: 1, &brain)
      return frozen_lament if world.frozen?

      unless world.lit?
        puts "🌑 The void swallows your creation. First: let_there_be :light"
        return
      end

      if (klass = Feature::REGISTRY[kind])
        feature = klass.create(world: world, at: at, size: size, name: name)
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

      world.behold!
      puts epitaphs.join("\n") unless epitaphs.empty?
      at ? world.at(*at) : nil
    end

    def behold = world

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
      world.behold! if epitaphs.any?
      puts (epitaphs + notes).join("\n") if epitaphs.any? || notes.any?
      nil
    end

    # Invent a species: an animal (habitat: + speed:) or a plant (grows_on:
    # + spread:/lifespan:). Just data in an open hash — no new classes needed.
    def ordain(kind, emoji: nil, habitat: nil, speed: 1, grows_on: nil, spread: 0.15, lifespan: 10)
      return frozen_lament if world.frozen?
      unless kind.is_a?(Symbol) && emoji
        puts %(Name and mark it: ordain :wolf, emoji: "🐺", habitat: :land, speed: 3)
        puts %(Plants take root:  ordain :cactus, emoji: "🌵", grows_on: [:sand], lifespan: 40)
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
        Plant.ordain(kind, emoji: emoji, grows_on: grows_on, spread: spread, lifespan: lifespan)
        puts "#{emoji} #{known ? 'You reshape' : 'Into the book of species goes'} the #{kind} — roots in #{Array(grows_on).join('/')}."
      else
        return puts("Give it a nature: habitat: :land/:water/:air (animal) or grows_on: [:plains] (plant).")
      end
      puts "   spawn #{kind.inspect} awaits. (Session-only — edit lib/terra/animal.rb or plant.rb to make it eternal.)"
      nil
    end

    def powers
      puts <<~SHEET
        ━━━ THE LAWS OF TERRA ━━━
        ⚡ The echo is the UI — every value draws itself. `world` IS the map.
        ⏳ Time passes only when you `pass`. Between commands, a photograph.
        🧊 `freeze` is forever — Object#freeze has no undo. big_bang! is the only mercy.

        ━━━ LEVEL 1: GENESIS ━━━
        let_there_be :light                              begin creation
        spawn :lake, at: [4, 3], size: 2, name: "…"      also :mountain :forest :desert
        smite at: [x, y] / smite 5, 1                    🔥 the place — splash damage
        smite wolf / smite herd                          🔥 the thing — never misses
        unmake :lake / unmake "Mirkwood"                 by kind or name (one match only)
        unmake world.features.last                       by reference — always precise
        big_bang! width: 20, height: 12                  begin again — bigger, if you ask
        eden! width: 16, height: 10                      a ready-made world, yours to edit
        world / behold      the map                      world.at(x, y)   one tile
        world.features      everything you have made

        Every spawn RETURNS the thing — hold it and poke it:
          lake = spawn :lake        lake.name = "Mirrormere"
          lake.freeze!  lake.thaw!  mountain.erupt!  forest.grow!
      SHEET

      if world.life?
        puts <<~SHEET
          ━━━ LEVEL 2: LIFE 🔓 ━━━
          spawn :rabbit, count: 5     🐇 land, speed 2     spawn :fern     🌿 land, spreads
          spawn :tortoise             🐢 land, speed 1     spawn :flower   🌼 plains, blooms
          spawn :fish                 🐟 water only        spawn :lily     🪷 water
          spawn :hawk                 🦅 flies anywhere
          pass / pass 7               let days happen — animals roam, plants live & die
          world.animals / world.plants                 everything alive, as arrays
          world.rabbits / world.lilies / world.wolves  the plural of any species works

          Divine brains — a block replaces instinct, runs once per day:
            spawn(:rabbit) { |r| r.hop_toward :water }
            verbs: r.wander · r.hop_toward(:forest) · r.hop_toward([x, y]) · r.stay

          Invent species — new entries in an open registry:
            ordain :wolf, emoji: "🐺", habitat: :land, speed: 3
            ordain :cactus, emoji: "🌵", grows_on: [:sand], spread: 0.05, lifespan: 40

          🔒 Level 3: Providence — Enumerable as divine power
        SHEET
      else
        puts "🔒 Level 2 sleeps. Wake it:  let_there_be :life"
      end
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

    def strike_tile(tile)
      tile.scorch!
      victims = world.beings.select { |b| b.x == tile.x && b.y == tile.y }
      victims.each(&:die!)
      world.beings.reject!(&:dead?)
      victims.map { |v| "#{v.emoji} The smite claims the #{v.kind}." }
    end

    def birth!(width:, height:)
      w = width.clamp(4, 40)
      h = height.clamp(4, 30)
      puts "(The fabric of space stretches only so far: #{w}×#{h}.)" if [w, h] != [width, height]
      Godhood.world = World.new(width: w, height: h)
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

    # Shown when any power is used on a world someone called `freeze` on.
    def frozen_lament
      puts <<~MSG
        🧊 The world is frozen in time. Nothing answers you.
        That was Ruby's own Object#freeze — it makes an object permanently
        immutable. There is no unfreeze; there never has been.
        Speak `big_bang!` to abandon this universe and begin again.
      MSG
    end
  end
end
