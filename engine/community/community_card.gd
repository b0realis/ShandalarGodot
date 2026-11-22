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
	"no_untap": {"label": "Doesn't untap during your untap step", "kind": "flag", "types": PERMANENTS},
	"shroud": {"label": "Shroud", "kind": "flag", "types": PERMANENTS,
		"tip": "It can't be the target of spells or abilities."},
	"enters_x_counters": {"label": "Enters with X +1/+1 counters", "kind": "flag", "types": ["creature"],
		"tip": "X is the {X} paid for it: put {X} in the mana cost."},
	"pt_count": {"label": "Power and toughness equal to a count", "kind": "count", "types": ["creature"],
		"tip": "Its power and toughness are each the number of what it counts (one of counts())."},
}
## WHAT A COUNT COUNTS and whose: an id is `<what>_<whose>` ("swamp_you",
## "creature_all", "hand_opponent"); see [method counts], [method
## count_words]. An effect's `per` multiplies its amount by one; the card
## rule `pt_count` makes one a creature's power and toughness.
const COUNT_WHAT := ["creature", "land", "artifact", "plains", "island", "swamp", "mountain", "forest",
	"hand", "graveyard"]
const COUNT_WHOSE := ["you", "opponent", "all"]
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
	"draw_step": "At the beginning of your draw step",
	"each_draw": "At the beginning of each player's draw step",
	"cast_white": "Whenever a player casts a white spell",
	"cast_blue": "Whenever a player casts a blue spell",
	"cast_black": "Whenever a player casts a black spell",
	"cast_red": "Whenever a player casts a red spell",
	"cast_green": "Whenever a player casts a green spell",
	"deals_damage": "Whenever CARDNAME deals damage",
	"damage_player": "Whenever CARDNAME deals damage to a player",
	"damage_creature": "Whenever CARDNAME deals damage to a creature",
	"land_tapped": "Whenever a player taps a land for mana",
	"to_graveyard": "When CARDNAME is put into a graveyard from the battlefield",
}
## The triggers an Aura may watch its creature for (`enchanted` in a
## trigger: "Whenever enchanted creature attacks, …").
const HOST_TRIGGERS := ["attacks", "blocks", "blocked", "unblocked", "combat_damage_player", "deals_damage",
	"damage_player", "damage_creature"]
## The triggers that name a player of their own — whose step it is, who
## cast the spell, who tapped the land, who was dealt the damage: "that
## player" is that one when no effect before it targeted a player.
const EVENT_PLAYER_TRIGGERS := ["each_upkeep", "each_draw", "opponent_casts", "cast_white", "cast_blue",
	"cast_black", "cast_red", "cast_green", "land_tapped", "damage_player", "combat_damage_player"]
## The triggers on the card's own damage.
const DAMAGE_TRIGGERS := ["deals_damage", "damage_player", "damage_creature", "combat_damage_player"]
## Whether a triggered ability must be done: always, "you may", or with
## "up to one target" (the first is the default; `choice` in a spec).
const TRIGGER_CHOICES := {
	"must": {"label": "Always"},
	"may": {"label": "You may"},
	"up_to": {"label": "Up to one target"},
}
## The triggers that never happen during combat (no creature is attacking).
const QUIET_TRIGGERS := ["upkeep", "each_upkeep", "end_step", "draw_step", "each_draw"]
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
	"cost_more": {"label": "Spells cost more", "pt": false, "spell_type": true, "amount": [1, 3],
		"who": true, "spell_color": true},
	"attack_tax": {"label": "Creatures can't attack you unless their controller pays", "pt": false,
		"amount": [1, 3]},
}
## Whose spells a "cost more" static taxes (`who`; the first is the default).
const COST_WHO := ["all", "opponents"]
const COST_WHO_WORDS := {"all": "everyone's", "opponents": "your opponents'"}
## The spell types a "cost more" static may name: one type, or every spell.
const COST_SPELL_TYPES := ["creature", "artifact", "enchantment", "instant", "sorcery", "any"]

## THE EFFECTS a spell, an ability or a trigger may do: each one's label,
## its amount (range), whether it may be the X paid (`x`), its targets (the
## first is the default; "self" is the card itself, never a spell's),
## +P/+T, keywords, a color, a token.
const EFFECTS := {
	"damage": {"label": "Deal damage", "amount": [1, 20], "x": true,
		"only": true, "targets": ["any", "creature", "creature_attacking", "creature_flying", "player", "opponent",
			"each_opponent", "each_creature", "each_creature_and_player", "you", "that_player", "that_creature",
			"divided"], "per": true},
	"draw": {"label": "Draw cards", "amount": [1, 7], "x": true, "per": true,
		"targets": ["you", "player", "each_player", "that_player"]},
	"shuffle_in": {"label": "Shuffle into library", "from": true,
		"targets": ["each_player", "you", "player", "that_player"]},
	"gain_life": {"label": "Gain life", "amount": [1, 20], "x": true, "per": true,
		"targets": ["you", "player", "that_player"]},
	"lose_life": {"label": "Lose life", "amount": [1, 20], "x": true, "per": true,
		"targets": ["opponent", "player", "each_opponent", "you", "that_player"]},
	"drain": {"label": "Drain life", "amount": [1, 20], "x": true, "targets": ["opponent", "each_opponent"]},
	"destroy": {"label": "Destroy", "only": true, "targets": ["creature", "creature_nonblack", "creature_nonartifact",
		"creature_flying", "creature_attacking", "creature_tapped", "artifact", "enchantment",
		"artifact_or_enchantment", "land", "nonbasic_land", "permanent", "that_creature"]},
	"destroy_all": {"label": "Destroy all", "only": true, "targets": ["creatures", "creatures_flying", "artifacts",
		"enchantments", "lands"]},
	"exile": {"label": "Exile", "only": true,
		"targets": ["creature", "creature_attacking", "permanent", "that_creature"]},
	"bounce": {"label": "Return to hand", "only": true,
		"targets": ["creature", "artifact", "enchantment", "land", "permanent", "that_creature"]},
	"pump": {"label": "Give +P/+T", "pt": true, "keywords": true, "x": true, "per": true,
		"targets": ["creature", "self", "that_creature"]},
	"mass_pump": {"label": "Give +P/+T to many", "pt": true, "keywords": true, "only": true,
		"targets": ["yours", "all"]},
	"counters": {"label": "Put +1/+1 counters", "amount": [1, 5], "per": true,
		"targets": ["creature", "self", "that_creature"]},
	"minus_counters": {"label": "Put -1/-1 counters", "amount": [1, 5], "targets": ["creature", "that_creature"]},
	"counter": {"label": "Counter", "unless": [0, 4], "targets": ["spell", "creature_spell", "noncreature_spell"]},
	"counter_ability": {"label": "Counter an activated ability", "unless": [0, 4], "targets": ["ability"]},
	"token": {"label": "Create creature tokens", "amount": [1, 5], "token": true, "keywords": true, "x": true,
		"per": true},
	"add_mana": {"label": "Add mana", "amount": [1, 5], "color": true},
	"extra_mana": {"label": "That player adds one more mana of that type"},
	"mill": {"label": "Mill", "amount": [1, 20], "x": true, "targets": ["player", "opponent", "that_player"]},
	"discard": {"label": "Discard (you choose)", "amount": [1, 7], "x": true,
		"targets": ["opponent", "player", "that_player"]},
	"discard_own": {"label": "Discard (their choice)", "amount": [1, 7], "x": true,
		"targets": ["opponent", "player", "you", "that_player"]},
	"discard_random": {"label": "Discard at random", "amount": [1, 7], "x": true,
		"targets": ["opponent", "player", "that_player"]},
	"sacrifice": {"label": "Sacrifice a creature", "targets": ["opponent", "player", "you", "that_player"]},
	"sacrifice_self": {"label": "Sacrifice this card"},
	"exile_self": {"label": "Exile this card"},
	"return_self": {"label": "Return this card to its owner's hand"},
	"steal": {"label": "Gain control", "only": true, "targets": ["creature", "artifact"]},
	"borrow": {"label": "Take control until end of turn", "only": true, "targets": ["creature"]},
	"search_basic": {"label": "Search for a basic land", "targets": ["to_hand", "to_battlefield"]},
	"tap": {"label": "Tap", "only": true, "targets": ["creature", "artifact", "land", "permanent", "that_creature"]},
	"untap": {"label": "Untap", "only": true, "targets": ["creature", "land", "permanent", "that_creature"]},
	"regenerate": {"label": "Regenerate", "targets": ["self", "creature"]},
	"prevent": {"label": "Prevent damage", "amount": [1, 20], "x": true, "targets": ["any", "creature"]},
	"fog": {"label": "Prevent all combat damage"},
	"raise": {"label": "Return a card from your graveyard",
		"targets": ["creature_card", "creature_card_to_battlefield", "any_card", "creature_card_to_top",
			"any_card_to_top"]},
	"extra_turn": {"label": "Take an extra turn"},
	"shield": {"label": "Prevent damage from a color", "shield": true},
	"set_pt": {"label": "Set base power/toughness", "base": true, "targets": ["creature", "self"]},
	"switch_pt": {"label": "Switch power and toughness", "targets": ["creature", "self"]},
	"landwalk": {"label": "Give landwalk", "land": true, "targets": ["creature", "self"]},
	"lose_keyword": {"label": "Lose a keyword", "lose": true, "targets": ["creature"]},
	"animate": {"label": "Become a creature", "base": true, "subtype": true},
	"draw_later": {"label": "Draw cards next upkeep", "amount": [1, 3]},
	"search": {"label": "Search for a card", "amount": [1, 3], "x": true, "where": true, "named": true,
		"targets": ["a_creature", "an_artifact", "an_enchantment", "a_land", "a_card", "a_named"]},
}
## Where "Search for a card" looks, and how each is said.
const SEARCH_WHERE := ["library", "graveyard", "library_top"]
const SEARCH_WHERE_WORDS := {"library": "in your library", "graveyard": "in your graveyard",
	"library_top": "in your library, put on top"}
## What "Shuffle into library" takes back, and how each is said.
const SHUFFLE_FROM := ["hand_and_graveyard", "graveyard", "hand"]
const SHUFFLE_FROM_WORDS := {"hand_and_graveyard": "hand and graveyard", "graveyard": "graveyard",
	"hand": "hand"}
## What a created token does at the beginning of the next end step (`ends`
## in a token effect; the first — it stays — is the default).
const TOKEN_ENDS := ["", "sacrifice", "exile"]
const TOKEN_ENDS_WORDS := {"": "stays", "sacrifice": "sacrificed at end of turn", "exile": "exiled at end of turn"}
## A COLOR OR TYPE FILTER on what an effect may target or sweep (`only` in
## an effect whose entry says "only"; "" — the default — is no filter):
## "destroy target white permanent", "destroy all nonblack creatures".
const ONLY := ["", "white", "blue", "black", "red", "green", "nonwhite", "nonblue", "nonblack", "nonred",
	"nongreen", "artifact", "nonartifact", "nonland"]
## The targets a filter may narrow: one creature or permanent, or a sweep.
const ONLY_TARGETS := ["creature", "permanent", "creatures", "each_creature", "yours", "all"]
## The targets that name a player an effect before it targeted.
const PLAYER_TARGETS := ["player", "opponent"]
## The keywords that hinder the creature that has them.
const HINDERING := ["defender", "must_attack", "phasing"]
## Effects a triggered ability may not use.
const NOT_IN_TRIGGERS := ["counter", "fog", "counter_ability", "shield", "animate"]
## Effects a spell may not use (it has no card on the battlefield).
const NOT_IN_SPELLS := ["sacrifice_self", "exile_self"]
## Effects only a triggered ability may use.
const TRIGGER_ONLY := ["return_self", "extra_mana"]
## The effects whose X is worked out as they resolve (the others read X
## themselves).
const VARYING_X := ["lose_life", "drain", "token", "mill", "discard", "discard_own", "discard_random"]
## Effects only an activated ability may use (a land or an artifact
## becoming a creature for the turn).
const ACTIVATED_ONLY := ["animate"]
## Effects an activated ability may not use: mana is made by a mana ability
## (CR 605: it never uses the stack and is used while paying).
const NOT_IN_ACTIVATED := ["add_mana"]
## The effects that help what they target (a trigger offers its own side
## first for these, the opponent's first for the rest — the computer takes
## the first).
const HELPFUL := ["pump", "counters", "regenerate", "untap", "draw", "gain_life", "prevent", "landwalk", "raise"]
## How each target is said.
const TARGET_WORDS := {"any": "any target", "creature": "target creature",
	"creature_attacking": "target attacking creature", "creature_flying": "target creature with flying",
	"creature_nonblack": "target nonblack creature", "creature_nonartifact": "target nonartifact creature",
	"creature_tapped": "target tapped creature", "player": "target player", "opponent": "target opponent",
	"each_opponent": "each opponent", "each_player": "each player", "each_creature": "each creature",
	"each_creature_and_player": "each creature and each player", "you": "you",
	"artifact": "target artifact", "enchantment": "target enchantment",
	"artifact_or_enchantment": "target artifact or enchantment", "land": "target land",
	"nonbasic_land": "target nonbasic land", "permanent": "target permanent",
	"creatures": "creatures", "creatures_flying": "creatures with flying", "artifacts": "artifacts",
	"enchantments": "enchantments", "lands": "lands", "self": "this card", "yours": "creatures you control",
	"all": "all creatures", "spell": "target spell", "creature_spell": "target creature spell",
	"noncreature_spell": "target noncreature spell",
	"creature_card": "target creature card in your graveyard",
	"creature_card_to_battlefield": "target creature card in your graveyard, to the battlefield",
	"any_card": "target card in your graveyard", "that_player": "that player",
	"creature_card_to_top": "target creature card in your graveyard, on top of your library",
	"any_card_to_top": "target card in your graveyard, on top of your library",
	"that_creature": "that creature", "divided": "divided among any number of targets",
	"to_hand": "put it into your hand",
	"to_battlefield": "put it onto the battlefield", "ability": "target activated ability",
	"a_creature": "a creature card", "an_artifact": "an artifact card", "an_enchantment": "an enchantment card",
	"a_land": "a land card", "a_card": "a card", "a_named": "a card named..."}

const LIMITS := {"abilities": 6, "effects": 4, "name": 40, "artist": 60, "set_name": 40,
	"flavor": 200, "subtypes": 3, "subtype": 20, "power": [0, 99], "pt_change": [-10, 10]}


# --------------------------------------------------------- the catalogue --

static func target_words(target: String) -> String:
	return String(TARGET_WORDS.get(target, target.replace("_", " ")))


static func static_info(what: String) -> Dictionary:
	return STATICS.get(what, {})


## Every count id ("creature_you", "swamp_all", "hand_opponent", …).
static func counts() -> Array[String]:
	var out: Array[String] = []
	for what in COUNT_WHAT:
		for whose in COUNT_WHOSE:
			out.append("%s_%s" % [what, whose])
	return out


## How a count is said: "creature you control", "Swamp on the battlefield",
## "card in your opponents' hands" — [param plural]: "Swamps you control".
static func count_words(id: String, plural := false) -> String:
	var cut := id.rfind("_")
	var what := id.left(cut)
	var whose := id.substr(cut + 1)
	if what in ["hand", "graveyard"]:
		var place: String = {"you": "your %s", "opponent": "your opponents' %ss", "all": "all %ss"}.get(whose, "%s")
		return ("cards in " if plural else "card in ") + place % what
	var noun := what.capitalize() if LANDS.has(what) else what
	if plural:
		noun += "s"
	return noun + String({"you": " you control", "opponent": " your opponents control",
		"all": " on the battlefield"}.get(whose, ""))


## The picker's words for every count: {id: "for each creature you control"}.
static func count_labels() -> Dictionary:
	var out := {}
	for id in counts():
		out[id] = "for each " + count_words(id)
	return out


## How many of [param id] there are, for the player [param controller].
static func count_of(game: MtgGame, controller: int, id: String) -> int:
	var cut := id.rfind("_")
	var what := id.left(cut)
	var whose := id.substr(cut + 1)
	var n := 0
	for pid in game.players.size():
		if (whose == "you" and pid != controller) or (whose == "opponent" and pid == controller):
			continue
		match what:
			"hand": n += game.players[pid].hand.size()
			"graveyard": n += game.players[pid].graveyard.size()
			_:
				for inst in game.players[pid].battlefield:
					if inst.phased_out:
						continue
					match what:
						"creature": n += 1 if inst.is_creature() else 0
						"land": n += 1 if inst.is_land() else 0
						"artifact": n += 1 if inst.is_type(Mtg.CardType.ARTIFACT) else 0
						_: n += 1 if inst.is_land() and inst.has_subtype(what) else 0
	return n


## Whether the effect [param id] is offered in an ability of [param kind]
## (a mode of a "Choose one —" spell is a "spell").
static func effect_allowed(id: String, kind: String) -> bool:
	return EFFECTS.has(id) and not (kind == "trigger" and id in NOT_IN_TRIGGERS) \
		and not (kind != "activated" and id in ACTIVATED_ONLY) \
		and not (kind == "activated" and id in NOT_IN_ACTIVATED) \
		and not (kind == "spell" and id in NOT_IN_SPELLS) \
		and not (kind != "trigger" and id in TRIGGER_ONLY)


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
	if info.has("from"):
		e["from"] = SHUFFLE_FROM[0]
	if info.has("where"):
		e["where"] = SEARCH_WHERE[0]
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
	if not (_list(s.get("protection")).is_empty() and _list(s.get("landwalk")).is_empty()) \
			and not types.has("creature"):
		out.append("Protection and landwalk are for creatures.")
	for l in _list(s.get("landwalk")):
		if not LANDS.has(l):
			out.append("Landwalk is plainswalk, islandwalk, swampwalk, mountainwalk or forestwalk.")
	# A card that keeps a game card's rules: whether the pool has that card
	# now is not asked here ([method pool_problems]) — a card is the same
	# card whichever packs are switched on.
	var kept := String(s.get("rules_of", "")).strip_edges()
	if s.has("rules_of") and (kept == "" or kept.length() > 60):
		out.append("rules_of names a game card (1 to 60 characters).")
	_look_problems(out, s.get("look", {}))
	_rule_problems(out, s.get("rules", {}), types)
	if s.get("rules") is Dictionary and (s["rules"] as Dictionary).has("enters_x_counters") \
			and not cost.contains("{X}"):
		out.append("Enters with X +1/+1 counters needs {X} in the mana cost.")
	# An Aura on a creature may give it an ability or watch it for a trigger.
	var hosts := _enchants_creature(s)
	var grants: bool = s.get("abilities") is Array and (s["abilities"] as Array).any(func(a: Variant) -> bool:
		return a is Dictionary and a.get("enchanted", false) is bool and bool(a.get("enchanted", false)))
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
				_effects_problems(out, where, a.get("effects"), "spell", cost.contains("{X}"), types.has("creature"),
					"sorcery" if types.has("sorcery") else "")
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
							types.has("creature"), "sorcery" if types.has("sorcery") else "")
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
				var enchanted := bool(a.get("enchanted", false))
				if enchanted and shared != "":
					out.append(where + "it is shared with a creature type or given to the enchanted creature, not both.")
				elif enchanted and not hosts:
					out.append(where + "only an Aura that enchants a creature gives its creature an ability.")
				if removes > 0 and removes <= 3 and not types.has("creature") and shared == "" and not enchanted:
					out.append(where + "removing +1/+1 counters is for a creature.")
				# {X} is a price only when an effect reads it: "{X}: deal 1
				# damage" is paid with X = 0, for nothing.
				var free := a_cost == "" or (cost_ok(a_cost) and ManaCost.parse(a_cost).mana_value() == 0
					and not (a_cost.contains("{X}") and _reads_x(a.get("effects"))))
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
					types.has("creature") or shared != "" or enchanted)
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
				elif bool(a.get("enchanted", false)):
					if not hosts:
						out.append(where + "only an Aura that enchants a creature watches its creature.")
					elif not when in HOST_TRIGGERS:
						out.append(where + "the enchanted creature is watched for attacking, blocking and dealing damage.")
				elif when in CREATURE_TRIGGERS and not types.has("creature"):
					out.append(where + "only a creature has \"%s\"." % String(TRIGGERS[when]).replace("CARDNAME", "it"))
				var choice := String(a.get("choice", "must"))
				if not TRIGGER_CHOICES.has(choice):
					out.append(where + "it is done always, \"you may\", or with \"up to one target\".")
				elif choice == "up_to" and _aimed_count(a.get("effects")) != 1:
					out.append(where + "\"up to one target\" needs exactly one effect with a target.")
				# A mandatory loop: each token it makes arrives and triggers it again.
				if when == "creature_enters" and a.get("effects") is Array and (a["effects"] as Array).any(
						func(e: Variant) -> bool: return e is Dictionary and String(e.get("effect", "")) == "token"):
					out.append(where + "it cannot create creature tokens: each token would trigger it again, without end.")
				var ids: Array = []
				for e in a.get("effects") if a.get("effects") is Array else []:
					ids.append(String(e.get("effect", "")) if e is Dictionary else "")
				# The loops that feed themselves.
				if when == "land_tapped" and ids.has("untap"):
					out.append(where + "it cannot untap: the land would be tapped for mana again, without end.")
				if ids.has("extra_mana") and (ids.size() > 1 or choice != "must"):
					out.append(where + "the extra mana is the whole ability: no other effect, no \"you may\".")
				if when in DAMAGE_TRIGGERS and not bool(a.get("enchanted", false)) and ids.has("damage"):
					out.append(where + "it cannot deal damage: that damage would trigger it again, without end.")
				_effects_problems(out, where, a.get("effects"), "trigger", false, types.has("creature"), when)
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
					if int(a.get("power", 0)) == 0 and int(a.get("toughness", 0)) == 0 \
							and _list(a.get("keywords")).is_empty():
						out.append(where + "choose what it does: +P/+T or a keyword.")
				if info.get("subtype", false) and not _word_ok(String(a.get("subtype", ""))):
					out.append(where + "name the creature type, one word.")
				if info.get("spell_type", false) and not (COST_SPELL_TYPES if what == "cost_more" else SPELL_TYPES).has(
						String(a.get("spell_type", ""))):
					out.append(where + "choose the spell type.")
				if info.has("amount"):
					var n := int(a.get("amount", 1))
					if n < int(info["amount"][0]) or n > int(info["amount"][1]):
						out.append(where + {"cost_less": "it costs {1} to {3} less.",
							"cost_more": "it costs {1} to {3} more."}.get(what, "the amount is {1} to {3}."))
				if a.has("who") and (not info.get("who", false) or not COST_WHO.has(String(a["who"]))):
					out.append(where + "it taxes everyone's spells or your opponents'.")
				if String(a.get("spell_color", "")) != "" and (not info.get("spell_color", false)
						or not PROTECTIONS.has(String(a["spell_color"]))):
					out.append(where + "the spell color is white, blue, black, red or green.")
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
						and not bool(a.get("frozen", false)) and not grants:
					out.append(where + "choose what the Aura does.")
			_:
				out.append(where + "unknown kind \"%s\"." % kind)
	if kept != "" and modals + auras > 0:
		out.append("A card that keeps %s's rules takes abilities on top, not a second \"Choose one\" or Aura." % kept)
	if spell_like and spells + modals == 0 and kept == "":
		out.append("An instant or a sorcery needs a spell effect.")
	if modals > 1 or (modals == 1 and spells > 0):
		out.append("A \"Choose one\" spell has its modes and nothing else.")
	if modals > 0 and (s.get("rules", {}) as Dictionary).has("buyback"):
		out.append("Buyback is not offered on a \"Choose one\" spell.")
	if auras > 1:
		out.append("An Aura enchants one thing: one Aura ability.")
	return out


## THE CARD WHOSE RULES IT KEEPS (`rules_of`): the game's own card of
## that name, null when the spec names none or the pool has none such now.
static func base_of(spec: Dictionary) -> CardData:
	var base_name := String(spec.get("rules_of", "")).strip_edges() if spec.get("rules_of", "") is String else ""
	return CardRegistry.game_card(base_name) if base_name != "" else null


## WHAT THE POOL OF NOW SAYS of a card that keeps a game card's rules
## ([] for any other card): that card must be in the pool, and what its
## rules lean on stays as it has it — its card types, an {X} in its cost,
## a power and toughness its rules set. Asked on every load of the pool
## and by the editor; never kept with the card's file.
static func pool_problems(spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if not spec is Dictionary or not spec.get("rules_of", "") is String:
		return out
	var s: Dictionary = spec
	var base_name := String(s.get("rules_of", "")).strip_edges()
	if base_name == "":
		return out
	var base := base_of(s)
	if base == null:
		out.append("It keeps the rules of \"%s\", a card the game does not have now (is its pack switched on?)." % base_name.left(60))
		return out
	var mask := 0
	for t in _list(s.get("types")):
		mask |= int(TYPES.get(t, 0))
	if mask != base.types:
		out.append("A card that keeps %s's rules keeps its card types." % base.card_name)
	var cost := String(s.get("cost", "")) if s.get("cost", "") is String else ""
	var base_cost := base.cost.text if base.cost != null else ""
	if (mask & Mtg.CardType.LAND) == 0 and base_cost.contains("{X}") != cost.contains("{X}"):
		out.append("%s's rules read %s: the mana cost %s." % [base.card_name,
			"X" if base_cost.contains("{X}") else "no X",
			"keeps {X}" if base_cost.contains("{X}") else "has no {X}"])
	if (s.get("rules") is Dictionary and (s["rules"] as Dictionary).has("pt_count")) and base.characteristic_definition.is_valid():
		out.append("%s's rules set its power and toughness already." % base.card_name)
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
	for key in ["rarity", "artist", "set_name", "flavor", "rules_of"]:
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
				_want(out, rules, id, {"flag": "yes", "amount": "whole", "cost": "text", "count": "text"}[kind],
					false, "rules.")
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
					"shared", "enchant", "protection", "choice", "who", "spell_color"]:
				_want(out, a, key, "text", true, where)
			for key in ["tap", "sacrifice", "control", "pacify", "frozen", "enchanted"]:
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


## Whether the card is an Aura that enchants a creature.
static func _enchants_creature(s: Dictionary) -> bool:
	var abilities: Variant = s.get("abilities", [])
	return abilities is Array and (abilities as Array).any(func(a: Variant) -> bool:
		return a is Dictionary and String(a.get("kind", "")) == "enchant" \
			and String(a.get("enchant", "creature")) == "creature")


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
		for key in ["target", "color", "subtype", "land", "from", "where", "named", "only", "ends", "per"]:
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
			"count":
				if not counts().has(String(rules[id])):
					out.append("%s: choose what it counts." % info["label"])
			"cost":
				if not cost_ok(String(rules[id])) or String(rules[id]).contains("{X}") \
						or ManaCost.parse(String(rules[id])).mana_value() == 0:
					out.append("%s needs a mana cost like {1}{R}." % info["label"])


## Whether an effect of [param effects] uses the X paid.
static func _reads_x(effects: Variant) -> bool:
	return effects is Array and (effects as Array).any(func(e: Variant) -> bool:
		return e is Dictionary and e.get("x", false) is bool and bool(e.get("x", false)))


## Whether the effect [param e] chooses a target of its own ("that player"
## rides the target of an effect before it).
static func _aims(e: Variant) -> bool:
	if not e is Dictionary or not EFFECTS.has(String(e.get("effect", ""))):
		return false
	var info: Dictionary = EFFECTS[String(e["effect"])]
	if not info.has("targets"):
		return false
	var target := String(e.get("target", (info["targets"] as Array)[0]))
	return target == "any" or target_words(target).begins_with("target ")


## How many effects of [param effects] choose a target.
static func _aimed_count(effects: Variant) -> int:
	var n := 0
	if effects is Array:
		for e in effects:
			if _aims(e):
				n += 1
	return n


## What a card would do that its maker may not mean ([] when nothing): it
## still builds and plays — these are said beside the problems, never
## instead of them.
static func warnings(spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if not spec is Dictionary or not problems(spec).is_empty():
		return out
	var s: Dictionary = spec
	var types := _list(s.get("types"))
	var rules: Dictionary = s.get("rules") if s.get("rules") is Dictionary else {}
	if types.has("creature") and int(s.get("toughness", 1)) <= 0 and not rules.has("enters_counters") \
			and not rules.has("enters_x_counters") and not rules.has("pt_count"):
		out.append("A creature with toughness 0 dies as it arrives, unless something raises it.")
	if String(s.get("cost", "")).contains("{X}"):
		var read := rules.has("enters_x_counters")
		for a in s.get("abilities", []):
			if String(a.get("kind", "")) == "spell":
				read = read or _reads_x(a.get("effects"))
			elif String(a.get("kind", "")) == "modal":
				for mode in a.get("modes", []):
					read = read or _reads_x(mode.get("effects"))
		if not read:
			out.append("Nothing uses the {X} in the mana cost.")
	var at := 0
	for a in s.get("abilities", []):
		at += 1
		if String(a.get("kind", "")) == "activated" and String(a.get("cost", "")).contains("{X}") \
				and not _reads_x(a.get("effects")):
			out.append("Ability %d: nothing uses the {X} in its cost." % at)
	return out


## [param when]: "sorcery" for a sorcery's spell, a trigger's own `when`.
static func _effects_problems(out: Array[String], where: String, effects: Variant, context: String,
		has_x: bool, creature := true, when := "") -> void:
	if not effects is Array or (effects as Array).is_empty():
		out.append(where + "add at least one effect.")
		return
	if (effects as Array).size() > LIMITS["effects"]:
		out.append(where + "at most %d effects." % LIMITS["effects"])
	# An effect before this one targeted a player — or the trigger names one.
	var named_player := context == "trigger" and when in EVENT_PLAYER_TRIGGERS
	for e in effects:
		if not e is Dictionary or not EFFECTS.has(String(e.get("effect", ""))):
			out.append(where + "unknown effect.")
			continue
		var id := String(e["effect"])
		var info: Dictionary = EFFECTS[id]
		if not effect_allowed(id, context):
			var said := "%s is for an activated ability."
			if context == "trigger":
				said = "%s is not offered in a triggered ability."
			elif id in NOT_IN_ACTIVATED:
				said = "%s is a mana ability's: add one with + Mana."
			elif id in TRIGGER_ONLY:
				said = "%s is for a triggered ability."
			elif id in NOT_IN_SPELLS:
				said = "%s is for a card on the battlefield."
			out.append(where + said % info["label"])
		# A sorcery is cast with nothing else on the stack and no combat on.
		if when == "sorcery" and id in ["counter", "counter_ability"]:
			out.append(where + "a sorcery cannot counter: nothing is on the stack when it is cast. Make it an instant.")
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
		if info.has("from") and not SHUFFLE_FROM.has(String(e.get("from", SHUFFLE_FROM[0]))):
			out.append(where + "shuffle the hand and graveyard, the graveyard or the hand.")
		if info.has("where") and not SEARCH_WHERE.has(String(e.get("where", SEARCH_WHERE[0]))):
			out.append(where + "search the library or the graveyard.")
		if info.has("named") and String(e.get("target", "")) == "a_named":
			var wanted := String(e.get("named", "")).strip_edges()
			if wanted == "" or wanted.length() > LIMITS["name"] or not _name_ok(wanted):
				out.append(where + "name the card it looks for (letters, digits, spaces and ' , -).")
		var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
		if info.has("targets") and not (info["targets"] as Array).has(target):
			out.append(where + "%s cannot target \"%s\"." % [info["label"], target])
		if target == "creature_attacking" and when == "sorcery":
			out.append(where + "a sorcery finds no attacking creature: it is cast outside combat. Make it an instant.")
		elif target == "creature_attacking" and when in QUIET_TRIGGERS:
			out.append(where + "no creature is attacking when this triggers.")
		if id == "return_self" and context == "trigger" and not when in ["dies", "to_graveyard"]:
			out.append(where + "it returns from the graveyard: for \"dies\" or \"is put into a graveyard\".")
		if id == "extra_mana" and context == "trigger" and when != "land_tapped":
			out.append(where + "the extra mana is for \"whenever a player taps a land for mana\".")
		if target == "that_creature" and not (context == "trigger" and when == "damage_creature"):
			out.append(where + "\"that creature\" is the one dealt damage: for \"deals damage to a creature\".")
		if target == "divided" and (context == "trigger" or bool(e.get("x", false))):
			out.append(where + "divided damage is a fixed amount, for a spell or an activated ability.")
		var per := String(e.get("per", ""))
		if per != "":
			if not info.get("per", false) or not counts().has(per):
				out.append(where + "%s takes no such \"for each\"." % info["label"])
			elif bool(e.get("x", false)) or target == "divided":
				out.append(where + "an amount is X, divided, or \"for each\": one of them.")
		if info.has("where") and String(e.get("where", "")) == "library_top" \
				and (bool(e.get("x", false)) or int(e.get("amount", 1)) != 1):
			out.append(where + "one card goes on top of the library.")
		if target == "that_player" and not named_player:
			out.append(where + "\"that player\" follows an effect that targets a player.")
		if target in PLAYER_TARGETS:
			named_player = true
		var only := String(e.get("only", ""))
		if only != "":
			if not info.get("only", false) or not ONLY.has(only):
				out.append(where + "%s takes no such color or type filter." % info["label"])
			elif not target in ONLY_TARGETS:
				out.append(where + "a color or type filter goes with a creature, a permanent or a sweep of creatures.")
			elif only == "nonland" and target != "permanent":
				out.append(where + "\"nonland\" goes with target permanent.")
		if e.has("ends") and (not info.has("token") or not TOKEN_ENDS.has(String(e["ends"]))):
			out.append(where + "a token stays, or is sacrificed or exiled at end of turn.")
		if info.has("pt") and not bool(e.get("x", false)) and int(e.get("power", 0)) == 0 \
				and int(e.get("toughness", 0)) == 0 and _list(e.get("keywords")).is_empty():
			out.append(where + "choose what it does: +P/+T or a keyword.")
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
			elif target == "each_opponent" and id == "damage":
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
			out.append(where + "giving only defender, phasing or \"attacks each combat\" is an Aura's.")
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
	if _rx("^(\\{(?:[0-9]|[1-9][0-9]|[WUBRGX])\\})+$").search(cost) == null:
		return false
	return ManaCost.parse(cost).mana_value() <= 16 and cost.count("{") <= 8


static func _name_ok(name: String) -> bool:
	return _rx("^[A-Za-z0-9][A-Za-z0-9 ',\\-]*$").search(name) != null \
		and not name.contains("  ")


static func _word_ok(word: String) -> bool:
	return _rx("^[A-Za-z]{1,20}$").search(word) != null


## Each pattern compiled once (a spec is checked on every keystroke).
static var _patterns: Dictionary = {}


static func _rx(pattern: String) -> RegEx:
	if not _patterns.has(pattern):
		_patterns[pattern] = RegEx.create_from_string(pattern)
	return _patterns[pattern]


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
	var data: CardData
	var kept := String(spec.get("rules_of", "")).strip_edges() != ""
	if kept:
		# THE RULES OF A GAME CARD, WHOLE: that card under this name — its
		# own abilities, the game's script — with this card's cost, power
		# and toughness and subtypes, and whatever the spec adds on top.
		var base := base_of(spec)
		if base == null:
			# The pool has no such card now ([method pool_problems] says so
			# and the pool leaves the card out): its frame, to be looked at.
			var shown := CardData.new(name, String(spec.get("cost", "")), types)
			if types & Mtg.CardType.CREATURE:
				shown.pt(int(spec.get("power", 1)), int(spec.get("toughness", 1)))
			shown.with_subtypes(_list(spec.get("subtypes")))
			shown.oracle(rules_text(spec))
			shown.flavor_text = String(spec.get("flavor", ""))
			return shown
		data = base.copy_named(name)
		data.artist = ""   # nothing of the game card's picture comes with it
		data.set_code = ""
		types = data.types
		if (types & Mtg.CardType.LAND) == 0:
			data.cost = ManaCost.parse(String(spec.get("cost", "")))
		if (types & Mtg.CardType.CREATURE) and not base.characteristic_definition.is_valid():
			data.pt(int(spec.get("power", base.power)), int(spec.get("toughness", base.toughness)))
		if spec.has("subtypes") and (types & (Mtg.CardType.CREATURE | Mtg.CardType.LAND)):
			data.subtypes.clear()
	else:
		data = CardData.new(name, String(spec.get("cost", "")), types)
		if types & Mtg.CardType.CREATURE:
			data.pt(int(spec.get("power", 1)), int(spec.get("toughness", 1)))
	if _list(spec.get("supertypes")).has("legendary"):
		data.with_supertypes(Mtg.Supertype.LEGENDARY)
	if not kept or data.subtypes.is_empty():
		data.with_subtypes(_list(spec.get("subtypes")))
	var kws: Array = []
	for k in _list(spec.get("keywords")):
		if not data.keywords.has(KEYWORDS[k]):
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
	if (types & Mtg.CardType.LAND) and not kept:
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
			"shroud":
				data.static_ability(StaticAbility.new(func(_g: MtgGame, s: CardInstance) -> void:
					s.cur_shroud = true, "Shroud.").changing_abilities())
			"enters_x_counters":
				data.as_it_enters(_enter_with_x)
			"pt_count":
				var counted := String(value)
				data.static_ability(StaticAbility.new(func(g: MtgGame, s: CardInstance) -> void:
					var n := count_of(g, s.controller_id, counted)
					s.cur_power = n
					s.cur_toughness = n,
					"Power and toughness equal to the number of %s." % count_words(counted, true)).setting_base_pt())
			"no_untap":
				data.static_ability(StaticAbility.new(func(_g: MtgGame, s: CardInstance) -> void:
					s.cur_skips_untap = true,
					"%s doesn't untap during your untap step." % data.card_name))


## "Enters with X +1/+1 counters": the X of the spell that put it there
## (Rock Hydra's shape); any other arrival brings X = 0.
static func _enter_with_x(g: MtgGame, inst: CardInstance, _pid: int) -> void:
	var x := int(inst.memory.get("x_value", 0))
	if x > 0:
		g.add_counters(inst, "+1/+1", x)


## "At the beginning of your upkeep, sacrifice CARDNAME unless you pay
## COST." (Conversion's shape.)
static func _upkeep_cost(name: String, cost: String) -> TriggeredAbility:
	var toll := ManaCost.parse(cost)
	return TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		func(game: MtgGame, source: CardInstance, _ev: GameEvent) -> void:
			if source.zone != Mtg.Zone.BATTLEFIELD:
				return
			if EffectBase.unless_paid(game, game.controller_acting_for(source), toll,
					"Pay %s to keep %s?" % [cost, name]):
				return
			game.sacrifice_permanent(source),
		"At the beginning of your upkeep, sacrifice %s unless you pay %s." % [name, cost],
		func(_game: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
			return int(ev.data.get("player", -1)) == source.controller_id)


static func _add_ability(data: CardData, a: Dictionary) -> void:
	var name := data.card_name
	match String(a["kind"]):
		"spell":
			for effect in effects_of(a["effects"]):
				data.spell(effect)
		"modal":
			var helps: Array = []
			for mode in a["modes"]:
				var effects: Array = effects_of(mode["effects"])
				var flags: Array = []
				for e in mode["effects"]:
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
	var enchanted := bool(a.get("enchanted", false))
	var effects: Array = effects_of(a["effects"])
	var kinds: Array = ["creature"] if shared != "" or enchanted else _kinds_of(data)
	var granted := shared != "" or enchanted
	var own_text := _sentence(ability_text(a, "this creature" if granted else data.card_name, granted, kinds))
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
	if enchanted:
		# The Aura's creature has it as its own (Hermetic Study, Fire Whip).
		data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
			var host := game.find_instance(source.attached_to) if source.attached_to != -1 else null
			if host != null and host.zone == Mtg.Zone.BATTLEFIELD and not host.phased_out:
				host.cur_activated_abilities.append(ability.granted_by(source)),
			_sentence(ability_text(a, data.card_name))).changing_abilities())
		return
	if shared == "":
		data.activated(ability)
		return
	data.static_ability(StaticAbility.new(func(game: MtgGame, source: CardInstance) -> void:
		for inst in game.all_battlefield():
			if not inst.phased_out and inst.is_creature() and inst.has_subtype(shared):
				# Each card that shares it gives its own copy: two of them,
				# two "once each turn" uses.
				inst.cur_activated_abilities.append(ability.granted_by(source)),
		_sentence(ability_text(a, data.card_name))).changing_abilities())


## The basic land types of a land [param spec], in their order.
static func _basic_types(spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if _list(spec.get("types")).has("land"):
		for sub in _list(spec.get("subtypes")):
			if BASIC_COLORS.has(sub.to_lower()) and not out.has(sub.to_lower()):
				out.append(sub.to_lower())
	return out


## The card's types by their catalogue words ("creature", "artifact", …).
static func _kinds_of(data: CardData) -> Array:
	var out: Array = []
	for word in TYPES:
		if data.is_type(int(TYPES[word])):
			out.append(word)
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
			# Every target looked at: a creature or a card on the right side
			# is a fuller aim than a player ("any target" lists players too).
			for ref in spec.legal_targets(game, inst):
				var mine := false
				if ref.is_player:
					mine = ref.player_id == pid
				else:
					var target := game.find_instance(ref.instance_id)
					mine = target != null and (target.controller_id == pid or target.zone == Mtg.Zone.GRAVEYARD
						and target.owner_id == pid)
				if mine == helpful:
					side = true
					aimed = aimed or not ref.is_player
			if not side:
				fits = false
				break
		var score := (2 if aimed else 1) if fits else 0
		if score > best_score:
			best = m
			best_score = score
	return maxi(best, 0)


## The effects of one ability (a spell, a mode, an activated ability, a
## trigger), in order. "That player" rides the target of the nearest effect
## before it that targeted a player: it is told which target that is.
static func effects_of(list: Array) -> Array:
	var out: Array = []
	var slot := 0
	var player_slot := -1
	for e in list:
		var effect := effect_of(e)
		if effect is ThatPlayer:
			if (effect as ThatPlayer).wants_player:
				(effect as ThatPlayer).slot = player_slot
		elif effect.target_spec != null:
			if String(e.get("target", "")) in PLAYER_TARGETS:
				player_slot = slot
			slot += 1
		out.append(effect)
	return out


## A stock effect, ready to resolve, from one effect of a spec.
static func effect_of(e: Dictionary) -> EffectBase:
	var id := String(e["effect"])
	var info: Dictionary = EFFECTS[id]
	var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
	if target == "that_player":
		var as_player := e.duplicate()
		as_player["target"] = "player"
		return ThatPlayer.new(effect_of(as_player), _helpful(e))
	if target == "that_creature":
		var as_creature := e.duplicate()
		as_creature["target"] = "creature"
		var that := ThatPlayer.new(effect_of(as_creature), _helpful(e))
		that.wants_player = false
		return that
	# An amount worked out as it resolves: "for each …", or an X the stock
	# effect does not read itself.
	if String(e.get("per", "")) != "" or (bool(e.get("x", false)) and id in VARYING_X):
		return Varying.new(e)
	var only := String(e.get("only", "")) if target in ONLY_TARGETS else ""
	var x := bool(e.get("x", false))
	var n := 0 if x else int(e.get("amount", 1))
	var kws: Array = []
	for k in _list(e.get("keywords")):
		if KEYWORDS.has(k):
			kws.append(KEYWORDS[k])
	match id:
		"damage":
			match target:
				"you":
					var own := DamageEffect.new(n).to_controller()
					return own.x_damage() if x else own
				"divided":
					return DamageEffect.new(0).any_target().divided(n)
				"creature", "creature_attacking", "creature_flying":
					var hit := DamageEffect.new(n).target_creature(aim_words(target, only),
						_only_filter(only) if only != "" else _creature_filter(target))
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
					var each := DamageAllEffect.new(n, aim_words(target, only), _only_filter(only))
					return each.x_damage() if x else each
				"each_creature_and_player":
					var all := DamageAllEffect.new(n, "each creature").and_each_player()
					return all.x_damage() if x else all
			var any := DamageEffect.new(n).any_target()
			return any.x_damage() if x else any
		"draw":
			if target == "each_player":
				return EachPlayerDraws.new(n, x)
			var draw := DrawEffect.new(n).target_player() if target == "player" else DrawEffect.new(n)
			return draw.x_cards() if x else draw
		"shuffle_in":
			var back := ShuffleIn.new(String(e.get("from", SHUFFLE_FROM[0])), target)
			if target == "player":
				back.target_spec = TargetSpec.player()
			return back
		"gain_life":
			var gain := GainLifeEffect.new(n).target_player() if target == "player" else GainLifeEffect.new(n)
			return gain.x_amount() if x else gain
		"lose_life":
			if target == "each_opponent":
				return EachOpponent.new("lose", n)
			if target == "you":
				return GainLifeEffect.new(-n)
			var loss := GainLifeEffect.new(-n).target_player()
			if target == "opponent":
				loss.target_spec = TargetSpec.opponent()
			return loss
		"drain":
			return EachOpponent.new("drain", n) if target == "each_opponent" else DrainEffect.new(n)
		"destroy":
			return DestroyEffect.new(_spec_for(target, only))
		"destroy_all":
			if only != "":
				var narrow := _only_filter(only)
				return DestroyAllEffect.new("all " + aim_words(target, only),
					func(i: CardInstance) -> bool: return i.is_creature() and bool(narrow.call(i)))
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
			return ExileEffect.new(_spec_for(target, only))
		"bounce":
			return ReturnToHandEffect.new(_spec_for(target, only))
		"pump":
			var pump := PumpEffect.new(int(e.get("power", 0)), int(e.get("toughness", 0)), kws)
			if target == "self":
				pump.self_buff()
			return pump.x_power() if x else pump
		"mass_pump":
			var mass := MassPumpEffect.new(int(e.get("power", 0)), int(e.get("toughness", 0)),
				aim_words(target, only), kws)
			if only != "":
				mass.with_filter(_only_filter(only))
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
			var ends := String(e.get("ends", ""))
			var token: CreateTokenEffect
			if ends == "":
				token = CreateTokenEffect.new(subtype, int(e.get("power", 1)), int(e.get("toughness", 1)),
					int(COLORS[String(e.get("color", "colorless"))]), subtype.to_lower(), n)
			else:
				token = EndingTokens.new(subtype, int(e.get("power", 1)), int(e.get("toughness", 1)),
					int(COLORS[String(e.get("color", "colorless"))]), subtype.to_lower(), n, ends == "exile")
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
			var loses := LoseAbilityEffect.new([KEYWORDS[lost[0]]], String(KEYWORD_WORDS[lost[0]]))
			loses.ai_helpful = _helpful(e)
			return loses
		"animate":
			var sub := String(e.get("subtype", "")).to_lower()
			return AnimateSelfEffect.new(Mtg.CardType.CREATURE, int(e.get("power", 2)), int(e.get("toughness", 2)),
				[sub] if sub != "" else [])
		"draw_later":
			return DelayedDrawEffect.new(n)
		"search":
			var filter := _search_filter(target, String(e.get("named", "")))
			var place := String(e.get("where", SEARCH_WHERE[0]))
			if place == "library_top":
				return TopTutor.new(filter, search_words(e, target, 1, false))
			if place == "library" and not x and n <= 1:
				# One card off the library: the duel's own library picker
				# opens before the cast, as for Demonic Tutor.
				return SearchLibraryEffect.new(search_words(e, target, 1, false), filter)
			return FindCards.new(place, maxi(n, 1), x, filter, search_words(e, target, n, x))
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
		"discard_own":
			var own_pick := OwnDiscard.new(n, target == "you")
			if target == "opponent":
				own_pick.target_spec = TargetSpec.opponent()
			return own_pick
		"return_self":
			return ReturnSelf.new()
		"extra_mana":
			return EffectBase.new()   # the trigger itself is the effect ([method _extra_mana])
		"borrow":
			return Borrow.new(_spec_for(target, only))
		"sacrifice_self":
			return LeaveSelf.new(false)
		"exile_self":
			return LeaveSelf.new(true)
		"discard_random":
			var random := RandomHandDiscardEffect.new(n)
			random.target_spec = TargetSpec.opponent() if target == "opponent" else TargetSpec.player()
			return random
		"sacrifice":
			return EdictEffect.new(target == "opponent", target == "you")
		"steal":
			return StealEffect.new(_spec_for(target, only))
		"search_basic":
			var search := SearchLibraryEffect.new("a basic land card", func(i: CardInstance) -> bool:
				return i.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0)
			return search.to_battlefield() if target == "to_battlefield" else search
		"tap":
			return TapEffect.new(_spec_for(target, only))
		"untap":
			return UntapEffect.new(_spec_for(target, only))
		"regenerate":
			return RegenerateEffect.new().target_creature() if target == "creature" else RegenerateEffect.new()
		"prevent":
			var prevent := PreventDamageEffect.new(n).target_creature() if target == "creature" \
				else PreventDamageEffect.new(n).any_target()
			return prevent.x_amount() if x else prevent
		"fog":
			return PreventCombatDamageEffect.new()
		"raise":
			match target:
				"creature_card_to_battlefield": return ReturnFromGraveyardEffect.new().to_battlefield()
				"creature_card_to_top": return RaiseToTop.new(false)
				"any_card_to_top": return RaiseToTop.new(true)
				"any_card": return ReturnFromGraveyardEffect.new().any_card()
			return ReturnFromGraveyardEffect.new()
		"extra_turn":
			return ExtraTurnEffect.new()
	push_error("CommunityCard: unknown effect %s" % id)
	return DrawEffect.new(1)


## What a library search may find, by [param target].
static func _search_filter(target: String, named := "") -> Callable:
	match target:
		"a_named":
			var wanted := named.strip_edges().to_lower()
			return func(i: CardInstance) -> bool: return i.data.card_name.to_lower() == wanted
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


## What a color or type filter lets through ([constant ONLY]).
static func _only_filter(only: String) -> Callable:
	match only:
		"": return Callable()
		"artifact": return func(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
		"nonartifact": return func(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT)
		"nonland": return func(i: CardInstance) -> bool: return not i.is_land()
	var negated := only.begins_with("non")
	var mask := int(COLORS.get(only.trim_prefix("non"), 0))
	return func(i: CardInstance) -> bool: return ((i.cur_colors & mask) != 0) != negated


## How a target or a sweep is said with its filter: "target white
## creature", "nonblack creatures", "green creatures you control".
static func aim_words(target: String, only := "") -> String:
	if only == "" or not target in ONLY_TARGETS:
		return target_words(target)
	match target:
		"permanent": return "target %s permanent" % only
		"creatures": return "%s creatures" % only
		"each_creature": return "each %s creature" % only
		"yours": return "%s creatures you control" % only
		"all": return "all %s creatures" % only
	return "target %s creature" % only


static func _spec_for(target: String, only := "") -> TargetSpec:
	var spec: TargetSpec
	if only != "" and target in ONLY_TARGETS:
		if target == "permanent":
			return TargetSpec.new(TargetSpec.Kind.PERMANENT, aim_words(target, only), _only_filter(only))
		return TargetSpec.creature(aim_words(target, only), _only_filter(only))
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
	var when := String(a["when"])
	var hosted := bool(a.get("enchanted", false))
	if when == "land_tapped" and String((a["effects"][0] as Dictionary).get("effect", "")) == "extra_mana":
		return _extra_mana(name, _sentence(ability_text(a, name)))
	var plan := TriggerPlan.new()
	plan.card_name = name
	plan.choice = String(a.get("choice", "must"))
	var built := effects_of(a["effects"])
	for i in built.size():
		var e: Dictionary = a["effects"][i]
		plan.effects.append(built[i])
		plan.helpful.append(_helpful(e))
		plan.harmful.append(not _helpful(e) and String(e.get("effect", "")) != "steal")
		plan.drawback.append(_drawback(e))
	plan.question = "%s: %s?" % [name, _upper_first(effects_text(a["effects"], name, "trigger"))]
	var effects := plan.effects
	var helpful := plan.helpful
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
		"draw_step":
			event = Mtg.EventType.DRAW_STEP
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return int(ev.data.get("player", -1)) == source.controller_id
		"each_draw":
			event = Mtg.EventType.DRAW_STEP
			condition = Callable()
		"cast_white", "cast_blue", "cast_black", "cast_red", "cast_green":
			event = Mtg.EventType.SPELL_CAST
			var color := int(COLORS[when.trim_prefix("cast_")])
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				var spell: CardInstance = ev.data.get("instance")
				return spell != null and spell != source and (spell.cur_colors & color) != 0
		"deals_damage":
			event = Mtg.EventType.SOURCE_DEALT_DAMAGE
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return ev.data.get("source") == source and int(ev.data.get("amount", 0)) > 0
		"damage_player", "damage_creature":
			event = Mtg.EventType.DAMAGE_DEALT
			var key := "to_player" if when == "damage_player" else "to_instance"
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				if ev.data.get("source") != source or not ev.data.has(key) or int(ev.data.get("amount", 0)) <= 0:
					return false
				var hit: Variant = ev.data.get(key)
				return key == "to_player" or (hit is CardInstance and (hit as CardInstance).is_creature())
		"land_tapped":
			event = Mtg.EventType.TAPPED_FOR_MANA
			condition = Callable()
		"to_graveyard":
			event = Mtg.EventType.LEAVES_BATTLEFIELD
			condition = func(_g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
				return ev.data.get("instance") == source and source.zone == Mtg.Zone.GRAVEYARD
	if hosted:
		# The Aura watches its creature: the same test, asked of the host.
		var of_card := condition
		condition = func(g: MtgGame, source: CardInstance, ev: GameEvent) -> bool:
			var host := g.find_instance(source.attached_to) if source.attached_to != -1 else null
			return host != null and source.zone == Mtg.Zone.BATTLEFIELD and bool(of_card.call(g, host, ev))
	for i in effects.size():
		plan.slots.append(-1)
	# The plan rides the callable: the computer reads it before it casts
	# the card ([method TriggerPlan.slot_harms]).
	var trigger := TriggeredAbility.new(event, _run_plan.bind(plan), _sentence(ability_text(a, name)), condition)
	var slot := 0
	for i in effects.size():
		if effects[i] is ThatPlayer:
			# With no target before it to ride, the event's own player or creature.
			var rides := (effects[i] as ThatPlayer).slot
			plan.slots[i] = rides if rides >= 0 else (TriggerPlan.EVENT_PLAYER
				if (effects[i] as ThatPlayer).wants_player else TriggerPlan.EVENT_CREATURE)
			continue
		var spec: TargetSpec = effects[i].target_spec
		if spec == null:
			continue
		if plan.choice == "up_to":
			trigger.targeting_up_to(spec, 1, _order(helpful[i]))
		elif slot == 0:
			trigger.targeting(spec, _order(helpful[i]))
		else:
			trigger.and_targeting(spec, _order(helpful[i]))
		plan.slots[i] = slot
		slot += 1
	return trigger


## What a community trigger does as it resolves, and what the computer
## reads of it beforehand: its effects, which of them help or harm what
## they target, the target slot each reads, and whether it must be done.
class TriggerPlan extends RefCounted:
	## Slots that are no target: the player, the creature the event names.
	const EVENT_PLAYER := -2
	const EVENT_CREATURE := -3
	var card_name := ""
	var choice := "must"
	var question := ""
	var effects: Array[EffectBase] = []
	var helpful: Array[bool] = []
	var harmful: Array[bool] = []
	var drawback: Array[bool] = []
	var slots: Array[int] = []

	## Whether the trigger may be declined, whole or by taking no target.
	func is_optional() -> bool:
		return choice != "must"

	## Whether an effect that reads target slot [param slot] harms it.
	func slot_harms(slot: int) -> bool:
		for i in mini(slots.size(), harmful.size()):
			if slots[i] == slot and harmful[i]:
				return true
		return false

	## Whether every effect that reads [param slot] helps what it targets.
	func slot_helps(slot: int) -> bool:
		for i in mini(slots.size(), helpful.size()):
			if slots[i] == slot and not helpful[i]:
				return false
		return true


## A community trigger resolving ([param plan] bound by [method _trigger]).
static func _run_plan(g: MtgGame, source: CardInstance, ev: GameEvent, plan: TriggerPlan) -> void:
	# The trigger's controller, not the card's now (a stolen creature
	# that died is its owner's again; its trigger is still the thief's).
	var controller := g.controller_acting_for(source)
	var chosen: Array = []
	var wrong_side := false
	for i in plan.effects.size():
		var ref: TargetRef = null
		if plan.slots[i] >= 0:
			ref = g.current_trigger_target(plan.slots[i])
			if ref != null and (_rank(g, source, ref, plan.helpful[i]) != 0):
				wrong_side = true
		elif plan.slots[i] < -1:
			ref = _event_ref(ev, plan.slots[i] == TriggerPlan.EVENT_PLAYER)
		chosen.append(ref)
	if plan.choice == "may":
		# The sensible answer: yes, unless it would turn on its own side or
		# costs its controller something.
		var hint := not wrong_side and not plan.drawback.has(true)
		if not g.agents[controller].choose_yes_no(g, controller, plan.question, hint):
			return
	# "Up to one target": a seat that answers for itself takes none rather
	# than turn the effect on the wrong side.
	var declines := plan.choice == "up_to" and wrong_side and not g.agents[controller].wants_to_be_asked()
	for i in plan.effects.size():
		var effect: EffectBase = plan.effects[i]
		if plan.slots[i] == -1:
			effect.resolve_multi(g, source, controller, [], 0)
		elif plan.slots[i] < -1:
			# Named by the event, never chosen: nothing to decline.
			if chosen[i] != null:
				effect.resolve_multi(g, source, controller, [chosen[i]], 0)
		elif chosen[i] != null and not declines:
			effect.resolve_multi(g, source, controller, [chosen[i]], 0)


## The player (or the creature) the event [param ev] names: whose step it
## is, who cast the spell or tapped the land, who or what was dealt damage.
static func _event_ref(ev: GameEvent, player: bool) -> TargetRef:
	if ev == null:
		return null
	if not player:
		var hit: Variant = ev.data.get("to_instance")
		return TargetRef.card(hit) if hit is CardInstance and (hit as CardInstance).zone == Mtg.Zone.BATTLEFIELD \
			else null
	for key in ["to_player", "player", "controller"]:
		if ev.data.has(key) and ev.data[key] is int:
			return TargetRef.player(int(ev.data[key]))
	return null


## "Whenever a player taps a land for mana, that player adds one more mana
## of any type that land produced" (Mana Flare's shape, a mana trigger: it
## resolves as the land is tapped, and the planner counts it).
static func _extra_mana(name: String, text: String) -> TriggeredAbility:
	var bonus := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _add_extra_mana.bind(name), text) \
		.as_mana_trigger()
	bonus.mana_bonus_subtype = ManaPlanner.BONUS_ANY_LAND
	bonus.mana_bonus_color = 0
	bonus.mana_bonus_amount = 1
	return bonus


static func _add_extra_mana(game: MtgGame, source: CardInstance, event: GameEvent, name: String) -> void:
	var pid := int(event.data["player"])
	var color := int(event.data["color"])
	var types: Array = event.data.get("colors", [color])
	var answered := int((event.data.get("bonus_colors", {}) as Dictionary).get(source.id, -1))
	if types.has(answered):
		color = answered
	elif types.size() > 1:
		var labels: Array[String] = []
		for t in types:
			labels.append(Mtg.COLOR_NAMES[int(t)])
		var picked: int = game.agents[pid].choose_option(game, pid, labels,
			PlayerChoice.mana_color_prompt(name), maxi(types.find(color), 0))
		color = int(types[picked])
	game.players[pid].mana_pool.add(color, 1)
	game.log_line("%s adds a bonus %s" % [name, Mtg.COLOR_NAMES[color]])


## Whether [param e] costs its own controller: a card that leaves, or
## damage, life, a card or a creature of "you".
static func _drawback(e: Dictionary) -> bool:
	var id := String(e.get("effect", ""))
	return id in ["sacrifice_self", "exile_self"] \
		or (String(e.get("target", "")) == "you" and id in ["damage", "lose_life", "discard_own", "sacrifice"])


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
	var seat := g.controller_acting_for(s)
	var mine := false
	if ref.is_player:
		mine = ref.player_id == seat
	else:
		var inst := g.find_instance(ref.instance_id)
		mine = inst != null and inst.controller_id == seat
	return (0 if mine else 1) if helpful else (1 if mine else 0)


## The static abilities: anthems and lords (+P/+T and keywords, by whose
## creatures and of what type), and cheaper spells of a type.
static func _add_static(data: CardData, a: Dictionary) -> void:
	var what := String(a["what"])
	if what == "cost_less":
		var spell_type := int(TYPES[String(a.get("spell_type", "creature"))])
		var less := int(a.get("amount", 1))
		# A card may print two ("Creature spells cost {2} less", "Artifact
		# spells cost {1} less"): one callback, each added to those before it.
		var before: Callable = data.cost_modifier.get("spell", Callable())
		data.with_cost_modifier(func(game: MtgGame, caster: int, card: CardData, modifier: CardInstance) -> int:
			var change := int(before.call(game, caster, card, modifier)) if before.is_valid() else 0
			return change + (-less if modifier.controller_id == caster and card.is_type(spell_type) else 0))
		return
	if what == "cost_more":
		var taxed := String(a.get("spell_type", "creature"))
		var taxed_type := int(TYPES.get(taxed, 0))
		var taxed_color := int(COLORS.get(String(a.get("spell_color", "")), 0))
		var more := int(a.get("amount", 1))
		var everyone := String(a.get("who", COST_WHO[0])) == "all"
		var earlier: Callable = data.cost_modifier.get("spell", Callable())
		data.with_cost_modifier(func(game: MtgGame, caster: int, card: CardData, modifier: CardInstance) -> int:
			var change := int(earlier.call(game, caster, card, modifier)) if earlier.is_valid() else 0
			if (everyone or modifier.controller_id != caster) and (taxed_type == 0 or card.is_type(taxed_type)) \
					and (taxed_color == 0 or (card.color_mask() & taxed_color) != 0):
				change += more
			return change)
		return
	if what == "attack_tax":
		var toll := int(a.get("amount", 1))
		var price := ManaCost.parse("{%d}" % toll)
		var said := "its controller pays {%d} (%s)" % [toll, data.card_name]
		var can_pay := func(game: MtgGame, who: int) -> bool: return game.can_afford_cost(who, price)
		var pay := func(game: MtgGame, who: int) -> void: game.try_pay(who, price)
		data.static_ability(StaticAbility.new(func(g: MtgGame, s: CardInstance) -> void:
			for i in g.players[g.opponent_of(s.controller_id)].battlefield:
				if i.is_creature():
					i.cur_attack_costs.append({"desc": said, "generic_mana": toll, "can_pay": can_pay, "pay": pay}),
			_sentence(static_text(a))))
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
		# The card that activated it, not a new one of the same name (CR 400.7).
		if game.is_present(source) \
				and source.layer_timestamp == int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
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


## "Search your library for up to N ... cards, put them into your hand,
## then shuffle" or "Return [up to N] ... from your graveyard to your
## hand": one question a card as it resolves (the duel asks the player
## each), stopping at the first one not taken.
class FindCards extends EffectBase:
	var place := "library"
	var amount := 1
	var use_x := false
	var filter: Callable
	var description := "a card"

	func _init(p_place: String, p_amount: int, p_x: bool, p_filter: Callable, p_description: String) -> void:
		place = p_place
		amount = p_amount
		use_x = p_x
		filter = p_filter
		description = p_description
		ai_role = &"search"

	func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef,
			x_value: int = 0) -> void:
		var n := x_value if use_x else amount
		var p := game.players[controller]
		if place == "graveyard":
			for _i in n:
				var candidates: Array[CardInstance] = []
				for inst in p.graveyard:
					if not filter.is_valid() or filter.call(inst):
						candidates.append(inst)
				if candidates.is_empty():
					return
				var chosen := game.agents[controller].choose_card(game, controller, candidates,
					"Return %s from your graveyard to your hand" % description, true)
				if chosen == null:
					return
				game.return_from_graveyard_to_hand(chosen)
			return
		for _i in n:
			var before := p.library.size()
			game.search_library(controller, filter, "Search your library for %s" % description, false, false)
			if p.library.size() == before:
				break
		game.shuffle_library(controller)

	func describe() -> String:
		if place == "graveyard":
			return "return %s from your graveyard to your hand" % description
		return "search your library for %s, then shuffle" % description


## "Each player draws N (or X) cards", the active player first.
class EachPlayerDraws extends EffectBase:
	var amount := 1
	var use_x := false

	func _init(p_amount: int, p_x: bool) -> void:
		amount = p_amount
		use_x = p_x

	func resolve(game: MtgGame, _source: CardInstance, _controller: int, _target: TargetRef,
			x_value: int = 0) -> void:
		for pid in [game.active_player, game.opponent_of(game.active_player)]:
			game.draw_cards(pid, x_value if use_x else amount)

	func describe() -> String:
		return "each player draws %s card(s)" % ("X" if use_x else str(amount))


## "Shuffle your hand and graveyard into your library" — or only the
## graveyard, or only the hand; for you, a target player or each player
## (the active player first). A spell shuffling its own controller's
## graveyard in is itself on the stack, so it goes to the graveyard after
## (CR 608.2m), as Timetwister does.
class ShuffleIn extends EffectBase:
	var from := "hand_and_graveyard"
	var who := "each_player"

	func _init(p_from: String, p_who: String) -> void:
		from = p_from
		who = p_who

	func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		var pids: Array = [game.active_player, game.opponent_of(game.active_player)]
		if who == "you":
			pids = [controller]
		elif who == "player":
			if target == null or not target.is_player:
				return
			pids = [target.player_id]
		for pid in pids:
			match from:
				"graveyard":
					game.shuffle_graveyard_into_library(pid)
				"hand":
					game.shuffle_hand_into_library(pid)
				_:
					game.shuffle_hand_and_graveyard_into_library(pid)

	func describe() -> String:
		return "shuffle %s into library" % from.replace("_", " ")


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
		if game.is_present(source) \
				and source.layer_timestamp == int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
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


## "Target opponent (player) sacrifices a creature" — the victim chooses —
## or "Sacrifice a creature": the controller's own, no target.
class EdictEffect extends EffectBase:
	var on_controller := false

	func _init(opponent: bool, p_on_controller := false) -> void:
		on_controller = p_on_controller
		if on_controller:
			return
		target_spec = TargetSpec.opponent() if opponent else TargetSpec.player()
		with_ai_role(&"opponent_sacrifice_creature")

	func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		if not on_controller and (target == null or not target.is_player):
			return
		var pid := controller if on_controller else target.player_id
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


## "Target player discards N cards" — the one who discards chooses — or
## "Discard N cards": the controller's own, no target.
class OwnDiscard extends RandomHandDiscardEffect:
	func _init(number: int, self_discard: bool) -> void:
		super(number, self_discard)

	func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
			_x_value := 0) -> void:
		if not controller_mode and (target == null or not target.is_player):
			return
		var pid := controller if controller_mode else target.player_id
		var n := mini(count, game.players[pid].hand.size())
		if n > 0:
			game.discard_cards(pid, game.agents[pid].choose_discard(game, pid, n))

	func describe() -> String:
		return "%s discards %d card(s)" % ["you" if controller_mode else "target player", count]


## "Sacrifice CARDNAME" / "Exile CARDNAME", as an effect of its own ability.
class LeaveSelf extends EffectBase:
	var exile := false

	func _init(p_exile: bool) -> void:
		exile = p_exile

	func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		# The card that did it, not a new one of the same name (CR 400.7).
		if not game.is_present(source) \
				or source.layer_timestamp != int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
			return
		if exile:
			game.exile_permanent(source)
		else:
			game.sacrifice_permanent(source)

	func describe() -> String:
		return "exile this card" if exile else "sacrifice this card"


## Tokens that are sacrificed (or exiled) at the beginning of the next end
## step (Ball Lightning's kin made as tokens, Waylay's Knights).
class EndingTokens extends CreateTokenEffect:
	var exile := false

	func _init(name: String, power: int, toughness: int, color: int, subtype: String, number: int,
			p_exile: bool) -> void:
		super(name, power, toughness, color, subtype, number)
		exile = p_exile

	func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef,
			_x_value := 0) -> void:
		var ids: Array = []
		var stamps: Array = []
		for made in game.create_token(controller, token, count):
			ids.append(made.id)
			stamps.append(made.layer_timestamp)
		if ids.is_empty():
			return
		game.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, CommunityCard._end_tokens,
			"%s the tokens %s created." % ["Exile" if exile else "Sacrifice", source.data.card_name]),
			controller, source, false, {"ids": ids, "stamps": stamps, "exile": exile})


## The end step after [EndingTokens]: each token still there goes.
static func _end_tokens(g: MtgGame, _source: CardInstance, _ev: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var ids: Array = memory.get("ids", [])
	var stamps: Array = memory.get("stamps", [])
	for n in ids.size():
		var token := g.find_instance(int(ids[n]))
		if token == null or token.zone != Mtg.Zone.BATTLEFIELD or token.layer_timestamp != int(stamps[n]):
			continue
		if bool(memory.get("exile", false)):
			g.exile_permanent(token)
		else:
			g.sacrifice_permanent(token)


## "That player …": a stock player-targeting effect with no target of its
## own — it reads the player an effect before it targeted ([member slot]:
## which of the ability's targets; a trigger hands the player over itself).
class ThatPlayer extends EffectBase:
	var inner: EffectBase
	var slot := -1
	## False: "that creature", handed over by a trigger (the one dealt damage).
	var wants_player := true

	func _init(p_inner: EffectBase, p_helpful: bool) -> void:
		inner = p_inner
		ai_helpful = p_helpful

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value: int = 0) -> void:
		var ref := target
		if ref == null:
			var all: Array = game.current_targets()
			if slot >= 0 and slot < all.size():
				ref = all[slot]
		if ref != null and ref.is_player == wants_player:
			inner.resolve(game, source, controller, ref, x_value)

	func describe() -> String:
		return inner.describe().replace("target player", "that player").replace("target creature", "that creature")


## AN AMOUNT WORKED OUT AS THE EFFECT RESOLVES: "for each creature you
## control" (`per`, the amount times the count) or the X paid, for the
## effects that do not read X themselves. The stock effect is built then,
## with the number in it — nothing shared is ever changed.
class Varying extends EffectBase:
	var base: Dictionary
	var per := ""

	func _init(e: Dictionary) -> void:
		base = e.duplicate(true)
		per = String(e.get("per", ""))
		var shape := CommunityCard.effect_of(CommunityCard._scaled(base, 1))
		target_spec = shape.target_spec
		# The computer judges a stock effect by its class; this one says.
		ai_helpful = shape.ai_helpful or CommunityCard._helpful(base)
		ai_role = shape.ai_role
		ai_parameters = shape.ai_parameters

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value: int = 0) -> void:
		var times := x_value if per == "" else CommunityCard.count_of(game, controller, per)
		if times > 0:
			CommunityCard.effect_of(CommunityCard._scaled(base, times)).resolve(game, source, controller, target, 0)

	func describe() -> String:
		return CommunityCard.effect_text(base, "it", "spell")


## "Return CARDNAME to its owner's hand", from the graveyard it was just
## put into (Rancor).
class ReturnSelf extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		if source.zone == Mtg.Zone.GRAVEYARD and not source.is_token:
			game.return_from_graveyard_to_hand(source)

	func describe() -> String:
		return "return this card to its owner's hand"


## "Put target (creature) card from your graveyard on top of your library."
class RaiseToTop extends ReturnFromGraveyardEffect:
	func _init(any: bool) -> void:
		super()
		if any:
			any_card()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id) if target != null and not target.is_player else null
		if inst != null:
			game.return_from_graveyard_to_library_top(inst)

	func describe() -> String:
		return "puts %s on top of its owner's library" % target_spec.description


## "Search your library for a card, then shuffle and put that card on top."
class TopTutor extends EffectBase:
	var filter: Callable
	var description := "a card"

	func _init(p_filter: Callable, p_description: String) -> void:
		filter = p_filter
		description = p_description
		ai_role = &"search"

	func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		var candidates: Array[CardInstance] = []
		for inst in game.players[controller].library:
			if not filter.is_valid() or filter.call(inst):
				candidates.append(inst)
		var chosen: CardInstance = null
		if not candidates.is_empty():
			chosen = game.agents[controller].choose_card(game, controller, candidates,
				"Search your library for %s" % description, true)
		game.shuffle_library(controller)
		if chosen != null and candidates.has(chosen):
			game.move_library_card_to_top(chosen)

	func describe() -> String:
		return "search your library for %s, then shuffle and put it on top" % description


## "Untap target creature and gain control of it until end of turn. It
## gains haste until end of turn. When you lose control of it, tap it."
## (Ray of Command's shape.)
class Borrow extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		var taken := game.find_instance(target.instance_id) if target != null and not target.is_player else null
		if taken == null or taken.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.untap_permanent(taken)
		game.gain_control_until_eot(taken, controller)
		game.continuous.add_until_eot_pump(taken.id, 0, 0, [Mtg.Keyword.HASTE])
		game.recalculate()
		var back := TriggeredAbility.new(Mtg.EventType.CONTROL_CHANGED,
			CommunityCard._borrow_tap.bind(taken.id, taken.layer_timestamp), "Tap the borrowed creature.",
			CommunityCard._borrow_lost.bind(taken.id, taken.layer_timestamp, controller)) \
			.also_when(Mtg.EventType.LEAVES_BATTLEFIELD)
		game.schedule_delayed_trigger(back, controller, source)

	func describe() -> String:
		return "untap %s and gain control of it until end of turn, with haste" % target_spec.description


static func _borrow_lost(_g: MtgGame, _s: CardInstance, ev: GameEvent, id: int, stamp: int, pid: int) -> bool:
	var inst: Variant = ev.data.get("instance")
	return inst is CardInstance and (inst as CardInstance).id == id \
		and (inst as CardInstance).layer_timestamp == stamp and int(ev.data.get("from_controller", -1)) == pid


static func _borrow_tap(g: MtgGame, _s: CardInstance, _ev: GameEvent, id: int, stamp: int) -> void:
	var inst := g.find_instance(id)
	if inst != null and inst.id == id and inst.layer_timestamp == stamp and inst.zone == Mtg.Zone.BATTLEFIELD:
		g.tap_permanent(inst)


## One effect of a spec with its amount (a pump's +P/+T) taken [param
## times], and nothing left for [Varying] to work out.
static func _scaled(e: Dictionary, times: int) -> Dictionary:
	var out := e.duplicate(true)
	var by_x := bool(out.get("x", false))
	out.erase("x")
	out.erase("per")
	if (EFFECTS.get(String(out.get("effect", "")), {}) as Dictionary).has("pt"):
		out["power"] = int(out.get("power", 0)) * (1 if by_x else times)
		out["toughness"] = int(out.get("toughness", 0)) * (1 if by_x else times)
		if by_x:
			out["x"] = true
	else:
		out["amount"] = (1 if by_x else int(out.get("amount", 1))) * times
	return out


# --------------------------------------------------------- the rules text --

## THE RULES TEXT, written from the blocks: the keywords line, protection
## and landwalk, the card rules, then each ability's sentence, one a line.
static func rules_text(spec: Dictionary) -> String:
	var base := base_of(spec)
	if base == null:
		var missing := String(spec.get("rules_of", "")).strip_edges() if spec.get("rules_of", "") is String else ""
		return _own_text(spec) if missing == "" else "(The rules of %s, a card the game does not have now.)" % missing
	# The card's own words under this card's name, then what was added.
	var name := String(spec.get("name", "")).strip_edges()
	var kept := base.oracle_text if name == "" else base.oracle_text.replace(base.card_name, name)
	var more := spec.duplicate()
	more.erase("subtypes")   # a kept land's types tap as its own rules say
	var added := _own_text(more)
	return kept if added == "" else (added if kept == "" else kept + "\n" + added)


## The rules text of what the spec itself says (without a kept card's).
static func _own_text(spec: Dictionary) -> String:
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
	if rules.has("shroud"):
		words.append("shroud")
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
	if rules.has("enters_x_counters"):
		lines.append("%s enters the battlefield with X +1/+1 counters on it." % name)
	if rules.has("pt_count"):
		lines.append("%s's power and toughness are each equal to the number of %s." % [name,
			count_words(String(rules["pt_count"]), true)])
	if rules.has("no_untap"):
		lines.append("%s doesn't untap during your untap step." % name)
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
				"activated", "trigger": line = _sentence(ability_text(a, name, false, _list(spec.get("types"))))
				"mana": line = _sentence(mana_text(a, name))
				"static": line = _sentence(static_text(a))
				"enchant": line = _sentence(enchant_text(a))
			if line != "":
				lines.append(line)
	return "\n".join(lines)


## An activated or triggered ability's sentence. A SHARED activated
## ability ("All Sliver creatures have …") is quoted whole; [param inner]
## asks for the quoted ability alone, as each creature that has it reads it.
## [param kinds]: the card's own types ("Sacrifice another creature" only
## when the card is one).
static func ability_text(a: Dictionary, name: String, inner := false, kinds: Array = []) -> String:
	if String(a.get("kind", "")) == "trigger":
		var when := String(TRIGGERS.get(String(a.get("when", "")), "")).replace("CARDNAME",
			"enchanted creature" if bool(a.get("enchanted", false)) else name)
		var body := effects_text(a.get("effects", []), name, "trigger")
		match String(a.get("choice", "must")):
			"may": body = _may_text(a.get("effects", []), name)
			"up_to": body = _up_to_text(body)
		return "%s, %s" % [when, _lower_first(body, name)]
	var shared := String(a.get("shared", ""))
	if bool(a.get("enchanted", false)) and not inner:
		return "Enchanted creature has \"%s\"" % _sentence(ability_text(a, "this creature", true, ["creature"]))
	if shared != "" and not inner:
		return "All %s creatures have \"%s\"" % [_type_word(shared),
			_sentence(ability_text(a, "this creature", true, ["creature"]))]
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
		var another := bool(a.get("sacrifice", false)) and kinds.has(sac)
		parts.append("Sacrifice %s" % ("another " + sac if another else SACRIFICES[sac]))
	var discard := int(a.get("discard", 0))
	if discard > 0:
		parts.append("Discard %s" % _cards(discard))
	var removes := int(a.get("remove_counters", 0))
	if removes > 0:
		parts.append("Remove %s +1/+1 counter%s from %s" % [_number(removes), "s" if removes > 1 else "", self_name])
	if int(a.get("life", 0)) > 0:
		parts.append("Pay %d life" % int(a["life"]))
	var text := "%s: %s" % [", ".join(parts), _upper_first(effects_text(a.get("effects", []), name, "activated",
		kinds))]
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
		"cost_more":
			var kind := String(a.get("spell_type", "creature"))
			var words: Array[String] = []
			if String(a.get("spell_color", "")) != "":
				words.append(String(a["spell_color"]))
			if kind != "any":
				words.append(kind)
			words.append("spells")
			if String(a.get("who", COST_WHO[0])) == "opponents":
				words.append("your opponents cast")
			return "%s cost {%d} more to cast" % [_upper_first(" ".join(words)), int(a.get("amount", 1))]
		"attack_tax":
			return ("Creatures can't attack you unless their controller pays {%d} for each creature they control "
				+ "that's attacking you") % int(a.get("amount", 1))
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
		lines.append("Enchanted creature has protection from %s. This effect doesn't remove this Aura." \
			% String(a["protection"]))
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


## "You may …" before a trigger's effects: the first in its bare form
## ("you may have CARDNAME deal 2 damage to any target"), the rest after
## "If you do,".
static func _may_text(effects: Variant, name: String) -> String:
	if not effects is Array or (effects as Array).is_empty():
		return ""
	var list: Array = effects
	var text := "you may " + _bare(effects_text([list[0]], name, "trigger"), name)
	if list.size() > 1:
		text += ". If you do, " + _lower_first(effects_text(list.slice(1), name, "trigger"), name)
	return text


## The verbs an effect's sentence is written with, and each one bare.
const _VERBS := {" deals ": " deal ", " gets ": " get ", " gains ": " gain ", " has ": " have ",
	" draws ": " draw ", " loses ": " lose ", " discards ": " discard ", " sacrifices ": " sacrifice ",
	" puts ": " put ", " shuffles ": " shuffle ", " reveals ": " reveal "}


## An effect's sentence after "you may": "draw a card", "gain 3 life",
## "have target creature get +1/+1 until end of turn".
static func _bare(text: String, name: String) -> String:
	if text.begins_with("You "):
		return text.substr(4)
	var told := false
	for verb in _VERBS:
		if text.contains(verb):
			told = true
			text = text.replace(verb, String(_VERBS[verb]))
	# "Creatures you control get …" has its subject and a bare verb already.
	if told or text.contains(" get +") or text.contains(" get -") or text.contains(" have "):
		return "have " + _lower_first(text, name)
	return _lower_first(text, name)


## "Up to one target …": the effect's one target may be left unchosen.
static func _up_to_text(text: String) -> String:
	if text.begins_with("Target "):
		return "Up to one target " + text.substr(7)
	var at := text.find("target ")
	return text if at < 0 else text.left(at) + "up to one " + text.substr(at)


## The effects as one sentence: "Draw two cards and you gain 3 life".
## [param kinds]: the card's own types (a land that becomes a creature is
## "still a land").
static func effects_text(effects: Variant, name: String, context: String, kinds: Array = []) -> String:
	var parts: Array[String] = []
	if effects is Array:
		var list: Array = effects
		var i := 0
		while i < list.size():
			var e: Variant = list[i]
			if e is Dictionary:
				var part := effect_text(e, name, context, kinds)
				var next: Variant = list[i + 1] if i + 1 < list.size() else null
				if _shuffle_then_draw(e, next):
					# Timetwister's "..., then draws seven cards": the same
					# players shuffle and draw, said once.
					var drawn := effect_text(next, name, context)
					part += ", then " + (drawn.trim_prefix("Each player ") if drawn.begins_with("Each player ")
						else drawn.left(1).to_lower() + drawn.substr(1))
					i += 1
				parts.append(part)
			i += 1
	if parts.is_empty():
		return ""
	var text := parts[0]
	for i in range(1, parts.size()):
		text += (" and " if parts.size() == 2 else ", then ") + _lower_first(parts[i], name)
	return text


## Whether [param e] shuffles into a library and [param next] then draws
## for the same players — each player, or you — to be said as one.
static func _shuffle_then_draw(e: Variant, next: Variant) -> bool:
	if not (e is Dictionary and next is Dictionary):
		return false
	if String(e.get("effect", "")) != "shuffle_in" or String(next.get("effect", "")) != "draw":
		return false
	var who := String(e.get("target", "each_player"))
	return who in ["each_player", "you"] and String(next.get("target", "you")) == who


static func effect_text(e: Dictionary, name: String, _context: String, kinds: Array = []) -> String:
	var id := String(e.get("effect", ""))
	if not EFFECTS.has(id):
		return ""
	var info: Dictionary = EFFECTS[id]
	var target := String(e.get("target", (info["targets"] as Array)[0] if info.has("targets") else ""))
	var x := bool(e.get("x", false))
	var n := int(e.get("amount", 1))
	var amount := "X" if x else str(n)
	var aim := aim_words(target, String(e.get("only", "")))
	if target == "that_creature":
		var as_creature := e.duplicate()
		as_creature["target"] = "creature"
		return effect_text(as_creature, name, _context, kinds).replace("target creature", "that creature") \
			.replace("Target creature", "That creature")
	if String(e.get("per", "")) != "":
		var plain := e.duplicate()
		plain.erase("per")
		return "%s for each %s" % [effect_text(plain, name, _context, kinds), count_words(String(e["per"]))]
	var some_cards := "X cards" if x else _cards(n)
	match id:
		"damage":
			if target == "divided":
				return "%s deals %s damage divided as you choose among any number of targets" % [name, amount]
			return "%s deals %s damage to %s" % [name, amount, aim]
		"draw":
			var cards := "X cards" if x else _cards(n)
			if target == "each_player":
				return "Each player draws %s" % cards
			if target == "that_player":
				return "That player draws %s" % cards
			return ("Target player draws %s" if target == "player" else "Draw %s") % cards
		"shuffle_in":
			var what := String(SHUFFLE_FROM_WORDS.get(String(e.get("from", SHUFFLE_FROM[0])), "hand and graveyard"))
			match target:
				"you":
					return "Shuffle your %s into your library" % what
				"player":
					return "Target player shuffles their %s into their library" % what
				"that_player":
					return "That player shuffles their %s into their library" % what
			return "Each player shuffles their %s into their library" % what
		"gain_life":
			if target == "that_player":
				return "That player gains %s life" % amount
			return ("Target player gains %s life" if target == "player" else "You gain %s life") % amount
		"lose_life":
			if target == "you":
				return "You lose %s life" % amount
			return "%s loses %s life" % [_upper_first(target_words(target)), amount]
		"drain":
			if target == "each_opponent":
				return "Each opponent loses %s life and you gain that much life" % amount
			return "Target opponent loses %s life and you gain %s life" % [amount, amount]
		"destroy":
			return "Destroy %s" % aim
		"destroy_all":
			return "Destroy all %s" % aim
		"exile":
			return "Exile %s" % aim
		"bounce":
			return "Return %s to its owner's hand" % aim
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
			var whose := _upper_first(aim)
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
				String(e.get("color", "colorless")), subtype, "s" if n > 1 or x else ""]
			var granted := _list(e.get("keywords"))
			if not granted.is_empty():
				var words: Array[String] = []
				for k in granted:
					words.append(String(KEYWORD_WORDS.get(k, k)))
				shown += " with " + _and_list(words)
			# "an 8/8", "an 11/11", "an 18/18".
			var count := "X" if x else _number(n)
			if n == 1 and not x and int(e.get("power", 1)) in [8, 11, 18]:
				count = "an"
			var ends := String(e.get("ends", ""))
			if ends in ["sacrifice", "exile"]:
				shown += " and %s %s at the beginning of the next end step" % [ends, "them" if n > 1 or x else "it"]
			return "Create %s %s" % [count, shown]
		"add_mana":
			return "Add %s" % String(MANA_SYMBOLS.get(String(e.get("color", "colorless")), "{C}")).repeat(maxi(1, n))
		"mill":
			return "%s puts the top %s of their library into their graveyard" % [
				_upper_first(target_words(target)), "X cards" if x else ("card" if n == 1 else "%s cards" % _number(n))]
		"discard":
			# The caster looks and picks (Coercion), and the card says so.
			return "%s reveals their hand and discards %s of your choice" % [_upper_first(target_words(target)),
				some_cards]
		"discard_own":
			if target == "you":
				return "Discard %s" % some_cards
			return "%s discards %s" % [_upper_first(target_words(target)), some_cards]
		"return_self":
			return "Return %s to its owner's hand" % name
		"extra_mana":
			return "That player adds one additional mana of any type that land produced"
		"borrow":
			return ("Untap %s and gain control of it until end of turn. It gains haste until end of turn. "
				+ "When you lose control of it, tap it") % aim
		"sacrifice_self":
			return "Sacrifice %s" % name
		"exile_self":
			return "Exile %s" % name
		"discard_random":
			return "%s discards %s at random" % [_upper_first(target_words(target)), some_cards]
		"sacrifice":
			if target == "you":
				return "Sacrifice a creature"
			return "%s sacrifices a creature" % _upper_first(target_words(target))
		"steal":
			return "Gain control of %s" % aim
		"search_basic":
			return "Search your library for a basic land card, %s, then shuffle" % target_words(target)
		"tap":
			return "Tap %s" % aim
		"untap":
			return "Untap %s" % aim
		"regenerate":
			return "Regenerate %s" % (name if target == "self" else "target creature")
		"prevent":
			return "Prevent the next %s damage that would be dealt to %s this turn" % [amount, target_words(target)]
		"fog":
			return "Prevent all combat damage that would be dealt this turn"
		"raise":
			match target:
				"creature_card_to_battlefield":
					return "Return target creature card from your graveyard to the battlefield"
				"any_card":
					return "Return target card from your graveyard to your hand"
				"creature_card_to_top":
					return "Put target creature card from your graveyard on top of your library"
				"any_card_to_top":
					return "Put target card from your graveyard on top of your library"
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
			return "%s becomes a %d/%d %screature until end of turn%s" % [name, int(e.get("power", 2)),
				int(e.get("toughness", 2)), sub + " " if sub != "" else "",
				". It's still a land" if kinds.has("land") else ""]
		"draw_later":
			return "Draw %s at the beginning of the next turn's upkeep" % _cards(n)
		"search":
			var what := search_words(e, target, n, x)
			if String(e.get("where", SEARCH_WHERE[0])) == "graveyard":
				return "Return %s from your graveyard to your hand" % what
			if String(e.get("where", SEARCH_WHERE[0])) == "library_top":
				return "Search your library for %s, then shuffle and put that card on top" % search_words(e, target, 1,
					false)
			return "Search your library for %s, put %s into your hand, then shuffle" % [what,
				"them" if x or n > 1 else "it"]
	return ""


## A creature type as printed: "Goblin" ("mindflayer" stays one word).
static func _type_word(word: String) -> String:
	word = word.strip_edges()
	return word.left(1).to_upper() + word.substr(1).to_lower()


## What a search looks for: "a creature card", "a card named Shivan
## Dragon", "up to two land cards", "up to X cards".
static func search_words(e: Dictionary, target: String, n: int, x: bool) -> String:
	var named := String(e.get("named", "")).strip_edges()
	if not x and n <= 1:
		return ("a card named %s" % named) if target == "a_named" else target_words(target)
	var many := {"a_creature": "creature cards", "an_artifact": "artifact cards",
		"an_enchantment": "enchantment cards", "a_land": "land cards", "a_card": "cards",
		"a_named": "cards named %s" % named}
	return "up to %s %s" % ["X" if x else _number(n), String(many.get(target, "cards"))]


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
			"Put ", "Gain ", "Search ", "Take ", "Switch ", "The next ", "Shuffle ", "Sacrifice ", "Discard ",
			"That ", "Up to ", "Untap ", "White ", "Blue ", "Black ", "Red ", "Green ", "Non", "Artifact "]:
		if text.begins_with(start):
			return text.left(1).to_lower() + text.substr(1)
	return text


static func _sentence(text: String) -> String:
	text = text.strip_edges()
	if text == "":
		return ""
	# A quoted ability ends inside its quotes: 'have "{2}: Regenerate it."'.
	return text if text.ends_with(".") or text.ends_with(".\"") else text + "."
