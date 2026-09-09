class_name CounterMarks
extends RefCounted
## THE COUNTER STONES — what a small card wears for the counters on it,
## and what its cue card says about them. [1997], 2026-09-08.
##
## The original drew a permanent's counters as a row of little oval
## STONES across the top of the card's art (`Cardcounters.pic`, 24 stones
## in one column) and named them on the cue card, one string per card:
## `@CUECARD_COUNTERS_OsaiVultures` = `Carrion counters: %d`
## (`Program/UIStrings.txt:745-840`, latin-1 — GNU grep prints nothing
## without `-a`; the s30 copy `assets/text/Uistrings.txt` is the clean
## 1997 text, Manalink's own copy shortens the Unstable Mutation line).
## Neither the file nor the strings had been imported until today —
## `docs/card-states.md` §3.7 carried the gap as deliberate, and the
## owner's 2026-09-08 note closed it: *"no small card draws its counters
## ... That's a [1997] item."*
##
## TWO TABLES, BOTH THE EXECUTABLE'S OWN, and they are keyed differently:
##
##  * **The stone is chosen BY CARD.** `Magic.exe` 0x4d4ca0
##    (`get_counter_type_by_id`, a switch on the card's csv id — read off
##    the disassembly with `objdump -d --start-address=0x4d4ca0`, and the
##    Manalink trace names it at `src/Magic-trace.c`) maps 27 cards onto
##    22 of the 24 stones. The glyphs make sense once the table is in
##    hand: a scythe for Armageddon Clock's doom, a lightning bolt per
##    Mana Battery in the battery's colour, a gear for the two Clockworks
##    and Time Vault, an ankh per lucky charm (Throne of Bone .. Ivory
##    Cup, "Life counters"), grapes for Living Artifact's vitality, a
##    bird for Osai Vultures' carrion, a tombstone for Scavenging Ghoul's
##    corpses and Necropolis of Azar's husks, the Tetravus itself for its
##    drones, a whirl for Cyclone's wind — and a YIN-YANG for every
##    +1/+1 counter, coloured by the card that grows them: green (12),
##    black (16), artifact (18), red (20).
##  * **Counters put on OTHER cards use a fixed stone per source.**
##    `Magic.exe` 0x4d3cc0 (`draw_standard_counters`) blits five fixed
##    rows: the +1/+1 from Dwarven Weaponsmith and the −0/−1 from Orcish
##    Catapult wear the RED yin-yang (20), Unstable Mutation's −1/−1 the
##    BLUE one (22), Spirit Shackle's −0/−2 the GREY one (21) and Ashnod's
##    Transmogrant's +1/+1 the ARTIFACT one (18). The colour is the
##    SOURCE's, which is why the two stones the card table never reaches
##    — 21 and 22 — exist at all.
##
## Our engine keeps counters as `kind -> count` with no memory of the
## source ([member CardInstance.counters]), so the lookup here goes by
## the card's NAME first (its own stone and its own cue line), then by
## the KIND for the five foreign kinds above, and otherwise falls back to
## a generic `<Kind> counters: %d` with no stone — the pool's Legends and
## Dark counter kinds (pupa, glyph, sleep, mire ...) never existed in the
## 1997 game, and inventing a stone for them would be a lie about the
## art. [MiniCard] draws the lettered chip for those.
##
## What is DIFFERENT from 1997, and why: the original put down ONE STONE
## PER COUNTER, spaced to fit the band and overlapping when they did
## not. On a 132 px card a Rock Hydra's six heads would be six stones
## eleven pixels apart, glyphs unreadable; we draw ONE stone per kind
## with the COUNT beside it, and the cue card still says the number the
## 1997 way. [QoL], noted at the site in [MiniCard].


## The 24 `@CUECARD_COUNTERS_*` rows, VERBATIM and in the string table's
## own order (`UIStrings.txt:745-840`, s30's clean copy). Do not
## paraphrase them. Each row: the tag's suffix, the engine's counter kind
## the line is about, the line itself. The kinds are the ones our card
## scripts use (`cards/sets/**`), so that a card carrying a SECOND kind
## from somewhere else — a Sengir Vampire under Unstable Mutation — gets
## its own line for its own kind and the Mutation line for the other.
const CUE_ROWS: Array = [
	["ArmageddonClock", "doom", "Doom counters: %d"],
	["ManaBattery", "charge", "Charge counters: %d"],
	["ClockworkAvian", "+1/+0", "Clockwork (+1/+0) counters: %d"],
	["ClockworkBeast", "+1/+0", "Clockwork (+1/+0) counters: %d"],
	["LuckyCharms", "life", "Life counters: %d"],
	["Fungusaur", "+1/+1", "+1/+1 counters: %d"],
	["WhirlingDervish", "+1/+1", "+1/+1 counters: %d"],
	["LivingArtifact", "vitality", "Vitality counters: %d"],
	["OsaiVultures", "carrion", "Carrion counters: %d"],
	["ScavengingGhouls", "corpse", "Corpse counters: %d"],
	["SengirVampire", "+1/+1", "+1/+1 counters: %d"],
	["NecropolisOfAzar", "husk", "Husk counters: %d"],
	["Triskelion", "+1/+1", "+1/+1 counters: %d"],
	["Tetravus", "+1/+1", "Drone (+1/+1) counters: %d"],
	["TimeVault", "turn", "Turn counters: %d"],
	["Cyclone", "wind", "Wind counters: %d"],
	["CitanulDruid", "+1/+1", "+1/+1 counters: %d"],
	["RockHydra", "+1/+1", "+1/+1 counters: %d"],
	["KhabalGhoul", "+1/+1", "+1/+1 counters: %d"],
	["OrcishCatapult", "-0/-1", "Damage (-0/-1) counters: %d"],
	# `UIStrings.txt:827` in the s30 copy; Manalink's `Program/` copy
	# reads `-1/-1 counters: %d` there (Provenance.md, the "shortened"
	# note). The 1997 wording is the one kept.
	["UnstableMutation", "-1/-1", "Mutation (-1/-1) counters: %d"],
	["SpiritShackle", "-0/-2", "Shackle (-0/-2) counters: %d"],
	["DwarvenWeaponsmith", "+1/+1", "+1/+1 counters: %d"],
	# The tag is misspelled in the original ("Transmorgrant"); kept as it
	# is there, since the tag is the citation.
	["AshnodsTransmorgrant", "+1/+1", "+1/+1 counters: %d"],
]

## Which cue row a card's OWN counters use, by the card's printed name.
## One tag serves the five Mana Batteries and one the five lucky charms
## — the string table has one line for each family. Scavenging Ghoul's
## tag is plural in the table; the card is singular in every set.
##
## A KEY MUST BE THE CARD'S PRINTED NAME, accents and all: a key that
## does not match falls through to [constant ROW_BY_KIND] in silence, and
## the card wears the wrong stone rather than none. "Khabál Ghoul" was
## keyed without its accent and wore Dwarven Weaponsmith's red yin-yang
## instead of its own black one until 2026-09-09;
## `test_every_card_the_tables_name_is_in_the_pool` now pins every key.
const ROW_BY_CARD := {
	"Armageddon Clock": "ArmageddonClock",
	"Black Mana Battery": "ManaBattery",
	"Blue Mana Battery": "ManaBattery",
	"Green Mana Battery": "ManaBattery",
	"Red Mana Battery": "ManaBattery",
	"White Mana Battery": "ManaBattery",
	"Clockwork Avian": "ClockworkAvian",
	"Clockwork Beast": "ClockworkBeast",
	"Throne of Bone": "LuckyCharms",
	"Crystal Rod": "LuckyCharms",
	"Wooden Sphere": "LuckyCharms",
	"Iron Star": "LuckyCharms",
	"Ivory Cup": "LuckyCharms",
	"Fungusaur": "Fungusaur",
	"Whirling Dervish": "WhirlingDervish",
	"Living Artifact": "LivingArtifact",
	"Osai Vultures": "OsaiVultures",
	"Scavenging Ghoul": "ScavengingGhouls",
	"Sengir Vampire": "SengirVampire",
	"Necropolis of Azar": "NecropolisOfAzar",
	"Triskelion": "Triskelion",
	"Tetravus": "Tetravus",
	"Time Vault": "TimeVault",
	"Cyclone": "Cyclone",
	"Citanul Druid": "CitanulDruid",
	"Rock Hydra": "RockHydra",
	"Khabál Ghoul": "KhabalGhoul",
}

## The cue row for a counter KIND a card was GIVEN by another card — the
## five "standard" counters of `Magic.exe` 0x4d3cc0, each named by its
## 1997 source's own line. `+1/+1` takes the Weaponsmith's line rather
## than the Transmogrant's because the two lines are the same words.
const ROW_BY_KIND := {
	"+1/+1": "DwarvenWeaponsmith",
	"-0/-1": "OrcishCatapult",
	"-1/-1": "UnstableMutation",
	"-0/-2": "SpiritShackle",
}

## `Magic.exe` 0x4d4ca0 — the stone each card's own counters wear, by
## card. Twenty-seven cases in the switch; every other csv id returns −1
## and draws nothing. Rows of `Cardcounters.pic`, 0 at the top.
const TILE_BY_CARD := {
	"Armageddon Clock": 0,
	"Black Mana Battery": 1,
	"Blue Mana Battery": 2,
	"Green Mana Battery": 3,
	"Red Mana Battery": 4,
	"White Mana Battery": 5,
	"Clockwork Beast": 6,
	"Time Vault": 6,
	"Clockwork Avian": 6,
	"Throne of Bone": 7,
	"Crystal Rod": 8,
	"Wooden Sphere": 9,
	"Iron Star": 10,
	"Ivory Cup": 11,
	"Fungusaur": 12,
	"Citanul Druid": 12,
	"Whirling Dervish": 12,
	"Living Artifact": 13,
	"Osai Vultures": 14,
	"Scavenging Ghoul": 15,
	"Sengir Vampire": 16,
	"Khabál Ghoul": 16,
	"Necropolis of Azar": 17,
	"Triskelion": 18,
	"Tetravus": 19,
	"Rock Hydra": 20,
	"Cyclone": 23,
}

## `Magic.exe` 0x4d3cc0 — the stone for a counter kind put on a card by
## something else. The engine does not record the source, so Ashnod's
## Transmogrant's +1/+1 (the artifact stone, 18, in 1997) wears the
## Weaponsmith's red one here; the cue line is the same either way.
const TILE_BY_KIND := {
	"+1/+1": 20,
	"-0/-1": 20,
	"-1/-1": 22,
	"-0/-2": 21,
}

## The strip's geometry, measured off `Cardcounters.pic` (24x750): 25
## cells of 24x30, the stone an oval of 22x28 inside each at (1, 1), the
## 25th cell the MASK every stone shares — index 254 inside the oval,
## 255 outside — which is why the file is one column and not the
## side-by-side image+mask pair the other sprites are.
const CELL_W := 24
const CELL_H := 30
const STONE := Rect2i(1, 1, 22, 28)
const STONE_COUNT := 24
const MASK_ROW := 24

## The skin key `tools/import_original.py` gives the strip.
const SKIN_KEY := "card_counters"


## The 1997 cue line for [param count] counters of [param kind] on the
## card named [param card_name], filled in; or the generic
## `<Kind> counters: %d` when neither table has a line for it.
static func cue(card_name: String, kind: String, count: int) -> String:
	return cue_template(card_name, kind) % count


## The unfilled line — the `%d` still in it — so a test can pin the
## words apart from the number.
static func cue_template(card_name: String, kind: String) -> String:
	var tag: String = ROW_BY_CARD.get(card_name, "")
	if tag != "":
		var row := _row(tag)
		if row[1] == kind:
			return row[2]
	tag = ROW_BY_KIND.get(kind, "")
	if tag != "":
		return _row(tag)[2]
	return "%s counters: %%d" % kind.capitalize()


## Which stone a card's counters of [param kind] wear, or −1 for none.
static func tile_for(card_name: String, kind: String) -> int:
	var tag: String = ROW_BY_CARD.get(card_name, "")
	if tag != "" and _row(tag)[1] == kind and TILE_BY_CARD.has(card_name):
		return TILE_BY_CARD[card_name]
	return TILE_BY_KIND.get(kind, -1)


static func _row(tag: String) -> Array:
	for row in CUE_ROWS:
		if row[0] == tag:
			return row
	return ["", "", ""]


## One stone cut out of the strip and masked, at its native 22x28, or
## null when the skin does not carry the strip (the clean skin) or the
## row is out of range. Cached per row for the run — the same texture on
## every Sengir Vampire on the table.
##
## The decode is [method MiniCard.masked_sprite]'s rule applied
## vertically with one mask for all: the mask cell's own corner is
## background, so whichever it reads — alpha 0 in the s30 `card/`
## conversion, a dark index in the `screens/duel/` one — is what comes
## out transparent, and no per-file polarity table is needed. One thing
## that rule does not cover: inside the stones, the glyph's black INK is
## index 255, the index the s30 conversion hangs its tRNS on, so it
## loads at alpha 0 and would punch holes through the bolt and the ankh.
## A pixel that is transparent in the IMAGE half is ink, and is painted
## back opaque black before the mask is applied.
static var _tile_cache: Dictionary = {}

static func tile(row: int) -> Texture2D:
	if _tile_cache.has(row):
		return _tile_cache[row]
	var result: Texture2D = null
	var sheet := GameSkin.texture(SKIN_KEY)
	if sheet != null and row >= 0 and row < STONE_COUNT \
			and sheet.get_height() >= CELL_H * (MASK_ROW + 1) \
			and sheet.get_width() >= CELL_W:
		var full := sheet.get_image()
		var img := full.get_region(Rect2i(0, row * CELL_H, CELL_W, CELL_H))
		var mask := full.get_region(Rect2i(0, MASK_ROW * CELL_H, CELL_W, CELL_H))
		img.convert(Image.FORMAT_RGBA8)
		mask.convert(Image.FORMAT_RGBA8)
		var corner := mask.get_pixel(0, 0)
		var mask_has_alpha := corner.a < 0.5
		var clear_is_bright := corner.r > 0.5
		for y in CELL_H:
			for x in CELL_W:
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					px = Color.BLACK
				var m := mask.get_pixel(x, y)
				if mask_has_alpha:
					px.a = m.a
				else:
					px.a = (1.0 - m.r) if clear_is_bright else m.r
				img.set_pixel(x, y, px)
		result = ImageTexture.create_from_image(img.get_region(STONE))
	_tile_cache[row] = result
	return result


## Forget the cut stones. [method GameSkin.clear_caches] does not reach
## the derived caches ([member MiniCard._badge_cache] is the same shape)
## — a skin arriving mid-game restarts the duel screen instead — so this
## is for a test that takes the strip away from a running widget.
static func clear_cache() -> void:
	_tile_cache.clear()
