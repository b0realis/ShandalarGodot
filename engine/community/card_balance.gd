class_name CardBalance
extends RefCounted
## A CRUDE BALANCE CHECK for a community card — suggestions only, it never
## refuses a card. The card is set beside the game's own cards (every card
## of the pool but the community ones) by mana value: a creature's size,
## power, toughness and keyword pile; whatever a spell, an ability or a
## trigger does for its price ([constant _M]: damage, cards, life, tokens,
## mass destruction, extra turns, searches, control, pumps, …); the mana
## an ability makes beyond its costs; an anthem's or an Aura's bonus or
## curse; how much the card does; what it costs.
##
## WHAT WAS SET BESIDE NOTHING IS SAID SO: a row "Not compared" names it
## in plain words, and a card with such a row is never said to simply fit
## ([method advice], [method coverage]).
##
## Then again beside the cards of its own color: where a creature's size
## or keywords are unusual for the game, whether they are for its color
## too; and what the card does beside what that color's cards do — an
## effect almost none of them have is told plainly ("Few white cards deal
## direct damage").
##
## Both sides are read the same way, from the rules text (the community
## card's is written by [CommunityCard] in the same words), with the card's
## own name read as CARDNAME and reminder text in parentheses left out, so
## a classic card and a new one are measured alike. The numbers of the
## game's cards are counted once per pool and kept as plain numbers and
## names.

const OK := "ok"
const LOW := "low"
const HIGH := "high"
const VERY_HIGH := "very_high"
## Something on the card that was set beside nothing (never a verdict on
## its strength), and a color hint (an effect rare in the card's color).
const NOT_COMPARED := "not_compared"
const RARE := "rare_in_color"
const LEVEL_WORDS := {OK: "Usual", LOW: "Low", HIGH: "High", VERY_HIGH: "Very high",
	NOT_COMPARED: "Not compared", RARE: "Rare in color"}
## Mana values (and prices) from this one up share one shelf.
const TOP_SHELF := 8
## The share of the game's cards a "usual" value stays within: "almost
## all", 97 in 100 — told only of a shelf with cards enough for it to mean
## something ([method _past_usual]). (9 in 10, the line until 2026-11-22,
## called one in eight of the game's own cards strong — a Serra Angel, an
## Erhnam Djinn.) Up to
## [constant KEYWORDS_FREE] keywords are never much, whatever the shelf.
const USUAL := 0.97
const SIZE_USUAL := 0.97
const SIZE_SAID := "Almost all"
## "Weak" accuses nobody: a creature smaller than 9 in 10 of its shelf is
## told so, as before.
const SIZE_SMALL := 0.9
const USUAL_KEYWORDS := 0.97
const KEYWORDS_FREE := 2

static var _corpus := {}
static var _corpus_size := -1
## Each pattern compiled once (the corpus reads every card's lines).
static var _patterns: Dictionary = {}


static func _rx(pattern: String) -> RegEx:
	if not _patterns.has(pattern):
		_patterns[pattern] = RegEx.create_from_string(pattern)
	return _patterns[pattern]

const _WORD_NUMBERS := {"a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
	"six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}
const _VERBS := "\\b(deals|draws?|gains?|loses?|destroy|returns?|puts?|creates?|add|taps?|untaps?|counter|exile|search|discards?|sacrifices?|prevent|regenerate|gets?)\\b"


# ---------------------------------------------------------- the verdict --

## The suggestions for [param spec] (a whole spec): rows of
## `{level, topic, text, yours}`, the summary first (`topic` "Summary", no
## `yours`). A row that measured something also has `rank` (where the
## card's number sits among the game's: 0 the least, 1 the most, past 1
## beyond every card) and `worth` — what [method power] is made of.
##
## NOTHING IS PASSED OVER IN SILENCE: whatever the card has that was set
## beside nothing — an amount of X, an effect none of the pool's cards
## has, a block this check has no measure for — gets a row of level
## [constant NOT_COMPARED] naming it, and the summary then never says the
## card simply fits.
static func advice(spec: Dictionary) -> Array[Dictionary]:
	var c := corpus()
	# Read under a neutral name: no name can be taken for rules words (a
	# land named "T", an Aura named "Enchanted").
	var masked := spec.duplicate()
	masked["name"] = "CARDNAME"
	var data := CommunityCard.build(masked)
	var rows := _rows_of(c, data)
	_coverage_rows(rows, spec)
	rows.push_front(_summary(rows, c))
	return rows


## The same table for a card as built ([param data]) — one of the game's
## own, say: read from its rules text alone, as the game's cards are
## counted.
static func card_advice(data: CardData) -> Array[Dictionary]:
	var c := corpus()
	var rows := _rows_of(c, data)
	rows.push_front(_summary(rows, c))
	return rows


static func _rows_of(c: Dictionary, data: CardData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := _facts(data)
	var land: bool = f["land"]
	var creature: bool = f["creature"]
	_thumb_rows(rows, c, data, f)
	if not land:
		_cost_rows(rows, c, f)
	if creature:
		_creature_rows(rows, c, data, f)
		if not land:
			_color_size_rows(rows, c, data, int(f["mv"]), int(f["drawbacks"]), int(f["gifts"]))
	_text_rows(rows, c, f)
	if not land:
		_pie_rows(rows, c, data, creature, String(f["text"]))
	return rows


## The summary row. The color hints and the "Not compared" rows stay out of
## its level (an effect rare in the card's color is not a weak or a strong
## card) and get a sentence each; but a card with a "Not compared" row is
## never said to simply fit.
static func _summary(rows: Array[Dictionary], c: Dictionary) -> Dictionary:
	var worst := OK
	var pie := false
	var unread := false
	for row in rows:
		var row_level := String(row["level"])
		if row_level == RARE:
			pie = true
		elif row_level == NOT_COMPARED:
			unread = true
		elif _rank(row_level) > _rank(worst):
			worst = row_level
	var level := worst
	var summary := "Fits the game's cards."
	match worst:
		VERY_HIGH: summary = "Probably too strong (or too odd) beside the game's cards — see the red lines."
		HIGH: summary = "Strong in places beside the game's cards — see the orange lines."
		LOW: summary = "Weak in places beside the game's cards."
		_:
			if unread:
				level = NOT_COMPARED
				summary = "Fits the game's cards where it could be compared."
	if unread:
		summary += " Part of it was not compared (the \"Not compared\" lines) — judge that part yourself."
	if pie:
		summary += " Some of what it does is rare in its color (the \"Color\" lines)."
	return {"level": level, "topic": "Summary", "text": "%s Compared with %d of the game's cards; only a suggestion — the card saves either way." % [summary, int(c["cards"])]}


# ----------------------------------------------------- one power number --

## ONE NUMBER FOR THE CARD, 0 to 100, from the rows of [method advice]:
## about 50 is a usual card of its cost, 70 the strongest the game has in
## some respect, past 85 beyond every card of the game. 0: nothing on it
## could be measured.
##
## Each measured row gives `worth` x (70 x `rank`, and 60 for each whole
## step past 1); the best row counts whole and every other row adds 15 in
## 100 of its own. So a bigger number on the card, one more ability or a
## lower cost never lowers it where the game's cards themselves grow with
## their cost; "Not compared" rows add nothing.
static func power(spec: Dictionary) -> int:
	return power_of(advice(spec))


## [method power] from rows already made.
static func power_of(rows: Array[Dictionary]) -> int:
	var scores: Array[float] = []
	for row in rows:
		if not row.has("rank"):
			continue
		var r := float(row["rank"])
		scores.append(float(row.get("worth", 1.0)) * (70.0 * r if r <= 1.0 else 70.0 + 60.0 * (r - 1.0)))
	if scores.is_empty():
		return 0
	scores.sort()
	var total := scores[-1]
	for i in scores.size() - 1:
		total += 0.15 * scores[i]
	return clampi(roundi(total), 0, 100)


## A WHOLE SET AT ONCE: one line a card, the worst first, then the set's
## own remarks. Rows of `{kind, name, level, power, topic, text}`:
## `kind` "card" — `name`, the summary's `level` ("invalid" for a spec that
## cannot be a card yet), `power` ([method power]; -1 when invalid),
## `topic` the check of its worst row and `text` that row's sentence; then
## `kind` "set" — `topic` "Colors", "Rarities", "Types" or "Curve" and a
## sentence (`name` "", `level` "ok", or "low" for a gap, `power` -1).
static func set_advice(specs: Array) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var colors := {}
	var rarities := {}
	var kinds := {}
	var curve := {}
	var order := {"invalid": 0, VERY_HIGH: 1, HIGH: 2, NOT_COMPARED: 3, LOW: 4, OK: 5}
	for entry: Variant in specs:
		if not entry is Dictionary:
			continue
		var spec: Dictionary = entry
		var card_name := String(spec.get("name", "")).strip_edges()
		var problems := CommunityCard.problems(spec)
		if not problems.is_empty():
			cards.append({"kind": "card", "name": card_name, "level": "invalid", "power": -1,
				"topic": "Problem", "text": problems[0]})
			continue
		var rows := advice(spec)
		var level := String(rows[0]["level"])
		var topic := "Summary"
		var text := "Fits the game's cards."
		if level != OK:
			for row in rows.slice(1):
				if String(row["level"]) == level:
					topic = String(row["topic"])
					text = game_words(row)
					break
		cards.append({"kind": "card", "name": card_name, "level": level, "power": power_of(rows),
			"topic": topic, "text": text})
		var data := CommunityCard.build(spec)
		var color := String(COLOR_WORDS[_color_key(data)])
		var types := CommunityCard._list(spec.get("types"))
		if data.is_land():
			color = "land"
		else:
			var mv := data.cost.mana_value() if data.cost != null else 0
			curve[mini(mv, 7)] = int(curve.get(mini(mv, 7), 0)) + 1
		colors[color] = int(colors.get(color, 0)) + 1
		var rarity := String(spec.get("rarity", "common"))
		rarities[rarity] = int(rarities.get(rarity, 0)) + 1
		for type in types:
			kinds[type] = int(kinds.get(type, 0)) + 1
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := int(order.get(a["level"], 5))
		var rb := int(order.get(b["level"], 5))
		if ra != rb:
			return ra < rb
		if int(a["power"]) != int(b["power"]):
			return int(a["power"]) > int(b["power"])
		return String(a["name"]) < String(b["name"]))
	var counted := 0
	for key in colors:
		counted += int(colors[key])
	if counted == 0:
		return cards
	var said := func(topic: String, level: String, text: String) -> void:
		cards.append({"kind": "set", "name": "", "level": level, "power": -1, "topic": topic, "text": text})
	var tally := func(counts: Dictionary, keys: Array) -> String:
		var bits: Array[String] = []
		for key: Variant in keys:
			bits.append("%d %s" % [int(counts.get(key, 0)), key])
		return ", ".join(bits)
	var color_keys := ["white", "blue", "black", "red", "green", "gold", "colorless", "land"]
	var missing: Array[String] = []
	for key: String in color_keys.slice(0, 5):
		if not colors.has(key):
			missing.append(key)
	var color_text: String = "%s." % tally.call(colors, color_keys)
	if not missing.is_empty() and missing.size() < 5 and counted >= 10:
		color_text += " No %s cards." % " or ".join(missing)
	said.call("Colors", LOW if color_text.contains("No ") else OK, _upper(color_text))
	var rarity_keys: Array = CommunityCard.RARITIES.duplicate()
	for key: Variant in rarities:
		if not rarity_keys.has(key):
			rarity_keys.append(key)
	var rarity_text: String = "%s." % tally.call(rarities, rarity_keys)
	var commons := int(rarities.get("common", 0))
	var uncommons := int(rarities.get("uncommon", 0))
	var rares := int(rarities.get("rare", 0)) + int(rarities.get("mythic", 0))
	var gaps: Array[String] = []
	if commons == 0:
		gaps.append("no commons")
	if uncommons == 0:
		gaps.append("no uncommons")
	if rares == 0:
		gaps.append("no rares")
	if gaps.is_empty() and commons < uncommons:
		gaps.append("fewer commons than uncommons")
	if not gaps.is_empty():
		rarity_text += " A booster wants all three: %s here." % ", ".join(gaps)
	said.call("Rarities", OK if gaps.is_empty() else LOW, _upper(rarity_text))
	var type_keys: Array = CommunityCard.TYPES.keys()
	said.call("Types", OK, _upper("%s." % tally.call(kinds, type_keys)))
	var steps: Array[String] = []
	var holes: Array[String] = []
	for mv in range(0, 8):
		steps.append("%d at %s" % [int(curve.get(mv, 0)), "7 or more" if mv == 7 else str(mv)])
		if mv >= 1 and mv <= 5 and not curve.has(mv):
			holes.append(str(mv))
	var curve_text := "Mana curve: %s." % ", ".join(steps)
	if not holes.is_empty() and counted >= 10:
		curve_text += " Nothing costs %s." % " or ".join(holes)
		said.call("Curve", LOW, curve_text)
	else:
		said.call("Curve", OK, curve_text)
	return cards


static func _upper(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


# ------------------------------------------------- what was not compared --

## Vocabulary this check will never measure, by "TABLE/id", in plain words
## (see [method coverage]).
const _NOT_COMPARED := {
	"EFFECTS/extra_mana": "the mana it adds depends on the lands tapped as it plays",
	"EFFECTS/return_self": "returning the card itself to its owner's hand",
}
## The tables of [CommunityCard] that shape or word a card but add nothing
## to weigh: kinds and colors, prices and timings (a limit is never a
## strength), how targets are said (a narrower target is never stronger,
## and each effect is read with every target it may have). A table in
## neither list is new — the tests refuse it until it is put in one.
const NOT_VOCABULARY := ["TYPES", "PERMANENTS", "KEYWORD_WORDS", "COLORS", "MANA_COLORS", "MANA_SYMBOLS",
	"BASIC_COLORS", "RARITIES", "BORDERS", "FRAMES", "SPELL_TYPES", "SACRIFICES", "MODES", "TIMINGS",
	"CREATURE_TRIGGERS", "SEARCH_WHERE", "SEARCH_WHERE_WORDS", "SHUFFLE_FROM", "SHUFFLE_FROM_WORDS",
	"HINDERING", "NOT_IN_TRIGGERS", "ACTIVATED_ONLY", "NOT_IN_ACTIVATED", "HELPFUL", "TARGET_WORDS",
	"LIMITS", "COUNT_WHAT", "COUNT_WHOSE", "HOST_TRIGGERS", "EVENT_PLAYER_TRIGGERS", "DAMAGE_TRIGGERS",
	"TRIGGER_CHOICES", "QUIET_TRIGGERS", "COST_WHO", "COST_WHO_WORDS", "COST_SPELL_TYPES", "TOKEN_ENDS",
	"TOKEN_ENDS_WORDS", "ONLY", "ONLY_TARGETS", "PLAYER_TARGETS", "NOT_IN_SPELLS", "TRIGGER_ONLY", "VARYING_X"]
## What an entry of [constant CommunityCard.EFFECTS] may say of itself;
## each is read through the effect's own sentence.
const EFFECT_FIELDS := ["label", "amount", "x", "targets", "pt", "keywords", "color", "token", "unless",
	"from", "base", "land", "lose", "shield", "subtype", "where", "named", "only", "per"]
## The tables of [CommunityCard] that are vocabulary — each entry of each
## is measured or named "Not compared" ([method coverage]).
const VOCABULARY := ["EFFECTS", "TRIGGERS", "STATICS", "CARD_RULES", "KEYWORDS", "PROTECTIONS", "LANDS",
	"MANA_CHOICES", "ENCHANTS"]


## HOW EACH WORD OF THE VOCABULARY IS COMPARED, "TABLE/id" to a few words:
## the measures its own sentence is read as (each entry is written out by
## [CommunityCard] and read back, as a card's text is), "drawback",
## "keyword pile", "size", "priced", "once"/"repeats" for a trigger — or
## "not compared: …" from [constant _NOT_COMPARED]. "" means the entry
## has neither: a hole, which the tests refuse.
static func coverage() -> Dictionary:
	var out := {}
	var named := func(key: String, how: String) -> void:
		out[key] = how if how != "" else (("not compared: " + String(_NOT_COMPARED[key])) if _NOT_COMPARED.has(key) else "")
	for id: String in CommunityCard.EFFECTS:
		var kind := "activated" if id in CommunityCard.ACTIVATED_ONLY else "spell"
		var e := CommunityCard.effect_defaults(id, kind)
		named.call("EFFECTS/" + id, _how_read(_own_text({"abilities": [{"kind": kind, "cost": "{1}", "effects": [e]}]},
			["artifact"] if kind == "activated" else ["sorcery"])))
	for id: String in CommunityCard.TRIGGERS:
		var opening := String(CommunityCard.TRIGGERS[id])
		named.call("TRIGGERS/" + id, "once" if opening.begins_with("When ") else (
			"repeats" if opening.begins_with("Whenever ") or opening.begins_with("At ") else ""))
	for id: String in CommunityCard.STATICS:
		# Read both ways: what it gives and what it takes.
		var hows: Array[String] = []
		for sign: int in [1, -1]:
			var how := _how_read(_own_text({"abilities": [{"kind": "static", "what": id, "power": sign,
				"toughness": sign, "subtype": "goblin", "spell_type": "creature", "amount": 1}]}, ["enchantment"]))
			if how == "":
				hows.clear()
				break
			if not hows.has(how):
				hows.append(how)
		named.call("STATICS/" + id, " / ".join(hows))
	for id: String in CommunityCard.CARD_RULES:
		var info: Dictionary = CommunityCard.CARD_RULES[id]
		var value: Variant = true
		match String(info.get("kind", "flag")):
			"cost": value = "{1}"
			"amount": value = int((info.get("range", [1, 1]) as Array)[0])
			"count": value = "creature_you"
		named.call("CARD_RULES/" + id, _rule_how(_own_text({"rules": {id: value}}, ["creature"])))
	for id: String in CommunityCard.KEYWORDS:
		named.call("KEYWORDS/" + id, "drawback" if id in CommunityCard.HINDERING else "keyword pile")
	for id: String in CommunityCard.PROTECTIONS:
		named.call("PROTECTIONS/" + id, "keyword pile" if _text_gifts(_own_text({"protection": [id]}, ["creature"]).split("\n", false)) > 0 else "")
	for id: String in CommunityCard.LANDS:
		named.call("LANDS/" + id, "keyword pile" if _text_gifts(_own_text({"landwalk": [id]}, ["creature"]).split("\n", false)) > 0 else "")
	for id: String in CommunityCard.MANA_CHOICES:
		var text := _own_text({"abilities": [{"kind": "mana", "color": id, "amount": 1}]}, ["artifact"])
		var ability := _ability(text)
		named.call("MANA_CHOICES/" + id, "mana" if not ability.is_empty() and _mana_made(String(ability["effect"])) > 0 else "")
	for id: String in CommunityCard.ENCHANTS:
		named.call("ENCHANTS/" + id, _how_read(_own_text({"abilities": [{"kind": "enchant", "enchant": id,
			"power": 1, "toughness": 1}]}, ["enchantment"])))
	return out


## The rules text [CommunityCard] writes for [param part] alone (some
## abilities, some card rules) on a card of [param types], as this check
## reads it.
static func _own_text(part: Dictionary, types: Array) -> String:
	var spec := {"name": "CARDNAME", "types": types, "abilities": []}
	spec.merge(part, true)
	return _clean(CommunityCard.rules_text(spec))


## What [param text] is read as: its measures, "mana", "drawback" or "".
static func _how_read(text: String) -> String:
	var found := {}
	for line in text.split("\n", false):
		var piece := line.trim_prefix("• ")
		var ability := _ability(piece)
		if not ability.is_empty():
			piece = String(ability["effect"])
			if piece.begins_with("Add ") and _mana_made(piece) > 0:
				found["mana"] = true
		var opening := _rx("^(?:When|Whenever|At) [^,]*, ").search(piece)
		if opening != null:
			piece = piece.substr(opening.get_end())
		for sentence in piece.split(". ", false):
			for id: String in _read(sentence):
				found[id] = true
			for id: String in _read_static(sentence):
				found[id] = true
			if _rx("(?i)^add ").search(sentence) != null and _mana_made(sentence) > 0:
				found["mana"] = true
			if found.is_empty() and (_self_harm(sentence) or _static_drawback(sentence)):
				found["drawback"] = true
	return ", ".join(found.keys())


## How a card rule's own line is taken: "priced" (cycling, buyback: its
## cost beside the game's), "drawback", "keyword pile", "size" or "".
static func _rule_how(text: String) -> String:
	var lower := text.to_lower()
	if _rx("(?m)^(?:cycling|buyback) \\{").search(lower) != null:
		return "priced"
	if _rx("(?m)^echo |cumulative upkeep|unless you pay|, pay \\d+ life|can't block\\b|enters (?:the battlefield )?tapped").search(lower) != null:
		return "drawback"
	if _rx("rampage \\d|can't be blocked by walls|can block |can't be countered").search(lower) != null:
		return "keyword pile"
	if lower.contains("doesn't untap"):
		return "drawback"
	if _rx("(?m)^shroud\\b|can't be the target").search(lower) != null:
		return "keyword pile"
	if lower.contains("equal to") or (lower.contains("+1/+1 counter") and lower.contains("enters")):
		return "size"
	return "drawback" if _self_harm(lower) else ""


## Whether [param text] only costs its own controller (pain, a sacrifice
## of the card itself, a discard of one's own) — a drawback, never a
## strength left unmeasured.
static func _self_harm(text: String) -> bool:
	return _rx("(?i)damage to you\\b|\\byou lose \\d+ life|\\b(?:sacrifice|exile) (?:cardname|this \\w+)|^discard |\\byou discard|\\bsacrifice an? |doesn't untap during your").search(text) != null


## THE ROWS FOR WHAT WAS SET BESIDE NOTHING: each effect, static line, card
## rule, mana ability and trigger of [param spec] is written out alone and
## read back; one that reads as nothing gets a "Not compared" row with its
## label. (An effect of the pool's cards never have gets its row from the
## measure itself.)
static func _coverage_rows(rows: Array[Dictionary], spec: Dictionary) -> void:
	var types := CommunityCard._list(spec.get("types"))
	var creature := types.has("creature")
	var seen := {}
	var say := func(topic: String, text: String) -> void:
		if not seen.has(topic + text):
			seen[topic + text] = true
			rows.append({"level": NOT_COMPARED, "topic": topic, "yours": "", "text": text})
	var effects := func(list: Variant) -> void:
		if not list is Array:
			return
		for e: Variant in list:
			if not e is Dictionary:
				continue
			var id := String(e.get("effect", ""))
			var label := String((CommunityCard.EFFECTS.get(id, {}) as Dictionary).get("label", id))
			if _NOT_COMPARED.has("EFFECTS/" + id):
				say.call(label, "Not compared: %s." % String(_NOT_COMPARED["EFFECTS/" + id]))
				continue
			var kind := "activated" if id in CommunityCard.ACTIVATED_ONLY else "spell"
			var text := _own_text({"abilities": [{"kind": kind, "cost": "{1}", "effects": [e]}]},
				["artifact"] if kind == "activated" else ["sorcery"])
			if String(e.get("per", "")) != "":
				say.call(label, "Its amount is for each of something counted as it plays — not set beside the game's cards.")
			if _how_read(text) != "":
				continue
			if e.get("x", false) is bool and bool(e.get("x", false)):
				say.call(label, "Its amount is X, set as it is cast — not set beside the game's cards.")
			else:
				say.call(label, "This check has no measure for it — it was not set beside the game's cards.")
	var abilities: Variant = spec.get("abilities", [])
	if abilities is Array:
		for a: Variant in abilities:
			if not a is Dictionary:
				continue
			match String(a.get("kind", "")):
				"spell", "activated":
					effects.call(a.get("effects", []))
				"trigger":
					effects.call(a.get("effects", []))
					var opening := String(CommunityCard.TRIGGERS.get(String(a.get("when", "")), ""))
					if not (opening.begins_with("When") or opening.begins_with("At ")):
						say.call("Triggered ability", "This check does not know how often \"%s\" happens — not compared." % String(a.get("when", "")))
				"modal":
					var modes: Variant = a.get("modes", [])
					if modes is Array:
						for mode: Variant in modes:
							if mode is Dictionary:
								effects.call(mode.get("effects", []))
				"mana":
					var ability := _ability(_own_text({"abilities": [a]}, types))
					if ability.is_empty() or _mana_made(String(ability["effect"])) <= 0:
						say.call("Mana", "The mana this ability makes could not be read — not compared.")
				"static", "enchant":
					var label := "Aura" if String(a.get("kind", "")) == "enchant" else String(
						CommunityCard.static_info(String(a.get("what", ""))).get("label", "Static ability"))
					for sentence in _own_text({"abilities": [a]}, types).replace("\n", " ").split(". ", false):
						var said := sentence.trim_suffix(".")
						if _rx("^Enchant \\w+$").search(said) != null or said.begins_with("This effect doesn't remove"):
							continue
						if _how_read(said) == "":
							say.call(label, "\"%s\" — this check has no measure for it; not compared." % said)
				var other:
					say.call("Ability", "An ability of a kind this check does not know (\"%s\") — not compared." % other)
	var rules: Variant = spec.get("rules")
	if rules is Dictionary:
		for id: Variant in rules:
			var key := "CARD_RULES/" + String(id)
			var label := String((CommunityCard.CARD_RULES.get(id, {}) as Dictionary).get("label", id))
			if _NOT_COMPARED.has(key):
				say.call(label, "Not compared: %s." % String(_NOT_COMPARED[key]))
				continue
			var how := _rule_how(_own_text({"rules": {id: rules[id]}}, types))
			if how == "" or (how == "keyword pile" and not creature):
				say.call(label, "This check has no measure for it%s — not compared." % (
					"" if creature or how == "" else " on a card that is no creature"))
	if not creature:
		var pile := CommunityCard._list(spec.get("keywords")) + CommunityCard._list(spec.get("protection")) \
			+ CommunityCard._list(spec.get("landwalk"))
		var gifts := pile.filter(func(k: String) -> bool: return not k in CommunityCard.HINDERING)
		if not gifts.is_empty():
			say.call("Keywords", "Keywords on a card that is no creature (%s) — not compared." % ", ".join(gifts))


# ------------------------------------------------------ rules of thumb --

## THE RULES OF THUMB: simple lines that few of the game's cards cross —
## and those that do pay with a heavy drawback. A card past one is told so,
## with how many of the game's cards are past it too and which — COUNTED IN
## THE POOL IN USE ([method corpus], `thumb`), never quoted from another —
## and what would bring it back. A line fewer than 1 in 500 of the game's
## cards cross is "Very high", one up to 1 in 20 "High"; a line more of the
## pool crosses is no line there and is not told.
##
## For a creature, its drawbacks count as mana ([method _drawbacks_in]) and
## the +1/+1 counters it enters with count in its size; a creature with no
## power (a Wall, an Ornithopter) is left to the toughness line.
const THUMB_TOPIC := "Rule of thumb"


## The lines [param data] is past: `[id, yours, what is past what, advice]`.
static func _thumb_checks(f: Dictionary) -> Array:
	var out: Array = []
	var mv: int = f["mv"]
	var x: bool = f["x"]
	var land: bool = f["land"]
	var creature: bool = f["creature"]
	var d: int = f["drawbacks"]
	if creature and not x and not bool(f["star"]):
		var e := mv + d
		var body: Vector2i = f["body"]
		var size := body.x + body.y
		var paid := (" (its drawbacks counted as %d mana)" % d) if d > 0 else ""
		if body.x > 0 and size > 2 * e + 4:
			out.append(["size_far", str(size), "Power + toughness %d is far past 2 x cost + 4%s (here %d; yours %d)." % [size, paid, 2 * e + 4, size],
				"Raise the cost to %d or shrink it to %d in all." % [maxi(mv + 1, ceili((size - 1) / 2.0) - d), 2 * e + 1]])
		elif body.x > 0 and size > 2 * e + 1:
			out.append(["size", str(size), "Power + toughness %d is past 2 x cost + 1%s (here %d; yours %d)." % [size, paid, 2 * e + 1, size],
				"Raise the cost to %d or shrink it to %d in all." % [maxi(mv + 1, ceili((size - 1) / 2.0) - d), 2 * e + 1]])
		if body.x > e + 3:
			out.append(["power", str(body.x), "Power %d is past cost + 3%s (here %d; yours %d)." % [body.x, paid, e + 3, body.x],
				"Raise the cost to %d or lower its power to %d." % [maxi(mv + 1, body.x - 3 - d), e + 3]])
		if body.y > 2 * e + 4:
			out.append(["toughness", str(body.y), "Toughness %d is past 2 x cost + 4%s (here %d; yours %d)." % [body.y, paid, 2 * e + 4, body.y],
				"Raise the cost to %d or lower its toughness to %d." % [maxi(mv + 1, ceili((body.y - 4) / 2.0) - d), 2 * e + 4]])
		var gifts: int = f["gifts"]
		if gifts > 3:
			out.append(["keywords_many", str(gifts), "%d keywords are more than 3 (yours %d)." % [gifts, gifts],
				"Keep the three that matter most."])
		elif gifts >= 2 and mv <= 1:
			out.append(["keywords_cheap", str(gifts), "%d keywords for %d mana are more than 1 (yours %d)." % [gifts, mv, gifts],
				"Keep one keyword or raise the cost to 2."])
		elif gifts >= 3 and mv <= 3:
			out.append(["keywords_three", str(gifts), "3 keywords for %d mana are more than 2 (yours %d)." % [mv, gifts],
				"Drop a keyword or raise the cost to 4."])
	if not x:
		# A spell, or a triggered ability that happens once (as it enters).
		var r: Dictionary = f["once_read"]
		var damage := int(r.get("damage", 0))
		if damage > mv + 2:
			out.append(["spell_damage", str(damage), "A spell that deals %d damage is past cost + 2 (here %d; yours %d)." % [damage, mv + 2, damage],
				"Raise the cost to %d or lower the damage to %d." % [damage - 2, mv + 2]])
		var draw := int(r.get("draw", 0))
		if draw > mv + 2:
			out.append(["spell_draw_far", str(draw), "A spell that draws %d cards is far past cost + 1 (here %d; yours %d)." % [draw, mv + 1, draw],
				"Raise the cost to %d or draw %d." % [draw - 1, mv + 1]])
		elif draw > mv + 1:
			out.append(["spell_draw", str(draw), "A spell that draws %d cards is past cost + 1 (here %d; yours %d)." % [draw, mv + 1, draw],
				"Raise the cost to %d or draw %d." % [draw - 1, mv + 1]])
		var life := int(r.get("life", 0))
		if life > 2 * mv + 2:
			out.append(["spell_life", str(life), "A spell that gains %d life is past 2 x cost + 2 (here %d; yours %d)." % [life, 2 * mv + 2, life],
				"Raise the cost to %d or gain %d." % [ceili((life - 2) / 2.0), 2 * mv + 2]])
	for piece: Dictionary in f["pieces"]:
		if String(piece["kind"]) == "mana":
			var m: Dictionary = piece["mana"]
			if bool(m["once"]) or int(m["made"]) == 0:
				continue
			var net := int(m["net"])
			if land:
				if net - d >= 3:
					out.append(["land_mana_far", str(net), "A land that makes %d mana a turn is past 2 (yours %d)." % [net, net],
						"Make it tap for 1, or for 2 with a drawback (pain, enters tapped)."])
				elif net - d == 2:
					out.append(["land_mana", str(net), "A land that makes %d mana a turn%s is past 1 (yours %d)." % [net,
						" with no drawback" if d == 0 else ", its drawbacks counted,", net],
						"Make it tap for 1, or give it a drawback (pain, enters tapped)."])
			elif net > mv + 2:
				out.append(["mana_far", str(net), "A permanent that makes %d mana a turn is past cost + 2 (here %d; yours %d)." % [net, mv + 2, net],
					"Raise the cost to %d or make %d." % [net - 2, mv + 2]])
			elif creature and mv <= 2 and net > 1:
				out.append(["creature_mana", str(net), "A creature of %d mana that makes %d mana a turn is past 1 (yours %d)." % [mv, net, net],
					"Make it 1 mana or raise the cost to 3."])
		elif String(piece["kind"]) == "static":
			var r: Dictionary = piece["read"]
			var anthem := int(r.get("anthem", 0))
			if anthem > 5:
				out.append(["anthem_far", "+%d" % anthem, "An anthem worth +%d in all is far past +3 (yours +%d)." % [anthem, anthem],
					"Lower it to +1/+1."])
			elif anthem > 3:
				out.append(["anthem", "+%d" % anthem, "An anthem worth +%d in all is past +3 (yours +%d)." % [anthem, anthem],
					"Lower it to +1/+1."])
			var aura := int(r.get("aura", 0))
			if aura > 2 * mv + 2:
				out.append(["aura", "+%d" % aura, "An Aura worth +%d in all is past 2 x cost + 2 (here %d; yours +%d)." % [aura, 2 * mv + 2, aura],
					"Raise the cost to %d or lower it to +%d in all." % [ceili((aura - 2) / 2.0), 2 * mv + 2]])
	if not land and mv > 9:
		out.append(["cost", str(mv), "A cost of %d is past 9 (yours %d)." % [mv, mv], "Lower the cost."])
	var lines: PackedStringArray = f["lines"]
	if lines.size() > 5:
		out.append(["lines", str(lines.size()), "%d lines of rules are more than 5 (yours %d)." % [lines.size(), lines.size()],
			"Cut it down to what matters."])
	return out


static func _thumb_rows(rows: Array[Dictionary], c: Dictionary, _data: CardData, f: Dictionary) -> void:
	var stats: Dictionary = c.get("thumb", {})
	var total := int(c.get("all", 0))
	for check: Array in _thumb_checks(f):
		var stat: Dictionary = stats.get(check[0], {"past": 0, "names": []})
		var past := int(stat["past"])
		if past * 20 > total:
			continue
		var level := VERY_HIGH if past * 500 <= total else HIGH
		rows.append({"level": level, "topic": THUMB_TOPIC, "yours": String(check[1]),
			"text": "%s %s %s" % [check[2], _past_words(stat, total), check[3]],
			"rank": 1.4 if level == VERY_HIGH else 1.1})


## How many of the game's cards are past a line, and which.
static func _past_words(stat: Dictionary, total: int) -> String:
	var past := int(stat.get("past", 0))
	var names: Array = stat.get("names", [])
	if past == 0:
		return "None of the game's %d cards is past that line." % total
	var listed := ", ".join(names)
	if past == 1:
		return "Of the game's %d cards only %s is past it." % [total, listed]
	if past <= names.size():
		return "Of the game's %d cards only %d are past it (%s)." % [total, past, listed]
	return "%d of the game's %d cards are past it (%s and others)." % [past, total, listed]


## A row's sentence without its own "yours ..." clause — for a table that
## shows the card's number ([code]row["yours"][/code]) in a column of its
## own: "...; yours has 9." and " (yours has 4)" go, "(here 10; yours 12)"
## reads "(here 10)". A row without a number keeps its whole sentence.
static func game_words(row: Dictionary) -> String:
	var text := String(row.get("text", ""))
	if String(row.get("yours", "")) == "":
		return text
	if _yours_rx.is_empty():
		_yours_rx = [RegEx.create_from_string(";\\s*yours\\b[^.;)]*"),
			RegEx.create_from_string("\\s*\\(yours\\b[^)]*\\)")]
	for rx: RegEx in _yours_rx:
		text = rx.sub(text, "", true)
	return text


static var _yours_rx: Array[RegEx] = []


static func _rank(level: String) -> int:
	return {OK: 0, LOW: 1, HIGH: 2, VERY_HIGH: 3}.get(level, 0)


## A CREATURE'S DRAWBACKS, IN MANA, read from the rules text (so the game's
## own cards get the same credit) and SCALED BY WHAT THEY COST: echo or an
## upkeep payment of three mana or more 2, a smaller one 1; cumulative
## upkeep 1; can't block 1; defender 1; an extra cost of 2 or 3 life 1, of
## 4 or more 2 (1 life buys nothing); damage or life lost each upkeep 2,
## three or more 3 (the game prices it so: a Juzám Djinn, a Serendib
## Efreet); sacrificed at end of turn 2; doesn't untap 1. Four at most.
static func _drawbacks_in(data: CardData, text: String) -> int:
	var lower := text.to_lower()
	var n := 0
	if data.keywords.has(Mtg.Keyword.DEFENDER):
		n += 1
	var echo := _rx("(?m)^echo ((?:\\{[^}]+\\})+)").search(lower)
	if echo != null:
		n += 2 if _symbols_value(echo.get_string(1)) >= 3 else 1
	if lower.contains("cumulative upkeep"):
		n += 1
	if lower.contains("unless"):
		var unless := _rx("sacrifice (?:cardname|this \\w+) unless you pay ((?:\\{[^}]+\\})+)").search(lower)
		if unless != null:
			n += 2 if _symbols_value(unless.get_string(1)) >= 3 else 1
		elif _rx("sacrifice (?:cardname|this \\w+) unless").search(lower) != null:
			n += 1
	if lower.contains("can't block") and _rx("(?:cardname|this creature) can't block(?:\\.|$)").search(lower) != null:
		n += 1
	if lower.contains("additional cost"):
		var life := _rx("as an additional cost to cast [^,]*, pay (\\d+) life").search(lower)
		if life != null:
			n += mini(2, int(life.get_string(1)) / 2)
	if lower.contains("upkeep"):
		var pain := _rx("at the beginning of your upkeep, [^.]*?(?:deals (\\d+) damage to you|you lose (\\d+) life)").search(lower)
		if pain != null:
			n += 3 if maxi(int(pain.get_string(1)), int(pain.get_string(2))) >= 3 else 2
	if lower.contains("end step") and _rx("at the beginning of (?:the|your) end step, sacrifice (?:cardname|this)").search(lower) != null:
		n += 2
	if lower.contains("doesn't untap during your untap step"):
		n += 1
	return mini(n, 4)


## A land's drawbacks, one each: enters tapped, pain, doesn't untap, an
## upkeep to pay, a land to return or to give up.
static func _land_drawbacks(text: String) -> int:
	var lower := text.to_lower()
	var n := 0
	for pattern: String in ["enters (?:the battlefield )?tapped", "damage to you\\b|you lose \\d+ life", "doesn't untap",
			"cumulative upkeep|(?m)^echo |sacrifice (?:cardname|this land) unless",
			"return an? [a-z ]*land[a-z ]* to its owner's hand|depletion counter|sacrifice an? [a-z ]*land"]:
		if _rx(pattern).search(lower) != null:
			n += 1
	return n


static func _cost_rows(rows: Array[Dictionary], c: Dictionary, f: Dictionary) -> void:
	var costs: Array = c["costs"]
	if costs.is_empty():
		return
	var mv: int = f["mv"]
	var top := int(costs[-1])
	var at_least := costs.size() - costs.bsearch(mv)
	if mv > top:
		rows.append({"yours": str(mv), "level": VERY_HIGH, "topic": "Mana cost",
			"text": "No card of the game costs more than %d (%s); yours costs %d." % [top, c["costs_top_name"], mv]})
	elif mv >= 7 and at_least * 50 < costs.size():
		rows.append({"yours": str(mv), "level": HIGH, "topic": "Mana cost",
			"text": "Only %d of the game's %d cards cost %d or more." % [at_least, costs.size(), mv]})
	elif mv == 0 and bool(f["x"]):
		rows.append({"yours": "X", "level": OK, "topic": "Mana cost", "text": "Its cost is X, paid as it is cast."})
	elif mv == 0:
		# Costing nothing is rare, not wrong (a Mox, an Ornithopter): what the
		# card does for nothing is what the rows below weigh.
		rows.append({"yours": "0", "level": OK, "topic": "Mana cost",
			"text": "Cards that cost nothing are rare (%d of the game's %d) — what it does for nothing is weighed in the other lines." % [int(c["free"]), costs.size()]})
	else:
		rows.append({"yours": str(mv), "level": OK, "topic": "Mana cost", "text": "A cost of %d is usual." % mv})


static func _creature_rows(rows: Array[Dictionary], c: Dictionary, _data: CardData, f: Dictionary) -> void:
	var mv: int = f["mv"]
	# Drawbacks count as mana (echo, upkeep, can't block, …).
	var drawbacks: int = f["drawbacks"]
	var shelf := mini(mv + drawbacks, TOP_SHELF)
	var said := ("%d-mana" % shelf) if drawbacks == 0 else ("%d-mana (its drawbacks counted as mana)" % shelf)
	var body: Vector2i = f["body"]
	var size := body.x + body.y
	var shown := "%d/%d (%d)" % [body.x, body.y, size]
	var lower := String(f["text"]).to_lower()
	var bucket: Dictionary = (c["size"] as Dictionary).get(shelf, {})
	if body.y <= 0 and not (lower.contains("equal to") or lower.contains("counter")
			or _rx("gets? \\+\\d+/\\+[1-9]").search(lower) != null):
		rows.append({"yours": "%d/%d" % [body.x, body.y], "level": LOW, "topic": "Size", "rank": 0.0,
			"text": "A %d/%d creature with no counters dies on arrival — give it toughness, or +1/+1 counters to enter with." % [body.x, body.y]})
	elif bool(f["star"]):
		rows.append({"yours": "", "level": NOT_COMPARED, "topic": "Size",
			"text": "Its power and toughness are set as it plays — its size was not set beside the game's creatures."})
	elif not bucket.is_empty():
		var values: Array = bucket["values"]
		var usual := _at(values, SIZE_USUAL)
		var small := _at(values, 1.0 - SIZE_SMALL)
		var rank := _rank_in(values, size)
		if size > int(bucket["max"]):
			rows.append({"yours": shown, "level": VERY_HIGH, "topic": "Size", "rank": rank,
				"text": "The biggest %s creature of the game is %s (%s); yours is %d/%d." % [said,
					bucket["max_name"], bucket["max_shown"], body.x, body.y]})
		elif _past_usual(values, size, SIZE_USUAL):
			rows.append({"yours": shown, "level": HIGH, "topic": "Size", "rank": rank,
				"text": "%s of the game's %s creatures have power + toughness %d or less; yours has %d." % [SIZE_SAID, said, usual, size]})
		elif size < small:
			rows.append({"yours": shown, "level": LOW, "topic": "Size", "rank": rank,
				"text": "9 in 10 of the game's %s creatures have power + toughness %d or more; yours has %d." % [said, small, size]})
		else:
			rows.append({"yours": shown, "level": OK, "topic": "Size", "rank": rank,
				"text": "%d/%d is a usual size for a %s creature (most are %d to %d in power + toughness)." % [
					body.x, body.y, said, small, usual]})
	for side in [["power", body.x], ["toughness", body.y]]:
		var most: Dictionary = c["most_" + String(side[0])]
		if int(side[1]) > int(most["value"]):
			rows.append({"yours": str(side[1]), "level": VERY_HIGH, "topic": String(side[0]).capitalize(),
				"text": "No creature of the game has more %s than %d (%s); yours has %d." % [side[0],
					most["value"], most["name"], side[1]]})
	# The keyword pile: keywords, protections, landwalks, rampage and the
	# like, one each. Two is never much (a Serra Angel).
	var kw_shelf := mini(mv, TOP_SHELF)
	var keywords: Dictionary = (c["keywords"] as Dictionary).get(kw_shelf, {})
	var count: int = f["gifts"]
	if not keywords.is_empty() and count > 0:
		var rank := _rank_in(keywords["values"], count)
		var most := maxi(_at(keywords["values"], USUAL_KEYWORDS), KEYWORDS_FREE)
		if count > int(keywords["max"]):
			rows.append({"yours": str(count), "level": VERY_HIGH if count > KEYWORDS_FREE else HIGH, "topic": "Keywords",
				"rank": rank, "worth": 0.8,
				"text": "No %d-mana creature of the game has more than %s (%s); yours has %d." % [
					kw_shelf, _keywords(int(keywords["max"])), keywords["max_name"], count]})
		elif count > KEYWORDS_FREE and _past_usual(keywords["values"], count, USUAL_KEYWORDS):
			rows.append({"yours": str(count), "level": HIGH, "topic": "Keywords", "rank": rank, "worth": 0.8,
				"text": "Almost all of the game's %d-mana creatures have %s or fewer; yours has %d." % [
					kw_shelf, _keywords(most), count]})
		else:
			rows.append({"yours": str(count), "level": OK, "topic": "Keywords", "rank": rank, "worth": 0.8,
				"text": "%s (protections and landwalks counted) %s usual for a %d-mana creature." % [
					_upper(_keywords(count)), "is" if count == 1 else "are", kw_shelf]})


static func _keywords(n: int) -> String:
	return "no keyword" if n == 0 else ("1 keyword" if n == 1 else "%d keywords" % n)


## Where [param n] sits among [param values] (sorted): the share of them
## under it, those level with it counted half — and past 1 (to 1.5) beyond
## the biggest.
static func _rank_in(values: Array, n: int) -> float:
	if values.is_empty():
		return 0.5
	var top := int(values[-1])
	if n > top:
		return 1.0 + minf(0.5, float(n - top) / float(maxi(top, 1) + 2))
	return 0.5 * (values.bsearch(n, true) + values.bsearch(n, false)) / values.size()


## Whether [param n] is past what [param share] of [param values] (sorted)
## keep to — said only of a shelf with cards enough for one of them to be
## past it (34 for "almost all"): on a smaller shelf only "more than any"
## is told.
static func _past_usual(values: Array, n: int, share: float) -> bool:
	return values.size() * (1.0 - share) >= 1.0 and n > _at(values, share)



# ---------------------------------------------------------- the measures --

## THE MEASURES: everything a line of rules text is read as, each with the
## check's name in the table, what the game's cards "do" (plural), the unit
## its number counts ("" for an effect that is there or not — those are
## set beside the game's cards by cost alone: the cheapest that does it)
## and its worth in [method power]. How each is read: [constant _READS]
## and [method _read], [method _read_static].
const _M := {
	"damage": ["Damage", "deal", "damage", 1.0],
	"draw": ["Cards drawn", "draw", "cards", 1.0],
	"life": ["Life", "give", "life", 0.5],
	"lose_life": ["Life lost", "make a player lose", "life", 0.8],
	"discard": ["Discard", "make a player discard", "cards", 0.9],
	"mill": ["Mill", "mill", "cards", 0.4],
	"tokens": ["Tokens", "create tokens of", "power + toughness in all", 1.0],
	"tutor": ["Search", "search a library for", "cards", 1.0],
	"regrowth": ["Graveyard", "return", "cards from a graveyard", 0.8],
	"pump": ["Pump", "give", "power + toughness until end of turn (a keyword counts as 1)", 0.6],
	"shrink": ["Shrink", "take away", "power + toughness until end of turn", 0.7],
	"mass_pump": ["Pump for all", "give each creature", "power + toughness until end of turn (a keyword counts as 1)", 0.8],
	"mass_shrink": ["Shrink for all", "take from each creature", "power + toughness until end of turn", 0.9],
	"counters": ["+1/+1 counters", "put", "+1/+1 counters", 0.7],
	"minus_counters": ["-1/-1 counters", "put", "-1/-1 counters", 0.8],
	"prevent": ["Prevention", "prevent", "damage", 0.4],
	"cost_less": ["Cost reduction", "lower costs by", "mana", 1.0],
	"cost_more": ["Cost tax", "raise costs by", "mana", 0.7],
	"attack_tax": ["Attack tax", "tax each attacker", "mana", 0.8],
	"reanimate": ["Graveyard", "put a card from a graveyard onto the battlefield", "", 1.0],
	"animate": ["Becomes a creature", "become creatures of", "power + toughness", 0.6],
	"anthem": ["Anthem", "give each creature", "power + toughness (a keyword counts as 1)", 1.0],
	"weaken": ["Weakening", "take from each creature", "power + toughness", 1.0],
	"aura": ["Aura", "give the enchanted creature", "power + toughness (a keyword counts as 1)", 0.7],
	"aura_minus": ["Aura, weakening", "take from the enchanted creature", "power + toughness", 0.8],
	"sweep_creatures": ["Mass destruction", "destroy all creatures", "", 1.0],
	"sweep_lands": ["Mass destruction", "destroy all lands", "", 1.0],
	"sweep_other": ["Mass destruction", "destroy all artifacts, enchantments or permanents", "", 0.9],
	"kill": ["Destruction", "destroy a creature", "", 0.9],
	"kill_land": ["Destruction", "destroy a land", "", 0.8],
	"kill_other": ["Destruction", "destroy an artifact or an enchantment", "", 0.6],
	"exile": ["Exile", "exile a creature or a permanent", "", 0.9],
	"bounce": ["Return to hand", "return a permanent to its owner's hand", "", 0.6],
	"counter": ["Counterspell", "counter a spell", "", 0.9],
	"counter_ability": ["Counter an ability", "counter an activated ability", "", 0.4],
	"steal": ["Control", "take control of a permanent", "", 1.0],
	"edict": ["Sacrifice", "make a player sacrifice a creature", "", 0.8],
	"tap": ["Tap", "tap a permanent", "", 0.4],
	"untap": ["Untap", "untap a permanent", "", 0.4],
	"regenerate": ["Regeneration", "regenerate a creature", "", 0.5],
	"fog": ["Fog", "prevent all combat damage", "", 0.4],
	"extra_turn": ["Extra turn", "give an extra turn", "", 1.0],
	"land_search": ["Land search", "search a library for a land", "", 0.6],
	"shield": ["Prevention", "prevent the damage of one source", "", 0.4],
	"set_pt": ["Base power/toughness", "set a creature's power and toughness", "", 0.5],
	"switch_pt": ["Switch", "switch a creature's power and toughness", "", 0.4],
	"give_landwalk": ["Landwalk", "give landwalk", "", 0.4],
	"strip": ["Lose a keyword", "take a keyword away", "", 0.4],
	"reshuffle": ["Shuffle back", "shuffle a hand or a graveyard into a library", "", 0.6],
	"pacify": ["Pacify", "keep a creature from attacking and blocking", "", 0.8],
	"freeze": ["Keep tapped", "keep a permanent from untapping", "", 0.7],
	"ward": ["Protection", "give protection from a color", "", 0.5],
}
## The measures an ability is set beside others by its own price for; the
## rest go by all the mana spent, card and price — a cheap card may not
## hide a big ability behind a small price.
const _BY_PRICE := ["pump", "shrink", "regenerate", "animate"]
## Cards doing a thing in the pool before "no card does it for less" is
## called very high and before "almost all" is said of a shelf; with fewer
## the row says how few it had to go by and stops at "High".
const EVIDENCE := 3
const _KIND_WORDS := {"spell": "spells", "ability": "abilities", "once": "one-shot abilities",
	"price": "abilities", "static": "permanents"}


## One measure of the card beside the game's: [param n] of [param id]
## among the [param kind] ("spell", "ability", "once", "price", "static")
## of [param shelf], said as [param said]; [param note] is added after.
static func _measure_row(rows: Array[Dictionary], c: Dictionary, kind: String, id: String, n: int,
		shelf: int, said: String, note := "") -> void:
	var info: Array = _M.get(id, [])
	if info.is_empty():
		return
	var table: Dictionary = ((c["m"] as Dictionary).get(kind, {}) as Dictionary).get(id, {})
	var does := String(info[1])
	var unit := String(info[2])
	var presence := unit == ""
	if unit == "cards" and n == 1:
		unit = "card"
	var row := {"topic": String(info[0]), "yours": "" if presence else str(n), "worth": float(info[3])}
	var kinds := String(_KIND_WORDS.get(kind, "cards"))
	var evidence := 0
	var cheapest := -1
	var at_least := 0
	for key: Variant in table:
		var size := (table[key]["values"] as Array).size()
		evidence += size
		if int(key) >= shelf:
			at_least += size
		if cheapest < 0 or int(key) < cheapest:
			cheapest = int(key)
	if evidence == 0:
		# None of that kind: is it past everything the game's other cards do?
		var other := {}
		for k: String in c["m"]:
			var elsewhere: Dictionary = (c["m"][k] as Dictionary).get(id, {})
			for key: Variant in elsewhere:
				if other.is_empty() or int(elsewhere[key]["max"]) > int(other["max"]):
					other = elsewhere[key]
		if other.is_empty():
			row["level"] = NOT_COMPARED
			row["text"] = "None of the game's cards %s — there is nothing to set it beside." % does
		elif not presence and n > int(other["max"]):
			row["level"] = HIGH
			row["rank"] = 1.1
			row["text"] = "None of the game's %s %s; its other cards %s at most %d %s (%s); yours %d." % [
				kinds, _does_plain(does), does, other["max"], unit, other["max_name"], n]
		else:
			row["level"] = NOT_COMPARED
			row["text"] = "None of the game's %s %s (other cards of the game do: %s) — it was not set beside them." % [
				kinds, _does_plain(does), other["max_name"]]
		rows.append(row)
		return
	var strong := VERY_HIGH if evidence >= EVIDENCE else HIGH
	var few := "" if evidence >= EVIDENCE else " Only %d of the game's %s to go by." % [evidence, kinds]
	var cheapest_name := String(table[cheapest]["max_name"])
	var or_cheaper := said if shelf == 0 else said + " or cheaper"
	var text := ""
	var level := OK
	var rank := 0.5
	if presence:
		if shelf >= cheapest:
			rank = 0.5 + 0.5 * float(at_least) / evidence
			text = "The game's %s %s from %d mana (%s)." % [kinds, does, cheapest, cheapest_name]
		else:
			level = strong
			rank = 1.0 + minf(0.5, 0.25 * (cheapest - shelf))
			text = "None of the game's %s %s; the cheapest costs %d (%s).%s" % [or_cheaper, does, cheapest, cheapest_name, few]
	else:
		var bucket: Dictionary = table.get(shelf, {})
		if bucket.is_empty():
			var best := _best_below(table, shelf)
			if best.is_empty():
				level = strong
				rank = 1.0 + minf(0.5, 0.25 * (cheapest - shelf))
				text = "None of the game's %s %s at all; the cheapest costs %d (%s).%s" % [or_cheaper, _does_plain(does), cheapest, cheapest_name, few]
			elif n > int(best["max"]):
				level = strong
				rank = _rank_in(best["values"], n)
				text = "The game's %s %s at most %d %s (%s); yours %d.%s" % [or_cheaper, does, best["max"], unit, best["max_name"], n, few]
			else:
				rank = minf(_rank_in(best["values"], n), 0.9)
				text = "%d %s is in reach of the game's cheaper cards (%s)." % [n, unit, best["max_name"]]
		else:
			var values: Array = bucket["values"]
			var usual := _at(values, USUAL)
			rank = _rank_in(values, n)
			if n > int(bucket["max"]):
				level = strong
				text = "The game's %s %s at most %d %s (%s); yours %d.%s" % [said, does, bucket["max"], unit, bucket["max_name"], n, few]
			elif _past_usual(values, n, USUAL):
				level = HIGH
				text = "Almost all of the game's %s %s %d %s or less (%s: %d); yours %d." % [said, does, usual, unit,
					bucket["max_name"], bucket["max"], n]
			else:
				text = "%d %s is usual for %s." % [n, unit, said]
	row["level"] = level
	row["rank"] = rank
	row["text"] = text + note
	rows.append(row)


## The rules text, piece by piece ([method _pieces]): what a spell, an
## ability, a trigger or a static line gives for its price, the mana a
## permanent makes, how many things a line does and how many lines the
## card has.
static func _text_rows(rows: Array[Dictionary], c: Dictionary, f: Dictionary) -> void:
	var mv: int = f["mv"]
	var land: bool = f["land"]
	var shelf := mini(mv, TOP_SHELF)
	var lines: PackedStringArray = f["lines"]
	# A spell: each measure once, the biggest of its lines (of a "Choose
	# one —" spell, its biggest mode).
	var spell_read: Dictionary = f["spell_read"]
	for id: String in spell_read:
		if id == "burst":
			_burst_row(rows, c, int(spell_read[id]))
		else:
			_measure_row(rows, c, "spell", id, int(spell_read[id]), shelf, "%d-mana spells" % shelf)
	for piece: Dictionary in f["pieces"]:
		var read: Dictionary = piece["read"]
		var kind := String(piece["kind"])
		match kind:
			"mana":
				_mana_rows(rows, c, piece["mana"], f)
			"ability", "once":
				var price := int(piece["price"])
				for id: String in read:
					if id in _BY_PRICE:
						_measure_row(rows, c, "price", id, int(read[id]), mini(price, TOP_SHELF),
							"abilities of price %d" % mini(price, TOP_SHELF))
					else:
						var total := mini(mv + price, TOP_SHELF)
						_measure_row(rows, c, kind, id, int(read[id]), total, "%s that cost %d in all (card and price)" % [
							"one-shot abilities" if kind == "once" else "abilities", total])
			"trigger":
				# A trigger is measured like a spell of the card's cost when it
				# happens once, like an ability whose whole price is the card when
				# it happens again and again.
				for id: String in read:
					if not bool(piece["repeats"]):
						_measure_row(rows, c, "spell", id, int(read[id]), shelf, "%d-mana spells" % shelf,
							" (A triggered ability that happens once: set beside spells of the card's cost.)")
					elif id in _BY_PRICE:
						_measure_row(rows, c, "price", id, int(read[id]), 1, "abilities of price 1",
							" (A triggered ability that happens again and again: set beside the cheapest abilities.)")
					else:
						_measure_row(rows, c, "ability", id, int(read[id]), shelf, "abilities that cost %d in all (card and price)" % shelf,
							" (A triggered ability that happens again and again: set beside abilities, the card its whole price.)")
			"static":
				for id: String in read:
					_measure_row(rows, c, "static", id, int(read[id]), shelf, "%d-mana permanents" % shelf)
	var priced: Dictionary = f["priced"]
	for id: String in priced:
		_priced_row(rows, c, id, int(priced[id]))
	var things := 0
	for line in lines:
		var clauses := _clauses(line)
		things += clauses
		if clauses > int(c["clauses_max"]):
			rows.append({"yours": str(clauses), "level": VERY_HIGH, "topic": "Effects",
				"text": "No line of the game's cards does more than %d things; \"%s\" does %d." % [
					c["clauses_max"], _short(line), clauses]})
	_effects_row(rows, c, things, shelf, land)
	if lines.size() > int(c["lines_max"]):
		rows.append({"yours": str(lines.size()), "level": VERY_HIGH, "topic": "Rules text",
			"text": "No card of the game has more than %d lines of rules (%s); yours has %d." % [
				c["lines_max"], c["lines_max_name"], lines.size()]})
	elif lines.size() > int(c["lines_rare"]):
		rows.append({"yours": str(lines.size()), "level": HIGH, "topic": "Rules text",
			"text": "Only 1 in 100 of the game's cards has %d lines of rules or more." % lines.size()})


## How many things the whole card does, beside the game's cards of its cost.
static func _effects_row(rows: Array[Dictionary], c: Dictionary, n: int, shelf: int, land: bool) -> void:
	var bucket: Dictionary = (c["verbs"] as Dictionary).get("land" if land else shelf, {})
	if bucket.is_empty() or n == 0:
		return
	var said := "lands" if land else "%d-mana cards" % shelf
	var usual := _at(bucket["values"], USUAL)
	if n > int(bucket["max"]):
		rows.append({"yours": str(n), "level": VERY_HIGH, "topic": "Effects",
			"text": "None of the game's %s does more than %d things (%s); yours does %d." % [said, bucket["max"],
				bucket["max_name"], n]})
	elif _past_usual(bucket["values"], n, USUAL):
		rows.append({"yours": str(n), "level": HIGH, "topic": "Effects",
			"text": "Almost all of the game's %s do %d things or fewer; yours does %d." % [said, usual, n]})
	else:
		rows.append({"yours": str(n), "level": OK, "topic": "Effects", "text": "%d %s usual for %s." % [n, "thing is" if n == 1 else "things are", said]})


## "give" for "give each creature" and the like where no number follows.
static func _does_plain(does: String) -> String:
	return {"put": "put counters", "give": "give that", "take away": "take that away", "return": "return cards",
		"prevent": "prevent damage", "deal": "deal damage", "draw": "draw cards", "mill": "mill cards"}.get(does, does)


static func _best_below(table: Dictionary, shelf: int) -> Dictionary:
	var best := {}
	for key: Variant in table:
		if int(key) <= shelf and (best.is_empty() or int(table[key]["max"]) > int(best["max"])):
			best = table[key]
	return best


## THE MANA AN ABILITY MAKES, WHATEVER ITS PRICE: what it adds less what
## the ability costs (each mana, each sacrifice, discard, counter or life
## payment one) — a use for a permanent that keeps it, beside the game's
## permanents of its cost or the game's lands (a land's drawbacks taken
## off first: pain, enters tapped); once for one that is sacrificed
## ([method _burst_row]).
static func _mana_rows(rows: Array[Dictionary], c: Dictionary, m: Dictionary, f: Dictionary) -> void:
	var land: bool = f["land"]
	var mv: int = f["mv"]
	if int(m["made"]) <= 0:
		rows.append({"yours": "", "level": NOT_COMPARED, "topic": "Mana",
			"text": "The mana it makes changes as it plays — not set beside the game's cards."})
		return
	if bool(m["once"]):
		_burst_row(rows, c, int(m["net"]) - (0 if land else mv))
		return
	var drawbacks: int = f["drawbacks"] if land else 0
	var n := int(m["net"]) - drawbacks
	var shelf := "land" if land else str(mini(mv, TOP_SHELF))
	var bucket: Dictionary = (c["mana"] as Dictionary).get(shelf, {})
	var said := "lands" if land else "%s-mana permanents" % shelf
	var counted := ", the ability's own costs%s taken off" % (" and its drawbacks" if drawbacks > 0 else "")
	var row := {"yours": str(n), "topic": "Mana", "worth": 1.0}
	if bucket.is_empty():
		row.merge({"level": HIGH, "rank": 1.1, "text": "None of the game's %s makes mana; yours makes %d a use%s." % [said, n, counted]})
	else:
		var values: Array = bucket["values"]
		row["rank"] = _rank_in(values, n)
		if n > int(bucket["max"]):
			row.merge({"level": VERY_HIGH, "text": "The game's %s make at most %d mana a use%s (%s); yours makes %d." % [
				said, bucket["max"], counted, bucket["max_name"], n]})
		elif _past_usual(values, n, USUAL):
			row.merge({"level": HIGH, "text": "Almost all of the game's %s make %d mana a use or less%s (%s makes %d); yours makes %d." % [
				said, _at(values, USUAL), counted, bucket["max_name"], bucket["max"], n]})
		else:
			row.merge({"level": OK, "text": "%d mana a use%s is in reach of the game's %s (%s makes %d)." % [
				n, counted, said, bucket["max_name"], bucket["max"]]})
	rows.append(row)


## MANA MADE ONCE — a ritual, a permanent sacrificed for mana: how much
## more than everything paid for it (the card, the ability) comes back,
## beside all of the game's cards that do the same.
static func _burst_row(rows: Array[Dictionary], c: Dictionary, n: int) -> void:
	var bucket: Dictionary = (c["burst"] as Dictionary).get("all", {})
	var row := {"yours": "%+d" % n, "topic": "Mana, once", "worth": 1.0}
	if bucket.is_empty():
		row.merge({"level": NOT_COMPARED, "text": "None of the game's cards makes mana once (a ritual, a permanent sacrificed for mana) — there is nothing to set it beside."})
		rows.append(row)
		return
	var values: Array = bucket["values"]
	var top := int(bucket["max"])
	row["rank"] = _rank_in(values, n)
	if n > top:
		row.merge({"level": VERY_HIGH if values.size() >= EVIDENCE else HIGH,
			"text": "No card of the game gives more than %d mana beyond all it costs, once (%s); yours %+d." % [top, bucket["max_name"], n]})
	elif n > 0 and _past_usual(values, n, USUAL):
		row.merge({"level": HIGH, "text": "Almost all of the game's one-shot mana gives %d or less beyond all it costs (%s gives %d); yours %+d." % [
			_at(values, USUAL), bucket["max_name"], top, n]})
	elif n > 0:
		row.merge({"level": OK, "text": "%d mana beyond all it costs, once, is in reach of the game's cards (%s gives %d)." % [n, bucket["max_name"], top]})
	else:
		row.merge({"level": OK, "text": "It gives back no more mana than it costs."})
	rows.append(row)


## Cycling and buyback: the cheaper, the stronger — beside the cheapest of
## the game's.
static func _priced_row(rows: Array[Dictionary], c: Dictionary, id: String, n: int) -> void:
	var bucket: Dictionary = ((c["priced"] as Dictionary).get(id, {}) as Dictionary).get("all", {})
	var row := {"yours": str(n), "topic": _upper(id)}
	if bucket.is_empty():
		row.merge({"yours": "", "level": NOT_COMPARED, "text": "None of the game's cards has %s — there is nothing to set it beside." % id})
		rows.append(row)
		return
	var cheapest := -int(bucket["max"])
	var size := (bucket["values"] as Array).size()
	if n < cheapest:
		row.merge({"level": VERY_HIGH if size >= EVIDENCE else HIGH, "rank": 1.25, "worth": 0.5,
			"text": "The cheapest %s of the game costs %d (%s); yours %d." % [id, cheapest, bucket["max_name"], n]})
	else:
		row.merge({"level": OK, "text": "%s for %d is usual (the game's cheapest costs %d: %s)." % [_upper(id), n, cheapest, bucket["max_name"]]})
	rows.append(row)


static func _short(line: String) -> String:
	return line if line.length() <= 60 else line.left(57) + "..."


# ---------------------------------------------------- the card's color --

## THE CARD'S OWN COLOR (2026-11-17): a one-color card is set beside the
## game's cards of that color, a colorless one beside the colorless ones.
## Crude and evident on purpose: with all ten packs on, fewer than 1 in 20
## of the game's own cards get a color line ([method corpus] counts them,
## `color_flagged`) — a Prodigal Sorcerer, an Armageddon or a Serra Angel
## none.
##
## A GOLD card (two colors or more) is read two ways, the one that reads
## better for each. Its size is set beside the gold creatures, which pay
## with two colors and are bigger for it (with all ten packs on, the gold
## 4-drops average 5.7 in power + toughness, the one-color ones 4.2 to
## 5.2), so a gold card measured against one color would be called big for
## being gold.
## What it does is set beside each of its colors and the kindest counts:
## an effect is at home on a card when it is at home in any of its colors
## (a white and blue card may counter a spell), and the gold cards
## together are a mix of every pair, whose shares mean nothing.
##
## Lands are left out on both sides: they are colorless and tap for mana.
const PIE_TOPIC := "Color"
## The creatures of one color and mana value are a shelf of their own only
## when there are this many; with fewer, nothing is said (the rows of all
## colors stand).
const COLOR_SHELF_MIN := 15
## The by-color rows speak only where the rows of all colors call a
## creature's size or keywords unusual, and then say whether its own color
## goes that far: "almost all" of the shelf (97 in 100) is the line, so a
## big green creature is green and not a warning.
const COLOR_USUAL := 0.97
## An effect is "at home" in the color whose cards have it most often; it
## is told only when at least this many of that color's cards have it —
## fewer prove nothing.
const PIE_EVIDENCE := 20
## With fewer than that but at least this many (the default pool: seven
## blue counterspells), only "none or almost none of the color's cards do
## it" is told, and the row says how small the sample is.
const PIE_EVIDENCE_FEW := 6
## "Few": at most a tenth of the home color's share, and fewer than 1 in
## 20 of the color's cards. "Almost none": at most a 25th of it, and fewer
## than 1 in 200. Either way the row's level is [constant RARE] ("Rare in
## color"), never a verdict on strength: a color hint is a matter of
## flavor. Only a spell that counters ANY spell (or any creature or
## noncreature spell) counts as a counterspell — the color hosers of every
## color and the conditional ones (Equinox) do not make countering at home
## there. (A quarter called Prodigal Sorcerer and
## Armageddon off-color: blue pings at a fifth of red's rate, white
## destroys lands at a seventh.)
const PIE_FEW := 10.0
const PIE_FEW_SHARE := 0.05
const PIE_NONE := 25.0
const PIE_NONE_SHARE := 0.005
const COLOR_KEYS := {Mtg.ManaColor.W: "W", Mtg.ManaColor.U: "U", Mtg.ManaColor.B: "B",
	Mtg.ManaColor.R: "R", Mtg.ManaColor.G: "G"}
const COLOR_WORDS := {"W": "white", "U": "blue", "B": "black", "R": "red", "G": "green",
	"C": "colorless", "M": "gold"}
const _WHO := "(?:target player|target opponent|each player|each opponent|that player|its controller|defending player|an opponent)"
const _DESTROY := "\\bdestroy (?:target|all|each|another|up to \\w+ target)[^.]*?"
## WHAT A CARD DOES, as the color hints read it: each effect's plain words,
## the words a sentence must hold before its pattern is tried ("|" between
## choices) and the pattern, matched on one lowered sentence at a time with
## its "When …," / "Whenever …," / "At …," opening left off (so "Whenever
## a player draws a card" is not a draw). Which effects are rare in which
## color is not written here: the game's cards say it ([method corpus]).
const _PIE_EFFECTS := {
	"damage": ["deal direct damage", "damage", "deals (?:x|\\d+) damage to (?!you\\b)"],
	"draw": ["draw cards", "draw", "\\bdraws? (?:a|an|one|two|three|four|five|six|seven|x|\\d+) cards?"],
	"life": ["gain life", "life", "^(?:(?!loses)[^.])*?\\bgains? (?:x|\\d+) life"],
	"lose_life": ["make a player lose life", "loses", "\\bloses (?:x|\\d+) life\\b"],
	"counter": ["counter spells", "counter target", "\\bcounter target (?:creature |noncreature )?spell\\b(?! (?:if|that)\\b)"],
	"steal": ["gain control of permanents", "control", "\\bgain control of|\\bexchange control"],
	"kill": ["destroy creatures", "destroy", _DESTROY + "\\bcreatures?\\b"],
	"artifact": ["destroy artifacts", "destroy", _DESTROY + "\\bartifacts?\\b"],
	"enchantment": ["destroy enchantments", "destroy", _DESTROY + "\\benchantments?\\b"],
	"land": ["destroy lands", "destroy", _DESTROY + "\\blands?\\b"],
	"exile": ["exile permanents", "exile", "\\bexile (?:target|all|each)"],
	"bounce": ["return permanents to their owner's hand", "hand",
		"\\breturn (?:target|all|each|up to)[^.]*? to (?:its|their) owners?'?s?'? hands?"],
	"discard": ["make a player discard", "discards", _WHO + " discards"],
	"edict": ["make a player sacrifice", "sacrifices", _WHO + " sacrifices"],
	"tap": ["tap permanents", "tap ", "\\btap (?:target|all|up to)"],
	"untap": ["untap permanents", "untap", "\\buntap (?:target|all|up to)"],
	"regenerate": ["regenerate", "regenerate", "\\bregenerate\\b"],
	"prevent": ["prevent damage", "prevent", "\\bprevent (?!all combat damage)"],
	"fog": ["prevent all combat damage", "combat damage", "prevent all combat damage"],
	"search": ["search a library", "search", "\\bsearch (?:your|target player's|its owner's) library"],
	"raise": ["return cards from a graveyard", "graveyard",
		"\\breturn[^.]*?\\bcards? from (?:your|a|target player's|their) graveyard"],
	"mana": ["make mana", "add {", "\\badd \\{"],
	"token": ["create creature tokens", "token", "\\bcreates? [^.]*?\\btokens?\\b"],
	"plus_counters": ["put +1/+1 counters on creatures", "+1/+1 counter", "\\+1/\\+1 counters?"],
	"mill": ["mill cards", "mill|librar", "\\bmills? |\\bputs? the top [^.]*? of [^.]*library into [^.]*graveyard"],
	"pump": ["make creatures bigger until end of turn", "until end of turn",
		"\\bgets? \\+(?:\\d+|x)/\\+(?:\\d+|x) until end of turn"],
	"extra_turn": ["take extra turns", "extra turn", "extra turn"],
}
## The effects a narrow answer (to fliers, to attackers or blockers) is not
## counted as.
const _PIE_NARROW := ["kill", "damage", "exile"]
## Keywords that are drawbacks are never a color hint.
const _PIE_SKIP_KEYWORDS := [Mtg.Keyword.DEFENDER, Mtg.Keyword.MUST_ATTACK]


## The card's color shelf: "W", "U", "B", "R" or "G" for one color, "C"
## for none, "M" for gold.
static func _color_key(data: CardData) -> String:
	var keys := _color_keys(data)
	if keys.is_empty():
		return "C"
	return keys[0] if keys.size() == 1 else "M"


## The card's colors, as shelf keys.
static func _color_keys(data: CardData) -> Array[String]:
	var mask := data.printed_colors if data.printed_colors >= 0 \
		else (data.cost.color_mask() if data.cost != null else 0)
	var out: Array[String] = []
	for bit in COLOR_KEYS:
		if mask & int(bit):
			out.append(String(COLOR_KEYS[bit]))
	return out


## A creature's size and keywords beside the creatures of its color and
## cost — only where the rows of all colors call them unusual, only where
## that shelf is full enough, and never past HIGH: a 4/4 for three is big
## for the game, and the green line says whether green goes that far. A
## */* creature (its size set as it plays) says nothing.
static func _color_size_rows(rows: Array[Dictionary], c: Dictionary, data: CardData, mv: int,
		drawbacks: int, gifts: int) -> void:
	if _is_star(data):
		return
	var key := _color_key(data)
	var group: Dictionary = (c["by_color"] as Dictionary)[key]
	var shelf := mini(mv + drawbacks, TOP_SHELF)
	var color := String(COLOR_WORDS[key])
	var said := ("%d-mana %s" % [shelf, color]) if drawbacks == 0 \
		else ("%d-mana %s (its drawbacks counted as mana)" % [shelf, color])
	var body := _body(data)
	var size := body.x + body.y
	var everyone: Dictionary = (c["size"] as Dictionary).get(shelf, {})
	var bucket: Dictionary = (group["size"] as Dictionary).get(shelf, {})
	if not everyone.is_empty() and _unusual(everyone["values"], size, SIZE_USUAL) \
			and not bucket.is_empty() and (bucket["values"] as Array).size() >= COLOR_SHELF_MIN:
		var most := _at(bucket["values"], COLOR_USUAL)
		var least := _at(bucket["values"], 1.0 - COLOR_USUAL)
		if size > int(bucket["max"]):
			rows.append({"yours": "%d/%d (%d)" % [body.x, body.y, size], "level": HIGH, "topic": "Size by color",
				"text": "The biggest %s creature of the game is %s (%s); yours is %d/%d." % [said,
					bucket["max_name"], bucket["max_shown"], body.x, body.y]})
		elif size > most:
			rows.append({"yours": "%d/%d (%d)" % [body.x, body.y, size], "level": HIGH, "topic": "Size by color",
				"text": "Almost all of the game's %s creatures have power + toughness %d or less; yours has %d." % [said, most, size]})
		elif size < least:
			rows.append({"yours": "%d/%d (%d)" % [body.x, body.y, size], "level": LOW, "topic": "Size by color",
				"text": "Almost all of the game's %s creatures have power + toughness %d or more; yours has %d." % [said, least, size]})
		else:
			rows.append({"yours": "%d/%d (%d)" % [body.x, body.y, size], "level": OK, "topic": "Size by color",
				"text": "%d/%d is in reach of the game's %s creatures (almost all are %d to %d in power + toughness)." % [
					body.x, body.y, said, least, most]})
		for side in [["power", body.x], ["toughness", body.y]]:
			var top: Dictionary = (group[side[0]] as Dictionary).get(shelf, {})
			if not top.is_empty() and int(side[1]) > int(top["max"]):
				rows.append({"yours": str(side[1]), "level": HIGH, "topic": "%s by color" % String(side[0]).capitalize(),
					"text": "No %s creature of the game has more than %d %s (%s); yours has %d." % [said,
						top["max"], side[0], top["max_name"], side[1]]})
	var kw_shelf := mini(mv, TOP_SHELF)
	var all_keywords: Dictionary = (c["keywords"] as Dictionary).get(kw_shelf, {})
	var keywords: Dictionary = (group["keyword_count"] as Dictionary).get(kw_shelf, {})
	var count := gifts
	if count > 0 and not all_keywords.is_empty() \
			and count > maxi(_at(all_keywords["values"], USUAL_KEYWORDS), KEYWORDS_FREE) \
			and not keywords.is_empty() and (keywords["values"] as Array).size() >= COLOR_SHELF_MIN:
		var most := _at(keywords["values"], COLOR_USUAL)
		var plural := func(n: int) -> String: return "keyword" if n == 1 else "keywords"
		if count > int(keywords["max"]):
			rows.append({"yours": str(count), "level": HIGH, "topic": "Keywords by color",
				"text": "No %d-mana %s creature of the game has more than %d %s (%s); yours has %d." % [
					kw_shelf, color, keywords["max"], plural.call(int(keywords["max"])), keywords["max_name"], count]})
		elif count > most:
			rows.append({"yours": str(count), "level": HIGH, "topic": "Keywords by color",
				"text": "Almost all of the game's %d-mana %s creatures have %d %s or fewer; yours has %d." % [
					kw_shelf, color, most, plural.call(most), count]})
		else:
			rows.append({"yours": str(count), "level": OK, "topic": "Keywords by color",
				"text": "%d %s is in reach of the game's %d-mana %s creatures (%s has %d)." % [count,
					plural.call(count), kw_shelf, color, keywords["max_name"], keywords["max"]]})


## Whether [param n] is past what [param share] of [param values] (sorted)
## keep to, either way.
static func _unusual(values: Array, n: int, share: float) -> bool:
	return _past_usual(values, n, share) or n < _at(values, 1.0 - SIZE_SMALL) \
		or (not values.is_empty() and n > int(values[-1]))


## THE COLOR HINTS: what the card does (and, for a creature, its keywords)
## that few cards of its color do, with the color the effect is at home
## in. A colorless card gets none.
static func _pie_rows(rows: Array[Dictionary], c: Dictionary, data: CardData, creature: bool,
		rules_text: String) -> void:
	var keywords: Array = []
	if creature:
		keywords = data.keywords
	_pie_rows_of(rows, c, _pie_colors(data), _pie_effects(rules_text), keywords)


## The colors a card's effects are set beside: its own, or each of a gold
## card's.
static func _pie_colors(data: CardData) -> Array[String]:
	var key := _color_key(data)
	if key == "M":
		return _color_keys(data)
	var colors: Array[String] = [key]
	return colors


static func _pie_rows_of(rows: Array[Dictionary], c: Dictionary, colors: Array[String],
		effects: Array[String], keywords: Array) -> void:
	# A colorless card has no color to be off: artifacts did everything in
	# 1993-99 (Nevinyrral's Disk, Rod of Ruin, Jayemdae Tome).
	if colors.size() == 1 and colors[0] == "C":
		return
	var homes: Dictionary = c["pie_home"]
	for id in effects:
		_pie_row(rows, c, homes.get(id, {}), colors, "effects", "cards", id,
			String((_PIE_EFFECTS[id] as Array)[0]))
	homes = c["pie_home_keywords"]
	for k in keywords:
		if k in _PIE_SKIP_KEYWORDS:
			continue
		var word := str(Mtg.Keyword.find_key(k)).to_lower().replace("_", " ")
		_pie_row(rows, c, homes.get(k, {}), colors, "keywords", "creatures", k, "have " + word)


static func _pie_row(rows: Array[Dictionary], c: Dictionary, home: Dictionary, colors: Array[String],
		field: String, noun: String, id: Variant, does: String) -> void:
	if home.is_empty() or int(home["count"]) < PIE_EVIDENCE_FEW or colors.has(String(home["color"])):
		return
	var thin := int(home["count"]) < PIE_EVIDENCE
	var by_color: Dictionary = c["by_color"]
	var share := -1.0
	var kindest := ""
	for col in colors:
		var group: Dictionary = by_color[col]
		if int(group[noun]) == 0:
			continue
		var mine := float((group[field] as Dictionary).get(id, 0)) / int(group[noun])
		if mine > share:
			share = mine
			kindest = col
	if share < 0.0:
		return
	var at_home := float(home["share"])
	var rare := ""
	if share * PIE_NONE <= at_home and share < PIE_NONE_SHARE:
		rare = "none"
	elif share * PIE_FEW <= at_home and share < PIE_FEW_SHARE and not thin:
		rare = "few"
	else:
		return
	var words: Array[String] = []
	for col in colors:
		words.append(String(COLOR_WORDS[col]))
	var who := " or ".join(words) if words.size() <= 2 \
		else ", ".join(words.slice(0, words.size() - 1)) + " or " + words[-1]
	var home_said := "%s of %s %s" % [_percent(at_home), COLOR_WORDS[home["color"]], noun]
	var text := ""
	if share == 0.0:
		text = "None of the game's %s %s %s (%s do)." % [who, noun, does, home_said]
	else:
		var of_them := "of them" if colors.size() == 1 else "of the %s ones" % COLOR_WORDS[kindest]
		text = "%s %s %s %s (%s %s; %s)." % ["Almost no" if rare == "none" else "Few", who, noun, does,
			_percent(share), of_them, home_said]
	if thin:
		text += " Only %d %s %s do in this pool — a small sample, so take it lightly." % [
			int(home["count"]), COLOR_WORDS[home["color"]], noun]
	# The verdict word is "Rare in color" and the "Yours" column stays empty
	# (the sentence says what); `rare` keeps how rare: "few" or "none".
	rows.append({"level": RARE, "topic": PIE_TOPIC, "text": text, "yours": "", "rare": rare})


## "13%", or "0.5%" under one in a hundred.
static func _percent(share: float) -> String:
	return ("%.1f%%" % (share * 100.0)) if share < 0.01 else ("%d%%" % roundi(share * 100.0))


## [constant _PIE_EFFECTS] made ready once: `[id, hints, pattern]` rows.
static var _pie_reading: Array = []


## The effects [param text] has, as keys of [constant _PIE_EFFECTS].
static func _pie_effects(text: String) -> Array[String]:
	if _pie_reading.is_empty():
		for id in _PIE_EFFECTS:
			var entry: Array = _PIE_EFFECTS[id]
			_pie_reading.append([String(id), String(entry[1]).split("|"), _rx(String(entry[2]))])
	var found: Array[String] = []
	var opening := _rx("^(?:when|whenever|at) [^,.]*, ")
	for line in text.to_lower().split("\n", false):
		for whole in line.split(". ", false):
			var sentence := opening.sub(whole, "")
			# Narrow answers are at home in more colors than the wide ones
			# (green downs fliers, white strikes attackers): not counted as
			# destroying, damaging or exiling, on either side.
			var narrow := sentence.contains("with flying") or sentence.contains("attacking") \
				or sentence.contains("blocking")
			for reading in _pie_reading:
				var id := String(reading[0])
				if found.has(id) or (narrow and id in _PIE_NARROW):
					continue
				var hinted := false
				for hint in (reading[1] as PackedStringArray):
					if sentence.contains(hint):
						hinted = true
						break
				if hinted and (reading[2] as RegEx).search(sentence) != null:
					found.append(id)
	return found


# ---------------------------------------------------- the game's cards --

## The numbers of the game's own cards (counted once per pool): `m` the
## measures by kind and shelf, `mana`, `burst` and `priced`, `thumb` how
## many cards are past each rule of thumb and which (of `all` cards, lands
## too). Its `color_flagged` counts the game's own nonland cards that
## would get a color line beside the rest (`pie` the color hints, `size`
## the by-color rows past usual, `any` either, of `cards`), so the color
## lines can be held to the few cards that really are off their color.
static func corpus() -> Dictionary:
	var size := CardRegistry.size() - CardRegistry.community_names().size()
	if size == _corpus_size and not _corpus.is_empty():
		return _corpus
	var skip := {}
	for n in CardRegistry.community_names():
		skip[n] = true
	var c := {"cards": 0, "all": 0, "costs": [], "costs_top_name": "", "free": 0, "size": {}, "keywords": {},
		"most_power": {"value": 0, "name": ""}, "most_toughness": {"value": 0, "name": ""},
		"m": {"spell": {}, "ability": {}, "once": {}, "price": {}, "static": {}},
		"mana": {}, "burst": {}, "priced": {}, "thumb": {},
		"lines": [], "lines_max_name": "", "clauses": [], "verbs": {}}
	# By color (lands left out): how many cards and creatures, how many of
	# them do each effect or have each keyword, and the creatures' sizes.
	var by_color := {}
	for key in COLOR_WORDS:
		by_color[key] = {"cards": 0, "creatures": 0, "effects": {}, "keywords": {},
			"size": {}, "power": {}, "toughness": {}, "keyword_count": {}}
	c["by_color"] = by_color
	# What each nonland card does, kept to count the color lines after.
	var read := {}
	var most_lines := -1
	var most_cost := -1
	var measures: Dictionary = c["m"]
	var thumb: Dictionary = c["thumb"]
	for card_name in CardRegistry.all_names():
		if skip.has(card_name):
			continue
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		var f := _facts(data)
		var land: bool = f["land"]
		var mv: int = f["mv"]
		var shelf := mini(mv, TOP_SHELF)
		var lines: PackedStringArray = f["lines"]
		var drawbacks: int = f["drawbacks"]
		var gifts: int = f["gifts"]
		# A creature sits on the shelf of its cost and its drawbacks, as a
		# community card is set there.
		var size_shelf := mini(mv + drawbacks, TOP_SHELF)
		var things := 0
		c["all"] = int(c["all"]) + 1
		if not land:
			c["cards"] = int(c["cards"]) + 1
			(c["costs"] as Array).append(mv)
			if mv == 0 and not bool(f["x"]):
				c["free"] = int(c["free"]) + 1
			(c["lines"] as Array).append(lines.size())
			if lines.size() > most_lines:
				most_lines = lines.size()
				c["lines_max_name"] = card_name
			if mv > most_cost:
				most_cost = mv
				c["costs_top_name"] = card_name
			read[card_name] = [_count_color(by_color[_color_key(data)], data, f, shelf, size_shelf, card_name),
				drawbacks, gifts]
		if bool(f["creature"]):
			_add(c["keywords"], shelf, gifts, card_name)
			if not bool(f["star"]):
				var body: Vector2i = f["body"]
				_add(c["size"], size_shelf, body.x + body.y, card_name, "%d/%d" % [body.x, body.y])
				for side in [["power", body.x], ["toughness", body.y]]:
					var most: Dictionary = c["most_" + String(side[0])]
					if int(side[1]) > int(most["value"]):
						most["value"] = int(side[1])
						most["name"] = card_name
		var spell_read: Dictionary = {} if bool(f["ante"]) else f["spell_read"]
		for id: String in spell_read:
			if id == "burst":
				_add(c["burst"], "all", int(spell_read[id]), card_name)
			else:
				_add(_sub(measures["spell"], id), shelf, int(spell_read[id]), card_name)
		for piece: Dictionary in ([] if bool(f["ante"]) else f["pieces"]):
			var piece_read: Dictionary = piece["read"]
			var kind := String(piece["kind"])
			match kind:
				"mana":
					var m: Dictionary = piece["mana"]
					if int(m["made"]) <= 0:
						pass
					elif bool(m["once"]):
						_add(c["burst"], "all", int(m["net"]) - (0 if land else mv), card_name)
					else:
						_add(c["mana"], "land" if land else str(shelf), int(m["net"]) - (drawbacks if land else 0), card_name)
				"ability", "once":
					var price := int(piece["price"])
					for id: String in piece_read:
						_add(_sub(measures[kind], id), mini(mv + price, TOP_SHELF), int(piece_read[id]), card_name)
						if id in _BY_PRICE:
							_add(_sub(measures["price"], id), mini(price, TOP_SHELF), int(piece_read[id]), card_name)
				"trigger":
					# Where a community card's trigger is set ([method _text_rows]),
					# the game's own triggers stand too.
					for id: String in piece_read:
						if not bool(piece["repeats"]):
							_add(_sub(measures["spell"], id), shelf, int(piece_read[id]), card_name)
						elif id in _BY_PRICE:
							_add(_sub(measures["price"], id), 1, int(piece_read[id]), card_name)
						else:
							_add(_sub(measures["ability"], id), shelf, int(piece_read[id]), card_name)
				"static":
					for id: String in piece_read:
						_add(_sub(measures["static"], id), shelf, int(piece_read[id]), card_name)
		var priced: Dictionary = f["priced"]
		for id: String in priced:
			_add(_sub(c["priced"], id), "all", -int(priced[id]), card_name)
		for check: Array in ([] if bool(f["ante"]) else _thumb_checks(f)):
			if not thumb.has(check[0]):
				thumb[check[0]] = {"past": 0, "names": []}
			var stat: Dictionary = thumb[check[0]]
			stat["past"] = int(stat["past"]) + 1
			if (stat["names"] as Array).size() < 4:
				(stat["names"] as Array).append(card_name)
		for line in lines:
			var clauses := _clauses(line)
			things += clauses
			(c["clauses"] as Array).append(clauses)
		_add(c["verbs"], "land" if land else shelf, things, card_name)
	(c["costs"] as Array).sort()
	var lines_all: Array = c["lines"]
	lines_all.sort()
	c["lines_max"] = int(lines_all[-1]) if not lines_all.is_empty() else 0
	c["lines_rare"] = _at(lines_all, 0.99)
	var clauses_all: Array = c["clauses"]
	clauses_all.sort()
	c["clauses_max"] = int(clauses_all[-1]) if not clauses_all.is_empty() else 0
	c.erase("clauses")
	c["pie_home"] = _pie_homes(by_color, "effects", "cards")
	c["pie_home_keywords"] = _pie_homes(by_color, "keywords", "creatures")
	_sort_all(c)
	c["color_flagged"] = _color_flagged(c, read)
	_corpus = c
	_corpus_size = size
	return c


static func _sub(table: Dictionary, key: Variant) -> Dictionary:
	if not table.has(key):
		table[key] = {}
	return table[key]


## One nonland card of the game counted on its color's shelf; returns the
## effects read from it.
static func _count_color(group: Dictionary, data: CardData, f: Dictionary, shelf: int, size_shelf: int,
		card_name: String) -> Array[String]:
	group["cards"] = int(group["cards"]) + 1
	var effects: Dictionary = group["effects"]
	var found := _pie_effects(String(f["text"]))
	for id in found:
		effects[id] = int(effects.get(id, 0)) + 1
	if not bool(f["creature"]):
		return found
	group["creatures"] = int(group["creatures"]) + 1
	var keywords: Dictionary = group["keywords"]
	var seen := {}
	for k in data.keywords:
		if not seen.has(k):
			seen[k] = true
			keywords[k] = int(keywords.get(k, 0)) + 1
	_add(group["keyword_count"], shelf, int(f["gifts"]), card_name)
	if bool(f["star"]):
		return found
	var body: Vector2i = f["body"]
	_add(group["size"], size_shelf, body.x + body.y, card_name, "%d/%d" % [body.x, body.y])
	_add(group["power"], size_shelf, body.x, card_name)
	_add(group["toughness"], size_shelf, body.y, card_name)
	return found


## How many of the game's own nonland cards get a color line past usual
## (see [method corpus]), each read as a community card of its cost and
## drawbacks would be.
static func _color_flagged(c: Dictionary, read: Dictionary) -> Dictionary:
	var out := {"pie": 0, "size": 0, "any": 0, "cards": read.size()}
	for card_name in read:
		var data := CardRegistry.get_card(card_name)
		var creature := data.is_type(Mtg.CardType.CREATURE)
		var rows: Array[Dictionary] = []
		var keywords: Array = []
		if creature:
			keywords = data.keywords
		var known: Array = read[card_name]
		_pie_rows_of(rows, c, _pie_colors(data), known[0], keywords)
		var pie := not rows.is_empty()
		var size := false
		if creature:
			rows.clear()
			_color_size_rows(rows, c, data, data.cost.mana_value() if data.cost != null else 0, int(known[1]), int(known[2]))
			size = rows.any(func(row: Dictionary) -> bool: return row["level"] != OK)
		out["pie"] = int(out["pie"]) + int(pie)
		out["size"] = int(out["size"]) + int(size)
		out["any"] = int(out["any"]) + int(pie or size)
	return out


## Each effect's (or keyword's) home: the one color whose cards have it
## most often, `{color, share, count}`.
static func _pie_homes(by_color: Dictionary, field: String, noun: String) -> Dictionary:
	var homes := {}
	for key in COLOR_KEYS.values():
		var group: Dictionary = by_color[key]
		var n := int(group[noun])
		if n == 0:
			continue
		var counts: Dictionary = group[field]
		for id in counts:
			var share := float(counts[id]) / n
			if not homes.has(id) or share > float(homes[id]["share"]):
				homes[id] = {"color": key, "share": share, "count": int(counts[id])}
	return homes


static func _add(table: Dictionary, key: Variant, value: int, card_name: String, shown := "") -> void:
	if not table.has(key):
		table[key] = {"values": [], "max": value, "max_name": card_name, "max_shown": shown}
	var bucket: Dictionary = table[key]
	(bucket["values"] as Array).append(value)
	if value > int(bucket["max"]):
		bucket["max"] = value
		bucket["max_name"] = card_name
		bucket["max_shown"] = shown


static func _sort_all(node: Variant) -> void:
	if node is Dictionary:
		if (node as Dictionary).has("values"):
			(node["values"] as Array).sort()
			return
		for key in node:
			_sort_all(node[key])


## The value [param share] of the way up [param values] (sorted).
static func _at(values: Array, share: float) -> int:
	if values.is_empty():
		return 0
	return int(values[clampi(int(floor(share * (values.size() - 1))), 0, values.size() - 1)])


# ------------------------------------------------- reading rules text --

## THE RULES TEXT AS THIS CHECK READS IT, both sides alike: the card's own
## name read as CARDNAME (a "Search Party Exile" neither searches nor
## exiles) — BY WHOLE WORDS ONLY, never inside a word or a mana symbol (a
## card named "T" leaves "{T}" be); and reminder text in parentheses left
## out (Brand's cycling reminder draws no card; a dual land's "({T}: Add
## {W} or {U}.)" is its land type, not an ability). A one-word name that
## is itself one of the verbs read ("Exile") is kept: its text says what
## it does. (A community card is built under the name CARDNAME to begin
## with, see [method advice].)
static func _rules_of(data: CardData) -> String:
	var text := data.oracle_text
	var name := data.card_name.strip_edges()
	if name != "" and name != "CARDNAME" and text.contains(name) \
			and _rx("(?i)^" + _VERBS + "$").search(name) == null:
		var escaped := ""
		for ch in name:
			escaped += ("\\" + ch) if ch in ".^$*+?()[]{}|\\/-" else ch
		var whole := RegEx.create_from_string("(?<![\\w{+/-])" + escaped + "(?![\\w}/])")
		if whole != null and whole.is_valid():
			text = whole.sub(text, "CARDNAME", true)
	return _clean(text)


## [param text] without reminder text and empty lines.
static func _clean(text: String) -> String:
	text = _rx("[ \\t]*\\([^)]*\\)").sub(text, "", true)
	var lines := PackedStringArray()
	for line in text.split("\n", false):
		var kept := line.strip_edges()
		if kept != "":
			lines.append(kept)
	return "\n".join(lines)


## EVERYTHING THE CHECK KNOWS OF ONE CARD, read once: its text and lines,
## cost, kinds, body, drawbacks (a land's own for a land), keyword pile,
## pieces ([method _pieces]), a spell's measures (`spell_read`: the
## biggest of its lines, so of a "Choose one —" spell its biggest mode;
## `burst` the mana a ritual gives beyond its cost) and its cycling or
## buyback cost (`priced`). The game's cards and a community card alike.
static func _facts(data: CardData) -> Dictionary:
	var text := _rules_of(data)
	var lines := text.split("\n", false)
	var mv := data.cost.mana_value() if data.cost != null else 0
	var land := data.is_land()
	var spell := data.is_type(Mtg.CardType.INSTANT) or data.is_type(Mtg.CardType.SORCERY)
	var f := {"text": text, "lines": lines, "mv": mv, "land": land, "spell": spell,
		"creature": data.is_type(Mtg.CardType.CREATURE), "x": data.cost != null and data.cost.has_x,
		"body": _body(data), "star": _is_star(data, text), "pieces": _pieces(lines, spell),
		"drawbacks": _land_drawbacks(text) if land else _drawbacks_in(data, text),
		"gifts": _gift_keywords(data) + _text_gifts(lines)}
	var spell_read := {}
	var priced := {}
	for piece: Dictionary in f["pieces"]:
		if String(piece["kind"]) != "spell":
			continue
		var read: Dictionary = piece["read"]
		for id: String in read:
			spell_read[id] = maxi(int(spell_read.get(id, 0)), int(read[id]))
		var line := String(piece["line"])
		if _rx("(?i)\\badd (?:\\{|one mana|two mana|three mana|four mana|five mana)").search(line) != null:
			var made := _mana_made(line.substr(line.to_lower().find("add ")))
			if made > 0:
				spell_read["burst"] = maxi(int(spell_read.get("burst", -99)), made - mv)
	for line in lines:
		var hit := _rx("^(Cycling|Buyback) ((?:\\{[^}]+\\})+)").search(line)
		if hit != null:
			priced[hit.get_string(1).to_lower()] = _symbols_value(hit.get_string(2))
	var once_read: Dictionary = spell_read.duplicate()
	for piece: Dictionary in f["pieces"]:
		if String(piece["kind"]) == "trigger" and not bool(piece["repeats"]):
			var read: Dictionary = piece["read"]
			for id: String in read:
				once_read[id] = maxi(int(once_read.get(id, 0)), int(read[id]))
	f["spell_read"] = spell_read
	f["once_read"] = once_read
	f["priced"] = priced
	# An ante card pays with a card for keeps: no measure of what the game
	# gives for a cost.
	f["ante"] = text.contains("playing for ante")
	return f


## The mana in a run of symbols: "{2}{B}{B}" is 4 ({T}, {Q} and {X} none).
static func _symbols_value(text: String) -> int:
	var n := 0
	for hit in _rx("\\{([^}]+)\\}").search_all(text):
		var s := hit.get_string(1).to_upper()
		if s.is_valid_int():
			n += int(s)
		elif not s in ["T", "Q", "X"]:
			n += 1
	return n


## THE PIECES OF A CARD'S RULES TEXT, a line each: `kind` "ability" (an
## activated ability that stays), "once" (one that sacrifices or exiles
## its card), "mana" (one that adds mana — `mana`: [method _mana_of]),
## "trigger" (`repeats`: "Whenever …" and "At …" happen again and again,
## "When …" once), "spell" (a line of an instant or a sorcery, a mode
## too) or "static" (any other line of a permanent); `read` what the
## piece's effect is measured as ([method _read]), `price` an ability's.
static func _pieces(lines: PackedStringArray, spell: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in lines:
		var line := raw.trim_prefix("• ").strip_edges()
		var ability := _ability(line)
		if not ability.is_empty():
			var effect := String(ability["effect"])
			var left := String(ability["price_text"])
			var once := _rx("(?i)\\b(?:sacrifice|exile) (?:cardname|this \\w+)").search(left) != null
			if effect.begins_with("Add "):
				out.append({"kind": "mana", "line": line, "read": {}, "mana": _mana_of(left, effect, once)})
			else:
				out.append({"kind": "once" if once else "ability", "line": line, "price": int(ability["price"]),
					"read": _read(effect)})
			continue
		var opening := _rx("^(?:When|Whenever|At) [^,]*, ").search(line)
		if opening != null:
			var effect := line.substr(opening.get_end())
			var repeats := not line.begins_with("When ")
			if effect.to_lower().begins_with("add ") or effect.to_lower().begins_with("you may add "):
				var made := _mana_made(effect)
				out.append({"kind": "mana", "line": line, "read": {},
					"mana": {"made": made, "net": made, "once": not repeats}})
			else:
				out.append({"kind": "trigger", "line": line, "repeats": repeats, "read": _read(effect)})
			continue
		if spell:
			out.append({"kind": "spell", "line": line, "read": _read(line)})
		else:
			var read := _read(line)
			read.merge(_read_static(line), true)
			out.append({"kind": "static", "line": line, "read": read})
	return out


## A creature's power and toughness as it enters: as printed, with the
## counters it enters with ("+1/+1", "+1/+0" and the like — a 0/0 Spike
## with two +1/+1 counters is a 2/2).
static func _body(data: CardData) -> Vector2i:
	var body := Vector2i(data.power, data.toughness)
	for kind in data.enters_with_counters:
		var hit := _rx("^([+-]\\d+)/([+-]\\d+)$").search(String(kind))
		if hit != null:
			var n := int(data.enters_with_counters[kind])
			body += Vector2i(int(hit.get_string(1)), int(hit.get_string(2))) * n
	return body


## A */* creature — its size is set as it plays (no toughness as it enters,
## or "its power … equal to …"): left out of the size tables.
static func _is_star(data: CardData, rules_text := "") -> bool:
	if _body(data).y <= 0:
		return true
	var text := rules_text if rules_text != "" else _rules_of(data)
	return _rx("(?i)\\b(?:power|toughness)(?: and toughness)? (?:is|are|are each) equal to").search(text) != null


## An activated ability's line split: `{price, price_text, effect}` ({} for
## any other line). The price counts each mana, {T}, each sacrifice,
## discard and counter removed (one each) and every 2 life as one.
static func _ability(line: String) -> Dictionary:
	if line.begins_with("When") or line.begins_with("At ") or line.begins_with("Enchant"):
		return {}
	var colon := line.find(": ")
	if colon <= 0:
		return {}
	var left := line.left(colon)
	var costs := false
	for start in ["Sacrifice", "Pay ", "Discard", "Remove"]:
		if left.begins_with(start):
			costs = true
	if not (costs or left.contains("{")):
		return {}
	var price := 0
	var symbols := _rx("\\{([^}]+)\\}")
	for hit in symbols.search_all(left):
		var s := hit.get_string(1)
		if s.is_valid_int():
			price += int(s)
		elif s != "X" and s != "Q":
			price += 1
	for part in left.split(", ", false):
		if part.begins_with("Sacrifice") or part.begins_with("Discard") \
				or (part.begins_with("Remove") and part.contains("counter")):
			price += 1
	var life := _rx("Pay (\\d+) life").search(left)
	if life != null:
		price += maxi(1, int(life.get_string(1)) / 2)
	return {"price": maxi(price, 1), "price_text": left.strip_edges(), "effect": line.substr(colon + 2)}


## A mana ability weighed: `made` what it adds (0: an amount that changes
## as it plays), `net` that less what the ability costs — each mana, and
## one for each sacrifice (of something else), discard, counter removed or
## life payment — and `once` whether the card is given up for it.
static func _mana_of(left: String, effect: String, once: bool) -> Dictionary:
	var made := _mana_made(effect)
	var paid := _symbols_value(left)
	for part in left.split(", ", false):
		if part.begins_with("Sacrifice"):
			if _rx("(?i)^sacrifice (?:cardname|this \\w+)").search(part) == null:
				paid += 1
		elif part.begins_with("Discard") or (part.begins_with("Remove") and part.contains("counter")) \
				or (part.begins_with("Pay ") and part.contains("life")):
			paid += 1
	return {"made": made, "net": made - paid, "once": once}


const _N := "(an?|one|two|three|four|five|six|seven|eight|nine|ten|\\d+)"
## THE PLAIN READINGS: `[measure, the words a text must hold before the
## pattern is tried ("|" between choices), the pattern (on lowered text),
## "n" (its first group is a number; every match adds up) or "one" (there
## or not)]`. Damage a card deals to its own controller is no damage here
## — it is a drawback.
const _READS := [
	["damage", "damage", "\\bdeals? (\\d+) damage (?:to (?!you\\b)|divided)", "n"],
	["draw", "draw", "\\bdraws? " + _N + " (?:additional )?cards?", "n"],
	["life", "life", "\\bgains? (\\d+) life", "n"],
	["lose_life", "lose", "(?<!you )\\bloses? (\\d+) life", "n"],
	["discard", "discard", "(?:players?|opponents?|controller) (?:reveals their hand and )?discards? " + _N + " cards?", "n"],
	["counters", "+1/+1 counter", "\\bputs? " + _N + " \\+1/\\+1 counters? on", "n"],
	["minus_counters", "-1/-1 counter", "\\bputs? " + _N + " -1/-1 counters? on", "n"],
	["prevent", "prevent the next", "prevent the next (\\d+) damage", "n"],
	["cost_less", "less to cast", "costs? \\{(\\d+)\\} less to cast", "n"],
	["cost_more", "more to cast", "costs? \\{(\\d+)\\} more to cast", "n"],
	["attack_tax", "can't attack", "can't attack (?:you )?unless [^.]*?pays? \\{(\\d+)\\}", "n"],
	["sweep_creatures", "destroy all", "\\bdestroy all (?:artifacts, )?(?:[a-z-]+ ){0,2}creatures\\b(?! (?:block|that|enchanted|of the))", "one"],
	["sweep_lands", "destroy all", "\\bdestroy all (?:[a-z-]+ ){0,2}(?:lands|plains|islands|swamps|mountains|forests)\\b", "one"],
	["sweep_other", "destroy all", "\\bdestroy all (?:[a-z-]+ ){0,2}(?:artifacts|enchantments|permanents)\\b", "one"],
	["kill", "destroy t", "\\bdestroy (?:that creature|target [^.]*?\\b(?:creature|permanent)\\b)", "one"],
	["kill_land", "destroy target", "\\bdestroy target [^.]*?\\bland\\b", "one"],
	["kill_other", "destroy target", "\\bdestroy target [^.]*?\\b(?:artifact|enchantment)\\b(?! creature)", "one"],
	["exile", "exile t", "\\bexile (?:that creature|target [^.]*?\\b(?:creature|permanent)\\b)", "one"],
	["bounce", "hand", "\\breturn (?:target|all|each|up to|that)[^.]*? to (?:its|their) owners?'?s?'? hands?", "one"],
	["reanimate", "graveyard", "\\b(?:return|put) [^.]*?\\bcards? from (?:your|a|any) graveyard (?:to|onto) the battlefield", "one"],
	["counter", "counter target", "\\bcounter target [^.]*?\\bspell\\b", "one"],
	["counter_ability", "counter target", "\\bcounter target [^.]*?\\bability\\b", "one"],
	["steal", "control", "\\bgain control of target|\\byou control enchanted", "one"],
	["edict", "sacrifice", "(?:target player|target opponent|each opponent|each player|that player) sacrifices? an? creature", "one"],
	["tap", "tap t", "\\btap (?:target|that creature)", "one"],
	["untap", "untap t", "\\buntap (?:target|that creature)", "one"],
	["regenerate", "regenerate", "\\bregenerate (?:target|this|cardname|it\\b|enchanted)", "one"],
	["fog", "combat damage", "prevent all combat damage", "one"],
	["extra_turn", "extra turn", "\\btakes? an extra turn", "one"],
	["shield", "source of your choice", "source of your choice would deal damage", "one"],
	["set_pt", "base power", "base power and toughness \\d+/\\d+", "one"],
	["switch_pt", "switch", "\\bswitch [^.]*?power and toughness", "one"],
	["give_landwalk", "walk", "\\bgains? \\w*walk\\b", "one"],
	["strip", "loses", "\\bloses? (?!\\d)[a-z' ]+? until end of turn", "one"],
	["reshuffle", "library", "\\bshuffles? (?:their|your) [a-z ]*?into (?:their|your) library", "one"],
	["pacify", "can't attack", "enchanted creature can't attack or block", "one"],
	["freeze", "doesn't untap", "enchanted \\w+ doesn't untap during its controller's untap step", "one"],
	["ward", "protection", "enchanted creature has protection from", "one"],
]
const _KEYWORD_WORDS := "\\b(?:flying|first strike|trample|haste|vigilance|reach|fear|unblockable|banding|flanking|shadow|protection from \\w+|\\w+walk)\\b"
## [constant _READS] made ready once.
static var _reading: Array = []


## WHAT ONE EFFECT'S TEXT IS MEASURED AS: measure to number (1 for an
## effect that is there or not). Amounts of X are not read. Beside the
## plain readings: cards milled; a search (a land, or how many cards);
## cards returned from a graveyard; tokens (their power + toughness in
## all); +P/+T until end of turn, for one creature or many, a keyword
## counted as 1 — what is added ("pump") and what is taken ("shrink")
## apart; a permanent that becomes a creature (its size).
static func _read(text: String) -> Dictionary:
	var out := {}
	var lower := text.to_lower()
	if _reading.is_empty():
		for entry: Array in _READS:
			_reading.append([entry[0], String(entry[1]).split("|"), _rx(String(entry[2])), entry[3]])
	for entry: Array in _reading:
		var hinted := false
		for hint in (entry[1] as PackedStringArray):
			if lower.contains(hint):
				hinted = true
				break
		if not hinted:
			continue
		var rx: RegEx = entry[2]
		if String(entry[3]) == "one":
			if rx.search(lower) != null:
				out[entry[0]] = 1
		else:
			var n := 0
			for hit in rx.search_all(lower):
				n += _word_number(hit.get_string(1))
			if n > 0:
				out[entry[0]] = n
	if lower.contains("library into") or lower.contains("mills "):
		var n := 0
		for hit in _rx("\\bmills " + _N + " cards?|\\bputs? the top (?:" + _N + " )?cards? of [a-z' ]*?library into [a-z' ]*?graveyard").search_all(lower):
			var word := hit.get_string(1) if hit.get_string(1) != "" else hit.get_string(2)
			n += _word_number(word) if word != "" else 1
		if n > 0:
			out["mill"] = n
	if lower.contains("search your library"):
		var hit := _rx("search your library for ([^,.]*)").search(lower)
		if hit != null:
			var what := hit.get_string(1)
			if _rx("\\b(?:land|plains|island|swamp|mountain|forest)\\b").search(what) != null:
				out["land_search"] = 1
			elif _rx("\\bx\\b").search(what) == null:
				out["tutor"] = _count_in(what)
	if lower.contains("from your graveyard to your hand") or lower.contains("from your graveyard on top of your library"):
		var hit := _rx("\\b(?:return|put) ([^.]*?)cards? from your graveyard (?:to your hand|on top of your library)").search(lower)
		if hit != null and _rx("\\bx\\b").search(hit.get_string(1)) == null:
			out["regrowth"] = _count_in(hit.get_string(1))
	if lower.contains("token"):
		var n := 0
		for hit in _rx("\\bcreates? (?:" + _N + " )?(\\d+)/(\\d+) [^.]*?tokens?").search_all(lower):
			var count := _word_number(hit.get_string(1)) if hit.get_string(1) != "" else 1
			n += count * (int(hit.get_string(2)) + int(hit.get_string(3)))
		if n > 0:
			out["tokens"] = n
	if lower.contains("until end of turn"):
		for sentence in lower.split(". ", false):
			var hit := _rx("^(.*?)\\b(?:gets?|has|have|gains?) (.*?)until end of turn").search(sentence)
			if hit == null or hit.get_string(2).contains("base power"):
				continue
			var bonus := _bonus_of(hit.get_string(2))
			var many := hit.get_string(1).contains("creatures")
			if bonus.x > 0:
				var id := "mass_pump" if many else "pump"
				out[id] = int(out.get(id, 0)) + bonus.x
			if bonus.y > 0:
				var id := "mass_shrink" if many else "shrink"
				out[id] = int(out.get(id, 0)) + bonus.y
	if lower.contains("becomes a"):
		var hit := _rx("\\bbecomes an? (\\d+)/(\\d+) [^.]*?creature").search(lower)
		if hit != null:
			out["animate"] = int(hit.get_string(1)) + int(hit.get_string(2))
	return out


## WHAT A STATIC LINE IS MEASURED AS: an anthem (what it adds to one's own
## creatures, or to all), a weakening (what it takes from the opponents',
## or from all), an Aura's gift and an Aura's curse — power + toughness in
## all, a keyword counted as 1. What a line takes from one's own creatures
## or gives to the opponents' is a drawback and is not read.
static func _read_static(line: String) -> Dictionary:
	var out := {}
	var lower := line.to_lower()
	if lower.contains("until end of turn") or lower.contains("equipped"):
		return out
	if lower.contains("enchanted creature"):
		for hit in _rx("enchanted creature (?:gets?|has) ([^.]*)").search_all(lower):
			var bonus := _bonus_of(hit.get_string(1))
			if bonus.x > 0:
				out["aura"] = int(out.get("aura", 0)) + bonus.x
			if bonus.y > 0:
				out["aura_minus"] = int(out.get("aura_minus", 0)) + bonus.y
		return out
	if not (lower.contains(" get ") or lower.contains(" have ")):
		return out
	var hit := _rx("\\b\\w+s\\b([^.:\"]{0,40}?) (get [+-]\\d+/[+-]\\d+[^.]*|have [^.\"]*)").search(lower)
	if hit != null:
		var who := hit.get_string(1)
		var bonus := _bonus_of(hit.get_string(2))
		if bonus.x > 0 and not who.contains("opponent"):
			out["anthem"] = bonus.x
		if bonus.y > 0 and not who.contains("you control"):
			out["weaken"] = bonus.y
	return out


## Whether a static line only helps the opponents' creatures or only
## hurts one's own — a drawback, not read as an anthem.
static func _static_drawback(line: String) -> bool:
	var hit := _rx("\\b\\w+s\\b([^.:\"]{0,40}?) (get [+-]\\d+/[+-]\\d+[^.]*|have [^.\"]*)").search(line.to_lower())
	if hit == null:
		return false
	var bonus := _bonus_of(hit.get_string(2))
	var who := hit.get_string(1)
	return (who.contains("opponent") and bonus.x > 0 and bonus.y == 0) \
		or (who.contains("you control") and bonus.y > 0 and bonus.x == 0)


## What "+2/-1 and has flying" adds (x) and takes (y): power + toughness,
## each keyword given counted as 1.
static func _bonus_of(segment: String) -> Vector2i:
	var plus := 0
	var minus := 0
	var hit := _rx("([+-])(\\d+)/([+-])(\\d+)").search(segment)
	if hit != null:
		var p := int(hit.get_string(2)) * (1 if hit.get_string(1) == "+" else -1)
		var t := int(hit.get_string(4)) * (1 if hit.get_string(3) == "+" else -1)
		plus = maxi(p, 0) + maxi(t, 0)
		minus = maxi(-p, 0) + maxi(-t, 0)
	plus += _rx(_KEYWORD_WORDS).search_all(segment).size()
	return Vector2i(plus, minus)


## The number in "up to three creature cards" (1 with none).
static func _count_in(what: String) -> int:
	var hit := _rx("\\b(two|three|four|five|six|seven|eight|nine|ten|\\d+)\\b").search(what)
	return _word_number(hit.get_string(1)) if hit != null else 1


static func _word_number(word: String) -> int:
	return int(word) if word.is_valid_int() else int(_WORD_NUMBERS.get(word, 1))


## The mana one "Add …" makes (0 when the amount changes as it plays:
## "for each …", "equal to …", X).
static func _mana_made(effect: String) -> int:
	var lower := effect.to_lower()
	if lower.contains("for each") or lower.contains("equal to") or lower.contains("{x}") \
			or lower.contains("x mana") or lower.contains("that much"):
		return 0
	# "Add {W} or {U}" makes one of them; what comes after the sentence
	# (a pain land's damage) is no mana.
	effect = effect.get_slice(". ", 0).get_slice(" or ", 0)
	var n := 0
	for hit in _rx("\\{([WUBRGC]|\\d+)\\}").search_all(effect):
		var s := hit.get_string(1)
		n += int(s) if s.is_valid_int() else 1
	if n == 0:
		var words := _rx("(one|two|three|four|five|six|seven) mana").search(effect.to_lower())
		n = _word_number(words.get_string(1)) if words != null else 1
	return n


## The keywords a creature is helped by: defender, "attacks each combat"
## and phasing are drawbacks, never a gift — on the card's side and the
## game's alike.
static func _gift_keywords(data: CardData) -> int:
	var n := 0
	for k in data.keywords:
		if not k in [Mtg.Keyword.DEFENDER, Mtg.Keyword.MUST_ATTACK, Mtg.Keyword.PHASING]:
			n += 1
	return n


## THE REST OF THE KEYWORD PILE, read from the text (they are no keywords
## of the engine's list): each protection, each landwalk and rampage on a
## keyword line, and "can't be blocked by Walls", "can block an additional
## creature", "can't be countered" — one each.
static func _text_gifts(lines: PackedStringArray) -> int:
	var n := 0
	for line in lines:
		var lower := line.to_lower()
		if line.ends_with(".") or line.contains(":"):
			if lower.contains("can't be blocked by walls") or lower.contains("can't be countered") \
					or lower.contains("can't be the target of spells") \
					or (lower.contains("can block ") and lower.contains("additional")):
				n += 1
			continue
		if lower.contains("protection"):
			n += _rx("\\bfrom \\w+").search_all(lower).size()
		if lower.contains("walk"):
			n += _rx("\\b\\w+walk\\b").search_all(lower).size()
		if lower.contains("rampage"):
			n += 1
		if lower.contains("shroud"):
			n += 1
	return n


## How many things [param line] does (its verbs).
static func _clauses(line: String) -> int:
	return _rx("(?i)" + _VERBS).search_all(line).size()
