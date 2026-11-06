extends RefCounted
## Urza's Legacy (_enchantments, Pack 10). Non-Aura enchantments: global statics, triggers and activations.
##
## - The "sacrifice this enchantment and …" upkeep cards (Planar Collapse,
##   Second Chance, Brink of Madness, Impending Disaster, Defense of the
##   Heart) carry an intervening "if" (CR 603.4), checked as they trigger
##   and again on resolution. Both halves are instructions: the rest
##   happens even when the enchantment can no longer be sacrificed (it
##   left, or another player controls it — CR 701.17a).
## - Aura Flux grants Energy Flux's upkeep tax to every OTHER enchantment,
##   each paid by that enchantment's controller in their own upkeep; two
##   Fluxes grant it twice.
## - Delusions of Mediocrity: "you" in the leave trigger is the player who
##   controlled it as it left (a Donated Delusions costs its new owner).
## - Engineered Plague's creature type is chosen as it enters (CR 614.1c);
##   the -1/-1 is read live (a creature gaining the type shrinks at once).
## - No Mercy hears one "deals damage" event per source per damage event;
##   the creature is destroyed only while it is still that object.
## - Martyr's Cause is Circle of Despair's shield ("to any target").
## - Rivalry: an intervening "if" over the upkeep player's lands.
## - Defense of the Heart: up to two creature cards, chosen one by one, enter
##   together (E10's `put_onto_battlefield_together`), then one shuffle.
## tests/cards/test_pack_10_B6_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const E := preload("res://cards/sets/usg/_enchantments.gd")
const TYPES := preload("res://engine/core/creature_types.gd")

const UPKEEP := Mtg.EventType.UPKEEP_START


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Knighthood":
			c.static_ability(StaticAbility.new(_grant_own.bind(Mtg.Keyword.FIRST_STRIKE),
				"Creatures you control have first strike.").changing_abilities())
		"Martyr's Cause":
			c.activated(ActivatedAbility.new("", false, [SourceShieldEffect.prevent_to_target()],
				"Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.") \
				.with_sacrifice_of("creature", E._creature).may_sacrifice_itself())
		"Planar Collapse":
			c.triggered(TriggeredAbility.new(UPKEEP, _planar_collapse,
				"At the beginning of your upkeep, if there are four or more creatures on the battlefield, sacrifice this enchantment and destroy all creatures. They can't be regenerated.",
				_four_creatures))
		# ------------------------------------------------------------- blue
		"Aura Flux":
			var tax := TriggeredAbility.new(UPKEEP, F._upkeep_payment.bind("{2}"),
				"At the beginning of your upkeep, sacrifice this enchantment unless you pay {2}.",
				F._your_upkeep).capturing(F._source_context)
			c.static_ability(StaticAbility.new(_flux.bind(tax),
				"Other enchantments have \"At the beginning of your upkeep, sacrifice this enchantment unless you pay {2}.\"") \
				.changing_abilities().granting_triggers([UPKEEP]))
		"Delusions of Mediocrity":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _delusions_gain,
				"When this enchantment enters, you gain 10 life.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _delusions_lose,
				"When this enchantment leaves the battlefield, you lose 10 life.",
				F._self_enter).capturing(_left_under))
		"Levitation":
			c.static_ability(StaticAbility.new(_grant_own.bind(Mtg.Keyword.FLYING),
				"Creatures you control have flying.").changing_abilities())
		"Second Chance":
			c.triggered(TriggeredAbility.new(UPKEEP, _second_chance,
				"At the beginning of your upkeep, if you have 5 or less life, sacrifice this enchantment and take an extra turn after this one.",
				_five_or_less_life))
		# ------------------------------------------------------------ black
		"Brink of Madness":
			c.triggered(TriggeredAbility.new(UPKEEP, _brink,
				"At the beginning of your upkeep, if you have no cards in hand, sacrifice this enchantment and target opponent discards their hand.",
				_empty_handed).targeting(TargetSpec.opponent()))
		"Engineered Plague":
			c.as_it_enters(_plague_choose).with_chosen_type(PLAGUE)
			c.static_ability(StaticAbility.new(_plague, "All creatures of the chosen type get -1/-1."))
		"No Mercy":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SOURCE_DEALT_DAMAGE, _no_mercy,
				"Whenever a creature deals damage to you, destroy it.",
				_creature_dealt_damage_to_me).capturing(_damage_source_context))
		"Phyrexian Reclamation":
			c.activated(ActivatedAbility.new("{1}{B}", false, [ReturnFromGraveyardEffect.new()],
				"{1}{B}, Pay 2 life: Return target creature card from your graveyard to your hand.") \
				.with_life_cost(2))
		"Subversion":
			c.triggered(TriggeredAbility.new(UPKEEP, _subversion,
				"At the beginning of your upkeep, each opponent loses 1 life. You gain life equal to the life lost this way.",
				F._your_upkeep))
		# -------------------------------------------------------------- red
		"Ghitu War Cry":
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0)],
				"{R}: Target creature gets +1/+0 until end of turn."))
		"Impending Disaster":
			c.triggered(TriggeredAbility.new(UPKEEP, _impending_disaster,
				"At the beginning of your upkeep, if there are seven or more lands on the battlefield, sacrifice this enchantment and destroy all lands.",
				_seven_lands))
		"Rivalry":
			c.triggered(TriggeredAbility.new(UPKEEP, _rivalry,
				"At the beginning of each player's upkeep, if that player controls more lands than each other player, this enchantment deals 2 damage to them.",
				E._upkeep_player_has_most_lands).capturing(E._upkeep_player_context))
		# ------------------------------------------------------------ green
		"Defense of the Heart":
			c.triggered(TriggeredAbility.new(UPKEEP, _defense_of_the_heart,
				"At the beginning of your upkeep, if an opponent controls three or more creatures, sacrifice this enchantment, search your library for up to two creature cards, put those cards onto the battlefield, then shuffle.",
				_opponent_has_three_creatures))
		_: return false
	return true


## How many present creatures there are, both players' (CR 702.26b).
static func _creatures(g: MtgGame) -> int:
	var n := 0
	for i in g.all_battlefield():
		if g.is_present(i) and i.is_creature(): n += 1
	return n


## "Creatures you control have <keyword>" (layer 6).
static func _grant_own(g: MtgGame, s: CardInstance, keyword: int) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and not i.cur_keywords.has(keyword):
			i.cur_keywords.append(keyword)


# ============================================================ Planar Collapse

static func _four_creatures(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _creatures(g) >= 4


static func _planar_collapse(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if _creatures(g) < 4: return
	E.sacrifice_self(g, s)
	DestroyAllEffect.new("all creatures", E._creature, false).resolve(g, s, E.you(g, s), null)


# ================================================================== Aura Flux

## One tax per Aura Flux on every OTHER enchantment, whoever controls it.
static func _flux(g: MtgGame, s: CardInstance, tax: TriggeredAbility) -> void:
	for i in g.all_battlefield():
		if i != s and i.is_type(Mtg.CardType.ENCHANTMENT):
			i.cur_triggered_abilities.append(tax)


# ==================================================== Delusions of Mediocrity

static func _delusions_gain(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.adjust_life(E.you(g, s), 10)


static func _left_under(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["controller"] = int(e.data.get("from_controller", s.controller_id))
	return ctx


static func _delusions_lose(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("controller", s.controller_id))
	g.adjust_life(who, -10)


# ============================================================== Second Chance

static func _five_or_less_life(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and g.players[s.controller_id].life <= 5


static func _second_chance(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := E.you(g, s)
	if g.players[pid].life > 5: return
	E.sacrifice_self(g, s)
	g.add_extra_turn(pid)


# =========================================================== Brink of Madness

static func _empty_handed(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and g.players[s.controller_id].hand.is_empty()


static func _brink(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := E.you(g, s)
	if not g.players[pid].hand.is_empty(): return
	E.sacrifice_self(g, s)
	var t := g.current_trigger_target(0)
	if t != null and t.is_player: g.discard_hand(t.player_id)


# ========================================================== Engineered Plague

const PLAGUE := "plague_type"

## The fair hint: the creature type the OPPONENT shows most (public board).
static func _plague_choose(g: MtgGame, s: CardInstance, pid: int) -> void:
	var counts := {}
	for i in g.players[g.opponent_of(pid)].battlefield:
		if i.is_creature():
			for kind in i.cur_subtypes: counts[kind] = int(counts.get(kind, 0)) + 1
	var best := 0
	var score := -1
	for index in TYPES.ALL.size():
		var n := int(counts.get(TYPES.ALL[index].to_lower(), 0))
		if n > score:
			best = index
			score = n
	var pick := g.agents[pid].choose_option(g, pid, TYPES.ALL,
		"Engineered Plague: choose a creature type", best)
	var kind: String = TYPES.ALL[clampi(pick, 0, TYPES.ALL.size() - 1)]
	g._rec(s, &"memory")
	s.memory[PLAGUE] = kind.to_lower()
	g.log_line("Engineered Plague: %s chooses %s" % [g.players[pid].player_name, kind])


static func _plague(g: MtgGame, s: CardInstance) -> void:
	var kind := String(s.memory.get(PLAGUE, ""))
	if kind == "": return
	for i in g.all_battlefield():
		if i.is_creature() and i.has_subtype(kind):
			i.cur_power -= 1
			i.cur_toughness -= 1


# =================================================================== No Mercy

## A creature source — its live types, or as it last existed (CR 113.7a) —
## that dealt damage to No Mercy's controller in this event.
static func _creature_dealt_damage_to_me(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var source: CardInstance = e.data.get("source")
	return source != null and (g.source_types(source) & Mtg.CardType.CREATURE) != 0 \
		and (e.data.get("to_players", []) as Array).has(s.controller_id)


static func _damage_source_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var source: CardInstance = e.data.get("source")
	ctx["id"] = source.id
	ctx["stamp"] = source.layer_timestamp
	return ctx


## "Destroy it" — only the object that dealt the damage (CR 400.7).
static func _no_mercy(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var it := g.find_instance(int(ctx.get("id", -1)))
	if g.is_present(it) and it.layer_timestamp == int(ctx.get("stamp", -2)):
		g.destroy(it)


# ================================================================= Subversion

## The life actually lost (a player at a "can't lose life" floor loses
## none), gained back by Subversion's controller.
static func _subversion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := E.you(g, s)
	var lost := 0
	for other in g.players.size():
		if other == pid: continue
		var before := g.players[other].life
		g.adjust_life(other, -1)
		lost += maxi(0, before - g.players[other].life)
	if lost > 0: g.adjust_life(pid, lost)


# ========================================================= Impending Disaster

static func _lands(g: MtgGame) -> int:
	var n := 0
	for pid in g.players.size(): n += E.lands_of(g, pid)
	return n


static func _seven_lands(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _lands(g) >= 7


static func _impending_disaster(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if _lands(g) < 7: return
	E.sacrifice_self(g, s)
	DestroyAllEffect.new("all lands", E._land).resolve(g, s, E.you(g, s), null)


# ==================================================================== Rivalry

static func _rivalry(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("player", -1))
	if not E.has_most_lands(g, who): return
	g.deal_damage(s, TargetRef.player(who), 2)


# ======================================================= Defense of the Heart

static func _opponent_creatures(g: MtgGame, pid: int) -> int:
	var most := 0
	for other in g.players.size():
		if other == pid: continue
		var n := 0
		for i in g.players[other].battlefield:
			if g.is_present(i) and i.is_creature(): n += 1
		most = maxi(most, n)
	return most


static func _opponent_has_three_creatures(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _opponent_creatures(g, s.controller_id) >= 3


## Up to two creature cards, each pick free to find nothing (CR 701.19b);
## both enter at ONE moment (Pack 10 E10, CR 603.6a), then one shuffle
## (CR 701.19a). The searcher sees the whole library: the list is ranked
## biggest first, never in library order.
static func _defense_of_the_heart(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := E.you(g, s)
	if _opponent_creatures(g, pid) < 3: return
	E.sacrifice_self(g, s)
	var left: Array[CardInstance] = []
	for card in g.players[pid].library:
		if card.data.is_creature(): left.append(card)
	left.sort_custom(_bigger_card)
	var entries: Array = []
	for n in mini(2, left.size()):
		var pick := g.agents[pid].choose_card(g, pid, left,
			"Defense of the Heart: search for a creature card (%d of up to 2)" % (n + 1), true)
		if pick == null or not left.has(pick): break
		left.erase(pick)
		entries.append({"instance": pick, "controller": pid})
	var who := g.players[pid].player_name
	if entries.is_empty():
		g.log_line("%s searches their library and finds nothing" % who)
	else:
		g.put_onto_battlefield_together(entries)
	g.shuffle_library(pid)


static func _bigger_card(a: CardInstance, b: CardInstance) -> bool:
	var va := a.data.power + a.data.toughness + a.data.cost.mana_value()
	var vb := b.data.power + b.data.toughness + b.data.cost.mana_value()
	return va > vb if va != vb else a.id < b.id
