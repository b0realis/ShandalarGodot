class_name WorldMagic
extends RefCounted
## CASTING THE WORLD MAGICS (the owner, 2026-10-23: *"implement all items
## you suggest"* — "click a lit icon, or press keys 1–5, to use the five
## that spend an amulet"). The 1997 game, read in 1.3's
## `UpdateAdventureWorldInputAndMovement` (0055e808, the keys `1`–`5`) and
## `HandleWorldMagicChoiceControlEvent` (004ff888, a click on the frame's
## icon, which plays the colour's `…wm.wav` and queues the same key):
##  - key N casts the World Magic of bit 2N — 1 Conjurer's Will (black),
##    2 Leap of Fate (blue), 3 Quickening (green), 4 Staff of Thunder (red),
##    5 Sword of Resistance (white) — when it is owned and an amulet of its
##    colour is left; otherwise nothing happens;
##  - the amulet is RISKED, not spent (`@WORLDMAGIC_EXPLAINS`: "Risk one
##    blue amulet…"): `internal_rand(4 − difficulty) == 0` takes it — one
##    time in four for an Apprentice, every time for a Wizard — drawn
##    before the magic works;
##  - Conjurer's Will opens the deck builder with the cards free to move;
##    Leap of Fate draws tiles (x, then y, each `internal_rand(64)`) until
##    one is land and sets the hero in its middle ("JUMP!"); Quickening
##    gives 150 ticks of a unit more each step ("SPEED!"); Staff of
##    Thunder takes the nearest roaming creature of slots 0–5 off the map,
##    however far ("THUNDERED on: %s!"); Sword of Resistance takes the hero
##    to the creature besieging a town, slot 7 ("Went to aid of %s").
##  - Nothing asks first and nothing is said: the journal keeps the line
##    (`@LOGSTRINGS`).
##
## OURS [QoL]: a magic with nothing to work on — no creature roaming, no
## town besieged, no cards yet to move — says so and risks nothing (the
## original drew the dice and could take the amulet all the same), and a
## cast says what it did beside the panel.

## The five that are cast, by key: their World Magic and their amulet.
const KEYS: Array[String] = ["Conjurer's Will", "Leap of Fate", "Quickening",
	"Staff of Thunder", "Sword of Resistance"]
## Quickening's ticks (`worldmagic_duration = 0x96`).
const QUICKENING_TICKS := 150
## The siege's creature is kept in roaming slot 7; slots 0–5 roam.
const SIEGE_SLOT := 7
const ROAMING_SLOTS := 6


## The key (1–5) that casts World Magic [param magic_name], 0 for none.
static func key_of(magic_name: String) -> int:
	return KEYS.find(magic_name) + 1


## The amulet colour key [param key] (1–5) risks.
static func amulet_of(key: int) -> String:
	return AdventurePlayer.COLORS[key - 1]


## Whether key [param key]'s magic can be cast now: owned, an amulet left.
static func ready_to_cast(player: AdventurePlayer, key: int) -> bool:
	return key >= 1 and key <= 5 and player.owns(KEYS[key - 1]) \
		and int(player.amulets.get(amulet_of(key), 0)) > 0


## CAST the magic of key [param key] (1–5) for [param player]: `{cast,
## said, moved, deck, spent}` — whether it was cast, the words for the
## screen, whether the hero now stands elsewhere, whether the deck should
## open, whether the amulet was taken.
static func cast(player: AdventurePlayer, key: int) -> Dictionary:
	var out := {"cast": false, "said": "", "moved": false, "deck": false, "spent": false}
	if key < 1 or key > 5:
		return out
	var magic: String = KEYS[key - 1]
	var color := amulet_of(key)
	if not player.owns(magic):
		out["said"] = "%s is not yours yet." % magic
		return out
	if int(player.amulets.get(color, 0)) <= 0:
		out["said"] = "No %s amulet left to power %s." % [color, magic]
		return out
	var target := -1
	match key:
		1:
			if player.cards.is_empty():
				out["said"] = "No cards to change yet: the starting deck comes with the 1997 card rarities."
				return out
		4:
			target = nearest_roaming(player)
			if target < 0:
				out["said"] = "No creature roams near enough to strike."
				return out
		5:
			if siege_creature(player).is_empty():
				out["said"] = "No town is under siege."
				return out
	var dice := MsvcRandom.new(player.dice)
	if dice.below(4 - clampi(player.difficulty, 0, 3)) == 0:
		player.amulets[color] = int(player.amulets[color]) - 1
		out["spent"] = true
	out["cast"] = true
	match key:
		1:
			out["deck"] = true
			out["said"] = "Conjurer's Will: your deck, to change out here."
		2:
			var x := 0
			var y := 0
			while true:
				x = dice.below(64)
				y = dice.below(64)
				if player.world.is_land(x, y):
					break
			player.position = Vector2i(x * 32 + 16, y * 32 + 16)
			out["moved"] = true
			player.log_event("magic", "JUMP!")
			out["said"] = "Leap of Fate: you stand elsewhere in Shandalar."
		3:
			player.quickening = QUICKENING_TICKS
			player.log_event("magic", "SPEED!")
			out["said"] = "Quickening: a burst of speed."
		4:
			var creature: Dictionary = player.monsters[target]
			var called := String(creature.get("name", "creature"))
			player.monsters.remove_at(target)
			player.log_event("magic", "THUNDERED on: %s!" % called)
			out["said"] = "Staff of Thunder: the %s is struck from the land." % called
		5:
			var siege := siege_creature(player)
			player.position = Vector2i((int(siege["x"]) & ~31) + 16, (int(siege["y"]) & ~31) + 31)
			out["moved"] = true
			var town := WorldNames.site_name(player.world, int(siege.get("town", -1)))
			player.log_event("magic", "Went to aid of %s" % town)
			out["said"] = "Sword of Resistance: to the aid of %s!" % town
	player.dice = dice.state
	if out["spent"]:
		out["said"] += " The %s amulet is spent." % color
	return out


## The roaming creature (slots 0–5) nearest the hero, as an index into
## [member AdventurePlayer.monsters], or -1 (1.3's `ApproximateDistance`,
## [method WorldGenerator.distance]): never a lair, as in 1997, nor a
## creature still waiting for the duels unseen ([WorldLairs]).
static func nearest_roaming(player: AdventurePlayer) -> int:
	var best := -1
	var best_distance := 0x7fff
	for i in player.monsters.size():
		var creature: Dictionary = player.monsters[i]
		if int(creature.get("slot", -1)) < 0 or int(creature.get("slot", -1)) >= ROAMING_SLOTS:
			continue
		if String(creature.get("kind", "")) == "lair" or bool(creature.get("waiting", false)):
			continue
		var d := WorldGenerator.distance(player.position.x - int(creature.get("x", 0)),
			player.position.y - int(creature.get("y", 0)))
		if d < best_distance:
			best_distance = d
			best = i
	return best


## The creature besieging a town (slot 7), or `{}`.
static func siege_creature(player: AdventurePlayer) -> Dictionary:
	for creature in player.monsters:
		if int((creature as Dictionary).get("slot", -1)) == SIEGE_SLOT:
			return creature
	return {}
