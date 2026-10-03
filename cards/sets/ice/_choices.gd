extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Freyalise's Charm", "Leshrac's Sigil":
			var charm := c.card_name == "Freyalise's Charm"
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _color_spell.bind(charm), "You may pay to draw or make that opponent discard.", _opposing_color.bind(Mtg.ManaColor.B if charm else Mtg.ManaColor.G)).capturing(_spell_context))
			c.activated(F._ability("{G}{G}" if charm else "{B}{B}", false, C.SelfBounce.new()))
		"Pentagram of the Ages": c.activated(F._ability("{4}", true, PreventDamageShieldEffect.new(0).from_sources("a source", _any)))
		"Mercenaries": c.activated(F._ability("{3}", false, MercenaryShield.new()).anyone_activated())
		"Kjeldoran Royal Guard":
			var e := F.Action.new(_royal_guard, "redirect unblocked creatures' combat damage to this creature this turn", null, true)
			e.is_damage_prevention = true
			c.activated(F._ability("", true, e))
		"Minion of Leshrac":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _minion, "Sacrifice another creature or take 5 damage; if damaged, tap this creature.", F._your_upkeep))
			c.activated(F._ability("", true, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target creature or land", _creature_land))))
		"Goblin Lyre": c.activated(F._ability("", false, F.Action.new(_lyre, "flip a coin: creatures determine damage to your opponent or you", TargetSpec.opponent())).with_sacrifice_cost())
		"Game of Chaos": c.spell(F.Action.new(_chaos, "flip a coin for life, then the winner may double the stakes and repeat", TargetSpec.opponent()))
		"Amulet of Quoz":
			c.activated(F._ability("", true, F.Action.new(_quoz, "opponent may ante a card, otherwise flip a coin to decide who loses", TargetSpec.opponent())).with_sacrifice_cost().during_step(Mtg.Step.UPKEEP).your_turn_only())
		_: return false
	return true

static func _any(_i: CardInstance) -> bool: return true
static func _creature_land(i: CardInstance) -> bool: return i.is_creature() or i.is_land()
static func _opposing_color(_g: MtgGame, s: CardInstance, e: GameEvent, color: int) -> bool:
	return int(e.data.controller) != s.controller_id and (e.data.instance.cur_colors & color) != 0
static func _spell_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary: return {"controller": s.controller_id, "other": int(e.data.controller)}
static func _color_spell(g: MtgGame, s: CardInstance, _e: GameEvent, charm: bool) -> void:
	var ctx := g.trigger_context(s)
	var who := int(ctx.controller)
	if not EffectBase.unless_paid(g, who, ManaCost.parse("{G}{G}" if charm else "{B}{B}"), s.data.card_name + ": pay for the triggered effect?"): return
	if charm:
		g.draw_cards(who, 1)
	else:
		var other := int(ctx.other)
		var cards: Array[CardInstance] = g.players[other].hand.duplicate()
		if cards.is_empty(): return
		var chosen := g.agents[who].choose_card(g, who, cards, "Leshrac's Sigil: look at that hand and choose a card to discard")
		if chosen != null and cards.has(chosen): g.discard_cards(other, [chosen])
static func _royal_guard(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_floating_static(s, StaticAbility.new(_redirect.bind(pid, s.id), "Redirect unblocked combat damage to the Royal Guard."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()
static func _redirect(g: MtgGame, _s: CardInstance, pid: int, id: int) -> void:
	var i := g.find_instance(id)
	# A phased-out Guard takes nothing: the damage stays with you (CR 702.26b).
	if g.is_present(i): g.players[pid].combat_damage_redirect = id
static func _minion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var pid := int(ctx.controller)
	var candidates: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_creature() and i != s: candidates.append(i)
	if not candidates.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Sacrifice another creature to prevent Minion of Leshrac's 5 damage?", g.players[pid].life <= 8):
		var pick := g.agents[pid].choose_card(g, pid, candidates, "Choose another creature to sacrifice", false, true)
		if pick != null and candidates.has(pick):
			g.sacrifice_permanent(pick)
			return
	var stamp := int(ctx.timestamp)
	g.deal_damage(s, TargetRef.player(pid), 5, false, func(dealt: int) -> void:
		if dealt > 0 and s.zone == Mtg.Zone.BATTLEFIELD and s.layer_timestamp == stamp: g.tap_permanent(s))
static func _creatures(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_creature(): n += 1
	return n
static func _lyre(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if g.flip_coin(pid): g.deal_damage(s, t, _creatures(g, pid))
	else: g.deal_damage(s, TargetRef.player(pid), _creatures(g, t.player_id))
static func _chaos(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var stakes := 1
	# State-based losses wait until the entire resolving spell finishes.
	g.begin_simultaneous()
	for round_index in 30:
		var won := g.flip_coin(pid)
		g.adjust_life(pid, stakes if won else -stakes)
		g.adjust_life(t.player_id, -stakes if won else stakes)
		if round_index == 29:
			g.log_line("Game of Chaos: the documented 30-flip safety limit was reached")
			break
		var chooser := pid if won else t.player_id
		if not g.agents[chooser].choose_yes_no(g, chooser, "Game of Chaos: flip again for %d life?" % (stakes * 2), false): break
		stakes *= 2
	g.end_simultaneous()
static func _quoz(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	if not g.players[who].library.is_empty() and g.agents[who].choose_yes_no(g, who, "Ante the top card of your library to avoid Amulet of Quoz's coin flip?", true):
		g.ante_top_of_library(who)
		return
	g.lose_game(who if g.flip_coin(pid) else pid, "Amulet of Quoz")

class MercenaryShield extends EffectBase:
	func _init() -> void: is_damage_prevention = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var id := s.id
		var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
		g._rec(g.players[pid], &"prevention_shield_filters")
		g.players[pid].prevention_shield_filters.append({"desc": "Mercenaries", "filter": func(i: CardInstance) -> bool: return i.id == id and i.layer_timestamp == stamp})
	func describe() -> String: return "prevent the next damage this creature would deal to you this turn"
