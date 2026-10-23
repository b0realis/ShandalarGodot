class_name WorldLairs
extends RefCounted
## THE LAIRS ON THE MAP (the owner, 2026-10-23: *"Build all trade
## features"* — the Nomad's Bazaar, the Gemcutter's Guild, the Oasis of
## Muldoon and the Diamond Mine are lairs) — 1.3's
## `UpdateWorldLairAndMonsterSlots` (0055fd27), run once a tick of the
## world's clock for its six roaming slots ([member
## AdventurePlayer.monsters]):
##  - A slot empty, or holding something more than 4 tiles from the hero on
##    either axis, is filled again: a tile on the square 4 tiles out from
##    the hero (half the time on its left or right side, half on its top or
##    bottom, the place along the side at random), not the sea; its colour
##    one of its land's, at random.
##  - Lair or creature: with `vc` the lairs explored / 8 and the duels won
##    against that colour, a draw of `rand(clamp(128 / (vc + 4), 6, 20)) +
##    5 / (vc + 1)` makes a lair on 3, 9, 12, 14 and 16 or more — 60 in 100
##    at first, fewer as the hero goes on — and a creature otherwise. A
##    creature waits after its slot's last meeting, `(4 − difficulty) ·
##    373248000 / ((T / 15)² + 2309²)` ticks of the clock `T`, and on
##    Apprentice slot 5 holds none; a lair never waits.
##  - A lair of a beaten wizard's colour is black instead (blue when black's
##    wizard is the beaten one) — or gone when another wizard is beaten too;
##    one on a town's tile, or on another slot's place, is gone.
##  - A lair is seen only within a tile of the hero, never moves, and is
##    entered when the hero comes within 26 of its middle (1997's distance:
##    twice the larger axis and the smaller). Entered, it is SPENT AT ONCE
##    ([method explored]) — gone, its slot's meeting now, the clock on to
##    the next 32, one more lair explored — and only then is the game saved
##    ([method WorldScreen.enter_lair]; the lead's ruling C, 2026-10-23: no
##    save may hold a lair the hero is inside, or loading it would give the
##    lair's gold again).
## THE CREATURES come with the duels: until then a creature's draw holds its
## slot unseen and is never met — so lairs come as often as in 1997.

## The roaming slots.
const SLOTS := 6
## How far out a slot is filled, and how far it may be before it is.
const RING := 4
## A lair is entered within this (1997 distance), a creature met within 16.
const REACH := 26
## The draws that make a lair (`rand(M) + 5 / (vc + 1)`; 16 and more too).
const LAIR_DRAWS: Array[int] = [3, 9, 12, 14]
## The creature tier each other draw meets (0 a lair, 10 the weaker kinds).
const TIERS: Array[int] = [10, 10, 10, 0, 10, 8, 6, 4, 6, 0, 4, 6, 0, 4, 0, 4]
## Tries for a place not on the sea before the slot waits a tick.
const TRIES := 200


## THE WORLD'S TICK for the lairs: every roaming slot filled or kept, as the
## 1997 game kept them. The slot of a lair the hero has come to, or -1.
static func tick(player: AdventurePlayer) -> int:
	var world := player.world
	if world == null:
		return -1
	var dice := MsvcRandom.new(player.dice)
	var hero := player.tile()
	for slot in SLOTS:
		var held := held_in(player, slot)
		if held.is_empty() or absi(hero.x - int(held["x"]) / 32) > RING \
				or absi(hero.y - int(held["y"]) / 32) > RING:
			_fill(player, slot, dice)
	player.dice = dice.state
	for slot in SLOTS:
		var held := held_in(player, slot)
		if String(held.get("kind", "")) == "lair" and WorldGenerator.distance(
				player.position.x - int(held["x"]), player.position.y - int(held["y"])) < REACH:
			return slot
	return -1


## What slot [param slot] holds, `{}` for nothing.
static func held_in(player: AdventurePlayer, slot: int) -> Dictionary:
	for creature in player.monsters:
		if int((creature as Dictionary).get("slot", -1)) == slot:
			return creature
	return {}


## The lairs the hero can see: within a tile of them.
static func seen(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hero := player.tile()
	for creature in player.monsters:
		var lair := creature as Dictionary
		if String(lair.get("kind", "")) == "lair" and absi(int(lair["x"]) / 32 - hero.x) <= 1 \
				and absi(int(lair["y"]) / 32 - hero.y) <= 1:
			out.append(lair)
	return out


## THE LAIR IN SLOT [param slot] IS EXPLORED — as it is entered, once its
## event is drawn ([method LairEvent.begin] reads the clock first): gone,
## its slot's meeting now, the clock on to the next 32 ticks, one more lair
## explored.
static func explored(player: AdventurePlayer, slot: int) -> void:
	_empty(player, slot)
	if slot < player.world.lair_respawn.size():
		player.world.lair_respawn[slot] = player.monster_timer
	player.monster_timer |= 0x1F
	player.lairs_explored += 1


static func _empty(player: AdventurePlayer, slot: int) -> void:
	for i in range(player.monsters.size() - 1, -1, -1):
		if int((player.monsters[i] as Dictionary).get("slot", -1)) == slot:
			player.monsters.remove_at(i)


## Slot [param slot] filled again (or left empty this tick).
static func _fill(player: AdventurePlayer, slot: int, dice: MsvcRandom) -> void:
	var world := player.world
	var hero := player.tile()
	var at := Vector2i(-1, -1)
	var mask := 0
	for attempt in TRIES:
		if dice.below(2) != 0:
			at = Vector2i(hero.x + (RING if dice.below(2) != 0 else -RING), hero.y + dice.below(9) - RING)
		else:
			at = Vector2i(hero.x + dice.below(9) - RING, hero.y + (RING if dice.below(2) != 0 else -RING))
		mask = ShandalarWorld.magic_mask(world.terrain(at.x, at.y))
		if mask != 0:
			break
	if mask == 0:
		_empty(player, slot)
		return
	var color := 0
	while true:
		color = dice.below(6)
		if mask & (1 << color) != 0:
			break
	var vc := player.lairs_explored / 8 + _wins_against(player, color)
	var draw := dice.below(clampi(128 / (vc + 4), 6, 20)) + 5 / (vc + 1)
	var tier := TIERS[draw] if draw < TIERS.size() else 0
	if tier == 10:
		var roll := dice.below(200)
		tier = 10 if roll < 50 else 11 if roll < 85 else 12 if roll < 115 else 13 if roll < 142 \
			else 14 if roll < 165 else 16 if roll < 185 else 18
	if tier != 0:
		if player.difficulty == 0 and slot == 5:
			return
		var now := player.monster_timer
		var since := 0
		if slot < world.lair_respawn.size():
			since = world.lair_respawn[slot]
		var wait := (4 - player.difficulty) * 373248000 / ((now / 15) * (now / 15) + 2309 * 2309)
		if wait > now - since:
			return
	_empty(player, slot)
	var entry := {"slot": slot, "kind": "lair" if tier == 0 else "creature",
		"x": at.x * 32 + 16, "y": at.y * 32 + 16, "color": color}
	if tier != 0:
		entry["tier"] = tier
		entry["waiting"] = true
	elif color >= 1 and color <= 5 and AdventurePlayer.COLORS[color - 1] in player.defeated_wizards:
		if player.defeated_wizards.size() > 1:
			return
		entry["color"] = 2 if AdventurePlayer.COLORS[0] in player.defeated_wizards else 1
	if world.tile_flags(at.x, at.y) & ShandalarWorld.SITE != 0:
		return
	for other in player.monsters:
		if int(other["x"]) == int(entry["x"]) and int(other["y"]) == int(entry["y"]):
			return
	player.monsters.append(entry)


## The duels the hero has won against creatures of colour [param color]
## (0 colourless, 1 black … 5 white).
static func _wins_against(player: AdventurePlayer, color: int) -> int:
	var count := 0
	for win in player.duel_victories:
		var hue: Variant = (win as Dictionary).get("color", -1) if win is Dictionary else -1
		if hue is String:
			hue = AdventurePlayer.COLORS.find(String(hue)) + 1
		if int(hue) == color:
			count += 1
	return count
