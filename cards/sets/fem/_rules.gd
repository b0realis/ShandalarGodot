extends RefCounted
## Shared Fallen Empires patterns. Each card still owns its metadata and
## build() file; this module has no static CardData cache or external code.

const LAND_COLORS := {
	"Bottomless Vault": Mtg.ManaColor.B, "Dwarven Hold": Mtg.ManaColor.R,
	"Hollow Trees": Mtg.ManaColor.G, "Icatian Store": Mtg.ManaColor.W,
	"Sand Silos": Mtg.ManaColor.U, "Dwarven Ruins": Mtg.ManaColor.R,
	"Ebon Stronghold": Mtg.ManaColor.B, "Havenwood Battleground": Mtg.ManaColor.G,
	"Ruins of Trokair": Mtg.ManaColor.W, "Svyelunite Temple": Mtg.ManaColor.U}
const STORAGE := ["Bottomless Vault", "Dwarven Hold", "Hollow Trees", "Icatian Store", "Sand Silos"]
const SPORES := ["Thallid", "Thallid Devourer", "Elvish Farmer", "Feral Thallid", "Spore Flower", "Thorn Thallid"]

static func apply(c: CardData) -> CardData:
	c = _configure(c)
	if c == null:
		return null
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid():
			trigger.capturing(_source_context)
	for ability in c.activated_abilities:
		var extra: Array[String] = []
		if ability.sacrifice_cost:
			extra.append("Sacrifice this permanent")
		if ability.sacrifice_filter.is_valid():
			extra.append("Sacrifice %d %s" % [ability.sacrifice_count, ability.sacrifice_filter_desc])
		if ability.counter_cost_kind != "":
			extra.append("Remove %d %s counter(s)" % [ability.counter_cost_count, ability.counter_cost_kind])
		if ability.discard_cost > 0 or ability.random_discard_cost > 0:
			extra.append("Discard %d card(s)%s" % [maxi(ability.discard_cost, ability.random_discard_cost),
				" at random" if ability.random_discard_cost > 0 else ""])
		if ability.graveyard_exile_filter.is_valid():
			extra.append("Exile %d %s from one graveyard" % [ability.graveyard_exile_count, ability.graveyard_exile_desc])
		if ability.tap_permanent_count > 0:
			extra.append("Tap %d eligible permanent(s)" % ability.tap_permanent_count)
		if not extra.is_empty():
			ability.text = "; ".join(extra) + " — " + ability.text
	return c

static func _configure(c: CardData) -> CardData:
	var name := c.card_name
	if LAND_COLORS.has(name):
		var color: int = LAND_COLORS[name]
		c.with_enters_tapped()
		if STORAGE.has(name):
			c.with_may_skip_untap()
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_storage, "If this land is tapped, put a storage counter on it.", _tapped_upkeep))
			c.mana(ManaAbility.new(color, 0).with_any_number_of_counters("storage"))
		else:
			c.mana(ManaAbility.new(color))
			c.mana(ManaAbility.new(color, 2).with_sacrifice())
		return c
	if SPORES.has(name):
		c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
			_counter_upkeep.bind("spore"), "Put a spore counter on this creature.", _your_upkeep))
		var effect: EffectBase = _saproling()
		if name == "Feral Thallid":
			effect = RegenerateEffect.new()
		elif name == "Spore Flower":
			effect = PreventCombatDamageEffect.new()
		elif name == "Thorn Thallid":
			effect = DamageEffect.new(1).any_target()
		c.activated(_ability("", false, effect).with_counter_cost("spore", 3))
		if name == "Elvish Farmer":
			c.activated(_ability("", false, GainLifeEffect.new(2)).with_sacrifice_of("Saproling", _subtype.bind("saproling")))
		elif name == "Thallid Devourer":
			c.activated(_ability("", false, PumpEffect.new(1, 2).self_buff()).with_sacrifice_of("Saproling", _subtype.bind("saproling")))
		return c
	match name:
		"Vodalian Soldiers", "Icatian Phalanx":
			pass
		"Aeolipile":
			c.activated(_ability("{1}", true, DamageEffect.new(2).any_target()).with_sacrifice_cost())
		"Armor Thrull":
			c.activated(_ability("", true, CounterMarkerEffect.new("+1/+2")).with_sacrifice_cost())
		"Balm of Restoration":
			c.activated(_ability("{1}", true, GainLifeEffect.new(2)).with_sacrifice_cost())
			c.activated(_ability("{1}", true, PreventDamageEffect.new(2).any_target()).with_sacrifice_cost())
		"Basal Thrull":
			c.mana(ManaAbility.new(Mtg.ManaColor.B, 2).with_sacrifice())
		"Brassclaw Orcs":
			c.with_cant_block_power_ge(2)
		"Breeding Pit":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_upkeep_payment.bind("{B}{B}"), "Sacrifice this enchantment unless you pay {B}{B}.", _your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
				_breed, "Create a 0/1 black Thrull creature token.", _your_upkeep))
		"Combat Medic":
			c.activated(_ability("{1}{W}", false, PreventDamageEffect.new(1).any_target()))
		"Conch Horn":
			c.activated(_ability("{1}", true, Action.new(_conch, "draw two cards, then put one card from your hand on top of your library")).with_sacrifice_cost())
		"Deep Spawn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_deep_upkeep, "Sacrifice this creature unless you mill two cards.", _your_upkeep))
			c.activated(_ability("{U}", false, Action.new(_shroud, "this creature gains shroud, taps, and skips its next untap")))
		"Homarid Warrior":
			c.activated(_ability("{U}", false, Action.new(_shroud, "this creature gains shroud, taps, and skips its next untap")))
		"Derelor":
			c.cost_modifier["spell_colored"] = _derelor_tax
		"Draconian Cylix":
			c.activated(_ability("{2}", true, RegenerateEffect.new().target_creature()).with_random_discard_cost(1))
		"Dwarven Armorer":
			for kind in ["+0/+1", "+1/+0"]:
				c.activated(_ability("{R}", true, CounterMarkerEffect.new(kind)).with_discard_cost(1))
		"Dwarven Catapult":
			c.spell(Action.new(_catapult, "deal X damage divided evenly among an opponent's creatures", TargetSpec.opponent()))
		"Dwarven Lieutenant", "Icatian Lieutenant":
			var tribe := "dwarf" if name == "Dwarven Lieutenant" else "soldier"
			var pump := PumpEffect.new(1, 0)
			pump.target_spec = TargetSpec.creature("target " + tribe, _subtype.bind(tribe))
			c.activated(_ability("{1}{R}" if tribe == "dwarf" else "{1}{W}", false, pump))
		"Dwarven Soldier":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _dwarf_block,
				"When blocking or blocked by Orcs, gets +0/+2 until end of turn.", _dwarf_orc_pair))
		"Elven Fortress":
			var pump := PumpEffect.new(0, 1)
			pump.target_spec = TargetSpec.creature("target blocking creature").with_game_filter(_blocking)
			c.activated(_ability("{1}{G}", false, pump))
		"Elven Lyre":
			c.activated(_ability("{1}", true, PumpEffect.new(2, 2)).with_sacrifice_cost())
		"Elvish Hunter":
			c.activated(_ability("{1}{G}", true, Action.new(_hunter, "target creature skips its next untap", TargetSpec.creature())))
		"Elvish Scout":
			var spec := TargetSpec.creature("target attacking creature you control").with_source_filter(_own_attacker)
			c.activated(_ability("{G}", true, Action.new(_scout, "untap and prevent combat damage to and from target attacker", spec, true)))
		"Farrelite Priest", "Initiates of the Ebon Hand":
			var color := Mtg.ManaColor.W if name == "Farrelite Priest" else Mtg.ManaColor.B
			c.mana(ManaAbility.new(color).without_tap().with_mana_cost("{1}")
				.with_plannable_conversion().with_side_effect(_fourth_conversion))
		"Fungal Bloom":
			c.activated(_ability("{G}{G}", false, CounterMarkerEffect.new("spore", 1,
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Fungus", _subtype.bind("fungus")))))
		"Goblin Chirurgeon":
			c.activated(_ability("", false, RegenerateEffect.new().target_creature())
				.with_sacrifice_of("Goblin", _subtype.bind("goblin")).may_sacrifice_itself())
		"Goblin Grenade":
			c.with_additional_sacrifice("Goblin", _subtype.bind("goblin"))
			c.spell(DamageEffect.new(5).any_target())
		"Goblin Kites":
			var spec := TargetSpec.creature("target creature you control with toughness 2 or less").with_source_filter(_small_own)
			c.activated(_ability("{R}", false, Action.new(_kites, "target creature gains flying; a lost end-step coin flip sacrifices it", spec, true)))
		"High Tide":
			c.spell(Action.new(_high_tide, "Islands produce an additional blue mana this turn"))
		"Homarid", "Tidal Influence":
			c.with_enters_counters("tide", 1)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_tide_upkeep, "Put a tide counter on this permanent.", _your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK,
				_tide_reset, "Remove all tide counters from this permanent.", _four_tides))
			c.static_ability(StaticAbility.new(_tide_static, "Tide counters change power and toughness."))
			if name == "Tidal Influence":
				c.castable_only_when(_one_influence)
		"Homarid Shaman":
			var tap := TapEffect.new()
			tap.target_spec = TargetSpec.creature("target green creature", _color.bind(Mtg.ManaColor.G))
			c.activated(_ability("{U}", false, tap))
		"Homarid Spawning Bed":
			c.activated(_ability("{1}{U}{U}", false, Action.new(_spawning_bed, "create Camarid tokens equal to the sacrificed creature's mana value"))
				.with_sacrifice_of("blue creature", _colored_creature.bind(Mtg.ManaColor.U)))
		"Hymn to Tourach":
			c.spell(RandomHandDiscardEffect.new(2))
		"Icatian Infantry":
			for keyword in [Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.BANDING]:
				c.activated(_ability("{1}", false, PumpEffect.new(0, 0, [keyword]).self_buff()))
		"Icatian Javelineers":
			c.with_enters_counters("javelin", 1)
			c.activated(_ability("", true, DamageEffect.new(1).any_target()).with_counter_cost("javelin"))
		"Icatian Moneychanger":
			c.with_enters_counters("credit", 3)
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
				_money_enter, "This creature deals 3 damage to you.", _self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_counter_upkeep.bind("credit"), "Put a credit counter on this creature.", _your_upkeep))
			c.activated(_ability("", false, Action.new(_cash_credit, "gain one life per credit counter"))
				.with_sacrifice_cost().during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Icatian Priest":
			c.activated(_ability("{1}{W}{W}", false, PumpEffect.new(1, 1)))
		"Icatian Scout":
			c.activated(_ability("{1}", true, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE])))
		"Icatian Skirmishers":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS,
				_skirmishers, "Creatures banded with this creature gain first strike.", _self_attack).capturing(_band_context))
		"Icatian Town":
			c.spell(CreateTokenEffect.new("Citizen", 1, 1, Mtg.ManaColor.W, "citizen", 4))
		"Implements of Sacrifice":
			for color in _all_colors(null, null):
				c.mana(ManaAbility.new(color, 2).with_mana_cost("{1}")
					.with_sacrifice().with_plannable_conversion())
		"Orcish Captain":
			c.activated(_ability("{1}", false, Action.new(_captain, "flip a coin for +2/+0 or -0/-2", TargetSpec.creature("target Orc", _subtype.bind("orc")), true)))
		"Orcish Veteran":
			c.activated(_ability("{R}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()))
			c.static_ability(StaticAbility.new(_veteran, "Cannot block white creatures with power 2 or greater."))
		"Order of Leitbur", "Order of the Ebon Hand":
			var cost := "{W}" if name == "Order of Leitbur" else "{B}"
			c.activated(_ability(cost, false, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()))
			c.activated(_ability(cost + cost, false, PumpEffect.new(1, 0).self_buff()))
		"Orgg":
			c.with_cant_block_power_ge(3)
			c.static_ability(StaticAbility.new(_orgg, "Cannot attack into an untapped creature with power 3 or greater.").reading_pt())
		"Rainbow Vale":
			for color in _all_colors(null, null):
				c.mana(ManaAbility.new(color).with_side_effect(_rainbow))
		"Ring of Renewal":
			c.activated(ActivatedAbility.new("{5}", true, [RandomHandDiscardEffect.new(1, true), DrawEffect.new(2)], c.oracle_text))
		"River Merfolk":
			c.activated(_ability("{U}", false, Action.new(_mountainwalk, "this creature gains mountainwalk until end of turn")))
		"Seasinger":
			c.with_sacrifice_if_no_land("island").with_may_skip_untap()
			c.activated(_ability("", true, Action.new(_seasinger, "gain control while this creature remains tapped",
				TargetSpec.creature("target creature whose controller controls an Island").with_game_filter(_controller_has_island))))
		"Spirit Shield", "Zelyon Sword":
			var power := 0 if name == "Spirit Shield" else 2
			var toughness := 2 if name == "Spirit Shield" else 0
			c.with_may_skip_untap()
			c.activated(_ability("{2}" if power == 0 else "{3}", true,
				Action.new(_hold.bind(power, toughness), "target creature gets a bonus while this remains tapped", TargetSpec.creature(), true)))
			c.static_ability(StaticAbility.new(_hold_static, "The held creature keeps its bonus while this remains tapped."))
		"Spore Cloud":
			c.spell(Action.new(_cloud, "tap blocking creatures; attackers and blockers skip their next untap"))
			c.spell(PreventCombatDamageEffect.new())
		"Svyelunite Priest":
			c.activated(_ability("{U}{U}", true, Action.new(_grant_shroud, "target creature gains shroud until end of turn", TargetSpec.creature(), true))
				.during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Thrull Champion":
			c.static_ability(StaticAbility.new(_thrull_lord, "Thrull creatures get +1/+1."))
			c.activated(_ability("", true, Action.new(_champion, "gain control of target Thrull while you control this creature",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Thrull", _subtype.bind("thrull")))))
		"Thrull Retainer":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			var regeneration := Action.new(_regenerate_host, "regenerate enchanted creature")
			regeneration.is_regeneration = true
			c.activated(_ability("", false, regeneration).with_sacrifice_cost())
		"Vodalian Knights":
			c.with_attack_needs_defender_land("island").with_sacrifice_if_no_land("island")
			c.activated(_ability("{U}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff()))
		"Vodalian Mage":
			c.activated(_ability("{U}", true, TollCounter.new("{1}")))
		"Thrull Wizard":
			c.activated(_ability("{1}{B}", false, TollCounter.new("{B}", "{3}", _color.bind(Mtg.ManaColor.B))))
		_:
			return _advanced(c)
	return c

static func _ability(cost: String, taps: bool, effect: EffectBase) -> ActivatedAbility:
	var description := ""
	if effect is PumpEffect and effect.self_mode:
		description = "this creature gets %+d/%+d until end of turn" % [effect.power, effect.toughness]
		for keyword in effect.granted_keywords:
			description += " and gains " + Mtg.Keyword.keys()[keyword].capitalize()
	else:
		description = effect.describe()
	return ActivatedAbility.new(cost, taps, [effect], (cost + ", " if cost != "" else "") +
		("{T}: " if taps else ": ") + description)

static func _saproling() -> CreateTokenEffect:
	return CreateTokenEffect.new("Saproling", 1, 1, Mtg.ManaColor.G, "saproling")

static func _subtype(inst: CardInstance, kind: String) -> bool:
	return inst.cur_subtypes.has(kind)

static func _color(inst: CardInstance, color: int) -> bool:
	return (inst.cur_colors & color) != 0

static func _colored_creature(inst: CardInstance, color: int) -> bool:
	return inst.is_creature() and _color(inst, color)

static func _your_upkeep(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data.get("player", -1)) == source.controller_id

static func _tapped_upkeep(g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return source.tapped and _your_upkeep(g, source, event)

static func _self_enter(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source

static func _self_attack(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("attackers", []).has(source)

static func _counter_upkeep(g: MtgGame, source: CardInstance, _event: GameEvent, kind: String) -> void:
	if _same_trigger_source(g, source):
		g.add_counters(source, kind)

static func _storage(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if _same_trigger_source(g, source) and source.tapped:
		g.add_counters(source, "storage")

static func _upkeep_payment(g: MtgGame, source: CardInstance, _event: GameEvent, cost: String) -> void:
	var pid := int(g.trigger_context(source).get("controller", source.controller_id))
	if _same_trigger_source(g, source) and not EffectBase.unless_paid(g,
			pid, ManaCost.parse(cost), "Pay %s to keep %s?" % [cost, source.data.card_name]) \
			and source.controller_id == pid:
		g.sacrifice_permanent(source)

static func _breed(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := int(g.trigger_context(source).get("controller", source.controller_id))
	CreateTokenEffect.new("Thrull", 0, 1, Mtg.ManaColor.B, "thrull").resolve(g, source, pid, null)

static func _blocking(g: MtgGame, inst: CardInstance) -> bool:
	return not g.combat.attackers_blocked_by(inst.id).is_empty()

static func _own_attacker(g: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id and g.combat.attackers.has(inst.id)

static func _small_own(_g: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id and inst.cur_toughness <= 2

static func _hunter(g: MtgGame, _s: CardInstance, _pid: int, target: TargetRef, _x: int) -> void:
	var inst := g.find_instance(target.instance_id)
	if inst != null:
		g._rec(inst, &"skip_next_untap")
		inst.skip_next_untap = true

static func _scout(g: MtgGame, _s: CardInstance, _pid: int, target: TargetRef, _x: int) -> void:
	var inst := g.find_instance(target.instance_id)
	if inst != null:
		g.untap_permanent(inst)
		g.continuous.add_until_eot_combat_prevention(inst.id, true, true)
		g.recalculate()

static func _grant_shroud(g: MtgGame, source: CardInstance, _pid: int, target: TargetRef, _x: int) -> void:
	var id := target.instance_id
	g.continuous.add_floating_static(source, StaticAbility.new(
		func(game: MtgGame, _src: CardInstance) -> void:
			var inst := game.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				inst.cur_shroud = true, "Shroud until end of turn."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, id)
	g.recalculate()

static func _shroud(g: MtgGame, source: CardInstance, pid: int, _target: TargetRef, x: int) -> void:
	if not _same_activation_source(g, source):
		return
	_grant_shroud(g, source, pid, TargetRef.card(source), x)
	g._rec(source, &"skip_next_untap")
	source.skip_next_untap = true
	g.tap_permanent(source)

static func _deep_upkeep(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := int(g.trigger_context(source).get("controller", source.controller_id))
	var present := _same_trigger_source(g, source) and source.controller_id == pid
	if g.players[pid].library.size() >= 2 and g.agents[pid].choose_yes_no(g, pid, "Mill two cards to keep Deep Spawn?", present):
		g.mill(pid, 2)
	elif present:
		g.sacrifice_permanent(source)

static func _derelor_tax(_g: MtgGame, pid: int, card: CardData, source: CardInstance) -> Dictionary:
	if pid == source.controller_id and (card.color_mask() & Mtg.ManaColor.B) != 0:
		return {Mtg.ManaColor.B: 1}
	return {}

static func _catapult(g: MtgGame, source: CardInstance, _pid: int, target: TargetRef, x: int) -> void:
	var creatures: Array = []
	for inst in g.players[target.player_id].battlefield:
		if inst.is_creature():
			creatures.append(inst)
	if creatures.is_empty():
		return
	var amount := floori(float(x) / creatures.size())
	g.begin_simultaneous()
	for inst in creatures:
		g.deal_damage(source, TargetRef.card(inst), amount)
	g.end_simultaneous()

static func _dwarf_orc_pair(g: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	# Blocking one band member is blocking every member (CR 702.22h, 2026-10-03).
	var others: Array = g.combat.opposing_attackers(source.id)
	if g.combat.attackers.has(source.id):
		others.append_array(g.combat.blockers_of_band(g.combat.band_of(source.id)))
	for id in others:
		var other := g.find_instance(id)
		if other != null and other.cur_subtypes.has("orc"):
			return true
	return false

static func _dwarf_block(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if not _same_trigger_source(g, source):
		return
	g.continuous.add_until_eot_pump(source.id, 0, 2)
	g.recalculate()

static func _all_colors(_g: MtgGame, _source: CardInstance) -> Array:
	return [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]

static func _fourth_conversion(g: MtgGame, source: CardInstance, pid: int) -> void:
	var last := int(source.memory.get("conversion_turn", -1))
	var count := int(source.memory.get("conversions", 0)) if last == g.turn_number else 0
	g._rec(source, &"memory")
	source.memory["conversion_turn"] = g.turn_number
	source.memory["conversions"] = count + 1
	if count + 1 >= 4:
		var timestamp := source.layer_timestamp
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
			func(game: MtgGame, src: CardInstance, _event: GameEvent) -> void:
				if src.zone == Mtg.Zone.BATTLEFIELD and src.layer_timestamp == timestamp and src.controller_id == pid:
					game.sacrifice_permanent(src), "Sacrifice the mana converter at the next end step."), pid, source)

static func _kites(g: MtgGame, source: CardInstance, pid: int, target: TargetRef, _x: int) -> void:
	PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).resolve(g, source, pid, target)
	var id := target.instance_id
	var timestamp := g.find_instance(id).layer_timestamp
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		func(game: MtgGame, _src: CardInstance, _event: GameEvent) -> void:
			var lost := game.rng.randi_range(0, 1) == 0
			game.log_line("Goblin Kites: %s loses the flip" % game.players[pid].player_name if lost
				else "Goblin Kites: %s wins the flip" % game.players[pid].player_name)
			var inst := game.find_instance(id)
			if lost and inst != null and inst.zone == Mtg.Zone.BATTLEFIELD \
					and inst.layer_timestamp == timestamp and inst.controller_id == pid:
				game.sacrifice_permanent(inst), "Flip a coin for Goblin Kites; a loss sacrifices the creature."), pid, source)

static func _high_tide(g: MtgGame, source: CardInstance, _pid: int, _target: TargetRef, _x: int) -> void:
	var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA,
		func(game: MtgGame, _s: CardInstance, event: GameEvent) -> void:
			var pid: int = event.data.player
			game.players[pid].mana_pool.add(Mtg.ManaColor.U, 1),
		"Whenever an Island is tapped for mana, add an additional {U}.",
		func(_game: MtgGame, _s: CardInstance, event: GameEvent) -> bool:
			return event.data.instance.cur_subtypes.has("island")).as_mana_trigger()
	trigger.mana_bonus_subtype = "island"
	trigger.mana_bonus_color = Mtg.ManaColor.U
	trigger.mana_bonus_amount = 1
	var delayed := g.schedule_delayed_trigger(trigger, source.controller_id, source, true)
	delayed["expires_turn"] = g.turn_number

static func _tide_upkeep(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if _same_trigger_source(g, source):
		g.add_counters(source, "tide")

static func _four_tides(_g: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return int(source.counters.get("tide", 0)) >= 4

static func _tide_reset(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if _same_trigger_source(g, source):
		g.remove_counters(source, "tide", int(source.counters.get("tide", 0)))

static func _tide_static(g: MtgGame, source: CardInstance) -> void:
	var tide := int(source.counters.get("tide", 0))
	var delta := -1 if tide == 1 else (1 if tide == 3 else 0)
	if source.data.card_name == "Homarid":
		source.cur_power += delta
		source.cur_toughness += delta
	else:
		for player in g.players:
			for inst in player.battlefield:
				if inst.is_creature() and _color(inst, Mtg.ManaColor.U):
					inst.cur_power += delta * 2

## CardData.cast_condition is called as func(game, pid) — a third parameter
## makes every announcement of the card fail the call and skip the rider.
static func _one_influence(g: MtgGame, _pid: int) -> String:
	for player in g.players:
		for inst in player.battlefield:
			if inst.data.card_name == "Tidal Influence":
				return "A Tidal Influence is already on the battlefield."
	return ""

static func _spawning_bed(g: MtgGame, source: CardInstance, pid: int, _target: TargetRef, _x: int) -> void:
	var amount := int(g.cost_paid("_sacrificed_mana_value", 0))
	CreateTokenEffect.new("Camarid", 1, 1, Mtg.ManaColor.U, "camarid", amount).resolve(g, source, pid, null)

static func _money_enter(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	g.deal_damage(source, TargetRef.player(int(g.trigger_context(source).get("controller", source.controller_id))), 3)

static func _cash_credit(g: MtgGame, _source: CardInstance, pid: int, _target: TargetRef, _x: int) -> void:
	var counters: Dictionary = g.cost_paid("_source_counters", {})
	g.adjust_life(pid, int(counters.get("credit", 0)))

static func _band_context(g: MtgGame, source: CardInstance, event: GameEvent) -> Dictionary:
	var context := _source_context(g, source, event)
	var band: Array = []
	for id in g.combat.band_of(source.id):
		if id != source.id:
			band.append([g.find_instance(id), g.find_instance(id).layer_timestamp])
	context["band"] = band
	return context

static func _skirmishers(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	for entry in g.trigger_context(source).get("band", []):
		var body: CardInstance = entry[0]
		if body.zone == Mtg.Zone.BATTLEFIELD and body.layer_timestamp == int(entry[1]):
			g.continuous.add_until_eot_keywords(body.id, [Mtg.Keyword.FIRST_STRIKE])
	g.recalculate()

static func _captain(g: MtgGame, source: CardInstance, pid: int, target: TargetRef, _x: int) -> void:
	var won := g.rng.randi_range(0, 1) == 1
	PumpEffect.new(2 if won else 0, 0 if won else -2).resolve(g, source, pid, target)

static func _veteran(_g: MtgGame, source: CardInstance) -> void:
	source.cur_cant_block_filter = func(attacker: CardInstance) -> bool:
		return (attacker.cur_colors & Mtg.ManaColor.W) != 0 and attacker.cur_power >= 2

static func _orgg(g: MtgGame, source: CardInstance) -> void:
	for inst in g.players[1 - source.controller_id].battlefield:
		if inst.is_creature() and not inst.tapped and inst.cur_power >= 3:
			source.cur_cant_attack = true

static func _rainbow(g: MtgGame, source: CardInstance, pid: int) -> void:
	var id := source.id
	var timestamp := source.layer_timestamp
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		func(game: MtgGame, _src: CardInstance, _event: GameEvent) -> void:
			var inst := game.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.layer_timestamp == timestamp:
				game.change_control(inst, 1 - pid), "An opponent gains control of Rainbow Vale."), pid, source)

static func _mountainwalk(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not _same_activation_source(g, source):
		return
	g.continuous.add_until_eot_landwalk(source.id, ["mountain"])
	g.recalculate()

static func _controller_has_island(g: MtgGame, inst: CardInstance) -> bool:
	for land in g.players[inst.controller_id].battlefield:
		if land.cur_subtypes.has("island"):
			return true
	return false

static func _seasinger(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var inst := g.find_instance(t.instance_id)
	if inst != null and _remained_tapped(g, source) and _original_source(g, source, pid):
		g.gain_control_leashed(inst, source, true)

static func _champion(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var inst := g.find_instance(t.instance_id)
	if inst != null and _original_source(g, source, pid):
		g.gain_control_leashed(inst, source)

static func _original_source(g: MtgGame, source: CardInstance, pid: int) -> bool:
	return _same_activation_source(g, source) and source.controller_id == pid \
		and source.control_sequence == int(g.cost_paid("_source_control_sequence", source.control_sequence))

static func _same_activation_source(g: MtgGame, source: CardInstance) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and source.layer_timestamp == int(g.cost_paid("_source_timestamp", source.layer_timestamp))

static func _remained_tapped(g: MtgGame, source: CardInstance) -> bool:
	return _same_activation_source(g, source) and source.tapped \
		and source.untap_sequence == int(g.cost_paid("_source_untap_sequence", source.untap_sequence))

static func _hold(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x: int, power: int, toughness: int) -> void:
	if _remained_tapped(g, source):
		g._rec(source, &"memory")
		source.memory["fem_held"] = [t.instance_id, power, toughness, g.find_instance(t.instance_id).layer_timestamp]
		g.recalculate()

static func _hold_static(g: MtgGame, source: CardInstance) -> void:
	if not source.tapped:
		g._rec(source, &"memory")
		source.memory.erase("fem_held")
		return
	var held: Array = source.memory.get("fem_held", [])
	if held.is_empty():
		return
	var inst := g.find_instance(int(held[0]))
	if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.layer_timestamp == int(held[3]):
		inst.cur_power += int(held[1])
		inst.cur_toughness += int(held[2])

static func _cloud(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for player in g.players:
		for inst in player.battlefield.duplicate():
			var blocking := _blocking(g, inst)
			if blocking:
				g.tap_permanent(inst)
			if blocking or g.combat.attackers.has(inst.id):
				g._rec(inst, &"skip_next_untap")
				inst.skip_next_untap = true

static func _thrull_lord(g: MtgGame, _source: CardInstance) -> void:
	for player in g.players:
		for inst in player.battlefield:
			if inst.is_creature() and _subtype(inst, "thrull"):
				inst.cur_power += 1
				inst.cur_toughness += 1

static func _aura_pump(g: MtgGame, source: CardInstance, power: int, toughness: int) -> void:
	var host := g.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += power
		host.cur_toughness += toughness

static func _regenerate_host(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var id := int(g.cost_paid("_source_attached_to", source.attached_to))
	var host := g.find_instance(id)
	if host != null and host.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -1)):
		RegenerateEffect.new().target_creature().resolve(g, source, pid, TargetRef.card(host))

class Action extends EffectBase:
	var callback: Callable
	var line: String
	func _init(cb: Callable, description: String, spec: TargetSpec = null, beneficial := false) -> void:
		callback = cb
		line = description
		target_spec = spec
		ai_helpful = beneficial
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x_value := 0) -> void:
		callback.call(game, source, controller, target, x_value)
	func describe() -> String:
		return line

class TollCounter extends CounterEffect:
	var first: String
	var second: String
	func _init(cost: String, alternate := "", filter := Callable()) -> void:
		super("target spell", filter)
		first = cost
		second = alternate
	func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef, _x := 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null:
			return
		var item := game.find_stack_item(spell)
		var pid := spell.controller_id if item == null else item.controller
		if EffectBase.unless_paid(game, pid, ManaCost.parse(first), "Pay %s to prevent the counter?" % first):
			return
		if second != "" and EffectBase.unless_paid(game, pid, ManaCost.parse(second), "Pay %s instead?" % second):
			return
		game.counter_spell(spell)
	func describe() -> String:
		return "counter target spell unless its controller pays " + first + (" or " + second if second != "" else "")

static func _conch(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.draw_cards(pid, 2)
	var hand: Array[CardInstance] = g.players[pid].hand.duplicate()
	if not hand.is_empty():
		var chosen := g.agents[pid].choose_card(g, pid, hand, "Conch Horn — put a card on top of your library", false, true)
		g.put_from_hand_on_top_of_library(chosen if chosen != null else hand[0])

static func _advanced(c: CardData) -> CardData:
	match c.card_name:
		"Delif's Cone", "Delif's Cube":
			var cone := c.card_name == "Delif's Cone"
			var spec := TargetSpec.creature("target creature you control").with_source_filter(_own)
			var ability := _ability("" if cone else "{2}", true,
				Action.new(_delif.bind(cone), "watch target attacker this turn instead of its combat damage", spec, true))
			if cone:
				ability.with_sacrifice_cost()
			c.activated(ability)
			if not cone:
				c.activated(_ability("{2}", false, RegenerateEffect.new().target_creature()).with_counter_cost("cube"))
		"Ebon Praetor":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _counter_upkeep.bind("-2/-2"),
				"Put a -2/-2 counter on this creature.", _your_upkeep))
			c.activated(_ability("", false, Action.new(_praetor, "remove a -2/-2 counter; a sacrificed Thrull also adds a +1/+0 counter"))
				.with_sacrifice_of("creature", _creature).may_sacrifice_itself()
				.during_step(Mtg.Step.UPKEEP).your_turn_only().per_turn(1))
		"Farrel's Mantle", "Farrel's Zealot":
			var mantle := c.card_name == "Farrel's Mantle"
			if mantle:
				c.enchants(TargetSpec.creature())
			var spec := TargetSpec.creature("target creature").with_source_filter(_farrel_target.bind(mantle))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED,
				_farrel.bind(mantle), "An unblocked attacker may deal damage to target creature instead.",
				_farrel_unblocked.bind(mantle)).targeting(spec, _enemy_first).capturing(_farrel_context.bind(mantle)))
		"Goblin Flotilla":
			c.triggered(TriggeredAbility.new(Mtg.EventType.COMBAT_START, _flotilla_fee,
				"Unless you pay {R}, creatures blocking or blocked by this creature gain first strike this combat."))
		"Goblin War Drums":
			c.static_ability(StaticAbility.new(_menace, "Creatures you control can't be blocked except by two or more creatures."))
		"Goblin Warrens":
			var ability := _ability("{2}{R}", false, CreateTokenEffect.new("Goblin", 1, 1, Mtg.ManaColor.R, "goblin", 3))
			ability.with_sacrifice_of("Goblin", _subtype.bind("goblin"))
			ability.sacrifice_count = 2
			c.activated(ability)
		"Hand of Justice":
			var ability := _ability("", true, DestroyEffect.new(TargetSpec.creature()))
			ability.tap_permanent_count = 3
			ability.tap_permanent_filter = _colored_creature.bind(Mtg.ManaColor.W)
			c.activated(ability)
		"Heroism":
			c.activated(_ability("", false, Action.new(_heroism, "prevent attacking red creatures' combat damage unless their controllers pay {2}{R} each"))
				.with_sacrifice_of("white creature", _colored_creature.bind(Mtg.ManaColor.W)))
		"Merseine":
			c.enchants(TargetSpec.creature()).with_enters_counters("net", 3)
			var ability := _ability("", false, Action.new(_remove_net, "remove a net counter from Merseine")).anyone_activated()
			ability.activator_condition = _merseine_activator
			c.activated(ability)
			c.static_ability(StaticAbility.new(_merseine, "Net counters prevent the enchanted creature from untapping; its controller may pay its mana cost."))
		"Mindstab Thrull":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _mindstab,
				"You may sacrifice this unblocked attacker to make the defending player discard three cards.", _unblocked).capturing(_source_context))
		"Necrite":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _necrite,
				"You may sacrifice this unblocked attacker to destroy target defending creature without regeneration.", _unblocked)
				.targeting(TargetSpec.creature("target creature defending player controls").with_source_filter(_defending), _enemy_first).capturing(_source_context))
		"Night Soil":
			var ability := _ability("{1}", false, _saproling()).with_exile_from_graveyard("creature cards", _creature)
			ability.graveyard_exile_count = 2
			ability.graveyard_exile_any_player = true
			c.activated(ability)
		"Orcish Spy":
			c.activated(_ability("", true, Action.new(_spy, "look privately at the top three cards of target player's library", TargetSpec.player())))
		"Raiding Party":
			c.static_ability(StaticAbility.new(_white_target_ban, "White spells and abilities from white sources can't target this enchantment."))
			c.activated(_ability("", false, Action.new(_raid, "each player may tap white creatures to save two Plains each; destroy the rest"))
				.with_sacrifice_of("Orc", _subtype.bind("orc")))
		"Soul Exchange":
			c.with_additional_sacrifice("creature", _creature)
			c.additional_sacrifice["exile"] = true
			c.spell(SoulReturn.new())
		"Thelon's Chant", "Tourach's Chant":
			var green := c.card_name == "Thelon's Chant"
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_upkeep_payment.bind("{G}" if green else "{B}"), "Pay the upkeep or sacrifice this enchantment.", _your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _chant,
				"The entering land's controller takes 3 damage unless they put a -1/-1 counter on a creature they control.",
				_land_enter.bind("swamp" if green else "forest")))
		"Thelon's Curse":
			c.static_ability(StaticAbility.new(_curse, "Blue creatures don't untap during their controllers' untap steps."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _curse_payment,
				"The active player may pay {U} for each tapped blue creature they want to untap."))
		"Thelonite Druid":
			c.activated(_ability("{1}{G}", true, Action.new(_druid, "Forests you control become 2/3 creatures until end of turn"))
				.with_sacrifice_of("creature", _creature).may_sacrifice_itself())
		"Thelonite Monk":
			c.activated(_ability("", true, Action.new(_monk, "target land becomes a Forest indefinitely",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)))
				.with_sacrifice_of("green creature", _colored_creature.bind(Mtg.ManaColor.G)).may_sacrifice_itself())
		"Tidal Flats":
			c.activated(_ability("{U}{U}", false, Action.new(_flats, "your blockers gain first strike against each nonflying attacker unless its controller pays {1}")))
		"Tourach's Gate":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "land you control", _land).with_source_filter(_own))
			c.activated(_ability("", false, Action.new(_gate_time, "put three time counters on this Aura"))
				.with_sacrifice_of("Thrull", _subtype.bind("thrull")))
			var ability := _ability("", false, Action.new(_gate_boost, "attacking creatures you control get +2/-1 until end of turn"))
			ability.tap_permanent_count = 1
			ability.tap_permanent_filter = func(_inst: CardInstance) -> bool: return false
			c.activated(ability)
			c.static_ability(StaticAbility.new(_gate_cost, "Tap enchanted land to activate the attack bonus."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _gate_upkeep,
				"Remove a time counter, then sacrifice this Aura if it has none.", _your_upkeep))
		"Vodalian War Machine":
			for effect in [Action.new(_machine_attack, "this creature may attack as though it didn't have defender this turn"),
					PumpEffect.new(2, 1).self_buff()]:
				var ability := _ability("", false, effect)
				ability.tap_permanent_count = 1
				ability.tap_permanent_filter = _subtype.bind("merfolk")
				ability.on_cost_paid = _machine_paid
				c.activated(ability)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _machine_dies,
				"Destroy all Merfolk tapped this turn to pay for this creature's abilities.", _self_enter))
		_:
			push_error("Unrecognized Fallen Empires card: " + c.card_name)
			return null
	return c

static func _creature(inst: CardInstance) -> bool:
	return inst.is_creature()

static func _land(inst: CardInstance) -> bool:
	return inst.is_land()

static func _own(_g: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id

static func _defending(g: MtgGame, _source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == g.opponent_of(g.active_player)

static func _unblocked(g: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return g.combat.attackers.has(source.id) and g.combat.blockers_of_band(g.combat.band_of(source.id)).is_empty()

static func _enemy_first(g: MtgGame, source: CardInstance, at: TargetRef, bt: TargetRef) -> bool:
	if at.is_player or bt.is_player:
		var av := (1000 if at.player_id != source.controller_id else -1000) if at.is_player else 0
		var bv := (1000 if bt.player_id != source.controller_id else -1000) if bt.is_player else 0
		return av > bv
	var a := g.find_instance(at.instance_id)
	var b := g.find_instance(bt.instance_id)
	var av := (1000 if a.controller_id != source.controller_id else 0) + a.cur_power + a.cur_toughness
	var bv := (1000 if b.controller_id != source.controller_id else 0) + b.cur_power + b.cur_toughness
	return av > bv

static func _no_assignment(g: MtgGame, source: CardInstance, id: int) -> void:
	g.continuous.add_floating_static(source, StaticAbility.new(
		func(game: MtgGame, _source: CardInstance) -> void:
			var inst := game.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				inst.cur_assigns_no_combat_damage = true, "Assigns no combat damage this turn."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, id)
	g.recalculate()

static func _delif(g: MtgGame, source: CardInstance, pid: int, target: TargetRef, _x: int, cone: bool) -> void:
	var id := target.instance_id
	var watched := g.find_instance(id)
	var timestamp := watched.layer_timestamp
	var source_timestamp := int(g.cost_paid("_source_timestamp", source.layer_timestamp))
	var trigger := TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED,
		func(game: MtgGame, src: CardInstance, _event: GameEvent) -> void:
			var original := watched.zone == Mtg.Zone.BATTLEFIELD and watched.layer_timestamp == timestamp
			var power := watched.cur_power if original else watched.last_power
			if cone:
				if not game.agents[pid].choose_yes_no(game, pid, "Gain %d life instead of this attacker's combat damage?" % power,
						game.players[pid].life <= 8):
					return
				game.adjust_life(pid, maxi(power, 0))
			elif src.zone == Mtg.Zone.BATTLEFIELD and src.layer_timestamp == source_timestamp:
				game.add_counters(src, "cube")
			if original:
				_no_assignment(game, src, id),
		"The watched unblocked attacker assigns no combat damage this turn.",
		func(game: MtgGame, _src: CardInstance, event: GameEvent) -> bool:
			var attacker := game.find_instance(id)
			return attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD \
				and attacker.layer_timestamp == timestamp and _unblocked(game, attacker, event))
	var delayed := g.schedule_delayed_trigger(trigger, pid, source)
	delayed["expires_turn"] = g.turn_number

static func _praetor(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not _same_activation_source(g, source):
		return
	g.remove_counters(source, "-2/-2", 1)
	if (g.cost_paid("_sacrificed_subtypes", []) as Array).has("thrull"):
		g.add_counters(source, "+1/+0")

static func _farrel_target(g: MtgGame, source: CardInstance, inst: CardInstance, mantle: bool) -> bool:
	var context := g.trigger_context(source)
	if mantle and context.has("attacker"):
		return inst != context.attacker
	return not mantle or inst.id != source.attached_to

static func _source_context(_g: MtgGame, source: CardInstance, _event: GameEvent) -> Dictionary:
	return {"timestamp": source.layer_timestamp, "controller": source.controller_id}

static func _same_trigger_source(g: MtgGame, source: CardInstance) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and source.layer_timestamp == int(g.trigger_context(source).get("timestamp", source.layer_timestamp))

static func _trigger_source_present(g: MtgGame, source: CardInstance) -> bool:
	var context := g.trigger_context(source)
	return source.zone == Mtg.Zone.BATTLEFIELD and source.layer_timestamp == int(context.get("timestamp", source.layer_timestamp)) \
		and source.controller_id == int(context.get("controller", source.controller_id))

static func _farrel_context(g: MtgGame, source: CardInstance, _event: GameEvent, mantle: bool) -> Dictionary:
	var attacker := g.find_instance(source.attached_to) if mantle else source
	return {"attacker": attacker, "timestamp": attacker.layer_timestamp, "controller": attacker.controller_id}

static func _farrel_unblocked(g: MtgGame, source: CardInstance, event: GameEvent, mantle: bool) -> bool:
	var attacker := g.find_instance(source.attached_to) if mantle else source
	return attacker != null and _unblocked(g, attacker, event)

static func _farrel(g: MtgGame, source: CardInstance, _event: GameEvent, mantle: bool) -> void:
	var context := g.trigger_context(source)
	var attacker: CardInstance = context.get("attacker", g.find_instance(source.attached_to) if mantle else source)
	var targets := g.current_targets()
	if attacker == null or targets.is_empty():
		return
	var victim := g.find_instance(targets[0].instance_id)
	var original := attacker.zone == Mtg.Zone.BATTLEFIELD and attacker.layer_timestamp == int(context.get("timestamp", attacker.layer_timestamp))
	var power := attacker.cur_power if original else attacker.last_power
	var amount := power + 2 if mantle else 3
	var pid := int(context.get("controller", attacker.controller_id))
	if g.agents[pid].choose_yes_no(g, pid, "Deal %d damage to %s instead of assigning combat damage?" % [amount, victim.data.card_name],
			victim.controller_id != pid and victim.cur_toughness - victim.damage <= amount):
		g.deal_damage(attacker, targets[0], amount)
		if original:
			_no_assignment(g, source, attacker.id)

static func _flotilla_fee(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var context := g.trigger_context(source)
	var pid := int(context.get("controller", source.controller_id))
	var timestamp := int(context.get("timestamp", source.layer_timestamp))
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{R}"), "Pay {R} for Goblin Flotilla?"):
		return
	var id := source.id
	var trigger := TriggeredAbility.new(Mtg.EventType.BLOCKED,
		func(game: MtgGame, src: CardInstance, _event: GameEvent) -> void:
			var occurrence := game.trigger_context(src)
			var other: CardInstance = occurrence.other
			if other.zone != Mtg.Zone.BATTLEFIELD or other.layer_timestamp != int(occurrence.timestamp): return
			game.continuous.add_until_eot_keywords(other.id, [Mtg.Keyword.FIRST_STRIKE])
			game.recalculate(), "The other creature gains first strike.",
		func(_game: MtgGame, _src: CardInstance, event: GameEvent) -> bool:
			return (event.data.attacker.id == id and event.data.attacker.layer_timestamp == timestamp) \
				or (event.data.blocker.id == id and event.data.blocker.layer_timestamp == timestamp))
	trigger.capturing(func(_game: MtgGame, _src: CardInstance, event: GameEvent) -> Dictionary:
		var other: CardInstance = event.data.blocker if event.data.attacker.id == id else event.data.attacker
		return {"other": other, "timestamp": other.layer_timestamp})
	var delayed := g.schedule_delayed_trigger(trigger, pid, source, true)
	delayed["expires_turn"] = g.turn_number
	g.schedule_end_of_combat_action(func(game: MtgGame) -> void: game.delayed_triggers.erase(delayed))

static func _menace(g: MtgGame, source: CardInstance) -> void:
	for inst in g.players[source.controller_id].battlefield:
		if inst.is_creature():
			inst.cur_min_blockers = maxi(inst.cur_min_blockers, 2)

static func _heroism(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker != null and _color(attacker, Mtg.ManaColor.R) and not EffectBase.unless_paid(g,
				attacker.controller_id, ManaCost.parse("{2}{R}"), "Pay {2}{R} so %s deals combat damage?" % attacker.data.card_name):
			g.continuous.add_until_eot_combat_prevention(id, true, false)
	g.recalculate()

static func _merseine_activator(g: MtgGame, source: CardInstance, pid: int) -> String:
	var host := g.find_instance(source.attached_to)
	return "" if host != null and host.controller_id == pid else "Only the enchanted creature's controller may activate this ability."

static func _merseine(g: MtgGame, source: CardInstance) -> void:
	var host := g.find_instance(source.attached_to)
	if host == null:
		return
	if int(source.counters.get("net", 0)) > 0:
		host.cur_skips_untap = true
	if not source.cur_activated_abilities.is_empty():
		var ability := source.cur_activated_abilities[0].shallow_copy()
		ability.cost = host.data.cost_for(0)
		ability.text = "Pay " + host.data.cost.to_string() + ": Remove a net counter from Merseine."
		source.cur_activated_abilities[0] = ability

static func _remove_net(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if _same_activation_source(g, source):
		g.remove_counters(source, "net", 1)

static func _mindstab(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	if _trigger_source_present(g, source) and g.agents[pid].choose_yes_no(g, pid,
			"Sacrifice Mindstab Thrull to make the defending player discard three cards?", g.players[1 - pid].hand.size() >= 2):
		g.sacrifice_permanent(source)
		var defender := g.opponent_of(g.active_player)
		g.discard_cards(defender, g.agents[defender].choose_discard(g, defender, mini(3, g.players[defender].hand.size())))

static func _necrite(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or not _trigger_source_present(g, source):
		return
	var victim := g.find_instance(targets[0].instance_id)
	if victim != null and g.agents[source.controller_id].choose_yes_no(g, source.controller_id,
			"Sacrifice Necrite to destroy %s?" % victim.data.card_name, victim.cur_power + victim.cur_toughness >= 4):
		g.sacrifice_permanent(source)
		g.destroy(victim, false)

static func _spy(g: MtgGame, _s: CardInstance, pid: int, target: TargetRef, _x: int) -> void:
	var library: Array[CardInstance] = g.players[target.player_id].library
	var names: Array[String] = []
	for i in mini(3, library.size()):
		names.append(library[-1 - i].data.card_name)
	# Only the activating seat receives this private resolution question.
	# Do not put the identities in the public game log.
	var options: Array[String] = ["Continue"]
	g.agents[pid].choose_option(g, pid, options, "Orcish Spy — top to bottom: " + (", ".join(names) if not names.is_empty() else "empty library"), 0)

static func _white_target_ban(_g: MtgGame, source: CardInstance) -> void:
	source.cur_target_bans.append({"filter": func(_game: MtgGame, from: CardInstance, _spec: TargetSpec) -> bool:
		return _color(from, Mtg.ManaColor.W)})

static func _raid(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var plains: Array[CardInstance] = []
	for inst in g.all_battlefield():
		if inst.cur_subtypes.has("plains"):
			plains.append(inst)
	var saved: Array[int] = []
	for pid in [g.active_player, g.opponent_of(g.active_player)]:
		var candidates: Array[CardInstance] = []
		for inst in g.players[pid].battlefield:
			if not inst.tapped and _colored_creature(inst, Mtg.ManaColor.W):
				candidates.append(inst)
		while not candidates.is_empty() and not plains.is_empty():
			var pick := g.agents[pid].choose_card(g, pid, candidates, "Tap a white creature to save up to two Plains?", true, true)
			if pick == null:
				break
			candidates.erase(pick)
			g.tap_permanent(pick)
			var options: Array[CardInstance] = plains.duplicate()
			options.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.controller_id == pid and b.controller_id != pid)
			for _n in 2:
				if options.is_empty():
					break
				var land := g.agents[pid].choose_card(g, pid, options, "Choose a Plains to save", true, false, true)
				if land == null:
					break
				options.erase(land)
				plains.erase(land)
				saved.append(land.id)
	g.begin_simultaneous()
	for land in plains:
		if not saved.has(land.id):
			g.destroy(land)
	g.end_simultaneous()

class SoulReturn extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		to_battlefield()
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, _x := 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst != null:
			game.reanimate(inst, controller)
			if inst.zone == Mtg.Zone.BATTLEFIELD and (source.memory.get("paid_creature_subtypes", []) as Array).has("thrull"):
				game.add_counters(inst, "+2/+2")

static func _land_enter(_g: MtgGame, _source: CardInstance, event: GameEvent, kind: String) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.cur_subtypes.has(kind)

static func _chant(g: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var land: CardInstance = event.data.instance
	var pid: int = event.data.get("controller", land.controller_id)
	var candidates: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_creature():
			candidates.append(inst)
	var chosen: CardInstance = null
	if not candidates.is_empty():
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.cur_toughness > b.cur_toughness)
		chosen = g.agents[pid].choose_card(g, pid, candidates, "Put a -1/-1 counter on a creature instead of taking 3 damage?", true, true)
	if chosen == null:
		g.deal_damage(source, TargetRef.player(pid), 3)
	else:
		g.add_counters(chosen, "-1/-1")

static func _curse(g: MtgGame, _source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if _colored_creature(inst, Mtg.ManaColor.U):
			inst.cur_skips_untap = true

static func _curse_payment(g: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data.player
	var candidates: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.tapped and _colored_creature(inst, Mtg.ManaColor.U):
			candidates.append(inst)
	while not candidates.is_empty():
		var inst := g.agents[pid].choose_card(g, pid, candidates, "Choose a blue creature to untap for {U}", true)
		if inst == null:
			break
		candidates.erase(inst)
		if EffectBase.unless_paid(g, pid, ManaCost.parse("{U}"), "Pay {U} to untap %s?" % inst.data.card_name):
			g.untap_permanent(inst)

static func _druid(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for inst in g.players[pid].battlefield:
		if inst.cur_subtypes.has("forest"):
			g.continuous.add_until_eot_animation(inst.id, Mtg.CardType.CREATURE, 2, 3)
	g.recalculate()

static func _monk(g: MtgGame, source: CardInstance, _pid: int, target: TargetRef, _x: int) -> void:
	var id := target.instance_id
	g.continuous.add_floating_static(source, StaticAbility.new(
		func(game: MtgGame, _source: CardInstance) -> void:
			var land := game.find_instance(id)
			if land != null and land.zone == Mtg.Zone.BATTLEFIELD:
				land.become_basic_land_type("forest", Mtg.ManaColor.G), "This land is a Forest.").changing_land_types(),
		ContinuousEffects.Duration.INDEFINITE, -1, false, id)
	g.recalculate()

static func _flats(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker == null or attacker.has_keyword(Mtg.Keyword.FLYING):
			continue
		var blockers: Array[int] = []
		for blocker_id in g.combat.blockers_of_band(g.combat.band_of(id)):
			var blocker := g.find_instance(blocker_id)
			if blocker != null and blocker.controller_id == pid:
				blockers.append(blocker_id)
		if not blockers.is_empty() and not EffectBase.unless_paid(g, attacker.controller_id, ManaCost.parse("{1}"),
				"Pay {1} to stop %s's blockers gaining first strike?" % attacker.data.card_name):
			for blocker_id in blockers:
				g.continuous.add_until_eot_keywords(blocker_id, [Mtg.Keyword.FIRST_STRIKE])
	g.recalculate()

static func _gate_time(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if _same_activation_source(g, source):
		g.add_counters(source, "time", 3)

static func _gate_cost(_g: MtgGame, source: CardInstance) -> void:
	if source.cur_activated_abilities.size() >= 2:
		var id := source.attached_to
		var ability := source.cur_activated_abilities[1].shallow_copy()
		ability.tap_permanent_filter = func(inst: CardInstance) -> bool: return inst.id == id
		source.cur_activated_abilities[1] = ability

static func _gate_upkeep(g: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if _same_trigger_source(g, source):
		g.remove_counters(source, "time", 1)
		if int(source.counters.get("time", 0)) == 0 \
				and source.controller_id == int(g.trigger_context(source).get("controller", source.controller_id)):
			g.sacrifice_permanent(source)

static func _gate_boost(g: MtgGame, _source: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for id in g.combat.attackers:
		var inst := g.find_instance(id)
		if inst != null and inst.controller_id == pid:
			g.continuous.add_until_eot_pump(id, 2, -1)
	g.recalculate()

static func _machine_paid(g: MtgGame, source: CardInstance, paid: Dictionary) -> void:
	g._rec(source, &"memory")
	if int(source.memory.get("machine_turn", -1)) != g.turn_number:
		source.memory["machine_turn"] = g.turn_number
		source.memory["machine_crew"] = []
	for id in paid.get("_tapped_instances", []):
		var crew := g.find_instance(id)
		var incarnation := [id, crew.layer_timestamp]
		if not source.memory.machine_crew.has(incarnation):
			source.memory.machine_crew.append(incarnation)

static func _machine_attack(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not _same_activation_source(g, source):
		return
	var id := source.id
	g.continuous.add_floating_static(source, StaticAbility.new(
		func(game: MtgGame, _s: CardInstance) -> void:
			var inst := game.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				inst.cur_can_attack_with_defender = true, "May attack as though it didn't have defender."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, id)
	g.recalculate()

static func _machine_dies(g: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var memory: Dictionary = event.data.get("memory", {})
	if int(memory.get("machine_turn", -1)) != g.turn_number:
		return
	g.begin_simultaneous()
	for incarnation in memory.get("machine_crew", []):
		var inst := g.find_instance(int(incarnation[0]))
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD \
				and inst.layer_timestamp == int(incarnation[1]):
			g.destroy(inst)
	g.end_simultaneous()
