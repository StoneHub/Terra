# frozen_string_literal: true

module Terra
  # The written word of the game — prose lives here, logic stays in Godhood.
  # Heredoc constants need an explicit .freeze (the magic comment above skips
  # heredocs); text with runtime holes uses %{name} + format at the call site.
  module Lore
    # THE MENTOR — after every successful act, one line of full signature
    # (read live off the method itself, see mentor_note) and one example
    # worth stealing. These are the examples; the signatures are never
    # written down anywhere — introspection keeps them honest.
    EXAMPLES = {
      let_there_be: ["let_there_be :life", "let_there_be :rain", "let_there_be :storm"],
      spawn: ['spawn :lake, at: [4, 3], size: 3, name: "Mirrormere"',
              "spawn :river, at: [0, 4], length: world.width, width: 2",
              "spawn :rabbit, count: 5",
              "spawn(:rabbit, count: 3) { |r| r.hop_toward :water }",
              'spawn :mountain, size: 4, name: "The Old Tooth"'],
      sow: ["sow 12", "sow 6, on: :desert", "sow 10, on: :water"],
      smite: ["smite at: [3, 4]", "smite 5, 1",
              "smite world.animals.max_by(&:age)", "smite :wolf"],
      unmake: ["unmake :forest", 'unmake "Mirkwood"', "unmake world.features.last"],
      ordain: ["ordain :wolf, emoji: palette(:wolf), habitat: :land, speed: 3",
               'ordain :cactus, emoji: "🌵", grows_on: [:desert], spread: 0.05, spread_limit: 2, lifespan: 40'],
      terraform: ["terraform :meadow", "terraform :desert"],
      pass: ["pass 7", "pass 30"],
    }.freeze

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
      { title: "The Prairie World", lore: "A living meadow from nothing, in seven lines.",
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
                'spawn :meadow, size: 2   # an island',
                'spawn :meadow, size: 2   # another',
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
          landforms: :lake :river :mountain :forest :desert :meadow (🌾 = green grass)
          spawn :rabbit, count: 5              creatures need `let_there_be :life`
          spawn(:rabbit) { |r| r.wander }      a block becomes its brain (parens!)
        terraform :meadow — repaint every barren 🟫 tile at once (:desert, :water, …)
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
        pass — the deliberate clock. Acts already spend days on their own
        (spawn 1 · sow 1 · smite 1 · terraform 3 · winter!/spring! 2);
        pass is for when you want nothing but time itself to happen.
          pass          one day       pass 7        a week
          world.day     the calendar  chronicle     what happened
        Only pass lets the sky drift — your own acts hold it steady.
      TXT
      sow: <<~TXT,
        sow — scatter seeds; the terrain decides what grows.
          sow 12                     🌿🌼 meadow · 🍄 forest · 🌵 desert · 🪷 water
          sow 6, on: :desert        only the desert
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
          ordain :cactus, emoji: "🌵", grows_on: [:desert], spread: 0.05, spread_limit: 2, lifespan: 40
        Out of emoji ideas? `palette` is the cabinet: palette :creatures,
        then ordain :bear, emoji: palette(:bear), habitat: :land
      TXT
      palette: <<~TXT,
        palette — hardcoded emoji, grouped in drawers. Observing is free.
          palette                   the whole cabinet    palette :structures   one drawer
          palette :wolf             one emoji, returned  Terra::Palette.lookup("dot")  search
        drawers: :tiles :dots :gems :creatures :plants :structures :sky :marks
        The nine colored squares/circles are ALL Unicode has — emoji color is
        baked into the font, so there's no custom-hex tile and never will be.
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
      winter: <<~TXT,
        winter — reversible world climate, ordinary mutable game state.
          winter!      water ices, fire dies, snow holds, fish wait
          spring!      only water frozen by that winter thaws again
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

    # Shown when any power is used after the Great Freeze.
    FROZEN_LAMENT = <<~MSG.freeze
      🥶 The Great Freeze has ended this world. Nothing answers you.
      World#freeze called `super`, reaching Ruby's Object#freeze: permanent,
      shallow immutability. There is no unfreeze; there never has been.
      Speak `big_bang!` to abandon this universe and begin again.
    MSG

    # Shown when let_there_be :life wakes the world.
    LIFE = <<~MSG.freeze
      🌱 And the world drew breath. New forms answer your call:
        spawn :rabbit, count: 3    🐇 land, fast      spawn :fern     🌿 spreads on land
        spawn :tortoise            🐢 land, slow      spawn :flower   🌼 blooms on plains
        spawn :fish                🐟 water-locked    spawn :lily     🪷 floats on water
        spawn :hawk                🦅 goes anywhere

      ⏳ Every act spends its days as you work; `pass 7` spends a week
         on purpose. (`powers` for the details.)
    MSG

    # Shown after eden! hands over a ready-made world.
    EDEN = <<~MSG.freeze
      🌏 A world, ready-made — and yours to edit. `unmake` what displeases you;
         `pass 7` to see it live. (`powers` for everything else.)
    MSG

    # Map headers (Cartographer). The lit-day header stays in code — it's
    # all holes, no prose.
    GREAT_FREEZE_HEADER = "🥶 The Great Freeze — no usable energy remains. Only a new `big_bang!` can follow."
    VOID_HEADER = "🌑 The Void — darkness upon the face of the deep"

    # The powers sheet, in two halves. Godhood#powers prints GENESIS_SHEET,
    # computes the life-lock status, then fills the second half's hole:
    #   puts format(Lore::LIFE_SHEET, status: status)
    GENESIS_SHEET = <<~MSG.freeze
      ━━━ THE LAWS OF TERRA ━━━
      ⚡ The echo is the UI — every value draws itself. `world` IS the map.
      ⏳ Acting spends time — every successful power costs days (most 1,
         terraform 3, the seasons 2). A refused act costs nothing.
         `pass` spends days deliberately; observing is always free.
      🥶 `great_freeze!` calls Ruby's real Object#freeze through `super`. No undo.

      ━━━ LEVEL 1: GENESIS ━━━
      let_there_be :light                              begin creation
      winter! / spring!                                reversible world climate
      spawn :lake, at: [4, 3], size: 2, name: "…"      also :mountain :forest :desert
      spawn :river, at: [0, 4], length: 12, width: 2   🌊 connected water across the map
      spawn :meadow                                    🌾 green grass on demand
      terraform :meadow                                repaint ALL barren 🟫 — any terrain
      smite at: [x, y] / smite 5, 1                    🔥 the place — starts a small fire
      smite wolf / smite herd                          🔥 the thing — never misses
      unmake :lake / unmake "Mirkwood"                 by kind or name (one match only)
      unmake world.features.last                       by reference — always precise
      big_bang! width: 20, height: 12                  begin again — bigger, if you ask
      great_freeze!                                    heat death — this World ends forever
      eden! width: 16, height: 10                      a ready-made world, yours to edit
      world               the map                      world.at(x, y)   one tile
      world.features      everything you have made     world.history    every recorded act
      chronicle / chronicle!                           the story so far / written as HTML
      palette / palette :creatures                     the emoji cabinet, for building new things
      hush! / mentor!                                  silence / restore the ✍️ signature hints
      inspire / inspire :all                           a worked example when you're stuck
      guide / guide :smite                             where you stand + chapters of help
      companion                                        open the illustrated HTML manual

      Every spawn RETURNS the thing — hold it and poke it:
        lake = spawn :lake        lake.name = "Mirrormere"
        mountain.erupt!  forest.grow!  lake.iced_over?
    MSG

    LIFE_SHEET = <<~MSG.freeze
      ━━━ LEVEL 2: LIFE %{status} ━━━
      let_there_be :life          wake the world; everything below needs it
      spawn :rabbit, count: 5     🐇 land, speed 2     spawn :fern     🌿 finite colony
      spawn :tortoise             🐢 land, speed 1     spawn :flower   🌼 plains, blooms
      spawn :fish                 🐟 water only        spawn :lily     🪷 water
      spawn :hawk                 🦅 flies anywhere    spawn :cactus   🌵 :mushroom 🍄 too
      sow 12 / sow 6, on: :desert scatter seeds; each grows what its terrain allows
                                  (🌿🌼 meadow · 🍄 forest · 🌵 desert · 🪷 water)
      pass / pass 7               spend extra days — animals roam, plants live & die
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
        ordain :bramble, emoji: "🌾", grows_on: [:desert], spread: 0.05, spread_limit: 3, lifespan: 40

      🔒 Level 3: Providence — Enumerable as divine power
    MSG
  end
end
