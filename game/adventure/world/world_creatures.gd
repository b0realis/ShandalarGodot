class_name WorldCreatures
extends RefCounted
## THE CREATURES ON THE MAP (part B, 2026-10-23) — 1.3's
## `UpdateWorldLairAndMonsterSlots` (world_lair_monster_slots.c 327–969,
## 0055fd27; retail glue_adventure.c 1000–1510 moves them the same), run once
## a tick of the world's clock, after the hero's step and before the clock
## goes on ([method WorldScreen.advance]). For each of the slots 0–5 and the
## besieger's 7, in order ([member AdventurePlayer.monsters]):
##  - REFILL (slots 0–5): a slot empty, or holding something more than 4
##    tiles from the hero on either axis, is filled again
##    ([method WorldLairs.fill]: the ring, the colour, a lair or a creature's
##    tier, the creature drawn — `PickRandomCreatureTypeForWizardTier` —
##    and the gates); a creature waiting out its slot's respawn time, or
##    Apprentice slot 5, keeps what it held and does nothing this tick.
##  - MOVE: every creature steers at the hero every tick — there is no aggro
##    range — 1 unit a tick (2 for a flyer and the three fast ones,
##    [method CreatureBook.stride]):
##     - the aim is the hero, led ahead of a walking hero by `clamp(d0 / 3,
##       0, 16 · difficulty)` units (an Apprentice is never led);
##     - turned away (it FLEES) while within 64 when the hero has beaten
##       difficulty + 3 creatures of its kind on its colour;
##     - the besieger (slot 7), more than 24 from the hero, keeps to its
##       town's middle, the point swept ±16 by the clock (`(T & 31) − 16`
##       across, `((T & 62) >> 1) − 16` down): it hovers there;
##     - eight units of its last heading are added (inertia), the result is
##       one of eight ways ([method way_of]), taken as the new heading only
##       on the ticks where `(T + slot) & 3 == 0` (each creature turns at most
##       every 240 ms, staggered by slot);
##     - a probe 4 units on: a creature that would come within 32 of another
##       (and nearer to it than now) stands still this tick, unless the hero
##       is within 32 — CROWDING;
##     - the BLINK creatures (War Mage, Mind Stealer, the four djinn) on
##       every 64th tick move the probe 32 units in a random straight way,
##       which only changes the land the next test reads (two dice);
##     - land with none of the creature's colours under the probe stops it
##       (the sea stops every creature but the besieger); when its own tile
##       has none either, it is gone. Otherwise it steps on, its walk's frame
##       1–4.
##  - CONTACT: within 16 of the hero (1997's distance, twice the longer axis
##    and the shorter; a lair within 26) the creature is MET — the tick ends
##    there and the world opens the meeting ([method WorldScreen.meet_creature],
##    a lair [method WorldScreen.enter_lair]).
##  - CRY: a creature that stepped, within 80, cries one time in `d0 / 4`
##    ([method WorldSoundscape.cry]).
## (`d0` is the creature's distance from the hero as the tick begins, `T`
## the world's clock before this tick moves it on, `d` the difficulty, 0
## Apprentice … 3 Wizard.)
##
## THE HERO SEES every live creature within the 4 tiles it lives in
## ([method seen]) — [QoL, the owner's ruling 2 of 2026-10-23: 1997 drew a
## creature only within a tile of the hero (adventureWorldUi.c 2225), so on a
## whole screen they popped up close]. The two LURKERS (Conjurer, Troll
## Shaman — and the Shapeshifter while its disguise shows the Conjurer) hide
## further than 256 of 1997's page pixels from the hero's feet. Lairs keep
## the 1997 rule ([method WorldLairs.seen]).
##
## ENTERING A PLACE pushes the creatures near the hero 48 units out
## ([method push_back]); A MEETING spends the slot ([method met]); A DUEL
## clears the creatures crowding the hero ([method clear_crowd]).
##
## FIXED [ours: 1997 slips, each marked where it is fixed; listed in
## docs/adventure-implementation-notes.md]:
##  - `d0` on the tick a slot is filled is read at the creature's new place
##    (1997 read it at the slot's old place, measured before the refill: a
##    loud cry, a lead or a flight decided for where the slot stood before);
##  - only live creatures crowd (1997's empty slots blocked at the stale
##    places their last creatures left, unseen walls on the map);
##  - a slot emptied by the colour stop is not met on the same tick (1997
##    tested it against the hero at 16 and could open a meeting with an
##    empty slot — undefined);
##  - the quest's creature: slot 0 is held for it only while its quest is
##    under way (1997 held it, and refused every other creature and every
##    lair there, from the quest's acceptance until the next quest — through
##    the report back and after a failure), and it neither flees from the
##    hero nor stops coming after more than 8 wins of its kind on its colour
##    (1997 could make the quest impossible);
##  - the besieger keeps to the town it besieges (1997 to whichever site was
##    nearest it, so a besieger lured away hovered at another town — the
##    lead's ruling: the besieged town is the one that falls);
##  - a creature's cry pans by where it stands on the screen (1997 panned by
##    its heading: `dx` of `(heading + 2) & 7`, so a creature west of the
##    hero walking north-east sounded on the left), and is drawn on the
##    soundscape's own dice (1997's `internal_rand(d0)` drew the world's:
##    ours never lets a sound change what the world's dice give).
##
## DESIGNED, NEVER USED — computed or laid out by 1997, never let take
## effect; kept dead here (and in docs/adventure-unused-1997-features.md):
##  - THE AGGRO RANGE AND THE SPEED (slots.c 361–375 and 636–714; retail
##    1251–1352): per kind a range (32 wizards and flyers, 48 knights, lords
##    and archmages, 64 djinn and dragons, 96 trolls and wyrms) × 3/2,
##    doubled for flag 0x200 ([constant CreatureBook.MOVE_WIDE_RANGE]),
##    halved for every creature but the one nearest the hero (a search of
##    its own, dead too); and a speed that doubles for every halving of the
##    distance needed to bring it inside the range. Nothing reads either but
##    the range's sign (lairs −1). Switched on, a creature would steer at the
##    hero only within its range — wandering, or standing, until the hero
##    came near — and close the distance faster the further it was: the
##    world would have quiet stretches and sudden rushes, the dragons and
##    wide-ranged ones noticing the hero from twice as far. To switch on:
##    [method _walk] aims at the hero only inside the range and multiplies
##    [method CreatureBook.stride] by the speed.
##  - SLOW ON SOME LANDS (flags 0x008–0x080, [constant
##    CreatureBook.MOVE_TERRAIN]; slots.c 770–780): the dead speed halved on
##    land of the colours the bits name — mostly not the creature's own (the
##    Merfolk Shaman's black, the Sedge Beast's green, the Elementalist's
##    black and green, the Centaur Shaman's blue, the Centaur Warchief's red;
##    the Ape Lord's blue never). Switched on (with the speed), outrunning
##    them would depend on where they stand. To switch on: halve the stride
##    there.
##  - CREATURE NAMES ON THE MAP (adventureWorldUi.c 2280–2284): a drawn
##    creature's name — for the three DISGUISE creatures the row of [method
##    CreatureBook.shown_row], a row lower every 32 ticks — was copied into
##    the message line for 8 ticks of every 32, slot by slot (`(T >> 3) & 3`
##    the slot's `& 3`), and never drawn.
##    Switched on, the hero would know what approaches before meeting it, and
##    the Necromancer, the Shapeshifter and the Summoner would come
##    disguised as weaker creatures. To switch on: the world screen's pointer
##    tip names a creature under the pointer by [method CreatureBook.name_of]
##    of [method CreatureBook.shown_row]. (The disguise itself is live: it
##    moves the lurk test.)
##  - SLOT 6: the ruled town's liberation duel writes its creature into
##    roaming slot 6 (visitLocation.c 4312–4313) and never places it; its
##    place (0, 0) is the sea, so the colour stop empties it on the next
##    tick. Never on the map: not modelled.

## The slots walked each tick, in 1997's order: the six roaming ones and the
## besieger's (slot 6 is never on the map, see the class's notes).
const WALKED: Array[int] = [0, 1, 2, 3, 4, 5, 7]
## The besieger's slot.
const SIEGE_SLOT := 7
## How far out a creature lives, in tiles on either axis.
const RING := 4
## A creature is met within this (1997's distance), a lair within
## [constant WorldLairs.REACH].
const CONTACT := 16
## Within this of the hero a creature that has lost to the hero often
## enough runs from them.
const FLEE := 64
## The besieger keeps to its town while the hero is further than this.
const SIEGE_CHASE := 24
## A creature's probe goes this far ahead of it, and comes no nearer than
## [constant CROWD] to another (unless the hero is within [constant CROWD]).
const PROBE := 4
const CROWD := 32
## The BLINK creatures jump on the ticks where `T & 63 == 0`, this far.
const BLINK_TICKS := 63
const BLINK := 32
## The inertia: units of the last heading added to the aim.
const INERTIA := 8
## A creature cries only within this of the hero.
const CRY_REACH := 80
## Entering a place pushes the creatures within this out to [constant
## PUSHED] on each axis that leads.
const PUSH_REACH := 96
const PUSHED := 48
## A duel clears the creatures within this of the hero.
const CROWD_CLEARED := 64
## A lurker hides further than this (1997 page pixels, 640 across) from the
## hero's feet.
const LURK := 256
## What a meeting came to ([signal WorldEncounters] `finished`): the duel
## won, lost, drawn, or no duel at all (paid, a riddle, a tribute — 1997's
## `duel_result` 0 for these).
const WON := 1
const LOST := 0
const DRAWN := -1
const NO_DUEL := 2
## The rows a creature of the map may be (the lair is 0; the castle wizards
## and Arzakon never walk).
const FIRST_ROW := 1
const LAST_ROW := 54


# ------------------------------------------------------------ the tick --

## THE WORLD'S TICK for the slots: each filled or kept, walked, met or
## crying, in 1997's order — `{met, kind, cries}`: the slot met this tick
## (−1 for none; the tick stops there), `lair` or `creature`, and the
## creatures that may cry (`{slot, creature, distance, x, y}`, for [method
## WorldSoundscape.cry], which throws its own dice). Reads the clock `T`
## before this tick moves it on ([method HeroWalk.end_tick]).
static func tick(player: AdventurePlayer) -> Dictionary:
	var out := {"met": -1, "kind": "", "cries": []}
	if player == null or player.world == null:
		return out
	var dice := MsvcRandom.new(player.dice)
	var hero := player.tile()
	for slot in WALKED:
		if slot < WorldLairs.SLOTS:
			var was := WorldLairs.held_in(player, slot)
			if not is_live(was) or absi(hero.x - int(was["x"]) / 32) > RING \
					or absi(hero.y - int(was["y"]) / 32) > RING:
				# The gates (Apprentice slot 5, the respawn wait) keep what
				# the slot held, unmoved and unmet this tick.
				if not WorldLairs.fill(player, slot, dice):
					continue
		var held := WorldLairs.held_in(player, slot)
		if not is_live(held):
			continue
		var at := Vector2i(int(held["x"]), int(held["y"]))
		if is_lair(held):
			# A lair runs the walk too in 1997, with a stride of 0: only its
			# contact matters.
			if _distance(player.position, at) < WorldLairs.REACH:
				out["met"] = slot
				out["kind"] = "lair"
				break
			continue
		var step := _walk(player, slot, held, dice)
		if step["blocked"] or step["gone"]:
			# Blocked: nothing else this tick. Gone (the colour stop): not
			# met [ours: 1997 slip — an emptied slot met at 16].
			continue
		at = Vector2i(int(held["x"]), int(held["y"]))
		if _distance(player.position, at) < CONTACT:
			out["met"] = slot
			out["kind"] = "creature"
			break
		if int(held.get("frame", 0)) != 0 and int(step["d0"]) < CRY_REACH:
			(out["cries"] as Array).append({"slot": slot, "creature": int(held["creature"]),
				"distance": int(step["d0"]), "x": at.x, "y": at.y})
	player.dice = dice.state
	return out


## ONE CREATURE'S WALK this tick (slots.c 641–934): its aim, the way, the
## probe, the crowding, the jump, the colour stop and the step — `{d0,
## blocked, gone}`, the record [param held] changed in place.
static func _walk(player: AdventurePlayer, slot: int, held: Dictionary, dice: MsvcRandom) -> Dictionary:
	var row := int(held["creature"])
	var flags := CreatureBook.move_flags(row)
	var now := player.monster_timer
	var hero := player.position
	var from := Vector2i(int(held["x"]), int(held["y"]))
	# [ours: 1997 slip — on the tick a slot is filled 1997 measured from the
	# slot's old place; here from where the creature stands.]
	var d0 := _distance(hero, from)
	var aim := aim_of(player, slot, held, d0)
	var heading := clampi(int(held.get("heading", 0)), 0, 8)
	aim += _dir(heading) * INERTIA
	var way := way_of(aim)
	if (now + slot) & 3 == 0:
		heading = way
		held["heading"] = heading
	else:
		way = heading
	var probe := from + _dir(way) * PROBE
	var out := {"d0": d0, "blocked": false, "gone": false}
	if d0 >= CROWD and crowded(player, slot, from, probe):
		held["frame"] = 0
		out["blocked"] = true
		return out
	if flags & CreatureBook.MOVE_BLINK != 0 and now & BLINK_TICKS == 0:
		# The jump moves only the probe, which the colour test reads next:
		# both branches below set the place anew (two dice, as 1997).
		if dice.below(2) != 0:
			probe.x += BLINK if dice.below(2) != 0 else -BLINK
		else:
			probe.y += BLINK if dice.below(2) != 0 else -BLINK
	var colors := colors_of(row)
	if slot != SIEGE_SLOT and _land_colors(player.world, probe) & colors == 0:
		held["frame"] = 0
		if _land_colors(player.world, from) & colors == 0:
			empty(player, slot)
			out["gone"] = true
		return out
	var to := from + _dir(way) * CreatureBook.stride(row)
	held["x"] = to.x
	held["y"] = to.y
	held["heading"] = way
	var frame := int(held.get("frame", 0)) + 1
	held["frame"] = 1 if frame > 4 else frame
	return out


## WHERE CREATURE [param held] in slot [param slot] AIMS, as an offset from
## where it stands, before its inertia ([param d0] its distance from the
## hero): the hero, led ahead of them by `clamp(d0 / 3, 0, 16 · difficulty)`
## while they walk; turned round when it flees ([method flees]); the
## besieger's town while the hero is further than 24.
static func aim_of(player: AdventurePlayer, slot: int, held: Dictionary, d0: int) -> Vector2i:
	var from := Vector2i(int(held["x"]), int(held["y"]))
	var aim := player.position - from
	if player.step != 0:
		var lead := clampi(d0 / 3, 0, 16 * clampi(player.difficulty, 0, 3))
		aim += _dir(player.facing) * lead
	if slot < SIEGE_SLOT and d0 < FLEE and flees(player, held):
		aim = -aim
	if slot == SIEGE_SLOT and d0 > SIEGE_CHASE:
		var town := siege_town_of(player, held)
		if town >= 0:
			var site: Dictionary = player.world.sites[town]
			var now := player.monster_timer
			aim = Vector2i(int(site["x"]) * 32 + 16 + (now & 31) - 16,
				int(site["y"]) * 32 + 16 + ((now & 62) >> 1) - 16) - from
	return aim


## Whether creature [param held] runs from the hero (slots.c 741–758): the
## hero has beaten difficulty + 3 creatures of its kind on its colour —
## kinds are shared across rows. [Ours: 1997 slip — never the quest's
## creature while its quest is under way.]
static func flees(player: AdventurePlayer, held: Dictionary) -> bool:
	var row := int(held.get("creature", 0))
	if row == quest_row(player):
		return false
	return player.wins_against(CreatureBook.kind(row), int(held.get("color", 0))) >= player.difficulty + 3


## The town besieger [param held] keeps to: the one it besieges [ours: 1997
## slip — 1997 the site nearest it, `FindNearestTownIndex`, which is still
## the way for a record without a town]; −1 for none.
static func siege_town_of(player: AdventurePlayer, held: Dictionary) -> int:
	var town := int(held.get("town", -1))
	if town >= 0 and town < player.world.sites.size():
		return town
	return nearest_site(player.world, Vector2i(int(held["x"]) / 32, int(held["y"]) / 32))


## `FindNearestTownIndex` (adventureWorldUi.c 300–321): the site nearest
## tile [param tile] (1997's distance in tiles; the first of equals), −1 for
## none.
static func nearest_site(world: ShandalarWorld, tile: Vector2i) -> int:
	var best := -1
	var best_distance := 0x7fff
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["type"]) <= 0:
			continue
		var d := WorldGenerator.distance(int(site["x"]) - tile.x, int(site["y"]) - tile.y)
		if d < best_distance:
			best_distance = d
			best = slot
	return best


## Whether the probe [param probe] of the creature in slot [param slot]
## (standing at [param from]) comes within 32 of another live creature of
## slots 0–5 and nearer to it than now (slots.c 848–876). [Ours: 1997 slip
## — only live creatures: 1997's empty slots blocked at their stale places.]
## Lairs and the besieger are never in the way.
static func crowded(player: AdventurePlayer, slot: int, from: Vector2i, probe: Vector2i) -> bool:
	for other in WorldLairs.SLOTS:
		if other == slot:
			continue
		var them := WorldLairs.held_in(player, other)
		if not is_creature(them):
			continue
		var there := Vector2i(int(them["x"]), int(them["y"]))
		var near := _distance(probe, there)
		if near < CROWD and near < _distance(from, there):
			return true
	return false


## THE WAY OF AN AIM (slots.c 786–834): east or west when the aim lies
## within about 27° of that axis (`2|y| < |x|`), north or south likewise,
## else the diagonal of its quarter; no aim at all is north-west (8). The
## ways are 1997's: 1 N, 2 NE, 3 E, 4 SE, 5 S, 6 SW, 7 W, 8 NW.
static func way_of(aim: Vector2i) -> int:
	if absi(aim.y) * 2 < absi(aim.x):
		return 3 if aim.x > 0 else 7
	if absi(aim.x) * 2 < absi(aim.y):
		return 5 if aim.y > 0 else 1
	if aim.x > 0:
		return 4 if aim.y > 0 else 2
	return 6 if aim.y > 0 else 8


# ---------------------------------------------------------- the meeting --

## THE CREATURE IN SLOT [param slot] IS MET, the meeting over with
## [param result] ([constant WON], [constant LOST], [constant DRAWN],
## [constant NO_DUEL]) — slots.c 941–958: its slot's respawn stamp now, the
## creature gone (whatever came of it: won, lost, drawn, paid, riddled), the
## clock on to the next 32 ticks. What it was, for the caller: `{slot,
## creature, color, town, siege}` — `siege` "" for a roaming slot; for the
## besieger "lifted" on a win and "falls" otherwise (1997 resolved the siege,
## `ResolveWizardTownSiege`, on any result ≤ 0, its bribes and riddles
## included; the town is taken, its news shown — [method
## WorldScreen._after_siege_meeting], the sieges' hook). The win's log, the
## spoils and the quest are the meeting's own ([WorldEncounters]).
static func met(player: AdventurePlayer, slot: int, result: int) -> Dictionary:
	var held := WorldLairs.held_in(player, slot)
	var out := {"slot": slot, "creature": int(held.get("creature", 0)), "color": int(held.get("color", 0)),
		"town": int(held.get("town", -1)), "siege": ""}
	if slot == SIEGE_SLOT and not held.is_empty():
		out["siege"] = "lifted" if result == WON else "falls"
	if player.world != null and slot >= 0 and slot < player.world.lair_respawn.size():
		player.world.lair_respawn[slot] = player.monster_timer
	empty(player, slot)
	player.monster_timer |= 0x1F
	return out


## A DUEL BEGINS with the creature of slot [param slot] (world_lair_monster_
## encounter.c 2232–2244): every other creature of the roaming slots within
## 64 of the hero is gone, unstamped — no lair, never the besieger. The
## slots cleared. (A bribe, a riddle or a tribute return before this.)
static func clear_crowd(player: AdventurePlayer, slot: int) -> Array[int]:
	var cleared: Array[int] = []
	for other in WorldLairs.SLOTS:
		if other == slot:
			continue
		var them := WorldLairs.held_in(player, other)
		if is_creature(them) and _distance(player.position, Vector2i(int(them["x"]), int(them["y"]))) < CROWD_CLEARED:
			empty(player, other)
			cleared.append(other)
	return cleared


## THE HERO ENTERS A PLACE (a village, a town, a city, a castle; adventure_
## input.c 838–883): every creature of the roaming slots within 96 is set
## 48 units from the hero on each axis that leads — east or west when the
## hero is more than half as far across as down, north or south likewise —
## and level with the hero on the other: so it stays on its side, or at a
## diagonal 48 × 48. Lairs and the besieger stay. No colour test: one set
## on land not its own is gone on the next tick.
static func push_back(player: AdventurePlayer) -> void:
	var hero := player.position
	for slot in WorldLairs.SLOTS:
		var held := WorldLairs.held_in(player, slot)
		if not is_creature(held):
			continue
		var at := Vector2i(int(held["x"]), int(held["y"]))
		if _distance(hero, at) >= PUSH_REACH:
			continue
		var gap := hero - at
		held["x"] = hero.x - (_sign(gap.x) * PUSHED if absi(gap.y) / 2 < absi(gap.x) else 0)
		held["y"] = hero.y - (_sign(gap.y) * PUSHED if absi(gap.x) / 2 < absi(gap.y) else 0)


# ------------------------------------------------------------- the eyes --

## THE CREATURES THE HERO SEES: every live creature within 4 tiles of the
## hero on both axes [QoL, the owner's ruling 2: 1997 within 1], but a
## LURKER further than 256 page pixels from the hero's feet (adventureWorldUi
## .c 2225–2240; its flags read on the row its disguise shows) [ours: 1997
## slip — 1997 measured from the page's point (320, 240), the hero's feet
## being at (320, 320), so lurkers showed north and east of the hero and
## hid a tile south or west]. `{slot, creature, x, y, heading, frame,
## color}`, slots in order; for [member WorldView.creatures].
static func seen(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or player.world == null:
		return out
	var hero := player.tile()
	for slot in WALKED:
		var held := WorldLairs.held_in(player, slot)
		if not is_creature(held):
			continue
		var at := Vector2i(int(held["x"]), int(held["y"]))
		if absi(at.x / 32 - hero.x) > RING or absi(at.y / 32 - hero.y) > RING:
			continue
		if lurks(player, held):
			continue
		out.append({"slot": slot, "creature": int(held["creature"]), "x": at.x, "y": at.y,
			"heading": int(held.get("heading", 0)), "frame": int(held.get("frame", 0)),
			"color": int(held.get("color", 0))})
	return out


## Whether creature [param held] is hidden from the hero as a lurker: its
## shown row ([method CreatureBook.shown_row]) carries [constant
## CreatureBook.MOVE_HIDDEN] and it stands further than [constant LURK] page
## pixels from the hero's feet (1997's distance over [method
## WorldView.project]'s pixels).
static func lurks(player: AdventurePlayer, held: Dictionary) -> bool:
	var shown := CreatureBook.shown_row(int(held.get("creature", 0)), player.monster_timer)
	if CreatureBook.move_flags(shown) & CreatureBook.MOVE_HIDDEN == 0:
		return false
	# The page's projection ([method WorldView.project]): 2 pixels across and
	# 1 down for each unit, across the diamond.
	var dx := int(held["x"]) - player.position.x
	var dy := int(held["y"]) - player.position.y
	return WorldGenerator.distance(2 * (dx + dy), dy - dx) > LURK


# ------------------------------------------------------------ the slots --

## Whether [param held] is a slot's lair.
static func is_lair(held: Dictionary) -> bool:
	return String(held.get("kind", "")) == "lair"


## Whether [param held] is a creature of the map: a row 1–54 (an old
## save's unpicked "waiting" creature is none).
static func is_creature(held: Dictionary) -> bool:
	if String(held.get("kind", "")) != "creature" or not held.has("x") or not held.has("y"):
		return false
	var row := int(held.get("creature", 0))
	return row >= FIRST_ROW and row <= LAST_ROW


## Whether [param held] is something on the map: a lair or a creature.
static func is_live(held: Dictionary) -> bool:
	return (is_lair(held) and held.has("x") and held.has("y")) or is_creature(held)


## The creature row in slot [param slot], 0 for none (a lair, nothing) —
## for a town's creature quest ([Quests]).
static func creature_in(player: AdventurePlayer, slot: int) -> int:
	var held := WorldLairs.held_in(player, slot)
	return int(held["creature"]) if is_creature(held) else 0


## Slot [param slot] emptied, unstamped (a creature quest drawing its own
## creature empties slot 0, visitLocation.c 1754–1756).
static func empty(player: AdventurePlayer, slot: int) -> void:
	for i in range(player.monsters.size() - 1, -1, -1):
		if int((player.monsters[i] as Dictionary).get("slot", -1)) == slot:
			player.monsters.remove_at(i)


## THE QUEST'S CREATURE while its quest is under way (the quest type in
## (−100, 0) is −row; [Quests]), 0 for none — slot 0 is held for it.
static func quest_row(player: AdventurePlayer) -> int:
	if player.quest.is_empty() or int(player.quest.get("destination", -1)) < 0:
		return 0
	var kind := int(player.quest.get("type", 0))
	if kind >= 0 or kind <= Quests.DEFEATED:
		return 0
	return -kind if -kind >= FIRST_ROW and -kind <= LAST_ROW else 0


## Creature row [param row]'s colours (1997 colour bits, 0x02 black …
## 0x20 white).
static func colors_of(row: int) -> int:
	return int(CreatureBook.ROWS[row][CreatureBook.COLORS]) if CreatureBook.is_row(row) else 0


# ------------------------------------------------------------- helpers --

## The colours of the land at world point [param point] (off the map, the
## sea's none; the tile by 1997's division, toward 0).
static func _land_colors(world: ShandalarWorld, point: Vector2i) -> int:
	return ShandalarWorld.magic_mask(world.terrain(point.x / 32, point.y / 32))


## 1997's `ApproximateDistance` between two world points.
static func _distance(a: Vector2i, b: Vector2i) -> int:
	return WorldGenerator.distance(a.x - b.x, a.y - b.y)


## Way [param way] (0–8) as a step of one unit.
static func _dir(way: int) -> Vector2i:
	var d := clampi(way, 0, 8)
	return Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])


## 1997's `SignNonZero`: −1 below 0, else 1.
static func _sign(value: int) -> int:
	return -1 if value < 0 else 1
