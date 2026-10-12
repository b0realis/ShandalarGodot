extends RefCounted
## Snow, counters and cold-weather effects. Reads live supertypes, not
## names or artwork: Melting removes snow without removing basic status.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Melting":
			c.static_ability(StaticAbility.new(_melting, "All lands are no longer snow.").changing_types())
		"Blizzard":
			c.castable_only_when(_cast_with_snow)
			c.static_ability(StaticAbility.new(_lock_flying, "Flying creatures don't untap."))
		"Energy Storm":
			c.static_ability(StaticAbility.new(_energy_storm, "Prevent instant and sorcery spell damage; flying creatures don't untap."))
		"Cold Snap":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _cold_snap, "Deal damage equal to that player's snow lands."))
		"Glacial Chasm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _chasm_enter, "Sacrifice a land.", F._self_enter))
			c.static_ability(StaticAbility.new(_chasm, "Your creatures can't attack; prevent all damage to you."))
		"Drift of the Dead":
			c.static_ability(StaticAbility.new(_drift, "Power and toughness equal your snow lands.").setting_base_pt())
		"Woolly Mammoths":
			c.static_ability(StaticAbility.new(_mammoths, "Trample while you control a snow land.").changing_abilities())
		"Arctic Foxes":
			c.static_ability(StaticAbility.new(_foxes, "Conditional evasion against defending snow lands."))
		"Karplusan Giant":
			var ability := F._ability("", false, PumpEffect.new(1, 1).self_buff())
			ability.tap_permanent_count = 1
			ability.tap_permanent_filter = _snow_land
			c.activated(ability)
		"Gangrenous Zombies":
			c.activated(F._ability("", true, F.Action.new(_zombies, "deal 1 damage to each creature and player, or 2 with a snow Swamp") \
				.with_ai_role(&"sweep_each_creature_and_player", {"amount": _zombies_amount})).with_sacrifice_cost())
		"Balduvian Conjurer":
			c.activated(F._ability("", true, F.Action.new(_animate_snow, "target snow land becomes a 2/2 creature this turn",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target snow land", _snow_land), true)))
		"Avalanche":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target snow land", _snow_land)).x_targets())
		"Icequake", "Thermokarst":
			c.spell(SnowDestroy.new(c.card_name == "Thermokarst"))
		"Hallowed Ground":
			c.activated(F._ability("{W}{W}", false, ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target nonsnow land you control", _nonsnow).with_source_filter(F._own))))
		"Snowfall":
			var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _snowfall,
				"Add blue mana usable only for cumulative upkeep.", _island_mana).as_mana_trigger()
			trigger.mana_bonus_subtype = "island"
			trigger.mana_bonus_color = Mtg.ManaColor.U
			trigger.mana_bonus_amount = 1
			trigger.mana_bonus_snow_extra = 1
			trigger.mana_bonus_restriction = "cumulative_upkeep"
			c.triggered(trigger)
		"Withering Wisps":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _empty_sacrifice,
				"If no creatures are on the battlefield, sacrifice this enchantment.", _no_creatures))
			c.activated(F._ability("{B}", false, DamageAllEffect.new(1).and_each_player()).only_if(_wisps_limit))
		"Staff of the Ages":
			c.static_ability(StaticAbility.new(_staff, "Landwalk doesn't prevent blocking."))
		"Curse of Marit Lage":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _tap_islands, "Tap all Islands.", F._self_enter))
			c.static_ability(StaticAbility.new(_lock_islands, "Islands don't untap."))
		"Wrath of Marit Lage":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _tap_red, "Tap all red creatures.", F._self_enter))
			c.static_ability(StaticAbility.new(_lock_red, "Red creatures don't untap."))
		"Fyndhorn Pollen":
			c.static_ability(StaticAbility.new(_pollen, "All creatures get -1/-0."))
			c.activated(F._ability("{1}{G}", false, MassPumpEffect.new(-1, 0)))
		"Iceberg":
			c.as_it_enters(_iceberg_enter)
			c.activated(F._ability("{3}", false, F.Action.new(_add_ice, "put an ice counter on this enchantment")))
			var release := ManaAbility.new(Mtg.ManaColor.C).without_tap().with_counter_cost("ice")
			release.planner_counter_cost = true
			c.mana(release)
		"Time Bomb":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._counter_upkeep.bind("time"),
				"Put a time counter on this artifact.", F._your_upkeep))
			c.activated(F._ability("{1}", true, F.Action.new(_time_bomb, "deal damage equal to time counters to each creature and player") \
				.with_ai_role(&"sweep_each_creature_and_player", {"amount": _time_bomb_amount})).with_sacrifice_cost())
		_:
			return false
	return true

static func _snow_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.SNOW) != 0
static func _nonsnow(i: CardInstance) -> bool: return i.is_land() and not _snow_land(i)
static func _land(i: CardInstance) -> bool: return i.is_land()
static func snow_count(g: MtgGame, pid: int, subtype := "") -> int:
	var count := 0
	for i in g.players[pid].battlefield:
		if _snow_land(i) and (subtype == "" or i.has_subtype(subtype)): count += 1
	return count
static func _cast_with_snow(g: MtgGame, pid: int) -> String:
	return "" if snow_count(g, pid) > 0 else "you must control a snow land"
static func _melting(g: MtgGame, _source: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land(): i.cur_supertypes &= ~Mtg.Supertype.SNOW
static func _lock_flying(g: MtgGame, _source: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING): i.cur_skips_untap = true
static func _spell(i: CardInstance) -> bool:
	return i.zone == Mtg.Zone.STACK and (i.is_type(Mtg.CardType.INSTANT) or i.is_type(Mtg.CardType.SORCERY))
static func _spell_source(_g: MtgGame, i: CardInstance) -> bool: return _spell(i)
static func _spell_packet(p: DamagePacket) -> bool:
	return p.source_was_spell and (p.source.is_type(Mtg.CardType.INSTANT) or p.source.is_type(Mtg.CardType.SORCERY))
static func _all(_i: CardInstance) -> bool: return true
static func _energy_storm(g: MtgGame, source: CardInstance) -> void:
	_lock_flying(g, source)
	for p in g.players: p.static_prevention_shields.append({"desc": source.data.card_name, "filter": _spell, "packet_filter": _spell_packet})
	for i in g.all_battlefield():
		i.cur_damage_immunity.append({"desc": source.data.card_name, "filter": _spell_source, "packet_filter": _spell_packet})
static func _chasm(g: MtgGame, source: CardInstance) -> void:
	g.players[source.controller_id].static_prevention_shields.append({"desc": source.data.card_name, "filter": _all})
	for i in g.players[source.controller_id].battlefield:
		if i.is_creature(): i.cur_cant_attack = true
static func _chasm_enter(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := int(g.trigger_context(source).controller)
	var lands: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land(): lands.append(i)
	if not lands.is_empty():
		var pick := g.agents[pid].choose_card(g, pid, lands, "Glacial Chasm: sacrifice a land")
		if pick != null: g.sacrifice_permanent(pick)
static func _cold_snap(g: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data.player)
	g.deal_damage(source, TargetRef.player(pid), snow_count(g, pid))
static func _drift(g: MtgGame, source: CardInstance) -> void:
	source.cur_power = snow_count(g, source.controller_id)
	source.cur_toughness = source.cur_power
static func _mammoths(g: MtgGame, source: CardInstance) -> void:
	if snow_count(g, source.controller_id) > 0 and not source.cur_keywords.has(Mtg.Keyword.TRAMPLE):
		source.cur_keywords.append(Mtg.Keyword.TRAMPLE)
static func _foxes(g: MtgGame, source: CardInstance) -> void:
	if snow_count(g, 1 - source.controller_id) > 0: source.cur_cant_be_blocked_by_power_ge = 2
static func _zombies(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	DamageAllEffect.new(2 if snow_count(g, pid, "swamp") > 0 else 1).and_each_player().resolve(g, source, pid, null)
static func _animate_snow(g: MtgGame, _source: CardInstance, _pid: int, target: TargetRef, _x: int) -> void:
	g.continuous.add_until_eot_animation(target.instance_id, Mtg.CardType.CREATURE, 2, 2)
	g.recalculate()
static func _island_mana(_g: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	return (event.data.instance as CardInstance).has_subtype("island")
static func _snowfall(g: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var land: CardInstance = event.data.instance
	var pid := land.controller_id
	var count := 2 if _snow_land(land) else 1
	if g.agents[pid].choose_yes_no(g, pid, "Snowfall: add %d blue mana only for cumulative upkeep?" % count,
			g.current_step() == Mtg.Step.UPKEEP):
		g.players[pid].mana_pool.add_restricted(Mtg.ManaColor.U, count, "cumulative_upkeep")
static func _no_creatures(g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool:
	for i in g.all_battlefield():
		if i.is_creature(): return false
	return true
static func _empty_sacrifice(g: MtgGame, source: CardInstance, e: GameEvent) -> void:
	if F._same_trigger_source(g, source) and _no_creatures(g, source, e): g.sacrifice_permanent(source)
static func _wisps_limit(g: MtgGame, source: CardInstance) -> String:
	return "" if int(source.ability_uses.get(0, 0)) < snow_count(g, source.controller_id, "swamp") else "activation limit equals your snow Swamps"
static func _staff(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		for walk in i.cur_landwalk: g.nullified_landwalk[walk] = true
static func _tap_islands(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("island"): g.tap_permanent(i)
static func _lock_islands(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("island"): i.cur_skips_untap = true
static func _tap_red(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.R) != 0: g.tap_permanent(i)
static func _lock_red(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.R) != 0: i.cur_skips_untap = true
static func _pollen(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_power -= 1
static func _iceberg_enter(_g: MtgGame, source: CardInstance, _pid: int) -> void:
	source.counters["ice"] = int(source.memory.get("x_value", 0))
static func _add_ice(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and source.layer_timestamp == int(g.cost_paid("_source_timestamp", -1)):
		g.add_counters(source, "ice")
static func _time_bomb(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var counters: Dictionary = g.cost_paid("_source_counters", {})
	DamageAllEffect.new(int(counters.get("time", 0))).and_each_player().resolve(g, source, pid, null)
# --- campaign 2026-10-12 f-aiB: the sweep each shape declares (b4-3) ---
## What the sweep would deal if activated now — the `amount` the AI's
## `sweep_each_creature_and_player` reader prices (engine/ai/ice_age_tactics.gd).
static func _zombies_amount(g: MtgGame, source: CardInstance) -> int:
	return 2 if snow_count(g, source.controller_id, "swamp") > 0 else 1
static func _time_bomb_amount(_g: MtgGame, source: CardInstance) -> int:
	return int(source.counters.get("time", 0))
# --- end campaign 2026-10-12 f-aiB ---

class SnowDestroy extends DestroyEffect:
	var gain: bool
	func _init(gain_life: bool) -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
			func(i: CardInstance) -> bool: return i.is_land()))
		gain = gain_life
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		if victim == null: return
		var snow := (victim.cur_supertypes & Mtg.Supertype.SNOW) != 0
		var owner := victim.controller_id
		g.begin_simultaneous()
		g.destroy(victim)
		if snow:
			if gain: g.adjust_life(pid, 1)
			else: g.deal_damage(source, TargetRef.player(owner), 1)
		g.end_simultaneous()
