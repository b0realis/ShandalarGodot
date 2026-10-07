extends RefCounted
## Additional Ice Age spells and activated/triggered patterns. Every delayed
## effect binds a battlefield incarnation, not merely a reusable instance id.
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")
const S := preload("res://cards/sets/ice/_snow.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Barbed Sextant":
			for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]:
				c.mana(ManaAbility.new(color).with_mana_cost("{1}").with_sacrifice().with_side_effect(_slow_draw).with_plannable_conversion())
		"Urza's Bauble":
			var a := F._ability("", true, F.Action.new(_bauble, "look at a random card in target player's hand", TargetSpec.player(), true)).with_sacrifice_cost()
			a.effects.append(DelayedDrawEffect.new())
			c.activated(a)
		"Celestial Sword":
			var a := F._ability("{3}", true, own_pump(3, 3))
			a.effects.append(F.Action.new(_doom, "sacrifice that creature at the next end step"))
			c.activated(a)
		"Dwarven Armory":
			c.activated(F._ability("{2}", false, CounterMarkerEffect.new("+2/+2")).with_sacrifice_of("land", _land).during_step(Mtg.Step.UPKEEP))
		"Orcish Lumberjack":
			for red in 4:
				var a := ManaAbility.new(Mtg.ManaColor.R, red).with_sacrifice_of("Forest", _forest)
				if red < 3: a.and_also(Mtg.ManaColor.G, 3 - red)
				c.mana(a)
		"Krovikan Elementalist":
			c.activated(F._ability("{2}{R}", false, PumpEffect.new(1, 0)))
			var a := F._ability("{U}{U}", false, own_pump(0, 0, [Mtg.Keyword.FLYING]))
			a.effects.append(F.Action.new(_doom_yours, "sacrifice that creature at the next end step"))
			c.activated(a)
		"Kjeldoran Guard", "Kjeldoran Elite Guard":
			var n := 1 if c.card_name == "Kjeldoran Guard" else 2
			var a := F._ability("", true, PumpEffect.new(n, n)).combat_only()
			a.effects.append(F.Action.new(_guard_link, "if that creature leaves this turn, sacrifice the Guard"))
			if n == 1: a.only_if(_no_defending_snow)
			c.activated(a)
		"Phantasmal Mount":
			var pump := own_pump(1, 1, [Mtg.Keyword.FLYING])
			pump.target_spec = TargetSpec.creature("target creature you control with toughness 2 or less", _small_toughness).with_source_filter(F._own)
			var a := F._ability("", true, pump)
			a.effects.append(F.Action.new(_mount_link, "if either creature leaves this turn, sacrifice the other"))
			c.activated(a)
		"Goblin Ski Patrol":
			var a := F._ability("{1}{R}", false, F.Action.new(_ski, "permanently gain +2/+0 and flying, then sacrifice at the next end step")).only_if(_ski_legal)
			a.on_cost_paid = _mark_ski
			c.activated(a)
		"Bone Shaman": c.activated(F._ability("{B}", false, F.Action.new(_bone, "damage from this creature prevents regeneration this turn")))
		"Touch of Vitae":
			c.spell(PumpEffect.new(0, 0, [Mtg.Keyword.HASTE]))
			c.spell(F.Action.new(_vitae, "grant a once-only untap ability for this turn"))
			c.spell(DelayedDrawEffect.new())
		"Wiitigo":
			c.with_enters_counters("+1/+1", 6)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wiitigo, "Add a counter if it blocked or was blocked since your last upkeep; otherwise remove one.", F._your_upkeep))
		"Battle Cry": c.spell(F.Action.new(_battle_cry, "untap your white creatures; each creature blocking this turn gets +0/+1", null, true))
		"Venomous Breath": c.spell(F.Action.new(_venom, "at end of combat, destroy all creatures that blocked or were blocked by target creature this turn", TargetSpec.creature()))
		"Meteor Shower": c.spell(Meteor.new())
		"Fire Covenant":
			c.with_additional_life(0, true)
			c.spell(DamageEffect.new(0).target_creature().x_damage().divided(-1))
		"Fumarole":
			c.with_additional_life(3)
			c.spell(DestroyEffect.new(TargetSpec.creature()))
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)))
		"Pox": c.spell(F.Action.new(_pox, "each player loses, discards, and sacrifices a third, rounded up"))
		"Demonic Consultation": c.spell(F.Action.new(_consult, "name a card; exile six cards, then search by revealing and exiling", null, true))
		"Stench of Evil": c.spell(F.Action.new(_stench, "destroy all Plains and charge their controllers {2} or 1 damage per destroyed land"))
		_: return false
	return true

static func _land(i: CardInstance) -> bool: return i.is_land()
static func own_pump(p: int, t: int, keywords: Array = []) -> PumpEffect:
	var effect := PumpEffect.new(p, t, keywords)
	effect.target_spec.with_source_filter(F._own)
	return effect
static func _forest(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("forest")
static func _small_toughness(i: CardInstance) -> bool: return i.cur_toughness <= 2
static func _slow_draw(g: MtgGame, s: CardInstance, pid: int) -> void: DelayedDrawEffect.new().resolve(g, s, pid, null)
static func _bauble(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var hand := g.players[t.player_id].hand
	if not hand.is_empty():
		var shown: CardInstance = hand[g.rng.randi_range(0, hand.size() - 1)]
		g.log_line("%s looks at %s with Urza's Bauble" % [g.players[pid].player_name, shown.data.card_name])
static func target_from_activation(g: MtgGame) -> CardInstance:
	var refs := g.current_targets()
	return g.find_instance(refs[0].instance_id) if not refs.is_empty() else null
## Celestial Sword: "ITS CONTROLLER sacrifices it" — whoever controls it
## at that end step (the doom's default sacrificer).
static func _doom(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var body := target_from_activation(g)
	if body != null: g.doom_at_next_end_step(body, false, false, true)
## Krovikan Elementalist: a bare "Sacrifice it" — the ACTIVATOR does, only
## while they still control it (CR 603.7d, 701.17a).
static func _doom_yours(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var body := target_from_activation(g)
	if body != null: g.doom_at_next_end_step(body, false, false, true, pid)
static func _no_defending_snow(g: MtgGame, _s: CardInstance) -> String:
	return "" if S.snow_count(g, 1 - g.active_player) == 0 else "The defending player controls a snow land"
static func _guard_link(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var body := target_from_activation(g)
	if body != null and C.same_activation(g, s): leave_link(g, s, pid, body, s)
static func _mount_link(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x: int) -> void:
	_guard_link(g, s, pid, t, x)
	var body := target_from_activation(g)
	if body != null:
		if C.same_activation(g, s): leave_link(g, s, pid, s, body)
		# A delayed leaves-play trigger cannot trigger retroactively if
		# the Mount already left before this ability resolved.
static func leave_link(g: MtgGame, source: CardInstance, pid: int, watched: CardInstance, doomed: CardInstance) -> void:
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD,
		_link_sacrifice.bind(doomed.id, doomed.layer_timestamp), "Sacrifice the linked creature.",
		_left.bind(watched.id, watched.layer_timestamp)), pid, source)
	entry["expires_turn"] = g.turn_number
static func _left(_g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int) -> bool:
	return e.data.instance.id == id and e.data.instance.layer_timestamp == stamp
static func _link_sacrifice(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var body := g.find_instance(id)
	var who := int(g.current_delayed().controller)
	if body != null and body.zone == Mtg.Zone.BATTLEFIELD and body.layer_timestamp == stamp and body.controller_id == who: g.sacrifice_permanent(body)
static func _ski_legal(g: MtgGame, s: CardInstance) -> String:
	if s.memory.get("ski_used", false): return "Activate only once"
	return "" if S.snow_count(g, s.controller_id, "mountain") > 0 else "You need a snow Mountain"
static func _mark_ski(g: MtgGame, s: CardInstance, _cost: Dictionary) -> void:
	g._rec(s, &"memory")
	s.memory["ski_used"] = true
static func _ski(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s): return
	# Phased out: no pump (CR 702.26e); the sacrifice is still scheduled.
	if g.is_present(s): g.continuous.add_until_eot_pump(s.id, 2, 0, [Mtg.Keyword.FLYING], false, ContinuousEffects.Duration.INDEFINITE)
	# "ITS CONTROLLER sacrifices it": whoever controls it then (the default).
	g.doom_at_next_end_step(s, false, false, true)
	g.recalculate()
static func _bone(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s): return
	var key := "%d:%d" % [s.id, s.layer_timestamp]
	for i in g.all_battlefield():
		if i.damage_origins_this_turn.has(key): _bone_hit(g, s, i, 0)
	g.watch_damage_dealt(s, _bone_hit)
static func _bone_hit(g: MtgGame, _s: CardInstance, victim: CardInstance, _amount: int) -> void:
	if victim != null:
		g._rec(victim, &"regeneration_banned_this_turn")
		victim.regeneration_banned_this_turn = true
static func _vitae(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var body := target_from_activation(g)
	if body == null: return
	var a := F._ability("", false, F.Action.new(_untap_self, "untap this creature")).per_turn(1)
	g.continuous.add_granted_activated_ability(body.id, a, ContinuousEffects.Duration.END_OF_TURN)
	g.recalculate()
static func _untap_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if C.same_activation(g, s): g.untap_permanent(s)
static func _wiitigo(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	if s.block_history_sequence > int(s.memory.get("wiitigo_block_sequence", 0)): g.add_counters(s, "+1/+1")
	else: g.remove_counters(s, "+1/+1")
	g._rec(s, &"memory")
	s.memory["wiitigo_block_sequence"] = s.block_history_sequence
static func _battle_cry(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.players[pid].battlefield:
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.W) != 0: g.untap_permanent(i)
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.BLOCKED, _cry_block,
		"Blocking creature gets +0/+1.", _first_block).capturing(_cry_context), pid, s, true)
	entry["expires_turn"] = g.turn_number
	entry["blocking_toughness_bonus"] = 1
static func _first_block(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return g.combat.attackers_blocked_by(e.data.blocker.id).front() == e.data.attacker.id
static func _cry_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary:
	return {"blocker_stamp": e.data.blocker.layer_timestamp}
static func _cry_block(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var i: CardInstance = e.data.blocker
	if g.is_present(i) and i.layer_timestamp == int(g.trigger_context(s).blocker_stamp):   # CR 702.26e
		g.continuous.add_until_eot_pump(i.id, 0, 1)
		g.recalculate()
static func _venom(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var body := g.find_instance(t.instance_id)
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_venom_end.bind(body.id, body.layer_timestamp), "Destroy creatures that fought the marked creature."), pid, s)
	entry["expires_turn"] = g.turn_number
	entry["combat_destruction"] = {"id": body.id, "stamp": body.layer_timestamp}
static func _venom_end(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	# Reproduced: pre-combat Breath missed a survivor after its marked Bear
	# died; old blocker history also killed a blinked attacker. The turn
	# ledger preserves both incarnations, even after either has departed.
	var marked := g.combat_opponents_this_turn(id, stamp)
	g.begin_simultaneous()
	for other in marked:
		var i := g.find_instance(other)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(marked[other]): g.destroy(i)
	g.end_simultaneous()
static func _pox(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	g.begin_simultaneous()
	for who in [g.active_player, 1 - g.active_player]: g.adjust_life(who, -((maxi(0, g.players[who].life) + 2) / 3))
	g.end_simultaneous()
	var discards: Array = []
	for who in [g.active_player, 1 - g.active_player]:
		var cards := g.agents[who].choose_discard(g, who, (g.players[who].hand.size() + 2) / 3)
		discards.append([who, cards])
	g.begin_simultaneous()
	for row in discards: g.discard_cards(row[0], row[1])
	g.end_simultaneous()
	for type in [Mtg.CardType.CREATURE, Mtg.CardType.LAND]:
		var chosen: Array[CardInstance] = []
		for who in [g.active_player, 1 - g.active_player]:
			var legal: Array[CardInstance] = []
			for i in g.players[who].battlefield:
				if i.is_type(type): legal.append(i)
			for _n in (legal.size() + 2) / 3:
				var pick := g.agents[who].choose_card(g, who, legal, "Pox: choose a permanent to sacrifice")
				if pick != null:
					chosen.append(pick)
					legal.erase(pick)
		g.begin_simultaneous()
		for i in chosen: g.sacrifice_permanent(i)
		g.end_simultaneous()
static func _consult(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	# Named from the caster's own DECKLIST, most copies unaccounted for
	# first (the 2026-09-07 ruling: never every name in the pool). A bare
	# game without a decklist names nothing and the search runs dry.
	var riddle = load("res://cards/sets/leg/petra_sphinx.gd").RiddleEffect
	var names: Array[String] = riddle.nameable(g, pid)
	var named := ""
	if not names.is_empty():
		var hint := _consult_hint(names, riddle.unaccounted(g, pid))
		named = names[clampi(g.agents[pid].choose_option(g, pid, names, "Demonic Consultation: name a card", hint),
			0, names.size() - 1)]
	g.log_line("Demonic Consultation names " + named)
	for _i in 6: _exile_top_face_up(g, pid)
	while not g.players[pid].library.is_empty():
		var top: CardInstance = g.players[pid].library.back()
		g.log_line("Demonic Consultation reveals " + top.data.card_name)
		if top.data.card_name == named:
			g.top_of_library_to_hand(pid)
			return
		_exile_top_face_up(g, pid)
## The HINT for Demonic Consultation's name (campaign 2026-10, w2-9): the
## list stays ordered by copies unaccounted for, but the default is the
## most valuable NONLAND name with a copy still unaccounted for — a tutor
## that exiles six cards is not spent on a basic land — then a land, and
## never a name with no copy left (that would exile the whole library).
## Valued off the decklist and the visible board only (docs/fair-play.md).
static func _consult_hint(names: Array[String], left: Dictionary) -> int:
	var best := -1
	var best_key := []
	for i in names.size():
		var copies := int(left.get(names[i], 0))
		if copies <= 0 or names[i] == "Demonic Consultation":
			continue
		var data := CardRegistry.get_card(names[i])
		var nonland := data != null and not data.is_land()
		var key := [int(nonland), Evaluator.card_value(data) if data != null else 0.0, copies]
		if best < 0 or key > best_key:
			best = i
			best_key = key
	return maxi(best, 0)
static func _exile_top_face_up(g: MtgGame, pid: int) -> void:
	var i := g.exile_top_of_library(pid)
	if i != null:
		g._rec(i, &"face_down")
		i.face_down = false
static func _stench(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var lands: Array = []
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("plains"): lands.append([i, i.controller_id])
	g.begin_simultaneous()
	var hit: Array[int] = []
	for row in lands:
		g.destroy(row[0])
		if row[0].zone != Mtg.Zone.BATTLEFIELD: hit.append(row[1])
	g.end_simultaneous()
	for who in hit:
		if not EffectBase.unless_paid(g, who, ManaCost.parse("{2}"), "Pay {2} to prevent 1 Stench of Evil damage?"): g.deal_damage(s, TargetRef.player(who), 1)

class Meteor extends DamageEffect:
	func _init() -> void:
		super(1)
		x_damage()
		x_bonus = 1
		any_target().divided(-1)
	func divided_amount(x_value: int) -> int: return x_value + 1
