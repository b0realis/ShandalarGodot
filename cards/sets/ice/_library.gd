extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Elkin Bottle": c.activated(F._ability("{3}", true, F.Action.new(_bottle, "exile the top card; you may play it until your next upkeep", null, true)))
		"Ashen Ghoul":
			c.activated(F._ability("{B}", false, F.Action.new(_ashen, "return this card from your graveyard to the battlefield", null, true)).from_graveyard().during_step(Mtg.Step.UPKEEP).your_turn_only().only_if(_ashen_legal))
		"Whiteout":
			c.spell(F.Action.new(_whiteout, "all creatures lose flying until end of turn"))
			c.activated(F._ability("", false, F.Action.new(_return_self, "return this card from your graveyard to your hand", null, true)).from_graveyard().with_sacrifice_of("snow land", _snow_land))
		"Necropotence":
			c.replaces_draw_step(_necro_skip)
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED, _necro_discard, "Exile the discarded card from your graveyard.", _your_discard).capturing(_grave_context))
			c.activated(F._ability("", false, F.Action.new(_necro, "exile the top card face down; put it into your hand at your next end step", null, true)).with_life_cost(1))
		"Enduring Renewal":
			c.static_ability(StaticAbility.new(_reveal_hands.bind(false), "Play with your hand revealed."))
			c.replaces_draws(_renewal_draw, _renewal_applies)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _renewal_return, "Return the creature card to your hand.", _your_creature_died).capturing(_grave_context))
		"Zur's Weirding":
			c.static_ability(StaticAbility.new(_reveal_hands.bind(true), "Both players play with hands revealed."))
			c.replaces_draws(_weirding_draw, _weirding_applies)
		"Jester's Cap":
			c.activated(F._ability("{2}", true, F.Action.new(_cap, "search target player's library and exile three cards, then shuffle", TargetSpec.player())).with_sacrifice_cost())
		"Jester's Mask":
			c.with_enters_tapped()
			c.activated(F._ability("{1}", true, F.Action.new(_mask, "replace target opponent's hand with that many cards chosen from their library", TargetSpec.opponent())).with_sacrifice_cost())
		"Icy Prison":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _prison, "Exile target creature.", F._self_enter).targeting(TargetSpec.creature()))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _prison_pay, "Sacrifice this enchantment unless any player pays {3}.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _prison_return, "Return the exiled card under its owner's control.", F._self_enter).capturing(_prison_context))
		_: return false
	return true

static func _ashen_legal(g: MtgGame, s: CardInstance) -> String:
	var pile: Array[CardInstance] = g.players[s.owner_id].graveyard
	var at := pile.find(s)
	if at < 0: return "This card must be in your graveyard"
	var creatures := 0
	for n in range(at + 1, pile.size()):
		if pile[n].is_creature(): creatures += 1
	return "" if creatures >= 3 else "Three creature cards must be above Ashen Ghoul"
static func _bottle(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if g.players[pid].library.is_empty(): return
	var i: CardInstance = g.players[pid].library.back()
	g.exile_library_card(i)
	g.grant_exile_play(i, pid, true)
static func _same_grave_activation(g: MtgGame, s: CardInstance) -> bool:
	return s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.cost_paid("_source_graveyard_entry", -1))
static func _ashen(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	# Number above it is an activation restriction, not a resolution condition.
	if _same_grave_activation(g, s): g.reanimate(s, pid)
static func _whiteout(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): g.continuous.add_until_eot_loss(i.id, [Mtg.Keyword.FLYING])
	g.recalculate()
static func _snow_land(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.SNOW) != 0
static func _return_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if _same_grave_activation(g, s): g.return_from_graveyard_to_hand(s)

static func _necro_skip(_g: MtgGame, s: CardInstance, pid: int) -> bool: return s.controller_id == pid and not s.cur_abilities_silenced
static func _your_discard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.controller_id
static func _grave_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary:
	return {"id": e.data.instance.id, "stamp": int(e.data.get("graveyard_entry", e.data.instance.graveyard_entry)), "in_grave": e.data.instance.zone == Mtg.Zone.GRAVEYARD}
static func _grave_card(g: MtgGame, s: CardInstance) -> CardInstance:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.id))
	return i if bool(ctx.in_grave) and i != null and i.zone == Mtg.Zone.GRAVEYARD and i.graveyard_entry == int(ctx.stamp) else null
static func _necro_discard(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := _grave_card(g, s)
	if i != null: g.exile_from_graveyard(i)
static func _necro(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var i := g.exile_top_of_library(pid)
	if i == null: return
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _necro_return.bind(i.id, i.exile_entry), "Put the exiled card into your hand.", _end_of.bind(pid)), pid, s)
static func _end_of(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool: return int(e.data.player) == pid
static func _necro_return(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == stamp: g.return_from_exile_to_hand(i, false)
static func _reveal_hands(g: MtgGame, s: CardInstance, both: bool) -> void:
	g.players[s.controller_id].hand_revealed = true
	if both: g.players[1 - s.controller_id].hand_revealed = true
static func _renewal_applies(_g: MtgGame, s: CardInstance, pid: int, _ctx: Dictionary) -> bool: return s.controller_id == pid and not s.cur_abilities_silenced
static func _weirding_applies(_g: MtgGame, s: CardInstance, _pid: int, _ctx: Dictionary) -> bool: return not s.cur_abilities_silenced
static func _renewal_draw(g: MtgGame, _s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	if g.players[pid].library.is_empty(): return false
	var i: CardInstance = g.players[pid].library.back()
	g.log_line("Enduring Renewal reveals " + i.data.card_name)
	if i.is_creature():
		g.mill(pid, 1)
		return true
	return false
static func _your_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.instance
	return i.owner_id == s.controller_id and (i.last_types & Mtg.CardType.CREATURE) != 0
static func _renewal_return(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := _grave_card(g, s)
	if i != null: g.return_from_graveyard_to_hand(i)
static func _weirding_draw(g: MtgGame, _s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	if g.players[pid].library.is_empty(): return false
	var i: CardInstance = g.players[pid].library.back()
	g.log_line("Zur's Weirding reveals " + i.data.card_name)
	var other := 1 - pid
	if g.players[other].life < 2: return false
	var hint := g.players[other].life > 5 and (not i.is_land() or g.players[pid].battlefield.size() < 4)
	if g.agents[other].choose_yes_no(g, other, "Pay 2 life to put %s into its owner's graveyard instead of drawing it?" % i.data.card_name, hint):
		g.adjust_life(other, -2)
		g.mill(pid, 1)
		return true
	return false
static func _cap(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	for _n in mini(3, g.players[who].library.size()):
		var candidates: Array[CardInstance] = g.players[who].library.duplicate()
		var choice := g.agents[pid].choose_card(g, pid, candidates, "Jester's Cap: choose a card to exile")
		if choice != null and candidates.has(choice): g.exile_library_card(choice)
	g.shuffle_library(who)
static func _mask(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var old: Array[CardInstance] = g.players[who].hand.duplicate()
	for i in old: g.put_from_hand_on_top_of_library(i)
	for _n in old.size():
		var candidates: Array[CardInstance] = g.players[who].library.duplicate()
		var choice := g.agents[pid].choose_card(g, pid, candidates, "Jester's Mask: choose a replacement card", false, true)
		if choice != null and candidates.has(choice): g.library_card_to_hand(choice)
	g.shuffle_library(who)
static func _prison(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := g.find_instance(g.current_targets()[0].instance_id)
	g.exile_permanent(i)
	if F._same_trigger_source(g, s) and i.zone == Mtg.Zone.EXILE:
		g._rec(s, &"memory")
		s.memory["prison_id"] = i.id
		s.memory["prison_stamp"] = i.exile_entry
## "Unless ANY player pays {3}" — asked of each seat, the active player
## first. The HINT is per seat (campaign 2026-10, w2-7): keeping the Prison
## is worth {3} only to a player who does not own the card it holds (the
## card returns under its OWNER's control); to the owner, and to everyone
## when it holds nothing, the hint is no.
static func _prison_pay(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var held := g.find_instance(int(s.memory.get("prison_id", -1)))
	if held != null and (held.zone != Mtg.Zone.EXILE
			or held.exile_entry != int(s.memory.get("prison_stamp", -1))):
		held = null
	for who in [g.active_player, 1 - g.active_player]:
		var worth_it: bool = held != null and held.owner_id != int(who)
		if EffectBase.unless_paid(g, who, ManaCost.parse("{3}"), "Pay {3} to keep Icy Prison?", worth_it): return
	g.sacrifice_permanent(s)
static func _prison_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary: return e.data.memory.duplicate()
static func _prison_return(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get("prison_id", -1)))
	if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(ctx.get("prison_stamp", -1)): g.return_from_exile_to_play(i, i.owner_id)
