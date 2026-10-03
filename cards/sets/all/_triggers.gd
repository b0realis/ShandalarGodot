extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const R := preload("res://cards/sets/all/_resources.gd")
const I := preload("res://cards/sets/ice/_library.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Balduvian Horde": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _horde, "Sacrifice this creature unless you discard a card at random.", F._self_enter))
		"Fyndhorn Druid": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _druid, "If this creature was blocked this turn, gain 4 life.", _druid_died))
		"Casting of Bones", "False Demise":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _host_died, "When enchanted creature dies, resolve this Aura's death effect.", _host_death).capturing(_host_grave))
		"Inheritance": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _inheritance, "May pay {3} to draw a card.", _creature_died))
		"Insidious Bookworms": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _bookworms, "May pay {1}{B}; target player discards a card at random.", F._self_enter).targeting(TargetSpec.player(), F._enemy_first))
		"Lord of Tresserhorn":
			c.activated(F._ability("{B}", false, RegenerateEffect.new()))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _lord, "Lose 2 life, sacrifice two creatures, and target opponent draws two cards.", F._self_enter).targeting(TargetSpec.opponent()))
		"Phyrexian War Beast": c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _war_beast, "Sacrifice a land; this creature deals 1 damage to you.", F._self_enter))
		"Ivory Gargoyle":
			c.activated(F._ability("{4}{W}", false, F.Action.new(_exile_self, "exile this creature")))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _gargoyle, "Return this card at the next end step and skip your next draw step.", F._self_enter).capturing(_self_grave))
		"Soldevi Heretic": c.activated(ActivatedAbility.new("{W}", true, [PreventDamageEffect.new(2).target_creature(), OptionalDraw.new()], "{W}, {T}: Prevent 2 damage to target creature; target opponent may draw a card"))
		"Soldevi Steam Beast":
			c.activated(F._ability("{2}", false, RegenerateEffect.new()))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _steam, "Target opponent gains 2 life.", F._self_enter).targeting(TargetSpec.opponent()))
		"Soldevi Sentry": c.activated(F._ability("{1}", false, SentryRegeneration.new()))
		"Spiny Starfish":
			c.activated(F._ability("{U}", false, RegenerateEffect.new()))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _starfish, "Create a Starfish for each time this creature regenerated this turn.", _regenerated))
		"Phantasmal Sphere":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _sphere_upkeep, "Add a +1/+1 counter, then sacrifice this creature unless you pay {1} per +1/+1 counter.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _orb, "Target opponent creates an X/X blue Orb with flying for this creature's +1/+1 counters.", F._self_enter).capturing(_sphere_left).targeting(TargetSpec.opponent()))
		"Rogue Skycaptain": c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _skycaptain, "Add a wage counter; may pay {2} per wage counter, otherwise remove wages and an opponent gains control.", F._your_upkeep))
		"Chaos Harlequin": c.activated(F._ability("{R}", false, F.Action.new(_harlequin, "exile the top card; this creature gets -4/-0 if it is a land, otherwise +2/+0", null, true)))
		"Suffocation":
			c.castable_only_when(_suffocation_window)
			c.spell(F.Action.new(_suffocation, "deal 4 damage to the last red instant or sorcery's controller that damaged you this turn")).spell(DelayedDrawEffect.new())
		"Scars of the Veteran": c.spell(Scars.new()).with_pitch_cost(Mtg.ManaColor.W)
		_: return false
	return true

class OptionalDraw extends DrawEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if g.agents[t.player_id].choose_yes_no(g, t.player_id, "Draw a card?", not g.players[t.player_id].library.is_empty()): g.draw_cards(t.player_id, 1)

class SentryRegeneration extends RegenerateEffect:
	func _init() -> void:
		super()
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if not B.live_source(g, s) or not g.is_present(s): return   # CR 702.26e
		RegenerateEffect.new().resolve(g, s, pid, null)
		g._rec(s, &"regeneration_draws")
		s.regeneration_draws[s.regeneration_shields - 1] = {"beneficiary": t.player_id, "controller": pid}
	func describe() -> String: return "regenerate this creature; when it regenerates this way, target opponent may draw a card"

class Scars extends PreventDamageEffect:
	func _init() -> void:
		super(7)
		any_target()
		helpful()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if t.is_player:
			super(g, s, pid, t, x)
			return
		var i := g.find_instance(t.instance_id)
		var receipt := g.book_tracked_prevention(i, 7, "Scars of the Veteran")
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, load("res://cards/sets/ice/_remaining.gd")._boon_counters.bind(i.id, i.layer_timestamp, receipt), "Put +0/+1 counters equal to damage prevented by this shield."), pid, s)

static func _horde(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).controller)
	if not g.players[who].hand.is_empty() and g.agents[who].choose_yes_no(g, who, "Discard a card at random to keep Balduvian Horde?", true): g.discard_random(who, 1)
	elif F._same_trigger_source(g, s) and s.controller_id == who: g.sacrifice_permanent(s)
static func _druid_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.instance == s and s.last_blocked_this_turn
static func _creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool: return (e.data.instance.last_types & Mtg.CardType.CREATURE) != 0
static func _druid(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(int(g.trigger_context(s).controller), 4)
static func _host_death(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.instance.id == (s.attached_to if s.zone == Mtg.Zone.BATTLEFIELD else s.last_attached_to)
static func _host_grave(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"id": e.data.instance.id, "entry": e.data.instance.graveyard_entry, "controller": s.controller_id}
static func _host_died(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var who := int(ctx.controller)
	if s.data.card_name == "Casting of Bones":
		var before := g.players[who].drawn_this_turn.size()
		g.draw_cards(who, 3)
		B.discard_one_just_drawn(g, who, before, "Casting of Bones: discard one of the cards just drawn")
	else:
		var i := g.find_instance(int(ctx.id))
		if i != null and i.zone == Mtg.Zone.GRAVEYARD and i.graveyard_entry == int(ctx.entry): g.reanimate(i, who)
static func _inheritance(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{3}"), "Pay {3} to draw a card with Inheritance?", true): g.draw_cards(pid, 1)
static func _bookworms(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{1}{B}"), "Pay {1}{B} for Insidious Bookworms?", true):
		for t in g.current_targets(): g.discard_random(t.player_id, 1)
static func sacrifice(g: MtgGame, pid: int, filter: Callable, desc: String, count := 1) -> void:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if filter.call(i): choices.append(i)
	var picked: Array[CardInstance] = []
	for n in mini(count, choices.size()):
		var i := g.agents[pid].choose_card(g, pid, choices, "Sacrifice " + desc)
		if i == null or not choices.has(i): i = choices[0]
		picked.append(i)
		choices.erase(i)
	g.begin_simultaneous()
	for i in picked: g.sacrifice_permanent(i)
	g.end_simultaneous()
static func _lord(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	g.adjust_life(pid, -2)
	sacrifice(g, pid, B._creature, "two creatures", 2)
	for t in g.current_targets(): g.draw_cards(t.player_id, 2)
static func _war_beast(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).controller)
	sacrifice(g, who, B._land, "a land")
	g.deal_damage(s, TargetRef.player(who), 1)
static func _exile_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if B.live_source(g, s): g.exile_permanent(s)
static func _self_grave(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"id": s.id, "entry": int(e.data.graveyard_entry), "controller": int(e.data.controller), "owner": s.owner_id}
static func _gargoyle(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var pid := int(ctx.controller)
	g._rec(g.players[pid], &"skip_draw_steps")
	g.players[pid].skip_draw_steps += 1
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _gargoyle_return.bind(int(ctx.id), int(ctx.entry), int(ctx.owner)), "Return Ivory Gargoyle under its owner's control."), pid, s)
static func _gargoyle_return(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, entry: int, owner: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.GRAVEYARD and i.graveyard_entry == entry: g.reanimate(i, owner)
static func _steam(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets(): g.adjust_life(t.player_id, 2)
static func _regenerated(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return s.regenerations_this_turn > 0
static func _starfish(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var count := s.regenerations_this_turn if F._same_trigger_source(g, s) else s.last_regenerations_this_turn
	if count <= 0: return
	var token := CardData.new("Starfish", "", Mtg.CardType.CREATURE).pt(0, 1).with_colors(Mtg.ManaColor.U).with_subtypes(["starfish"])
	g.create_token(int(g.trigger_context(s).controller), token, count)
static func _sphere_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.add_counters(s, "+1/+1")
	var pid := int(g.trigger_context(s).controller)
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{%d}" % int(s.counters.get("+1/+1", 0))), "Pay {1} per +1/+1 counter to keep Phantasmal Sphere?", true) and s.controller_id == pid: g.sacrifice_permanent(s)
static func _sphere_left(_g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary: return {"count": int(s.last_counters.get("+1/+1", 0))}
static func _orb(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var size := int(g.trigger_context(s).count)
	var token := CardData.new("Orb", "", Mtg.CardType.CREATURE).pt(size, size).with_colors(Mtg.ManaColor.U).with_subtypes(["orb"]).with_keywords([Mtg.Keyword.FLYING])
	for t in g.current_targets(): g.create_token(t.player_id, token)
static func _skycaptain(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.add_counters(s, "wage")
	var pid := int(g.trigger_context(s).controller)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{%d}" % (2 * int(s.counters.get("wage", 0)))), "Pay {2} per wage counter to keep Rogue Skycaptain?", true): return
	g.remove_counters(s, "wage", int(s.counters.get("wage", 0)))
	g.change_control(s, 1 - pid)
static func _harlequin(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var top := g.exile_top_of_library(pid, false)
	if top == null or not B.live_source(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_until_eot_pump(s.id, -4 if top.is_land() else 2, 0)
	g.recalculate()
static func _suffocation_window(g: MtgGame, pid: int) -> String:
	return "" if g.players[pid].last_red_spell_damage_controller >= 0 else "Cast only after a red instant or sorcery spell dealt damage to you this turn"
static func _suffocation(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var who := g.players[pid].last_red_spell_damage_controller
	if who >= 0: g.deal_damage(s, TargetRef.player(who), 4)
