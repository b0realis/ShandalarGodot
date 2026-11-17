class_name CommunityCard
extends RefCounted
## A CARD A PLAYER MADE — plain data, built here into a [CardData] from the
## engine's own pieces: its keywords and card rules (echo, cycling,
## cumulative upkeep, buyback, rampage, …), the stock effects of
## engine/effects, [ActivatedAbility], [ManaAbility], and trusted adapters
## for the triggers and statics a stock effect cannot express alone — the
## mechanics of every set the game has, the Urza block included. Nothing a
## player writes is ever run: a spec names blocks from [constant EFFECTS],
## [constant TRIGGERS], [constant STATICS] and [constant CARD_RULES], with
## numbers and choices.
##
## THE RULES TEXT IS WRITTEN HERE ([method rules_text]) from the same
## blocks the card is built from, so a card never says one thing and does
## another; the flavor is the player's own words, apart.
##
## A spec is checked first ([method problems]) and built only whole. The
## registry builds every community card again on each rebuild
## ([method CardRegistry.configure_community]) and nothing here keeps a
## [CardData] (the registry's rule about static state).

const FORMAT := "shandalar-community-card"
const VERSION := 1
## The set every community card is shown in.
const SET_CODE := "comm"
const SET_NAME := "Community cards"

const TYPES := {
	"creature": Mtg.CardType.CREATURE, "artifact": Mtg.CardType.ARTIFACT,
	"enchantment": Mtg.CardType.ENCHANTMENT, "instant": Mtg.CardType.INSTANT,
	"sorcery": Mtg.CardType.SORCERY, "land": Mtg.CardType.LAND,
}
const PERMANENTS := ["creature", "artifact", "enchantment", "land"]
const KEYWORDS := {
	"flying": Mtg.Keyword.FLYING, "first_strike": Mtg.Keyword.FIRST_STRIKE,
	"trample": Mtg.Keyword.TRAMPLE, "haste": Mtg.Keyword.HASTE,
	"vigilance": Mtg.Keyword.VIGILANCE, "reach": Mtg.Keyword.REACH,
	"defender": Mtg.Keyword.DEFENDER, "fear": Mtg.Keyword.FEAR,
	"flash": Mtg.Keyword.FLASH, "unblockable": Mtg.Keyword.UNBLOCKABLE,
	"banding": Mtg.Keyword.BANDING, "flanking": Mtg.Keyword.FLANKING,
	"shadow": Mtg.Keyword.SHADOW, "phasing": Mtg.Keyword.PHASING,
	"must_attack": Mtg.Keyword.MUST_ATTACK,
}
## How each keyword is printed.
const KEYWORD_WORDS := {
	"flying": "flying", "first_strike": "first strike", "trample": "trample",
	"haste": "haste", "vigilance": "vigilance", "reach": "reach",
	"defender": "defender", "fear": "fear", "flash": "flash",
	"unblockable": "unblockable", "banding": "banding", "flanking": "flanking",
	"shadow": "shadow", "phasing": "phasing", "must_attack": "attacks each combat if able",
}
const COLORS := {
	"white": Mtg.ManaColor.W, "blue": Mtg.ManaColor.U, "black": Mtg.ManaColor.B,
	"red": Mtg.ManaColor.R, "green": Mtg.ManaColor.G, "colorless": 0,
}
## The colors mana is made in — colorless is {C} here, not "no color".
const MANA_COLORS := {
	"white": Mtg.ManaColor.W, "blue": Mtg.ManaColor.U, "black": Mtg.ManaColor.B,
	"red": Mtg.ManaColor.R, "green": Mtg.ManaColor.G, "colorless": Mtg.ManaColor.C,
}
const MANA_SYMBOLS := {"white": "{W}", "blue": "{U}", "black": "{B}", "red": "{R}",
	"green": "{G}", "colorless": "{C}"}
const PROTECTIONS := ["white", "blue", "black", "red", "green"]
## The basic land types and the color each taps for.
const BASIC_COLORS := {"plains": "white", "island": "blue", "swamp": "black", "mountain": "red", "forest": "green"}
const LANDS := ["plains", "island", "swamp", "mountain", "forest"]
const RARITIES := ["common", "uncommon", "rare", "mythic"]
const BORDERS := ["black", "white", "silver"]
const FRAMES := ["auto", "white", "blue", "black", "red", "green", "gold", "artifact", "land"]
const SPELL_TYPES := ["creature", "artifact", "enchantment", "instant", "sorcery"]

## CARD RULES — what a card is, beside its abilities: `kind` "flag", an
## "amount" in `range`, or a mana "cost"; `types` the cards it fits (none:
## every card).
const CARD_RULES := {
	"echo": {"label": "Echo", "kind": "cost", "types": PERMANENTS,
		"tip": "At the beginning of your upkeep after it arrives, pay this again or sacrifice it."},
	"cycling": {"label": "Cycling", "kind": "cost", "types": [],
		"tip": "Pay this and discard the card from your hand: draw a card."},
	"cumulative_upkeep": {"label": "Cumulative upkeep", "kind": "cost", "types": PERMANENTS,
		"tip": "Each upkeep it gains an age counter; pay this once per counter or sacrifice it."},
	"buyback": {"label": "Buyback", "kind": "cost", "types": ["instant", "sorcery"],
		"tip": "Pay this more as you cast it and the spell returns to your hand."},
	"rampage": {"label": "Rampage", "kind": "amount", "range": [1, 5], "types": ["creature"],
		"tip": "Whenever it becomes blocked, it gets +N/+N for each blocker beyond the first."},
	"enters_tapped": {"label": "Enters tapped", "kind": "flag", "types": PERMANENTS},
	"enters_counters": {"label": "Enters with +1/+1 counters", "kind": "amount", "range": [1, 5],
		"types": ["creature"]},
	"cant_be_countered": {"label": "Can't be countered", "kind": "flag", "types": SPELL_TYPES},
	"cant_block": {"label": "Can't block", "kind": "flag", "types": ["creature"]},
	"no_walls": {"label": "Can't be blocked by Walls", "kind": "flag", "types": ["creature"]},
	"extra_blocks": {"label": "Blocks additional creatures", "kind": "amount", "range": [1, 3],
		"types": ["creature"]},
	"extra_life": {"label": "Additional cost: pay life", "kind": "amount", "range": [1, 10], "types": SPELL_TYPES},
	"upkeep_cost": {"label": "Upkeep: pay or sacrifice", "kind": "cost", "types": PERMANENTS,
		"tip": "At the beginning of your upkeep, sacrifice it unless you pay this."},
}
## What an activated ability may sacrifice besides the card itself.
const SACRIFICES := {"creature": "a creature", "land": "a land", "artifact": "an artifact"}
## What an Aura may enchant.
const ENCHANTS := ["creature", "land", "artifact", "permanent"]
## The colors a mana ability makes: one color, colorless, or any color.
const MANA_CHOICES := ["white", "blue", "black", "red", "green", "colorless", "any"]
## Modes of a "Choose one —" spell.
const MODES := [2, 4]
## When an activated ability may be used.
const TIMINGS := {
	"any": {"label": "Any time"},
	"your_turn": {"label": "Only during your turn"},
	"once": {"label": "Only once each turn"},
	"combat": {"label": "Only during combat"},
}
## What a triggered ability waits for.
const TRIGGERS := {
	"enters": "When CARDNAME enters the battlefield",
	"dies": "When CARDNAME dies",
	"leaves": "When CARDNAME leaves the battlefield",
	"upkeep": "At the beginning of your upkeep",
	"each_upkeep": "At the beginning of each upkeep",
	"end_step": "At the beginning of your end step",
	"attacks": "Whenever CARDNAME attacks",
	"blocks": "Whenever CARDNAME blocks",
	"blocked": "Whenever CARDNAME becomes blocked",
	"unblocked": "Whenever CARDNAME attacks and isn't blocked",
	"combat_damage_player": "Whenever CARDNAME deals combat damage to a player",
	"you_cast": "Whenever you cast a spell",
	"you_cast_creature": "Whenever you cast a creature spell",
	"opponent_casts": "Whenever an opponent casts a spell",
	"creature_enters": "Whenever another creature enters the battlefield under your control",
	"creature_dies": "Whenever a creature dies",
	"land_enters": "Whenever a land enters the battlefield under your control",
}
## The triggers only a creature can have.
const CREATURE_TRIGGERS := ["dies", "attacks", "blocks", "blocked", "unblocked", "combat_damage_player"]
## The static abilities offered (beside keywords, protection, landwalk).
const STATICS := {
	"anthem": {"label": "Creatures you control get +P/+T", "pt": true},
	"anthem_others": {"label": "Other creatures you control get +P/+T", "pt": true},
	"lord": {"label": "Other creatures of a type you control get +P/+T", "pt": true, "subtype": true},
	"tribe": {"label": "All creatures of a type get +P/+T", "pt": true, "subtype": true},
	"opponents": {"label": "Creatures your opponents control get +P/+T", "pt": true},
	"all": {"label": "All creatures get +P/+T", "pt": true},
	"cost_less": {"label": "Your spells of a type cost less", "pt": false, "spell_type": true,
		"amount": [1, 3]},
}

## THE EFFECTS a spell, an ability or a trigger may do: each one's label,
## its amount (range), whether it may be the X paid (`x`), its targets (the
## first is the default; "self" is the card itself, never a spell's),
## +P/+T, keywords, a color, a token.
const EFFECTS := {
	"damage": {"label": "Deal damage", "amount": [1, 20], "x": true,
		"targets": ["any", "creature", "creature_attacking", "creature_flying", "player", "opponent",
			"each_opponent", "each_creature", "each_creature_and_player"]},
	"draw": {"label": "Draw cards", "amount": [1, 7], "x": true, "targets": ["you", "player"]},
	"gain_life": {"label": "Gain life", "amount": [1, 20], "x": true, "targets": ["you", "player"]},
	"lose_life": {"label": "Lose life", "amount": [1, 20], "targets": ["opponent", "player", "each_opponent"]},
	"drain": {"label": "Drain life", "amount": [1, 20], "targets": ["opponent", "each_opponent"]},
	"destroy": {"label": "Destroy", "targets": ["creature", "creature_nonblack", "creature_nonartifact",
		"creature_flying", "creature_attacking", "creature_tapped", "artifact", "enchantment",
		"artifact_or_enchantment", "land", "nonbasic_land", "permanent"]},
	"destroy_all": {"label": "Destroy all", "targets": ["creatures", "creatures_flying", "artifacts",
		"enchantments", "lands"]},
	"exile": {"label": "Exile", "targets": ["creature", "creature_attacking", "permanent"]},
	"bounce": {"label": "Return to hand", "targets": ["creature", "artifact", "enchantment", "land", "permanent"]},
	"pump": {"label": "Give +P/+T", "pt": true, "keywords": true, "x": true, "targets": ["creature", "self"]},
	"mass_pump": {"label": "Give +P/+T to many", "pt": true, "keywords": true, "targets": ["yours", "all"]},
	"counters": {"label": "Put +1/+1 counters", "amount": [1, 5], "targets": ["creature", "self"]},
	"minus_counters": {"label": "Put -1/-1 counters", "amount": [1, 5], "targets": ["creature"]},
	"counter": {"label": "Counter", "unless": [0, 4], "targets": ["spell", "creature_spell", "noncreature_spell"]},
	"counter_ability": {"label": "Counter an activated ability", "unless": [0, 4], "targets": ["ability"]},
	"token": {"label": "Create creature tokens", "amount": [1, 5], "token": true, "keywords": true},
	"add_mana": {"label": "Add mana", "amount": [1, 5], "color": true},
	"mill": {"label": "Mill", "amount": [1, 20], "targets": ["player", "opponent"]},
	"discard": {"label": "Discard (chosen)", "amount": [1, 7], "targets": ["opponent", "player"]},
	"discard_random": {"label": "Discard at random", "amount": [1, 7], "targets": ["opponent", "player"]},
	"sacrifice": {"label": "Sacrifice a creature", "targets": ["opponent", "player"]},
	"steal": {"label": "Gain control", "targets": ["creature", "artifact"]},
	"search_basic": {"label": "Search for a basic land", "targets": ["to_hand", "to_battlefield"]},
	"tap": {"label": "Tap", "targets": ["creature", "artifact", "land", "permanent"]},
	"untap": {"label": "Untap", "targets": ["creature", "land", "permanent"]},
	"regenerate": {"label": "Regenerate", "targets": ["self", "creature"]},
	"prevent": {"label": "Prevent damage", "amount": [1, 20], "x": true, "targets": ["any", "creature"]},
	"fog": {"label": "Prevent all combat damage"},
	"raise": {"label": "Return a creature card", "targets": ["creature_card"]},
	"extra_turn": {"label": "Take an extra turn"},
	"shield": {"label": "Prevent damage from a color", "shield": true},
	"set_pt": {"label": "Set base power/toughness", "base": true, "targets": ["creature", "self"]},
	"switch_pt": {"label": "Switch power and toughness", "targets": ["creature", "self"]},
	"landwalk": {"label": "Give landwalk", "land": true, "targets": ["creature", "self"]},
	"lose_keyword": {"label": "Lose a keyword", "lose": true, "targets": ["creature"]},
	"animate": {"label": "Become a creature", "base": true, "subtype": true},
	"draw_later": {"label": "Draw cards next upkeep", "amount": [1, 3]},
	"search": {"label": "Search for a card", "targets": ["a_creature", "an_artifact", "an_enchantment",
		"a_land", "a_card"]},
}
## The keywords that hinder the creature that has them.
const HINDERING := ["defender", "must_attack"]
## Effects a triggered ability may not use.
const NOT_IN_TRIGGERS := ["counter", "fog", "counter_ability", "shield", "animate"]
## Effects only an activated ability may use (a land or an artifact
## becoming a creature for the turn).
const ACTIVATED_ONLY := ["animate"]
## The effects that help what they target (a trigger offers its own side
## first for these, the opponent's first for the rest — the computer takes
## the first).
const HELPFUL := ["pump", "counters", "regenerate", "untap", "draw", "gain_life", "prevent", "landwalk"]
## How each target is said.
const TARGET_WORDS := {"any": "any target", "creature": "target creature",
	"creature_attacking": "target attacking creature", "creature_flying": "target creature with flying",
	"creature_nonblack": "target nonblack creature", "creature_nonartifact": "target nonartifact creature",
	"creature_tapped": "target tapped creature", "player": "target player", "opponent": "target opponent",
	"each_opponent": "each opponent", "each_creature": "each creature",
	"each_creature_and_player": "each creature and each player", "you": "you",
	"artifact": "target artifact", "enchantment": "target enchantment",
	"artifact_or_enchantment": "target artifact or enchantment", "land": "target land",
	"nonbasic_land": "target nonbasic land", "permanent": "target permanent",
	"creatures": "creatures", "creatures_flying": "creatures with flying", "artifacts": "artifacts",
	"enchantments": "enchantments", "lands": "lands", "self": "this card", "yours": "creatures you control",
	"all": "all creatures", "spell": "target spell", "creature_spell": "target creature spell",
	"noncreature_spell": "target noncreature spell",
	"creature_card": "target creature card in your graveyard", "to_hand": "put it into your hand",
	"to_battlefield": "put it onto the battlefield", "ability": "target activated ability",
	"a_creature": "a creature card", "an_artifact": "an artifact card", "an_enchantment": "an enchantment card",
	"a_land": "a land card", "a_card": "a card"}

const LIMITS := {"abilities": 6, "effects": 4, "name": 40, "artist": 60, "set_name": 40,
	"flavor": 200, "subtypes": 3, "subtype": 20, "power": [0, 99], "pt_change": [-10, 10]}


# --------------------------------------------------------- the catalogue --

static func target_words(target: String) -> String:
	return String(TARGET_WORDS.get(target, target.replace("_", " ")))


static func static_info(what: String) -> Dictionary:
	return STATICS.get(what, {})


## Whether the effect [param id] is offered in an ability of [param kind]
## (a mode of a "Choose one —" spell is a "spell").
static func effect_allowed(id: String, kind: String) -> bool:
	return EFFECTS.has(id) and not (kind == "trigger" and id in NOT_IN_TRIGGERS) \
		and not (kind != "activated" and id in ACTIVATED_ONLY)


## A fresh effect of [param id] for an ability of [param kind].
static func effect_defaults(id: String, kind: String) -> Dictionary:
	var info: Dictionary = EFFECTS.get(id, {})
	var e := {"effect": id}
	if info.has("amount"):
		e["amount"] = maxi(1, int(info["amount"][0]))
	if info.has("targets"):
		var targets: Array = info["targets"]
		e["target"] = targets[1] if kind == "spell" and targets[0] == "self" and targets.size() > 1 else targets[0]
	if info.has("pt"):
		e["power"] = 1
		e["toughness"] = 1
	if info.has("color"):
		e["color"] = "green"
	if info.has("token"):
		e.merge({"power": 1, "toughness": 1, "color": "colorless", "subtype": "soldier"}, true)
	if info.has("base"):
		e.merge({"power": 2, "toughness": 2}, true)
	if info.has("land"):
		e["land"] = "island"
	if info.has("lose"):
		e["keywords"] = ["flying"]
	if info.has("shield"):
		e["color"] = "red"
	return e


# ------------------------------------------------------------- checking --

## Every reason [param spec] cannot be a card, one a line ([] when it can).
static func problems(spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if not spec is Dictionary:
		out.append("The card is not a JSON object.")
		return out
	var s: Dictionary = spec
	# THE SHAPE FIRST: a field of the wrong kind is a problem, never a crash
	# (a spec from a shared zip is untrusted), and nothing below reads one.
	out.append_array(_shape_problems(s))
	if not out.is_empty():
		return out
	if String(s.get("format", "")) != FORMAT:
		out.append("format must be \"%s\"." % FORMAT)
	if int(s.get("version", 0)) < 1 or int(s.get("version", 0)) > VERSION:
		out.append("version must be 1 to %d." % VERSION)
	var name := String(s.get("name", "")).strip_edges()
	if name == "" or name.length() > LIMITS["name"]:
		out.append("The name must be 1 to %d characters." % LIMITS["name"])
	elif not _name_ok(name):
		out.append("The name may hold letters, digits, spaces and ' , - only.")
	var types := _list(s.get("types"))
	if types.is_empty():
		out.append("Choose at least one card type.")
	for t in types:
		if not TYPES.has(t):
			out.append("Unknown card type \"%s\"." % t)
	var spell_like := types.has("instant") or types.has("sorcery")
	if spell_like and types.size() > 1:
		out.append("An instant or a sorcery is that alone.")
	if types.has("land") and types.any(func(t: String) -> bool: return t != "land" and t != "artifact"):
		out.append("A land is a land (or an artifact land) only.")
	var cost := String(s.get("cost", ""))
	if types.has("land"):
		if cost != "":
			out.append("A land has no mana cost.")
	elif not cost_ok(cost):
		out.append("The mana cost is like {2}{R}: numbers and W U B R G X, at most 16 mana.")
	if types.has("creature"):
		for key in ["power", "toughness"]:
			var v: Variant = s.get(key)
			if not (v is int or v is float) or int(v) < LIMITS["power"][0] or int(v) > LIMITS["power"][1]:
				out.append("A creature's %s is a number from 0 to 99." % key)
	if not RARITIES.has(String(s.get("rarity", "common"))):
		out.append("The rarity is common, uncommon, rare or mythic.")
	for key in ["artist", "set_name", "flavor"]:
		if String(s.get(key, "")).length() > int(LIMITS[key]):
			out.append("The %s is at most %d characters." % [key.replace("_", " "), LIMITS[key]])
	var subs := _list(s.get("subtypes"))
	if subs.size() > LIMITS["subtypes"]:
		out.append("At most %d subtypes." % LIMITS["subtypes"])
	for sub in subs:
		if not _word_ok(sub):
			out.append("A subtype is one word of letters (\"%s\")." % sub)
	if not subs.is_empty() and not types.has("creature") and not types.has("land"):
		out.append("Only a creature or a land has subtypes here.")
	for sup in _list(s.get("supertypes")):
		if sup != "legendary":
			out.append("The only supertype offered is legendary.")
	for k in _list(s.get("keywords")):
		if not KEYWORDS.has(k):
			out.append("Unknown keyword \"%s\"." % k)
	if not _list(s.get("keywords")).is_empty() and not types.has("creature"):
		out.append("Keywords are for creatures.")
	for c in _list(s.get("protection")):
		if not PROTECTIONS.has(c):
			out.append("Protection is from white, blue, black, red or green.")
	for l in _list(s.get("landwalk")):
		if not LANDS.has(l):
			out.append("Landwalk is plainswalk, islandwalk, swampwalk, mountainwalk or forestwalk.")
	_look_problems(out, s.get("look", {}))
	_rule_problems(out, s.get("rules", {}), types)
	var abilities: Variant = s.get("abilities", [])
	if not abilities is Array:
		out.append("abilities must be a list.")
		return out
	if (abilities as Array).size() > LIMITS["abilities"]:
		out.append("At most %d abilities." % LIMITS["abilities"])
	var spells := 0
	var modals := 0
	var auras := 0
	for i in (abilities as Array).size():
		var a: Variant = abilities[i]
		var where := "Ability %d: " % (i + 1)
		if not a is Dictionary:
			out.append(where + "not an object.")
			continue
		var kind := String(a.get("kind", ""))
		match kind:
			"spell":
				spells += 1
				if not spell_like:
					out.append(where + "only an instant or a sorcery has a spell effect.")
				_effects_problems(out, where, a.get("effects"), "spell", cost.contains("{X}"), types.has("creature"))
			"modal":
				modals += 1
				if not spell_like:
					out.append(where + "only an instant or a sorcery is a \"Choose one\" spell.")
				var modes: Variant = a.get("modes", [])
				if not modes is Array or (modes as Array).size() < MODES[0] or (modes as Array).size() > MODES[1]:
					out.append(where + "a \"Choose one\" spell has %d to %d modes." % [MODES[0], MODES[1]])
				elif modes is Array:
					for m in (modes as Array).size():
						var mode: Variant = modes[m]
						_effects_problems(out, "%smode %d: " % [where, m + 1],
							mode.get("effects") if mode is Dictionary else null, "spell", cost.contains("{X}"),
							types.has("creature"))
			"activated":
				if spell_like:
					out.append(where + "an instant or a sorcery has no activated ability.")
				var a_cost := String(a.get("cost", ""))
				if not cost_ok(a_cost, true):
					out.append(where + "the cost is like {1}{R} (or nothing with {T}).")
				var sac := String(a.get("sacrifice_what", ""))
				if sac != "" and not SACRIFICES.has(sac):
					out.append(where + "it sacrifices a creature, a land or an artifact.")
				var discard := int(a.get("discard", 0))
				if discard < 0 or discard > 2:
					out.append(where + "it discards 0 to 2 cards.")
				var shared := String(a.get("shared", ""))
				if shared != "" and not _word_ok(shared):
					out.append(where + "name the creature type that shares it, one word.")
				var removes := int(a.get("remove_counters", 0))
				if removes < 0 or removes > 3:
					out.append(where + "it removes 0 to 3 +1/+1 counters.")
				elif removes > 0 and not types.has("creature") and shared == "":
					out.append(where + "removing +1/+1 counters is for a creature.")
				var free := a_cost == "" or (cost_ok(a_cost) and not a_cost.contains("{X}")
					and ManaCost.parse(a_cost).mana_value() == 0)
				if free and not bool(a.get("tap", false)) \
						and not bool(a.get("sacrifice", false)) and int(a.get("life", 0)) <= 0 \
						and sac == "" and discard <= 0 and removes <= 0:
					out.append(where + "an ability needs a cost.")
				if int(a.get("life", 0)) < 0 or int(a.get("life", 0)) > 20:
					out.append(where + "the life it costs is 0 to 20.")
				if not TIMINGS.has(String(a.get("timing", "any"))):
					out.append(where + "unknown timing.")
				# A shared ability is the creature's that has it: its "self"
				# is a creature, and it never animates the card.
				_effects_problems(out, where, a.get("effects"), "activated", a_cost.contains("{X}"),
					types.has("creature") or shared != "")
				for e in a.get("effects", []) if a.get("effects") is Array else []:
					if e is Dictionary and String(e.get("effect", "")) == "animate" \
							and (types.has("creature") or shared != "" or _has_kind(s, "enchant")):
						out.append(where + "\"Become a creature\" is for a land, an artifact or an enchantment that is not an Aura.")
			"mana":
				if spell_like:
					out.append(where + "an instant or a sorcery makes no mana.")
				if not MANA_CHOICES.has(String(a.get("color", ""))):
					out.append(where + "choose the mana's color.")
				if int(a.get("amount", 1)) < 1 or int(a.get("amount", 1)) > 3:
					out.append(where + "a mana ability makes 1 to 3 mana.")
				var m_cost := String(a.get("cost", ""))
				if not cost_ok(m_cost, true) or m_cost.contains("{X}"):
					out.append(where + "the mana ability's cost is like {1} (or nothing).")
				if int(a.get("pain", 0)) < 0 or int(a.get("pain", 0)) > 2:
					out.append(where + "the damage it deals you is 0 to 2.")
			"trigger":
				if spell_like:
					out.append(where + "an instant or a sorcery has no triggered ability.")
				var when := String(a.get("when", ""))
				if not TRIGGERS.has(when):
					out.append(where + "choose when it triggers.")
				elif when in CREATURE_TRIGGERS and not types.has("creature"):
					out.append(where + "only a creature has \"%s\"." % String(TRIGGERS[when]).replace("CARDNAME", "it"))
				_effects_problems(out, where, a.get("effects"), "trigger", false, types.has("creature"))
			"static":
				if spell_like:
					out.append(where + "an instant or a sorcery has no static ability.")
				var what := String(a.get("what", ""))
				if not STATICS.has(what):
					out.append(where + "choose the static ability.")
					continue
				var info: Dictionary = STATICS[what]
				if info.get("pt", false):
					_pt_problems(out, where, a)
				if info.get("subtype", false) and not _word_ok(String(a.get("subtype", ""))):
					out.append(where + "name the creature type, one word.")
				if info.get("spell_type", false) and not SPELL_TYPES.has(String(a.get("spell_type", ""))):
					out.append(where + "choose the spell type.")
				if info.has("amount"):
					var n := int(a.get("amount", 1))
					if n < int(info["amount"][0]) or n > int(info["amount"][1]):
						out.append(where + "it costs {1} to {3} less.")
				for k in _list(a.get("keywords")):
					if not KEYWORDS.has(k):
						out.append(where + "unknown keyword \"%s\"." % k)
				if _list(a.get("keywords")).has("flash"):
					out.append(where + "flash means nothing on a card already in play.")
			"enchant":
				auras += 1
				if not types.has("enchantment") or types.size() > 1:
					out.append(where + "only an enchantment is an Aura.")
				_pt_problems(out, where, a)
				for k in _list(a.get("keywords")):
					if not KEYWORDS.has(k):
						out.append(where + "unknown keyword \"%s\"." % k)
				if _list(a.get("keywords")).has("flash"):
					out.append(where + "flash means nothing on a card already in play.")
				var host := String(a.get("enchant", "creature"))
				var ward := String(a.get("protection", ""))
				if not ENCHANTS.has(host):
					out.append(where + "an Aura enchants a creature, a land, an artifact or a permanent.")
				elif host != "creature" and (int(a.get("power", 0)) != 0 or int(a.get("toughness", 0)) != 0
						or not _list(a.get("keywords")).is_empty() or bool(a.get("pacify", false)) or ward != ""):
					out.append(where + "+P/+T, keywords, protection and \"can't attack or block\" are for an Aura on a creature.")
				if ward != "" and not PROTECTIONS.has(ward):
					out.append(where + "protection is from white, blue, black, red or green.")
				if int(a.get("power", 0)) == 0 and int(a.get("toughness", 0)) == 0 \
						and _list(a.get("keywords")).is_empty() and ward == "" \
						and not bool(a.get("control", false)) and not bool(a.get("pacify", false)) \
						and not bool(a.get("frozen", false)):
					out.append(where + "choose what the Aura does.")
			_:
				out.append(where + "unknown kind \"%s\"." % kind)
	if spell_like and spells + modals == 0:
		out.append("An instant or a sorcery needs a spell effect.")
	if modals > 1 or (modals == 1 and spells > 0):
		out.append("A \"Choose one\" spell has its modes and nothing else.")
	if modals > 0 and (s.get("rules", {}) as Dictionary).has("buyback"):
		out.append("Buyback is not offered on a \"Choose one\" spell.")
	if auras > 1:
		out.append("An Aura enchants one thing: one Aura ability.")
	return out


## How each kind of field is said in a problem.
const _KIND_WORDS := {"text": "text", "whole": "a whole number", "number": "a number",
	"yes": "true or false", "object": "an object", "list": "a list (at most 64)",
	"words": "a list of words (at most 64)"}


## THE SHAPE of a spec: every field the JSON kind it must be (text, a whole
## number, true/false, an object, a list of words), before anything reads
## it — a spec from a shared zip is untrusted.
static func _shape_problems(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	_want(out, s, "format", "text")
	_want(out, s, "version", "whole")
	_want(out, s, "name", "text")
	_want(out, s, "types", "words")
	_want(out, s, "cost", "text", true)
	for key in ["supertypes", "subtypes", "keywords", "protection", "landwalk"]:
		_want(out, s, key, "words", true)
	for key in ["power", "toughness"]:
		_want(out, s, key, "whole", true)
	for key in ["rarity", "artist", "set_name", "flavor"]:
		_want(out, s, key, "text", true)
	if _want(out, s, "look", "object", true):
		var look: Dictionary = s["look"]
		_want(out, look, "border", "text", true, "look.")
		_want(out, look, "frame", "text", true, "look.")
		if _want(out, look, "art", "object", true, "look."):
			for key in ["zoom", "x", "y"]:
				_want(out, look["art"], key, "number", true, "look.art.")
	if _want(out, s, "rules", "object", true):
		var rules: Dictionary = s["rules"]
		for id in rules:
			if CARD_RULES.has(id):
				var kind := String(CARD_RULES[id]["kind"])
				_want(out, rules, id, {"flag": "yes", "amount": "whole", "cost": "text"}[kind], false, "rules.")
	if _want(out, s, "abilities", "list", true):
		var abilities: Array = s["abilities"]
		for i in abilities.size():
			var where := "abilities[%d]." % i
			if not abilities[i] is Dictionary:
				out.append("abilities[%d] must be an object." % i)
				continue
			var a: Dictionary = abilities[i]
			_want(out, a, "kind", "text", false, where)
			for key in ["cost", "when", "color", "what", "subtype", "spell_type", "timing", "sacrifice_what",
					"shared", "enchant", "protection"]:
				_want(out, a, key, "text", true, where)
			for key in ["tap", "sacrifice", "control", "pacify", "frozen"]:
				_want(out, a, key, "yes", true, where)
			for key in ["life", "amount", "power", "toughness", "discard", "remove_counters", "pain"]:
				_want(out, a, key, "whole", true, where)
			_want(out, a, "keywords", "words", true, where)
			_effects_shape(out, a, where)
			if _want(out, a, "modes", "list", true, where):
				var modes: Array = a["modes"]
				for m in modes.size():
					if not modes[m] is Dictionary:
						out.append("%smodes[%d] must be an object." % [where, m])
						continue
					_effects_shape(out, modes[m], "%smodes[%d]." % [where, m])
	return out


static func _has_kind(s: Dictionary, kind: String) -> bool:
	var abilities: Variant = s.get("abilities", [])
	return abilities is Array and (abilities as Array).any(func(a: Variant) -> bool:
		return a is Dictionary and String(a.get("kind", "")) == kind)


## The shape of the `effects` list of [param holder] (an ability or a mode).
static func _effects_shape(out: Array[String], holder: Dictionary, where: String) -> void:
	if not _want(out, holder, "effects", "list", true, where):
		return
	var effects: Array = holder["effects"]
	for j in effects.size():
		var at := "%seffects[%d]." % [where, j]
		if not effects[j] is Dictionary:
			out.append("%seffects[%d] must be an object." % [where, j])
			continue
		var e: Dictionary = effects[j]
		_want(out, e, "effect", "text", false, at)
		for key in ["target", "color", "subtype", "land"]:
			_want(out, e, key, "text", true, at)
		for key in ["amount", "power", "toughness", "unless"]:
			_want(out, e, key, "whole", true, at)
		_want(out, e, "x", "yes", true, at)
		_want(out, e, "keywords", "words", true, at)


## Whether [param holder]'s [param key] is of [param kind] (a missing
## optional field is fine): false, with the problem said, when it is not.
static func _want(out: Array[String], holder: Dictionary, key: String, kind: String, optional := false,
		prefix := "") -> bool:
	if not holder.has(key):
		if not optional:
			out.append("%s%s is missing." % [prefix, key])
		return false
	var v: Variant = holder[key]
	var ok := false
	match kind:
		"text":
			ok = v is String and (v as String).length() <= 400
		"whole":
			ok = (v is int or (v is float and is_finite(v) and v == floorf(v))) and absf(float(v)) <= 1000000.0
		"number":
			ok = (v is int or (v is float and is_finite(v))) and absf(float(v)) <= 1000000.0
		"yes":
			ok = v is bool
		"object":
			ok = v is Dictionary
		"list":
			ok = v is Array and (v as Array).size() <= 64
		"words":
			ok = v is Array and (v as Array).size() <= 64 \
				and (v as Array).all(func(w: Variant) -> bool: return w is String and (w as String).length() <= 40)
	if not ok:
		out.append("%s%s must be %s." % [prefix, key, _KIND_WORDS[kind]])
	return ok


static func _look_problems(out: Array[String], look: Variant) -> void:
	if not look is Dictionary:
		return
	if not BORDERS.has(String(look.get("border", "black"))):
		out.append("The border is black, white or silver.")
	if not FRAMES.has(String(look.get("frame", "auto"))):
		out.append("Unknown frame \"%s\"." % look.get("frame"))
	var art: Variant = look.get("art", {})
	if art is Dictionary:
		if float(art.get("zoom", 1.0)) < 1.0 or float(art.get("zoom", 1.0)) > 3.0:
			out.append("The art's zoom is 100% to 300%.")
		for key in ["x", "y"]:
			if float(art.get(key, 0.5)) < 0.0 or float(art.get(key, 0.5)) > 1.0:
				out.append("The art's position is 0 to 100%.")
				break


static func _rule_problems(out: Array[String], rules: Variant, types: Array[String]) -> void:
	if rules == null:
		return
	if not rules is Dictionary:
		out.append("rules must be an object.")
		return
	for id in rules:
		if not CARD_RULES.has(id):
			out.append("Unknown card rule \"%s\"." % id)
			continue
		var info: Dictionary = CARD_RULES[id]
		var fits: Array = info.get("types", [])
		if not fits.is_empty() and not types.any(func(t: String) -> bool: return fits.has(t)):
			out.append("%s is for %s cards." % [info["label"], " or ".join(fits)])
		match String(info["kind"]):
			"flag":
				if rules[id] != true:
					out.append("%s is on (true) or left out." % info["label"])
			"amount":
				var n := int(rules[id])
				if n < int(info["range"][0]) or n > int(info["range"][1]):
					out.append("%s is %d to %d." % [info["label"], info["range"][0], info["range"][1]])
			"cost":
				if not cost_ok(String(rules[id])) or String(rules[id]).contains("{X}"):
					out.append("%s needs a mana cost like {1}{R}." % info["label"])


static func _effects_problems(out: Array[String], where: String, effects: Variant, context: String,
		has_x: bool, creature := true) -> void:
	if not effects is Array or (effects as Array).is_empty():
		out.append(where + "add at least one effect.")
		return
	if (effects as Array).size() > LIMITS["effects"]:
		out.append(where + "at most %d effects." % LIMITS["effects"])
	for e in effects:
		if not e is Dictionary or not EFFECTS.has(String(e.get("effect", ""))):
			out.append(where + "unknown effect.")
			continue
		var id := String(e["effect"])
		var info: Dictionary = EFFECTS[id]
		if not effect_allowed(id, context):
			out.append(where + ("%s is not offered in a triggered ability." if context == "trigger"
				else "%s is for an activated ability.") % info["label"])
		if info.has("unless"):
			var toll := int(e.get("unless", 0))
			if toll < int(info["unless"][0]) or toll > int(info["unless"][1]):
				out.append(where + "\"unless its controller pays\" is {0} (none) to {4}.")
		if info.has("base"):
			var bp := int(e.get("power", 2))
			var bt := int(e.get("toughness", 2))
			if bp < 0 or bp > 20 or bt < 1 or bt > 20:
				out.append(where + "%s: 0/1 to 20/20." % info["label"])
			if info.has("subtype") and String(e.get("subtype", "")) != "" and not _word_ok(String(e["subtype"])):
				out.append(where + "the creature type is one word.")
		if info.has("land") and not LANDS.has(String(e.get("land", ""))):
			out.append(where + "landwalk is plainswalk, islandwalk, swampwalk, mountainwalk or forestwalk.")
		if info.has("lose"):
			var lost := _list(e.get("keywords"))
			if lost.size() != 1 or not KEYWORDS.has(lost[0]):
				out.append(where + "choose the keyword it loses.")
		if info.has("shield") and not PROTECTIONS.has(String(e.get("color", ""))):
			out.append(where + "choose the color of the source.")
		var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
		if info.has("targets") and not (info["targets"] as Array).has(target):
			out.append(where + "%s cannot target \"%s\"." % [info["label"], target])
		if target == "self" and context == "spell":
			out.append(where + "a spell has no \"self\" to target.")
		elif target == "self" and not creature:
			out.append(where + "%s on this card is for a creature." % info["label"])
		var x := bool(e.get("x", false))
		if info.has("amount") and not x:
			var n := int(e.get("amount", 1))
			if n < int(info["amount"][0]) or n > int(info["amount"][1]):
				out.append(where + "%s: the amount is %d to %d." % [info["label"], info["amount"][0], info["amount"][1]])
		if x:
			if not info.get("x", false):
				out.append(where + "%s cannot be X." % info["label"])
			elif context == "trigger":
				out.append(where + "a triggered ability has no X.")
			elif not has_x:
				out.append(where + "an X amount needs {X} in the cost.")
			elif target == "each_opponent":
				out.append(where + "X damage to each opponent is not offered.")
		if info.has("pt"):
			_pt_problems(out, where, e)
		var granted := _list(e.get("keywords"))
		for k in granted:
			if not KEYWORDS.has(k):
				out.append(where + "unknown keyword \"%s\"." % k)
		if not granted.is_empty() and not info.has("keywords") and not info.has("lose"):
			out.append(where + "%s gives no keyword." % info["label"])
		if granted.has("flash") and not info.has("lose"):
			out.append(where + "flash means nothing on a card already in play.")
		if granted.has("must_attack") and (info.has("token") or info.has("lose")):
			out.append(where + "\"attacks each combat if able\" is not offered here.")
		if id == "pump" and int(e.get("power", 0)) == 0 and int(e.get("toughness", 0)) == 0 \
				and not granted.is_empty() and granted.all(func(k: String) -> bool: return k in HINDERING):
			out.append(where + "giving only defender or \"attacks each combat\" is an Aura's.")
		if info.has("color") and not MANA_COLORS.has(String(e.get("color", ""))):
			out.append(where + "choose the mana's color.")
		if info.has("token"):
			var p := int(e.get("power", 1))
			var t := int(e.get("toughness", 1))
			if p < 0 or p > 20 or t < 1 or t > 20:
				out.append(where + "a token is 0/1 to 20/20.")
			if not _word_ok(String(e.get("subtype", "Soldier"))):
				out.append(where + "the token's creature type is one word.")
			if not COLORS.has(String(e.get("color", "colorless"))):
				out.append(where + "unknown token color.")


static func _pt_problems(out: Array[String], where: String, a: Dictionary) -> void:
	for key in ["power", "toughness"]:
		var n := int(a.get(key, 0))
		if n < int(LIMITS["pt_change"][0]) or n > int(LIMITS["pt_change"][1]):
			out.append(where + "+P/+T is -10 to +10.")
			return


## Whether [param cost] reads like `{2}{R}{R}` (empty only when [param
## may_be_empty]).
static func cost_ok(cost: String, may_be_empty := false) -> bool:
	if cost == "":
		return may_be_empty
	var re := RegEx.create_from_string("^(\\{(?:[0-9]{1,2}|[WUBRGX])\\})+$")
	if re.search(cost) == null:
		return false
	return ManaCost.parse(cost).mana_value() <= 16 and cost.count("{") <= 8


static func _name_ok(name: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9 ',\\-]*$").search(name) != null \
		and not name.contains("  ")


static func _word_ok(word: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z]{1,20}$").search(word) != null


static func _list(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for v in value:
			out.append(String(v))
	return out


# ------------------------------------------------------------- building --

## The card [param spec] describes (a spec [method problems] found whole).
static func build(spec: Dictionary) -> CardData:
	var types := 0
	for t in _list(spec.get("types")):
		types |= int(TYPES[t])
	var name := String(spec["name"]).strip_edges()
	var data := CardData.new(name, String(spec.get("cost", "")), types)
	if types & Mtg.CardType.CREATURE:
		data.pt(int(spec.get("power", 1)), int(spec.get("toughness", 1)))
	if _list(spec.get("supertypes")).has("legendary"):
		data.with_supertypes(Mtg.Supertype.LEGENDARY)
	data.with_subtypes(_list(spec.get("subtypes")))
	var kws: Array = []
	for k in _list(spec.get("keywords")):
		kws.append(KEYWORDS[k])
	data.with_keywords(kws)
	var mask := 0
	for c in _list(spec.get("protection")):
		mask |= int(COLORS[c])
	if mask != 0:
		data.with_protection_from(mask)
	if not _list(spec.get("landwalk")).is_empty():
		data.with_landwalk(_list(spec.get("landwalk")))
	# A land of a basic type taps for its color (a dual land's way).
	if types & Mtg.CardType.LAND:
		for basic in _basic_types(spec):
			data.mana(ManaAbility.new(int(MANA_COLORS[BASIC_COLORS[basic]])))
	for a in spec.get("abilities", []):
		_add_ability(data, a)
	_add_rules(data, spec.get("rules") if spec.get("rules") is Dictionary else {})
	data.oracle(rules_text(spec))
	data.flavor_text = String(spec.get("flavor", ""))
	return data


## The card rules, after the abilities (buyback reads the spell's effects).
static func _add_rules(data: CardData, rules: Dictionary) -> void:
	for id in rules:
		var value: Variant = rules[id]
		match String(id):
			"echo": EchoAbility.attach(data, String(value))
			"cycling": data.with_cycling(String(value))
			"cumulative_upkeep": CumulativeUpkeep.attach(data, String(value))
			"buyback": data.with_buyback({"mana": String(value)})
			"rampage": data.with_rampage(int(value))
			"enters_tapped": data.with_enters_tapped()
			"enters_counters": data.with_enters_counters("+1/+1", int(value))
			"cant_be_countered": data.with_cant_be_countered()
			"cant_block":
				data.static_ability(StaticAbility.new(func(_g: MtgGame, s: CardInstance) -> void:
					s.cur_cant_block_filter = func(_attacker: CardInstance) -> bool: return true,
					"%s can't block." % data.card_name))
			"no_walls": data.with_cant_be_blocked_by(["wall"])
			"extra_blocks": data.with_extra_blocks(int(value))
			"extra_life": data.with_additional_life(int(value))
			"upkeep_cost": data.triggered(_upkeep_cost(data.card_name, String(value)))


## "At the beginning of your upkeep, sacrifice CARDNAME unless you pay
## COST." (Conversion's shape.)
static func _upkeep_cost(name: String, cost: String) -> TriggeredAbility:
	var toll := ManaCost.parse(cost)
	return TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		func(game: MtgGame, source: CardInstance, _ev: GameEvent) -> void:
			if source.zone != Mtg.Zone.BATTLEFIELD:
				return
			if EffectBase.unless_paid(game, source.controller_id, toll, "Pay %s to keep %s?" % [cost, name]):
				return
			game.sacrifice_permanent(source),
		"At the beginning of your upkeep, sacrifice %s unless you pay %s." % [name, cost],
		func(_game: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
			return int(ev.data.get("player", -1)) == source.controller_id)


static func _add_ability(data: CardData, a: Dictionary) -> void:
	var name := data.card_name
	match String(a["kind"]):
		"spell":
			for e in a["effects"]:
				data.spell(effect_of(e))
		"modal":
			var helps: Array = []
			for mode in a["modes"]:
				var effects: Array = []
				var flags: Array = []
				for e in mode["effects"]:
					effects.append(effect_of(e))
					flags.append(_helpful(e))
				helps.append(flags)
				data.mode(_sentence(effects_text(mode["effects"], name, "spell")), effects)
			data.with_ai_mode(_ai_mode.bind(name, helps))
		"activated":
			_add_activated(data, a)
		"mana":
			_add_mana(data, a)
		"trigger":
			data.triggered(_trigger(a, name))
		"static":
			_add_static(data, a)
		"enchant":
			_add_enchant(data, a)


## An activated ability, its costs and timing — or, SHARED with a creature
## type, the same ability on every creature of that type, both players'
## (the Sliver shape: each has it as its own, "this creature" is the one
## whose ability it is).
static func _add_activated(data: CardData, a: Dictionary) -> void:
	var shared := String(a.get("shared", "")).to_lower()
	var effects: Array = []
	for e in a["effects"]:
		effects.append(effect_of(e))
	var own_text := _sentence(ability_text(a, "this creature" if shared != "" else data.card_name, shared != ""))
	var ability := ActivatedAbility.new(String(a.get("cost", "")), bool(a.get("tap", false)), effects, own_text)
	if bool(a.get("sacrifice", false)):
		ability.with_sacrifice_cost()
	var sac := String(a.get("sacrifice_what", ""))
	if sac != "":
		ability.with_sacrifice_of(String(SACRIFICES[sac]).trim_prefix("a ").trim_prefix("an "), _sacrifice_filter(sac))
		# "Sacrifice a creature" may be this creature itself — but not when
		# it is sacrificed for the cost already ("another creature").
		if not bool(a.get("sacrifice", false)):
			ability.may_sacrifice_itself()
	if int(a.get("discard", 0)) > 0:
		ability.with_discard_cost(int(a["discard"]))
	if int(a.get("remove_counters", 0)) > 0:
		ability.with_counter_cost("+1/+1", int(a["remove_counters"]))
	if int(a.get("life", 0)) > 0:
		ability.with_life_cost(int(a["life"]))
	match String(a.get("timing", "any")):
		"your_turn": ability.your_turn_only()
		"once": ability.per_turn(1)
		"combat": ability.combat_only()
	if shared == "":
		data.activated(ability)
		return
	data.static_ability(StaticAbility.new(func(game: MtgGame, _source: CardInstance) -> void:
		for inst in game.all_battlefield():
			if not inst.phased_out and inst.is_creature() and inst.has_subtype(shared):
				inst.cur_activated_abilities.append(ability),
		_sentence(ability_text(a, data.card_name))).changing_abilities())


## The basic land types of a land [param spec], in their order.
static func _basic_types(spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if _list(spec.get("types")).has("land"):
		for sub in _list(spec.get("subtypes")):
			if BASIC_COLORS.has(sub.to_lower()) and not out.has(sub.to_lower()):
				out.append(sub.to_lower())
	return out


static func _sacrifice_filter(what: String) -> Callable:
	match what:
		"land": return func(i: CardInstance) -> bool: return i.is_land()
		"artifact": return func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	return func(i: CardInstance) -> bool: return i.is_creature()


## A mana ability: one color, colorless, or any color (one ability a
## color, as Birds of Paradise is built); its costs (mana, sacrificing the
## card) and the damage it deals you (a pain land's).
static func _add_mana(data: CardData, a: Dictionary) -> void:
	var color := String(a["color"])
	var n := int(a.get("amount", 1))
	var pain := int(a.get("pain", 0))
	var colors: Array = [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G] \
		if color == "any" else [MANA_COLORS[color]]
	for c in colors:
		var mana := ManaAbility.new(int(c), n)
		if String(a.get("cost", "")) != "":
			# A filter ({1}, {T}: Add {U}{U}) the planner may plan through.
			mana.with_mana_cost(String(a["cost"])).with_plannable_conversion()
		if bool(a.get("sacrifice", false)):
			mana.with_sacrifice()
		if pain > 0:
			mana.hurting(pain).with_side_effect(func(game: MtgGame, source: CardInstance, pid: int) -> void:
				game.deal_damage(source, TargetRef.player(pid), pain))
		data.mana(mana)


## THE COMPUTER'S MODE of a "Choose one —" spell: of the modes whose
## every target can be one on the right side ([param helps], each effect's:
## its own for help, the opponent's for harm), one that does something to
## a target before one that aims at nothing (removal before a life gain);
## the first mode when none fits.
static func _ai_mode(game: MtgGame, pid: int, card_name: String, helps: Array) -> int:
	var inst: CardInstance = null
	for i in game.players[pid].hand:
		if i.data.card_name == card_name:
			inst = i
			break
	if inst == null:
		return 0
	var best := -1
	var best_score := 0
	for m in mini(inst.data.modes.size(), helps.size()):
		var effects: Array = (inst.data.modes[m] as Dictionary)["effects"]
		var fits := true
		var aimed := false
		for j in effects.size():
			var spec: TargetSpec = (effects[j] as EffectBase).target_spec
			if spec == null:
				continue
			var helpful := bool((helps[m] as Array)[j]) if j < (helps[m] as Array).size() else false
			var side := false
			for ref in spec.legal_targets(game, inst):
				var mine := false
				if ref.is_player:
					mine = ref.player_id == pid
				else:
					var target := game.find_instance(ref.instance_id)
					mine = target != null and target.controller_id == pid
				if mine == helpful:
					# A creature or a spell is a fuller aim than a player.
					side = true
					aimed = aimed or not ref.is_player
					break
			if not side:
				fits = false
				break
		var score := (2 if aimed else 1) if fits else 0
		if score > best_score:
			best = m
			best_score = score
	return maxi(best, 0)


## A stock effect, ready to resolve, from one effect of a spec.
static func effect_of(e: Dictionary) -> EffectBase:
	var id := String(e["effect"])
	var info: Dictionary = EFFECTS[id]
	var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
	var x := bool(e.get("x", false))
	var n := 0 if x else int(e.get("amount", 1))
	var kws: Array = []
	for k in _list(e.get("keywords")):
		if KEYWORDS.has(k):
			kws.append(KEYWORDS[k])
	match id:
		"damage":
			match target:
				"creature", "creature_attacking", "creature_flying":
					var hit := DamageEffect.new(n).target_creature(target_words(target), _creature_filter(target))
					_game_filter(hit.target_spec, target)
					return hit.x_damage() if x else hit
				"player":
					var at_player := DamageEffect.new(n).target_player()
					return at_player.x_damage() if x else at_player
				"opponent":
					var at := DamageEffect.new(n)
					at.target_spec = TargetSpec.opponent()
					return at.x_damage() if x else at
				"each_opponent":
					return EachOpponent.new("damage", n)
				"each_creature":
					var each := DamageAllEffect.new(n, "each creature")
					return each.x_damage() if x else each
				"each_creature_and_player":
					var all := DamageAllEffect.new(n, "each creature").and_each_player()
					return all.x_damage() if x else all
			var any := DamageEffect.new(n).any_target()
			return any.x_damage() if x else any
		"draw":
			var draw := DrawEffect.new(n).target_player() if target == "player" else DrawEffect.new(n)
			return draw.x_cards() if x else draw
		"gain_life":
			var gain := GainLifeEffect.new(n).target_player() if target == "player" else GainLifeEffect.new(n)
			return gain.x_amount() if x else gain
		"lose_life":
			if target == "each_opponent":
				return EachOpponent.new("lose", n)
			var loss := GainLifeEffect.new(-n).target_player()
			if target == "opponent":
				loss.target_spec = TargetSpec.opponent()
			return loss
		"drain":
			return EachOpponent.new("drain", n) if target == "each_opponent" else DrainEffect.new(n)
		"destroy":
			return DestroyEffect.new(_spec_for(target))
		"destroy_all":
			match target:
				"creatures_flying": return DestroyAllEffect.new("all creatures with flying",
					func(i: CardInstance) -> bool: return i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING))
				"artifacts": return DestroyAllEffect.new("all artifacts",
					func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT))
				"enchantments": return DestroyAllEffect.new("all enchantments",
					func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT))
				"lands": return DestroyAllEffect.new("all lands", func(i: CardInstance) -> bool: return i.is_land())
			return DestroyAllEffect.new("all creatures")
		"exile":
			return ExileEffect.new(_spec_for(target))
		"bounce":
			return ReturnToHandEffect.new(_spec_for(target))
		"pump":
			var pump := PumpEffect.new(int(e.get("power", 0)), int(e.get("toughness", 0)), kws)
			if target == "self":
				pump.self_buff()
			return pump.x_power() if x else pump
		"mass_pump":
			var mass := MassPumpEffect.new(int(e.get("power", 0)), int(e.get("toughness", 0)),
				"creatures you control" if target == "yours" else "all creatures", kws)
			return mass.yours_only() if target == "yours" else mass
		"counters":
			return SelfCounters.new(n) if target == "self" \
				else CounterMarkerEffect.new("+1/+1", n, TargetSpec.creature())
		"minus_counters":
			return CounterMarkerEffect.new("-1/-1", n, TargetSpec.creature())
		"counter":
			var desc := ""
			var which := Callable()
			match target:
				"creature_spell":
					desc = "target creature spell"
					which = func(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.CREATURE)
				"noncreature_spell":
					desc = "target noncreature spell"
					which = func(i: CardInstance) -> bool: return not i.data.is_type(Mtg.CardType.CREATURE)
			var toll := int(e.get("unless", 0))
			return UnlessCounter.new(desc, which, toll) if toll > 0 else CounterEffect.new(desc, which)
		"counter_ability":
			var stop := CounterAbilityEffect.new()
			if int(e.get("unless", 0)) > 0:
				stop.unless_they_pay("{%d}" % int(e["unless"]))
			return stop
		"token":
			var subtype := _type_word(String(e.get("subtype", "soldier")))
			var token := CreateTokenEffect.new(subtype, int(e.get("power", 1)), int(e.get("toughness", 1)),
				int(COLORS[String(e.get("color", "colorless"))]), subtype.to_lower(), n)
			if not kws.is_empty():
				token.token.with_keywords(kws)
			return token
		"shield":
			return PreventDamageShieldEffect.new(int(COLORS[String(e.get("color", "red"))]))
		"set_pt":
			var base := SetBasePowerToughnessEffect.new(int(e.get("power", 2)), int(e.get("toughness", 2)))
			base.ai_helpful = _helpful(e)
			return OnItself.new(base) if target == "self" else base
		"switch_pt":
			var swap := SwitchPowerToughnessEffect.new()
			return OnItself.new(swap) if target == "self" else swap
		"landwalk":
			var walk := GrantLandwalkEffect.new([String(e.get("land", "island"))])
			return OnItself.new(walk) if target == "self" else walk
		"lose_keyword":
			var lost := _list(e.get("keywords"))
			return LoseAbilityEffect.new([KEYWORDS[lost[0]]], String(KEYWORD_WORDS[lost[0]]))
		"animate":
			var sub := String(e.get("subtype", "")).to_lower()
			return AnimateSelfEffect.new(Mtg.CardType.CREATURE, int(e.get("power", 2)), int(e.get("toughness", 2)),
				[sub] if sub != "" else [])
		"draw_later":
			return DelayedDrawEffect.new(n)
		"search":
			var wanted := target_words(target)
			return SearchLibraryEffect.new(wanted, _search_filter(target))
		"add_mana":
			return AddManaEffect.new(int(MANA_COLORS[String(e["color"])]), n)
		"mill":
			var mill := MillEffect.new(n)
			if target == "opponent":
				mill.target_spec = TargetSpec.opponent()
			return mill
		"discard":
			var chosen := ChosenDiscardEffect.new(n)
			if target == "player":
				chosen.target_spec = TargetSpec.player()
			return chosen
		"discard_random":
			var random := RandomHandDiscardEffect.new(n)
			random.target_spec = TargetSpec.opponent() if target == "opponent" else TargetSpec.player()
			return random
		"sacrifice":
			return EdictEffect.new(target == "opponent")
		"steal":
			return StealEffect.new(_spec_for(target))
		"search_basic":
			var search := SearchLibraryEffect.new("a basic land card", func(i: CardInstance) -> bool:
				return i.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0)
			return search.to_battlefield() if target == "to_battlefield" else search
		"tap":
			return TapEffect.new(_spec_for(target))
		"untap":
			return UntapEffect.new(_spec_for(target))
		"regenerate":
			return RegenerateEffect.new().target_creature() if target == "creature" else RegenerateEffect.new()
		"prevent":
			var prevent := PreventDamageEffect.new(n).target_creature() if target == "creature" \
				else PreventDamageEffect.new(n).any_target()
			return prevent.x_amount() if x else prevent
		"fog":
			return PreventCombatDamageEffect.new()
		"raise":
			return ReturnFromGraveyardEffect.new()
		"extra_turn":
			return ExtraTurnEffect.new()
	push_error("CommunityCard: unknown effect %s" % id)
	return DrawEffect.new(1)


## What a library search may find, by [param target].
static func _search_filter(target: String) -> Callable:
	match target:
		"a_creature": return func(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.CREATURE)
		"an_artifact": return func(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.ARTIFACT)
		"an_enchantment": return func(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.ENCHANTMENT)
		"a_land": return func(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.LAND)
	return func(_i: CardInstance) -> bool: return true


## Which creatures a creature target may be, by [param target].
static func _creature_filter(target: String) -> Callable:
	match target:
		"creature_nonblack":
			return func(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
		"creature_nonartifact":
			return func(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT)
		"creature_flying":
			return func(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
		"creature_tapped":
			return func(i: CardInstance) -> bool: return i.tapped
	return Callable()


## A combat-state target needs the game: an attacking creature.
static func _game_filter(spec: TargetSpec, target: String) -> void:
	if target == "creature_attacking":
		spec.with_game_filter(func(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id))


static func _spec_for(target: String) -> TargetSpec:
	var spec: TargetSpec
	match target:
		"artifact":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact",
				func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT))
		"enchantment":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
				func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT))
		"artifact_or_enchantment":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or enchantment",
				func(i: CardInstance) -> bool:
					return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT))
		"land":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
				func(i: CardInstance) -> bool: return i.is_land())
		"nonbasic_land":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonbasic land",
				func(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0)
		"permanent":
			spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent")
		_:
			spec = TargetSpec.creature(target_words(target), _creature_filter(target))
			_game_filter(spec, target)
	return spec


## THE TRIGGER ADAPTER: the trigger listens for its event, checks it is
## this card's (or its controller's), targets with each effect's own target
## in order — its own side first for a helpful effect, the opponent's first
## for the rest (the computer takes the first) — and resolves the effects
## on what was chosen.
static func _trigger(a: Dictionary, name: String) -> TriggeredAbility:
	var effects: Array[EffectBase] = []
	var helpful: Array[bool] = []
	for e in a["effects"]:
		effects.append(effect_of(e))
		helpful.append(_helpful(e))
	var when := String(a["when"])
	var event: int = Mtg.EventType.ENTERS_BATTLEFIELD
	var condition := func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
		return ev.data.get("instance") == source
	match when:
		"dies":
			event = Mtg.EventType.DIES
		"leaves":
			event = Mtg.EventType.LEAVES_BATTLEFIELD
		"upkeep":
			event = Mtg.EventType.UPKEEP_START
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return int(ev.data.get("player", -1)) == source.controller_id
		"each_upkeep":
			event = Mtg.EventType.UPKEEP_START
			condition = Callable()
		"end_step":
			event = Mtg.EventType.END_STEP_START
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return int(ev.data.get("player", -1)) == source.controller_id
		"attacks":
			event = Mtg.EventType.DECLARED_ATTACKERS
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return (ev.data.get("attackers", []) as Array).has(source)
		"blocks":
			event = Mtg.EventType.BECOMES_BLOCKER
		"blocked":
			event = Mtg.EventType.BECOMES_BLOCKED
		"unblocked":
			event = Mtg.EventType.UNBLOCKED_ATTACKER
		"combat_damage_player":
			event = Mtg.EventType.DAMAGE_DEALT
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				var packet: Variant = ev.data.get("packet")
				return ev.data.get("source") == source and ev.data.has("to_player") \
					and packet != null and bool(packet.is_combat)
		"you_cast", "you_cast_creature", "opponent_casts":
			event = Mtg.EventType.SPELL_CAST
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				var caster := int(ev.data.get("controller", -1))
				var spell: CardInstance = ev.data.get("instance")
				if when == "opponent_casts":
					return caster != source.controller_id
				return caster == source.controller_id and spell != source \
					and (when == "you_cast" or (spell != null and spell.is_type(Mtg.CardType.CREATURE)))
		"creature_enters", "land_enters":
			event = Mtg.EventType.ENTERS_BATTLEFIELD
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				var arrived: CardInstance = ev.data.get("instance")
				if arrived == null or int(ev.data.get("controller", -1)) != source.controller_id:
					return false
				# "Another creature", but "a land" — a land counts itself.
				return arrived.is_land() if when == "land_enters" else (arrived != source and arrived.is_creature())
		"creature_dies":
			event = Mtg.EventType.DIES
			condition = func(_g: MtgGame, _source: CardInstance, ev: GameEvent) -> bool:
				var gone: CardInstance = ev.data.get("instance")
				return gone != null and (gone.last_types & Mtg.CardType.CREATURE) != 0
	var slots: Array[int] = []
	for i in effects.size():
		slots.append(-1)
	var resolve := func(g: MtgGame, source: CardInstance, _ev: GameEvent) -> void:
		var controller := source.controller_id
		for i in effects.size():
			var effect: EffectBase = effects[i]
			if slots[i] < 0:
				effect.resolve_multi(g, source, controller, [], 0)
				continue
			var chosen := g.current_trigger_target(slots[i])
			if chosen != null:
				effect.resolve_multi(g, source, controller, [chosen], 0)
	var trigger := TriggeredAbility.new(event, resolve, _sentence(ability_text(a, name)), condition)
	var slot := 0
	for i in effects.size():
		var spec: TargetSpec = effects[i].target_spec
		if spec == null:
			continue
		if slot == 0:
			trigger.targeting(spec, _order(helpful[i]))
		else:
			trigger.and_targeting(spec, _order(helpful[i]))
		slots[i] = slot
		slot += 1
	return trigger


## Whether [param e] helps what it targets — a pump only when it does
## not shrink (-2/-2 is aimed at the opponent's first).
static func _helpful(e: Dictionary) -> bool:
	var id := String(e.get("effect", ""))
	match id:
		"pump", "mass_pump":
			var p := int(e.get("power", 0))
			var t := int(e.get("toughness", 0))
			var kws := _list(e.get("keywords"))
			# Only defender to give is no gift.
			if p == 0 and t == 0 and not kws.is_empty() and kws.all(func(k: String) -> bool: return k in HINDERING):
				return false
			return p >= 0 and t >= 0
		"set_pt":
			# A big body is a gift, a small one a curse (Sorceress Queen's 0/2).
			return int(e.get("power", 2)) + int(e.get("toughness", 2)) >= 5
		"lose_keyword":
			return _list(e.get("keywords")).all(func(k: String) -> bool: return k in HINDERING)
	return id in HELPFUL


## The order a trigger's choices are offered in (the computer takes the
## first): its own side first for a helpful effect, else the opponent's.
static func _order(helpful: bool) -> Callable:
	return func(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
		return _rank(g, s, a, helpful) < _rank(g, s, b, helpful)


static func _rank(g: MtgGame, s: CardInstance, ref: TargetRef, helpful: bool) -> int:
	var mine := false
	if ref.is_player:
		mine = ref.player_id == s.controller_id
	else:
		var inst := g.find_instance(ref.instance_id)
		mine = inst != null and inst.controller_id == s.controller_id
	return (0 if mine else 1) if helpful else (1 if mine else 0)


## The static abilities: anthems and lords (+P/+T and keywords, by whose
## creatures and of what type), and cheaper spells of a type.
static func _add_static(data: CardData, a: Dictionary) -> void:
	var what := String(a["what"])
	if what == "cost_less":
		var spell_type := int(TYPES[String(a.get("spell_type", "creature"))])
		var less := int(a.get("amount", 1))
		data.with_cost_modifier(func(_game: MtgGame, caster: int, card: CardData, modifier: CardInstance) -> int:
			return -less if modifier.controller_id == caster and card.is_type(spell_type) else 0)
		return
	var text := _sentence(static_text(a))
	var p := int(a.get("power", 0))
	var t := int(a.get("toughness", 0))
	var subtype := String(a.get("subtype", "")).to_lower()
	var kws: Array[int] = []
	for k in _list(a.get("keywords")):
		kws.append(int(KEYWORDS[k]))
	var counts := func(source: CardInstance, inst: CardInstance) -> bool:
		if not inst.is_creature():
			return false
		match what:
			"anthem": return inst.controller_id == source.controller_id
			"anthem_others": return inst.controller_id == source.controller_id and inst != source
			"lord": return inst.controller_id == source.controller_id and inst != source and inst.has_subtype(subtype)
			"tribe": return inst.has_subtype(subtype)
			"opponents": return inst.controller_id != source.controller_id
		return true
	if p != 0 or t != 0:
		data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
			for inst in game.all_battlefield():
				if counts.call(source, inst):
					inst.cur_power += p
					inst.cur_toughness += t, text))
	if not kws.is_empty():
		data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
			for inst in game.all_battlefield():
				if counts.call(source, inst):
					for k in kws:
						if not inst.cur_keywords.has(k):
							inst.cur_keywords.append(k), text).changing_abilities())


## AN AURA: "Enchant creature (land, artifact, permanent)", and what it
## does to its host — +P/+T and keywords, protection, "can't attack or
## block", "doesn't untap", or "you control enchanted …". One that harms
## its host or takes it is aimed at the opponent's by the computer
## ([member CardData.ai_aura_hostile]).
static func _add_enchant(data: CardData, a: Dictionary) -> void:
	var on := String(a.get("enchant", "creature"))
	data.enchants(TargetSpec.creature() if on == "creature" else _spec_for(on))
	var p := int(a.get("power", 0))
	var t := int(a.get("toughness", 0))
	var kws: Array[int] = []
	for k in _list(a.get("keywords")):
		kws.append(int(KEYWORDS[k]))
	var text := _sentence(enchant_text(a))
	var pacify := bool(a.get("pacify", false))
	var frozen := bool(a.get("frozen", false))
	if bool(a.get("control", false)):
		data.steals_control()
	var only_hinders := p <= 0 and t <= 0 and not _list(a.get("keywords")).is_empty() \
		and _list(a.get("keywords")).all(func(k: String) -> bool: return k in HINDERING)
	if p < 0 or t < 0 or pacify or frozen or bool(a.get("control", false)) or only_hinders:
		data.ai_aura_hostile = true
	var ward := String(a.get("protection", ""))
	if ward != "":
		data.grants_host_protection(int(COLORS[ward]), "Enchanted creature has protection from %s." % ward)
	if p != 0 or t != 0 or pacify or frozen:
		data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
			var host := game.find_instance(source.attached_to) if source.attached_to != -1 else null
			if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
				return
			host.cur_power += p
			host.cur_toughness += t
			if pacify:
				host.cur_cant_attack = true
				host.cur_cant_block_filter = func(_attacker: CardInstance) -> bool: return true
			if frozen:
				host.cur_skips_untap = true, text))
	if not kws.is_empty():
		data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
			var host := game.find_instance(source.attached_to) if source.attached_to != -1 else null
			if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
				for k in kws:
					if not host.cur_keywords.has(k):
						host.cur_keywords.append(k), text).changing_abilities())


# ------------------------------------------------ the trusted effects --

## A targeted stock effect turned on the card itself ("CARDNAME gains
## islandwalk until end of turn"): no target, the source is the creature.
class OnItself extends EffectBase:
	var inner: EffectBase

	func _init(p_inner: EffectBase) -> void:
		inner = p_inner
		ai_helpful = true

	func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef,
			x_value: int = 0) -> void:
		if game.is_present(source):
			inner.resolve(game, source, controller, TargetRef.card(source), x_value)

	func describe() -> String:
		return inner.describe().replace("target creature", "this creature")


## "Counter target spell unless its controller pays {N}." (Mana Leak's
## shape: still a counterspell to the computer.)
class UnlessCounter extends CounterEffect:
	var toll := 1

	func _init(desc: String, filter: Callable, p_toll: int) -> void:
		super(desc, filter)
		toll = p_toll

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value: int = 0) -> void:
		if target == null or target.is_player:
			return
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK or game.spell_cant_be_countered(spell):
			return
		var item := game.find_stack_item(spell)
		var payer := spell.controller_id if item == null else item.controller
		if EffectBase.unless_paid(game, payer, ManaCost.parse("{%d}" % toll),
				"Pay {%d} to save %s?" % [toll, spell.data.card_name]):
			return
		super.resolve(game, source, controller, target, x_value)

	func describe() -> String:
		return "counter %s unless its controller pays {%d}" % [target_spec.description, toll]

## "Each opponent loses N life", "… is dealt N damage", "… loses N life and
## you gain that much life".
class EachOpponent extends EffectBase:
	var mode := "lose"
	var amount := 1

	func _init(p_mode: String, p_amount: int) -> void:
		mode = p_mode
		amount = p_amount

	func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		var lost := 0
		for pid in game.players.size():
			if pid == controller:
				continue
			if mode == "damage":
				game.deal_damage(source, TargetRef.player(pid), amount)
			else:
				game.adjust_life(pid, -amount)
				lost += amount
		if mode == "drain" and lost > 0:
			game.adjust_life(controller, lost)


## "Target opponent loses N life and you gain N life."
class DrainEffect extends EffectBase:
	var amount := 1

	func _init(p_amount: int) -> void:
		amount = p_amount
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		if target == null or not target.is_player:
			return
		game.adjust_life(target.player_id, -amount)
		game.adjust_life(controller, amount)


## "Put N +1/+1 counters on CARDNAME."
class SelfCounters extends EffectBase:
	var amount := 1

	func _init(p_amount: int) -> void:
		amount = p_amount
		ai_helpful = true

	func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		if game.is_present(source):
			game.add_counters(source, "+1/+1", amount)


## "Gain control of target creature (artifact)."
class StealEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		if target == null or target.is_player:
			return
		var victim := game.find_instance(target.instance_id)
		if victim != null and game.is_present(victim):
			game.change_control(victim, controller)


## "Target opponent (player) sacrifices a creature" — the victim chooses.
class EdictEffect extends EffectBase:
	func _init(opponent: bool) -> void:
		target_spec = TargetSpec.opponent() if opponent else TargetSpec.player()
		with_ai_role(&"opponent_sacrifice_creature")

	func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		if target == null or not target.is_player:
			return
		var pid := target.player_id
		var choices: Array[CardInstance] = []
		for i in game.players[pid].battlefield:
			if i.is_creature():
				choices.append(i)
		if choices.is_empty():
			return
		var picked := game.agents[pid].choose_card(game, pid, choices, "Sacrifice a creature")
		if picked == null or not choices.has(picked):
			picked = choices[0]
		game.sacrifice_permanent(picked)


# --------------------------------------------------------- the rules text --

## THE RULES TEXT, written from the blocks: the keywords line, protection
## and landwalk, the card rules, then each ability's sentence, one a line.
static func rules_text(spec: Dictionary) -> String:
	var name := String(spec.get("name", "")).strip_edges()
	var lines: Array[String] = []
	var words: Array[String] = []
	var keywords := _list(spec.get("keywords"))
	for k in keywords:
		if k != "must_attack":
			words.append(String(KEYWORD_WORDS.get(k, k)))
	for c in _list(spec.get("protection")):
		words.append("protection from %s" % c)
	for l in _list(spec.get("landwalk")):
		words.append("%swalk" % l)
	var rules: Dictionary = spec.get("rules") if spec.get("rules") is Dictionary else {}
	if rules.has("rampage"):
		words.append("rampage %d" % int(rules["rampage"]))
	if not words.is_empty():
		lines.append(_upper_first(", ".join(words)))
	var basics := _basic_types(spec)
	if not basics.is_empty():
		var symbols: Array[String] = []
		for basic in basics:
			symbols.append(String(MANA_SYMBOLS[BASIC_COLORS[basic]]))
		lines.append("({T}: Add %s.)" % " or ".join(symbols))
	for id in ["echo", "cumulative_upkeep", "buyback", "cycling"]:
		if rules.has(id):
			lines.append("%s %s" % [String(CARD_RULES[id]["label"]), String(rules[id])])
	if rules.has("upkeep_cost"):
		lines.append("At the beginning of your upkeep, sacrifice %s unless you pay %s." % [name,
			String(rules["upkeep_cost"])])
	if keywords.has("must_attack"):
		lines.append("%s attacks each combat if able." % name)
	if rules.has("extra_life"):
		lines.append("As an additional cost to cast %s, pay %d life." % [name, int(rules["extra_life"])])
	if rules.has("cant_be_countered"):
		lines.append("%s can't be countered." % name)
	if rules.has("enters_tapped"):
		lines.append("%s enters the battlefield tapped." % name)
	if rules.has("enters_counters"):
		var n := int(rules["enters_counters"])
		lines.append("%s enters the battlefield with %s +1/+1 counter%s on it." % [name, _number(n),
			"s" if n > 1 else ""])
	if rules.has("cant_block"):
		lines.append("%s can't block." % name)
	if rules.has("no_walls"):
		lines.append("%s can't be blocked by Walls." % name)
	if rules.has("extra_blocks"):
		var n := int(rules["extra_blocks"])
		lines.append("%s can block %s each combat." % [name,
			"an additional creature" if n == 1 else "%s additional creatures" % _number(n)])
	for a in spec.get("abilities", []):
		if a is Dictionary:
			var line := ""
			match String(a.get("kind", "")):
				"spell": line = _sentence(effects_text(a.get("effects", []), name, "spell"))
				"modal": line = modal_text(a, name)
				"activated", "trigger": line = _sentence(ability_text(a, name))
				"mana": line = _sentence(mana_text(a, name))
				"static": line = _sentence(static_text(a))
				"enchant": line = _sentence(enchant_text(a))
			if line != "":
				lines.append(line)
	return "\n".join(lines)


## An activated or triggered ability's sentence. A SHARED activated
## ability ("All Sliver creatures have …") is quoted whole; [param inner]
## asks for the quoted ability alone, as each creature that has it reads it.
static func ability_text(a: Dictionary, name: String, inner := false) -> String:
	if String(a.get("kind", "")) == "trigger":
		var when := String(TRIGGERS.get(String(a.get("when", "")), "")).replace("CARDNAME", name)
		return "%s, %s" % [when, _lower_first(effects_text(a.get("effects", []), name, "trigger"), name)]
	var shared := String(a.get("shared", ""))
	if shared != "" and not inner:
		return "All %s creatures have \"%s\"" % [_type_word(shared),
			_sentence(ability_text(a, "this creature", true))]
	var self_name := name
	var parts: Array[String] = []
	if String(a.get("cost", "")) != "":
		parts.append(String(a["cost"]))
	if bool(a.get("tap", false)):
		parts.append("{T}")
	if bool(a.get("sacrifice", false)):
		parts.append("Sacrifice %s" % self_name)
	var sac := String(a.get("sacrifice_what", ""))
	if SACRIFICES.has(sac):
		parts.append("Sacrifice %s" % ("another " + sac if bool(a.get("sacrifice", false)) else SACRIFICES[sac]))
	var discard := int(a.get("discard", 0))
	if discard > 0:
		parts.append("Discard %s" % _cards(discard))
	var removes := int(a.get("remove_counters", 0))
	if removes > 0:
		parts.append("Remove %s +1/+1 counter%s from %s" % [_number(removes), "s" if removes > 1 else "", self_name])
	if int(a.get("life", 0)) > 0:
		parts.append("Pay %d life" % int(a["life"]))
	var text := "%s: %s" % [", ".join(parts), _upper_first(effects_text(a.get("effects", []), name, "activated"))]
	match String(a.get("timing", "any")):
		"your_turn": text = _sentence(text) + " Activate only during your turn"
		"once": text = _sentence(text) + " Activate only once each turn"
		"combat": text = _sentence(text) + " Activate only during combat"
	return text


## "{T}: Add {G}.", "{T}: Add one mana of any color.", "{1}, {T}, Sacrifice
## CARDNAME: Add three mana of any one color.", a pain land's damage after.
static func mana_text(a: Dictionary, name := "") -> String:
	var color := String(a.get("color", "colorless"))
	var n := maxi(1, int(a.get("amount", 1)))
	var parts: Array[String] = []
	if String(a.get("cost", "")) != "":
		parts.append(String(a["cost"]))
	parts.append("{T}")
	if bool(a.get("sacrifice", false)):
		parts.append("Sacrifice %s" % (name if name != "" else "it"))
	var made := ""
	if color == "any":
		made = "one mana of any color" if n == 1 else "%s mana of any one color" % _number(n)
	else:
		made = String(MANA_SYMBOLS.get(color, "{C}")).repeat(n)
	var text := "%s: Add %s" % [", ".join(parts), made]
	var pain := int(a.get("pain", 0))
	if pain > 0:
		text += ". %s deals %d damage to you" % [name if name != "" else "It", pain]
	return text


## "Choose one —" and a line for each mode.
static func modal_text(a: Dictionary, name: String) -> String:
	var lines: Array[String] = ["Choose one —"]
	var modes: Variant = a.get("modes", [])
	if modes is Array:
		for mode in modes:
			if mode is Dictionary:
				lines.append("• " + _sentence(effects_text(mode.get("effects", []), name, "spell")))
	return "\n".join(lines)


static func static_text(a: Dictionary) -> String:
	var subtype := _type_word(String(a.get("subtype", "")))
	match String(a.get("what", "")):
		"cost_less":
			return "%s spells you cast cost {%d} less to cast" % [
				String(a.get("spell_type", "creature")).capitalize(), int(a.get("amount", 1))]
		"anthem_others":
			return "Other creatures you control " + _gets_and_has(a, true)
		"lord":
			return "Other %s creatures you control %s" % [subtype, _gets_and_has(a, true)]
		"tribe":
			return "All %s creatures %s" % [subtype, _gets_and_has(a, true)]
		"opponents":
			return "Creatures your opponents control " + _gets_and_has(a, true)
		"all":
			return "All creatures " + _gets_and_has(a, true)
	return "Creatures you control " + _gets_and_has(a, true)


static func enchant_text(a: Dictionary) -> String:
	var on := String(a.get("enchant", "creature"))
	var lines: Array[String] = ["Enchant %s." % on]
	var p := int(a.get("power", 0))
	var t := int(a.get("toughness", 0))
	if p != 0 or t != 0 or not _list(a.get("keywords")).is_empty():
		lines.append("Enchanted creature %s." % _gets_and_has(a, false))
	if String(a.get("protection", "")) != "":
		lines.append("Enchanted creature has protection from %s." % String(a["protection"]))
	if bool(a.get("pacify", false)):
		lines.append("Enchanted creature can't attack or block.")
	if bool(a.get("frozen", false)):
		lines.append("Enchanted %s doesn't untap during its controller's untap step." % on)
	if bool(a.get("control", false)):
		lines.append("You control enchanted %s." % on)
	return " ".join(lines)


static func _gets_and_has(a: Dictionary, plural: bool) -> String:
	var bits: Array[String] = []
	var p := int(a.get("power", 0))
	var t := int(a.get("toughness", 0))
	if p != 0 or t != 0:
		bits.append(("get %+d/%+d" if plural else "gets %+d/%+d") % [p, t])
	var kws := _list(a.get("keywords"))
	var words: Array[String] = []
	for k in kws:
		if k != "must_attack":
			words.append(String(KEYWORD_WORDS.get(k, k)))
	if not words.is_empty():
		bits.append(("have " if plural else "has ") + _and_list(words))
	if kws.has("must_attack"):
		bits.append("attack each combat if able" if plural else "attacks each combat if able")
	return " and ".join(bits) if not bits.is_empty() else ("get +0/+0" if plural else "gets +0/+0")


## The effects as one sentence: "Draw two cards and you gain 3 life".
static func effects_text(effects: Variant, name: String, context: String) -> String:
	var parts: Array[String] = []
	if effects is Array:
		for e in effects:
			if e is Dictionary:
				parts.append(effect_text(e, name, context))
	if parts.is_empty():
		return ""
	var text := parts[0]
	for i in range(1, parts.size()):
		text += (" and " if parts.size() == 2 else ", then ") + _lower_first(parts[i], name)
	return text


static func effect_text(e: Dictionary, name: String, _context: String) -> String:
	var id := String(e.get("effect", ""))
	if not EFFECTS.has(id):
		return ""
	var info: Dictionary = EFFECTS[id]
	var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
	var x := bool(e.get("x", false))
	var n := int(e.get("amount", 1))
	var amount := "X" if x else str(n)
	match id:
		"damage":
			return "%s deals %s damage to %s" % [name, amount, target_words(target)]
		"draw":
			var cards := "X cards" if x else _cards(n)
			return ("Target player draws %s" if target == "player" else "Draw %s") % cards
		"gain_life":
			return ("Target player gains %s life" if target == "player" else "You gain %s life") % amount
		"lose_life":
			return "%s loses %d life" % [_upper_first(target_words(target)), n]
		"drain":
			if target == "each_opponent":
				return "Each opponent loses %d life and you gain that much life" % n
			return "Target opponent loses %d life and you gain %d life" % [n, n]
		"destroy":
			return "Destroy %s" % target_words(target)
		"destroy_all":
			return "Destroy all %s" % target_words(target)
		"exile":
			return "Exile %s" % target_words(target)
		"bounce":
			return "Return %s to its owner's hand" % target_words(target)
		"pump":
			var who := name if target == "self" else "Target creature"
			if x:
				var has := _list(e.get("keywords"))
				var granted: Array[String] = []
				for k in has:
					if k != "must_attack":
						granted.append(String(KEYWORD_WORDS.get(k, k)))
				return "%s gets +X/%+d%s%s until end of turn" % [who, int(e.get("toughness", 0)),
					(" and has " + _and_list(granted)) if not granted.is_empty() else "",
					" and attacks each combat if able" if has.has("must_attack") else ""]
			return "%s %s until end of turn" % [who, _gets_and_has(e, false)]
		"mass_pump":
			var whose := "Creatures you control" if target == "yours" else "All creatures"
			return "%s %s until end of turn" % [whose, _gets_and_has(e, true)]
		"counters":
			var where := name if target == "self" else "target creature"
			return "Put %s +1/+1 counter%s on %s" % [_number(n), "s" if n > 1 else "", where]
		"minus_counters":
			return "Put %s -1/-1 counter%s on target creature" % [_number(n), "s" if n > 1 else ""]
		"counter", "counter_ability":
			var toll := int(e.get("unless", 0))
			return "Counter %s%s" % [target_words(target),
				" unless its controller pays {%d}" % toll if toll > 0 else ""]
		"token":
			var subtype := _type_word(String(e.get("subtype", "soldier")))
			var shown := "%d/%d %s %s creature token%s" % [int(e.get("power", 1)), int(e.get("toughness", 1)),
				String(e.get("color", "colorless")), subtype, "s" if n > 1 else ""]
			var granted := _list(e.get("keywords"))
			if not granted.is_empty():
				var words: Array[String] = []
				for k in granted:
					words.append(String(KEYWORD_WORDS.get(k, k)))
				shown += " with " + _and_list(words)
			return "Create %s %s" % [_number(n), shown]
		"add_mana":
			return "Add %s" % String(MANA_SYMBOLS.get(String(e.get("color", "colorless")), "{C}")).repeat(maxi(1, n))
		"mill":
			return "%s puts the top %s of their library into their graveyard" % [
				_upper_first(target_words(target)), "card" if n == 1 else "%s cards" % _number(n)]
		"discard":
			return "%s discards %s" % [_upper_first(target_words(target)), _cards(n)]
		"discard_random":
			return "%s discards %s at random" % [_upper_first(target_words(target)), _cards(n)]
		"sacrifice":
			return "%s sacrifices a creature" % _upper_first(target_words(target))
		"steal":
			return "Gain control of %s" % target_words(target)
		"search_basic":
			return "Search your library for a basic land card, %s, then shuffle" % target_words(target)
		"tap":
			return "Tap %s" % target_words(target)
		"untap":
			return "Untap %s" % target_words(target)
		"regenerate":
			return "Regenerate %s" % (name if target == "self" else "target creature")
		"prevent":
			return "Prevent the next %s damage that would be dealt to %s this turn" % [amount, target_words(target)]
		"fog":
			return "Prevent all combat damage that would be dealt this turn"
		"raise":
			return "Return target creature card from your graveyard to your hand"
		"extra_turn":
			return "Take an extra turn after this one"
		"shield":
			return "The next time a %s source of your choice would deal damage to you this turn, prevent that damage" \
				% String(e.get("color", "red"))
		"set_pt":
			return "%s has base power and toughness %d/%d until end of turn" % [
				name if target == "self" else "Target creature", int(e.get("power", 2)), int(e.get("toughness", 2))]
		"switch_pt":
			return "Switch %s power and toughness until end of turn" % (
				name + "'s" if target == "self" else "target creature's")
		"landwalk":
			return "%s gains %swalk until end of turn" % [name if target == "self" else "Target creature",
				String(e.get("land", "island"))]
		"lose_keyword":
			var lost := _list(e.get("keywords"))
			return "Target creature loses %s until end of turn" % (
				String(KEYWORD_WORDS.get(lost[0], lost[0])) if not lost.is_empty() else "")
		"animate":
			var sub := _type_word(String(e.get("subtype", "")))
			return "%s becomes a %d/%d %screature until end of turn" % [name, int(e.get("power", 2)),
				int(e.get("toughness", 2)), sub + " " if sub != "" else ""]
		"draw_later":
			return "Draw %s at the beginning of the next turn's upkeep" % _cards(n)
		"search":
			return "Search your library for %s, reveal it, put it into your hand, then shuffle" % target_words(target)
	return ""


## A creature type as printed: "Goblin" ("mindflayer" stays one word).
static func _type_word(word: String) -> String:
	word = word.strip_edges()
	return word.left(1).to_upper() + word.substr(1).to_lower()


static func _cards(n: int) -> String:
	return "a card" if n == 1 else "%s cards" % _number(n)


static func _number(n: int) -> String:
	var words := ["zero", "one", "two", "three", "four", "five", "six", "seven"]
	return "a" if n == 1 else (words[n] if n < words.size() else str(n))


static func _and_list(words: Array[String]) -> String:
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]


static func _upper_first(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## An effect sentence after "When …," or "and": its first word lowered
## unless it is the card's own name.
static func _lower_first(text: String, name := "") -> String:
	if name != "" and text.begins_with(name):
		return text
	for start in ["Target ", "Draw ", "Destroy ", "Return ", "Create ", "Add ", "Untap ", "Tap ",
			"Exile ", "Counter ", "Prevent ", "Regenerate ", "You ", "All ", "Creatures ", "Each ",
			"Put ", "Gain ", "Search ", "Take ", "Switch ", "The next "]:
		if text.begins_with(start):
			return text.left(1).to_lower() + text.substr(1)
	return text


static func _sentence(text: String) -> String:
	text = text.strip_edges()
	if text == "":
		return ""
	# A quoted ability ends inside its quotes: 'have "{2}: Regenerate it."'.
	return text if text.ends_with(".") or text.ends_with(".\"") else text + "."
