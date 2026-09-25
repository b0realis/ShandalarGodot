extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Melee":
			c.castable_only_when(_melee_timing)
			c.spell(F.Action.new(_melee, "choose the defending creatures' blocks this combat; untap and remove unblocked attackers from combat"))
		"Drought":
			c.static_ability(StaticAbility.new(_drought, "Sacrifice a Swamp per black symbol in a spell's mana cost or ability's activation cost."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _drought_upkeep, "Sacrifice this enchantment unless you pay {W}{W}.", F._your_upkeep))
		"Errant Minion":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _minion, "Pay any amount of mana, then take 2 damage with that much prevention.", A._host_upkeep).capturing(A._host_context))
		"Errantry":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, 0), "Enchanted creature gets +3/+0."))
			c.static_ability(StaticAbility.new(_alone, "Enchanted creature can attack only alone."))
		"Orcish Conscripts": c.static_ability(StaticAbility.new(_conscripts, "Attack or block only in a group of at least three creatures."))
		"Hipparion": c.static_ability(StaticAbility.new(_hipparion, "Pay {1} for each creature with power 3 or greater it blocks."))
		"Flooded Woodlands", "Reclamation":
			c.static_ability(StaticAbility.new(_land_tax.bind(Mtg.ManaColor.G if c.card_name == "Flooded Woodlands" else Mtg.ManaColor.B), "Sacrifice a land for each affected attacker."))
		"Gaze of Pain": c.spell(F.Action.new(_gaze, "unblocked creatures you control may damage a target creature instead of assigning combat damage"))
		"General Jarkeld":
			var effect := F.Action.new(_jarkeld, "exchange blockers of two blocked attackers if every new block is legal", TargetSpec.creature("target blocked attacking creature").with_game_filter(_blocked))
			effect.target_min = 2
			effect.target_max = 2
			var ability := F._ability("", true, effect)
			ability.only_during_step = Mtg.Step.DECLARE_BLOCKERS
			c.activated(ability)
		_: return false
	return true

static func _alone(g: MtgGame, s: CardInstance) -> void:
	var host := A.host(g, s)
	if host != null: host.cur_attacks_alone = true
static func _melee_timing(g: MtgGame, pid: int) -> String:
	return "" if g.active_player == pid and g.current_step() in [Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS] else "Cast only during combat on your turn before blockers are declared"
static func _melee(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var key := g._resolving_item.id
	g.continuous.add_floating_static(s, StaticAbility.new(_melee_rule.bind(pid, key), "Melee: attacker chooses blockers this combat."), ContinuousEffects.Duration.END_OF_COMBAT)
	g.recalculate()
	var trigger := TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _melee_retreat, "Untap the unblocked attacker and remove it from combat.", _melee_active.bind(key)).capturing(_unblocked_context)
	var entry := g.schedule_delayed_trigger(trigger, pid, s, true)
	entry["expires_turn"] = g.turn_number
static func _melee_rule(g: MtgGame, _s: CardInstance, pid: int, key: int) -> void:
	g.block_chooser_override = pid
	g.melee_active_effects.append(key)
static func _melee_active(g: MtgGame, _s: CardInstance, _event: GameEvent, key: int) -> bool: return g.melee_active_effects.has(key)
static func _melee_retreat(g: MtgGame, s: CardInstance, _event: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.id))
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD or i.layer_timestamp != int(ctx.stamp): return
	g.untap_permanent(i)
	if g.undo_log != null: g.undo_log.record_object(g.combat)
	g.combat.forget(i.id)
	g.recalculate()
static func _drought(g: MtgGame, _s: CardInstance) -> void: g.black_symbol_sacrifices += 1
static func _drought_upkeep(g: MtgGame, s: CardInstance, _event: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	if not EffectBase.unless_paid(g, s.controller_id, ManaCost.parse("{W}{W}"), "Pay {W}{W} to keep Drought?"): g.sacrifice_permanent(s)
static func _minion(g: MtgGame, s: CardInstance, _event: GameEvent) -> void:
	var pid := int(g.trigger_context(s).host_controller)
	var amounts: Array[int] = [0]
	var labels: Array[String] = ["Pay nothing"]
	# Mana beyond two is a legal choice too (notably under mana burn).
	var max_mana := ManaPlanner.max_affordable_x(g, pid, ManaCost.parse(""))
	for n in range(1, max_mana + 1):
		amounts.append(n)
		labels.append("Pay {%d}" % n)
	var hint := mini(2, max_mana)
	var choice := g.agents[pid].choose_option(g, pid, labels, "Errant Minion: how much mana to pay to prevent its damage?", hint)
	var paid := amounts[clampi(choice, 0, amounts.size() - 1)]
	if paid > 0 and not g.try_pay(pid, ManaCost.parse("{%d}" % paid)): paid = 0
	g.deal_damage(s, TargetRef.player(pid), 2, false, Callable(), false, paid)
static func _conscripts(_g: MtgGame, s: CardInstance) -> void:
	s.cur_min_attack_group = 3
	s.cur_min_block_group = 3
static func _hipparion(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_power_tax_threshold = 3
	s.cur_block_power_tax = 1
static func _land_tax(g: MtgGame, _s: CardInstance, color: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & color) != 0: i.cur_attack_land_sacrifices += 1

static func _gaze(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var trigger := TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _gaze_damage, "May deal damage equal to the unblocked creature's power to target creature instead of assigning combat damage.", _our_unblocked.bind(pid)).capturing(_unblocked_context).targeting(TargetSpec.creature(), F._enemy_first)
	var entry := g.schedule_delayed_trigger(trigger, pid, s, true)
	entry["expires_turn"] = g.turn_number
static func _our_unblocked(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool: return int(e.data.controller) == pid
static func _unblocked_context(g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary:
	var i: CardInstance = e.data.instance
	g._rec(i, &"capture_departure_source")
	i.capture_departure_source = true
	return {"id": i.id, "stamp": i.layer_timestamp, "source": i, "pid": i.controller_id}
static func _gaze_damage(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i: CardInstance = ctx.source # tokens may already be absent from the live registry
	var targets := g.current_targets()
	if i == null or targets.is_empty(): return
	var live := i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(ctx.stamp)
	var origin: CardInstance = i if live else i.departed_sources.get(int(ctx.stamp))
	if origin == null: return
	var power := origin.cur_power
	var victim := g.find_instance(targets[0].instance_id)
	if victim == null: return    # the target is gone; nothing to name in the question
	var pid: int = ctx.pid
	var hint := victim.controller_id != pid and power >= victim.cur_toughness - victim.damage
	if not g.agents[pid].choose_yes_no(g, pid, "Gaze of Pain: deal damage to %s instead of assigning combat damage?" % victim.data.card_name, hint): return
	# If the original object left, its trigger still deals damage using
	# last-known power, but never suppresses its returned incarnation.
	if live:
		g.continuous.add_floating_static(i, StaticAbility.new(load("res://cards/sets/ice/_control.gd")._no_damage.bind(i.id), "Assigns no combat damage this turn."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
		g.recalculate()
	g.deal_damage(origin, targets[0], maxi(0, power))

static func _blocked(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) and g.combat.was_blocked(g.combat.band_of(i.id))
static func jarkeld_map(g: MtgGame, left: CardInstance, right: CardInstance) -> Dictionary:
	if left == null or right == null or left == right or not _blocked(g, left) or not _blocked(g, right): return {}
	var out := {}
	for id in g.combat.blocks:
		var blocker := g.find_instance(id)
		var against: Array = g.combat.attackers_blocked_by(id)
		if against.has(left.id) and CombatState.block_illegality(g, blocker, right, blocker.controller_id) != "": return {}
		if against.has(right.id) and CombatState.block_illegality(g, blocker, left, blocker.controller_id) != "": return {}
		var changed: Array = []
		for target in against:
			changed.append(right.id if target == left.id else (left.id if target == right.id else target))
		out[id] = changed
	for attacker in [left, right]:
		var assigned := 0
		for against in out.values():
			if against.has(attacker.id): assigned += 1
		if assigned < attacker.cur_min_blockers: return {}
	return out
static func _jarkeld(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var targets := g.current_targets()
	# Action resolves once per target; only the first invocation swaps.
	if targets.size() != 2 or _t != targets[0]: return
	var changed := jarkeld_map(g, g.find_instance(targets[0].instance_id), g.find_instance(targets[1].instance_id))
	if changed.is_empty(): return
	var previous := {}
	for id in changed:
		var members := {}
		for target in g.combat.attackers_blocked_by(id):
			for member in g.combat.band_of(target): members[member] = true
		previous[id] = members
	g._rec(g.combat, &"blocks")
	g._rec(g.combat, &"extra_blocks")
	g._rec(g.combat, &"damage_order")
	g.combat.blocks.clear()
	g.combat.extra_blocks.clear()
	g.combat.damage_order.clear()
	for id in changed:
		var targets_now: Array = changed[id]
		g.combat.blocks[id] = targets_now[0]
		if targets_now.size() > 1: g.combat.extra_blocks[id] = targets_now.slice(1)
		var blocker := g.find_instance(id)
		g._rec(blocker, &"blocked_ids_this_turn")
		for target in targets_now:
			var attacker := g.find_instance(target)
			blocker.blocked_ids_this_turn[target] = attacker.controller_id
	# CR 509.3d: a different blocking pair triggers "becomes blocked by a
	# creature", even though neither creature becomes blocked/blocking anew.
	# Finish every assignment first so trigger conditions see the full swap.
	for id in changed:
		var heard := {}
		for target in changed[id]:
			for member in g.combat.band_of(target):
				if heard.has(member): continue
				heard[member] = true
				var attacker := g.find_instance(member)
				var blocker := g.find_instance(id)
				if previous[id].has(member): g.record_combat_pair(attacker, blocker)
				else: g.dispatch_event(Mtg.EventType.BLOCKED, {"attacker": attacker, "blocker": blocker})
	g.recalculate()
