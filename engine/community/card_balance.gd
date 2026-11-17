class_name CardBalance
extends RefCounted
## A CRUDE BALANCE CHECK for a community card — suggestions only, it never
## refuses a card. The card is set beside the game's own cards (every card
## of the pool but the community ones) by mana value: a creature's size,
## power, toughness and keywords; the damage, cards and life a spell or an
## ability gives for its price; the mana a permanent taps for; an anthem's
## or an Aura's bonus; how much the card does; what it costs.
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
const LEVEL_WORDS := {OK: "Usual", LOW: "Low", HIGH: "High", VERY_HIGH: "Very high"}
## Mana values (and prices) from this one up share one shelf.
const TOP_SHELF := 8
## The share of the game's cards a "usual" value stays within; keywords
## and the length of the rules text are left more room (most cards have
## few of either, so 9 in 10 would call a Serra Angel strong).
const USUAL := 0.9
const USUAL_KEYWORDS := 0.97

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
## `{level, topic, text}`, the summary first (`topic` "Summary").
static func advice(spec: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var c := corpus()
	var data := CommunityCard.build(spec)
	var mv := data.cost.mana_value() if data.cost != null else 0
	var types := CommunityCard._list(spec.get("types"))
	var land := types.has("land")
	var rules: Dictionary = spec.get("rules") if spec.get("rules") is Dictionary else {}
	_thumb_rows(rows, data, mv, spec, types, rules)
	if not land:
		_cost_rows(rows, c, mv, spec)
	if types.has("creature"):
		_creature_rows(rows, c, data, mv, spec, rules)
		if not land:
			_color_size_rows(rows, c, data, mv, spec, rules)
	_text_rows(rows, c, data, mv, types, land)
	if not land:
		_pie_rows(rows, c, data, types.has("creature"))
	# The color hints stay out of the summary's level: an effect rare in the
	# card's color is not a weak or a strong card. They get a sentence of
	# their own.
	var worst := OK
	var pie := false
	for row in rows:
		var level := String(row["level"])
		if String(row["topic"]) == PIE_TOPIC:
			pie = true
		elif _rank(level) > _rank(worst):
			worst = level
	var summary := "Fits the game's cards."
	match worst:
		VERY_HIGH: summary = "Probably too strong (or too odd) beside the game's cards — see the red lines."
		HIGH: summary = "Strong in places beside the game's cards — see the orange lines."
		LOW: summary = "Weak in places beside the game's cards."
	if pie:
		summary += " Some of what it does is rare in its color (the \"Color\" lines)."
	rows.push_front({"level": worst, "topic": "Summary", "text": "%s Compared with %d of the game's cards; only a suggestion — the card saves either way." % [summary, int(c["cards"])]})
	return rows


# ------------------------------------------------------ rules of thumb --

## THE RULES OF THUMB, from a study of the whole pool (all ten packs, 3,684
## cards, 2026-11-17): simple lines that few of the game's cards cross —
## and those that do pay with a heavy drawback. A card past one is told so,
## with the game's cards that are past it too. For a creature, each
## drawback (echo, cumulative upkeep, an upkeep cost, can't block,
## defender, an extra life cost) counts as one more mana, and the +1/+1
## counters it enters with count in its size.
const THUMB_TOPIC := "Rule of thumb"


static func _thumb_rows(rows: Array[Dictionary], data: CardData, mv: int, spec: Dictionary,
		types: Array[String], rules: Dictionary) -> void:
	var say := func(level: String, text: String) -> void:
		rows.append({"level": level, "topic": THUMB_TOPIC, "text": text})
	var rules_text := _rules_of(data)
	if data.cost != null and data.cost.has_x:
		pass
	elif types.has("creature"):
		var e := mv + _drawbacks(spec, rules)
		var body := _body(data)
		var size := body.x + body.y
		if size > 2 * e + 4:
			say.call(VERY_HIGH, "power + toughness at most 2 x cost + 4 (here %d; yours %d). Only 6 of the game's 3,684 cards are bigger, all with a heavy drawback (Phyrexian Dreadnought, Lord of Tresserhorn, Endless Wurm, Aboroth, Primeval Force, Denizen of the Deep)." % [2 * e + 4, size])
		elif size > 2 * e + 1:
			say.call(HIGH, "power + toughness at most 2 x cost + 1 (here %d; yours %d) — 96 in 100 of the game's creatures keep to it." % [2 * e + 1, size])
		if body.x > e + 3:
			say.call(VERY_HIGH, "power at most cost + 3 (here %d; yours %d) — only Phyrexian Dreadnought, Lord of Tresserhorn and Endless Wurm have more." % [e + 3, body.x])
		if body.y > 2 * e + 4:
			say.call(VERY_HIGH, "toughness at most 2 x cost + 4 (here %d; yours %d) — only Phyrexian Dreadnought and Shield Sphere have more." % [2 * e + 4, body.y])
		var keywords := data.keywords.size()
		if keywords > 3:
			say.call(VERY_HIGH, "at most 3 keywords — no card of the game has more (yours has %d)." % keywords)
		elif keywords >= 2 and mv <= 1:
			say.call(VERY_HIGH, "one keyword at most for 0 or 1 mana — no card of the game has two (yours has %d)." % keywords)
		elif keywords >= 3 and mv <= 3:
			say.call(HIGH, "3 keywords for 3 mana or less — only Kjeldoran Skyknight (and one is banding).")
	var spell := types.has("instant") or types.has("sorcery")
	if spell and not (data.cost != null and data.cost.has_x):
		var amounts := _amounts(rules_text)
		if int(amounts.get("damage", 0)) > mv + 2:
			say.call(VERY_HIGH, "a spell deals at most cost + 2 damage (here %d; yours %d) — only Goblin Grenade and Reckless Abandon deal more, and both sacrifice a creature." % [mv + 2, amounts["damage"]])
		if int(amounts.get("draw", 0)) > mv + 2:
			say.call(VERY_HIGH, "a spell draws at most cost + 1 cards (here %d; yours %d) — past cost + 2 only Contract from Below, Timetwister and Wheel of Fortune, which all cost their caster dearly." % [mv + 1, amounts["draw"]])
		elif int(amounts.get("draw", 0)) > mv + 1:
			say.call(HIGH, "a spell draws at most cost + 1 cards (here %d; yours %d) — only Ancestral Recall, Brainstorm, Goblin Lore and the wheels draw more." % [mv + 1, amounts["draw"]])
		if int(amounts.get("life", 0)) > 2 * mv + 2:
			say.call(VERY_HIGH, "a spell gains at most 2 x cost + 2 life (here %d; yours %d) — no card of the game gains more." % [2 * mv + 2, amounts["life"]])
	for line in rules_text.split("\n", false):
		var ability := _ability(line)
		if not ability.is_empty() and String(ability["effect"]).begins_with("Add ") \
				and String(ability["price_text"]) == "{T}":
			var n := _mana_made(String(ability["effect"]))
			if types.has("land"):
				if n >= 3:
					say.call(VERY_HIGH, "a land taps for 1 mana, 2 at most — only the Urza lands, Mishra's Workshop and Scorched Ruins make 3 or more (yours %d)." % n)
				elif n == 2:
					say.call(HIGH, "a land taps for 1 mana — the lands that make 2 pay for it (pain, a bounce, depletion).")
			elif n > mv + 2:
				say.call(VERY_HIGH, "a permanent taps for at most cost + 2 mana (here %d; yours %d) — no card of the game makes more." % [mv + 2, n])
			elif types.has("creature") and mv <= 2 and n > 1:
				say.call(HIGH, "a creature of 2 mana or less taps for 1 mana — only Soldevi Machinist makes 2.")
		var anthem := _anthem(line)
		if anthem > 4:
			say.call(VERY_HIGH, "an anthem gives +1/+1 — none of the game's gives more than +2/+2 (yours +%d in all)." % anthem)
		elif anthem > 2:
			say.call(HIGH, "an anthem gives +1/+1 — only Jihad and Thran Weaponry give more, both with a price.")
		var aura := _aura(line)
		if aura > 2 * mv + 2:
			say.call(VERY_HIGH, "an Aura gives at most 2 x cost + 2 in all (here %d; yours %d) — only Unstable Mutation gives more, and it shrinks after." % [2 * mv + 2, aura])
	if not types.has("land") and mv > 9:
		say.call(HIGH, "a cost of 9 at most — only Aladdin's Lamp and Polar Kraken cost more.")
	if rules_text.split("\n", false).size() > 5:
		say.call(HIGH, "5 lines of rules at most — only Tidal Influence has more.")


static func _rank(level: String) -> int:
	return {OK: 0, LOW: 1, HIGH: 2, VERY_HIGH: 3}.get(level, 0)


## A creature's drawbacks (echo, cumulative upkeep, an upkeep cost to pay
## or sacrifice it, can't block, an extra life cost, defender): each counts
## as one more mana.
static func _drawbacks(spec: Dictionary, rules: Dictionary) -> int:
	var drawbacks := 0
	for id in ["echo", "cumulative_upkeep", "upkeep_cost", "cant_block", "extra_life"]:
		if rules.has(id):
			drawbacks += 1
	if CommunityCard._list(spec.get("keywords")).has("defender"):
		drawbacks += 1
	return drawbacks


static func _cost_rows(rows: Array[Dictionary], c: Dictionary, mv: int, spec: Dictionary) -> void:
	var costs: Array = c["costs"]
	if costs.is_empty():
		return
	var top := int(costs[-1])
	var at_least := costs.size() - costs.bsearch(mv)
	if mv > top:
		rows.append({"level": VERY_HIGH, "topic": "Mana cost",
			"text": "No card of the game costs more than %d (%s); yours costs %d." % [top, c["costs_top_name"], mv]})
	elif mv >= 7 and at_least * 50 < costs.size():
		rows.append({"level": HIGH, "topic": "Mana cost",
			"text": "Only %d of the game's %d cards cost %d or more." % [at_least, costs.size(), mv]})
	elif mv == 0 and not String(spec.get("cost", "")).contains("{X}"):
		rows.append({"level": HIGH, "topic": "Mana cost",
			"text": "Cards that cost nothing are rare: %d of the game's %d." % [int(c["free"]), costs.size()]})
	else:
		rows.append({"level": OK, "topic": "Mana cost", "text": "A cost of %d is usual." % mv})


static func _creature_rows(rows: Array[Dictionary], c: Dictionary, data: CardData, mv: int,
		spec: Dictionary, rules: Dictionary) -> void:
	# Drawbacks count as one more mana each (echo, upkeep, can't block, …).
	var drawbacks := _drawbacks(spec, rules)
	var shelf := mini(mv + drawbacks, TOP_SHELF)
	var said := ("%d-mana" % shelf) if drawbacks == 0 else ("%d-mana (its drawbacks counted as mana)" % shelf)
	var body := _body(data)
	var size := body.x + body.y
	var bucket: Dictionary = (c["size"] as Dictionary).get(shelf, {})
	if not bucket.is_empty():
		var values: Array = bucket["values"]
		var usual := _at(values, USUAL)
		var small := _at(values, 1.0 - USUAL)
		if size > int(bucket["max"]):
			rows.append({"level": VERY_HIGH, "topic": "Size",
				"text": "The biggest %s creature of the game is %s (%s); yours is %d/%d." % [said,
					bucket["max_name"], bucket["max_shown"], body.x, body.y]})
		elif size > usual:
			rows.append({"level": HIGH, "topic": "Size",
				"text": "9 in 10 of the game's %s creatures have power + toughness %d or less; yours has %d." % [said, usual, size]})
		elif size < small:
			rows.append({"level": LOW, "topic": "Size",
				"text": "9 in 10 of the game's %s creatures have power + toughness %d or more; yours has %d." % [said, small, size]})
		else:
			rows.append({"level": OK, "topic": "Size",
				"text": "%d/%d is a usual size for a %s creature (most are %d to %d in power + toughness)." % [
					body.x, body.y, said, small, usual]})
	for side in [["power", body.x], ["toughness", body.y]]:
		var most: Dictionary = c["most_" + String(side[0])]
		if int(side[1]) > int(most["value"]):
			rows.append({"level": VERY_HIGH, "topic": String(side[0]).capitalize(),
				"text": "No creature of the game has more %s than %d (%s); yours has %d." % [side[0],
					most["value"], most["name"], side[1]]})
	var keywords: Dictionary = (c["keywords"] as Dictionary).get(mini(mv, TOP_SHELF), {})
	var count := data.keywords.size()
	if not keywords.is_empty() and count > 0:
		if count > int(keywords["max"]):
			rows.append({"level": VERY_HIGH, "topic": "Keywords",
				"text": "No %d-mana creature of the game has more than %d keyword%s (%s); yours has %d." % [
					mini(mv, TOP_SHELF), keywords["max"], "" if int(keywords["max"]) == 1 else "s",
					keywords["max_name"], count]})
		elif count > _at(keywords["values"], USUAL_KEYWORDS):
			var most := _at(keywords["values"], USUAL_KEYWORDS)
			rows.append({"level": HIGH, "topic": "Keywords",
				"text": "Almost all of the game's %d-mana creatures have %d keyword%s or fewer; yours has %d." % [
					mini(mv, TOP_SHELF), most, "" if most == 1 else "s", count]})


## The rules text, line by line: what a spell or an ability gives for its
## price, the mana a permanent taps for, an anthem's or an Aura's bonus,
## how many things a line does and how many lines the card has.
static func _text_rows(rows: Array[Dictionary], c: Dictionary, data: CardData, mv: int,
		types: Array[String], land: bool) -> void:
	var spell := types.has("instant") or types.has("sorcery")
	var rules_text := _rules_of(data)
	var lines := rules_text.split("\n", false)
	if spell:
		_amount_rows(rows, c["spell"], _amounts(rules_text), mini(mv, TOP_SHELF), "%d-mana spells")
	for line in lines:
		var ability := _ability(line)
		if not ability.is_empty():
			if String(ability["effect"]).begins_with("Add ") and String(ability["price_text"]) == "{T}":
				_mana_row(rows, c, _mana_made(String(ability["effect"])), "land" if land else str(mini(mv, TOP_SHELF)))
			else:
				_amount_rows(rows, c["ability"], _amounts(String(ability["effect"])),
					mini(int(ability["price"]), TOP_SHELF), "abilities of price %d")
		var anthem := _anthem(line)
		if anthem > 0:
			_bonus_row(rows, c["anthem"], anthem, mini(mv, TOP_SHELF), "Anthem", "%d-mana anthems")
		var aura := _aura(line)
		if aura > 0:
			_bonus_row(rows, c["aura"], aura, mini(mv, TOP_SHELF), "Aura", "%d-mana Auras")
		var clauses := _clauses(line)
		if clauses > int(c["clauses_max"]):
			rows.append({"level": VERY_HIGH, "topic": "Effects",
				"text": "No line of the game's cards does more than %d things; \"%s\" does %d." % [
					c["clauses_max"], _short(line), clauses]})
	var things := 0
	for line in lines:
		things += _clauses(line)
	_effects_row(rows, c, things, mini(mv, TOP_SHELF), land)
	if lines.size() > int(c["lines_max"]):
		rows.append({"level": VERY_HIGH, "topic": "Rules text",
			"text": "No card of the game has more than %d lines of rules (%s); yours has %d." % [
				c["lines_max"], c["lines_max_name"], lines.size()]})
	elif lines.size() > int(c["lines_rare"]):
		rows.append({"level": HIGH, "topic": "Rules text",
			"text": "Only 1 in 100 of the game's cards has %d lines of rules or more." % lines.size()})


## How many things the whole card does, beside the game's cards of its cost.
static func _effects_row(rows: Array[Dictionary], c: Dictionary, n: int, shelf: int, land: bool) -> void:
	var bucket: Dictionary = (c["verbs"] as Dictionary).get("land" if land else shelf, {})
	if bucket.is_empty() or n == 0:
		return
	var said := "lands" if land else "%d-mana cards" % shelf
	var usual := _at(bucket["values"], USUAL)
	if n > int(bucket["max"]):
		rows.append({"level": VERY_HIGH, "topic": "Effects",
			"text": "None of the game's %s does more than %d things (%s); yours does %d." % [said, bucket["max"],
				bucket["max_name"], n]})
	elif n > usual:
		rows.append({"level": HIGH, "topic": "Effects",
			"text": "9 in 10 of the game's %s do %d things or fewer; yours does %d." % [said, usual, n]})
	else:
		rows.append({"level": OK, "topic": "Effects", "text": "%d things is usual for %s." % [n, said]})


static func _amount_rows(rows: Array[Dictionary], table: Dictionary, amounts: Dictionary, shelf: int,
		what: String) -> void:
	var said := what % shelf
	for kind in amounts:
		var n := int(amounts[kind])
		var bucket: Dictionary = (table[kind] as Dictionary).get(shelf, {})
		var topic := {"damage": "Damage", "draw": "Cards drawn", "life": "Life"}[kind] as String
		var verb := {"damage": "deal", "draw": "draw", "life": "give"}[kind] as String
		var unit := {"damage": "damage", "draw": "cards", "life": "life"}[kind] as String
		if bucket.is_empty():
			var best := _best_below(table[kind], shelf)
			if best.is_empty() or n > int(best["max"]):
				rows.append({"level": VERY_HIGH, "topic": topic,
					"text": "None of the game's %s or cheaper %s %d %s." % [said, verb + "s" if verb != "give" else "gives", n, unit]})
			else:
				rows.append({"level": OK, "topic": topic, "text": "%d %s is in reach of the game's cheaper cards (%s)." % [n, unit, best["max_name"]]})
			continue
		var usual := _at(bucket["values"], USUAL)
		if n > int(bucket["max"]):
			rows.append({"level": VERY_HIGH, "topic": topic,
				"text": "The game's %s %s at most %d %s (%s); yours %s %d." % [said, verb, bucket["max"], unit,
					bucket["max_name"], verb + "s" if verb != "give" else "gives", n]})
		elif n > usual:
			rows.append({"level": HIGH, "topic": topic,
				"text": "9 in 10 of the game's %s %s %d %s or less; yours %s %d." % [said, verb, usual, unit,
					verb + "s" if verb != "give" else "gives", n]})
		else:
			rows.append({"level": OK, "topic": topic, "text": "%d %s is usual for %s." % [n, unit, said]})


static func _best_below(table: Dictionary, shelf: int) -> Dictionary:
	var best := {}
	for key in table:
		if int(key) <= shelf and (best.is_empty() or int(table[key]["max"]) > int(best["max"])):
			best = table[key]
	return best


static func _mana_row(rows: Array[Dictionary], c: Dictionary, n: int, shelf: String) -> void:
	var bucket: Dictionary = (c["mana"] as Dictionary).get(shelf, {})
	var said := "lands" if shelf == "land" else "%s-mana permanents" % shelf
	if bucket.is_empty():
		rows.append({"level": HIGH, "topic": "Mana",
			"text": "None of the game's %s taps for mana; yours makes %d." % [said, n]})
	elif n > int(bucket["max"]):
		rows.append({"level": VERY_HIGH, "topic": "Mana",
			"text": "The game's %s tap for at most %d mana (%s); yours makes %d." % [said, bucket["max"], bucket["max_name"], n]})
	elif n > _at(bucket["values"], USUAL):
		rows.append({"level": HIGH, "topic": "Mana",
			"text": "9 in 10 of the game's %s tap for %d mana or less (%s makes %d); yours makes %d." % [said,
				_at(bucket["values"], USUAL), bucket["max_name"], bucket["max"], n]})
	else:
		rows.append({"level": OK, "topic": "Mana", "text": "%d mana from {T} is usual for %s." % [n, said]})


static func _bonus_row(rows: Array[Dictionary], table: Dictionary, n: int, shelf: int, topic: String,
		what: String) -> void:
	var said := what % shelf
	var bucket: Dictionary = table.get(shelf, {})
	if bucket.is_empty():
		var best := _best_below(table, shelf)
		var top := int(best.get("max", 2))
		rows.append({"level": VERY_HIGH if n > top else OK, "topic": topic,
			"text": ("The game's cheaper anthems and Auras give at most +%d in all; yours gives +%d." % [top, n])
				if n > top else "+%d in all is in reach of the game's cards." % n})
	elif n > int(bucket["max"]):
		rows.append({"level": VERY_HIGH, "topic": topic,
			"text": "The game's %s give at most +%d power and toughness in all (%s); yours gives +%d." % [said,
				bucket["max"], bucket["max_name"], n]})
	elif n > _at(bucket["values"], USUAL):
		rows.append({"level": HIGH, "topic": topic,
			"text": "9 in 10 of the game's %s give +%d in all or less; yours gives +%d." % [said,
				_at(bucket["values"], USUAL), n]})
	else:
		rows.append({"level": OK, "topic": topic, "text": "+%d in all is usual for %s." % [n, said]})


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
## "Few" (LOW): at most a tenth of the home color's share, and fewer than
## 1 in 20 of the color's cards. "Almost none" (HIGH): at most a 25th of
## it, and fewer than 1 in 200. Never VERY_HIGH: a color hint is a matter
## of flavor, not strength. (A quarter called Prodigal Sorcerer and
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
	"counter": ["counter spells", "counter target", "\\bcounter target"],
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
		spec: Dictionary, rules: Dictionary) -> void:
	if _is_star(data):
		return
	var key := _color_key(data)
	var group: Dictionary = (c["by_color"] as Dictionary)[key]
	var drawbacks := _drawbacks(spec, rules)
	var shelf := mini(mv + drawbacks, TOP_SHELF)
	var color := String(COLOR_WORDS[key])
	var said := ("%d-mana %s" % [shelf, color]) if drawbacks == 0 \
		else ("%d-mana %s (its drawbacks counted as mana)" % [shelf, color])
	var body := _body(data)
	var size := body.x + body.y
	var everyone: Dictionary = (c["size"] as Dictionary).get(shelf, {})
	var bucket: Dictionary = (group["size"] as Dictionary).get(shelf, {})
	if not everyone.is_empty() and _unusual(everyone["values"], size, USUAL) \
			and not bucket.is_empty() and (bucket["values"] as Array).size() >= COLOR_SHELF_MIN:
		var most := _at(bucket["values"], COLOR_USUAL)
		var least := _at(bucket["values"], 1.0 - COLOR_USUAL)
		if size > int(bucket["max"]):
			rows.append({"level": HIGH, "topic": "Size by color",
				"text": "The biggest %s creature of the game is %s (%s); yours is %d/%d." % [said,
					bucket["max_name"], bucket["max_shown"], body.x, body.y]})
		elif size > most:
			rows.append({"level": HIGH, "topic": "Size by color",
				"text": "Almost all of the game's %s creatures have power + toughness %d or less; yours has %d." % [said, most, size]})
		elif size < least:
			rows.append({"level": LOW, "topic": "Size by color",
				"text": "Almost all of the game's %s creatures have power + toughness %d or more; yours has %d." % [said, least, size]})
		else:
			rows.append({"level": OK, "topic": "Size by color",
				"text": "%d/%d is in reach of the game's %s creatures (almost all are %d to %d in power + toughness)." % [
					body.x, body.y, said, least, most]})
		for side in [["power", body.x], ["toughness", body.y]]:
			var top: Dictionary = (group[side[0]] as Dictionary).get(shelf, {})
			if not top.is_empty() and int(side[1]) > int(top["max"]):
				rows.append({"level": HIGH, "topic": "%s by color" % String(side[0]).capitalize(),
					"text": "No %s creature of the game has more than %d %s (%s); yours has %d." % [said,
						top["max"], side[0], top["max_name"], side[1]]})
	var kw_shelf := mini(mv, TOP_SHELF)
	var all_keywords: Dictionary = (c["keywords"] as Dictionary).get(kw_shelf, {})
	var keywords: Dictionary = (group["keyword_count"] as Dictionary).get(kw_shelf, {})
	var count := data.keywords.size()
	if count > 0 and not all_keywords.is_empty() and count > _at(all_keywords["values"], USUAL_KEYWORDS) \
			and not keywords.is_empty() and (keywords["values"] as Array).size() >= COLOR_SHELF_MIN:
		var most := _at(keywords["values"], COLOR_USUAL)
		var plural := func(n: int) -> String: return "keyword" if n == 1 else "keywords"
		if count > int(keywords["max"]):
			rows.append({"level": HIGH, "topic": "Keywords by color",
				"text": "No %d-mana %s creature of the game has more than %d %s (%s); yours has %d." % [
					kw_shelf, color, keywords["max"], plural.call(int(keywords["max"])), keywords["max_name"], count]})
		elif count > most:
			rows.append({"level": HIGH, "topic": "Keywords by color",
				"text": "Almost all of the game's %d-mana %s creatures have %d %s or fewer; yours has %d." % [
					kw_shelf, color, most, plural.call(most), count]})
		else:
			rows.append({"level": OK, "topic": "Keywords by color",
				"text": "%d %s is in reach of the game's %d-mana %s creatures (%s has %d)." % [count,
					plural.call(count), kw_shelf, color, keywords["max_name"], keywords["max"]]})


## Whether [param n] is past what [param share] of [param values] (sorted)
## keep to, either way.
static func _unusual(values: Array, n: int, share: float) -> bool:
	return n > _at(values, share) or n < _at(values, 1.0 - share)


## THE COLOR HINTS: what the card does (and, for a creature, its keywords)
## that few cards of its color do, LOW or HIGH, with the color the effect
## is at home in.
static func _pie_rows(rows: Array[Dictionary], c: Dictionary, data: CardData, creature: bool) -> void:
	var keywords: Array = []
	if creature:
		keywords = data.keywords
	_pie_rows_of(rows, c, _pie_colors(data), _pie_effects(_rules_of(data)), keywords)


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
	if home.is_empty() or int(home["count"]) < PIE_EVIDENCE or colors.has(String(home["color"])):
		return
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
	var level := ""
	if share * PIE_NONE <= at_home and share < PIE_NONE_SHARE:
		level = HIGH
	elif share * PIE_FEW <= at_home and share < PIE_FEW_SHARE:
		level = LOW
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
		text = "%s %s %s %s (%s %s; %s)." % ["Almost no" if level == HIGH else "Few", who, noun, does,
			_percent(share), of_them, home_said]
	rows.append({"level": level, "topic": PIE_TOPIC, "text": text})


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
			for reading in _pie_reading:
				var id := String(reading[0])
				if found.has(id):
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

## The numbers of the game's own cards (counted once per pool). Its
## `color_flagged` counts the game's own nonland cards that would get a
## color line beside the rest (`pie` the color hints, `size` the by-color
## rows past usual, `any` either, of `cards`), so the color lines can be
## held to the few cards that really are off their color.
static func corpus() -> Dictionary:
	var size := CardRegistry.size() - CardRegistry.community_names().size()
	if size == _corpus_size and not _corpus.is_empty():
		return _corpus
	var skip := {}
	for n in CardRegistry.community_names():
		skip[n] = true
	var c := {"cards": 0, "costs": [], "costs_top_name": "", "free": 0, "size": {}, "keywords": {},
		"most_power": {"value": 0, "name": ""}, "most_toughness": {"value": 0, "name": ""},
		"spell": {"damage": {}, "draw": {}, "life": {}}, "ability": {"damage": {}, "draw": {}, "life": {}},
		"mana": {}, "anthem": {}, "aura": {}, "lines": [], "lines_max_name": "", "clauses": [], "verbs": {}}
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
	for card_name in CardRegistry.all_names():
		if skip.has(card_name):
			continue
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		var land := data.is_land()
		var mv := data.cost.mana_value() if data.cost != null else 0
		var shelf := mini(mv, TOP_SHELF)
		var rules_text := _rules_of(data)
		var lines := rules_text.split("\n", false)
		var things := 0
		if not land:
			c["cards"] = int(c["cards"]) + 1
			(c["costs"] as Array).append(mv)
			if mv == 0 and not (data.cost != null and data.cost.has_x):
				c["free"] = int(c["free"]) + 1
			(c["lines"] as Array).append(lines.size())
			if lines.size() > most_lines:
				most_lines = lines.size()
				c["lines_max_name"] = card_name
			if mv > most_cost:
				most_cost = mv
				c["costs_top_name"] = card_name
			read[card_name] = _count_color(by_color[_color_key(data)], data, rules_text, shelf, card_name)
		if data.is_type(Mtg.CardType.CREATURE):
			_add(c["keywords"], shelf, data.keywords.size(), card_name)
			if not _is_star(data, rules_text):
				var body := _body(data)
				_add(c["size"], shelf, body.x + body.y, card_name, "%d/%d" % [body.x, body.y])
				for side in [["power", body.x], ["toughness", body.y]]:
					var most: Dictionary = c["most_" + String(side[0])]
					if int(side[1]) > int(most["value"]):
						most["value"] = int(side[1])
						most["name"] = card_name
		if data.is_type(Mtg.CardType.INSTANT) or data.is_type(Mtg.CardType.SORCERY):
			var amounts := _amounts(rules_text)
			for kind in amounts:
				_add(c["spell"][kind], shelf, int(amounts[kind]), card_name)
		for line in lines:
			var clauses := _clauses(line)
			things += clauses
			(c["clauses"] as Array).append(clauses)
			var ability := _ability(line)
			if not ability.is_empty():
				if String(ability["effect"]).begins_with("Add ") and String(ability["price_text"]) == "{T}":
					_add(c["mana"], "land" if land else str(shelf), _mana_made(String(ability["effect"])), card_name)
				else:
					var amounts := _amounts(String(ability["effect"]))
					for kind in amounts:
						_add(c["ability"][kind], mini(int(ability["price"]), TOP_SHELF), int(amounts[kind]), card_name)
			var anthem := _anthem(line)
			if anthem > 0:
				_add(c["anthem"], shelf, anthem, card_name)
			var aura := _aura(line)
			if aura > 0:
				_add(c["aura"], shelf, aura, card_name)
		_add(c["verbs"], "land" if land else shelf, things, card_name)
	(c["costs"] as Array).sort()
	var lines_all: Array = c["lines"]
	lines_all.sort()
	c["lines_max"] = int(lines_all[-1]) if not lines_all.is_empty() else 0
	c["lines_rare"] = _at(lines_all, 0.99)
	var clauses: Array = c["clauses"]
	clauses.sort()
	c["clauses_max"] = int(clauses[-1]) if not clauses.is_empty() else 0
	c.erase("clauses")
	c["pie_home"] = _pie_homes(by_color, "effects", "cards")
	c["pie_home_keywords"] = _pie_homes(by_color, "keywords", "creatures")
	_sort_all(c)
	c["color_flagged"] = _color_flagged(c, read)
	_corpus = c
	_corpus_size = size
	return c


## One nonland card of the game counted on its color's shelf; returns the
## effects read from it.
static func _count_color(group: Dictionary, data: CardData, rules_text: String, shelf: int,
		card_name: String) -> Array[String]:
	group["cards"] = int(group["cards"]) + 1
	var effects: Dictionary = group["effects"]
	var found := _pie_effects(rules_text)
	for id in found:
		effects[id] = int(effects.get(id, 0)) + 1
	if not data.is_type(Mtg.CardType.CREATURE):
		return found
	group["creatures"] = int(group["creatures"]) + 1
	var keywords: Dictionary = group["keywords"]
	var seen := {}
	for k in data.keywords:
		if not seen.has(k):
			seen[k] = true
			keywords[k] = int(keywords.get(k, 0)) + 1
	_add(group["keyword_count"], shelf, data.keywords.size(), card_name)
	if _is_star(data, rules_text):
		return found
	var body := _body(data)
	_add(group["size"], shelf, body.x + body.y, card_name, "%d/%d" % [body.x, body.y])
	_add(group["power"], shelf, body.x, card_name)
	_add(group["toughness"], shelf, body.y, card_name)
	return found


## How many of the game's own nonland cards get a color line past usual
## (see [method corpus]), each read as a community card of its cost would
## be (no drawbacks counted).
static func _color_flagged(c: Dictionary, read: Dictionary) -> Dictionary:
	var out := {"pie": 0, "size": 0, "any": 0, "cards": read.size()}
	for card_name in read:
		var data := CardRegistry.get_card(card_name)
		var creature := data.is_type(Mtg.CardType.CREATURE)
		var rows: Array[Dictionary] = []
		var keywords: Array = []
		if creature:
			keywords = data.keywords
		_pie_rows_of(rows, c, _pie_colors(data), read[card_name], keywords)
		var pie := not rows.is_empty()
		var size := false
		if creature:
			rows.clear()
			_color_size_rows(rows, c, data, data.cost.mana_value() if data.cost != null else 0, {}, {})
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
## exiles), and reminder text in parentheses left out (Brand's cycling
## reminder draws no card; a dual land's "({T}: Add {W} or {U}.)" is its
## land type, not an ability). A one-word name that is itself one of the
## verbs read ("Exile") is kept: its text says what it does.
static func _rules_of(data: CardData) -> String:
	var text := data.oracle_text
	var name := data.card_name.strip_edges()
	if name != "" and _rx("(?i)^" + _VERBS + "$").search(name) == null:
		text = text.replace(name, "CARDNAME")
	text = _rx("[ \\t]*\\([^)]*\\)").sub(text, "", true)
	var lines := PackedStringArray()
	for line in text.split("\n", false):
		var kept := line.strip_edges()
		if kept != "":
			lines.append(kept)
	return "\n".join(lines)


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


## Damage, cards drawn and life gained in [param text] (none when X).
static func _amounts(text: String) -> Dictionary:
	var out := {}
	var lower := text.to_lower()
	var damage := _rx("deals (\\d+) damage").search(lower)
	if damage != null:
		out["damage"] = int(damage.get_string(1))
	var draw := _rx("\\bdraws? (a|one|two|three|four|five|six|seven|\\d+) cards?").search(lower)
	if draw != null:
		out["draw"] = _word_number(draw.get_string(1))
	var life := _rx("gains? (\\d+) life").search(lower)
	if life != null:
		out["life"] = int(life.get_string(1))
	return out


static func _word_number(word: String) -> int:
	return int(word) if word.is_valid_int() else int(_WORD_NUMBERS.get(word, 1))


## The mana one "Add …" makes.
static func _mana_made(effect: String) -> int:
	# "Add {W} or {U}" makes one of them.
	effect = effect.get_slice(" or ", 0)
	var n := 0
	for hit in _rx("\\{([WUBRGC]|\\d+)\\}").search_all(effect):
		var s := hit.get_string(1)
		n += int(s) if s.is_valid_int() else 1
	if n == 0:
		var words := _rx("(one|two|three|four|five) mana").search(effect.to_lower())
		n = _word_number(words.get_string(1)) if words != null else 1
	return n


## An anthem's bonus (power + toughness) in [param line], 0 for none.
static func _anthem(line: String) -> int:
	if line.contains("until end of turn") or line.contains("Enchanted") or line.contains("Equipped"):
		return 0
	var hit := _rx("creatures (?:you control )?get \\+(\\d+)/\\+(\\d+)").search(line)
	return int(hit.get_string(1)) + int(hit.get_string(2)) if hit != null else 0


## An Aura's bonus (power + toughness) in [param line], 0 for none.
static func _aura(line: String) -> int:
	if line.contains("until end of turn"):
		return 0
	var hit := _rx("Enchanted creature gets \\+(\\d+)/\\+(\\d+)").search(line)
	return int(hit.get_string(1)) + int(hit.get_string(2)) if hit != null else 0


## How many things [param line] does (its verbs).
static func _clauses(line: String) -> int:
	return _rx("(?i)" + _VERBS).search_all(line).size()
