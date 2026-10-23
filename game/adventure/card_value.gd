class_name CardValue
extends RefCounted
## WHAT A CARD IS WORTH IN SHANDALAR (the owner, 2026-10-23: *"study how,
## which cards are available where and how the price of the cards is
## determined? (We will need this card value formula for future packs). If
## no formula is available try to devise a formula based on card stats that
## mimics the prices in the original"*). The 1997 game's own formula,
## `CalculateCardShopPrice` (1.3 004f1cce), written our way:
##
##  - a land 40;
##  - a creature `(ai + power + 3) · (toughness + 3) · 5`, half as much
##    again for each of a landwalk, regeneration, rules beyond plain
##    keywords, and banding, trample or first strike; three times for a
##    power pump and three times for a toughness pump; divided by its mana
##    value + 1 (flying adds nothing);
##  - an enchantment `(mana value + ai + 1) · 25`, twice with an activated
##    ability; a sorcery `(mana value + ai + 1) · 20`; an instant
##    `ai · 20 + (mana value + 1) · 40`, half again for an X; an artifact
##    `250 / (ai + generic mana + 2)`;
##  - then the rarity: uncommon twice (at least 100), rare four times (at
##    least 200), special eight times (at least 200); then the program's
##    staples (`extra_ability` 0x200) twice and its 0x400 cards half again.
##
## THE INPUTS. With the player's 1997 program imported
## (`adventure_cards.json`, `tools/import_original.py`) every number is the
## program's own and a price is the 1997 price. Without it — and for every
## card the 1997 game never had, a pack's — the inputs are read off the
## card: its type, colours, cost, power and toughness, keywords and rules,
## and no card is a staple ([method derive]). `ai`, the program's
## hand-tuned value, starts at its type's ([constant AI_BY_TYPE]: creature
## 1, enchantment 0, sorcery 0, instant −1, artifact 1 — tuned on the 1997
## prices under cross-validation, where the type's commonest value had
## priced creatures and sorceries a fifth too dear and artifacts,
## enchantments and instants a fifth too cheap) and is moved by what the card
## DOES (the owner: *"check also if card ruling/abilities can be
## incorporated into pricing … a general formula would be valuable (not a
## lookup table)"*): the engine's own reading of a card's abilities —
## removal, burn by its damage, card drawing, counters, mana, a creature's
## body and keywords ([method AutoDeck.score]) — against the middle of the
## 1997 base cards of its type, half a step for every two spreads
## ([constant STRENGTH_MIDDLE], [method strength_step]).
##
## HOW CLOSE (measured 2026-10-23 on the 339 cards a 1997 shop can sell,
## against the program's own prices): the card's own inputs give a price
## within a quarter of the 1997 one for 60 in 100 and within a half for 82
## (median 20% off; the type defaults tuned on nine tenths and measured on
## the tenth held out, ten times over: 59 and 82). The 1997 staples come
## out at the 53rd percentile of their type and rarity, against the 29th
## with no ability term. The 1997
## hand-tuned values follow no reading of the cards' strength — not their
## stats, nor their abilities (rank correlation -0.15 to 0.21 with the
## engine's rating). Fitted under ten-fold cross-validation on every
## feature the engine reads off a card — type, cost, body, keywords, its
## roles and effects, its rules' words — a ridge formula came within a
## quarter for 40 in 100, the 1997 structure times a fitted correction for
## 51, and even gradient boosting, no formula at all, for 47: the 1997
## structure is itself the best general formula, and the rest of a 1997
## price is hand-tuning no reading of the card predicts. So abilities move
## a price only by that half step, which keeps a strong pack card from
## coming cheap; a larger step, or a multiplier for strong cards, lost
## more of the match than it gained in ranking the staples.
##
## IN A TOWN (`RunTownBuyCardsScreen`): the base times (site type + 2) —
## three in a village, four in a town, five in a city; a card of no colour
## of the town's land costs half again when its colour goes with the town's
## first (or it is colourless), twice otherwise; then down to a multiple of
## 5, between 5 and 1000. SOLD (`SellPrice`, 004f1bcc): the same base and
## site, a card not exactly of the town's colours a third more when its
## colour goes with them, half again otherwise; down to a multiple of 5.

## The 1997 card types and colour bits.
const LAND := 1
const CREATURE := 2
const ENCHANTMENT := 4
const SORCERY := 8
const INSTANT := 16
const INTERRUPT := 32
const ARTIFACT := 64
const COLORLESS := 1
const COLOR_BITS := {"black": 2, "blue": 4, "green": 8, "red": 16, "white": 32}
## `ai_base_value` by type where the program's own is not at hand.
const AI_BY_TYPE := {CREATURE: 1, ENCHANTMENT: 0, SORCERY: 0, INSTANT: -1, INTERRUPT: -2, ARTIFACT: 1}
## The middle and the spread (median and median deviation) of the engine's
## rating ([method AutoDeck.score]) over the 1997 base cards of each type.
const STRENGTH_MIDDLE := {CREATURE: [1.8, 0.54], SORCERY: [0.88, 0.274], INSTANT: [0.96, 0.2],
	ARTIFACT: [1.118, 0.387], ENCHANTMENT: [0.946, 0.172]}
## The colours each colour goes with (the 1.3 preference table: black with
## red and blue, blue with black and white, green with white and red, red
## with green and black, white with blue), by 1997 colour bit.
const GOES_WITH := {2: [2, 16, 4], 4: [4, 2, 32], 8: [8, 32, 16], 16: [16, 8, 2], 32: [32, 4, 32]}
## The ability bits the formula reads: `static_ability` landwalks 0x1F,
## banding, trample and first strike 0x1C0, regeneration 0x200;
## `extra_ability` an enchantment's activated ability 0x3, a power pump
## 0x8, a toughness pump 0x10, the staples 0x200 and 0x400.
const LANDWALK := 0x1F
const FIGHTING := 0x1C0
const REGENERATES := 0x200
const ACTIVATED := 0x3
const PUMP_POWER := 0x8
const PUMP_TOUGHNESS := 0x10
const STAPLE := 0x200
const FAVOURED := 0x400
const KEYWORD_WORDS: Array[String] = ["flying", "banding", "trample", "first strike",
	"swampwalk", "islandwalk", "forestwalk", "mountainwalk", "plainswalk"]

## The 1997 card lists' own spellings of cards the engine names otherwise
## (beside those that differ only in case, marks and accents: "Circle of
## Protection Black", "Juzam Djinn").
const SPELLED_1997 := {"Argivian Archaeoligist": "Argivian Archaeologist",
	"Ashnod's Alter": "Ashnod's Altar", "Circle of Protection from Artifacts": "Circle of Protection: Artifacts",
	"Cyclopian Mummy": "Cyclopean Mummy", "Disrupting Sceptre": "Disrupting Scepter",
	"Hypnotic Spectre": "Hypnotic Specter", "Ivory Guardiands": "Ivory Guardians",
	"Kobold Drill Sergent": "Kobold Drill Sergeant", "Mons Goblin Raiders": "Mons's Goblin Raiders",
	"Necropolis of Azaar": "Necropolis of Azar", "Ressurection": "Resurrection",
	"Tablets of Epityr": "Tablet of Epityr", "Tawnos' Coffin": "Tawnos's Coffin",
	"Tawnos' Wand": "Tawnos's Wand", "Tawnos' Weaponry": "Tawnos's Weaponry",
	"Turndra Wolves": "Tundra Wolves", "Veduran Enchantress": "Verduran Enchantress",
	"Vesuvan Doppleganger": "Vesuvan Doppelganger", "Yotian Soldiers": "Yotian Soldier"}
## Accented letters read as their plain ones in a name's key.
const PLAIN_LETTERS := {"á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e",
	"í": "i", "î": "i", "ó": "o", "ô": "o", "ö": "o", "ú": "u", "û": "u", "ü": "u", "ñ": "n"}

static var _imported: Dictionary = {}
static var _imported_read := false
static var _keys: Dictionary = {}
static var _scorer: AutoDeck


## The 1997 program's entry for [param card_name] (`adventure_cards.json`,
## its names the engine's: [method engine_name]), or `{}`.
static func original(card_name: String) -> Dictionary:
	if not _imported_read:
		_imported_read = true
		_imported = {}
		var table: Dictionary = GameSkin.metadata("adventure_cards").get("cards", {})
		for name_1997 in table:
			var ours := engine_name(String(name_1997))
			if ours != "" and not _imported.has(ours):
				_imported[ours] = table[name_1997]
	return _imported.get(card_name, {})


## The engine's name for a card the 1997 card lists name [param name_1997]
## (`Info.csv`), or "" for none (a token, an empty row).
static func engine_name(name_1997: String) -> String:
	if CardRegistry.has_card(name_1997):
		return name_1997
	var spelled := String(SPELLED_1997.get(name_1997, ""))
	if spelled != "" and CardRegistry.has_card(spelled):
		return spelled
	if _keys.is_empty():
		for card_name in CardRegistry.all_names():
			_keys[name_key(String(card_name))] = String(card_name)
	return String(_keys.get(name_key(name_1997), ""))


## A name's key: its letters and digits, lower case, accents plain.
static func name_key(card_name: String) -> String:
	var out := ""
	for letter in card_name.to_lower():
		var plain := String(PLAIN_LETTERS.get(letter, letter))
		if (plain >= "a" and plain <= "z") or (plain >= "0" and plain <= "9"):
			out += plain
	return out


## Forget the imported table (a skin imported again, packs changed, a test).
static func forget() -> void:
	_imported = {}
	_imported_read = false
	_keys = {}


## THE FORMULA'S INPUTS for [param data]: the 1997 program's own when it was
## imported, else read off the card (`derived` true).
static func facts(data: CardData) -> Dictionary:
	var own := original(data.card_name)
	if not own.is_empty():
		var out := own.duplicate()
		out["derived"] = false
		return out
	return derive(data)


## The inputs read off the card itself, for a card the program never had.
static func derive(data: CardData) -> Dictionary:
	var kind := LAND
	if data.is_creature():
		kind = CREATURE
	elif data.is_type(Mtg.CardType.ARTIFACT):
		kind = ARTIFACT
	elif data.is_type(Mtg.CardType.ENCHANTMENT):
		kind = ENCHANTMENT
	elif data.is_type(Mtg.CardType.SORCERY):
		kind = SORCERY
	elif data.is_type(Mtg.CardType.INSTANT):
		kind = INSTANT
	var color := color_bits(data.color_mask())
	var pips := 0
	for hue in data.cost.colored:
		if hue != Mtg.ManaColor.C:
			pips += int(data.cost.colored[hue])
	var text := data.oracle_text.to_lower()
	var static_bits := 0
	if not data.landwalk.is_empty():
		static_bits |= 0x1
	if data.keywords.has(Mtg.Keyword.BANDING) or data.keywords.has(Mtg.Keyword.TRAMPLE) \
			or data.keywords.has(Mtg.Keyword.FIRST_STRIKE):
		static_bits |= 0x40
	if text.contains("regenerate"):
		static_bits |= REGENERATES
	var extra := 0
	if kind == ENCHANTMENT and not data.activated_abilities.is_empty():
		extra |= 0x1
	var pump := RegEx.create_from_string("\\{[^}]+\\}[^:\\n]*: [^\\n]*gets \\+([0-9x])/\\+([0-9x])")
	for found in pump.search_all(text):
		if found.get_string(1) != "0":
			extra |= PUMP_POWER
		if found.get_string(2) != "0":
			extra |= PUMP_TOUGHNESS
	return {"type": kind | (ARTIFACT if kind == CREATURE and data.is_type(Mtg.CardType.ARTIFACT) else 0),
		"color": color, "cc0": pips, "cc1": -1 if data.cost.has_x else data.cost.generic,
		"power": maxi(data.power, 0), "tough": maxi(data.toughness, 0),
		"static": static_bits, "extra": extra,
		"ai": clampi(int(AI_BY_TYPE.get(kind, 0)) + strength_step(data, kind), -2, 3),
		"vanilla": _plain(text), "rarity": rarity(data.card_name), "exp": 1 if is_base(data.card_name) else 2,
		"derived": true}


## How many half steps of the hand-tuned value [param data]'s abilities are
## worth over the middle of its type ([constant STRENGTH_MIDDLE]).
static func strength_step(data: CardData, kind: int) -> int:
	var middle: Array = STRENGTH_MIDDLE.get(kind, [])
	if middle.is_empty():
		return 0
	if _scorer == null:
		_scorer = AutoDeck.new()
	return roundi(0.5 * (_scorer.score(data) - float(middle[0])) / float(middle[1]))


## The 1997 colour bits of a card of colour mask [param mask]
## ([enum Mtg.ManaColor]): colourless 1.
static func color_bits(mask: int) -> int:
	var bits := 0
	for pair in [[Mtg.ManaColor.B, 2], [Mtg.ManaColor.U, 4], [Mtg.ManaColor.G, 8],
			[Mtg.ManaColor.R, 16], [Mtg.ManaColor.W, 32]]:
		if mask & int(pair[0]) != 0:
			bits |= int(pair[1])
	return bits if bits != 0 else COLORLESS


## A card's rarity for the shop, 1 common to 3 rare, 4 special: its first
## printing's (closest to the 1997 game's own list: it agrees on 84 in 100
## of the cards a shop sells, Fourth Edition's on 76), an Astral card
## special.
static func rarity(card_name: String) -> int:
	if CardRegistry.printed_rarity(card_name, "past") != "":
		return 4
	match CardRegistry.rarity_of(card_name).to_lower():
		"uncommon":
			return 2
		"rare", "mythic":
			return 3
		"special":
			return 4
	return 1


## Whether [param card_name] is of the base set the 1997 shops sell: printed
## in Unlimited or Fourth Edition.
static func is_base(card_name: String) -> bool:
	return CardRegistry.printed_rarity(card_name, "2ed") != "" \
		or CardRegistry.printed_rarity(card_name, "4ed") != ""


## Rules text that is nothing but plain keywords (the program's `card_dummy`).
static func _plain(text: String) -> bool:
	var rest := text
	for word in KEYWORD_WORDS:
		rest = rest.replace(word, "")
	for mark in [",", ".", "(", ")", " ", "\n"]:
		rest = rest.replace(mark, "")
	return rest == ""


## THE 1997 PRICE BEFORE THE TOWN (`CalculateCardShopPrice`).
static func base_price(data: CardData) -> int:
	return price_of(facts(data))


## The formula on inputs [param f] (see [method facts]).
static func price_of(f: Dictionary) -> int:
	var kind := int(f.get("type", LAND))
	var ai := int(f.get("ai", 0))
	var cc0 := int(f.get("cc0", 0))
	var generic := absi(int(f.get("cc1", 0)))
	var value := 40
	var static_bits := int(f.get("static", 0))
	var extra := int(f.get("extra", 0))
	if kind & CREATURE != 0:
		# A `*` is kept as 0x4000 over the printed part (1997's card table).
		var power := maxi(int(f.get("power", 0)), 0) & ~0x4000
		var tough := maxi(int(f.get("tough", 0)), 0) & ~0x4000
		value = (ai + power + 3) * (tough + 3) * 5
		if static_bits & LANDWALK != 0:
			value = value * 3 / 2
		if static_bits & REGENERATES != 0:
			value = value * 3 / 2
		if not bool(f.get("vanilla", true)):
			value = value * 3 / 2
		if static_bits & FIGHTING != 0:
			value = value * 3 / 2
		if extra & PUMP_POWER != 0:
			value *= 3
		if extra & PUMP_TOUGHNESS != 0:
			value *= 3
		value = _div(value, cc0 + generic + 1)
	elif kind == ENCHANTMENT:
		value = (generic + cc0 + ai + 1) * 25
		if extra & ACTIVATED != 0:
			value *= 2
	elif kind == SORCERY:
		value = (generic + cc0 + ai + 1) * 20
	elif kind == ARTIFACT:
		value = _div(250, ai + generic + 2)
	elif kind == INSTANT or kind == INTERRUPT:
		value = ai * 20 + (generic + cc0 + 1) * 40
		if int(f.get("cc1", 0)) == -1:
			value = value * 3 / 2
	# Power, the restricted and the Astral cards are special (`GetCardRarity`).
	var rank := int(f.get("rarity", 1))
	if extra & 0x180 != 0 or int(f.get("exp", 1)) == 0x40:
		rank = 4
	match rank:
		2:
			value = clampi(value * 2, 100, 9999)
		3:
			value = clampi(value * 4, 200, 9999)
		4:
			value = clampi(value * 8, 200, 9999)
	if extra & STAPLE != 0:
		value *= 2
	if extra & FAVOURED != 0:
		value = value * 3 / 2
	return value


## C's division, toward zero.
static func _div(a: int, b: int) -> int:
	if b == 0:
		return 0
	var q := absi(a) / absi(b)
	return q if (a >= 0) == (b > 0) else -q


## The first of the five colours (black, blue, green, red, white) in
## [param bits], or 0.
static func first_color(bits: int) -> int:
	for bit in [2, 4, 8, 16, 32]:
		if bits & bit != 0:
			return bit
	return 0


## Whether a card of colour [param card_bits] goes with land of colour
## [param tile_bits] at [param level] (`is_card_color_compatible_with_mask`):
## colourless always; else its first colour among the land's first
## colour's first [param level] companions.
static func goes_with(card_bits: int, tile_bits: int, level: int) -> bool:
	if card_bits == COLORLESS or tile_bits == COLORLESS:
		return true
	var mine := first_color(card_bits)
	var row: Array = GOES_WITH.get(first_color(tile_bits), [])
	for i in mini(level, row.size()):
		if int(row[i]) == mine:
			return true
	return level > 3


## THE PRICE IN A TOWN: [param data] at a site of [param site_type] (1
## village … 3 city) on land of colours [param tile_bits]
## ([method ShandalarWorld.magic_mask]).
static func buy_price(data: CardData, site_type: int, tile_bits: int) -> int:
	var f := facts(data)
	var value := price_of(f) * (site_type + 2)
	var color := int(f.get("color", COLORLESS))
	if tile_bits & color == 0:
		if color != 0 and goes_with(tile_bits, color, 3):
			value = value * 3 / 2
		else:
			value *= 2
	return clampi(_div(value, 50) * 5, 5, 1000)


## WHAT A TOWN PAYS for [param data] (`SellPrice`).
static func sell_price(data: CardData, site_type: int, tile_bits: int) -> int:
	var f := facts(data)
	var value := price_of(f) * (site_type + 2)
	var color := int(f.get("color", COLORLESS))
	if color != tile_bits and color != 0:
		if goes_with(tile_bits, color, 3):
			value = value * 4 / 3
		else:
			value = value * 3 / 2
	return _div(value, 50) * 5
