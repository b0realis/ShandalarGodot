# Adventure plugins — the developer reference

Adventure plugins (0.60.19) are data-only packages that add an island to the
adventure, reached by ship from a mainland harbor; since API 2 (0.70.4) a
**sites plugin** adds places instead — a hut, a guild's tower — that stand
on the mainland and on the islands ([Sites plugins](#sites-plugins-api-2)).
This page is for whoever
works on the game's side of them: the loader, the interpreter, the saves and
the tools. Plugin **authors** have their own guide, shipped with the game:
[`expanded_adventure/GUIDE/index.html`](../expanded_adventure/GUIDE/index.html)
(local HTML, never published), whose Reference page is generated from the
schema by `tools/adventure_plugin.py guide`.

The owner's words (2026-11-10): *"a small package players can download and
plugin to the vanilla shandalar adventure game … found in 'expanded_adventure'
folder in game folder where also card packs reside. Player can tick/enable
individual adventure plugins"*, and *"We will not design new content but let
the community do it at their will. Design good tools, api and docs for
them."*

## The rulings

1. **Data only, forever.** A plugin is JSON, text, PNG/JPEG/WebP pictures and
   Ogg Vorbis music. Nothing of it is ever loaded as a resource, run as a
   script or mounted (`load_resource_pack` is never used): files are read as
   bytes (`ZIPReader`, `FileAccess`) and decoded from buffers
   (`Image.load_*_from_buffer`, `AudioStreamOggVorbis.load_from_buffer`).
   Every behaviour is a `res://` interpreter of that data.
2. **Card packs behave as in the vanilla adventure.** A plugin names the
   packs it needs; it never withholds or unlocks their cards
   (`AdventurePacks.offers_cards` is not gated by any land).
3. **No launch flag.** `--expanded-adventure` is accepted and ignored. A
   plugin is on for a campaign when it was ticked at the Embark, is
   installed and valid, its packs are the campaign's and enabled, and its
   saved land fits the installed version.
4. **The Embark** shows one button, **Expanded adventure plugins...**, at the
   foot of the card-pack list; it opens `PluginsWindow`. Ticking a plugin
   ticks its installed packs; unticking a pack unticks the plugins needing it.
5. **A plugin missing, or changed so it cannot read a save**, never refuses
   the save: the land is carried as it is and the hero can always sail home.
   A missing **card pack** still refuses the resume.
6. **The island is deterministic.** The same recipe and the same campaign
   seed always make the same island, so the islands of a plugin's players
   that have not been visited yet stay as they are until the recipe changes.
   `tests/unit/test_island_generator_golden.gd` pins `IslandGenerator` to 70
   fingerprints of the prototype's island (seeds × colors × difficulties).
7. **API 1 scope:** islands reached by ship. Mainland touch points: the
   anchorage, its pane, the voyage, the Tasks rows. **API 2** (0.70.4, the
   owner, 2026-11-21) adds the sites plugins, a kind of their own: places on
   the lands a campaign has, never a land themselves.
8. **Shipping:** the desktop releases carry `expanded_adventure/`
   (`Fallen_Empires_Refuge_prototype.zip`, `README.txt`, `GUIDE/`) beside the
   game, and `tools/adventure_plugin.py` with its card lists. The guide holds
   no card art and no 1997 or skin picture.
9. **The prototype is a game-design and learning demo** (its manifest's
   `learning_note`, its README, the plugins window, the guide). The project
   adds no adventure content of its own — but for the two places the owner
   asked for on 2026-11-21 (*"No the project is a self contained new place!
   (As a study for other places the players wish)"*): **An Old Adventurer's
   Hut** and the **Conjuration Wizard Guild**, sites plugins shipped beside
   the Refuge, each a finished place and a study.

## Where the code is

| File | Class | Job |
|---|---|---|
| `game/adventure/plugins/adventure_plugins.gd` | `AdventurePlugins` | The registry: folders, scan, the staged checks, rows, data, descriptors, pictures and music from bytes. |
| `game/adventure/plugins/plugin_package.gd` | `PluginPackage` | One package read into `{rel: bytes}`: the zip's central directory or the folder walk, paths, kinds, limits, picture headers, OGG, UTF-8, JSON depth. |
| `game/adventure/plugins/schema_v1.json` | — | The content schema, API 1: kinds, files, types, limits, placeholders, skin pictures. Read by `PluginSchema` and by the tool. |
| `game/adventure/plugins/plugin_schema.gd` | `PluginSchema` | The content stage: shapes against the schema, defaults filled, cross checks, card names; the descriptor. |
| `game/adventure/plugins/plugin_text.gd` | `PluginText` | `text.json`: the closed placeholders, the engine's default words, `say()`. |
| `game/adventure/plugins/island_generator.gd` | `IslandGenerator` | `world.json`'s `"island"` generator and its objectives. |
| `game/adventure/plugins/data_region.gd` | `DataRegion` | The interpreter, one instance per plugin: every hook below. Model side. |
| `game/adventure/plugins/plugin_journey.gd` | `PluginJourney` | The UI side: the panes' buttons and the duels, reached from `DataRegion` by `load()` only (the h5-1 rule). |
| `game/adventure/expansions/adventure_expansions.gd` | `AdventureExpansions` | The lands' directory: definitions, providers, enabled/chosen, the voyage, places, the game's own panes, pictures, map sprites, music, the mainland note. |
| `game/adventure/expansions/adventure_regions.gd` | `AdventureRegions` | Travel and snapshots; a saved land judged FINE, BROKEN or CHANGED. |
| `game/adventure/expansions/expansion_contract.gd` | `ExpansionContract` | The provider fence, the progress schema, opaque progress bounds. |
| `game/adventure/world/world_terrain_palette.gd` | `WorldTerrainPalette` | Built-in palettes and a plugin's own, registered as `plugin:<id>` ([terrain palettes](terrain-palettes.md)). |
| `game/adventure/plugins_window.gd` | `PluginsWindow` | The Embark's plugins window. |
| `game/adventure/expansions/adventure_sites.gd` | `AdventureSites` | API 2: the sites plugins on for a campaign, their places put on each land (`world.expansion.sites`), the places' markers, panes, buttons, pictures and sprites. |
| `game/adventure/plugins/data_sites.gd` | `DataSites` | API 2: a sites plugin's interpreter, model side — panes, conditions, effects, the prices, a copy, a dungeon raised. |
| `game/adventure/plugins/site_journey.gd` | `SiteJourney` | API 2: what a place's buttons do on the world screen (the copy's card list), reached from `DataSites` by `load()` only. |
| `tools/adventure_plugin.py` | — | `new` (`--kind sites` for places), `validate`, `export`, `info`, `compat`, `guide`, and for places `add-place`, `add-dungeon`, `walk` (a place played as text, without the game) and `art` (advice on the pictures): the authoring tool and the Python twin of the checks. |

## Discovery

`AdventurePlugins.folders()`, in order, each folder once:

1. `GamePaths.expanded_adventure_folder()`: the `expanded_adventure_folder`
   key in `settings.cfg`, default `user://expanded_adventure` (on Android in
   the app's shared-storage corner). Options names it on its **Adventure
   plugins folder** line under the card folder.
2. `expanded_adventure/` beside the executable (on Android the same corner).
3. Not in an exported game: `res://expanded_adventure/` (the repository's own,
   with a `.gdignore`, excluded from every export preset) and
   `../shandalar-packs/expanded_adventure/`.

In each folder the `.zip` files by name, then the subfolders holding
`plugin.json` by name; anything else (the guide, a README) is passed over.
The first copy of an id wins; later copies are listed in its row's
`shadowed`. `scan()` runs once on first use and again from the plugins
window's Rescan; `revision` counts scans, and a rescan lets go of every
decoded picture and track. Tests set `folders_override`.

## The staged checks

The first stage with a problem refuses the plugin; its problems (all of that
stage's) are the row's `problems`, and later stages are not run. The tool runs
the same stages in the same order with the same sentences; the corpus in
`tools/plugin_fixtures/` is judged by both (`tests/unit/test_plugin_corpus.gd`,
`tools/test_adventure_plugin.py`).

1. **The package** (`PluginPackage.read`). A zip ≤ 32 MiB on disk, read from
   its central directory before anything is inflated: classic zip only (no
   zip64, no encryption), stored or deflated entries, no two names equal
   ignoring case, no symbolic link, every entry under one top folder that
   holds `plugin.json`. A folder: no symbolic link, ≤ 256 folders. Every
   path ≤ 200 characters, relative, `/` only, no `\`, `:`, NUL or control
   character, no empty, `.` or `..` part. Extensions `.json .txt .md .png
   .jpg .jpeg .webp .ogg` only. ≤ 512 files, ≤ 32 MiB in all; a JSON, `.txt`
   or `.md` ≤ 1 MiB and UTF-8; an OGG ≤ 16 MiB and Vorbis by its first page;
   a picture's header names its extension's kind and ≤ 4096 px a side
   (read from the header, nothing decoded). **Litter** is never read nor
   counted: a name beginning with `.`, a `__MACOSX` folder, `Thumbs.db`,
   `desktop.ini` (case ignored).
2. **The manifest** (`manifest_problems`). Unknown fields refused. Required:
   `plugin_format` (1), `api_version` (1..`API_VERSION`), `id`
   (`^[a-z][a-z0-9_]{0,39}$`, not `mainland`), `name` (≤ 100), `version` (1–4
   numbers and dots, ≤ 24 characters), `authors` (1–16 names ≤ 100),
   `description` (≤ 300), `region` (`title` required ≤ 100; `castle_name`,
   `salt` 0–2147483647, `mana_links` bool, `palette` a built-in name or an
   object). Optional: `minimum_game_version` (refused when newer than the
   game), `license` and `learning_note` (≤ 4000), `requires.card_packs`
   (≤ 16 of `{id, min_version}`, each a pack the game knows, never
   `pack-1`, none twice), `files`.
3. **The files list** (`integrity_problems`), when `files` is present: every
   listed file present with that SHA-256, every file but `plugin.json`
   listed. Integrity, not authorship. `export` writes it into the zip only;
   source folders carry none.
4. **The content** (`PluginSchema.read`). Each content file against its
   schema type, defaults filled and numbers normalized; then the cross
   checks: every text key exists (or is a `PluginText.DEFAULTS` key) and
   uses only the closed placeholders; picture keys begin with `<id>_`; every
   picture named is a plugin key or a schema `skin_pictures` name; every
   card is in a required pack's trusted list (`contract.names()`, shipped,
   never the zip's word) or a base-game card (`CardRegistry`, no numbered
   pack's); slots unique and ≤ 127, villages within range; quest givers are
   towns or places, one quest each; foes, flags, objectives, completions,
   quest indices and `deck_share` packs exist; a quest's last step is its
   duel and only its first may be an accept; flags avoid
   `PluginSchema.RESERVED_FLAGS`; a reward choice needs bundles; faces are
   creature rows; the palette object is well formed. Effects that would
   write progress the save check refuses are refused here
   (`PluginSchema._check_effects`): more than one `reward_choice` in a
   completion, any in the finale, a `set_stage` past its quest's steps less
   one, a `set_flag` of the finale's `done_flag` outside the finale. Their
   words, AT being `quests.json: quests[N].complete` or
   `quests.json: finale.effects` (a named completion is checked for each
   quest that uses it):
   - "AT: one reward_choice at most; a quest owes one reward choice."
   - "quests.json: finale.effects: a reward_choice belongs to a quest's
     completion, not the finale."
   - "AT: set_stage: quest Q has S steps; its stage goes up to S-1."
   - "AT: set_flag: F is the finale's flag; only the finale's effects set it."

   A JSON file that does not parse reads "FILE: line N: MESSAGE", N counted
   from 1, in the game and the tool alike.

A refused plugin is still a row of `all()`, so the window can say why.

## The registry API (`AdventurePlugins`)

- `API_VERSION := 2`, `PLUGIN_FORMAT := 1`, `FOLDER_NAME`, `ID_PATTERN`;
  `KIND_ISLAND`, `KIND_SITES`, `SITES_API` (2).
- `kind(id)`, `manifest_kind(manifest)`, `land_ids()` (the islands
  `AdventureExpansions` knows), `site_ids()` (the sites plugins
  `AdventureSites` knows); `ids()` lists both.
- `scan()`, `folders()`, `candidates(folder)`.
- `all() -> Array[Dictionary]`: rows `{id, name, version, api, path, kind
  ("zip"/"folder"), description, authors, license, learning_note, requires:
  {card_packs: [{id, min_version}]}, problems, shadowed}`, copies.
- `ids()` (valid only), `valid(id)`, `row(id)`, `refusal(id)` (the first
  problem), `manifest(id)`, `data(id)`, `descriptor(id)`, `pack_ids(id)`.
- `texture(id, rel) -> Texture2D`, `stream(id, rel) -> AudioStream`: the
  bytes read again and held to the hash the scan took; decoded, cached, the
  stream looping; null when absent or changed.
- `revision`; test seams `folders_override`, `content_reader`.

**The descriptor** (`PluginSchema.descriptor`, the manifest's word for any
field it leaves out): `id`, `plugin: true`, `version`, `name`, `title`,
`castle_name`, `salt`, `mana_links`, `palette` (a built-in name, or
`plugin:<id>` once registered), `pack` (the first) and `packs`,
`required_markers` (`port`, `castle`), `required_sites` (every town slot),
`progress_schema` `{quests, max_stage, stage_limits, max_pending, flags,
complete_flags}` (`stage_limits` each quest's steps less one; `max_pending`
the larger of 60 and quests × `rewards.count`), `initial_progress`, `pictures`, `sprites` (`{kind: [file,
width]}`), `generator` (the label a save writes beside the region's map),
`layout_version`. No `provider`: a plugin's provider is always
`DataRegion.new(id)`.

**The data** (`data(id)`): `{id, manifest, world, places, quests, foes,
rewards, text, packs}`, each content file normalized, `world.region` set to
the id, every quest's `complete` resolved to its effects.

## The hooks

`AdventureExpansions.active(player, method, args, fallback)` calls the
active land's provider when the hero is off the mainland; a few are called
directly. Every hook `DataRegion` answers:

<!-- hooks -->
| Hook | Called by | Answers |
|---|---|---|
| `initialize(player)` | the hook contract | forwards to `AdventureExpansions.initialize` (the mainland's anchorages, each land's initial progress), which the world screen calls itself |
| `travel(player)` | `PluginJourney`, the port's sail | the voyage either way, its clues and journal lines |
| `describe(player, tile)` | `AdventureExpansions.describe` | the port's or castle's pane: the first pane whose `when` holds, plus the current steps' buttons there |
| `decorate_town(player, slot, place)` | `VisitPane` | a giver town's line and button in the wise man's place; a step's button at its town |
| `ordinary_quests(player, slot)` | the world screen's town errands | false for `errands_off` slots |
| `act(screen, action, place)` | `AdventureExpansions.act` | the `<id>_<verb>` buttons, through `PluginJourney` |
| `duel_config(player, quest)` | tests and tools (`PluginJourney` builds the same) | a quest's duel, or the finale's (`-1`) |
| `status_lines(player)` | `world_status.gd` | `quests.status` |
| `targets(player)` | `world_status.gd` | each open quest's destination, then `targets.after_*` |
| `deck_line(player, cards)` | the town deck builder | `quests.deck_line` with the deck gate's numbers |
| `roaming_tier(player, tier)` | `world_lairs.gd`, a new creature's tier | at least `roaming.min_tier` (0 stays 0) |
| `tales(player)` | the wise man | `talk.tales` |
| `news(player)` | the wise man | `talk.news`, the first line that holds |
| `applause(player)` | the wise man | `talk.applause`, the first line that holds |
| `roaming_words(player, wins)` | a creature meeting | `talk.roaming`, or `talk.tribute` after `CreatureMeeting.TRIBUTE_WINS` |
| `dungeon_words(player)` | the dungeon's visit pane | `talk.dungeon` |
| `entered(player)` | `AdventureExpansions.entered` | objectives chosen, pennants refreshed |
| `task_rows(data, progress)` | `AdventureTasks` | the Tasks rows from the SAVED world and progress (no live world needed) |
| `generate(seed, color, difficulty)` | `AdventureExpansions.generate` | `IslandGenerator.generate`, the seed already XOR `region.salt` |
| `roaming_encounter(player, meeting)` | `CreatureMeeting` | the plugin's deck, name, life and ante for an ordinary roaming meeting |
| `study_decks()` | the Expansion Lab | each roaming deck, then the finale's foe under the castle's name |
| `music()` | `AdventureExpansions.music` | `world.music` decoded, or null |
<!-- /hooks -->

**Actions.** A plugin pane's buttons are `<id>_<verb>`: `sail`, `leave`,
`back`, `quest`, `accept_N`, `deliver_N`, `petition_N`, `fight`, `boss`,
`reward`, `reward_N`, `claim`. `AdventureExpansions.action_owner` gives the
longest id an action begins with. The game's own: `region_visit:<id>` (the
shared anchorage's choice), `region_home` and `region_leave` (a land nothing
can read now). Pane kinds: `region_port`, `region_castle`, `region_quest`,
`region_reward`, `region_result`.

**Model side.** `DataRegion` never names `WorldScreen`, `VisitPane`,
`WorldHud` or an autoload; the screen arrives untyped and builds its own pane
(`WorldScreen.open_place`). `tools/test_script_entry_points.py` follows the
references.

## Progress, saves and lands that cannot be read

**The progress record** (`player.expansions[id]`):
`{quests: [indices done], stages: {"i": steps done}, reward_choices:
[indices owed], pending: [card names]}` plus every declared flag (bool).
`ExpansionContract.valid_progress` holds it to the descriptor's
`progress_schema`: each quest's stage to its own `stage_limits` entry, the
waiting cards to `max_pending` (the Refuge's `stage_limits` are
`[2, 2, 0, 1, 0]`); a flag in `complete_flags` (the finale's `done_flag` when
the finale needs `"quests_done": "all"`) is on only with every quest done.

**Save version 8** (`AdventurePlayer.FORMAT_VERSION` 8; 9 since API 2,
which adds the sites plugins' progress) is the format that records the
ticked plugins: `hero.adventures` `[{id, version, name}]`, the
version and name each plugin had when its land was last read (the name kept
for the words when it is missing). The mainland's anchorages are
`world.expansion.entries`; `regions` holds each inactive land's snapshot and
`expansions` each land's progress.

**Each saved land is judged** against the installed version
(`AdventureRegions.saved_state`, `ExpansionContract.progress_state`):

- **FINE**: it fits. Plays on; `note_versions` brings `hero.adventures`'
  version and name up to the installed plugin's on load.
- **BROKEN**: damaged under any version: the map (grid, region id,
  appearance, names, objectives, banners, entries), a land without its port,
  a map that is not 128 site records, progress of the wrong shape. The save
  is refused, as any damaged save.
- **CHANGED**: whole, but not what the installed version describes: a castle
  or town slot it requires is missing, a number is past what it counts
  (a quest index or done count, a stage, waiting cards), or a complete flag
  is on before every quest is done. The land is **held**
  (`player.held_lands`, never saved, recomputed on each load): carried as
  saved, `enabled_for` false, `provider_for` null, no Tasks or voyage rows;
  a hero on it gets the game's own panes (`stranded_place`).
- **Missing** (no installed plugin describes it): progress carried as opaque
  data (≤ 256 KiB as JSON, depth ≤ 32), snapshot kept; only its port is a
  must.

At a held or missing land's port the game's **Ship home** pane
(`region_home`), at its castle **Leave** (`region_leave`). On the mainland,
once a launch, `AdventureExpansions.mainland_note` says why each ticked land
does not sail:

- "Ships to %s do not sail: the plugin %s is not installed."
- "Ships to %s do not sail: the plugin %s is refused."
- "Ships to %s do not sail: the plugin %s needs %s."
- "Ships to %s do not sail: the plugin %s needs %s %s or newer (installed %s)."
- "Ships to %s do not sail: this adventure was saved with version %s of the
  plugin %s, and the installed version %s cannot read it." ("with another
  version" when the save names none.)

Putting the plugin (or the version saved) back restores the land on the next
load. `tests/unit/test_adventure_plugins_saves.gd` and
`tests/unit/test_adventure_plugins_updates.gd` pin this.
`tools/adventure_plugin.py compat OLD NEW` lists, for authors, every change
that would hold old saves' land.

## Music and pictures

`world.music` (an OGG of the plugin) plays while the hero walks the island
(`world_duels.gd`'s region music, `AdventureExpansions.music`); the
mainland's music everywhere else. A plugin's duels rest the region track
and the place's tune like every adventure duel (`WorldDuels.host`,
`WorldDuels.place_tune_off`): the duel's own music alone. Pictures are decoded on demand by key
(`AdventureExpansions.picture`: a plugin's `pictures` key, else the skin's)
and map sprites by `AdventureExpansions.map_op`: the picture's used rect,
`width` world pixels wide, its foot at (64, 24) of the 128 × 64 tile box.

## How to add a condition or an effect

The closed sets today:
<!-- conditions -->conditions `flag`, `not_flag`, `stage`, `quest_done`, `quests_done`, `deck_share`, `on_region`, `here`, `rewards_owed`, `cards_pending`<!-- /conditions -->
and
<!-- effects -->effects `set_stage`, `set_flag`, `gold`, `food`, `reward_choice`, `claim_cards`, `log_clue`, `log_event`, `refresh_appearance`<!-- /effects -->.

1. **The schema.** Add the option to `types.condition.options` (or
   `types.effect.options`) in `game/adventure/plugins/schema_v1.json`, with
   its value's kind, limits and a `doc`. Both validators read it.
2. **The interpreter.** Add its case to `DataRegion._holds` (or
   `DataRegion.apply`). Keep it a pure reading of the player and the land's
   progress: never hero strength or hidden information, never card-pack
   availability, never a file of the plugin.
3. **The cross checks.** If its value names a flag, quest, objective, site or
   pack, record it in `PluginSchema._condition_uses` (or `_effect_uses`) so a
   wrong name refuses the plugin. An effect that writes progress must never
   write a record `ExpansionContract.valid_progress` refuses: check its
   bounds in `PluginSchema._check_effects`. Mirror any GDScript-side rule in
   `tools/adventure_plugin.py` (its twins are tested for drift).
4. **The API version.** A plugin using the new key would be refused by an
   older game at the content stage, with a shape problem rather than the plain
   "a newer game is needed". Raise `AdventurePlugins.API_VERSION` (and the
   schema's `api_version`) with the release that brings it, keep every API 1
   plugin valid, and tell authors to declare the new `api_version` when they
   use it.
5. **Tests and docs.** A case in `tests/unit/test_plugin_interpreter.gd` (it
   holds and does), a shape case in `tests/unit/test_plugin_schema.gd`, good
   and bad fixtures in `tools/plugin_fixtures/` with `expected.json`; then
   `python3 tools/adventure_plugin.py guide` to regenerate the guide's
   Reference page, and the tables in the guide's `quests.html` and in this
   page (`tools/test_adventure_guide.py` checks both lists against the
   schema).

## Sites plugins (API 2)

The owner, 2026-11-21: *"Is it possible to add a new type of town or
interaction place as a plugin? For example one would supply an icon and
rules."* Then: *"this separate plugin can be placed on other islands or on
mainland if used"*; a dungeon it raises is *"separate from the main quest
and hold[s] from the list of plugin creator"*; and *"Yes saves work!"*.

**The manifest.** `kind: "sites"` with `api_version` 2 or newer; no
`region` (refused). Its content is `sites.json` and `text.json`
(`schema_v1.json`'s `site_files` and its `sites_` types); every other rule
of the manifest, the package and the files list is the island's.

**`sites.json`.** `salt`, `flags` (declared, all off at the start),
`pictures` (keys beginning with the plugin's id), `dungeons` (by key:
`name`, `color` or `random`, `size`, `rules`, 1–6 `cards` of the base game
or a required pack, `distance` from the place in tiles) and `sites` (by
key, 1–8): `name`, `where` (`mainland`, `islands`), `picture`, `sprite`,
`gap`, and 1–8 `panes`, the first whose `when` holds shown — its `title`,
`subtitle`, `picture`, `lines` and up to 8 `actions`. An action has an `id`
(its uses are counted by it, the same id the same action in every pane),
`do` (`effects`, `copy_card` or `leave`), a `label`, `when`, `prices`,
`effects`, `result` (the lines after it is done) and, for a copy,
`pick_title` and `pick_line`.

**Prices.** The n-th use of an action costs its n-th price; once every
price is paid the action is gone from its pane. An action without prices
is free and never used up. A button is ready when the hero carries the
price (and, for a copy, a card may be copied and the bag has room); a
press that cannot be done pays nothing and says why (`site.no_gold`,
`site.bag_full`, `site.no_cards`, `site.no_room`).

The closed sets:
<!-- site_conditions -->conditions `flag`, `not_flag`, `gold_at_least`, `on_mainland`, `used`, `used_up`, `dungeon`<!-- /site_conditions -->
and
<!-- site_effects -->effects `set_flag`, `clear_flag`, `gold`, `food`, `log_clue`, `log_event`, `spawn_dungeon`<!-- /site_effects -->.
The placeholders `{price}`, `{uses_left}`, `{gold}`, `{card}` and
`{dungeon}` join the list.

**Where a place stands** (`AdventureSites.place_here`, from
`AdventureExpansions.initialize` on the mainland — after the anchorages —
and from `entered` on an island): once, the first time the hero is on a
land whose kind its `where` names, on a tile of the start's land (the
mainland's start, the island's port) with no site, road or dungeon, at
least `gap` tiles from every town, castle, dungeon, anchorage and place,
next to a road when such a tile is. The tile is drawn on the plugin's own
dice (`AdventureSites.dice_for`: the land's seed, the plugin's salt and
the place's key, FNV-1a), never the adventure's or the world's: a campaign
without sites plugins, and every 1997 draw of one with them, is as before
(`tests/unit/test_site_plugins_2026_11_21.gd` pins the fingerprint and the
dice). The tile is kept in that land's `world.expansion.sites`,
`{"<plugin>:<site>": [x, y]}`; a moved dungeon never takes it
(`DungeonDoors.expansion_place`).

**On the map and in the panes.** A place is a marker `<plugin>:<site>` of
`AdventureExpansions.places` (drawn by `map_op` from its `sprite`, listed
on the map and the minimap); its pane's kind is `site` (it pushes the
creatures back as a town does). Its buttons are `<plugin>_act:<site>:<action>`,
`<plugin>_back:<site>` and `<plugin>_leave`; `AdventureExpansions.act`
hands the longest owner of a button its press.

**A dungeon raised** (`DataSites.spawn`): a new encounter slot after the
1997 fifteen (`WorldClues.MOST_SLOTS`, 48 in all; on an island after its
six), its tile drawn on the plugin's dice within the dungeon's `distance`
of the place (else the nearest such tiles past its `min`), its color, size
and rules the plugin's, its treasure the plugin's cards by name
(`left_cards`, as cards put back in a dungeon are kept), its name in the
land's `dungeon_names`, and every clue of it known. From then on it is an
ordinary dungeon of the land: entered, moved when left, drawn and listed
as any. The doors, the board and the map look to `MOST_SLOTS`; 1997's dice
walks (the hint's pick, the marks' fading) keep their fifteen. A slot past
14 wears the look of slot 5 + (index − 5) mod 10. One dungeon of a key is
open on a land at a time; an action whose dungeon cannot be raised (no
slot, no tile) pays nothing.

**A copy** (`DataSites.copy_card`): one more of a card the hero holds
(`DataSites.copyable`: under the Classic MTG rules none they hold every
copy of, the wise man's rule), into the bag (`AdventurePlayer.add_card`).

**Progress and saves.** `AdventurePlayer.sites`, by plugin id: `{uses:
{"<site>.<action>": n}, flags: [names], dungeons: {"<land>:<dungeon>":
slot}}` — the uses the plugin's as a whole (the Guild's towers on two lands
share one count). **Save version 9** writes it as `sites` and a sites
plugin's row of `hero.adventures` with `kind: "sites"`; a save from before
reads none, and every row an island's. A sites plugin missing or refused:
its places hide (their tiles kept), its progress is kept, a dungeon it
raised stays an ordinary dungeon, and the save opens; it never has a ship,
a mainland note or a Tasks row (`AdventureExpansions.sites_row`).

**The shipped places.** `expanded_adventure/Old_Adventurers_Hut/` (id
`old_hut`): on the mainland; 1000 gold, once, raise *The Forgotten Vault*
(large, its color drawn, 8–22 tiles away) holding Old Man of the Sea,
Planar Gate and Mirror Universe; three panes by the vault's state.
`expanded_adventure/Conjuration_Wizard_Guild/` (id `conjuration_guild`):
on the mainland and every island; a copy for 2000, 4000, 8000 and 12000
gold, then no more. Neither needs a card pack.

## Tests

- Loader: `tests/unit/test_adventure_plugins_package.gd`,
  `test_adventure_plugins_registry.gd`, `test_adventure_plugins_music.gd`;
  saves: `test_adventure_plugins_saves.gd`, `test_adventure_plugins_updates.gd`.
- Content and interpreter: `test_plugin_schema.gd`, `test_plugin_text.gd`,
  `test_plugin_palette.gd`, `test_plugin_interpreter.gd`,
  `test_island_generator_golden.gd` (data `island_generator_golden.json`).
- The Refuge's behaviour: `test_refuge_*.gd`, `test_c26_X6_*.gd` and the UI
  tests that name it; the fixture plugin `tests/fixtures/adventure_plugins/tiny_isle/`.
- Sites plugins (API 2): `tests/unit/test_site_plugins_2026_11_21.gd` —
  the manifest's kind, the content checks, the places on the mainland and
  an island with the 1997 world and dice unchanged, the hut's vault, the
  guild's four copies, the buttons, save version 9, a missing plugin.
- Both validators on one corpus: `tests/unit/test_plugin_corpus.gd`,
  `tools/test_adventure_plugin.py`.
- The authors' guide against the code and the prototype:
  `tools/test_adventure_guide.py`.
- `tools/expansion_lab.sh --plugin PATH` plays a plugin headless: travel,
  terrain, objectives, saves, its pack (or, needing none, itself) taken away
  mid-trip, and its land
  played to its end on the model's results (`tools/expansion_testing/lab_campaign.gd`:
  every quest, the rewards claimed, the finale, the save read back).
