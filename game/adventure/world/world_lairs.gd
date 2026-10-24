class_name WorldLairs
extends RefCounted
## THE LAIRS ON THE MAP (the owner, 2026-10-23: *"Build all trade
## features"* — the Nomad's Bazaar, the Gemcutter's Guild, the Oasis of
## Muldoon and the Diamond Mine are lairs) AND WHAT FILLS THE ROAMING SLOTS
## — 1.3's `UpdateWorldLairAndMonsterSlots` (0055fd27, world_lair_monster_
## slots.c 384–621), its refill of the six roaming slots ([member
## AdventurePlayer.monsters]), run for each slot as the tick walks it
## ([method WorldCreatures.tick]):
##  - A slot empty, or holding something more than 4 tiles from the hero on
##    either axis, is filled again ([method fill]): a tile on the square 4
##    tiles out from the hero (half the time on its left or right side, half
##    on its top or bottom, the place along the side at random), not the
##    sea; its colour one of its land's, at random.
##  - Lair or creature: with `vc` the lairs explored / 8 and the duels won
##    against that colour, a draw of `rand(clamp(128 / (vc + 4), 6, 20)) +
##    5 / (vc + 1)` makes a lair on 3, 9, 12, 14 and 16 or more — 60 in 100
##    at first, fewer as the hero goes on — and a creature's tier otherwise
##    (4, 6, 8, or a roll of the stronger ones, 10–18). Slot 0 takes the
##    tier of the quest's creature while a creature quest is under way.
##  - A creature waits after its slot's last meeting, `(4 − difficulty) ·
##    373248000 / ((T / 15)² + 2309²)` ticks of the clock `T`, and on
##    Apprentice slot 5 holds none; the slot then keeps what it held, unmoved
##    and unmet this tick. A lair never waits.
##  - THE CREATURE ([method CreatureBook.pick]): a row of that tier and
##    colour, up to 999 draws — none found is a LAIR (so a white tier 13,
##    which no creature has, is always a lair); gone again when the hero has
##    beaten more than 8 of its kind on its colour.
##  - A BEATEN WIZARD'S COLOUR: a lair of it is black instead (blue when
##    black's wizard is the beaten one) — or gone when another wizard is
##    beaten too; a creature of it takes its other colour, or is gone when
##    it has none or that one's wizard is beaten too.
##  - Gone too: anything on a town's tile; in slot 0 anything but the
##    quest's creature while its quest is under way; a lair on another
##    slot's place.
##  - A lair is seen only within a tile of the hero ([method seen]; the
##    creatures over their whole 4 tiles, [method WorldCreatures.seen]),
##    never moves, and is entered when the hero comes within 26 of its
##    middle (1997's distance: twice the larger axis and the smaller).
##    Entered, it is SPENT AT ONCE ([method explored]) — gone, its slot's
##    meeting now, the clock on to the next 32, one more lair explored — and
##    only then is the game saved ([method WorldScreen.enter_lair]; the
##    lead's ruling C, 2026-10-23: no save may hold a lair the hero is
##    inside, or loading it would give the lair's gold again).
## [Ours: 1997 slip — slot 0 is held for the quest's creature only while
## its quest is under way (1997: from its acceptance until the next quest
## was taken, refusing every other creature and every lair there through
## the report back and after a failure), and the quest's creature keeps
## coming whatever the hero has won (1997 could make the quest impossible).]

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
## More wins than this over a creature's kind on its colour and it comes no
## more (slots.c 548–561).
const TOO_MANY_WINS := 8


## EVERY ROAMING SLOT FILLED OR KEPT, then the lair the hero has come to —
## the slot, or −1 — nothing moved and nothing met: the fill alone, for
## the tests and tools that look at it (the world's tick is [method
## WorldCreatures.tick], which walks each slot as it fills it).
static func tick(player: AdventurePlayer) -> int:
	var world := player.world
	if world == null:
		return -1
	var dice := MsvcRandom.new(player.dice)
	var hero := player.tile()
	for slot in SLOTS:
		var held := held_in(player, slot)
		if not WorldCreatures.is_live(held) or absi(hero.x - int(held["x"]) / 32) > RING \
				or absi(hero.y - int(held["y"]) / 32) > RING:
			fill(player, slot, dice)
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


## The lairs the hero can see: within a tile of them (1997's rule, kept for
## the lairs by the owner's ruling 2).
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


## SLOT [param slot] FILLED AGAIN on the adventure's [param dice] (slots.c
## 384–621, its steps lettered as in the part B notes): a lair, a creature,
## or nothing. False when a creature's gate stops the slot this tick — the
## respawn wait, Apprentice slot 5 —: it keeps what it held and neither
## moves nor is met.
static func fill(player: AdventurePlayer, slot: int, dice: MsvcRandom) -> bool:
	var world := player.world
	var hero := player.tile()
	# (a) The place: a tile of the square 4 out, not the sea.
	var at := Vector2i(-1, -1)
	var mask := 0
	for attempt in TRIES:
		if dice.below(2) != 0:
			at = Vector2i(hero.x + (RING if dice.below(2) != 0 else -RING), hero.y + dice.below(9) - RING)
		else:
			# The side's sign drawn BEFORE the offset along it, as 1997 drew
			# them (world_lair_monster_slots.c 401–403; retail the same) —
			# written in one constructor, x's offset came first (the bug pass
			# of part B).
			var dy := RING if dice.below(2) != 0 else -RING
			at = Vector2i(hero.x + dice.below(9) - RING, hero.y + dy)
		mask = ShandalarWorld.magic_mask(world.terrain(at.x, at.y))
		if mask != 0:
			break
	if mask == 0:
		_empty(player, slot)
		return true
	# (b) Its colour, one of its land's.
	var color := 0
	while true:
		color = dice.below(6)
		if mask & (1 << color) != 0:
			break
	# (c, d) A lair or a creature's tier, by the hero's experience there.
	var vc := player.lairs_explored / 8 + _wins_against(player, color)
	var draw := dice.below(clampi(128 / (vc + 4), 6, 20)) + 5 / (vc + 1)
	var tier := TIERS[draw] if draw < TIERS.size() else 0
	if tier == 10:
		var roll := dice.below(200)
		tier = 10 if roll < 50 else 11 if roll < 85 else 12 if roll < 115 else 13 if roll < 142 \
			else 14 if roll < 165 else 16 if roll < 185 else 18
	# (e) Slot 0 holds the quest's creature's tier while its quest runs.
	var wanted := WorldCreatures.quest_row(player)
	if slot == 0 and wanted != 0:
		tier = CreatureBook.tier(wanted)
	# (f) The creature's gates: Apprentice slot 5, the respawn wait.
	if tier != 0:
		if player.difficulty == 0 and slot == 5:
			return false
		var now := player.monster_timer
		var since := 0
		if slot < world.lair_respawn.size():
			since = world.lair_respawn[slot]
		var wait := (4 - player.difficulty) * 373248000 / ((now / 15) * (now / 15) + 2309 * 2309)
		if wait > now - since:
			return false
	_empty(player, slot)
	# (g) The creature drawn, or the lair.
	var row := CreatureBook.LAIR
	if tier != 0:
		row = CreatureBook.pick(dice, color, tier)
		if row != CreatureBook.LAIR and row != wanted \
				and player.wins_against(CreatureBook.kind(row), color) > TOO_MANY_WINS:
			return true
	# (h) The slot set: the tile's middle, heading 0, standing.
	var entry := {"slot": slot, "kind": "lair", "x": at.x * 32 + 16, "y": at.y * 32 + 16, "color": color}
	if row != CreatureBook.LAIR:
		entry["kind"] = "creature"
		entry["creature"] = row
		entry["heading"] = 0
		entry["frame"] = 0
	# (i) A beaten wizard's colour.
	if color >= 1 and color <= 5 and AdventurePlayer.COLORS[color - 1] in player.defeated_wizards:
		if row == CreatureBook.LAIR:
			if player.defeated_wizards.size() > 1:
				return true
			entry["color"] = 2 if AdventurePlayer.COLORS[0] in player.defeated_wizards else 1
		else:
			var other := WorldCreatures.colors_of(row) & ~(1 << color) & 0x3E
			if other == 0:
				return true
			for hue in range(1, 6):
				if other & (1 << hue) != 0 and AdventurePlayer.COLORS[hue - 1] in player.defeated_wizards:
					return true
			entry["color"] = _single_color(other)
	# (j) Never on a town's tile.
	if world.tile_flags(at.x, at.y) & ShandalarWorld.SITE != 0:
		return true
	# (k) Slot 0 holds only the quest's creature while its quest runs.
	if slot == 0 and wanted != 0 and row != wanted:
		return true
	# (l) A lair never on another slot's place.
	if row == CreatureBook.LAIR:
		for other in player.monsters:
			if int(other.get("x", -1)) == int(entry["x"]) and int(other.get("y", -1)) == int(entry["y"]):
				return true
	player.monsters.append(entry)
	return true


## 1997's `single_color_test_bit_to_color_t`: the colour (1 black …
## 5 white) of the lowest bit of [param bits].
static func _single_color(bits: int) -> int:
	for hue in range(1, 6):
		if bits & (1 << hue) != 0:
			return hue
	return 0


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
