class_name Sieges
extends RefCounted
## THE WIZARDS' SIEGES, THEIR MANA TAPS AND THE SPELL OF DOMINION (part B,
## 2026-10-23) — 1.3's siege clock (adventure_input.c 621–650),
## `StartWizardTownSiege` (world_lair_monster_slots.c 972–1121; retail
## glue_adventure.c ~1870 agrees), `ResolveWizardTownSiege` (1125–1263) and
## the besieger's meeting's end (941–958), in the words of `@NEWSFLASH` and
## `@QUESTFAILED`.
##
## THE CLOCK ([member AdventurePlayer.siege_timer], `T`) steps on every 32
## ticks the hero walks ([HeroWalk], which calls [method on_step] right
## after it does). Then:
##  - at `T & 63 == 0` a siege BEGINS ([method start]) and the clock jumps
##    `clamp(d + T / 256, 0, 16)` — the jump taken even when no siege began
##    because one is already under way;
##  - at `T & 63 == 24` it is RESOLVED ([method resolve]) and the clock
##    jumps `clamp(2d + T / 64, 0, 32)`.
## (`d` the difficulty, 0 Apprentice … 3 Wizard.) The first siege comes at
## T = 64, about two minutes of walking; the hero has 24 − a steps to lift
## it (24 for an Apprentice early on, 8 late), the land rests 40 − b steps
## before the next. Neither jump can pass a test: a ≤ 16 < 24 and 24 + b ≤
## 56 < 64.
##
## A SIEGE BEGINS (nothing while one is under way, [member
## AdventurePlayer.siege_active]): every town and city no wizard holds — the
## hero's linked ones, a quest's, the one the hero stands in alike; never a
## village or a castle — is scored for the wizard whose unbeaten castle is
## nearest it (1997's distance in tiles, the lower colour on a tie): the
## towns that wizard already holds × 32 + a die of 128, one die for each
## town in slot order. The lowest score is besieged (the first of equals).
## Its creature is the wizard's colour's, of the tier the clock has reached
## ([method tier_for]: 4, 6, 8, 12, then 12 or 16 by the town's row), drawn
## as every creature is ([method CreatureBook.pick]); it stands in roaming
## slot 7 at the town's middle ([WorldCreatures] walks it: it hovers round
## its town and chases a hero who comes within 24 — met, it is dueled like
## any creature, never refused). The town's tile is explored, the sieges
## counted, the NEWS FLASH: "Black Wizard sends a Witch to attack Kraag
## Temple!" ([NewsFlashPane]). No wizard with a castle left: no siege.
##
## A SIEGE RESOLVED — at its time on the clock, or at once when the hero
## meets the besieger and does not beat it ([method resolve]; a draw takes
## the town too, the lead's ruling): the besieged town is the wizard's —
## its mana link lost ("Your mana tap here is lost.") — and the news says
## so: "The Evil Red Wizardess taps Kraag Temple!", "She needs 2 more mana
## taps to cast the Spell of Dominion!" — or, his taps now 3 (5 while the
## hero owns Ring of the Guardian), "He casts the spell of Dominion":
## DOMINION, the adventure lost ([AdventureEndScreen], the 1997 words of
## `@QUESTFAILED`, back to the title with the saves as they were — 1997
## ended the program and its Resume took up the last save, from before the
## fall). A besieger beaten lifts the siege ([method lifted]): "Saved %s" in
## the journal. A siege lifted is never resolved: the clock's turn finds no
## besieger and says nothing.
##
## RETALIATION (part C, Wizard difficulty only): 1997 sent a siege as the
## hero left a wizard's castle unbeaten (`TriggerWizardSiegeNewsflash`,
## visitLocation.c 502–655, called at 4394) — [method start] with that
## wizard: only his castle scored, so the town is drawn at random among
## them, in `@NEWSFLASH` 2/3's words. Called by [method DungeonDoors.leave]
## as the hero comes out of a castle unbeaten (2026-10-27) — live once part
## C's board opens the castle's door ([constant DungeonDoors.BOARD_READY]).
## [method free_all] is part C's too: a beaten wizard's towns freed and his
## creatures gone (`HandleDefeatedWizardCastle`, dungeonEncounter.c
## 918–970).
##
## FIXED [ours: 1997 slips, each marked where it is fixed; listed in
## docs/adventure-implementation-notes.md]:
##  - THE BESIEGED TOWN falls — the one the news named and the map reds
##    (1997 gave the wizard whatever site stood nearest the besieger as the
##    clock ran out, `FindNearestTownIndex`: a besieger lured away by the
##    hero took a village, a castle or another town);
##  - a wizard past the taps he needs casts Dominion (1997 tested "needs
##    exactly 0 more", and would have said "needs −1 more" — a count only a
##    save could reach);
##  - no castle of the retaliating wizard, no siege (1997 read a stale
##    colour from its castle scan and sent another wizard's creature);
##  - no town left to besiege, no siege (1997 read an unset town).
## OURS beside: the news flash shows the wizard's taps in the quest pane's
## words (1997 popped the wizards' stats window after a fall's news,
## `ShowStatsWindow(3)`; ours keeps the screen and says it in a line); the
## sieges are counted in the save (1997 never saved `g_wizard_siege_count`,
## which part C's end score takes off).
##
## DESIGNED, NEVER USED — kept dead here (and in
## docs/adventure-unused-1997-features.md):
##  - THE WIZARDS' AND THE CREATURES' GENDERED WORDS that say the same:
##    `@NEWSFLASH` 2/3 ("In retaliation…") and 4/5 ("The Evil %1 taps %2!"),
##    `@QUESTFAILED` 2/3 (the Minion's Dominion) — chosen by the wizard's
##    gender (`IsWizardColorFeminine`) — and `@VISIT` 21/22 and 26/27 ("glad
##    to be rid of the pesky %s", by the creature's) are pairs of the same
##    text. Written apart, they were meant to differ ("her Minion", "the
##    Evil Wizardess"…); never were. Given words of their own, the news and
##    the end would speak of each wizard as the stats window does. To
##    switch on: give each pair its own words here ([method fall_lines],
##    [method dominion_lines], [method siege_lines]) and in [Quests].

## The siege clock's two tests, as `T & 63`.
const START_AT := 0
const RESOLVE_AT := 24
## The clock's jumps: after a start `clamp(d + T / 256, 0, 16)`, after a
## resolve `clamp(2d + T / 64, 0, 32)`.
const START_JUMP_MOST := 16
const RESOLVE_JUMP_MOST := 32
## The besieger's slot ([member AdventurePlayer.monsters]).
const SLOT := WorldCreatures.SIEGE_SLOT
## A site a wizard has beaten (1997's location type 5).
const BEATEN_CASTLE := 5
## The score per town a wizard already holds, and the die beside it.
const TAP_WEIGHT := 32
const SCORE_DIE := 128
## The creature's tier by `T / 128` (0 … 3; later, 12 on an odd row and 16
## on an even).
const TIERS: Array[int] = [4, 6, 8, 12]
const LATE_ODD := 12
const LATE_EVEN := 16

## `@NEWSFLASH` 0–10.
const NEWS_FLASH := "--- NEWS FLASH ---"
const SENDS := "%s sends %s to attack %s!"
const RETALIATION := "In retaliation for your effrontery the Great %s sends %s to attack %s!"
const TAPS := "The Evil %s taps %s!"
const SHE_NEEDS := "She needs %d more mana taps to cast the Spell of Dominion!"
const HE_NEEDS := "He needs %d more mana taps to cast the Spell of Dominion!"
const SHE_CASTS := "She casts the spell of Dominion"
const HE_CASTS := "He casts the spell of Dominion"
const TAP_LOST := "Your mana tap here is lost."
## `@QUESTFAILED` 1, 2/3 and 5: the Spell of Dominion cast.
const FAILED := "Your Righteous Quest has Failed"
const DOMINION := "The Evil Planeswalker Arzakon\nand his Minion the\nEvil %s\nhave attained Dominion over the plane of Shandalar"
const SUFFER := "The people will suffer\na thousand more years of their oppression\nbefore another Savior shall rise up from amongst them\nto challenge the great Arzakon and his Slimy Minions"


# ------------------------------------------------------------ the clock --

## THE SIEGE CLOCK HAS STEPPED ON ([member AdventurePlayer.siege_timer],
## just raised by [HeroWalk]): a siege begun or resolved when the clock
## says, and its jump. The news, in the order it happened — each `{kind,
## lines, town, wizard, creature}`, the kind `siege` (begun), `fall` (a
## town taken) or `dominion` (the adventure lost, after the fall's news);
## the state is changed already.
static func on_step(player: AdventurePlayer) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	var d := clampi(player.difficulty, 0, 3)
	if player.siege_timer & 63 == START_AT:
		news.append_array(start(player))
		# The jump is taken even when a siege was already under way.
		player.siege_timer += clampi(d + player.siege_timer / 256, 0, START_JUMP_MOST)
	if player.siege_timer & 63 == RESOLVE_AT:
		news.append_array(resolve(player))
		player.siege_timer += clampi(2 * d + player.siege_timer / 64, 0, RESOLVE_JUMP_MOST)
	return news


## The besieger's tier for siege clock [param timer] and a town on row
## [param town_y] (`T / 128`: 4, 6, 8, 12; later 12 on an odd row, 16 on
## an even).
static func tier_for(timer: int, town_y: int) -> int:
	var step := maxi(timer, 0) / 128
	if step < TIERS.size():
		return TIERS[step]
	return LATE_ODD if town_y & 1 != 0 else LATE_EVEN


# ------------------------------------------------------- a siege begins --

## A SIEGE BEGINS (`StartWizardTownSiege`; with [param retaliating_wizard]
## 1–5, `TriggerWizardSiegeNewsflash`, part C): the town besieged and its
## creature put in slot 7 — the news `[{kind: "siege", …}]`, or `[]` when a
## siege is already under way (no die drawn), no wizard has a castle left,
## or no town is left to besiege (the dice drawn all the same, one for each
## town, as 1997 drew them).
static func start(player: AdventurePlayer, retaliating_wizard := 0) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	if player.siege_active or player.world == null:
		return news
	var world := player.world
	var castles := castle_tiles(player)
	if retaliating_wizard != 0:
		# Only the angry wizard's castle: every town is his, at one score.
		for color in castles.keys():
			if int(color) != retaliating_wizard:
				castles.erase(color)
	var taps := WorldStatus.taps(player)
	var dice := MsvcRandom.new(player.dice)
	var best_score := 0x7fff
	var town := -1
	var wizard := 0
	for slot in candidates(world):
		var color := nearest_castle(world, slot, castles)
		var score := (taps[color - 1] if color > 0 else 0) * TAP_WEIGHT + dice.below(SCORE_DIE)
		if score < best_score:
			best_score = score
			town = slot
			wizard = color
	# [ours: 1997 slip — with no castle (every wizard beaten, or the
	# retaliating one's gone) 1997 ended here only for the start, and read
	# a stale colour for the retaliation; with no town at all, an unset one.]
	if wizard <= 0 or town < 0:
		player.dice = dice.state
		return news
	var site: Dictionary = world.sites[town]
	var tile := Vector2i(int(site["x"]), int(site["y"]))
	var row := CreatureBook.pick(dice, wizard, tier_for(player.siege_timer, tile.y))
	player.dice = dice.state
	if row < WorldCreatures.FIRST_ROW or row > WorldCreatures.LAST_ROW:
		# The pick gave up (999 misses) on the lair row: every tier a siege
		# asks has a creature of every colour, so never in play. [ours]
		return news
	WorldCreatures.empty(player, SLOT)
	player.monsters.append({"slot": SLOT, "kind": "creature", "creature": row,
		"x": tile.x * 32 + 16, "y": tile.y * 32 + 16, "color": wizard, "heading": 0, "frame": 0,
		"town": town})
	player.siege_count += 1
	_explore_tile(world, tile)
	player.siege_active = true
	news.append({"kind": "siege", "town": town, "wizard": wizard, "creature": row,
		"lines": siege_lines(player, wizard, row, town, retaliating_wizard != 0)})
	return news


## The towns a siege may fall on, in slot order: every site no wizard holds
## that is neither a village nor a castle (a beaten one neither).
static func candidates(world: ShandalarWorld) -> Array[int]:
	var out: Array[int] = []
	for slot in world.sites.size():
		var kind := int(world.sites[slot]["type"])
		if kind <= 0 or kind == ShandalarWorld.VILLAGE or kind == ShandalarWorld.CASTLE \
				or kind == BEATEN_CASTLE or TownStatus.ruled(world, slot):
			continue
		out.append(slot)
	return out


## THE WIZARDS STILL IN THEIR CASTLES: `{colour: tile}` (1 black … 5
## white) — each unbeaten castle's site (type 4), by the colour of the land
## it stands on (1997's `single_color_test_bit_to_color_t`; the lowest
## colour of a land of two), a wizard the hero has beaten left out.
static func castle_tiles(player: AdventurePlayer) -> Dictionary:
	var out := {}
	var world := player.world
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["type"]) != ShandalarWorld.CASTLE:
			continue
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		var color := _color_of_mask(ShandalarWorld.magic_mask(world.terrain(tile.x, tile.y)))
		if color <= 0 or AdventurePlayer.COLORS[color - 1] in player.defeated_wizards:
			continue
		out[color] = tile
	return out


## The wizard whose castle ([param castles], [method castle_tiles]) is
## nearest site [param slot] (1997's distance in tiles; the lower colour on
## a tie), 0 for none.
static func nearest_castle(world: ShandalarWorld, slot: int, castles: Dictionary) -> int:
	var site: Dictionary = world.sites[slot]
	var nearest := 0x7fff
	var wizard := 0
	for color in range(1, 6):
		if not castles.has(color):
			continue
		var at: Vector2i = castles[color]
		var d := WorldGenerator.distance(int(site["x"]) - at.x, int(site["y"]) - at.y)
		if d < nearest:
			nearest = d
			wizard = color
	return wizard


## The news of a siege begun (`@NEWSFLASH` 1, or 2/3 for a retaliation by
## the wizard's gender — the same words): the wizard, the creature with its
## article, the town.
static func siege_lines(player: AdventurePlayer, wizard: int, row: int, town: int,
		retaliation := false) -> Array[String]:
	var named: String = WorldNames.WIZARDS[clampi(wizard, 1, 5) - 1]
	var words := RETALIATION if retaliation else SENDS
	return [words % [named, CreatureBook.called(row), WorldNames.site_name(player.world, town)]] as Array[String]


# ---------------------------------------------------- a siege resolved --

## THE SIEGE RESOLVED (`ResolveWizardTownSiege`): [param besieger] the
## besieger's record — slot 7's when not given (the clock's turn); the
## meeting's end gives it as it was met ([method WorldCreatures.met], the
## slot already spent). With none, the siege was lifted: nothing but the
## flag lowered. Else the besieged town is the wizard's, its link lost,
## the sieges counted, slot 7 emptied — and the news: `[{kind: "fall"}]`,
## then `{kind: "dominion"}` when the wizard's taps cast the Spell of
## Dominion.
static func resolve(player: AdventurePlayer, besieger := {}) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	player.siege_active = false
	var held := besieger if not besieger.is_empty() else WorldLairs.held_in(player, SLOT)
	var row := int(held.get("creature", 0))
	if held.is_empty() or row <= 0 or player.world == null:
		return news
	var world := player.world
	var wizard := clampi(int(held.get("color", 1)), 1, 5)
	# [ours: 1997 slip — the besieged town: 1997 took the site nearest the
	# besieger as the clock ran out (`FindNearestTownIndex`).]
	var town := int(held.get("town", -1))
	if not Quests.is_site(world, town):
		town = WorldCreatures.nearest_site(world, Vector2i(int(held.get("x", 0)) / 32, int(held.get("y", 0)) / 32))
	if town < 0:
		WorldCreatures.empty(player, SLOT)
		return news
	# The link is read before the town is taken: taking it clears the link.
	var link_lost := TownStatus.linked(world, town)
	TownStatus.take(world, town, wizard)
	var taps: int = WorldStatus.taps(player)[wizard - 1]
	var needed := WorldStatus.dominion(player)
	player.siege_count += 1
	WorldCreatures.empty(player, SLOT)
	news.append({"kind": "fall", "town": town, "wizard": wizard, "creature": row,
		"taps": taps, "needed": needed,
		"lines": fall_lines(player, wizard, town, taps, needed, link_lost)})
	if taps >= needed:
		news.append({"kind": "dominion", "town": town, "wizard": wizard, "creature": row,
			"lines": dominion_lines(wizard)})
	return news


## The news of a town fallen (`@NEWSFLASH` 4/5, then 6/7 or 8/9 by the
## wizard's gender, then 10 when the hero's link there is lost), and ours:
## the wizard's taps as the quest pane says them (1997 popped the wizards'
## window after the news).
static func fall_lines(player: AdventurePlayer, wizard: int, town: int, taps: int, needed: int,
		link_lost: bool) -> Array[String]:
	var named: String = WorldNames.WIZARDS[clampi(wizard, 1, 5) - 1]
	var she := CreatureMeeting.wizard_feminine(wizard)
	var lines: Array[String] = [TAPS % [named, WorldNames.site_name(player.world, town)]]
	# [ours: 1997 slip — "needs" only while short of the count (1997:
	# while not exactly at it).]
	if needed - taps > 0:
		lines.append((SHE_NEEDS if she else HE_NEEDS) % (needed - taps))
	else:
		lines.append(SHE_CASTS if she else HE_CASTS)
	if link_lost:
		lines.append(TAP_LOST)
	lines.append("%s: %d of %d mana taps" % [named, taps, needed])
	return lines


## The end's words when wizard [param wizard] casts the Spell of Dominion
## (`@QUESTFAILED` 1, 2/3 — the same words by his gender — and 5).
static func dominion_lines(wizard: int) -> Array[String]:
	return [FAILED, DOMINION % WorldNames.WIZARDS[clampi(wizard, 1, 5) - 1], SUFFER] as Array[String]


## Whether [param news] ([method on_step], [method resolve]) ends the
## adventure (the Spell of Dominion cast).
static func ends(news: Array) -> bool:
	for one in news:
		if String((one as Dictionary).get("kind", "")) == "dominion":
			return true
	return false


## THE BESIEGER BEATEN (world_lair_monster_slots.c 947–951): the siege
## lifted — the flag lowered, "Saved %s" in the journal (1997's journal
## entry 13; ours names the town). [param besieger] the besieger as it was
## met ([method WorldCreatures.met]: `town`); slot 7 when not given.
static func lifted(player: AdventurePlayer, besieger := {}) -> void:
	var held := besieger if not besieger.is_empty() else WorldLairs.held_in(player, SLOT)
	player.siege_active = false
	var town := int(held.get("town", -1))
	var named := WorldNames.site_name(player.world, town) if Quests.is_site(player.world, town) else ""
	player.log_event("saved", "Saved %s" % named, {"town": town})


# --------------------------------------------------------------- part C --

## A WIZARD BEATEN (part C, `HandleDefeatedWizardCastle`): every town
## wizard [param wizard] holds is freed (its link stays lost), and every
## creature of his colour leaves the map — the besieger too, its siege then
## over [ours: 1997 left the flag up for the clock to lower]. The towns
## freed, in slot order.
static func free_all(player: AdventurePlayer, wizard: int) -> Array[int]:
	var freed: Array[int] = []
	var world := player.world
	for slot in world.sites.size():
		if TownStatus.ruler(world, slot) == wizard:
			TownStatus.release(world, slot)
			freed.append(slot)
	for i in range(player.monsters.size() - 1, -1, -1):
		var held: Dictionary = player.monsters[i]
		if int(held.get("color", 0)) == wizard:
			if int(held.get("slot", -1)) == SLOT:
				player.siege_active = false
			player.monsters.remove_at(i)
	return freed


# ------------------------------------------------------------- helpers --

## The tile [param tile] marked explored, alone (1997's
## `SetWorldMapPixelFlags(0x80, x, y)`).
static func _explore_tile(world: ShandalarWorld, tile: Vector2i) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= ShandalarWorld.TILES or tile.y >= ShandalarWorld.TILES:
		return
	var at := tile.y * ShandalarWorld.PAGE_WIDTH + tile.x
	world.page[at] = world.page[at] | ShandalarWorld.EXPLORED


## The colour (1 black … 5 white) of a land's colour bits: the lowest set.
static func _color_of_mask(mask: int) -> int:
	for color in range(1, 6):
		if mask & (1 << color) != 0:
			return color
	return 0
