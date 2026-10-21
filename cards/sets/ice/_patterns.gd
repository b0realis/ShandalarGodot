extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")
const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Deflection": c.spell(F.Action.new(_deflection, "change the target of target spell with a single target", TargetSpec.spell("target spell with a single target").with_game_filter(_single_target)))
		"Ghostly Flame": c.static_ability(StaticAbility.new(_ghostly, "Black and red sources deal damage as colorless sources."))
		"Oath of Lim-Dûl":
			c.activated(F._ability("{B}{B}", false, DrawEffect.new(1)))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LIFE_LOST, _oath, "For each 1 life lost, sacrifice another permanent unless you discard a card.", _your_life_loss))
		"Burnt Offering":
			c.with_additional_sacrifice("a creature", _creature)
			c.spell(F.Action.new(_offering, "add the sacrificed creature's mana value in any combination of black and red mana", null, true))
		"Elemental Augury": c.activated(F._ability("{3}", false, F.Action.new(_augury, "look at and reorder the top three cards of target player's library", TargetSpec.player())))
		"Orcish Librarian": c.activated(F._ability("{R}", true, F.Action.new(_librarian, "look at eight cards, randomly exile four, and order the rest", null, true)))
		"Vexing Arcanix": c.activated(F._ability("{3}", true, F.Action.new(_arcanix, "target player names a card, then reveals their top card: keep it on a match, otherwise mill it and take 2 damage", TargetSpec.player())))
		"Hecatomb":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _hecatomb, "Sacrifice this enchantment unless you sacrifice four creatures.", F._self_enter))
			var a := F._ability("", false, DamageEffect.new(1).any_target())
			a.tap_permanent_count = 1
			a.tap_permanent_filter = _swamp
			c.activated(a)
		"Orcish Farmer": c.activated(F._ability("", true, F.Action.new(_farmer, "target land becomes a Swamp until its controller's next untap step", TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))))
		"Crown of the Ages": c.activated(F._ability("{4}", true, F.Action.new(_crown, "attach target Aura attached to a creature to another creature", TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Aura attached to a creature").with_game_filter(_creature_aura))))
		"Chaos Lord":
			c.as_it_enters(_lord_enter)
			c.static_ability(StaticAbility.new(_lord_haste, "Can attack as though it had haste unless it entered this turn."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _lord, "Target opponent gains control if the number of permanents is even.", F._your_upkeep).targeting(TargetSpec.opponent()))
		"Chaos Moon": c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _moon, "Count permanents: odd strengthens red creatures and Mountains, even weakens them."))
		"Call to Arms":
			c.as_it_enters(_arms_enter)
			c.static_ability(StaticAbility.new(_arms, "White creatures get +1/+1 while the chosen color is strictly most common."))
			# "When the chosen color isn't the most common ... sacrifice this
			# enchantment." The engine's clause, so it follows the rules fork
			# (RulesOptions.sacrifice_clauses_wait, 2026-10-13); switched on it
			# is a state trigger with no intervening "if": restoring the
			# colour's lead after it triggered does not stop the sacrifice.
			c.sacrifices_when(_arms_gone)
		_: return false
	return true

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _single_target(g: MtgGame, i: CardInstance) -> bool:
	var item := g.find_stack_item(i)
	return item != null and item.kind == Mtg.StackKind.SPELL and item.targets.size() == 1
static func _deflection(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var spell := g.find_instance(t.instance_id)
	var candidates := g.single_spell_retargets(spell)
	if candidates.is_empty(): return
	var labels: Array[String] = []
	var best := 0
	var value := -INF
	for n in candidates.size():
		var ref: TargetRef = candidates[n]
		var i := g.find_instance(ref.instance_id) if not ref.is_player else null
		labels.append(g.players[ref.player_id].player_name if ref.is_player else (i.data.card_name if i != null else str(ref)))
		var score := retarget_value(g, pid, spell, ref)
		if score > value:
			value = score
			best = n
	var at := g.agents[pid].choose_option(g, pid, labels, "Deflection: choose the spell's new target", best)
	if at >= 0 and at < candidates.size(): g.retarget_spell(spell, 0, candidates[at])
static func retarget_value(g: MtgGame, pid: int, spell: CardInstance, ref: TargetRef) -> float:
	var item := g.find_stack_item(spell)
	var helpful := false
	if item != null:
		for effect in item.effects:
			if effect.target_spec != null:
				helpful = effect.ai_helpful or effect is PumpEffect or effect is GainLifeEffect or effect is DrawEffect
				break
	var owner := ref.player_id if ref.is_player else -1
	var value := 4.0
	if not ref.is_player:
		var i := g.find_instance(ref.instance_id)
		if i == null: return -INF
		owner = i.controller_id
		value = float(maxi(1, i.data.cost.mana_value())) + maxi(0, i.cur_power) + maxi(0, i.cur_toughness)
	return value if (owner == pid) == helpful else -value
static func _ghostly(g: MtgGame, _s: CardInstance) -> void: g.ghostly_flame_active = true
static func _your_life_loss(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.controller_id and int(e.data.amount) > 0
static func _oath(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	for _n in int(e.data.amount):
		var cards: Array[CardInstance] = g.players[pid].hand.duplicate()
		var permanents: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if i != s or not F._same_trigger_source(g, s): permanents.append(i)
		if not cards.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Oath of Lim-Dûl: discard a card instead of sacrificing a permanent?", true):
			var pick := g.agents[pid].choose_card(g, pid, cards, "Oath of Lim-Dûl: discard a card", false, true)
			if pick != null and cards.has(pick):
				g.discard_cards(pid, [pick])
				continue
		if not permanents.is_empty():
			var pick := g.agents[pid].choose_card(g, pid, permanents, "Oath of Lim-Dûl: sacrifice a permanent other than this Oath", false, true)
			if pick != null and permanents.has(pick): g.sacrifice_permanent(pick)
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _swamp(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("swamp")
static func _offering(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var total := int(s.memory.get("sacrificed_mv", 0))
	var options: Array[String] = []
	for black in total + 1: options.append("%d black, %d red" % [black, total - black])
	var chosen := g.agents[pid].choose_option(g, pid, options, "Burnt Offering: choose the mana combination", total)
	if chosen < 0 or chosen > total: return
	g.players[pid].mana_pool.add(Mtg.ManaColor.B, chosen)
	g.players[pid].mana_pool.add(Mtg.ManaColor.R, total - chosen)
static func top(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var pile: Array[CardInstance] = g.players[pid].library
	for n in mini(count, pile.size()): result.append(pile[pile.size() - 1 - n])
	return result
static func order(g: MtgGame, chooser: int, owner: int, cards: Array[CardInstance]) -> void:
	var left: Array[CardInstance] = cards.duplicate()
	var ordered: Array[CardInstance] = []
	while not left.is_empty():
		var pick := g.agents[chooser].choose_card(g, chooser, left, "Order these revealed-to-you cards, next draw first", false, chooser != owner, true)
		if pick == null or not left.has(pick): return
		left.erase(pick)
		ordered.append(pick)
	g.reorder_top_of_library(owner, ordered)
static func _augury(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	order(g, pid, t.player_id, top(g, t.player_id, 3))
	if C.same_activation(g, s):
		g._rec(s, &"memory")
		s.memory["augury_turn"] = g.turn_number
static func _librarian(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards := top(g, pid, 8)
	# The four exiles are random without replacement, including short libraries.
	for _n in mini(4, cards.size()):
		var i: CardInstance = cards[g.rng.randi_range(0, cards.size() - 1)]
		cards.erase(i)
		g.exile_library_card(i)
	order(g, pid, pid, cards)
static func _arcanix(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	if g.players[who].library.is_empty(): return
	var names: Array[String] = load("res://cards/sets/leg/petra_sphinx.gd").RiddleEffect.nameable(g, who)
	var named := ""
	if not names.is_empty():
		var at := g.agents[who].choose_option(g, who, names, "Vexing Arcanix: name a card", 0)
		if at < 0 or at >= names.size(): return
		named = names[at]
	var card: CardInstance = g.players[who].library.back()
	g.log_line("Vexing Arcanix: named %s, revealed %s" % [named, card.data.card_name])
	if card.data.card_name == named: g.top_of_library_to_hand(who)
	else:
		g.mill(who, 1)
		g.deal_damage(s, t, 2)
static func hecatomb_worthwhile(g: MtgGame, pid: int) -> bool:
	var bodies: Array[int] = []
	var swamps := 0
	for i in g.players[pid].battlefield:
		if i.is_land() and i.has_subtype("swamp"): swamps += 1
		if i.is_creature(): bodies.append(maxi(0, i.cur_power) + maxi(0, i.cur_toughness) + (0 if i.is_token else i.data.cost.mana_value()))
	if bodies.size() < 4 or swamps < 3: return false
	if swamps >= g.players[1 - pid].life: return true
	bodies.sort()
	return bodies[0] + bodies[1] + bodies[2] + bodies[3] <= swamps * 3
static func _hecatomb(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_creature(): choices.append(i)
	if choices.size() < 4 or not g.agents[pid].choose_yes_no(g, pid, "Sacrifice four creatures to keep Hecatomb?", hecatomb_worthwhile(g, pid)):
		if F._same_trigger_source(g, s) and s.controller_id == pid: g.sacrifice_permanent(s)
		return
	var selected: Array[CardInstance] = []
	for n in 4:
		var pick := g.agents[pid].choose_card(g, pid, choices, "Hecatomb: sacrifice creature %d of 4" % (n + 1), false, true)
		if pick == null or not choices.has(pick): return
		choices.erase(pick)
		selected.append(pick)
	g.begin_simultaneous()
	for i in selected: g.sacrifice_permanent(i)
	g.end_simultaneous()
static func _farmer(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	g.continuous.add_floating_static(s, StaticAbility.new(_swamp_type.bind(i.id), "This land is a Swamp.").changing_land_types(), ContinuousEffects.Duration.UNTIL_UNTAP_OF, i.controller_id, false, i.id)
	g.recalculate()
static func _swamp_type(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD: i.become_basic_land_type("swamp", Mtg.ManaColor.B)
static func _creature_aura(g: MtgGame, i: CardInstance) -> bool:
	var host := g.find_instance(i.attached_to)
	return i.data.is_aura() and host != null and host.zone == Mtg.Zone.BATTLEFIELD and host.is_creature()
static func _crown(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var aura := g.find_instance(t.instance_id)
	var choices: Array[CardInstance] = []
	for i in g.all_battlefield():
		if not i.is_creature() or i.id == aura.attached_to: continue
		if not g.aura_can_enchant(aura, i): continue
		if (i.cur_protection & aura.cur_colors) != 0: continue
		choices.append(i)
	if choices.is_empty(): return
	choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return crown_value(g, aura, a, pid) > crown_value(g, aura, b, pid))
	var pick := g.agents[pid].choose_card(g, pid, choices, "Crown of the Ages: attach the Aura to another creature")
	if pick != null and choices.has(pick): g.move_aura(aura, pick)
# Public facts only (the AI ranks hosts with it): a face-down host weighs
# its mana value 0 (CR 708.2), never the card under the mask (bug hunt
# 2026-10-21).
static func crown_value(_g: MtgGame, aura: CardInstance, host: CardInstance, pid: int) -> float:
	if host == null: return 0.0
	var worth := float(maxi(1, host.cur_power) + maxi(1, host.cur_toughness)
		+ (0 if host.face_down else host.data.cost.mana_value()))
	if aura.data.aura_steals: return worth if aura.controller_id == pid else -worth
	var helpful := EffectIntent.aura_aim(aura.data) != EffectIntent.Aim.HOSTILE
	return worth if (host.controller_id == pid) == helpful else -worth
static func _lord_enter(g: MtgGame, s: CardInstance, _pid: int) -> void:
	g._rec(s, &"memory")
	s.memory["lord_entered_turn"] = g.turn_number
static func _lord_haste(g: MtgGame, s: CardInstance) -> void:
	if int(s.memory.get("lord_entered_turn", g.turn_number)) < g.turn_number: s.cur_attacks_as_if_hasty = true
static func _lord(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and g.all_battlefield().size() % 2 == 0:
		g.change_control(s, g.current_targets()[0].player_id)
static func _moon(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var odd := g.all_battlefield().size() % 2 != 0
	# P/T recipients are fixed as this triggered ability resolves (CR 611.2c).
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.R) != 0:
			g.continuous.add_until_eot_pump(i.id, 1 if odd else -1, 1 if odd else -1)
	if odd:
		var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _moon_mana, "Add an additional red mana.", _mountain_tapped).as_mana_trigger()
		trigger.mana_bonus_subtype = "mountain"
		trigger.mana_bonus_color = Mtg.ManaColor.R
		trigger.mana_bonus_amount = 1
		var delayed := g.schedule_delayed_trigger(trigger, int(g.trigger_context(s).controller), s, true)
		delayed["expires_turn"] = g.turn_number
	else: g.continuous.add_floating_static(s, StaticAbility.new(_moon_colorless, "Mountains produce colorless mana this turn."))
	g.recalculate()
static func _mountain_tapped(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool: return e.data.instance.has_subtype("mountain")
static func _moon_mana(g: MtgGame, _s: CardInstance, e: GameEvent) -> void: g.players[int(e.data.player)].mana_pool.add(Mtg.ManaColor.R, 1)
static func _moon_colorless(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("mountain") and not i.cur_land_mana_replacements.has(Mtg.ManaColor.C): i.cur_land_mana_replacements.append(Mtg.ManaColor.C)
static func _color_counts(g: MtgGame, pid: int) -> Dictionary:
	var counts := {}
	for color in COLORS: counts[color] = 0
	for i in g.players[pid].battlefield:
		if i.is_token: continue
		for color in COLORS:
			if (i.cur_colors & color) != 0: counts[color] += 1
	return counts
static func _arms_enter(g: MtgGame, s: CardInstance, pid: int) -> void:
	var counts := _color_counts(g, 1 - pid)
	var best: int = COLORS[0]
	for color in COLORS:
		if counts[color] > counts[best]: best = color
	g._rec(s, &"memory")
	s.memory["arms_color"] = g.agents[pid].choose_color(g, pid, "Call to Arms: choose a color", best)
	s.memory["arms_opponent"] = 1 - pid
static func _arms_fails(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	if not s.memory.has("arms_color"): return false
	var counts := _color_counts(g, int(s.memory.arms_opponent))
	var chosen := int(s.memory.arms_color)
	for color in COLORS:
		if color != chosen and counts[color] >= counts[chosen]: return true
	return false
static func _arms(g: MtgGame, s: CardInstance) -> void:
	if not s.memory.has("arms_color") or _arms_fails(g, s, null): return
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.W) != 0:
			i.cur_power += 1
			i.cur_toughness += 1
static func _arms_gone(g: MtgGame, s: CardInstance) -> bool: return _arms_fails(g, s, null)
