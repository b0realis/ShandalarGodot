class_name TownStatus
extends RefCounted
## A SITE'S STATUS WORD — 1.3's `status_and_ruling_wizard`, the one number
## each of the 128 site slots carries ([member ShandalarWorld.sites]'
## `status`). Every reader and writer of its bits goes through here, so
## what a bit means is said once:
##
## | Bit    | Name        | Meaning                                      |
## |--------|-------------|----------------------------------------------|
## | 0x0001 | LINKED      | The hero has a mana link with the town.      |
## | 0x0002 | VISITED     | The hero has been in it (the city list, F3). |
## | 0x0004 | NO_QUESTS   | A quest it gave was failed: its wise man     |
## |        |             | turns the hero away for good.                |
## | 0x0008 | PRICED      | 1997's own: the shop's prices were built.    |
## | 0xFF00 | the ruler   | The wizard who holds it, 1 black … 5 white.  |
##
## THE MANA LINKS ARE THE HERO'S LIFE. The 1997 duel starts the hero at the
## number of towns and cities linked and held by no wizard
## (`CountDuelPoolEligibleTowns`, 1.3 `duel.c` 1893; the frame's ankh shows
## the same count), and the world is made with the first ten towns and
## cities it places linked ([WorldGenerator]): a new hero has ten. A
## letter quest adds one, a wizard who takes the town ends it — freeing the
## town does not bring it back. A link on a village counts for nothing,
## but a linked village always offers a letter to carry ([Quests]).

const LINKED := 0x0001
const VISITED := 0x0002
const NO_QUESTS := 0x0004
const PRICED := 0x0008
const RULER_SHIFT := 8
const RULER_MASK := 0xFF00


## The status word of site [param slot], 0 for no such site.
static func of(world: ShandalarWorld, slot: int) -> int:
	if world == null or slot < 0 or slot >= world.sites.size():
		return 0
	return int(world.sites[slot]["status"])


## Whether site [param slot]'s status has [param bit].
static func has(world: ShandalarWorld, slot: int, bit: int) -> bool:
	return of(world, slot) & bit != 0


## Site [param slot]'s status with [param bit] set ([param on]) or cleared.
static func put(world: ShandalarWorld, slot: int, bit: int, on := true) -> void:
	if world == null or slot < 0 or slot >= world.sites.size():
		return
	var word := of(world, slot)
	world.sites[slot]["status"] = (word | bit) if on else (word & ~bit)


# ------------------------------------------------------------ the bits --

static func linked(world: ShandalarWorld, slot: int) -> bool:
	return has(world, slot, LINKED)


static func visited(world: ShandalarWorld, slot: int) -> bool:
	return has(world, slot, VISITED)


## Whether the town's wise man turns the hero away (a quest it gave failed).
static func refuses_quests(world: ShandalarWorld, slot: int) -> bool:
	return has(world, slot, NO_QUESTS)


## The wizard who holds site [param slot]: 1 black … 5 white, 0 for none.
static func ruler(world: ShandalarWorld, slot: int) -> int:
	var wizard := (of(world, slot) & RULER_MASK) >> RULER_SHIFT
	return wizard if wizard >= 1 and wizard <= 5 else 0


## Whether a wizard holds site [param slot].
static func ruled(world: ShandalarWorld, slot: int) -> bool:
	return ruler(world, slot) != 0


## Site [param slot] taken by wizard [param wizard] (1–5): his, and its mana
## link lost.
static func take(world: ShandalarWorld, slot: int, wizard: int) -> void:
	if world == null or slot < 0 or slot >= world.sites.size():
		return
	var word := of(world, slot) & ~RULER_MASK & ~LINKED
	world.sites[slot]["status"] = word | ((clampi(wizard, 1, 5) << RULER_SHIFT) & RULER_MASK)


## Site [param slot] freed from its wizard (its link stays lost).
static func release(world: ShandalarWorld, slot: int) -> void:
	put(world, slot, RULER_MASK, false)


# ------------------------------------------------------- the mana links --

## Whether site [param slot] is a town or a city (not a village or a castle).
static func is_town(world: ShandalarWorld, slot: int) -> bool:
	if world == null or slot < 0 or slot >= world.sites.size():
		return false
	var kind := int(world.sites[slot]["type"])
	return kind == ShandalarWorld.TOWN or kind == ShandalarWorld.CITY


## THE HERO'S MANA LINKS that count: towns and cities linked and held by no
## wizard — the hero's starting life in a duel, and the ankh's number.
static func mana_links(world: ShandalarWorld) -> int:
	return linked_towns(world).size()


## The site slots of the links that count ([method mana_links]).
static func linked_towns(world: ShandalarWorld) -> Array[int]:
	var out: Array[int] = []
	if world == null:
		return out
	for slot in world.sites.size():
		if is_town(world, slot) and linked(world, slot) and not ruled(world, slot):
			out.append(slot)
	return out
