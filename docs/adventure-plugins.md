# Adventure plugins — the developer reference

Adventure plugins (0.60.19) are data-only packages that add an island to the
adventure, reached by ship from a mainland harbor; since API 2 (0.70.4) a
**sites plugin** adds places instead — a hut, a guild's tower — that stand
on the mainland and on the islands, and since API 3 (0.70.6) such a place
can talk, roll dice, take a card, amulets or food, give gifts, duel, trade
cards and put a row in the Tasks
([Sites plugins](#sites-plugins-api-2-and-api-3)).
This page is for whoever
works on the game's side of them: the loader, the interpreter, the saves and
the tools. Plugin **authors** have their own guide, shipped with the game:
[`expanded_adventure/GUIDE/index.html`](../expanded_adventure/GUIDE/index.html)
(local HTML, never published), whose Reference page and places cheat sheet
are generated from the schema by `tools/adventure_plugin.py guide`.

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
   the lands a campaign has, never a land themselves. **API 3** (0.70.6,
   the owner, 2026-11-22: *"make it easy to create new places that give
   additional context and users can make do various game mechanics"*) adds
   words to a sites plugin and nothing else: an island plugin, and every
   API 1 and API 2 plugin, reads as before.
8. **Shipping:** the desktop releases carry `expanded_adventure/`
   (`Fallen_Empires_Refuge_prototype.zip`, the six places' zips of
   `tools/package_release.py`'s `PLACES`, `README.txt`, `GUIDE/`) beside the
   game, and `tools/adventure_plugin.py` with its card lists. The guide holds
   no card art and no 1997 or skin picture.
9. **The prototype is a game-design and learning demo** (its manifest's
   `learning_note`, its README, the plugins window, the guide). The project
   adds no adventure content of its own — but for the two places the owner
   asked for on 2026-11-21 (*"No the project is a self contained new place!
   (As a study for other places the players wish)"*): **An Old Adventurer's
   Hut** and the **Conjuration Wizard Guild**, sites plugins shipped beside
   the Refuge, each a finished place and a study. With API 3 (0.70.6) four
   small **study places** ship beside them, each made with the authoring
   tool's commands alone to show one mechanic: The Gambler's Den, The
   Riddle Stone, The Wandering Collector and The Duelist's Ring
   ([the shipped places](#the-shipped-places)). Each is a plugin of its
   own, ticked or not at the Embark; unticked, it changes nothing.

## Where the code is

| File | Class | Job |
|---|---|---|
| `game/adventure/plugins/adventure_plugins.gd` | `AdventurePlugins` | The registry: folders, scan, the staged checks, rows, data, descriptors, pictures and music from bytes. |
| `game/adventure/plugins/plugin_package.gd` | `PluginPackage` | One package read into `{rel: bytes}`: the zip's central directory or the folder walk, paths, kinds, limits, picture headers, OGG, UTF-8, JSON depth. Since 0.70.6 every entry is read by that one checked list (`zip_entries`, `entry_bytes`, `engine_agrees`, `read_one`). |
| `game/adventure/plugins/schema_v1.json` | — | The content schema, API 1 to 3 (`api_version` 3): kinds, files, types, limits, placeholders, skin pictures, and `v3_words`, the words only an API 3 plugin may use. Read by `PluginSchema` and by the tool. |
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
| `game/adventure/expansions/adventure_sites.gd` | `AdventureSites` | API 2: the sites plugins on for a campaign, their places put on each land (`world.expansion.sites`), the places' markers, panes, buttons, pictures and sprites. API 3: `task_rows` and `targets`, the plugins' Tasks rows and map targets. |
| `game/adventure/plugins/data_sites.gd` | `DataSites` | API 2: a sites plugin's interpreter, model side — panes, conditions, effects, the prices, a copy, a dungeon raised. API 3: counters, needs, talk panes, the roll, a duel's stake and result, card trades, the Tasks rows. |
| `game/adventure/plugins/site_journey.gd` | `SiteJourney` | API 2: what a place's buttons do on the world screen (the copy's card list), reached from `DataSites` by `load()` only. API 3: a place's duel through `WorldDuels`, a trade's card list. |
| `tools/adventure_plugin.py` | — | `new` (`--kind sites` for places), `validate`, `export`, `info`, `compat`, `guide`, and for places `add-place` (with its ten `--recipe`s), `add-action`, `add-pane`, `add-flag`, `add-counter`, `add-foe`, `set-text`, `set-info`, `remove-place`, `add-dungeon`, `walk` (a place played as text, without the game) and `art` (advice on the pictures): the authoring tool and the Python twin of the checks. |

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
   holds `plugin.json`; and one list of files, whoever reads it
   ([the zip reader](#the-zip-reader-since-0706)). A folder: no symbolic
   link, ≤ 256 folders. Every
   path ≤ 200 characters, relative, `/` only, no `\`, `:`, NUL or control
   character, no empty, `.` or `..` part. Extensions `.json .txt .md .png
   .jpg .jpeg .webp .ogg` only. ≤ 512 files, ≤ 32 MiB in all; a JSON, `.txt`
   or `.md` ≤ 1 MiB and UTF-8; an OGG ≤ 16 MiB and Vorbis by its first page;
   a picture's header names its extension's kind and ≤ 4096 px a side
   (read from the header, nothing decoded). **Litter** is never read nor
   counted: a name beginning with `.`, a `__MACOSX` folder, `Thumbs.db`,
   `desktop.ini` (case ignored).

   <a id="the-zip-reader-since-0706"></a>**The zip reader, since 0.70.6.**
   A zip can be built so that two readers find two different lists of
   files in it — one list checked, the other unpacked. `zip_entries`
   therefore takes the file's **last** end record and refuses the zip when
   that record's comment does not reach the file's very end while an
   earlier whole record does ("NAME holds a second end record after its
   list of files; save it as a plain zip."), when a zip64 locator behind
   the list leads to a zip64 end record, when the record names another
   disk or two different counts, or when the directory holds anything but
   its rows ("NAME: a zip64 or damaged zip; save it as a plain zip.",
   "NAME is damaged (its list of files)."). Bytes after the zip, and an
   end record hidden in the zip's comment, fall under the same rules.
   Nothing is unpacked through another reader: `engine_agrees` asks the
   engine's own `ZIPReader` only for its names, which must be the checked
   list's in the same order, and `entry_bytes` then reads each entry by
   the checked list alone — into room of exactly the entry's listed size,
   so a deflate stream that holds more fails instead of growing; never an
   entry on another disk, encrypted, claiming more than deflate can pack
   (`MAX_RATIO`), lying outside the file's data, or whose **local header**
   (name, method, CRC-32, sizes — but for a streamed entry, which leaves
   those three for after its data) disagrees with its row of the directory;
   a deflated entry is held to the directory's CRC-32 as it is unpacked.
   An entry that fails
   reads "REL: could not be read whole." `read_one` (one file of a zip,
   for a caller that wants only that) goes the same way under a cap.
   `tests/unit/test_c1122_files.gd` builds each such zip — two end
   records, bytes after the zip, an end record in the comment, a zip64
   record behind the list, a local header naming another size — and
   counts that nothing of it was unpacked (`unpack_calls`,
   `unpack_bytes`); whole zips, stored or deflated, read as ever. The
   tool's own reader (`tools/adventure_plugin.py`) repeats these refusals
   with the same sentences (`ZipRefusals` in
   `tools/test_c1122_places_tool.py` rebuilds the same zips from bytes).
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

- `API_VERSION := 3` (2 until 0.70.6), `PLUGIN_FORMAT := 1`, `FOLDER_NAME`,
  `ID_PATTERN`; `KIND_ISLAND`, `KIND_SITES`, `SITES_API` (2: the least a
  sites plugin declares).
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
which adds the sites plugins' progress — API 3 keeps 9, its counters an
optional part of that progress) is the format that records the
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
  (a quest index or done count, a stage, waiting cards), a complete flag
  is on before every quest is done, or (since 0.70.5) a value that is no
  switch stands under a name the installed version declares one — an older
  version may have kept another value there. The land is **held**
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

**The tool, since 0.70.5.** For a sites plugin `compat` also warns, and
exits 1, when a save may find an action used up: a free action (other than
a `leave`) that gains prices — its free uses were counted too
(`DataSites._count`) — and a price list made shorter. A longer list, other
prices and an action made free stay notes (exit 0). `add-place`,
`add-dungeon` and every other edit write each file whole or not at all and
put every file back when the edit is stopped (a file that cannot be
written, a failed judgement, Ctrl-C); a read-only file is left alone.
`add-place` refuses an id whose picture key (`<plugin id>_<place id>`)
would pass 40 characters; `add-dungeon` writes the dungeon's own name into
its words, not `{dungeon}` (the last dungeon raised on the land); `walk`
plays a place that stands on the mainland and the islands once for each;
`export` writes and judges the new zip in a dotted folder of its own, so a
zip already in `--out` is replaced only by one the game takes; `art`
inflates a PNG no further than its header's own size.

## Music and pictures

`world.music` (an OGG of the plugin) plays while the hero walks the island
(`world_duels.gd`'s region music, `AdventureExpansions.music`); the
mainland's music everywhere else. A plugin's duels rest the region track
and the place's tune like every adventure duel (`WorldDuels.host`,
`WorldDuels.place_tune_off`): the duel's own music alone. Pictures are decoded on demand by key
(`AdventureExpansions.picture`: a plugin's `pictures` key, else the skin's)
and map sprites by `AdventureExpansions.map_op`: the picture's used rect,
`width` world pixels wide, its foot at (64, 24) of the 128 × 64 tile box.

Since 0.70.5 they are made before they are asked for where a worker may
decode (`SkinWarmer.runs_here`): `AdventurePlugins.warm(id)` reads, checks
(the scan's hash) and decodes a plugin's pictures on a worker — the world
screen asks it for the land the hero walks and every sites plugin switched
on (`WorldScreen._warm_the_plugins`) — and the main thread keeps what is
made for at most `WARM_BUDGET_US` a frame, where `texture` and `stream`
look first. A land's track not yet decoded is decoded the same way
(`warm(id, false, rel, then)`, from `WorldDuels._tune_awaited`): the land
is silent until it is kept. A warm-up decodes at most `MOST_WARM_BYTES` of
pixels; what it did not reach, and everything headless, is made on demand
as before. A picture's used rect is measured as it is decoded and carried
by the texture (`AdventurePlugins.USED_RECT`), so `map_op` reads nothing
back from the graphics card.

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
   use it. For a sites plugin this is checked, not only told: list the new
   word in the schema's `v3_words` (or the next API's list) and
   `PluginSchema._check_api` refuses it in a plugin that declares less
   ([the API 3 gate](#when-a-plugin-declares-api-3)).
5. **Tests and docs.** A case in `tests/unit/test_plugin_interpreter.gd` (it
   holds and does), a shape case in `tests/unit/test_plugin_schema.gd`, good
   and bad fixtures in `tools/plugin_fixtures/` with `expected.json`; then
   `python3 tools/adventure_plugin.py guide` to regenerate the guide's
   Reference page, and the tables in the guide's `quests.html` and in this
   page (`tools/test_adventure_guide.py` checks both lists against the
   schema).

## Sites plugins (API 2 and API 3)

The owner, 2026-11-21: *"Is it possible to add a new type of town or
interaction place as a plugin? For example one would supply an icon and
rules."* Then: *"this separate plugin can be placed on other islands or on
mainland if used"*; a dungeon it raises is *"separate from the main quest
and hold[s] from the list of plugin creator"*; and *"Yes saves work!"*.
And on 2026-11-22, for API 3: *"make it easy to create new places that
give additional context and users can make do various game mechanics"*.

**The manifest.** `kind: "sites"` with `api_version` 2 or newer; no
`region` (refused). Its content is `sites.json` and `text.json`
(`schema_v1.json`'s `site_files` and its `sites_` types); every other rule
of the manifest, the package and the files list is the island's.

### When a plugin declares API 3

API 3 (0.70.6) is API 2 with more words; nothing of API 2 changed its
meaning, and the two places of 0.70.4 still declare 2 and load untouched
(`test_the_shipped_version_2_plugins_load_untouched`). The new words are
listed in the schema's `v3_words`, by where they stand:

| Where | Words of API 3 |
|---|---|
| `sites.json`, top level | `counters`, `foes`, `tasks` |
| a pane | `id` |
| a line | `one_of` |
| an action's `do` | `talk`, `duel`, `buy_card`, `sell_card` |
| an action's fields | `needs`, `to`, `foe`, `win`, `lose`, `count`, `cards`, `stock` |
| conditions | `has_card`, `amulets`, `hero_color`, `owns_magic`, `food_at_least`, `gold_below`, `day_at_least`, `wizards_defeated`, `at_peace`, `difficulty`, `plugin_on`, `counter`, `site_used`, `gift_waiting`, `any` |
| effects | `counter`, `amulet`, `give_card`, `next_duel`, `roll`, `reveal_map` |

**A plugin that uses one of them must declare `"api_version": 3`.**
`PluginSchema._check_api` refuses one that declares less, once per word and
by name:

- "PATH: "WORD" is a word of plugin API 3, and plugin.json declares
  api_version N. Set "api_version": 3 there (the plugin then needs a game
  that reads API 3)."

The reason is the older game. A game that reads only API 2 (0.70.4,
0.70.5) meets an API 3 plugin at the manifest stage, before any content is
read, and refuses it whole with the rule it always had: "This plugin needs
plugin API 3; this game reads API 2. A newer game is needed." The plugin is
a greyed row of the plugins window, the campaign plays on without it, and
a save that used it opens as with any missing sites plugin. Were the same
words allowed under `api_version` 2, that older game would refuse the file
for a word it does not know, or skip it. The tool's edit commands set the
number by themselves the moment a command adds such a word, and say so;
`info` lists a plugin's API 3 words (`api_3_words`). A plugin that asks
for an API newer than the game's (4 today) is refused the same way.

### `sites.json`

`salt`, `flags` (≤ 32, declared, all off at the start), `pictures` (keys
beginning with the plugin's id), `dungeons` (≤ 8, by key: `name`, `color`
or `random`, `size`, `rules`, 1–6 `cards` of the base game or a required
pack, `distance` from the place in tiles) and `sites` (by key, 1–8):
`name`, `where` (`mainland`, `islands`), `picture`, `sprite`, `gap`, and
1–8 `panes` — each with `when`, `title`, `subtitle`, `picture`, up to 16
`lines` and up to 8 `actions`. An action has an `id` (its uses are counted
by it, the same id the same action in every pane), `do`, a `label`,
`when`, `prices`, `effects`, `result` (the lines after it is done) and,
for a card list, `pick_title` and `pick_line`. API 3 adds three top-level
maps:

| Word | Shape | Limits |
|---|---|---|
| `counters` | `["wins"]` | ≤ 32 names, no duplicates; each a whole number 0–1000 (`DataSites.MOST_USES`), 0 at the start of a campaign |
| `foes` | `{"champion": {name, deck_name?, life, face, deck}}` — API 1's `foe` type | ≤ 8; a deck of 1–250 cards as `{card: copies}`; `face` a creature row; never scaled to the hero |
| `tasks` | `{"key": {"title", "text", "done"?, "at"?, "when": [], "done_when": []}}` | ≤ 8; `at` is `place:<site>` or `dungeon:<key>` of this plugin |

**Which pane is shown** (`DataSites.pane_of`): the first pane **without
an `id`** whose `when` holds. A pane with an `id` (API 3, unique in its
site) is never chosen by itself; a `talk` action opens it. Since 0.70.6
the checker makes sure a place can always be entered and left — before, a
place whose every pane had a `when` showed an empty pane with no button,
and only Escape left it:

- "AT.panes: every pane has an id, so none opens by itself; the place
  needs a pane without an id to open on."
- "AT.panes[N].when: the last pane without an id must have no when, so
  the place always has a pane to show; add one more pane without a when
  after it."
- "AT.actions: a pane needs an action that does "leave" and has no when,
  so the hero can always walk away." (every pane, named or not)

**Lines.** A text key, `{"text": key, "when": [...]}`, or (API 3)
`{"one_of": [keys], "by": "day" | "uses", "when": [...]}`: one of 2–16
texts in turn — the next one each day of the journey (`by` defaults to
`day`), or each time an action of the place is done (`uses`:
`DataSites.site_uses`, the place's uses together). No dice are cast, so
the line is the same after a reload.

### Prices, needs and refusals

**Prices.** The n-th use of an action costs its n-th price (≤ 16 prices,
each 0–1,000,000); once every price is paid the action is gone from its
pane. An action without prices is free and never used up; a price of 0 is
a free use that still counts.

**Needs** (API 3, `needs`, ≤ 4 an action; on `effects`, `talk`,
`copy_card` and `duel`, never on a `leave` or a trade): what the action
takes besides gold, each time, all of it.

| Need | Shape | Taken |
|---|---|---|
| `card` | `{"card": "Ornithopter"}` | one copy: one in no deck first, else the one in the fewest decks, which it leaves (`DataSites.take_card`) |
| `amulets` | `{"amulets": {"color": "any", "count": 3}}` | 1–99 of a color; of `any` (the default) one at a time from the color the hero has most of, black first among equals |
| `food` | `{"food": 5}` | 1–1000 |

**Every refusal comes before anything is paid** (`DataSites.refusal`,
asked by the pane for each button — a button that would be refused shows
not ready — and again at the press). A press that cannot be done pays
nothing, counts nothing and says why:

| Sentence | When |
|---|---|
| `site.no_gold` | the price is more than the hero carries |
| `site.needs_card`, `site.needs_amulets`, `site.needs_any_amulets`, `site.needs_food` | a need is not met |
| `site.bag_full` | a copy, a `give_card` or a bought card has no room in the bag — a duel's `win` and `lose` gifts are checked for room before the stake is taken |
| `site.card_limit` | the campaign's card rules allow no more copies of a card given or bought (`CardShop.classic_allows`) |
| `site.gift_waiting` | a `next_duel` gift while one already waits |
| `site.no_cards` | no card may be copied |
| `site.no_room` | no slot or tile for a dungeon to raise |
| `site.dungeon_open` | a priced action whose dungeon is already open on this land (0.70.6: the price used to be taken for nothing) |
| `site.no_stock`, `site.nothing_to_sell` | a trade with nothing to trade now |

A duel is also refused while the hero has no deck to fight with
(`DataSites.deck_problem`, as `DataRegion.deck_problem`).

### Conditions and effects

The closed sets:
<!-- site_conditions -->conditions `flag`, `not_flag`, `gold_at_least`, `on_mainland`, `used`, `used_up`, `dungeon`, `has_card`, `amulets`, `hero_color`, `owns_magic`, `food_at_least`, `gold_below`, `day_at_least`, `wizards_defeated`, `at_peace`, `difficulty`, `plugin_on`, `counter`, `site_used`, `gift_waiting`, `any`<!-- /site_conditions -->
and
<!-- site_effects -->effects `set_flag`, `clear_flag`, `gold`, `food`, `log_clue`, `log_event`, `spawn_dungeon`, `counter`, `amulet`, `give_card`, `next_duel`, `roll`, `reveal_map`<!-- /site_effects -->.
The first seven conditions and the first seven effects are API 2's. A
`when` is a list of at most 16 conditions, all of which must hold; it may
stand on a pane, a line, an action, a result line and a task.

The conditions of API 3 (`DataSites._holds`):

| Condition | Shape | Holds when; limits |
|---|---|---|
| `has_card` | `{"card", "min": 1}` | the hero holds at least `min` (1–99) copies, in a deck or not |
| `amulets` | `{"color": "red" … "any", "min": 1}` | at least `min` (0–99) amulets of the color; `any` (the default): all colors together |
| `hero_color` | `"red"` | the color chosen at the start; the five colors |
| `owns_magic` | `"Dwarven Pick"` | the hero owns this World Magic; one of the twelve |
| `food_at_least` | int | 0–100,000 |
| `gold_below` | int | 1–1,000,000; the hero carries less |
| `day_at_least` | int | 0–100,000; the journey's day (`DataSites.day`, from 0) |
| `wizards_defeated` | int | 0–5; at least that many |
| `at_peace` | bool | Arzakon is banished and the hero walks on |
| `difficulty` | `{"min": 0, "max": 3}` | 0–3, `min` ≤ `max` |
| `plugin_on` | `"id"` | that plugin, sites or island, is part of the campaign and enabled; a plugin not installed is simply not on |
| `counter` | `{"name", "min": 0, "max": 1000}` | the counter, declared in `counters`, is within the range; `min` ≤ `max` |
| `site_used` | `{"site", "action", "min": 1, "max": 1000}` | another place's action was done that often; both must exist |
| `gift_waiting` | bool | a gift for the next duel already waits |
| `any` | `[condition, …]` | at least one of 1–8 holds; no `any` inside an `any` |

The effects of API 3 (`DataSites.apply`, `effects_now`); an action's
effects run in order, at most 16, once it is paid:

| Effect | Shape | Does; limits |
|---|---|---|
| `counter` | `{"name", "add": n}` or `{"name", "set": n}` | exactly one of the two; `add` ±1000, `set` 0–1000; the counter stays within 0–1000 |
| `amulet` | `{"color", "count": 1}` | the five colors; −9…9, not 0; the hero never carries fewer than 0 or more than 99 of one (`MOST_AMULETS`) |
| `give_card` | `"Card"` | one copy into the bag |
| `next_duel` | `{"life": 5}`, `{"first_move": true}` or `{"card": "X"}` | exactly one; life 1–20; the gift the lairs give, spent by the next duel of any kind |
| `roll` | `{"outcomes": [{"weight": 1, "effects": [], "result": []}, …]}` | 2–6 outcomes, each weight 1–100: one is drawn, its effects applied and its lines shown after the action's |
| `reveal_map` | `{"around": "place" \| "dungeon:<key>", "radius": 4}` | radius 1–8; nothing while the dungeon is not raised |

`log_event` (API 2) changed with 0.70.6: the event is written as
`"<plugin id>:<event>"` (`DataSites.apply`). Before, a plugin's own word
went into the journal as it stood, and one named `duel`, `quest`, `saved`,
`freed` or `treasure` was read as one of the game's own — a free button
could count lost duels, quests or treasures on the hero's page. Lines
written by an older game still display.

### The anti-exploit rules

- **A gift needs a price or a need.** An action that gives a card
  (`give_card`) or amulets (`amulet` with a count above 0) must have
  `prices` or `needs`, or the plugin is refused
  (`PluginSchema._check_site_effects`' `priced`): a list of prices ends,
  and a need must be found again each time. Gold given without either
  loads; `validate` warns of it.
- **Refusals before paying**, as above: nothing is ever taken for an
  effect that then cannot be had.
- **A roll is on the plugin's own dice** (`DataSites.rolled`,
  `AdventureSites.dice_for` with the plugin's salt and the key
  `"<uses>:roll:<plugin>:<site>:<action>"`): the adventure's dice are never
  cast, and the same save rolls the same again — reloading does not change
  a throw. The use count stands first in the key: last, consecutive throws
  came out in runs. One roll an action; none inside a roll's outcome or a
  duel's `win` or `lose`. `walk` prints each outcome with its chance and
  the gold a throw brings on average, and `validate` warns when that is
  more than the cheapest price.
- **A trade's price has a floor and a cap** (below).
- **A duel's stake is paid first** (below).

### Actions

| `do` | Fields | Does |
|---|---|---|
| `effects` | `prices`, `needs`, `effects`, `result` | pays, counts the use, applies the effects, shows the result (none: the place's pane again) |
| `copy_card` | `prices`, `needs`, `pick_title`, `pick_line`, `result` | the hero picks a card they hold; a copy goes into the bag |
| `leave` | — | closes the pane; never counted |
| `talk` (API 3) | `to`, and optionally `prices`, `needs`, `effects` | opens the pane of this place whose `id` is `to` (it must exist); no `result` |
| `duel` (API 3) | `foe`, `prices`, `needs`, `win`, `lose`, `count` | pays the stake and fights the plugin's foe |
| `buy_card`, `sell_card` (API 3) | `cards`, `stock`, `pick_title`, `pick_line`, `result` | trades one card for gold; no `prices`, no `needs` |

Each kind carries only its own fields (`_check_site_action`): effects on
a `leave` read "only an action that does effects or talk has effects."
The default buttons are `site.pay`, `site.leave`, and for the new kinds
`site.talk`, `site.duel`, `site.buy`, `site.sell` (`DataSites.LABELS`); an
action that needs a card wears `site.give`.

**Talk.** A talk without prices, needs or effects only turns the page:
nothing is paid, counted or saved (`DataSites.plain_talk`). With any of
them it is a service like `effects`, done before its pane opens. A riddle
is three talk buttons and two panes with an `id`; a wrong answer adds to a
counter.

**A duel** (`SiteJourney._duel`, `DataSites.duel_begin`, `duel_end`). The
next price is the **stake**. In order: the refusals; the stake and the
needs paid, and the press counted unless `count` is `win` (`count`
defaults to `press`; the price is paid each time either way); **the world
saved**; then the duel dealt by the adventure's own duel host
(`WorldDuels.host`) against the foe as written
(`PluginJourney.foe_config`, split out of `duel_config`: an island's quest
and a place's duel build the same). No ante is staked. Afterwards `win`
or `lose` — a draw is a loss — gives its effects and its `result` lines
(none: `site.duel_won`, `site.duel_lost`), the result is written in the
journal as the event `<plugin>:duel`, never in the hero's duel record, and
the world is saved again.

- *A duel closed mid-way is a loss with the stake paid.* Nothing is saved
  under a duel, so leaving for the main menu (the question is
  `site.duel_leave_question`) or closing the window resumes the adventure
  as it was saved just before the deal: the stake gone, the press counted,
  no result. Never a free second try, never a prize had twice.
- *A place's duel casts the adventure's dice once.* The hero's deck goes
  through `CreatureMeeting.padded_deck`, as before every creature meeting
  and every island duel, and that pads on the adventure's own dice. It is
  the one place a sites plugin touches them, it happens only when the
  player presses the duel's button, and a campaign in which nobody does is
  draw for draw the campaign it was.

**Card trades** (`DataSites.buyable`, `sellable`, `buy_card`, `sell_card`;
the card list is the world screen's, its numbers the prices): `cards` is
≤ 32 cards, each with a price of 0–1,000,000; `stock` (1–1000) is how
many of each card are traded in a campaign, absent: without end. A place
is no way to mint gold: a card is **sold to the hero for no less**, and
**bought from the hero for no more**, than the most a town pays for it —
charged `max(listed, town)`, paid `min(listed, town)`, the town's price
`CardShop.sell_range(card).y` (`DataSites.town_price`) — so nothing bought
in one place and sold in the other makes gold. A purchase is refused for a
full bag, the card rules' copy limit or too little gold; only cards the
hero holds are bought from them, one in no deck first. The tool has no
card values and trades at the prices written.

**Tasks** (`DataSites.task_rows`, `AdventureSites.task_rows` and `targets`,
hooked into `AdventureTasks` and `WorldStatus.targets`): each entry of
`tasks` whose `when` holds is a row of the Tasks pane on the land the hero
walks, with the map's arrow to its `at` — a place's tile, or a dungeon's
once raised. It is done, and no longer a target, once `done_when` holds;
an empty `done_when` is never done. A task `at` a place shows only on a
land where the place stands, and only there may its conditions use `used`
and `used_up` (they read that place; elsewhere use `site_used`). The Tasks'
cache key takes in `player.sites` and the rows as they read now, since a
task's conditions may ask the gold, the cards or the day.

### Placeholders and words

API 2 brought `{price}`, `{uses_left}`, `{gold}`, `{card}` and
`{dungeon}`; API 3 adds `{food}`, `{amulets}` (all colors together) and
`{day}`, and fills four more (`DataSites.values`):

- `{count}`: the counter the action changes or its `when` asks about, in
  a line the one that line asks about, else the pane's, else the plugin's
  first (`counter_about`).
- `{foe}`, `{life}`: a duel action's opponent.
- `{card}`: the card an action needs, else the one it gives
  (`card_about`); after a copy or a trade, that card.
- `{dungeon}`: **bound since 0.70.6** to the action's own dungeon — the
  first its effects may raise, else the one its `when` asks about — then
  the pane's, then the plugin's first (`dungeon_about`, `dungeon_word`).
  It used to be the last dungeon raised on the land, and the bare word
  `{dungeon}` before any was; now it is the plugin's name for the dungeon
  before it is raised and the land's once it is.

The engine's own sentences, each replaced by a key of the same name in the
plugin's `text.json` (`PluginText.DEFAULTS`); the twelve of API 2 are
`site.leave`, `site.back`, `site.pay`, `site.pick_title`, `site.pick_line`,
`site.no_gold`, `site.bag_full`, `site.no_cards`, `site.no_room`,
`site.done`, `site.copied`, `site.copied_log`. New with 0.70.6:

| Key | Default |
|---|---|
| `site.dungeon_open` | {dungeon} still waits for you; there is nothing new to tell. |
| `site.talk` | Ask |
| `site.give` | Give {card} (it leaves your decks) |
| `site.needs_card` | You need {card} for this; you hold none. |
| `site.needs_amulets` | You need {count} {color} amulets for this. |
| `site.needs_any_amulets` | You need {count} amulets for this; you carry {amulets}. |
| `site.needs_food` | You need {count} food for this; you carry {food}. |
| `site.card_limit` | You may hold no more copies of {card}. |
| `site.gift_waiting` | A gift for your next duel already waits; fight that duel first. |
| `site.duel` | Duel {foe} |
| `site.duel_won`, `site.duel_lost` | You have defeated {foe}. / {foe} has defeated you. |
| `site.duel_won_log`, `site.duel_lost_log` | Defeated {foe}. / Lost to {foe}. |
| `site.duel_leave_question` | Return to the main menu? This unfinished duel is not saved. Your adventure resumes with the stake paid. |
| `site.buy`, `site.sell` | Buy a card / Sell a card |
| `site.buy_title`, `site.sell_title` | Buy a card / Sell a card |
| `site.buy_line` | The number beside each card is its price in gold. |
| `site.sell_line` | The number beside each card is the gold paid for it. |
| `site.no_stock` | Nothing here is for sale to you now. |
| `site.nothing_to_sell` | You hold no card that is wanted here. |
| `site.bought`, `site.sold` | {card} is yours for {price} gold. / You sell {card} for {price} gold. |
| `site.bought_log`, `site.sold_log` | {card} bought for {price} gold. / {card} sold for {price} gold. |

### On the land

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

A place never lands under the hero, under Arzakon's portal or on a lair
(0.70.5): `AdventureSites.blocked_tiles(player)` names those tiles — they
carry no flag on the page — and `spot` passes over them (its `blocked`).
It matters for a place put on a land later than its first day (a plugin's
new version with one more place, a card pack switched on again); a new
campaign has none of them on a tile `spot` would draw from, so its draws
are unchanged. A caller that asks `DungeonDoors.takes_dungeon` or
`expansion_place` of many tiles reads the land's kept tiles once,
`DungeonDoors.kept_points(world)` (a set `{tile: true}`, good for as long
as nothing is placed or moved), and hands it in as `kept`; none given, it
is read at each asking, the answer the same.

**On the map and in the panes.** A place is a marker `<plugin>:<site>` of
`AdventureExpansions.places` (drawn by `map_op` from its `sprite`, listed
on the map and the minimap once its tile is explored, as a town is:
`WorldMinimap.place_shown`); its pane's kind is `site` (it pushes the
creatures back as a town does). Its buttons are `<plugin>_act:<site>:<action>`,
`<plugin>_back:<site>` and `<plugin>_leave`; `AdventureExpansions.act`
hands the longest owner of a button its press. Every kind of action — a
service, a copy, a talk, a duel, a trade — is an `_act` button.

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
slot, no tile) pays nothing, and since 0.70.6 neither does a priced
action whose dungeon is still open (`site.dungeon_open`).

Since 0.70.5 a raised slot says whose it is: `spawn` writes
`WorldClues.RAISED` (`"raised": "<plugin>:<dungeon key>"`) into the slot,
and it is saved with it. `DataSites.dungeon_index` believes the plugin's
record of its dungeon only of a slot that carries that mark — never a
castle's slot (0–4), a 1997 dungeon's or another dungeon's — so a damaged
record cannot read "open" and take the price for a dungeon never raised. A
0.70.4 save's unmarked vault is found where only a raised dungeon stands
(past 1997's fifteen on the mainland; on an island past the castles' slots
and under the name the dungeon was given) and marked from then on. A
raised dungeon also **keeps its location as it moves** (`DungeonDoors.move`,
`WorldClues.raised`): the hints that tell a location again walk only
1997's fifteen slots, so past them it would be forgotten for good and its
Tasks row lost; its `town` becomes the one nearest its new tile. 1997's
slots forget their location as ever, and the move draws the same dice.

**A copy** (`DataSites.copy_card`): one more of a card the hero holds
(`DataSites.copyable`: under the Classic MTG rules none they hold every
copy of, the wise man's rule), into the bag (`AdventurePlayer.add_card`).

### Progress and saves

`AdventurePlayer.sites`, by plugin id: `{uses: {"<site>.<action>": n},
flags: [names], dungeons: {"<land>:<dungeon>": slot}}` and, since API 3,
an optional `counters: {name: n}` — the uses the plugin's as a whole (the
Guild's towers on two lands share one count). **Save version 9** writes it
as `sites` and a sites plugin's row of `hero.adventures` with `kind:
"sites"`; a save from before reads none, and every row an island's.

**API 3 keeps the format at 9.** What it adds are optional parts of that
record:

- `counters` is written only when the plugin counted anything: a record
  without it is the record it was
  (`test_the_counters_are_saved_in_format_9_and_an_empty_record_is_as_before`).
  The save's cleaner (`AdventurePlayer._cleaned_sites`) keeps names up to
  40 characters and whole counts 0–1000.
- **Per-land use keys.** One kind of action is counted on each land by
  itself, under `"<site>.<action>@<land>"`: an action with prices that
  may raise a dungeon (`DataSites.per_land`), since each land has its own
  dungeon to sell. Before 0.70.6 a place standing on the mainland and on
  the islands sold its once-paid dungeon once for all of them: paid on
  the mainland, its button was gone on every island, whose pane still
  made the offer. A plain count kept by an older game is read for each
  land whose `dungeons` record holds that dungeon, so nothing is sold
  twice on a land that has it. The cleaner keeps `uses` keys up to 120
  characters (80 before).
- **A trade's stock** is counted in `uses` too, under
  `"<site>.<action>#<hash>"`, the hash eight hex digits of the card's
  name (`AdventureSites.fnv`).

A sites plugin missing or refused: its places hide (their tiles kept), its
progress is kept, counters and all, a dungeon it raised stays an ordinary
dungeon, and the save opens; it never has a ship or a mainland note
(`AdventureExpansions.sites_row`), and its Tasks rows are gone with it.
An API 3 plugin under a game that reads only API 2 is such a refused
plugin.

**Updates.** Saves know a plugin by its id, a place by its key, an action
by its id, a dungeon by its key and a counter by its name. `compat` (below)
names what a new version would lose.

### The tool for places

`tools/adventure_plugin.py` (`-V` prints the game's version and "adventure
plugin API 3"). No JSON file needs opening: each edit command writes what
it adds, judges the whole plugin as the game will, changes nothing when
the result would be refused, and says which command comes next.

| Command | Does |
|---|---|
| `new --kind sites` | a sites plugin that loads and plays; names the next commands, a path with a space quoted |
| `add-place` | a place: `--recipe` (below), or `--service effects \| copy \| none` with `--prices` or `--free` (a button that costs nothing and is never used up); `--where`, `--look shrine \| tent \| stone \| gate \| ring` (the stand-in pictures), `--list-recipes` |
| `add-action` | a button: `--do effects \| talk \| duel \| copy \| buy \| sell \| leave`, `--prices` or `--free`, any number of `--effect K=V`, `--needs K=V` and `--when K=V` (`"A \| B"`: one of them), 2–6 `--outcome "WEIGHT \| EFFECTS \| WORDS"` for a roll, `--label` and `--result` as plain words, `--pane` (a number, a pane's id, or `all`), `--to`, `--foe`, `--win`, `--lose`, `--win-effect`, `--lose-effect`, `--count`, `--cards "NAME=PRICE; …"`, `--stock` |
| `add-pane` | a pane with an `--id` (a talk opens it) or a `--when`, its `--line`s, `--title`, `--subtitle` |
| `add-flag`, `add-counter` | declare a name |
| `add-foe` | an opponent from a text file, one card a line (`4 Lightning Bolt`): `--name`, `--life`, `--face`, `--deck-name`, `--replace` |
| `set-text`, `set-info` | one sentence of `text.json`; `plugin.json`'s name, description, license, authors, version |
| `remove-place` | a place out again, with its words, its pictures and whatever only it used |
| `add-dungeon` | a dungeon recipe, and with `--place` its button and panes; at a place that already has a service both now stay reachable |
| `walk` | the places played as text, without the game |
| `art`, `validate`, `info`, `export`, `compat` | as before, knowing API 3 |
| `guide` | writes `GUIDE/reference.html` and `GUIDE/cheatsheet.html` from the schema; `--check` exits 1 when either is stale |

**Recipes** (`add-place --recipe`, `place_recipe`): a whole place that
validates, walks and exports as written, its sentences plain ones to
rewrite. `--card` names the card of a gift, collector, quest or shop;
`--color` the color that passes a toll free.

| Recipe | Makes | Built from |
|---|---|---|
| `lore` | a rumor that changes by the day, and a tale behind a talk button | `one_of`, `talk`, a pane with an `id`, a flag, `log_clue` |
| `gift` | a gift given once: food and an amulet, or a card | `"prices": [0]`, `food` and `amulet`, or `give_card` |
| `healer` | a blessing for the next duel behind three prices, and food for gold | `next_duel`, `gift_waiting`, `gold`, `food` |
| `toll` | a gate that opens for gold, for an amulet, or for a hero of one color | `hero_color`, `amulets`, `day_at_least`, `needs`, a flag, `reveal_map` |
| `gambler` | five throws of the dice at 50 gold | `roll` behind a list of prices, a counter |
| `riddle` | a riddle with three answers | three `talk` buttons, two panes with an `id`, a counter, a flag, `gold` |
| `collector` | someone who pays for each copy of a card handed over | `has_card`, `needs`, `"prices": [0, 0, 0]`, a counter |
| `duelist` | a duel for a wager against the place's own champion | `duel`, a foe with a deck, `win` and `lose`, a counter |
| `shop` | a stall that sells a few cards and buys one | `buy_card` with `stock`, `sell_card` |
| `quest` | an errand: accept it, bring a card, be paid | `talk`, two flags, `has_card`, `needs`, `log_event`, a task |

**`walk`** follows the game's rules for panes, conditions, prices, needs
and effects (held to `data_sites.gd` by a drift test). Its hero can be
told what to carry and do: `--gold`, `--food`, `--cards`, `--amulets
COLOR=N`, `--color`, `--magic`, `--day`, `--wizards`, `--peace`,
`--difficulty`, `--plugin ID`, `--gift`, `--flag`, `--counter NAME=N`;
`--press a,b,c` presses exactly those buttons of one `--site` (`leave`
steps out and in again, `clear` clears the open dungeon); `--land` walks
one land and `--both` sends one hero over the mainland and then an island,
keeping gold, flags, uses and counters; `--win` and `--lose` end every
duel that way (a walk fights none; by default a free duel is won, then
lost); `--roll N` takes every roll's N-th outcome (default: the
likeliest). At its end it lists what it **never reached** — a pane never
shown, a button never pressed — with what stood in the way and the option
that opens it.

**`validate`** refuses what the game refuses, in the game's words, and
beside that **warns** — a warning never refuses — of what loads but is not
finished or would surprise a player: the tool's stand-in sentences,
license, description and pictures still in place; a flag, counter, text,
picture, foe or dungeon nothing uses; a placeholder where it is not
filled; `{price}` or `{uses_left}` in a free action's label; a pane too
long to fit (it does not scroll); a pane that can never be shown or that
no talk opens; a button that gives gold without end; a roll that pays
more than it costs; and, in a plugin that declares API 2, a once-paid
dungeon at a place on the mainland and the islands (a game from before
API 3 counts it once for all lands). A sentence where a text key belongs,
a mistyped key or a mistyped card gets its nearest names.

**`compat`** also knows API 3: a counter renamed or removed is a change
that loses saved progress (exit 1); a trade's stock made smaller, and a
priced action at a both-lands place that now raises a dungeon (its uses
counted on each land from now on), are notes (exit 0).

The cheat sheet (`expanded_adventure/GUIDE/cheatsheet.html`) gives every
word on one page, each with its JSON and the command that writes it; it
and the guide's `sites.html` are held to the schema, the tool and the
study plugins by `tools/test_c1122_places_tool.py` and
`tools/test_adventure_guide.py`.

### The shipped places

Six sites plugins ship in `expanded_adventure/`, each zipped by the
release tooling (`tools/package_release.py`'s `PLACES`), each a plugin of
its own to tick at the Embark, none needing a card pack. Unticked, a
place changes nothing: a campaign without it is the vanilla campaign.

The two of 0.70.4 declare API 2. `Old_Adventurers_Hut/` (id `old_hut`): on
the mainland; 1000 gold, once, raise *The Forgotten Vault* (large, its
color drawn, 8–22 tiles away) holding Old Man of the Sea, Planar Gate and
Mirror Universe; three panes by the vault's state.
`Conjuration_Wizard_Guild/` (id `conjuration_guild`): on the mainland and
every island; a copy for 2000, 4000, 8000 and 12000 gold, then no more.

The four **study places** of 0.70.6 declare API 3 and stand on the
mainland. Each shows one mechanic, and each was written by the tool's
commands alone — its `README.txt` lists them, and
`test_each_readmes_commands_make_the_plugin_again` runs them and compares
the three JSON files they write with the shipped ones:

| Folder (id) | The place | A study of |
|---|---|---|
| `Gamblers_Den/` (`gamblers_den`) | *The Gambler's Den*: Odo Three-Fingers throws bone dice, five throws at 50 gold, and a high table after three | `roll` on the plugin's dice, a counter of throws, a talk pane |
| `Riddle_Stone/` (`riddle_stone`) | *The Riddle Stone*: one riddle, three answers, a hint after two wrong ones, 100 gold for the right one | `talk` panes, a counter, a flag |
| `Wandering_Collector/` (`wandering_collector`) | *The Wandering Collector*: 150 gold for each Ornithopter handed over, three in all, then a parting gift | `has_card`, a `needs` of a card, a counter |
| `Duelists_Ring/` (`duelists_ring`) | *The Duelist's Ring*: Marda Ironhand duels for a wager of 50 gold; beaten twice, the Ringmaster steps in | `duel`, two foes (their decks beside as plain lists), a counter of wins |

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
- Places, API 3 (0.70.6): `tests/unit/test_c1122_places.gd` — the API
  gate and an unknown API, the way in and out of a place, what a word
  names, every new condition, gifts and their refusals before paying,
  needs, the map uncovered, the event's own name, `{dungeon}`, the open
  dungeon not paid for, a dungeon sold on each land and an older save's
  count, talk, `one_of`, the roll the same after a reload, the duel's
  stake and its single prize, the trade's floor and cap, a task and its
  map target, the counters in format 9 (fixture plugin
  `tests/support/c1122_places_fixture.gd`);
  `tests/ui/test_c1122_places_ui.gd` — a talk, a roll, a duel and a
  purchase through the real visit pane, a refused duel that deals none;
  `tests/unit/test_c1122_ptool.gd` — the four study places read by the
  loader as they lie, placed on a mainland and played;
  `tools/test_c1122_places_tool.py` — the tool's side: the corpus's API 3
  cases, the hints and warnings, the edit commands, the ten recipes, the
  walk's options, `info` and `compat`, the cheat sheet, the guide's page,
  the study plugins made again from their READMEs.
- The zip reader (0.70.6): `tests/unit/test_c1122_files.gd` — the zips of
  two lists, refused before anything is unpacked.
- The review of 2026-11-21: `tests/unit/test_review_2026_11_21_sites.gd`
  (a raised dungeon's location and mark, the kept and the blocked tiles),
  `Review20261121Test` in `tools/test_adventure_plugin.py` (the tool).
- Both validators on one corpus: `tests/unit/test_plugin_corpus.gd`,
  `tools/test_adventure_plugin.py`.
- The authors' guide against the code and the prototype:
  `tools/test_adventure_guide.py`.
- `tools/expansion_lab.sh --plugin PATH` plays a plugin headless: travel,
  terrain, objectives, saves, its pack (or, needing none, itself) taken away
  mid-trip, and its land
  played to its end on the model's results (`tools/expansion_testing/lab_campaign.gd`:
  every quest, the rewards claimed, the finale, the save read back).
