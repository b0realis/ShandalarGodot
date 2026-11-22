class_name CardImport
extends RefCounted
## A GAME CARD AS A DRAFT: the spec ([CommunityCard]) that builds the same
## card, as far as the vocabulary reaches — read off what every card shows
## as data ([CardData]: its cost, types, power and toughness, its rules
## text), never off its script.
##
## THE GENERATOR, INVERTED. Every entry of the vocabulary tables is written
## once by [CommunityCard]'s own text functions with placeholders for its
## numbers and words, and that text is made a pattern; a clause of the
## card's rules text that fits a pattern gives the entry and its
## parameters. So a new entry of the tables is matched with no line here.
## Both sides are compared NORMALISED ([method norm]): case, the card's
## name and "this creature" as "~", reminder text gone, number words as
## digits, old wording as the new ([constant SYNONYMS]).
##
## NOTHING IS GUESSED: a block is kept only when the text [CommunityCard]
## writes for it equals the clause; any other clause is `dropped` in the
## card's own words. Nothing of the card's pictures is copied.

## Wording the cards use and the generator does not, each as the
## generator's ([method norm] applies them in order, after lower-casing).
const SYNONYMS := [
	["enters the battlefield", "enters"], ["comes into play", "enters"],
	["this creature", "~"], ["this artifact", "~"], ["this enchantment", "~"], ["this land", "~"],
	["this permanent", "~"], ["this aura", "~"], ["this card", "~"], ["this spell", "~"],
	["cannot", "can't"], ["the top card", "the top 1 card"], [", it deals ", ", ~ deals "], [", it gets ", ", ~ gets "],
	["each player's upkeep", "each upkeep"], ["/-0", "/+0"],
	["is put into a graveyard from play", "is put into a graveyard from the battlefield"],
	["onto the battlefield under your control", "onto the battlefield"],
]
const _NUMBERS := {"a": "1", "an": "1", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
	"six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "zero": "0"}
## The stand-in name the vocabulary's texts are written with.
const _NAME := "Zzname"
## The placeholders, in the order they are looked for at one place of a
## text: [what is written, the pattern's group, the key it fills].
const _HOLES := [
	["\\+92", "([+-](?:\\d+|x))", "power"], ["\\+93", "([+-](?:\\d+|x))", "toughness"],
	["92", "(\\d+)", "power"], ["93", "(\\d+)", "toughness"], ["91", "(\\d+|x)", "amount"],
	["94", "(\\d+)", "unless"], ["zzonly", "([a-z]+)", "only"], ["zzcolor", "([a-z]+)", "color"],
	["zzsub", "([a-z]+)", "subtype"], ["zzkw", "([a-z ,]+?)", "keywords"], ["zznamed", "(.+?)", "named"],
	["\\{9\\}", "((?:\\{[0-9wubrgx]+\\})+)", "cost"],
]

static var _ready_for := -1
static var _effects_by_word: Dictionary = {}   # first word ("" = any) -> rows
static var _simple: Array = []                 # keyword, protection, landwalk and card-rule lines
static var _statics: Array = []
static var _aura: Array = []
static var _triggers: Array = []               # [prefix, when, enchanted], longest first
static var _counts: Dictionary = {}            # "swamp you control" -> id
static var _keywords: Dictionary = {}          # "first strike" -> id
static var _timings: Dictionary = {}           # " activate only during your turn" -> id
static var _quality: Dictionary = {}
static var _quality_for := -1
static var _rx: Dictionary = {}


# ------------------------------------------------------------ the answers --

## Whether a draft can be started from [param data] at all.
static func can_start(data: CardData) -> bool:
	if data == null or data.card_name.strip_edges() == "" or _types_of(data).is_empty():
		return false
	if _pattern("\\bante\\b").search(data.oracle_text.to_lower()) != null:
		return false
	return problems_of(_frame(data, [])).is_empty()


## The one problem a draft may still have: an instant or a sorcery none of
## whose effects the vocabulary writes has no spell effect yet (said in
## its notes; the editor asks for one before it saves).
const NEEDS_EFFECT := "An instant or a sorcery needs a spell effect."


## [method CommunityCard.problems] of a draft, but [constant NEEDS_EFFECT].
static func problems_of(spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line in CommunityCard.problems(spec):
		if line != NEEDS_EFFECT:
			out.append(line)
	return out


## How much of [param data] a draft keeps: 0 nothing but the frame, 100
## exact. Remembered per card until the registry changes.
static func quality(data: CardData) -> int:
	if data == null:
		return 0
	if _quality_for != CardRegistry.revision:
		_quality_for = CardRegistry.revision
		_quality.clear()
	if not _quality.has(data.card_name):
		_quality[data.card_name] = quality_of(from_card(data))
	return int(_quality[data.card_name])


## The same number from a result of [method from_card].
static func quality_of(result: Dictionary) -> int:
	if bool(result.get("exact", false)):
		return 100
	var kept := (result.get("kept", []) as Array).size()
	var dropped := (result.get("dropped", []) as Array).size()
	if dropped == 0:
		return 95   # every clause kept, something beside the text approximated
	if kept == 0:
		return 0
	return clampi(roundi(100.0 * kept / (kept + dropped)), 1, 94)


## The draft of [param data]: `spec`, `exact`, `kept`, `dropped`, `notes`.
static func from_card(data: CardData) -> Dictionary:
	_prepare()
	var notes: Array[String] = []
	var kept: Array[String] = []
	var dropped: Array[String] = []
	var spec := _frame(data, notes)
	var name := data.card_name
	var kinds: Array = spec["types"]
	var spell_like: bool = kinds.has("instant") or kinds.has("sorcery")
	# Each unit of the text and the block it gave: {line, ability | rule | part}.
	var units: Array = []
	var lines: Array[String] = []
	for raw in data.oracle_text.split("\n"):
		var line := _strip_reminders(raw).strip_edges()
		if line != "":
			lines.append(line)
	var aura := {}
	var aura_lines: Array[String] = []
	var i := 0
	while i < lines.size():
		var line := lines[i]
		i += 1
		# "Choose one —" and its modes are one block.
		if norm(line, name).begins_with("choose 1 —") and i < lines.size() and lines[i].begins_with("•"):
			var modes: Array = []
			var whole: Array[String] = [line]
			var fits := spell_like
			while i < lines.size() and lines[i].begins_with("•"):
				var found := _effects(norm(lines[i].trim_prefix("•"), name), kinds)
				fits = fits and not found.is_empty()
				modes.append({"effects": found})
				whole.append(lines[i])
				i += 1
			var modal := {"kind": "modal", "modes": modes}
			if fits and norm(CommunityCard.modal_text(modal, _NAME).replace("\n", " "), _NAME).replace("• ", "") \
					== norm(" ".join(whole), name).replace("• ", "").replace("•", ""):
				units.append({"line": "\n".join(whole), "ability": modal})
			else:
				for one in whole:
					dropped.append(one)
			continue
		var block := _clause(line, name, kinds, spell_like)
		if not block.is_empty():
			block["line"] = line
			units.append(block)
			continue
		if _aura_piece(line, name, aura):
			aura_lines.append(line)
			continue
		# Not as a whole: its sentences, each on its own — an Aura's, a
		# spell's, a line of several keywords. When none of them is
		# anything, the line is dropped as the one clause it is.
		var pieces := _keyword_parts(line) if not line.contains(". ") else _sentences(line)
		var parts: Array = []
		var some := false
		for piece in pieces:
			var part := {"aura": true} if pieces.size() > 1 and _aura_piece(piece, name, aura) \
				else (_clause(piece, name, kinds, spell_like, true) if pieces.size() > 1 else {})
			some = some or not part.is_empty()
			parts.append(part)
		if not some:
			dropped.append(line)
			continue
		for n in pieces.size():
			var part: Dictionary = parts[n]
			if part.is_empty():
				dropped.append(pieces[n])
			elif part.has("aura"):
				aura_lines.append(pieces[n])
			else:
				part["line"] = pieces[n]
				units.append(part)
	# The Aura's sentences are one block: kept only when it says them all.
	if not aura_lines.is_empty():
		var said := {}
		for sentence in _sentences(CommunityCard.enchant_text(aura)):
			said[norm(sentence, _NAME)] = true
		var all := aura.has("enchant")
		for sentence in aura_lines:
			all = all and said.has(norm(sentence, name))
		if all and said.size() == aura_lines.size():
			aura["kind"] = "enchant"
			units.push_front({"line": "\n".join(aura_lines), "ability": aura, "lines": aura_lines})
		else:
			dropped.append_array(aura_lines)
	for unit in units:
		_put(spec, unit)
	_settle(spec, units, dropped, notes)
	for unit in units:
		if unit.has("lines"):
			kept.append_array(unit["lines"])
		else:
			kept.append(String(unit["line"]))
	return {"spec": spec, "exact": dropped.is_empty() and notes.is_empty(), "kept": kept, "dropped": dropped,
		"notes": notes}


# -------------------------------------------------------------- the frame --

## The card's types by the catalogue's words ([] when one is not offered).
static func _types_of(data: CardData) -> Array[String]:
	var out: Array[String] = []
	var known := 0
	for word in CommunityCard.TYPES:
		known |= int(CommunityCard.TYPES[word])
		if data.is_type(int(CommunityCard.TYPES[word])):
			out.append(word)
	if (data.types & ~known) != 0:
		out.clear()
	return out


## What of the card is no rules text: name, cost, types, power and
## toughness, rarity. [param notes] hears what could not be carried.
static func _frame(data: CardData, notes: Array[String]) -> Dictionary:
	var types := _types_of(data)
	var name := _name(data.card_name)
	if name != data.card_name:
		notes.append("The name is written \"%s\": a card's name holds letters, digits, spaces and ' , - only." % name)
	var spec := {"format": CommunityCard.FORMAT, "version": CommunityCard.VERSION, "name": name,
		"cost": "", "types": types, "rarity": "common", "abilities": [], "flavor": "", "set_name": "",
		"artist": ""}
	if not types.has("land"):
		spec["cost"] = data.cost.text if data.cost != null else ""
		if spec["cost"] == "":
			spec["cost"] = "{0}"
	var rarity := CardRegistry.rarity_of(data.card_name, data.set_code).to_lower()
	if CommunityCard.RARITIES.has(rarity):
		spec["rarity"] = rarity
	if (data.supertypes & Mtg.Supertype.LEGENDARY) != 0:
		spec["supertypes"] = ["legendary"]
	if (data.supertypes & ~Mtg.Supertype.LEGENDARY) != 0:
		notes.append("Its basic, snow or world supertype is not offered.")
	var subs: Array[String] = []
	var lost := false
	for sub in data.subtypes:
		if sub.to_lower() == "aura":
			continue
		if (types.has("creature") or types.has("land")) and CommunityCard._word_ok(sub) \
				and subs.size() < int(CommunityCard.LIMITS["subtypes"]):
			subs.append(sub.to_lower())
		else:
			lost = true
	if lost:
		notes.append("Not every subtype could be kept.")
	if not subs.is_empty():
		spec["subtypes"] = subs
	if types.has("creature"):
		var limits: Array = CommunityCard.LIMITS["power"]
		spec["power"] = clampi(data.power, int(limits[0]), int(limits[1]))
		spec["toughness"] = clampi(data.toughness, int(limits[0]), int(limits[1]))
		if spec["power"] != data.power or spec["toughness"] != data.toughness:
			notes.append("Its power and toughness are outside 0 to 99.")
	if data.cost != null and not types.has("land") and data.color_mask() != data.cost.color_mask():
		notes.append("Its color is not the color of its mana cost.")
	return spec


## The name as a community card may be called: accents written plain,
## other signs left out.
static func _name(name: String) -> String:
	var plain := {"á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "í": "i", "ö": "o",
		"ó": "o", "ú": "u", "û": "u", "ü": "u", "Æ": "Ae", "æ": "ae", "’": "'"}
	var out := ""
	for ch in name:
		var c := String(plain.get(ch, ch))
		if _pattern("^[A-Za-z0-9 ',\\-]+$").search(c) != null:
			out += c
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.left(int(CommunityCard.LIMITS["name"]))


## [param unit]'s block into [param spec].
static func _put(spec: Dictionary, unit: Dictionary) -> void:
	if unit.has("ability"):
		(spec["abilities"] as Array).append(unit["ability"])
	elif unit.has("rule"):
		if not spec.has("rules"):
			spec["rules"] = {}
		spec["rules"][unit["rule"]] = unit["value"]
	elif unit.has("list"):
		if not spec.has(unit["list"]):
			spec[unit["list"]] = []
		if not (spec[unit["list"]] as Array).has(unit["value"]):
			(spec[unit["list"]] as Array).append(unit["value"])


static func _take(spec: Dictionary, unit: Dictionary) -> void:
	if unit.has("ability"):
		(spec["abilities"] as Array).erase(unit["ability"])
	elif unit.has("rule"):
		(spec.get("rules", {}) as Dictionary).erase(unit["rule"])
	elif unit.has("list"):
		(spec.get(unit["list"], []) as Array).erase(unit["value"])


## THE WHOLE CARD CHECKED: a block that makes the card no card is taken
## out again, and said. What is left always passes [method
## CommunityCard.problems] (a name the game has is the screen's to say).
static func _settle(spec: Dictionary, units: Array, dropped: Array[String], notes: Array[String]) -> void:
	var guard := 0
	while guard < 40:
		guard += 1
		var found := problems_of(spec)
		if found.is_empty():
			if CommunityCard.problems(spec).has(NEEDS_EFFECT):
				notes.append("It has no spell effect yet: add one before saving.")
			return
		var out: Dictionary = {}
		var hit := _pattern("^Ability (\\d+): ").search(found[0])
		if hit != null:
			var at := int(hit.get_string(1)) - 1
			var abilities: Array = spec["abilities"]
			for unit in units:
				if unit.has("ability") and at < abilities.size() and is_same(unit["ability"], abilities[at]):
					out = unit
		if out.is_empty():
			# Not an ability's: the block whose leaving mends it, else the last.
			for unit in units:
				_take(spec, unit)
				var better := problems_of(spec).size() < found.size()
				_put(spec, unit)
				if better:
					out = unit
					break
			if out.is_empty() and not units.is_empty():
				out = units[-1]
		if out.is_empty():
			return
		_take(spec, out)
		units.erase(out)
		if out.has("lines"):
			dropped.append_array(out["lines"])
		else:
			dropped.append(String(out["line"]))
		notes.append("\"%s\" was left out: %s" % [String(out["line"]).replace("\n", " "), found[0]])


# ------------------------------------------------------------- one clause --

## The block [param line] is, {} when the vocabulary has none that says
## exactly this. [param piece]: one sentence of a longer line — no ability
## with a cost or a condition is read from a part of its line.
static func _clause(line: String, name: String, kinds: Array, spell_like: bool, piece := false) -> Dictionary:
	var text := norm(line, name)
	if text == "":
		return {}
	for row in _simple:
		var hit: RegExMatch = (row["rx"] as RegEx).search(text)
		if hit != null:
			var unit: Dictionary = (row["unit"] as Dictionary).duplicate(true)
			if row["keys"].has("amount"):
				unit["value"] = int(hit.get_string(1))
			elif row["keys"].has("cost"):
				unit["value"] = hit.get_string(1).to_upper()
			return unit
	for row in _statics:
		var hit: RegExMatch = (row["rx"] as RegEx).search(text)
		if hit == null:
			continue
		var a := _filled(row, hit)
		if not a.is_empty() and norm(CommunityCard.static_text(a), _NAME) == text:
			return {"ability": a}
	if piece:
		if spell_like:
			var some := _effects(text, kinds)
			if not some.is_empty():
				return {"ability": {"kind": "spell", "effects": some}}
		return {}
	if spell_like:
		var effects := _effects(text, kinds)
		if not effects.is_empty():
			return {"ability": {"kind": "spell", "effects": effects}}
		return {}
	var built := _trigger(text, kinds)
	if built.is_empty():
		built = _activated(text, kinds)
	return {"ability": built} if not built.is_empty() else {}


## A triggered ability, {} when [param text] is none the tables write.
static func _trigger(text: String, kinds: Array) -> Dictionary:
	for row in _triggers:
		var prefix := String(row[0]) + ", "
		if not text.begins_with(prefix):
			continue
		var body := text.substr(prefix.length())
		var tries: Array = []   # [choice, the effects' text]
		if body.begins_with("you may "):
			var rest := body.substr(8)
			var after := ""
			var cut := rest.find(". if you do, ")
			if cut >= 0:
				after = rest.substr(cut + 13)
				rest = rest.left(cut)
			var firsts: Array = [rest, "you " + rest]
			if rest.begins_with("have "):
				var told := rest.substr(5)
				for verb in CommunityCard._VERBS:
					told = told.replace(String(CommunityCard._VERBS[verb]), String(verb))
				firsts.append(told)
			for first in firsts:
				tries.append(["may", first, after])
		elif body.contains("up to 1 target"):
			tries.append(["up_to", body.replace("up to 1 target", "target"), ""])
		tries.append(["must", body, ""])
		for attempt in tries:
			var effects := _effects(String(attempt[1]), kinds)
			if effects.is_empty():
				continue
			if String(attempt[2]) != "":
				var more := _effects(String(attempt[2]), kinds)
				if more.is_empty():
					continue
				effects.append_array(more)
			var a := {"kind": "trigger", "when": row[1], "effects": effects}
			if String(attempt[0]) != "must":
				a["choice"] = attempt[0]
			if bool(row[2]):
				a["enchanted"] = true
			if norm(CommunityCard.ability_text(a, _NAME, false, kinds), _NAME) == text:
				return a
	return {}


## An activated or a mana ability — its costs read part by part, its
## effects from the tables; a shared one ("All Sliver creatures have …") and
## an Aura's gift ("Enchanted creature has …") by their quoted ability.
static func _activated(text: String, kinds: Array) -> Dictionary:
	var shared := _pattern("^all ([a-z]+) creatures have \"(.+?)\\.?\"$").search(text)
	var given := _pattern("^enchanted creature has \"(.+?)\\.?\"$").search(text)
	var inner := text
	if shared != null:
		inner = shared.get_string(2)
	elif given != null:
		inner = given.get_string(1)
	var colon := inner.find(": ")
	if colon <= 0:
		return {}
	var a := {"kind": "activated", "cost": "", "effects": []}
	for part in inner.left(colon).split(", "):
		var n := _pattern("^(\\d+)").search(part.trim_prefix("discard ").trim_prefix("pay ").trim_prefix("remove "))
		if part == "{t}":
			a["tap"] = true
		elif _pattern("^(\\{[0-9wubrgxc]+\\})+$").search(part) != null:
			a["cost"] = String(a["cost"]) + part.to_upper()
		elif part == "sacrifice ~":
			a["sacrifice"] = true
		elif part.begins_with("sacrifice 1 ") and CommunityCard.SACRIFICES.has(part.substr(12)):
			a["sacrifice_what"] = part.substr(12)
		elif part.begins_with("sacrifice another ") and CommunityCard.SACRIFICES.has(part.substr(18)):
			a["sacrifice_what"] = part.substr(18)
		elif n != null and part.begins_with("discard ") and part.ends_with(" card"):
			a["discard"] = int(n.get_string(1))
		elif n != null and part.begins_with("pay ") and part.ends_with(" life"):
			a["life"] = int(n.get_string(1))
		elif n != null and part.begins_with("remove ") and part.ends_with(" +1/+1 counter from ~"):
			a["remove_counters"] = int(n.get_string(1))
		else:
			return {}
	var does := inner.substr(colon + 2)
	# A mana ability: "{T}: Add {G}{G}.", "… Add one mana of any color."
	if does.begins_with("add ") and shared == null and given == null:
		var mana := {"kind": "mana"}
		if String(a["cost"]) != "":
			mana["cost"] = a["cost"]
		if a.has("sacrifice"):
			mana["sacrifice"] = true
		var pain := _pattern("^(.+)\\. ~ deals (\\d+) damage to you$").search(does)
		if pain != null:
			mana["pain"] = int(pain.get_string(2))
			does = pain.get_string(1)
		var any := _pattern("^add (\\d+) mana of any (?:1 )?color$").search(does)
		var symbols := _pattern("^add ((?:\\{[wubrgc]\\})+)$").search(does)
		if any != null:
			mana["color"] = "any"
			mana["amount"] = int(any.get_string(1))
		elif symbols != null:
			var color: Variant = CommunityCard.MANA_SYMBOLS.find_key(symbols.get_string(1).left(3).to_upper())
			if color != null:
				mana["color"] = String(color)
				mana["amount"] = symbols.get_string(1).count("{")
		if mana.has("color") and norm(CommunityCard.mana_text(mana, _NAME), _NAME) == text:
			return mana
		return {}
	for suffix in _timings:
		if does.ends_with(String(suffix)):
			a["timing"] = _timings[suffix]
			does = does.left(does.length() - String(suffix).length())
			break
	var inside: Array = ["creature"] if shared != null or given != null else kinds
	a["effects"] = _effects(does, inside)
	if (a["effects"] as Array).is_empty():
		return {}
	if shared != null:
		a["shared"] = shared.get_string(1)
	if given != null:
		a["enchanted"] = true
	return a if norm(CommunityCard.ability_text(a, _NAME, false, kinds), _NAME) == text else {}


## One sentence of an Aura into [param aura] (true when it is one).
static func _aura_piece(piece: String, name: String, aura: Dictionary) -> bool:
	var text := norm(piece, name)
	for row in _aura:
		var hit: RegExMatch = (row["rx"] as RegEx).search(text)
		if hit == null:
			continue
		var a := _filled(row, hit)
		if a.is_empty():
			continue
		a.erase("kind")
		aura.merge(a, true)
		return true
	return false


# ------------------------------------------------------------ the effects --

## The effects [param text] says ([] when it is not all effects of the
## tables): one, or several joined as the generator joins them.
static func _effects(text: String, kinds: Array) -> Array:
	var one := _effect(text, kinds)
	if not one.is_empty():
		return [one]
	var parts: Array = []
	if text.contains(", then "):
		for part in text.split(", then "):
			var e := _effect(part, kinds)
			if e.is_empty():
				return []
			parts.append(e)
	else:
		var at := text.find(" and ")
		while at >= 0:
			var left := _effect(text.left(at), kinds)
			var right := _effect(text.substr(at + 5), kinds) if not left.is_empty() else {}
			if not right.is_empty():
				parts = [left, right]
				break
			at = text.find(" and ", at + 5)
	if parts.is_empty() or norm(CommunityCard.effects_text(parts, _NAME, "spell", kinds), _NAME) != text:
		return []
	return parts


## One effect, {} when no entry of the tables writes exactly [param text].
static func _effect(text: String, kinds: Array) -> Dictionary:
	var each := text.rfind(" for each ")
	if each > 0 and _counts.has(text.substr(each + 10)):
		var counted := _effect(text.left(each), kinds)
		if not counted.is_empty() and not counted.has("x") and not counted.has("per"):
			counted["per"] = _counts[text.substr(each + 10)]
			if norm(CommunityCard.effect_text(counted, _NAME, "spell", kinds), _NAME) == text:
				return counted
	var word := text.get_slice(" ", 0)
	for bucket in [_effects_by_word.get(word, []), _effects_by_word.get("", [])]:
		for row in bucket:
			var hit: RegExMatch = (row["rx"] as RegEx).search(text)
			if hit == null:
				continue
			var e := _filled(row, hit)
			if not e.is_empty() and norm(CommunityCard.effect_text(e, _NAME, "spell", kinds), _NAME) == text:
				return e
	return {}


## The entry of [param row] with what [param hit] caught ({} when a caught
## word is none the tables know).
static func _filled(row: Dictionary, hit: RegExMatch) -> Dictionary:
	var out: Dictionary = (row["base"] as Dictionary).duplicate(true)
	var keys: Array = row["keys"]
	for k in keys.size():
		var caught := hit.get_string(k + 1)
		match String(keys[k]):
			"amount":
				if caught == "x":
					out["x"] = true
					out.erase("amount")
				else:
					out["amount"] = int(caught)
			"power", "toughness":
				if caught.ends_with("x"):
					out["x"] = true
					out.erase(keys[k])
				else:
					out[keys[k]] = int(caught)
			"unless":
				out["unless"] = int(caught)
			"keywords":
				var list: Array = []
				for word in caught.replace(" and ", ", ").split(", "):
					if not _keywords.has(word):
						return {}
					list.append(_keywords[word])
				out["keywords"] = list
			"only":
				if not CommunityCard.ONLY.has(caught) or caught == "":
					return {}
				out["only"] = caught
			"named":
				out["named"] = caught.capitalize()
			_:
				out[keys[k]] = caught
	return out


# ----------------------------------------------------- the patterns, once --

## Every pattern, written from the tables (again when the registry changed:
## the tables are constants, the cost is small).
static func _prepare() -> void:
	if _ready_for == 0:
		return
	_ready_for = 0
	_effects_by_word.clear()
	_simple.clear()
	_statics.clear()
	_aura.clear()
	_triggers.clear()
	for id in CommunityCard.counts():
		_counts[norm(CommunityCard.count_words(id), _NAME)] = id
	for k in CommunityCard.KEYWORD_WORDS:
		_keywords[String(CommunityCard.KEYWORD_WORDS[k])] = k
	# The effects: each entry with each target and each of its choices.
	for id in CommunityCard.EFFECTS:
		for e in _effect_variants(String(id)):
			for with_land in ([[], ["land"]] if id == "animate" else [[]]):
				var row := _row(CommunityCard.effect_text(e, _NAME, "spell", with_land), e)
				if row.is_empty():
					continue
				var word := String(row["text"]).get_slice(" ", 0)
				if word.contains("(") or word.contains("\\") or word.contains("["):
					word = ""
				if not _effects_by_word.has(word):
					_effects_by_word[word] = []
				(_effects_by_word[word] as Array).append(row)
	# The lines that are one keyword, one protection, one landwalk, one card rule.
	var plain := {"name": _NAME}
	for k in CommunityCard.KEYWORDS:
		_simple_row(plain, {"keywords": [k]}, {"list": "keywords", "value": k})
	for c in CommunityCard.PROTECTIONS:
		_simple_row(plain, {"protection": [c]}, {"list": "protection", "value": c})
	for l in CommunityCard.LANDS:
		_simple_row(plain, {"landwalk": [l]}, {"list": "landwalk", "value": l})
	for id in CommunityCard.CARD_RULES:
		match String(CommunityCard.CARD_RULES[id]["kind"]):
			"flag": _simple_row(plain, {"rules": {id: true}}, {"rule": id, "value": true})
			"amount":
				_simple_row(plain, {"rules": {id: 91}}, {"rule": id, "value": 91})
				# "an additional creature": one is said its own way.
				_simple_row(plain, {"rules": {id: 1}}, {"rule": id, "value": 1})
			"cost": _simple_row(plain, {"rules": {id: "{9}"}}, {"rule": id, "value": ""})
			"count":
				for counted in CommunityCard.counts():
					_simple_row(plain, {"rules": {id: counted}}, {"rule": id, "value": counted})
	# The statics.
	for what in CommunityCard.STATICS:
		var info: Dictionary = CommunityCard.STATICS[what]
		var list: Array = [{"kind": "static", "what": what}]
		if info.get("subtype", false):
			list = _each(list, "subtype", ["zzsub"])
		if info.get("spell_type", false):
			list = _each(list, "spell_type", CommunityCard.COST_SPELL_TYPES if what == "cost_more"
				else CommunityCard.SPELL_TYPES)
		if info.has("amount"):
			list = _each(list, "amount", [91])
		if info.get("who", false):
			list = _each(list, "who", CommunityCard.COST_WHO)
		if info.get("spell_color", false):
			list = _each(list, "spell_color", [""] + CommunityCard.PROTECTIONS)
		if info.get("pt", false):
			list = _each(list, "power", [0, 92])
			list = _each(list, "keywords", [[], ["zzkw"]])
		for a in list:
			if a.has("power"):
				a["toughness"] = 93 if int(a["power"]) == 92 else 0
			if String(a.get("spell_color", "x")) == "":
				a.erase("spell_color")
			var row := _row(CommunityCard.static_text(a), a)
			if not row.is_empty():
				_statics.append(row)
	# An Aura, sentence by sentence.
	for host in CommunityCard.ENCHANTS:
		var gifts: Array = [{}, {"frozen": true}, {"control": true}]
		if host == "creature":
			gifts.append_array([{"power": 92, "toughness": 93}, {"power": 92, "toughness": 93, "keywords": ["zzkw"]},
				{"keywords": ["zzkw"]}, {"pacify": true}])
			for c in CommunityCard.PROTECTIONS:
				gifts.append({"protection": c})
		for gift in gifts:
			var a: Dictionary = {"enchant": host}
			a.merge(gift)
			var sentences := _sentences(CommunityCard.enchant_text(a))
			for n in sentences.size():
				if n == 0 and not (gift as Dictionary).is_empty():
					continue
				# The second sentence of a protection adds nothing of its own.
				var row := _row(sentences[n], a if n <= 1 else {"enchant": host})
				if not row.is_empty():
					_aura.append(row)
	# The triggers, the card's own and its creature's, longest first.
	for when in CommunityCard.TRIGGERS:
		_triggers.append([norm(String(CommunityCard.TRIGGERS[when]).replace("CARDNAME", _NAME), _NAME), when, false])
		if when in CommunityCard.HOST_TRIGGERS:
			_triggers.append([norm(String(CommunityCard.TRIGGERS[when]).replace("CARDNAME", "enchanted creature"),
				_NAME), when, true])
	_triggers.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	# "Activate only …", as the generator ends an ability with each timing.
	var base := {"kind": "activated", "cost": "{1}", "effects": [{"effect": "draw", "amount": 1}]}
	var bare := norm(CommunityCard.ability_text(base, _NAME), _NAME)
	for timing in CommunityCard.TIMINGS:
		var timed := base.duplicate(true)
		timed["timing"] = timing
		var said := norm(CommunityCard.ability_text(timed, _NAME), _NAME)
		if said != bare and said.begins_with(bare):
			_timings[said.substr(bare.length())] = timing


static func _simple_row(plain: Dictionary, more: Dictionary, unit: Dictionary) -> void:
	var spec := plain.duplicate(true)
	spec.merge(more)
	var row := _row(CommunityCard.rules_text(spec), {})
	if not row.is_empty():
		row["unit"] = unit
		_simple.append(row)


## Every way the effect [param id] may be asked for, numbers and words as
## placeholders.
static func _effect_variants(id: String) -> Array:
	var info: Dictionary = CommunityCard.EFFECTS[id]
	var list: Array = [{"effect": id}]
	if info.has("targets"):
		list = _each(list, "target", info["targets"])
	if info.has("amount"):
		list = _each(list, "amount", [91])
	if info.has("pt") or info.has("base") or info.has("token"):
		list = _each(list, "power", [92])
		list = _each(list, "toughness", [93])
	if info.has("pt") and info.get("x", false):
		list = _each(list, "x", [false, true])
	if info.has("pt"):
		# "Target creature has flying until end of turn": a keyword alone.
		list = _each(list, "power", [92, 0])
	if info.has("token"):
		list = _each(list, "color", ["zzcolor"])
		list = _each(list, "subtype", ["zzsub"])
		list = _each(list, "ends", CommunityCard.TOKEN_ENDS)
	elif info.has("subtype"):
		list = _each(list, "subtype", ["", "zzsub"])
	if info.has("unless"):
		list = _each(list, "unless", [0, 94])
	if info.has("land"):
		list = _each(list, "land", CommunityCard.LANDS)
	if info.has("lose"):
		list = _each(list, "keywords", CommunityCard.KEYWORDS.keys().map(func(k: Variant) -> Array: return [k]))
	elif info.has("keywords"):
		list = _each(list, "keywords", [[], ["zzkw"]])
	if info.has("shield"):
		list = _each(list, "color", CommunityCard.PROTECTIONS)
	if info.has("color") and not info.has("token"):
		list = _each(list, "color", CommunityCard.MANA_COLORS.keys())
		list = _each(list, "amount", [1, 2, 3, 4, 5])
	if info.has("from"):
		list = _each(list, "from", CommunityCard.SHUFFLE_FROM)
	if info.has("where"):
		list = _each(list, "where", CommunityCard.SEARCH_WHERE)
		list = _each(list, "amount", [1, 91])
		list = _each(list, "named", ["zznamed"])
	if info.get("only", false):
		list = _each(list, "only", ["", "zzonly"])
	var out: Array = []
	for e in list:
		# Left out where it is the default, as the editor leaves it.
		for key in ["x", "ends", "only", "subtype"]:
			if e.has(key) and (e[key] is bool and not e[key] or e[key] is String and e[key] == ""):
				e.erase(key)
		if e.has("only") and not String(e.get("target", "")) in CommunityCard.ONLY_TARGETS:
			continue
		if e.has("named") and String(e.get("target", "")) != "a_named":
			e.erase("named")
		if e.has("x") and info.has("pt"):
			if int(e.get("power", 92)) == 0:
				continue
			e.erase("power")
		if info.has("pt") and int(e.get("power", 92)) == 0:
			if not e.has("keywords") or (e["keywords"] as Array).is_empty():
				continue
			e["toughness"] = 0
		out.append(e)
	return out


## [param list] with [param key] set to each of [param values].
static func _each(list: Array, key: String, values: Array) -> Array:
	var out: Array = []
	for item in list:
		for value in values:
			var one: Dictionary = (item as Dictionary).duplicate(true)
			one[key] = value
			out.append(one)
	return out


## The pattern of [param text] (as the generator wrote it, placeholders in
## it) for the entry [param base]: {rx, keys, base, text}; {} for no text.
static func _row(text: String, base: Dictionary) -> Dictionary:
	var plain := norm(text, _NAME)
	if plain == "":
		return {}
	var escaped := ""
	for ch in plain:
		escaped += ("\\" + ch) if ch in "\\.^$|?*+()[]{}" else ch
	var source := ""
	var keys: Array = []
	var at := 0
	while at < escaped.length():
		var took := false
		for hole in _HOLES:
			if escaped.substr(at, String(hole[0]).length()) == String(hole[0]):
				source += String(hole[1])
				keys.append(hole[2])
				at += String(hole[0]).length()
				took = true
				break
		if not took:
			source += escaped[at]
			at += 1
	var clean: Dictionary = base.duplicate(true)
	for key in ["amount", "power", "toughness", "unless"]:
		if clean.has(key) and int(clean[key]) > 90:
			clean.erase(key)
	return {"rx": RegEx.create_from_string("^" + source + "$"), "keys": keys, "base": clean, "text": source}


# ---------------------------------------------------------- normalising --

## [param text] as both sides are compared: reminder text gone, the card's
## name and "this creature" as "~", lower case, number words as digits,
## the old wordings as the generator's, no final stop.
static func norm(text: String, name: String) -> String:
	var out := _strip_reminders(text)
	if name != "":
		out = out.replace(name, "~")
	out = out.to_lower().replace("’", "'").replace("“", "\"").replace("”", "\"")
	for pair in SYNONYMS:
		out = out.replace(String(pair[0]), String(pair[1]))
	# "gains flying until end of turn" is the generator's "has flying …".
	if out.contains(" gain"):
		for k in CommunityCard.KEYWORD_WORDS:
			var word := String(CommunityCard.KEYWORD_WORDS[k])
			out = out.replace(" gains %s until end of turn" % word, " has %s until end of turn" % word) \
				.replace(" gain %s until end of turn" % word, " have %s until end of turn" % word)
	var words := _pattern("\\b(a|an|zero|one|two|three|four|five|six|seven|eight|nine|ten)\\b")
	var shown := ""
	var from := 0
	for hit in words.search_all(out):
		shown += out.substr(from, hit.get_start() - from) + String(_NUMBERS[hit.get_string()])
		from = hit.get_end()
	out = shown + out.substr(from)
	out = _pattern("\\b(card|token|counter)s\\b").sub(out, "$1", true)
	out = _pattern("\\s+").sub(out, " ", true).strip_edges()
	# Two effects are joined "… and …" by the generator, "…, then …" by some cards.
	if out.count(", then ") == 1:
		out = out.replace(", then ", " and ")
	while out.ends_with("."):
		out = out.left(out.length() - 1)
	return out.replace(".\"", "\"")


static func _strip_reminders(text: String) -> String:
	return _pattern("\\s*\\([^)]*\\)").sub(text, "", true)


## The sentences of [param line] (a quoted ability stays whole).
static func _sentences(line: String) -> Array[String]:
	var out: Array[String] = []
	var piece := ""
	var quoted := false
	for n in line.length():
		var ch := line[n]
		if ch == "\"":
			quoted = not quoted
		piece += ch
		if ch == "." and not quoted and (n + 1 >= line.length() or line[n + 1] == " "):
			if piece.strip_edges() != "":
				out.append(piece.strip_edges())
			piece = ""
	if piece.strip_edges() != "":
		out.append(piece.strip_edges())
	return out


## The parts of a line of keywords ("Flying, first strike"); the line
## itself when it is no such list.
static func _keyword_parts(line: String) -> Array[String]:
	var out: Array[String] = []
	if line.contains(":") or line.contains("\""):
		out.append(line)
		return out
	for part in line.replace(";", ",").split(","):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out


static func _pattern(source: String) -> RegEx:
	if not _rx.has(source):
		_rx[source] = RegEx.create_from_string(source)
	return _rx[source]
