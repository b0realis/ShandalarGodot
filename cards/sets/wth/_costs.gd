extends RefCounted
## Weatherlight (_costs, Pack 8). Additional and alternative costs, cumulative upkeep and cost modifiers.
##
## Costs are the engine's own vocabulary (engine/additional_object_costs.gd,
## CardData.with_alternative_cost / with_object_cost, CumulativeUpkeep and
## its custom payments): validated before anything moves, chosen by the
## payer, paid as the spell or ability goes on the stack (CR 601.2h,
## 602.2b, 702.24a). tests/cards/test_pack_8_b8_weatherlight.gd pins each.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Alms":
			c.activated(ActivatedAbility.new("{1}", false, [PreventDamageEffect.new(1).target_creature()],
				"{1}, Exile the top card of your graveyard: Prevent the next 1 damage that would be dealt to target creature this turn.")
				.with_object_cost(OC.exiling_top("card")))
		"Aura of Silence":
			c.with_cost_modifier(_silence_tax)
			c.activated(ActivatedAbility.new("", false,
				[DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or enchantment", _artifact_or_enchantment))],
				"Sacrifice this enchantment: Destroy target artifact or enchantment.").with_sacrifice_cost())
		"Inner Sanctum":
			CumulativeUpkeep.attach(c, "", 2)
			c.static_ability(StaticAbility.new(_sanctum, "Prevent all damage that would be dealt to creatures you control."))
		"Revered Unicorn":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _unicorn_life,
				"When this creature leaves the battlefield, you gain life equal to the number of age counters on it.",
				F._self_enter).capturing(_departure_context))
		"Volunteer Reserves":
			CumulativeUpkeep.attach(c, "{1}")
		# ------------------------------------------------------------- blue
		"Abjure":
			c.spell(CounterEffect.new("target spell"))
			c.with_object_cost(OC.sacrificing("a blue permanent", _blue))
		"Ancestral Knowledge":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _knowledge,
				"When this enchantment enters, look at the top ten cards of your library, then exile any number of them and put the rest back on top of your library in any order.",
				F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _shuffle_on_leaving,
				"When this enchantment leaves the battlefield, shuffle your library.",
				F._self_enter).capturing(_departure_context))
		"Psychic Vortex":
			CumulativeUpkeep.attach_draw(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _vortex_end,
				"At the beginning of your end step, sacrifice a land and discard your hand.", F._your_upkeep))
		# ------------------------------------------------------------ black
		"Gallowbraid", "Morinfen":
			CumulativeUpkeep.attach(c, "", 1)
		"Haunting Misery":
			c.spell(DamageEffect.new(0).x_damage().target_player())
			c.with_object_cost(OC.times_x(OC.exiling(Mtg.Zone.GRAVEYARD, "a creature card", _creature_card)))
		"Necratog":
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()],
				"Exile the top creature card of your graveyard: This creature gets +2/+2 until end of turn.")
				.with_object_cost(OC.exiling_top("creature card", _creature_card)))
		"Spinning Darkness":
			c.spell(DamageEffect.new(3).target_creature("target nonblack creature", _nonblack))
			c.spell(GainLifeEffect.new(3))
			c.with_alternative_cost("Exile the top three black cards of your graveyard",
				{"object_costs": [OC.exiling_top("black card", _black_card, 3)]})
			c.with_ai_mode(_darkness_mode)
		"Tendrils of Despair":
			c.spell(F.Action.new(_tendrils, "target opponent discards two cards", TargetSpec.opponent())
				.with_ai_role(&"discard", {"count": 2}))
			c.with_object_cost(OC.sacrificing("a creature", _creature))
		"Wave of Terror":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _terror_wave,
				"At the beginning of your draw step, destroy each creature with mana value equal to the number of age counters on this enchantment. They can't be regenerated.",
				F._your_upkeep))
		"Zombie Scavengers":
			c.activated(ActivatedAbility.new("", false, [RegenerateEffect.new()],
				"Exile the top creature card of your graveyard: Regenerate this creature.")
				.with_object_cost(OC.exiling_top("creature card", _creature_card)))
		# -------------------------------------------------------------- red
		"Firestorm":
			c.spell(DamageEffect.new(0).x_damage().any_target().x_targets())
			c.with_object_cost(OC.times_x(OC.discarding("a card")))
		"Heart of Bogardan":
			CumulativeUpkeep.attach(c, "{2}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.CUMULATIVE_UPKEEP_UNPAID, _heart_blast,
				"When a player doesn't pay this enchantment's cumulative upkeep, this enchantment deals X damage to target player or planeswalker and each creature that player or that planeswalker's controller controls, where X is twice the number of age counters on this enchantment minus 2.",
				_own_upkeep_unpaid).targeting(TargetSpec.player(), F._enemy_first, "Select target player."))
		# ------------------------------------------------------------ green
		"Aboroth":
			CumulativeUpkeep.attach_self_counter(c, "-1/-1")
		"Arctic Wolves":
			CumulativeUpkeep.attach(c, "{2}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _wolves_draw,
				"When this creature enters, draw a card.", F._self_enter))
		"Mwonvuli Ooze":
			CumulativeUpkeep.attach(c, "{2}")
			# CR 604.3: a characteristic-defining ability works in every zone
			# (no age counters there: 1/1); on the battlefield it is layer 7a.
			c.static_ability(StaticAbility.new(_ooze, "Power and toughness are each equal to 1 plus twice the number of age counters on it.").setting_base_pt())
			c.characteristic_definition = _ooze
		"Uktabi Efreet":
			CumulativeUpkeep.attach(c, "{G}")
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()
static func _blue(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.U)
static func _nonblack(i: CardInstance) -> bool: return not i.has_color(Mtg.ManaColor.B)
## The LIVE colour (an off-zone colour rule reaches the graveyard, E10).
static func _black_card(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.B)
static func _artifact_or_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)

## A leaves-the-battlefield trigger's "you": the controller it left from,
## and the counters it left with (CR 603.10a looks back in time).
static func _departure_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp,
		"controller": int(e.data.get("from_controller", s.controller_id)),
		"ages": int(s.last_counters.get("age", 0))}

static func _context_pid(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))


# -------------------------------------------------------------- Aura of Silence

## "Artifact and enchantment spells your opponents cast cost {2} more."
static func _silence_tax(_g: MtgGame, caster: int, data: CardData, modifier: CardInstance) -> int:
	if caster == modifier.controller_id: return 0
	return 2 if data.is_type(Mtg.CardType.ARTIFACT) or data.is_type(Mtg.CardType.ENCHANTMENT) else 0


# ---------------------------------------------------------------- Inner Sanctum

static func _sanctum(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature(): i.cur_prevent_all_damage_taken = true


# --------------------------------------------------------------- Revered Unicorn

static func _unicorn_life(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var ages := int(ctx.get("ages", int(s.last_counters.get("age", 0))))
	if ages > 0: g.adjust_life(int(ctx.get("controller", s.owner_id)), ages)


# ----------------------------------------------------------- Ancestral Knowledge

## Look at the top ten; each is offered for exile (the default answer exiles
## surplus lands only); the rest go back on top in the order the owner
## chooses — the first one chosen ends on top.
static func _knowledge(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _context_pid(g, s)
	var library: Array = g.players[pid].library
	var n := mini(10, library.size())
	if n <= 0: return
	var seen: Array[CardInstance] = []
	for k in n: seen.append(library[library.size() - 1 - k])
	var names: Array = []
	for card in seen: names.append(card.data.card_name)
	g.reveal_information(pid, "Ancestral Knowledge — the top %d card(s) of your library" % n, names)
	var lands := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): lands += 1
	for i in g.players[pid].hand:
		if i.data.is_land(): lands += 1
	var kept: Array[CardInstance] = []
	for card in seen:
		var hint := card.data.is_land() and lands >= 6
		if g.agents[pid].choose_yes_no(g, pid, "Ancestral Knowledge: exile %s?" % card.data.card_name, hint):
			g.exile_library_card(card)
		else:
			kept.append(card)
			if card.data.is_land(): lands += 1
	var ordered: Array[CardInstance] = []
	while kept.size() > 1:
		var next := g.agents[pid].choose_card(g, pid, kept,
			"Ancestral Knowledge: choose the next card from the top", false, false, true)
		if next == null or not kept.has(next): next = kept[0]
		ordered.append(next)
		kept.erase(next)
	ordered.append_array(kept)
	if not ordered.is_empty(): g.reorder_top_of_library(pid, ordered)

static func _shuffle_on_leaving(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.shuffle_library(_context_pid(g, s))


# ---------------------------------------------------------------- Psychic Vortex

## "Sacrifice a land and discard your hand" — the controller picks the land
## (offered most-duplicated basic first, the sensible default).
static func _vortex_end(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _context_pid(g, s)
	var lands: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land(): lands.append(i)
	if not lands.is_empty():
		var copies := {}
		for i in lands: copies[i.data.card_name] = int(copies.get(i.data.card_name, 0)) + 1
		lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var ab := (a.cur_supertypes & Mtg.Supertype.BASIC) != 0
			var bb := (b.cur_supertypes & Mtg.Supertype.BASIC) != 0
			if ab != bb: return ab
			return int(copies[a.data.card_name]) > int(copies[b.data.card_name]))
		var pick := g.agents[pid].choose_card(g, pid, lands, "Psychic Vortex: sacrifice a land", false, false, true)
		if pick == null or not lands.has(pick): pick = lands[0]
		g.sacrifice_permanent(pick)
	var hand: Array = g.players[pid].hand.duplicate()
	if not hand.is_empty(): g.discard_cards(pid, hand)


# ------------------------------------------------------------- Spinning Darkness

## The AI's payment row: three black cards from the top of the graveyard
## cost a card a graveyard rarely misses, so they are used whenever they
## can pay; otherwise the printed {4}{B}{B}.
static func _darkness_mode(g: MtgGame, pid: int) -> int:
	return 1 if OC.refusal(g, pid, [OC.exiling_top("black card", _black_card, 3)]) == "" else 0


# -------------------------------------------------------------- the rest of it

## "Target opponent discards two cards" — that player chooses which.
static func _tendrils(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var cards: Array[CardInstance] = g.players[who].hand.duplicate()
	var picks: Array[CardInstance] = []
	for n in mini(2, cards.size()):
		var pick := g.agents[who].choose_card(g, who, cards, "Tendrils of Despair: choose a card to discard")
		if pick == null or not cards.has(pick): pick = cards[0]
		picks.append(pick)
		cards.erase(pick)
	if not picks.is_empty(): g.discard_cards(who, picks)

static func _terror_wave(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var counters := s.counters if F._same_trigger_source(g, s) else s.last_counters
	var ages := int(counters.get("age", 0))
	var doomed: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature() and (0 if i.face_down else i.data.cost.mana_value()) == ages: doomed.append(i)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed: g.destroy(i, false)
	g.end_simultaneous()

static func _own_upkeep_unpaid(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s

## X = twice the age counters minus 2, read from the event (the Heart is in
## the graveyard by now). Every creature the TARGET player controls, and
## that player, are dealt X at once.
static func _heart_blast(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var x := 2 * int(e.data.get("ages", 0)) - 2
	var ref := g.current_trigger_target(0)
	if x <= 0 or ref == null or not ref.is_player: return
	var victims: Array[CardInstance] = []
	for i in g.players[ref.player_id].battlefield:
		if i.is_creature(): victims.append(i)
	g.begin_simultaneous()
	g.deal_damage(s, ref, x)
	for i in victims: g.deal_damage(s, TargetRef.card(i), x)
	g.end_simultaneous()

static func _wolves_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(_context_pid(g, s), 1)

static func _ooze(_g: MtgGame, s: CardInstance) -> void:
	var size := 1 + 2 * int(s.counters.get("age", 0))
	s.cur_power = size
	s.cur_toughness = size
