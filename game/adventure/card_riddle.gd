class_name CardRiddle
extends RefCounted
## THE CARD RIDDLE of a lair's towers (Loremaster's Tower, the Pyramids of
## Aska-tet, a Ruined Tower with no clue to give) — 1.3's
## `RunCardRiddleChallenge` (00534530), in the words of `@RIDDLE`:
##  - the riddle is on a creature's power, its toughness, a spell's total
##    cost (twice as likely), or a creature's flying, landwalk,
##    regeneration, banding, first strike or trample; its card one of the
##    base set's that has it (four tries for a card, then another riddle);
##  - on Magician a quarter of the riddles, on Sorcerer a half, on Wizard
##    three quarters name the card and ask: "What is the power rating of
##    the Serra Angel?" — 0 to 8+ — or "What special ability does the
##    Serra Angel have?" — any of the ten it has is right;
##  - the rest show five cards: "Which of these spells has a power of 4?" —
##    four that have not (for the cost, of the same colour with another
##    count of coloured mana) and the one that has, at a place drawn at
##    random.
## Answered, the card is shown: "Correct!", "WRONG" or "WRONG.  Correct is:".

const POWER := 0
const TOUGHNESS := 1
const COST := 2
const FLYING := 3
const LANDWALK := 4
const REGENERATION := 5
const BANDING := 6
const FIRST_STRIKE := 7
const TRAMPLE := 8
## The 1997 ability bits (`static_ability`), in the answers' order.
const ABILITY_WORDS: Array[String] = ["Swampwalk", "Islandwalk", "Forestwalk", "Mountainwalk",
	"Plainswalk", "Flying", "Banding", "Trample", "First Strike", "Regeneration"]
const BIT_FLYING := 0x20
const BIT_BANDING := 0x40
const BIT_TRAMPLE := 0x80
const BIT_FIRST_STRIKE := 0x100
const BIT_REGENERATION := 0x200
## Each riddle's ability bit (none for power, toughness and cost).
const BITS := {FLYING: BIT_FLYING, LANDWALK: 0x1F, REGENERATION: BIT_REGENERATION,
	BANDING: BIT_BANDING, FIRST_STRIKE: BIT_FIRST_STRIKE, TRAMPLE: BIT_TRAMPLE}
const LANDS: Array[String] = ["swamp", "island", "forest", "mountain", "plains"]
const MANA_WORDS: Array[String] = ["black", "blue", "green", "red", "white"]
const CORRECT := "Correct!"
const WRONG := "WRONG"
const WRONG_SHOWN := "WRONG.  Correct is:"
const CHOICES := 5
const NUMBERS: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8+"]

static var _pool: Array[Dictionary] = []


## THE BASE SET'S CARDS as the riddles read them, once: `{name, creature,
## power, tough, cc0, cc1, color, bits}`.
static func pool() -> Array[Dictionary]:
	if not _pool.is_empty():
		return _pool
	CardRegistry.ensure_loaded()
	for card_name in CardRegistry.all_names():
		var name_text := String(card_name)
		if not CardTrade.in_adventure(name_text):
			continue
		var data := CardRegistry.get_card(name_text)
		var f := CardValue.facts(data)
		var core := int(f.get("exp", 0)) & 0xC1 != 0 if not bool(f.get("derived", true)) \
			else CardValue.is_base(name_text)
		if not core:
			continue
		_pool.append({"name": name_text, "creature": data.is_creature(),
			"power": data.power, "tough": data.toughness,
			"cc0": int(f.get("cc0", 0)), "cc1": int(f.get("cc1", 0)),
			"color": int(f.get("color", CardValue.COLORLESS)), "bits": abilities(data)})
	return _pool


static func forget() -> void:
	_pool.clear()


## A card's 1997 ability bits: the program's own when imported, else read
## off its keywords (landwalks 0x1F by land, flying 0x20, banding 0x40,
## trample 0x80, first strike 0x100, regeneration 0x200).
static func abilities(data: CardData) -> int:
	var own := CardValue.original(data.card_name)
	if not own.is_empty():
		return int(own.get("static", 0)) & 0x3FF
	var bits := 0
	for i in LANDS.size():
		if LANDS[i] in data.landwalk:
			bits |= 1 << i
	if data.keywords.has(Mtg.Keyword.FLYING):
		bits |= BIT_FLYING
	if data.keywords.has(Mtg.Keyword.BANDING):
		bits |= BIT_BANDING
	if data.keywords.has(Mtg.Keyword.TRAMPLE):
		bits |= BIT_TRAMPLE
	if data.keywords.has(Mtg.Keyword.FIRST_STRIKE):
		bits |= BIT_FIRST_STRIKE
	if data.oracle_text.to_lower().contains("regenerate"):
		bits |= BIT_REGENERATION
	return bits


## A RIDDLE drawn with [param dice] at [param difficulty]: `{kind, card,
## question, answers, right, direct}` — the answers as the buttons word
## them; `right` the right one's place (−1 for the ability riddle, where
## any the card has is right); `choices` the five cards' names.
static func make(dice: MsvcRandom, difficulty: int) -> Dictionary:
	var cards := pool()
	if cards.is_empty():
		return {}
	var kind := 0
	var card: Dictionary = {}
	for turn in 50:
		kind = dice.below(10)
		if kind == 9:
			kind = COST
		var fits := _subjects(cards, kind)
		if fits.is_empty():
			continue
		for attempt in 4:
			var pick: Dictionary = fits[dice.below(fits.size())]
			if _has(pick, kind):
				card = pick
				break
		if not card.is_empty():
			break
	if card.is_empty():
		return {}
	var out := {"kind": kind, "card": String(card["name"]), "direct": dice.below(4) < difficulty}
	if out["direct"]:
		match kind:
			POWER:
				out["question"] = "What is the power rating of the %s?" % card["name"]
				out["answers"] = NUMBERS.duplicate()
				out["right"] = clampi(int(card["power"]), 0, 8)
			TOUGHNESS:
				out["question"] = "What is the toughness of the %s?" % card["name"]
				out["answers"] = NUMBERS.duplicate()
				out["right"] = clampi(int(card["tough"]), 0, 8)
			COST:
				out["question"] = "What is the total casting cost of the %s?" % card["name"]
				out["answers"] = NUMBERS.duplicate()
				out["right"] = clampi(int(card["cc0"]) + int(card["cc1"]), 0, 8)
			_:
				out["question"] = "What special ability does the %s have?" % card["name"]
				out["answers"] = ABILITY_WORDS.duplicate()
				out["right"] = -1
				out["bits"] = int(card["bits"])
		return out
	var subjects := _subjects(cards, kind)
	var choices: Array[String] = []
	var tries := 0
	while choices.size() < CHOICES and tries < 5000:
		tries += 1
		var decoy: Dictionary = subjects[dice.below(subjects.size())]
		if _decoy(decoy, card, kind) and not String(decoy["name"]) in choices:
			choices.append(String(decoy["name"]))
	while choices.size() < CHOICES:
		choices.append(String(card["name"]))
	var right := dice.below(CHOICES)
	choices[right] = String(card["name"])
	out["question"] = _which(card, kind)
	out["answers"] = choices
	out["choices"] = choices
	out["right"] = right
	return out


## Whether [param answer] (the button's place) answers [param riddle].
static func correct(riddle: Dictionary, answer: int) -> bool:
	if int(riddle.get("right", 0)) == -1:
		return answer >= 0 and answer < 10 and int(riddle.get("bits", 0)) & (1 << answer) != 0
	return answer == int(riddle.get("right", -2))


## The words shown with the card after [param answer].
static func verdict(riddle: Dictionary, answer: int) -> String:
	if correct(riddle, answer):
		return CORRECT
	return WRONG if bool(riddle.get("direct", false)) else WRONG_SHOWN


static func _subjects(cards: Array[Dictionary], kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in cards:
		if bool(card["creature"]) or kind == COST:
			out.append(card)
	return out


static func _has(card: Dictionary, kind: int) -> bool:
	match kind:
		POWER:
			return int(card["power"]) > 0
		TOUGHNESS:
			return int(card["tough"]) > 0
		COST:
			return int(card["cc0"]) > 0 and int(card["cc1"]) >= 0
	return int(card["bits"]) & int(BITS.get(kind, 0)) != 0


static func _decoy(decoy: Dictionary, card: Dictionary, kind: int) -> bool:
	match kind:
		POWER:
			return int(decoy["power"]) != int(card["power"])
		TOUGHNESS:
			return int(decoy["tough"]) != int(card["tough"])
		COST:
			return int(decoy["color"]) == int(card["color"]) and int(decoy["cc0"]) != int(card["cc0"])
		LANDWALK:
			return int(decoy["bits"]) & int(card["bits"]) & 0x1F == 0
	return int(decoy["bits"]) & int(BITS.get(kind, 0)) == 0


static func _which(card: Dictionary, kind: int) -> String:
	match kind:
		POWER:
			return "Which of these spells has a power of %d?" % int(card["power"])
		TOUGHNESS:
			return "Which of these spells has a toughness of %d?" % int(card["tough"])
		COST:
			var hue := CardValue.first_color(int(card["color"]))
			var word := MANA_WORDS[CardShop.COLOR_BITS.find(hue)] if hue != 0 else "colored"
			return "Which of these spells requires %d %s and %d colorless mana to cast?" % [
				int(card["cc0"]), word, int(card["cc1"])]
		FLYING:
			return "Which of these spells has flying ability?"
		LANDWALK:
			# 1997 names the last of swamp, mountain, island, forest, plains it has.
			var walk := 0
			for i in [0, 3, 1, 2, 4]:
				if int(card["bits"]) & (1 << i) != 0:
					walk = i
			return "Which of these spells has %s ability?" % ABILITY_WORDS[walk].to_lower()
		REGENERATION:
			return "Which of these spells has regeneration ability?"
		BANDING:
			return "Which of these spells has banding ability?"
		FIRST_STRIKE:
			return "Which of these spells has first strike ability?"
	return "Which of these spells has trample ability?"
