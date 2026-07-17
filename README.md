# Terra 🌍

A god game played entirely from IRB. The prompt is the controller; the map is
whatever your expressions return.

## Mac setup

Terra supports current macOS on both Apple Silicon and Intel. It needs Ruby
3.1 or newer and pins the known-good Ruby 3.4.10 for repeatable setup. Apple's
`/usr/bin/ruby` is 2.6 and is too old.

On a fresh Mac, install [Homebrew](https://brew.sh/) if needed, then:

```sh
brew install mise
bin/setup
```

`bin/setup` installs Terra's isolated Ruby, installs its gems, and runs the
test suite. It does not replace the Mac's system Ruby. If you already manage a
modern Ruby with rbenv, asdf, or Homebrew and do not have mise installed,
`bin/setup` will use that Ruby instead.

## Play

```sh
bin/terra          # terminal; selects the pinned Ruby automatically when mise is installed
ruby bin/play.rb   # same game as a plain Ruby script — use this for RubyMine's play button
```

Then, as is tradition:

```ruby
eden!                                      # or skip straight to a pre-filled world…
let_there_be :light                        # …or build one yourself, from the dark
spawn :lake, at: [3, 4], size: 2
mtn = spawn :mountain, name: "The Old Tooth", size: 3
mtn.erupt!
let_there_be :life
spawn :rabbit, count: 3
spawn :fern
pass 7                                     # time moves only when you say so
spawn(:rabbit) { |r| r.hop_toward :water } # a block replaces its instinct
ordain :wolf, emoji: "🐺", habitat: :land, speed: 3   # invent a species
unmake lake                                # remove things; land reverts to plains
big_bang! width: 20, height: 12            # a bigger canvas (worlds are born with their size)
powers                                     # cheat sheet + the Laws of Terra
```

## The Laws of Terra

1. **The echo is the UI** — IRB prints every return value; `World#inspect` returns the map.
2. **Time passes only when you `pass`** — no engine loop; the world ticks on command, roguelike-style.
3. **`freeze` is forever** — `world.freeze` is Ruby's real `Object#freeze`. The map ices over permanently; `big_bang!` (a fresh `World`) is the only way out.

## Why this teaches Ruby

| You do | You learn |
|---|---|
| `spawn :lake, at: [3,4]` | symbols, keyword args, defaults |
| `lake.name = "Mirrormere"` | `attr_accessor`, objects are always live |
| `lake.freeze!`, `world.lit?` | `!`/`?` naming conventions |
| `world.at(3, 4)` at the prompt | `inspect` is IRB's UI — every echo is a render |
| `world.features` | arrays of real objects, no DTOs anywhere |
| reading `feature.rb` | class macros (`manifest_as`), the Rails `has_many` pattern |
| `spawn(:rabbit) { \|r\| r.hop_toward :water }` | blocks as behavior; why brace blocks need parens here |
| `world.animals.map(&:age)` | Enumerable over live objects (Level 3 preview) |
| `world.freeze` | `Object#freeze` — real, shallow, and irreversible |

## Layout

```
bin/setup              one-time Ruby/gem setup + test gate for macOS
bin/terra              launcher (selects the project Ruby, then starts IRB)
lib/terra.rb           engine entry + Terra.genesis
lib/terra/world.rb     the grid; render/illuminate!/tiles_near
lib/terra/tile.rb      one square: terrain symbol + owning feature
lib/terra/feature.rb   Lake/Mountain/Forest/Desert + manifest_as registry
lib/terra/being.rb     base class for living things (tick/age/die!)
lib/terra/animal.rb    🐇🐢🐟🦅 habitats, speed, wander/hop_toward, divine brains
lib/terra/plant.rb     🌿🌼🪷 spread, lifespan, quiet deaths
lib/terra/godhood.rb   the top-level god commands (extended onto main)
lib/terra/cartographer.rb    all presentation — World#render delegates here
lib/terra/species_lookup.rb  world.rabbits/world.lakes — a method_missing mixin (Rails-concern style)
lib/terra/chronicle.rb + chronicle.html.erb   world history → standalone HTML (stdlib ERB)
test/                  minitest suite — run with `bundle exec rake` from Terra/
```

Every act is recorded: `chronicle` prints the story so far, `chronicle!` renders
it to `terra-chronicle.html` with a map snapshot per act. `world.history` is the
raw array, queryable like everything else.

## Roadmap

- **Level 1 — Genesis** ✅: terrain, attributes, smiting
- **Level 2 — Life** ✅ (you are here): `let_there_be :life`, tick-based time via `pass`, creatures with block-defined brains, terrain-aware `sow`, weather (☀️🌧️❄️⛈️ — the map header is the forecast)
- **Level 3 — Providence**: Enumerable queries as divine power (`world.animals.select(&:hungry)...`)
- **Level 4 — Godhood**: reopen classes mid-game; rabbits learn to fly
