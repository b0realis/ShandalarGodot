class_name StarterDeck
extends RefCounted
## THE HERO'S FIRST CARDS — the 1997 game's `AddRandomStarterDeckCards`
## (004be0bf in 1.3) as `InitializeNewGameState` (004bdd0a) calls it, by
## its rules, on this game's base cards:
##  - by difficulty, the hero's colour gets so many basic lands, spells and
##    creatures and one rare; then more colours, drawn by the dice among
##    those not yet used (`PickRandomColorBitExcludingMask`), get theirs —
##    a Wizard's second share takes any colour ([constant QUOTAS]);
##  - lands are the colour's basic land;
##  - each spell is, on a coin toss, an artifact or an ENCHANTMENT of the
##    colour (the type mask is 0x04 or 0x40: 1.3's code at 0x4be1b1–0x4be1ba,
##    the retail game's alike — never an instant or a sorcery); the first,
##    third, fifth… may be uncommon, the others only common;
##  - creatures are of the colour, never with swampwalk or islandwalk
##    (`static_ability & 3`), the same uncommon-common turns, and no more
##    copies than the collection allows (`GetRemainingAllowedCardCopies`:
##    one while it holds under 40 cards) — until a thousand draws have
##    found none new, when a second copy may come;
##  - the rare is a creature, an enchantment or a sorcery of the colour or
##    colourless, rarity rare or more;
##  - A SHARE WITHOUT A RARE ENDS ON ONE MORE COPY OF ITS LAST CREATURE: the
##    call's last add stands outside its rare block (1.3's machine code at
##    0x4be3f8 jumps over the rare straight to it; the retail game's raw
##    code has it outside too), and adds whatever card was picked last —
##    the share's last creature — with no copy count asked. So a Magician
##    starts with 40 cards, a Sorcerer and a Wizard with 46, as every 1997
##    player did [1997, the owner's ruling of 2026-10-27];
##  - an Apprentice's spells and rare skip the landwalkers too; no card made
##    for ante, no dungeon's treasure (`extra_ability & 0x900`), only the
##    base set (`expansion & 0xc1`).
##
## OURS: the base set is the cards printed in Unlimited or Fourth Edition,
## each at its first printing's rarity — the rarity the 1997 game read from
## `Rarity.csv`'s original set. The dice are the adventure's, drawing among
## the cards that fit, where 1997 drew any card and threw back the ones that
## did not: the same odds, not the same cards. Under the Classic MTG rules
## the last creature's extra copy is not added past the rules' allowance
## [ours].
##
## AS PLAYED, NOT CHANGED: 1.3's Apprentice has a second quota, 13 lands,
## 7 spells, 15 creatures, behind a test that can never be true (`(mask <
## 1) & 0x20`: a 0 or a 1 tested against 0x20 — the machine code at
## 0x4bde0e–0x4bde16 always jumps on to 13/12/10, and the retail game's
## Ghidra output drops the block as unreachable); every Apprentice, of any
## colour, starts with 13, 12, 10 and a rare, 36 cards ([constant QUOTAS]
## row 0).

## The shares by difficulty: `[colour, lands, spells, creatures, rare]`,
## the colour `own`, `other` (a colour not yet used) or `any`.
const QUOTAS := [
	[["own", 13, 12, 10, true]],
	[["own", 11, 4, 12, true], ["other", 4, 3, 4, false]],
	[["own", 9, 3, 9, true], ["other", 5, 3, 4, false], ["other", 4, 3, 3, false]],
	[["own", 6, 3, 5, true], ["any", 11, 5, 14, false]],
]
const BASICS := {"black": "Swamp", "blue": "Island", "green": "Forest", "red": "Mountain",
	"white": "Plains"}
const MASKS := {"black": Mtg.ManaColor.B, "blue": Mtg.ManaColor.U, "green": Mtg.ManaColor.G,
	"red": Mtg.ManaColor.R, "white": Mtg.ManaColor.W}
const RARITIES := {"common": 1, "uncommon": 2, "rare": 3, "special": 4, "mythic": 4}
const BASE_SETS: Array[String] = ["2ed", "4ed"]

## The base cards, read once: `{name, color, kind, rarity, walker,
## rare_type, enchantment}` — the colour a key of [constant MASKS], ""
## colourless or "gold"; the kind `creature`, `artifact`, `spell` (an
## instant, a sorcery or an enchantment — the coloured spell's
## `enchantment`, the rare's `rare_type`) or `other`.
static var _cards: Array[Dictionary] = []


## THE FIRST DECK of a hero of [param color] at [param difficulty]: card
## names, drawn with [param dice]. Under the Classic MTG rules ([param
## classic]) no card comes once the deck holds as many copies as they allow
## under the adventure's ban list [param bans] ([method
## DeckModel.classic_allowance]: four, one of a restricted card, none of a
## banned one; [ClassicBans]) [ours].
static func deal(color: String, difficulty: int, dice: MsvcRandom, classic := false, bans := "") -> Array[String]:
	var dealt: Array[String] = []
	_keeps = Callable()
	if classic:
		_keeps = func(card: Dictionary) -> bool:
			var most := DeckModel.classic_allowance(String(card["name"]), false, bans)
			return most < 0 or dealt.count(String(card["name"])) < most
	var used: Array[String] = [color]
	for share in QUOTAS[clampi(difficulty, 0, 3)]:
		var hue := color
		match String(share[0]):
			"other":
				hue = AdventurePlayer.COLORS[0]
				while true:
					hue = AdventurePlayer.COLORS[dice.below(5)]
					if not hue in used:
						break
				used.append(hue)
			"any":
				hue = ""
		_share(dealt, hue, int(share[1]), int(share[2]), int(share[3]), bool(share[4]), difficulty, dice)
	_keeps = Callable()
	return dealt


## One call of `AddRandomStarterDeckCards`: [param hue] "" for any colour.
static func _share(dealt: Array[String], hue: String, lands: int, spells: int, creatures: int,
		rare: bool, difficulty: int, dice: MsvcRandom) -> void:
	for i in lands:
		dealt.append(BASICS[hue] if hue != "" else BASICS.values()[dice.below(5)])
	for i in spells:
		var artifact := dice.below(2) == 1
		var most := 2 if i % 2 == 0 else 1
		var spell := func(card: Dictionary, of_artifacts: bool) -> bool:
			if difficulty == 0 and bool(card["walker"]):
				return false
			if int(card["rarity"]) > most:
				return false
			if of_artifacts:
				return String(card["kind"]) == "artifact"
			return String(card["kind"]) == "spell" and bool(card["enchantment"]) and _of(card, hue)
		var picked := _pick(dice, spell.bind(artifact))
		if picked == "" and _keeps.is_valid():
			# [ours] Under the Classic MTG rules a side the allowance has
			# emptied (the one common artifact, Amulet of Kroog, a fifth
			# time) deals from the other side of the coin, so the deck keeps
			# its size.
			picked = _pick(dice, spell.bind(not artifact))
		if picked != "":
			dealt.append(picked)
	var last_creature := ""
	for i in creatures:
		var most := 2 if i % 2 == 0 else 1
		var creature := func(card: Dictionary) -> bool:
			return String(card["kind"]) == "creature" and not bool(card["walker"]) \
				and int(card["rarity"]) <= most and _of(card, hue) \
				and (hue == "" or String(card["color"]) != "")
		var picked := _pick(dice, func(card: Dictionary) -> bool:
			return creature.call(card) and copies_left(dealt, String(card["name"])) >= 1)
		# 1997 lets the copies go after a thousand draws found none new.
		if picked == "":
			picked = _pick(dice, creature)
		if picked != "":
			dealt.append(picked)
			last_creature = picked
	if rare:
		var picked := _pick(dice, func(card: Dictionary) -> bool:
			return String(card["kind"]) in ["creature", "spell"] and bool(card["rare_type"]) \
				and int(card["rarity"]) >= 3 and _of(card, hue) \
				and not (difficulty == 0 and bool(card["walker"])) \
				and copies_left(dealt, String(card["name"])) >= 1)
		if picked != "":
			dealt.append(picked)
	elif last_creature != "" and (not _keeps.is_valid() or _keeps.call({"name": last_creature})):
		# 1997's last add, outside the rare block: the last creature once
		# more, no copy count asked (see the class doc) — under the Classic
		# MTG rules only within their allowance [ours].
		dealt.append(last_creature)


## How many more copies of [param card_name] the collection [param dealt]
## allows (`GetRemainingAllowedCardCopies`, without Tome of
## Enlightenment): one while it holds under 40 cards, two from 40, three
## from 60; basic lands without end.
static func copies_left(dealt: Array[String], card_name: String) -> int:
	if card_name in BASICS.values():
		return 99
	var limit := 1
	if dealt.size() >= 40:
		limit = 2
	if dealt.size() >= 60:
		limit = 3
	return limit - dealt.count(card_name)


## Whether [param card] goes with colour [param hue] ("" any): of it, or
## colourless (`is_card_color_compatible_with_mask`).
static func _of(card: Dictionary, hue: String) -> bool:
	if hue == "":
		return String(card["color"]) != "gold"
	return String(card["color"]) == hue or String(card["color"]) == ""


## What the deal under way keeps out besides [param fits] ([method deal]'s
## classic rules), invalid for none.
static var _keeps := Callable()


static func _pick(dice: MsvcRandom, fits: Callable) -> String:
	var fitting: Array[String] = []
	for card in cards():
		if fits.call(card) and (not _keeps.is_valid() or _keeps.call(card)):
			fitting.append(String(card["name"]))
	if fitting.is_empty():
		return ""
	return fitting[dice.below(fitting.size())]


## The base cards a first deck is drawn from (see the class doc), read
## from the card registry once.
static func cards() -> Array[Dictionary]:
	if not _cards.is_empty():
		return _cards
	CardRegistry.ensure_loaded()
	var barred: Array[String] = DeckFormat.BANNED.duplicate()
	for row in ShandalarWorld.DUNGEON_CARDS:
		barred.append(String(row[1]))
	var names: Array = CardRegistry.all_names()
	names.sort()
	for card_name in names:
		var name_text := String(card_name)
		if name_text in barred or name_text in BASICS.values():
			continue
		var base := false
		for code in BASE_SETS:
			if CardRegistry.printed_rarity(name_text, code) != "":
				base = true
		if not base:
			continue
		var data := CardRegistry.get_card(name_text)
		if data == null or data.is_land():
			continue
		var color := ""
		var mask := data.color_mask()
		for hue in MASKS:
			if mask == MASKS[hue]:
				color = hue
		if mask != 0 and color == "":
			color = "gold"
		var kind := "other"
		if data.is_creature():
			kind = "creature"
		elif data.is_type(Mtg.CardType.ARTIFACT):
			kind = "artifact"
		elif data.is_type(Mtg.CardType.INSTANT) or data.is_type(Mtg.CardType.SORCERY) \
				or data.is_type(Mtg.CardType.ENCHANTMENT):
			kind = "spell"
		var walks := data.landwalk.has("swamp") or data.landwalk.has("island")
		_cards.append({"name": name_text, "color": color, "kind": kind,
			"rarity": int(RARITIES.get(CardRegistry.rarity_of(name_text).to_lower(), 1)),
			"walker": walks,
			"rare_type": data.is_creature() or data.is_type(Mtg.CardType.ENCHANTMENT)
				or data.is_type(Mtg.CardType.SORCERY),
			"enchantment": data.is_type(Mtg.CardType.ENCHANTMENT)})
	return _cards
