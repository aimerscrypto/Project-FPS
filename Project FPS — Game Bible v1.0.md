# Project FPS — Game Bible v1.0

**Working title:** Project FPS  
**Genre:** Fast-paced stylized first-person arena shooter  
**Platforms:** Web + Windows  
**Engine:** Godot 4.7  
**3D Pipeline:** Blender + Blender MCP  
**Development:** Antigravity + Gemini 3.7 Flash  
**Initial Match Size:** 8 players  
**Primary Game Mode:** Free For All  
**Art Direction:** Stylized Competitive Low-Poly

---

# 1. Vision

Project FPS is a fast, colorful, skill-focused first-person shooter built around satisfying movement, responsive gunplay, readable low-poly visuals, and short replayable matches.

The game should capture the **speed and simplicity** associated with browser FPS games such as Krunker and Deadshot.io and the **colorful, clean, low-poly readability** associated with Venge.io, while developing a completely original visual identity, maps, characters, weapons, UI, effects, and gameplay systems.

The intended feeling is:

> **Cool, energetic, colorful, competitive, and slightly playful — never childish.**

The player should understand the game almost immediately:

**Spawn → move → find enemy → shoot → kill → die → respawn → fight again.**

The game should be easy to learn but provide room for mastery through aim, movement, positioning, weapon choice, and map knowledge.

---

# 2. Design Pillars

## Pillar 1 — Movement feels great

Movement is not merely transportation between fights. It is part of the skill ceiling.

The player should enjoy simply running around the map.

Movement must feel:

- fast
- responsive
- predictable
- controllable
- rewarding to master

## Pillar 2 — Guns feel powerful

Every shot should communicate clearly.

Gunplay should combine:

- recoil
- muzzle flash
- sound
- hit effects
- hit markers
- camera feedback
- weapon animation
- impact feedback

A simple weapon model should still feel satisfying to fire.

## Pillar 3 — Readability beats realism

Players must quickly understand:

- where enemies are
- where they can move
- where cover is
- what weapon they are holding
- what happened after a shot

Realism is never allowed to damage readability.

## Pillar 4 — Simple geometry, strong art direction

Low-poly does not mean low quality.

We want:

**simple geometry + strong silhouettes + excellent colors + controlled materials + good lighting + polished VFX**

## Pillar 5 — Fast repetition

The game should minimize downtime.

Death should not feel like waiting.

Respawn should get the player back into action quickly.

---

# 3. Target Experience

The first impression should be:

> "This looks cool."

The first minute should be:

> "This is easy to understand."

The first match should be:

> "Movement feels really good."

After several matches:

> "I want to get better at this."

That is the experience we are building toward.

---

# 4. Platform Strategy

## Web

Browser play is a core target.

Therefore the game must be conscious of:

- draw calls
- polygon count
- texture memory
- shader complexity
- dynamic lighting
- particle counts
- loading times
- network bandwidth

## Windows

Windows can eventually receive:

- higher rendering settings
- larger texture budgets
- optional visual enhancements
- higher-quality effects

However, the underlying game architecture must remain compatible with the browser target.

---

# 5. Initial Game Mode

## Free For All

Initial target:

**8 players**

Every player competes against every other player.

Initial scoring model:

- elimination gives points
- death causes respawn
- highest score wins
- optional score limit
- optional match timer

The exact numbers will be tuned during playtesting.

Target match duration:

**Approximately 5–8 minutes.**

---

# 6. Core Gameplay Loop

```text
Spawn
  ↓
Move
  ↓
Search for enemy
  ↓
Engage
  ↓
Shoot
  ↓
Kill
  ↓
Earn score
  ↓
Continue fighting
  ↓
Die
  ↓
Respawn
  ↓
Repeat
```

This loop should remain fast.

There should be minimal menu friction and minimal downtime between fights.

---

# 7. Player Movement

Initial movement system:

- WASD movement
- mouse look
- sprint
- jump
- air control
- crouch
- slide
- fast acceleration
- fast deceleration
- weapon switching

The exact numerical values will be tuned in a graybox arena.

## Movement philosophy

The game should feel closer to an arcade shooter than a military simulator.

The player should not feel heavy.

The player should have enough air control for skilled movement without making basic movement uncontrollable.

## Future movement experiments

Possible future additions:

- bunny hopping
- wall jumping
- advanced slide mechanics
- movement boosts
- jump pads

These are explicitly **future experiments**, not initial requirements.

---

# 8. Combat

The player uses traditional firearms.

Initial combat should support:

- hip fire
- aiming
- firing
- reload
- weapon switching
- damage
- headshots
- hit detection
- death

The initial version should prioritize reliable and responsive combat over complexity.

---

# 9. Initial Weapon Roster

## 9.1 Assault Rifle

Purpose:

**General-purpose weapon**

Characteristics:

- medium damage
- medium fire rate
- controllable recoil
- medium range
- reliable in most situations

It should be the easiest weapon for new players to understand.

## 9.2 SMG

Purpose:

**Close-range aggressive weapon**

Characteristics:

- high fire rate
- lower damage per shot
- strong mobility
- short effective range
- larger magazine

## 9.3 Shotgun

Purpose:

**Close-range burst damage**

Characteristics:

- very high close-range damage
- slow fire rate
- limited effective range
- powerful sound and visual feedback

## 9.4 Sniper Rifle

Purpose:

**Precision weapon**

Characteristics:

- high damage
- slow fire rate
- long range
- high skill requirement
- strong reward for accurate shots

## 9.5 Pistol

Purpose:

**Secondary weapon**

Characteristics:

- fast swap
- reliable backup
- moderate damage
- useful when the primary weapon needs reloading

---

# 10. Weapon Architecture

Weapons must be data-driven.

The weapon system should not require manually rewriting weapon logic for every gun.

Conceptual weapon properties:

```text
damage
fire_rate
magazine_size
reserve_ammo
reload_time
spread
recoil
range
headshot_multiplier
movement_penalty
fire_mode
projectile_or_hitscan
```

A new weapon should primarily require:

1. a weapon data resource
2. a weapon model
3. animations
4. sounds
5. VFX

The core firing system should remain reusable.

---

# 11. Character Direction

The initial game uses:

**one universal player body**

Gameplay differences are not tied to character identity.

Later customization should use:

**skins / outfits / cosmetic variations**

rather than completely different gameplay characters.

## Character silhouette

Characters should be:

- stylized
- readable from a distance
- slightly chunky
- cleanly proportioned
- visually recognizable
- animation-friendly

Do not use realistic facial detail in the initial art style.

---

# 12. Art Direction

## Style Name

**Stylized Competitive Low-Poly**

## Overall tone

- cool
- energetic
- colorful
- modern
- slightly playful
- competitive
- not childish
- not photorealistic

## Core visual principle

> **Venge-like readability, but original identity.**

We may learn from the visual principles of Venge.io, but we will not copy its:

- characters
- weapons
- maps
- logos
- UI
- exact materials
- exact color schemes
- distinctive assets

---

# 13. Geometry Rules

Models should use:

- low to medium polygon density
- strong silhouettes
- large readable forms
- clean topology
- controlled bevels
- intentional exaggeration

Avoid:

- unnecessary microscopic geometry
- realistic micro-detail
- extremely dense meshes
- tiny decorative elements with no gameplay value

A model should look good from the distance at which players actually see it.

---

# 14. Material Rules

Default materials should be stylized PBR.

Typical properties:

- base color
- roughness
- metallic where appropriate
- limited emission
- controlled normal detail
- subtle ambient occlusion

Textures should support the geometry rather than compensate for bad geometry.

We should avoid making the game dependent on huge texture files.

---

# 15. Color Direction

The game should use vivid but controlled color palettes.

Potential palette families:

- cyan
- blue
- orange
- yellow
- purple
- green
- red
- cream
- dark navy

Colors should be assigned intentionally.

Not every object should be saturated.

Each map should have a defined primary palette and accent palette.

---

# 16. Visual Hierarchy

The visual importance hierarchy is:

### Highest priority

**Gameplay objects**

Enemies, weapons, pickups, important interactive objects.

### High priority

**Player characters and weapons**

### Medium priority

**Environment**

### Lowest priority

**Background scenery**

The environment must never overpower the player.

---

# 17. Weapon Art Direction

Weapons are allowed to have more visual detail than ordinary environment props.

They should be:

- recognizable
- stylized
- slightly exaggerated
- clean
- visually distinct

Traditional firearm designs are the starting point.

Future weapons may become more experimental, but the initial game should remain grounded.

---

# 18. Map Art Direction

Maps should feel like stylized game arenas rather than realistic military installations.

Possible visual themes:

- colorful industrial complex
- desert outpost
- urban district
- rooftop arena
- tropical facility
- futuristic training ground

Every map should have a controlled visual palette.

---

# 19. Map Design Rules

Each map should support:

- central combat
- flank routes
- high ground
- low ground
- close-range areas
- long-range sightlines
- cover
- movement routes
- multiple approach angles

Maps should be designed for combat first.

Decoration comes after gameplay structure.

---

# 20. First Map

The first map will begin as a graybox.

Initial geometry:

- cubes
- ramps
- stairs
- simple platforms
- simple walls
- collision blocks

No effort should initially be spent making the first map beautiful.

The graybox will first prove:

- movement
- sightlines
- combat ranges
- spawn safety
- map flow
- verticality

Only then will we build the final art.

---

# 21. VFX

VFX should be:

**punchy + readable + colorful + controlled**

Initial requirements:

- muzzle flash
- bullet tracer
- bullet impact
- hit spark
- hit marker
- reload effects
- shell ejection
- elimination effect
- subtle camera shake

Effects should communicate gameplay rather than simply fill the screen.

---

# 22. Audio

Audio is part of the gameplay feedback system.

Initial audio categories:

### Weapons

- fire
- reload
- dry fire
- weapon switch

### Player

- footsteps
- jumping
- landing
- movement

### Combat

- hit
- headshot
- elimination
- damage feedback

### UI

- button click
- menu navigation
- match start
- match end

### Environment

- ambient sound
- map-specific sounds

Different weapons must have recognizably different sounds.

---

# 23. HUD

The HUD should remain minimal.

## Center

Crosshair.

## Top

Score and match information.

## Bottom left

Health.

## Bottom right

Weapon and ammunition.

## Side

Kill feed.

The HUD should communicate information without obstructing gameplay.

---

# 24. Crosshair

Initial crosshair:

- simple
- readable
- centered
- low visual weight

Future options may include:

- size
- thickness
- gap
- dot
- color
- opacity

---

# 25. Menus

Eventually the main menu may contain:

```text
PLAY
LOADOUT
CUSTOMIZE
SETTINGS
PROFILE
```

Later additions may include:

```text
STORE
SOCIAL
PROGRESSION
```

None of these are required for the first prototype.

---

# 26. Progression

Progression is deliberately postponed.

Do not build:

- battle pass
- loot boxes
- complex currency
- daily missions
- achievements
- inventory systems

until the underlying game is genuinely fun.

---

# 27. Bots

Bots will be used during development before multiplayer.

The first bot should support:

- spawning
- navigation
- target detection
- aiming
- shooting
- taking damage
- death
- respawning

The first bot does not need advanced intelligence.

Its purpose is testing the combat loop.

---

# 28. Multiplayer Strategy

Multiplayer is a major technical system and should not be the first thing we build.

Development order:

### Stage 1

Single-player movement.

### Stage 2

Single-player combat.

### Stage 3

Bots.

### Stage 4

Stable FFA gameplay.

### Stage 5

Two-player multiplayer prototype.

### Stage 6

Four-player testing.

### Stage 7

Eight-player target.

This lets us validate gameplay before introducing networking complexity.

---

# 29. Technical Architecture

Systems should remain modular.

Major conceptual systems:

```text
PlayerController
MovementSystem
CameraSystem
WeaponSystem
HealthSystem
DamageSystem
BotSystem
MatchSystem
SpawnSystem
UI
AudioSystem
VFXSystem
```

Do not make one enormous player script responsible for everything.

---

# 30. Data-Driven Architecture

Reusable game data should be stored separately from logic.

Examples:

```text
WeaponData
CharacterData
MapData
MatchData
```

This lets balancing happen without rewriting gameplay code.

---

# 31. Project Organization

Suggested structure:

```text
project/
├── assets/
│   ├── models/
│   ├── materials/
│   ├── textures/
│   ├── animations/
│   ├── audio/
│   └── vfx/
│
├── scenes/
│   ├── player/
│   ├── weapons/
│   ├── enemies/
│   ├── maps/
│   ├── ui/
│   └── gameplay/
│
├── scripts/
│   ├── player/
│   ├── weapons/
│   ├── enemies/
│   ├── gameplay/
│   ├── systems/
│   └── ui/
│
└── data/
    ├── weapons/
    ├── characters/
    ├── maps/
    └── configuration/
```

The exact structure can be adjusted after Antigravity inspects the current project.

---

# 32. Blender MCP Pipeline

Blender is the production tool for 3D assets.

The intended workflow is:

```text
Game design
     ↓
Asset specification
     ↓
Blender / Blender MCP
     ↓
Model
     ↓
Materials
     ↓
Export
     ↓
Godot import
     ↓
Prefab / scene
     ↓
Gameplay integration
```

We do not generate random assets without a defined requirement.

---

# 33. Asset Production Rules

Every production asset should have:

- a clear purpose
- defined scale
- defined polygon budget
- consistent proportions
- consistent material treatment
- consistent color language
- clean naming
- appropriate collision

Assets should be reusable whenever possible.

---

# 34. AI Development Rules

Antigravity and Gemini are implementation tools, not autonomous game directors.

They must operate under the Game Bible.

## Rule 1

Do not redesign the project architecture without approval.

## Rule 2

Do not rewrite unrelated systems.

## Rule 3

Do not create duplicate systems when one already exists.

## Rule 4

Do not introduce unnecessary dependencies.

## Rule 5

Do not modify working systems just to make an unrelated feature easier.

## Rule 6

Do not generate production assets without an approved asset specification.

## Rule 7

Do not build future features while the current milestone is incomplete.

## Rule 8

When modifying code, preserve existing behavior unless the task explicitly changes it.

## Rule 9

Prefer small, testable changes.

## Rule 10

After completing a change, report what was changed and what should be tested.

---

# 35. Development Method

We use:

> **One subsystem → implement → test → fix → lock → next subsystem.**

Not:

> **Ask AI to create the whole game.**

This rule is fundamental.

---

# 36. Milestones

## Milestone 0 — Project Foundation

- Godot project structure
- input actions
- core folders
- basic test scene
- version control
- architecture setup

## Milestone 1 — Movement

- mouse look
- walk
- sprint
- jump
- air control
- crouch
- slide

## Milestone 2 — First Weapon

- weapon view
- fire
- ammo
- reload
- recoil
- hit detection

## Milestone 3 — Combat Loop

- health
- damage
- death
- respawn
- score

## Milestone 4 — Bot

- navigation
- targeting
- combat
- death
- respawn

## Milestone 5 — FFA

- multiple bots
- score
- timer
- match end
- scoreboard

## Milestone 6 — Combat Polish

- weapon animation
- hit VFX
- muzzle flash
- audio
- camera effects
- hit feedback

## Milestone 7 — First Art Pass

- character
- first weapon
- environment
- materials
- lighting
- first real map

## Milestone 8 — UI

- main menu
- HUD
- scoreboard
- settings

## Milestone 9 — Multiplayer

- networking foundation
- player synchronization
- shooting synchronization
- match synchronization
- 2-player prototype
- scaling toward 8 players

## Milestone 10 — Content

- additional weapons
- maps
- skins
- customization
- progression

---

# 37. Prototype 0.1 Definition

The first real playable prototype contains only:

```text
ONE PLAYER
ONE RIFLE
ONE GRAYBOX MAP
ONE BOT
```

Player can:

```text
LOOK
MOVE
SPRINT
JUMP
SLIDE
SHOOT
RELOAD
TAKE DAMAGE
KILL
DIE
RESPAWN
```

The goal is not visual beauty.

The goal is:

> **Does moving and shooting feel good?**

---

# 38. What We Do NOT Build Yet

Until Prototype 0.1 works, do not build:

- multiplayer
- skins
- shop
- progression
- battle pass
- multiple maps
- five finished weapons
- advanced bot AI
- complex UI
- matchmaking
- accounts
- social systems

The project grows only after the core gameplay proves itself.

---

# 39. Art Production Order

When the graybox is fun, the art pipeline should proceed roughly like this:

### First

Player character.

### Second

First-person rifle.

### Third

Basic environment kit.

### Fourth

Map props.

### Fifth

Materials and lighting.

### Sixth

VFX.

### Seventh

Additional weapons.

### Eighth

Cosmetics.

This gives us immediate visible improvement without wasting effort.

---

# 40. Performance Philosophy

The target is a game that feels fast even on weaker hardware.

We should favor:

- reusable materials
- modular assets
- reasonable poly counts
- efficient collision
- controlled textures
- limited expensive transparency
- limited dynamic lighting
- optimized particles
- sensible scene organization

The game should look good because of **art direction**, not brute-force rendering.

---

# 41. Quality Bar

An asset should not be accepted merely because it is technically functional.

The question is:

> **Does it look like it belongs in this game?**

A model can be technically excellent and still be rejected if it violates the art direction.

Consistency beats individual asset complexity.

---

# 42. Originality Rule

References are used to understand principles.

They are not templates to copy.

We may take inspiration from the broader design space of:

- Krunker
- Deadshot.io
- Venge.io
- other arcade FPS games

But Project FPS must develop its own:

- identity
- weapons
- characters
- maps
- UI
- visual language
- progression
- gameplay details
- branding

---

# 43. Temporary Naming

The final title is intentionally undecided.

Do not create logos, branding, splash screens, domains, or marketing materials until the name has been properly checked for existing games, companies, trademarks, domains, and social presence.

The name will be selected later.

---

# 44. Current Project Status

## Already completed

- Godot 4.7 project created
- Antigravity connected
- Blender MCP connected
- Gemini 3.7 Flash selected as the implementation model

## Current state

**Pre-production / Foundation**

## Current objective

Build the first graybox FPS prototype.

---

# 45. Immediate Next Step

The next task is **NOT Blender asset generation**.

The next task is:

> **Inspect and prepare the existing Godot project for the FPS prototype.**

Antigravity should first inspect the project and understand what already exists.

Then we establish the project structure and basic player architecture without building unnecessary systems.

After that we implement:

**camera + movement → sprint → jump → slide → first-person weapon → shooting.**

---

# 46. Master Rule

At every stage we ask:

> **Does this make the game more fun, more readable, more polished, or more technically reliable?**

If not, it probably does not belong in the current milestone.

---

# FINAL VISION

Project FPS aims to become:

> **A fast, colorful, highly readable, stylized low-poly FPS where movement and gunplay are the stars.**

It should be approachable like a browser game, polished enough to feel like a real commercial game, lightweight enough to run well, and structured so a small team using AI tools can continuously add content without destroying the codebase.

**Core formula:**

> **Fast movement + satisfying guns + colorful low-poly worlds + short matches + strong feedback + clean competitive presentation.**