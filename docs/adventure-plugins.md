# Adventure plugins — the developer reference

Adventure plugins (0.60.19) are data-only packages that add an island to the
adventure, reached by ship from a mainland harbor. This page is for whoever
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
   anchorage, its pane, the voyage, the Tasks rows.
8. **Shipping:** the desktop releases carry `expanded_adventure/`
   (`Fallen_Empires_Refuge_prototype.zip`, `README.txt`, `GUIDE/`) beside the
   game, and `tools/adventure_plugin.py` with its card lists. The guide holds
   no card art and no 1997 or skin picture.
9. **The prototype is a game-design and learning demo** (its manifest's
   `learning_note`, its README, the plugins window, the guide). The project
   adds no adventure content of its own.

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
| `tools/adventure_plugin.py` | — | `new`, `validate`, `export`, `info`, `compat`, `guide`: the authoring tool and the Python twin of the checks. |

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

- `API_VERSION := 1`, `PLUGIN_FORMAT := 1`, `FOLDER_NAME`, `ID_PATTERN`.
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

**Save version 8** (`AdventurePlayer.FORMAT_VERSION`) is the format that
records the ticked plugins: `hero.adventures` `[{id, version, name}]`, the
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
mainland's music everywhere else. Pictures are decoded on demand by key
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

## Tests

- Loader: `tests/unit/test_adventure_plugins_package.gd`,
  `test_adventure_plugins_registry.gd`, `test_adventure_plugins_music.gd`;
  saves: `test_adventure_plugins_saves.gd`, `test_adventure_plugins_updates.gd`.
- Content and interpreter: `test_plugin_schema.gd`, `test_plugin_text.gd`,
  `test_plugin_palette.gd`, `test_plugin_interpreter.gd`,
  `test_island_generator_golden.gd` (data `island_generator_golden.json`).
- The Refuge's behaviour: `test_refuge_*.gd`, `test_c26_X6_*.gd` and the UI
  tests that name it; the fixture plugin `tests/fixtures/adventure_plugins/tiny_isle/`.
- Both validators on one corpus: `tests/unit/test_plugin_corpus.gd`,
  `tools/test_adventure_plugin.py`.
- The authors' guide against the code and the prototype:
  `tools/test_adventure_guide.py`.
- `tools/expansion_lab.sh --plugin PATH` plays a plugin headless: travel,
  terrain, objectives, saves, its pack (or, needing none, itself) taken away
  mid-trip, and its land
  played to its end on the model's results (`tools/expansion_testing/lab_campaign.gd`:
  every quest, the rewards claimed, the finale, the save read back).
