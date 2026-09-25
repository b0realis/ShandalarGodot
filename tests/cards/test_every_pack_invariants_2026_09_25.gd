extends GameTest
## EVERY PACK, EVERY INVARIANT (2026-09-25).
##
## The registry-wide invariants of this suite were written over the base
## pool, and most of them still run over it alone — the gate has no pack
## enabled unless a test asks. The cast-gate arity sweep and the LAN card
## boundary already ask; the per-card invariants below did not, so a pack
## card could fall through any of them without a word: a draw replacement
## shipped without its `applies` half, oracle text the mana-symbol splitter
## cannot rebuild, a layer-4 land-type reader that would void the two-wave
## dependency analysis, an Aura the AI aims at its own board by default, a
## token-making ability the planner cannot see.
##
## This file enables all seven packs from the suite's own metadata-only
## archives (run_tests.sh sets SHANDALAR_PACK_1..7; one registry reload)
## and asks the pack cards. The base pool keeps its own pins in the tests
## these are drawn from — a player with no pack installed loses nothing —
## so where a list is compared, the names the base tests already vouch for
## are left out and only the pack cards answer.

const ALL_PACKS: Array[String] = [CardPacks.ID, FallenEmpiresPack.ID,
	IceAgePack.ID, HomelandsPack.ID, AlliancesPack.ID, PortalPack.ID,
	FifthEditionPack.ID]

## The base pool as the suite sees it with no pack enabled, taken before
## the packs are; the names a pack adds are `_pack_names`.
var _base: Dictionary = {}
var _pack_names: Array[String] = []


func before_each() -> void:
	_base.clear()
	for card_name in CardRegistry.all_names():
		_base[card_name] = true
	Settings.set_enabled_card_packs(ALL_PACKS)
	CardPacks.rescan()
	for id in ALL_PACKS:
		assert_true(CardPacks.is_enabled(id), id + " is available to the suite")
	_pack_names.clear()
	for card_name in CardRegistry.all_names():
		if not _base.has(card_name):
			_pack_names.append(String(card_name))
	super()


func after_each() -> void:
	g = null
	Settings.set_enabled_card_packs([] as Array[String])
	CardPacks.rescan()


func test_the_packs_add_a_thousand_identities_to_the_base_pool() -> void:
	assert_gt(_base.size(), 890, "the base pool")
	assert_gt(_pack_names.size(), 990, "the seven packs' own identities")
	assert_eq(CardRegistry.all_names().size(), _base.size() + _pack_names.size())


# ------------------------------------------------------------ the engine --

## From test_replacement_choice: the CR 616.1 candidate list needs the
## predicate half of every static draw replacement.
func test_every_pack_draw_replacement_has_a_pure_predicate() -> void:
	var missing: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data.draw_replacement.is_valid() \
				and not data.draw_replacement_applies.is_valid():
			missing.append(card_name)
	assert_eq(missing, [] as Array[String], "a draw replacement with no `applies` half")


## From test_layer_order: the base pool's two-wave layer analysis holds
## because ONE card reads a land type in layer 4. Ice Age brings two more,
## and a reader can then depend on a reader (Illusionary Terrain set to
## "Plains are Forests" under Conversion), which is what the readers' own
## dependency ordering is for — test_layer_four_readers pins it. A fourth
## reader must say what it reads and writes, and the sweep names it here.
func test_the_packs_bring_exactly_two_more_layer_four_readers() -> void:
	var readers: Array[String] = []
	for card_name in CardRegistry.all_names():
		for ability in CardRegistry.get_card(card_name).static_abilities:
			if ability.reads_land_types:
				readers.append(card_name)
				var edge: Array = ability.land_type_edge(null) \
					if not ability.land_types_edge.is_valid() else [[], []]
				assert_true(ability.land_types_edge.is_valid()
					or (not edge[0].is_empty() and not edge[1].is_empty()),
					"%s says what it reads and writes" % card_name)
	readers.sort()
	assert_eq(readers, ["Conversion", "Glaciers", "Illusionary Terrain"] as Array[String],
		"a new layer-4 land-type reader needs the dependency step re-checked")


# ---------------------------------------------------------------- the UI --

## From test_mana_text: the symbol splitter is lossless over the whole pool
## and every code it meets is on the 1997 sheet, or is {C}.
func test_no_pack_card_loses_a_character_to_the_mana_text_split() -> void:
	var codes := {}
	for card_name in _pack_names:
		var text: String = CardRegistry.get_card(card_name).oracle_text
		var back := ""
		for run in ManaText.runs(text):
			if run[0] == "s":
				codes[run[1]] = true
			back += run[1] if run[0] == "t" else "{" + String(run[1]) + "}"
		assert_eq(back, text, "%s survives the split" % card_name)
	var off_sheet := PackedStringArray()
	for code in codes:
		if not ManaIcons.CELL.has(code):
			off_sheet.append(code)
	assert_eq(str(off_sheet), str(PackedStringArray(["C"])),
		"only {C} is off the 1997 sheet; a new one would need a decision")


# ---------------------------------------------------------------- the AI --

## From test_ai_aftermath: a trigger that opts into the AI's aftermath
## forecast is a reviewed public payload — damage or death, no target, no
## modes — and the opted set is a deliberate list, not a default.
func test_only_reviewed_pack_triggers_opt_into_aftermath() -> void:
	var opted: Array[String] = []
	for card_name in _pack_names:
		var data := CardRegistry.get_card(card_name)
		for trigger in data.triggered_abilities + data.graveyard_triggers:
			if not trigger.forecast_safe: continue
			opted.append(card_name)
			assert_has([Mtg.EventType.DAMAGE_DEALT, Mtg.EventType.DIES], trigger.event_type)
			assert_null(trigger.target_spec)
			assert_true(trigger.modes.is_empty())
	opted.sort()
	assert_eq(opted, ["Baron Sengir", "Sengir Bats"] as Array[String],
		"the two Homelands death triggers of Sengir Vampire's shape, and no other")


## From test_ai_targeting: an Aura nobody classified is aimed at OUR OWN
## board. Every pack Aura is decided by a structural signal, named in
## EffectIntent.AURA_HOSTILE, or swept and listed here as a deliberate
## friendly.
func test_every_pack_aura_is_classified() -> void:
	# Swept 2026-09-25: pumps, grants, wards and engines the pack Auras
	# put on our own creature or land; the three that hurt their host are
	# in AURA_HOSTILE, and so is Aggression since the owner's ruling the
	# same day — removal for a body that will not attack into us, with
	# the friendly exception (a big attacker that lacks trample) decided
	# per board by AiPlayer, not by this table. See test_ai_aggression.
	const REVIEWED_FRIENDLY: Array[String] = [
		"Armor of Faith", "Awesome Presence", "Bestial Fury",
		"Black Scarab", "Blue Scarab", "Carapace", "Caribou Range",
		"Casting of Bones", "Chromatic Armor", "Cloak of Confusion", "Cooperation",
		"Earthlore", "Errantry", "False Demise", "Farrel's Mantle",
		"Feast of the Unicorn", "Forbidden Lore", "Fylgja", "Gift of the Woods",
		"Green Scarab", "Hot Springs", "Imposing Visage", "Kjeldoran Pride",
		"Krovikan Fetish", "Krovikan Plague", "Leshrac's Rite", "Mystic Might",
		"Nature's Chosen", "Prismatic Ward", "Red Scarab", "Snow Devil",
		"Soul Kiss", "Spectral Shield", "Stonehands", "Thrull Retainer",
		"Tourach's Gate", "Veteran's Voice", "Viscerid Armor", "White Scarab",
		"Wings of Aesthir",
	]
	var unclassified: Array[String] = []
	var auras := 0
	for card_name in _pack_names:
		var data := CardRegistry.get_card(card_name)
		if not data.is_aura():
			continue
		auras += 1
		var expected: int = EffectIntent.Aim.HOSTILE \
			if (EffectIntent.AURA_HOSTILE.has(card_name) or data.aura_steals) \
			else EffectIntent.Aim.FRIENDLY
		assert_eq(EffectIntent.aura_aim(data), expected, "%s's aim" % card_name)
		if EffectIntent.aura_is_classified(data) or REVIEWED_FRIENDLY.has(card_name):
			continue
		unclassified.append(card_name)
	assert_gt(auras, 40, "the packs really do hold that many Auras")
	assert_eq(unclassified, [] as Array[String],
		"a pack Aura nobody classified defaults to OUR OWN board — sweep it and "
		+ "put it in AURA_HOSTILE or in this test's REVIEWED_FRIENDLY list")


## From test_ai_token_ability: an activated ability that makes a token is
## one the planner can price, or it never uses it. The five base makers
## build their token in a Callable the reader cannot look inside and have
## a TOKEN_MAKERS row each; the pack makers build theirs from a
## CreateTokenEffect the reader sees for itself, so the body is asked of
## the reader here rather than of the table. Caribou Range's own line
## only SACRIFICES a token (the maker is the ability it grants the land).
## Homarid Spawning Bed is refused on the base file's own ruling: a row
## states what ONE activation GUARANTEES, and "X is the sacrificed
## creature's mana value" guarantees nothing — a Camarid fed back to it
## makes no Camarid at all.
func test_every_pack_token_ability_is_priced_by_the_planner() -> void:
	const NAMES_A_TOKEN_BUT_MAKES_NONE: Array[String] = ["Caribou Range"]
	const REFUSED_FOR_THE_SACRIFICE: Array[String] = ["Homarid Spawning Bed"]
	var unlisted: Array[String] = []
	var priced: Array[String] = []
	for card_name in _pack_names:
		var data := CardRegistry.get_card(card_name)
		for ability in data.activated_abilities:
			var line := ability.text.to_lower().replace("nontoken", "")
			if not line.contains("token"):
				continue
			if NAMES_A_TOKEN_BUT_MAKES_NONE.has(card_name) \
					or REFUSED_FOR_THE_SACRIFICE.has(card_name):
				continue
			var intent := EffectIntent.read(ability.effects, card_name)
			if intent.makes_token.is_empty():
				unlisted.append(card_name)
				continue
			assert_false(EffectIntent.TOKEN_MAKERS.has(card_name),
				"%s is read, not tabled" % card_name)
			assert_gt(int(intent.makes_token.get("toughness", 0)), 0,
				"%s's token has a body" % card_name)
			priced.append(card_name)
	assert_eq(unlisted, [] as Array[String],
		"an activated ability makes a token the planner cannot price")
	priced.sort()
	assert_eq(priced, ["Drudge Spell", "Elvish Farmer", "Goblin Warrens",
		"Kjeldoran Outpost", "Night Soil", "Thallid", "Thallid Devourer",
		"Wall of Kelp"] as Array[String])
	for refused in REFUSED_FOR_THE_SACRIFICE:
		assert_false(EffectIntent.TOKEN_MAKERS.has(refused), refused + " stays refused")
