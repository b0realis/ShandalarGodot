extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const TYPES: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]
const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]
const SINGULARITY := [Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B]
const REALITY := [Mtg.ManaColor.R, 0, Mtg.ManaColor.G, Mtg.ManaColor.W, Mtg.ManaColor.B]

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Infernal Darkness", "Ritual of Subdual", "Naked Singularity", "Reality Twist":
			c.static_ability(StaticAbility.new(_mana_replacement.bind(c.card_name), "Replace the type of mana produced by affected lands."))
		"Glaciers":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{W}{U}"), "Pay {W}{U} or sacrifice this enchantment.", F._your_upkeep))
			c.static_ability(StaticAbility.new(_glaciers, "Mountains are Plains.").changing_land_types().reading_land_types(["mountain"], ["plains"]))
		"Illusionary Terrain":
			c.as_it_enters(_terrain_enter)
			c.static_ability(StaticAbility.new(_terrain, "Basic lands of the first chosen type are the second type.").changing_land_types().reading_chosen_land_types(_terrain_edge))
		"Earthlink":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{2}"), "Pay {2} or sacrifice this enchantment.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _earthlink, "That creature's controller sacrifices a land.", _creature_died))
		"Justice":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{W}{W}"), "Pay {W}{W} or sacrifice this enchantment.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _justice, "Deal that much damage to the red creature's or spell's controller.", _red_damage).capturing(_justice_context))
		"Monsoon": c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _monsoon, "Tap that player's untapped Islands and deal damage for each."))
		"Mudslide":
			c.static_ability(StaticAbility.new(_mudslide, "Creatures without flying don't untap during their untap steps."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _mudslide_upkeep, "You may pay {2} for each nonflying creature to untap."))
		"Freyalise's Winds":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _wind_counter, "Put a wind counter on that permanent.").capturing(wind_context))
			c.static_ability(StaticAbility.new(_winds, "Replace untapping in the untap step with removing all wind counters."))
		"Halls of Mist": c.static_ability(StaticAbility.new(_halls, "Creatures that attacked in their controller's last turn can't attack."))
		_: return false
	return true

static func _mana_replacement(g: MtgGame, _s: CardInstance, name: String) -> void:
	for i in g.all_battlefield():
		if not i.is_land(): continue
		var colors: Array = []
		if name == "Infernal Darkness": colors.append(Mtg.ManaColor.B)
		elif name == "Ritual of Subdual": colors.append(Mtg.ManaColor.C)
		else:
			var table: Array = SINGULARITY if name == "Naked Singularity" else REALITY
			for n in TYPES.size():
				if i.has_subtype(TYPES[n]) and table[n] != 0: colors.append(table[n])
		for color in colors:
			if not i.cur_land_mana_replacements.has(color): i.cur_land_mana_replacements.append(color)
static func _glaciers(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("mountain"): i.become_basic_land_type("plains", Mtg.ManaColor.W)
static func _terrain_enter(g: MtgGame, s: CardInstance, pid: int) -> void:
	var from := g.agents[pid].choose_option(g, pid, TYPES, "Illusionary Terrain: choose the land type to change", 3)
	var to := g.agents[pid].choose_option(g, pid, TYPES, "Illusionary Terrain: choose its new land type", 1)
	g._rec(s, &"memory")
	s.memory["terrain_from"] = from
	s.memory["terrain_to"] = to
## The reader's two chosen types for the CR 613.8 step among readers —
## nothing before the choice, so nothing depends on an unset Terrain.
static func _terrain_edge(s: CardInstance) -> Array:
	if not s.memory.has("terrain_from"): return [[], []]
	return [[TYPES[int(s.memory.terrain_from)]], [TYPES[int(s.memory.terrain_to)]]]
static func _terrain(g: MtgGame, s: CardInstance) -> void:
	if not s.memory.has("terrain_from"): return
	var from := int(s.memory.terrain_from)
	var to := int(s.memory.terrain_to)
	for i in g.all_battlefield():
		if i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0 and i.has_subtype(TYPES[from]): i.become_basic_land_type(TYPES[to], COLORS[to])
static func _creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool: return (e.data.instance.last_types & Mtg.CardType.CREATURE) != 0
static func _earthlink(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.controller)
	var lands: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_land(): lands.append(i)
	if not lands.is_empty():
		var pick := g.agents[who].choose_card(g, who, lands, "Earthlink: sacrifice a land")
		if pick != null: g.sacrifice_permanent(pick)
static func _red_damage(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var source: CardInstance = e.data.get("source")
	return source != null and (g.damage_source_colors(source) & Mtg.ManaColor.R) != 0 and (source.is_creature() or e.data.packet.source_was_spell)
static func _justice_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary:
	return {"who": e.data.source.controller_id, "damage": int(e.data.amount)}
static func _justice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	g.deal_damage(s, TargetRef.player(int(ctx.who)), int(ctx.damage))
static func _monsoon(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.player)
	var count := 0
	for i in g.players[who].battlefield:
		if i.is_land() and i.has_subtype("island") and not i.tapped:
			g.tap_permanent(i)
			count += 1
	g.deal_damage(s, TargetRef.player(who), count)
static func _mudslide(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and not i.has_keyword(Mtg.Keyword.FLYING): i.cur_skips_untap = true
static func _mudslide_upkeep(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.player)
	var chosen: Array[CardInstance] = []
	# Each optional payment is offered from public state; no creature untaps
	# until all choices have been made, so its mana cannot finance the rest.
	for i in g.players[who].battlefield:
		if i.is_creature() and i.tapped and not i.has_keyword(Mtg.Keyword.FLYING):
			if EffectBase.unless_paid(g, who, ManaCost.parse("{2}"), "Mudslide: pay {2} to untap " + i.data.card_name + "?", true): chosen.append(i)
	for i in chosen: g.untap_permanent(i)
static func _wind_counter(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var i: CardInstance = e.data.instance
	# A returned object must not receive a counter from its previous tap.
	if i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(g.trigger_context(_s).get("target_stamp", -1)): g.add_counters(i, "wind")
static func wind_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary: return {"target_stamp": e.data.instance.layer_timestamp}
static func _winds(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield(): i.cur_wind_untap_replacement = true
static func _halls(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		var last := g.players[i.controller_id].last_turn_number
		if i.is_creature() and last > 0 and int(i.memory.get("attack_turn_" + str(i.controller_id), -1)) == last: i.cur_cant_attack = true
