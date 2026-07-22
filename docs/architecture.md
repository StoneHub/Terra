# The Shape of Terra

Every box is a real file in `lib/terra/`. Solid arrows are inheritance; diamonds
are ownership; dashed lines are "talks to." Kept current by hand — when a class
appears, dies, or changes owner, this map changes in the same PR.

```mermaid
%%{init: {'theme':'neutral'}}%%
classDiagram
  direction TB

  class Godhood["Godhood (module)"] {
    TIME_COSTS
    enact(power) / refuse!
    spawn · sow · smite · unmake
    let_there_be · terraform · ordain
    winter! · spring! · pass · great_freeze!
    guide · powers · inspire · palette
  }
  class Lore["Lore (module · pure data)"] {
    GRIMOIRE · GUIDEBOOK · EXAMPLES
    sheets & messages
  }
  class Palette["Palette (module · Enumerable)"] {
    TILES · CREATURES · MARKS …
    each → 50 free methods
  }
  class SpeciesLookup["SpeciesLookup (module)"] {
    method_missing → world.rabbits
  }

  class World {
    day · sky · season
    advance!(days, quiet)
    breathe · lightning! · ignite!
    freeze → super
  }
  class Cartographer { render }
  class Chronicle { write → HTML }
  class Tile { terrain · feature · emoji }

  class Weather {
    kind · emoji
    daily_event(world)
    stills_plants? · growth_bonus
  }
  class Season {
    lock_sky? · hold_weather?
    winter? · end!
  }
  class Winter { claimed tiles (memory) }

  class Feature {
    REGISTRY · manifest_as
    create · tiles · title
  }
  class Being { tick · pos · dead? · emoji }

  Weather <|-- Clear
  Weather <|-- Rain
  Weather <|-- Snow
  Weather <|-- Storm
  Season <|-- Winter

  Feature <|-- Lake
  Lake <|-- River
  Feature <|-- Mountain
  Feature <|-- Forest
  Feature <|-- Desert
  Feature <|-- Meadow

  Being <|-- Animal
  Being <|-- Plant
  Being <|-- Remains

  World *-- Tile : grid of
  World o-- Feature : features
  World o-- Being : beings
  World --> Weather : sky
  World --> Season : season
  SpeciesLookup ..> World : include
  Feature --> Tile : claims

  Godhood ..> World : commands + charges time
  Godhood ..> Lore : reads
  Godhood ..> Palette : reads
  Cartographer ..> World : renders
  Chronicle ..> World : exports history
```

## Where the "interfaces" are

Ruby has no `interface` keyword; three mechanisms play that role here.

1. **Duck type — `Being`.** Anything in `world.beings` must answer `tick`,
   `dead?`, `pos`, `emoji`, `kind`. Nothing declares the contract; the daily
   loop calls it and the test suite enforces it. `Remains` qualifies by quacking.
2. **Base class with calm defaults — `Weather`, `Season`.** The base states the
   whole surface; kinds override only their difference. `advance!` calls
   `daily_event` blind — method lookup is the `if` statement. Closest analog to
   a Kotlin interface with default methods.
3. **Module as role — `Enumerable`, `SpeciesLookup`.** The inverted contract:
   implement one hook (`each`) and receive ~50 methods. `Palette` earns
   `count`/`group_by`/`select` that way.

## Reading the arrows

| Arrow | Meaning |
|---|---|
| `A <\|-- B` | B inherits from A (`class B < A`) |
| `A *-- B` | composition — A builds and owns B for life (World's tile grid) |
| `A o-- B` | aggregation — A holds a changing collection of B (features, beings) |
| `A --> B` | A holds one B and swaps it (the sky, the season — the State pattern) |
| `A ..> B` | A talks to B without owning it (Godhood commands; Cartographer reads) |
