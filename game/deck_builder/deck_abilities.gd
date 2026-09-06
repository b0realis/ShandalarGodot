class_name DeckAbilities
## `[1997]` The ability profile behind the Deck Builder's ABILITY filter.
##
## The 1997 filter (`@ABILITY` in Menus.txt) asks two questions of a card —
## does it *natively* have an ability, and does it *give* that ability to
## something else — over a fixed list of thirteen: Flying, First strike,
## Trample, Regeneration, Banding, (Color) Ward, (Land) Walk, Poison,
## Rampage, Web, Stoning, Free Action and Quick draw. Manalink answered
## from per-card flag words; this port answers from what the card already
## carries — its keywords, its walk/protection/rampage fields, its aura
## grant — and reads the rest out of the oracle text.
##
## The text reading is deliberately narrow. A clause counts as a grant
## when its verb is `gains`/`has`/`have` and the subject is somebody else;
## the same verb with `this creature` (or the card's own name) at the head
## of the clause is native; `doesn't have`, `loses`, `without` and `if …
## has` are not grants at all. Quoted ability text ("bands with other
## Goblins", "{B}: Regenerate this permanent") is read for what it hands
## over, then stripped before the native pass so a Zombie Master does not
## regenerate himself. Every card in the pool was checked against this
## reading by hand — see `tests/ui/test_deck_abilities.gd`.
##
## Profiles are cached per card so the filter can ask 897 times a frame.

enum Ability {
	FLYING, FIRST_STRIKE, TRAMPLE, REGENERATION, BANDING, WARD, WALK,
	POISON, RAMPAGE, WEB, STONING, FREE_ACTION, QUICK_DRAW,
}

## The 1997 labels, in menu order (Menus.txt `@ABILITY`).
const LABELS := [
	"Flying", "First strike", "Trample", "Regeneration", "Banding",
	"Ward", "Walk", "Poison", "Rampage", "Web", "Stoning",
	"Free Action", "Quick draw",
]

## What the 1997 word means today, for the tooltip.
const MODERN := {
	Ability.WARD: "protection", Ability.WALK: "landwalk", Ability.WEB: "reach",
	Ability.STONING: "deathtouch", Ability.FREE_ACTION: "vigilance",
	Ability.QUICK_DRAW: "haste",
}

const ALL_MASK := (1 << 13) - 1

const _KEYWORD_BITS := {
	Mtg.Keyword.FLYING: 1 << Ability.FLYING,
	Mtg.Keyword.FIRST_STRIKE: 1 << Ability.FIRST_STRIKE,
	Mtg.Keyword.TRAMPLE: 1 << Ability.TRAMPLE,
	Mtg.Keyword.BANDING: 1 << Ability.BANDING,
	Mtg.Keyword.REACH: 1 << Ability.WEB,
	Mtg.Keyword.VIGILANCE: 1 << Ability.FREE_ACTION,
	Mtg.Keyword.HASTE: 1 << Ability.QUICK_DRAW,
}

## Words a granting clause can name, and the bit each one sets.
const _WORDS := {
	"flying": Ability.FLYING, "first strike": Ability.FIRST_STRIKE,
	"trample": Ability.TRAMPLE, "banding": Ability.BANDING,
	"protection from": Ability.WARD, "walk": Ability.WALK,
	"rampage": Ability.RAMPAGE, "reach": Ability.WEB,
	"deathtouch": Ability.STONING, "vigilance": Ability.FREE_ACTION,
	"haste": Ability.QUICK_DRAW,
}

static var _cache := {}
static var _re := {}


static func native(d: CardData) -> int:
	return _profile(d)[0]


static func gives(d: CardData) -> int:
	return _profile(d)[1]


static func clear_cache() -> void:
	_cache.clear()


static func _profile(d: CardData) -> Array:
	var key := d.get_instance_id()
	if not _cache.has(key):
		_cache[key] = _read(d)
	return _cache[key]


static func _rx(name: String, pattern: String) -> RegEx:
	if not _re.has(name):
		var re := RegEx.new()
		re.compile(pattern)
		_re[name] = re
	return _re[name]


static func _read(d: CardData) -> Array:
	var own := 0
	var given := 0
	for keyword in d.keywords:
		own |= _KEYWORD_BITS.get(keyword, 0)
	if d.protection_from != 0:
		own |= 1 << Ability.WARD
	if not d.landwalk.is_empty():
		own |= 1 << Ability.WALK
	if d.rampage > 0:
		own |= 1 << Ability.RAMPAGE
	if d.aura_grants_protection != 0:
		given |= 1 << Ability.WARD
	var text := d.oracle_text.to_lower()
	text = _rx("paren", "\\([^)]*\\)").sub(text, "", true)
	# Quoted text is an ability handed to something else: read it for what
	# it gives, then take it out of the picture for the native pass.
	for m in _rx("quote", "(gains?|has|have) (an ability |the ability )?\"([^\"]*)\"").search_all(text):
		var inner: String = m.get_string(3)
		if inner.contains("bands with"):
			given |= 1 << Ability.BANDING
		if inner.contains("regenerate"):
			given |= 1 << Ability.REGENERATION
		if inner.contains("poison"):
			given |= 1 << Ability.POISON
		for sentence in _sentences(inner):
			for grant in _grants(sentence, "\u0001"):
				given |= grant[1]
	text = _rx("unquote", "\"[^\"]*\"").sub(text, "", true)
	var self_name := d.card_name.to_lower()
	# Two cards phrase a native ability sideways. Gabriel Angelfire:
	# "choose flying, first strike, trample, or rampage 3. Gabriel
	# Angelfire gains that ability" — fold the choice into the grant.
	# Primal Clay: "it becomes your choice of … a 2/2 artifact creature
	# with flying" — a shape it can take is an ability it can have.
	text = _rx("choose", "choose ([^.]*)\\. (\\S[^.]*?) gains that ability").sub(text, "$2 gains $1", true)
	text = _rx("becomes", "\\b(it|this creature) becomes ([^.]*)").sub(text, "this creature gains $2", true)
	for sentence in _sentences(text):
		for grant in _grants(sentence, self_name):
			if grant[0]:
				own |= grant[1]
			else:
				given |= grant[1]
		# Regeneration is a verb on these cards, never a keyword.
		if _rx("regen_self", "regenerate (this creature|this permanent|it)\\b").search(sentence) != null:
			own |= 1 << Ability.REGENERATION
		if _rx("regen_other", "regenerate (target|enchanted|another|each|all|any)\\b").search(sentence) != null:
			given |= 1 << Ability.REGENERATION
		# Old-style "{1}: First strike until end of turn" on the card itself.
		var old_style := _rx("old_style", ": (first strike|flying|trample|banding) until end of turn").search(sentence)
		if old_style != null:
			own |= 1 << _WORDS[old_style.get_string(1)]
		# Stoning: destroys what it fights.
		if _rx("stone_self", "whenever this creature blocks or becomes blocked by [^,]*, destroy (that|the other) creature").search(sentence) != null:
			own |= 1 << Ability.STONING
		if _rx("stone_other", "whenever enchanted creature blocks or becomes blocked by [^,]*, destroy").search(sentence) != null:
			given |= 1 << Ability.STONING
		# Poison outside quotes is the card's own sting.
		if _rx("poison_self", "this creature deals damage to a player, that player gets").search(sentence) != null \
			and sentence.contains("poison"):
			own |= 1 << Ability.POISON
		# Free Action and Quick draw spelled out in prose.
		var no_tap := _rx("no_tap", "attacking doesn't cause ([^.]*) to tap").search(sentence)
		if no_tap != null:
			var who: String = no_tap.get_string(1)
			if who.begins_with("this creature") or who.begins_with(self_name):
				own |= 1 << Ability.FREE_ACTION
			else:
				given |= 1 << Ability.FREE_ACTION
		var as_though := _rx("as_though", "as though (it|they) had (\\w+)").search(sentence)
		if as_though != null and _WORDS.has(as_though.get_string(2)):
			given |= 1 << _WORDS[as_though.get_string(2)]
	return [own, given]


## Every `gains`/`has`/`have` clause of one sentence that names an ability,
## as `[is_native, bits]`. The subject runs from the last clause boundary
## to the verb; the clause runs from the verb to the next verb or the end of
## the sentence, so "gets +2/+0 and gains trample" and "your choice of
## banding, flying, first strike, or trample" both read whole.
static func _grants(sentence: String, self_name: String) -> Array:
	var found := []
	var verbs := _rx("verb", "\\b(gains?|has|have)\\b").search_all(sentence)
	for i in verbs.size():
		var verb: RegExMatch = verbs[i]
		var clause_end: int = verbs[i + 1].get_start() if i + 1 < verbs.size() else sentence.length()
		var bits := _named(sentence.substr(verb.get_end(), clause_end - verb.get_end()))
		if bits == 0:
			continue
		var before := sentence.left(verb.get_start())
		var boundary := maxi(maxi(before.rfind(", "), before.rfind(": ")), before.rfind("; "))
		var subject := before.substr(boundary + 2 if boundary >= 0 else 0).strip_edges()
		if subject.begins_with("if ") or subject.begins_with("unless ") or subject.contains("n't") \
			or subject.contains("without") or subject.contains("lose"):
			continue
		var own := subject.begins_with("this creature") or subject.begins_with("this permanent") \
			or subject.begins_with("this artifact") or subject.begins_with(self_name) \
			or (subject == "it" and (sentence.contains("this creature") or sentence.contains(self_name)))
		found.append([own, bits])
	return found


static func _sentences(text: String) -> PackedStringArray:
	return _rx("sentence", "\\.\\s+|\\s/\\s").sub(text, "\n", true).split("\n", false)


## The abilities a clause names, as a bit mask.
static func _named(clause: String) -> int:
	var bits := 0
	for word in _WORDS:
		if word == "walk":
			if _rx("walk", "\\b\\w*walk\\b").search(clause) != null:
				bits |= 1 << Ability.WALK
		elif clause.contains(word):
			bits |= 1 << _WORDS[word]
	return bits
