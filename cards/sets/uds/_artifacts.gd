extends RefCounted
## Urza's Destiny (_artifacts, Pack 10). Noncreature artifacts and artifact
## creatures with abilities.
##
## Every listed name implements its whole Oracle text; the shared helpers
## (the upkeep counter, the reveal search) are Urza's Saga's
## (cards/sets/usg/_artifacts.gd). tests/cards/test_pack_10_B8_*.gd pin
## each card.
##
## Braidwood Sextant — Citanul Flute's reveal search for a basic land card;
##   role `land_search` (alliances_tactics.gd).
## Caltrops — "Whenever a creature attacks" is one trigger PER attacking
##   creature, both players' (CR 603.2c, 508.3a): Barbed Foliage's fan-out
##   (mir/_combat.gd `attack_fan_out`), each trigger damaging its attacker
##   only while it is still that object (CR 400.7).
## Fodder Cannon — "Sacrifice a creature" is paid after the target is
##   chosen (CR 602.2b): sacrificing the target itself leaves the ability
##   without a legal target (CR 608.2b).
## Powder Keg — the fuse counters come from the activation's cost record
##   (snapshotted before the self-sacrifice, CR 608.2h); "mana value" is the
##   permanent's copiable one (a token's, a face-down creature's: 0), and the
##   destruction is one simultaneous departure — zero counters destroys the
##   tokens and every other mana-value-0 artifact or creature.
## Scrying Glass — the number and the colour are chosen as the ability
##   resolves (CR 608.2d), before the hand is revealed to both seats. The
##   numbers offered run from 1 to the target's hand size (a larger number
##   can never match; the hand size is public); the colour is read off each
##   revealed card's live colours. The hint reads public zones only.
## Thran Foundry — Feldon's Cane with a target player.
## Thran Golem — two statics (Lord of Atlantis's convention): a layer-6
##   keyword grant and a layer-7c +2/+2, both gated on MtgGame.is_enchanted
##   (a licid that is an Aura counts).
## Urza's Incubator — Volrath's Laboratory's choice as it enters (CR 614.1c,
##   CardData.with_chosen_type); a generic cost reduction for every caster's
##   creature spells of that type (the Medallions' shape: never into a
##   coloured pip). The hint is the type the chooser's own deck and hand
##   show most.
const F := preload("res://cards/sets/fem/_rules.gd")
const U := preload("res://cards/sets/usg/_artifacts.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")
const TYPES := preload("res://engine/core/creature_types.gd")
const PATH := "res://cards/sets/uds/_artifacts.gd"

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Braidwood Cup":
			c.activated(ActivatedAbility.new("", true, [GainLifeEffect.new(1)], "{T}: You gain 1 life."))
		"Braidwood Sextant":
			c.activated(ActivatedAbility.new("{2}", true,
				[U.RevealSearch.new("a basic land card", _basic_land_card, "Braidwood Sextant").with_ai_role(&"land_search")],
				"{2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal that card, put it into your hand, then shuffle.") \
				.with_sacrifice_cost())
		"Brass Secretary":
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice this creature: Draw a card.").with_sacrifice_cost())
		"Caltrops":
			c.triggered(MC.attack_fan_out(_caltrops_fan, Callable(),
				"Whenever a creature attacks, this artifact deals 1 damage to it."))
		"Fodder Cannon":
			c.activated(ActivatedAbility.new("{4}", true, [DamageEffect.new(4).target_creature()],
				"{4}, {T}, Sacrifice a creature: This artifact deals 4 damage to target creature.") \
				.with_sacrifice_of("creature", _creature))
		"Mantis Engine":
			c.activated(ActivatedAbility.new("{2}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff()],
				"{2}: This creature gains flying until end of turn."))
			c.activated(ActivatedAbility.new("{2}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()],
				"{2}: This creature gains first strike until end of turn."))
		"Powder Keg":
			c.triggered(U.upkeep_counter("fuse",
				"At the beginning of your upkeep, you may put a fuse counter on this artifact."))
			c.activated(ActivatedAbility.new("", true, [Keg.new()],
				"{T}, Sacrifice this artifact: Destroy each artifact and creature with mana value equal to the number of fuse counters on this artifact.") \
				.with_sacrifice_cost())
		"Scrying Glass":
			c.activated(ActivatedAbility.new("{3}", true, [Glass.new()],
				"{3}, {T}: Choose a number greater than 0 and a color. Target opponent reveals their hand. If that opponent reveals exactly the chosen number of cards of the chosen color, you draw a card."))
		"Thran Foundry":
			c.activated(ActivatedAbility.new("{1}", true,
				[F.Action.new(_foundry, "target player shuffles their graveyard into their library", TargetSpec.player())],
				"{1}, {T}, Exile this artifact: Target player shuffles their graveyard into their library.") \
				.with_exile_cost())
		"Thran Golem":
			c.static_ability(StaticAbility.new(_golem_keywords,
				"As long as this creature is enchanted, it has flying, first strike, and trample.").changing_abilities())
			c.static_ability(StaticAbility.new(_golem_pump, "As long as this creature is enchanted, it gets +2/+2."))
		"Urza's Incubator":
			c.as_it_enters(_incubator_choose).with_chosen_type("incubator_type")
			c.with_cost_modifier(_incubator)
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()

static func _basic_land_card(i: CardInstance) -> bool:
	return i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0


# ------------------------------------------------------------------- Caltrops --

static func _caltrops_fan(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	for attacker in e.data.get("attackers", []):
		var i := attacker as CardInstance
		if i == null: continue
		MC.queue_for_attacker(g, s, e, s.controller_id, i, _caltrops_sting,
			"Whenever a creature attacks, this artifact deals 1 damage to it.")

static func _caltrops_sting(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := MC.live(g, id, stamp)
	if i != null:
		g.deal_damage(s, TargetRef.card(i), 1)


# ----------------------------------------------------------------- Powder Keg --

class Keg extends EffectBase:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var counters: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(counters.get("fuse", 0))
		var doomed: Array[CardInstance] = []
		for i in g.all_battlefield():
			if (i.is_creature() or i.is_type(Mtg.CardType.ARTIFACT)) \
					and g.copiable_data(i).cost.mana_value() == n:
				doomed.append(i)
		if doomed.is_empty(): return
		g.depart_together(doomed, func(i: CardInstance) -> void: g.destroy(i))
	func describe() -> String:
		return "destroy each artifact and creature with mana value equal to the number of fuse counters on this artifact"


# -------------------------------------------------------------- Scrying Glass --

## The colour the opponent shows most in public — their permanents and
## their graveyard — white when they show none. Never their hand.
static func glass_color_hint(g: MtgGame, who: int) -> int:
	var counts := {}
	for i in g.players[who].battlefield:
		for c in Mtg.WUBRG:
			if (i.cur_colors & c) != 0: counts[c] = int(counts.get(c, 0)) + 1
	for card in g.players[who].graveyard:
		for c in Mtg.WUBRG:
			if (card.data.color_mask() & c) != 0: counts[c] = int(counts.get(c, 0)) + 1
	var best: int = Mtg.ManaColor.W
	var most := 0
	for c in Mtg.WUBRG:
		if int(counts.get(c, 0)) > most:
			most = int(counts.get(c, 0))
			best = c
	return best

class Glass extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
		ai_helpful = true
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var who := t.player_id
		var module: GDScript = load(PATH)
		var number: int = g.agents[pid].choose_number(g, pid, 1, maxi(1, g.players[who].hand.size()),
			"Scrying Glass: choose a number greater than 0", 1)
		var color: int = g.agents[pid].choose_color(g, pid, "Scrying Glass: choose a color",
			module.glass_color_hint(g, who))
		var names: Array = []
		var matched := 0
		for card in g.players[who].hand:
			names.append(card.data.card_name)
			if (card.cur_colors & color) != 0: matched += 1
		g.reveal_information(-1, "Scrying Glass: %s reveals their hand" % g.players[who].player_name, names)
		g.log_line("Scrying Glass: %s chose %d %s; %s reveals %d" % [g.players[pid].player_name, number,
			String(Mtg.COLOR_NAMES.get(color, "colorless")), g.players[who].player_name, matched])
		if matched == number:
			g.draw_cards(pid, 1)
	func describe() -> String:
		return "choose a number and a color; target opponent reveals their hand; if exactly that many cards of that color, draw a card"


# -------------------------------------------------------------- Thran Foundry --

static func _foundry(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t != null and t.is_player:
		g.shuffle_graveyard_into_library(t.player_id)


# ---------------------------------------------------------------- Thran Golem --

static func _golem_keywords(g: MtgGame, s: CardInstance) -> void:
	if not g.is_enchanted(s): return
	for k in [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]:
		if not s.cur_keywords.has(k): s.cur_keywords.append(k)

static func _golem_pump(g: MtgGame, s: CardInstance) -> void:
	if not g.is_enchanted(s): return
	s.cur_power += 2
	s.cur_toughness += 2


# ----------------------------------------------------------- Urza's Incubator --

## The chooser's own deck and hand (their own to know): the creature type
## printed most often on their creature cards.
static func incubator_hint(g: MtgGame, pid: int) -> int:
	var counts := {}
	var names: Array = []
	names.append_array(g.players[pid].deck_names)
	for card in g.players[pid].hand: names.append(card.data.card_name)
	for card_name in names:
		var data := CardRegistry.get_card(String(card_name))
		if data == null or not data.is_creature(): continue
		for sub in data.subtypes: counts[sub] = int(counts.get(sub, 0)) + 1
	var hint := 0
	var most := 0
	for index in TYPES.ALL.size():
		var n := int(counts.get(TYPES.ALL[index].to_lower(), 0))
		if n > most:
			most = n
			hint = index
	return hint

static func _incubator_choose(g: MtgGame, s: CardInstance, pid: int) -> void:
	var pick := g.agents[pid].choose_option(g, pid, TYPES.ALL,
		"Urza's Incubator: choose a creature type", incubator_hint(g, pid))
	var kind: String = TYPES.ALL[clampi(pick, 0, TYPES.ALL.size() - 1)]
	g._rec(s, &"memory")
	s.memory["incubator_type"] = kind.to_lower()
	g.log_line("Urza's Incubator: %s chooses %s" % [g.players[pid].player_name, kind])

## "Creature spells of the chosen type cost {2} less to cast" — every
## caster's.
static func _incubator(_g: MtgGame, _caster: int, data: CardData, source: CardInstance) -> int:
	var kind := String(source.memory.get("incubator_type", ""))
	return -2 if kind != "" and data.is_creature() and data.subtypes.has(kind) else 0
