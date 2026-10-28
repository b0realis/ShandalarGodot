class_name DungeonDoors
extends RefCounted
## THE DOORS OF THE CASTLES AND THE DUNGEONS (2026-10-27) — what 1.3 did
## to the WORLD as the hero went into a wizard's castle or a dungeon and as
## they came out of it: the first and the last steps of
## `RunCastleDungeonBoard` (dungeonEncounter.c 232–343 and 697–740; retail
## Palette.c 6346–6384, the same), after the castle's "Yes, enter the
## castle." (`VisitTownSlot`, visitLocation.c 4361–4396) or the dungeon's
## walk-in (adventure_input.c 888–899). The board itself — its rooms, their
## duels, the treasure, the castle's wizard — is part C's; this is its
## world side, headless, so the board plugs into it.
##
## THE DOOR. [method at] is the dungeon a step onto a tile would enter:
## 1997's four tests — the tile's DUNGEON flag, the first of the fifteen
## slots standing there (`FindCastleDungeonAtWorldCoordinates`), a clue
## known, a card still inside. [ours: 1997 slip A-s1 — 1997 tested the
## first of the three card places only; a slot's cards are a list here,
## any card left will do.] A castle is entered from its site ([method
## castle_of]). [QoL, the owner's ruling D-1 of 2026-10-27: a known dungeon
## walked to opens its pane — "Enter the dungeon" / "Leave" ([method
## VisitPane.describe], as any place the walk ends on) — where 1997 went
## straight down on the step; in 1997 an Escape at the board's door still
## spent an attempt and moved the dungeon.] The world screen also reads
## [method at] to name a known dungeon under the pointer on land not yet
## explored ([method WorldScreen.place_at]).
##
## GOING IN ([method enter]), in 1997's order:
##  - the journal: a dungeon "Explored %s" (`@LOGSTRINGS` 6, 1997's entry
##    type 3), a castle "Entered %1 (%2)" — "Entered Castle Necris (Black
##    Castle)" (`@LOGSTRINGS` 8, type 4; `@CITYNAME_MANACASTLE` names the
##    castle);
##  - the slot's ATTEMPTS one more: its `entered` count (1997's
##    `times_entered`, −1 for every slot as the world is made and raised
##    first thing on every board, before anything else, so a board left at
##    once still counts; kept per slot, so a dungeon moved keeps it; saved).
##    Ours stores the entries themselves — absent or 0 at the start, which
##    is 1997's −1 + 1, the number the stats screen showed under each
##    castle ("Attempts at Each Castle", adventureStats.c 943–949). The
##    board reads 1997's own value, `entered − 1` ([method enter]'s
##    `tries`): a room every `5 − min(tries + difficulty, 3)` steps
##    (dungeonEncounter.c 1765–1767);
##  - ROAMING SLOTS 0–4 EMPTIED [1997, the owner's ruling D-2]: the board's
##    five rooms borrow those slots' sprite work entries and leave each one
##    empty (dungeonEncounter.c 337) — every lair and creature in them gone
##    from the world, the quest's creature in slot 0 too; the world fills
##    them again as it runs ([WorldCreatures]). Slot 5 and the besieger's 7
##    stay.
## Not done here: 1997 reseeded its dice from the clock as the board began
## (`SeedRandomFromTickCount`, dungeonEncounter.c 244) [ours: the
## adventure keeps its dice]; the dungeon's life pool, the board's sprites,
## sounds and ground are the board's own (part C).
##
## COMING OUT ([method leave]; every way out of the board — its entrance
## reached, Escape, ejected, booted):
##  - THE NEXT DUEL'S GIFTS ARE KEPT [ours: 1997 slip — dungeonEncounter.c
##    713–715 set `g_next_duel_life_delta = 0` and `g_next_duel_card_id =
##    −1` on every way out, so a gift earned outside (a wise man's lives, a
##    card in play, the first move, the lives carried) was lost by walking
##    in and out; the owner's ruling D-4 of 2026-10-27];
##  - A DUNGEON MOVES (dungeonEncounter.c 722–740): the DUNGEON flag off
##    its tile; its clues `(clues & ~1) | 6` — where it lies forgotten, its
##    creatures and its rules known, so it is still drawn and entered
##    ([method WorldClues.on_world]) though the clues no longer say where;
##    a new tile drawn, `rand(64)` across and down, again until it is land
##    with no site and no road — [ours: 1997 slip D-s1 — and no other
##    dungeon and not the hero's tile: 1997 tested land and the site and
##    road flags only, so two dungeons could share a tile (the lower slot
##    alone shown and entered) or the dungeon land under the hero's feet] —
##    and the flag set there. A GUARD: no such tile left anywhere, it stays
##    where it was (1997 drew forever);
##  - A CASTLE LEFT UNBEATEN ON WIZARD — THE RETALIATION (visitLocation.c
##    4388–4395, retail town.c 3362–3367): after every castle run (Escape
##    at its door, booted after a lost room, its wizard's duel lost or
##    drawn), never on "Well... No.", never after the castle is won, on the
##    other difficulties never: the wizard sends a siege at once ([method
##    Sieges.start] with his colour, `TriggerWizardSiegeNewsflash`) — its
##    news handed back. Nothing while a siege is under way.
## The world screen shows the news after the save that follows the board
## (1997 saved after the news, with the same state).
##
## THE BOARD IS NOT MADE YET: [constant BOARD_READY] is false, so the two
## doors — the castle's "Yes, enter the castle." and the dungeon's "Enter
## the dungeon" — wait, disabled; the world screen's seam
## ([method WorldScreen._open_board]) and the tests stand a board in.
## The retaliation goes live with the board (the owner's ruling E-1: a
## siege for a castle that cannot be played would only punish).

## Whether part C's board exists: the doors open once it does.
const BOARD_READY := false
## Slots 0–4 are the wizards' castles (black, blue, green, red, white),
## 5–14 the dungeons ([member ShandalarWorld.encounters]).
const CASTLES := 5
const SLOTS := WorldClues.SLOTS
## The roaming slots the board's rooms empty ([constant WorldLairs.SLOTS]
## less slot 5).
const ROOMS: Array[int] = [0, 1, 2, 3, 4]
## Wizard, the difficulty that retaliates.
const RETALIATING := 3
## `@LOGSTRINGS` 6 and 8.
const EXPLORED := "Explored %s"
const ENTERED := "Entered %s (%s)"


## THE DUNGEON STANDING AT [param tile], as 1997's step onto it would enter
## it: its slot (5–14), or −1 — no DUNGEON flag there, no slot there (the
## generator's stray flag under each castle's first draw), the first slot
## there a castle, nothing known of it, or no card left in it.
static func at(world: ShandalarWorld, tile: Vector2i) -> int:
	if world == null or world.tile_flags(tile.x, tile.y) & ShandalarWorld.DUNGEON == 0:
		return -1
	for index in mini(world.encounters.size(), SLOTS):
		var slot: Dictionary = world.encounters[index]
		if int(slot.get("x", -1)) != tile.x or int(slot.get("y", -1)) != tile.y:
			continue
		# The first slot standing there is the one (1997's search).
		# A card put back in a full-bag swap keeps the dungeon open too.
		if index < CASTLES or int(slot.get("clues", 0)) == 0 or not WorldClues.holds_cards(slot):
			return -1
		return index
	return -1


## The castle of site [param site]: 0–4 (its wizard's colour − 1), or −1
## ([method WorldNames.castle_of_site]).
static func castle_of(world: ShandalarWorld, site: int) -> int:
	if world == null or site < 0 or site >= world.sites.size():
		return -1
	return WorldNames.castle_of_site(world, site)


## THE HERO GOES INTO castle or dungeon [param index] (0–14): the journal,
## the attempt counted, roaming slots 0–4 emptied (the class's notes). What
## the board is given: `{index, castle, color, tries}` — `castle` true for
## a wizard's castle, `color` the slot's (1 black … 5 white), `tries`
## 1997's `times_entered` as the board reads it (0 on the first entry). `{}`
## for no such slot.
static func enter(player: AdventurePlayer, index: int) -> Dictionary:
	var world := player.world if player != null else null
	if world == null or index < 0 or index >= mini(world.encounters.size(), SLOTS):
		return {}
	var slot: Dictionary = world.encounters[index]
	if index < CASTLES:
		player.log_event("castle", ENTERED % [WorldNames.dungeon_name(index), WorldNames.CASTLES[index]],
			{"slot": index})
	else:
		player.log_event("dungeon", EXPLORED % WorldNames.dungeon_name(index), {"slot": index})
	slot["entered"] = entered(world, index) + 1
	for room in ROOMS:
		WorldCreatures.empty(player, room)
	return {"index": index, "castle": index < CASTLES, "color": int(slot.get("color", 0)),
		"tries": int(slot["entered"]) - 1}


## How often castle or dungeon [param index] was entered (0 never; an old
## save that never counted reads 0).
static func entered(world: ShandalarWorld, index: int) -> int:
	if world == null or index < 0 or index >= world.encounters.size():
		return 0
	return maxi(int((world.encounters[index] as Dictionary).get("entered", 0)), 0)


## THE HERO COMES OUT OF castle or dungeon [param index] with the board's
## [param result], `{beaten, booted}` — `beaten` the castle's wizard or the
## dungeon's last room beaten, `booted` thrown out of a castle after a room
## lost (part C fills it; its words are part C's): the gifts kept, a dungeon
## moved, a castle left unbeaten on Wizard retaliated for (the class's
## notes). The news to show, `[{kind: "siege", …}]` ([method Sieges.start]),
## or `[]`.
static func leave(player: AdventurePlayer, index: int, result: Dictionary) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	var world := player.world if player != null else null
	if world == null or index < 0 or index >= mini(world.encounters.size(), SLOTS):
		return news
	if index >= CASTLES:
		move(player, index)
		return news
	if not bool(result.get("beaten", false)) and player.difficulty == RETALIATING \
			and not AdventurePlayer.COLORS[index] in player.defeated_wizards:
		news.append_array(Sieges.start(player, index + 1))
	return news


## DUNGEON [param index] MOVES as the hero comes out (the class's notes):
## its old tile loses the flag, its clues are `(clues & ~1) | 6`, a new
## tile is drawn on the adventure's dice. The tile it stands on now.
static func move(player: AdventurePlayer, index: int) -> Vector2i:
	var world := player.world
	var slot: Dictionary = world.encounters[index]
	var old := Vector2i(int(slot.get("x", 0)), int(slot.get("y", 0)))
	_put_flag(world, old, false)
	slot["clues"] = (int(slot.get("clues", 0)) & ~WorldClues.LOCATION) | WorldClues.CREATURES | WorldClues.RULES
	var hero := player.tile()
	var portal := FinalBattle.portal_tile_of(player)
	var dice := MsvcRandom.new(player.dice)
	var to := old
	var misses := 0
	while true:
		var x := dice.below(ShandalarWorld.TILES)
		var y := dice.below(ShandalarWorld.TILES)
		if takes_dungeon(world, Vector2i(x, y), hero, portal):
			to = Vector2i(x, y)
			break
		# GUARD: no tile left anywhere, and the original draws forever.
		misses += 1
		if misses == WorldGenerator.LOOK_EVERYWHERE_AFTER and not _place_left(world, hero, portal):
			break
	player.dice = dice.state
	slot["x"] = to.x
	slot["y"] = to.y
	_put_flag(world, to, true)
	return to


## Whether a moved dungeon may stand on [param tile]: land, no site, no
## road (1997's tests) — and [ours: 1997 slip D-s1] no other dungeon, not
## the hero's tile [param hero]; nor [ours, part C] Arzakon's portal's
## tile [param portal] ([method FinalBattle.portal_tile_of]; (−1, −1) for
## none).
static func takes_dungeon(world: ShandalarWorld, tile: Vector2i, hero: Vector2i,
		portal := Vector2i(-1, -1)) -> bool:
	if tile == hero or tile == portal or not world.is_land(tile.x, tile.y):
		return false
	var taken := ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON
	return world.tile_flags(tile.x, tile.y) & taken == 0


## Whether any tile could still take a moved dungeon.
static func _place_left(world: ShandalarWorld, hero: Vector2i, portal := Vector2i(-1, -1)) -> bool:
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if takes_dungeon(world, Vector2i(x, y), hero, portal):
				return true
	return false


## The DUNGEON flag of [param tile] set ([param on]) or cleared.
static func _put_flag(world: ShandalarWorld, tile: Vector2i, on: bool) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= ShandalarWorld.TILES or tile.y >= ShandalarWorld.TILES:
		return
	var at := tile.y * ShandalarWorld.PAGE_WIDTH + tile.x
	world.page[at] = (world.page[at] | ShandalarWorld.DUNGEON) if on else (world.page[at] & ~ShandalarWorld.DUNGEON)
