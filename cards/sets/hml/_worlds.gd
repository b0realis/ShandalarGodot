extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Aether Storm":
			c.bans_playing(_creature_ban)
			c.activated(F._ability("", false, F.Action.new(_destroy_self, "destroy this enchantment without regeneration")).with_life_cost(4).anyone_activated())
		"Autumn Willow":
			c.static_ability(StaticAbility.new(_shroud, "Shroud.").changing_abilities())
			c.activated(F._ability("{G}", false, F.Action.new(_ignore_shroud, "target player may target this creature as though it did not have shroud this turn", TargetSpec.player(), true)))
		"Aysen Highway": c.static_ability(StaticAbility.new(_highway, "White creatures have plainswalk.").changing_abilities())
		"Mystic Decree": c.static_ability(StaticAbility.new(_decree, "All creatures lose flying and islandwalk.").changing_abilities())
		"Feroz's Ban", "Irini Sengir": c.with_cost_modifier(_surcharge)
		"Primal Order": c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _primal, "Deal damage to that player for each nonbasic land they control."))
		"Hungry Mist": c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{G}{G}"), "Pay {G}{G} or sacrifice this creature.", F._your_upkeep))
		"Koskun Falls":
			c.static_ability(StaticAbility.new(_falls_tax, "Creatures can't attack you unless their controller pays {2} for each."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _falls_upkeep, "Tap an untapped creature you control or sacrifice this enchantment.", F._your_upkeep))
		"Apocalypse Chime": c.activated(F._ability("{2}", true, F.Action.new(_chime, "destroy all nontoken permanents originally printed in Homelands without regeneration")).with_sacrifice_cost())
		"Carapace":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 2), "Enchanted creature gets +0/+2."))
			var effect := F.Action.new(F._regenerate_host, "regenerate enchanted creature", null, true)
			effect.is_regeneration = true
			c.activated(F._ability("", false, effect).with_sacrifice_cost())
		"Feast of the Unicorn":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(F._aura_pump.bind(4, 0), "Enchanted creature gets +4/+0."))
		"Torture":
			c.enchants(TargetSpec.creature()).activated(F._ability("{1}{B}", false, F.Action.new(_torture, "put a -1/-1 counter on enchanted creature")))
		"Roots":
			c.enchants(TargetSpec.creature("target creature without flying", _nonflier))
			c.static_ability(StaticAbility.new(_roots, "Enchanted creature doesn't untap during its controller's untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _roots_enter, "Tap enchanted creature.", F._self_enter).capturing(A._host_context))
		"Serra Bestiary":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(_bestiary, "Can't attack, block or activate abilities with {T} in their costs."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{W}{W}"), "Pay {W}{W} or sacrifice this Aura.", F._your_upkeep))
		"Ironclaw Curse":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(_ironclaw, "Enchanted creature gets -0/-1 and can't block creatures with power at least its toughness."))
		_: return false
	return true

static func _creature_ban(_g: MtgGame, _pid: int, data: CardData) -> bool: return data.is_creature()
static func _destroy_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if C.same_activation(g, s): g.destroy(s, false)
static func _shroud(_g: MtgGame, s: CardInstance) -> void: s.cur_shroud = true
static func _ignore_shroud(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_floating_static(s, StaticAbility.new(_permission.bind(s.id, t.player_id), "The chosen player ignores this permanent's shroud."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()
static func _permission(g: MtgGame, _s: CardInstance, id: int, who: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and not i.cur_shroud_ignored_by.has(who): i.cur_shroud_ignored_by.append(who)
static func _highway(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.W) != 0 and not i.cur_landwalk.has("plains"): i.cur_landwalk.append("plains")
static func _decree(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature():
			i.cur_keywords.erase(Mtg.Keyword.FLYING)
			i.cur_landwalk.erase("island")
static func _surcharge(_g: MtgGame, _pid: int, data: CardData, s: CardInstance) -> int:
	if s.cur_abilities_silenced or s.cur_statics_suspended: return 0
	if s.data.card_name == "Feroz's Ban": return 2 if data.is_creature() else 0
	if (data.types & Mtg.CardType.ENCHANTMENT) == 0: return 0
	# A single cost modifier: a green-and-white spell qualifies once.
	return 2 if (data.color_mask() & (Mtg.ManaColor.G | Mtg.ManaColor.W)) != 0 else 0
static func _primal(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.player)
	var count := 0
	for i in g.players[who].battlefield:
		if i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0: count += 1
	g.deal_damage(s, TargetRef.player(who), count)
static func _can_pay_tax(g: MtgGame, who: int) -> bool: return g.can_afford_cost(who, ManaCost.parse("{2}"))
static func _pay_tax(g: MtgGame, who: int) -> void: g.try_pay(who, ManaCost.parse("{2}"))
static func _falls_tax(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[1 - s.controller_id].battlefield:
		if i.is_creature(): i.cur_attack_costs.append({"desc": "pay {2} to attack", "generic_mana": 2, "can_pay": _can_pay_tax, "pay": _pay_tax})
static func _falls_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var who := int(g.trigger_context(s).controller)
	var choices: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature() and not i.tapped: choices.append(i)
	var pick := g.agents[who].choose_card(g, who, choices, "Koskun Falls: tap a creature to keep this enchantment", true, true)
	if pick != null and choices.has(pick): g.tap_permanent(pick)
	elif s.controller_id == who: g.sacrifice_permanent(s)
static func _chime(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if not i.is_token and CardRegistry.originally_printed_in(i.data.card_name, "hml"): victims.append(i)
	g.begin_simultaneous()
	for i in victims: g.destroy(i, false)
	g.end_simultaneous()
static func _torture(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var i := A.paid_host(g, s)
	if i != null: g.add_counters(i, "-1/-1")
static func _nonflier(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)
static func _roots(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_skips_untap = true
static func _roots_enter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A._trigger_host(g, s)
	if i != null: g.tap_permanent(i)
static func _never_block(_i: CardInstance) -> bool: return true
static func _bestiary(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	i.cur_cant_attack = true
	i.cur_cant_block_filter = _never_block
	# Remove only the activatable menu entries whose cost uses {T}; other
	# activated, triggered and static abilities remain. This final static
	# pass runs after all layer-six ability grants, including mana grants.
	i.cur_activated_abilities = i.cur_activated_abilities.filter(func(a: ActivatedAbility) -> bool: return not a.tap_cost)
	i.cur_mana_abilities = i.cur_mana_abilities.filter(func(a: ManaAbility) -> bool: return not a.taps_source)
static func _ironclaw(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	i.cur_toughness -= 1
	i.cur_cant_block_power_ge_toughness = true
