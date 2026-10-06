extends GameTest
## Pack 9 engine package E3 — SPECIAL ACTIONS (CR 116.2c, 116.2d, 116.3).
##
## One list and one door for every "pay / sacrifice to end or ignore an
## effect" a seat may take any time it has priority, no stack:
##   * [method MtgGame.special_actions] — rows `{kind, id, label, cost, by,
##     card, desc}` (and `sacrifice` on an ignore row); kinds `settle`
##     (Sabertooth Cobra / Nafs Asp, the rows the duel screen, SGManalink
##     and the AI already read through
##     [method MtgGame.settleable_delayed_triggers], unchanged),
##     `licid_end` ("You may pay {R} to end this effect") and
##     `ignore_effect` (Volrath's Curse: "That creature's controller may
##     sacrifice a permanent of their choice for that player to ignore
##     this effect until end of turn");
##   * [method MtgGame.special_action_refusal] — why a row can't be taken
##     now (what a front end greys it with);
##   * [method MtgGame.take_special_action] — the one entry point.
## The licid's own activation is pinned in test_pack_9_engine_E3_licids.gd.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

static func _licid(end := "{R}") -> CardData:
	return CardData.new("Synthetic Licid", "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{R}", end) \
		.static_ability(StaticAbility.new(_host_haste, "Enchanted creature has haste.").changing_abilities()) \
		.oracle("{R}, {T}: ... You may pay %s to end this effect.\nEnchanted creature has haste." % end)


static func _host_haste(game: MtgGame, s: CardInstance) -> void:
	if s.attached_to == -1:
		return
	var h := game.find_instance(s.attached_to)
	if game.is_present(h) and not h.cur_keywords.has(Mtg.Keyword.HASTE):
		h.cur_keywords.append(Mtg.Keyword.HASTE)


## Volrath's Curse's shape: "Enchanted creature can't attack or block, and
## its activated abilities can't be activated. That creature's controller
## may sacrifice a permanent of their choice for that player to ignore
## this effect until end of turn." Every half of the effect asks
## [method MtgGame.effect_ignored_by] first.
static func _curse() -> CardData:
	return CardData.new("Synthetic Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_curse_host,
			"Enchanted creature can't attack or block.")) \
		.bans_activations(_curse_ban) \
		.ignorable_by_sacrifice("permanent") \
		.oracle("Enchant creature\nEnchanted creature can't attack or block, and its activated abilities can't be activated. That creature's controller may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.")


static func _curse_host(game: MtgGame, s: CardInstance) -> void:
	var h := game.find_instance(s.attached_to)
	if not game.is_present(h) or game.effect_ignored_by(s, h.controller_id):
		return
	h.cur_cant_attack = true
	h.cur_cant_block_filter = _any_attacker


static func _any_attacker(_attacker: CardInstance) -> bool:
	return true


static func _curse_ban(game: MtgGame, source: CardInstance, pid: int,
		inst: CardInstance, _ability: Variant, is_mana: bool) -> bool:
	return not is_mana and inst.id == source.attached_to \
		and not game.effect_ignored_by(source, pid)


func _attach_licid(licid: CardInstance, host: CardInstance) -> void:
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(host)]))
	resolve_stack()
	assert_true(g.is_licid_aura(licid))


func _rows(pid: int, kind: String) -> Array:
	var out: Array = []
	for row in g.special_actions(pid):
		if String(row["kind"]) == kind:
			out.append(row)
	return out


func _cursed(pid := 0) -> Array:
	var curse := give_synthetic(1, _curse())
	var bear := put_battlefield(pid, "Grizzly Bears")
	g.priority_player = 1
	g.attach_aura_from_anywhere(curse, bear, 1)
	g.priority_player = 0
	return [curse, bear]


static func _pay_debt(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass


static func _any_upkeep(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> bool:
	return true


func _debt(pid: int, source: CardInstance) -> Dictionary:
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _pay_debt, "At the next upkeep, a debt comes due.",
		_any_upkeep), 1 - pid, source, false, {}, "the debt")
	entry["settle_cost"] = ManaCost.parse("{2}")
	entry["settle_by"] = pid
	return entry


# ---------------------------------------------------------------- the rows --

func test_a_licid_aura_offers_its_controller_one_end_row() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(_rows(0, "licid_end").is_empty(), "a creature licid has no effect to end")
	_attach_licid(licid, bear)
	var rows := _rows(0, "licid_end")
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	assert_eq(int(row["id"]), licid.id)
	assert_eq(row["card"], licid)
	assert_eq(int(row["by"]), 0)
	assert_eq(str(row["cost"]), "{R}")
	assert_eq(String(row["label"]), "Pay {R}: end Synthetic Licid's effect")
	assert_true(_rows(1, "licid_end").is_empty(), "not the opponent's")


func test_the_settle_rows_are_the_delayed_triggers_rows_unchanged() -> void:
	var source := put_battlefield(1, "Grizzly Bears")
	var entry := _debt(0, source)
	assert_eq(g.settleable_delayed_triggers(0), [entry] as Array[Dictionary],
		"the old list is untouched")
	var rows := _rows(0, "settle")
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	assert_eq(int(row["id"]), int(entry["id"]))
	assert_eq(String(row["label"]), "Pay {2}: the debt", "the duel screen's own words")
	assert_eq(row["cost"], entry["settle_cost"])
	assert_eq(row["card"], source)
	assert_true(_rows(1, "settle").is_empty())
	assert_refused(g.take_special_action(0, row), "not enough mana")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.take_special_action(0, row))
	assert_true(g.delayed_triggers.is_empty(), "paid off, as settle_delayed_trigger does")


# --------------------------------------------------- ending a licid effect --

func test_ending_the_effect_uses_no_stack_and_keeps_priority() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))
	add_mana(0, Mtg.ManaColor.R)
	var heard: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void: heard.append(e.type))
	assert_ok(g.take_special_action(0, _rows(0, "licid_end")[0]))
	assert_true(g.stack.is_empty(), "nothing to respond to (CR 116.2c)")
	assert_eq(g.priority_player, 0, "the taker keeps priority (CR 116.3)")
	assert_false(heard.has(Mtg.EventType.ABILITY_ACTIVATED), "not an ability")
	assert_true(licid.is_creature())
	assert_true(licid.has_subtype("licid"))
	assert_false(licid.is_aura())
	assert_eq(licid.attached_to, -1)
	assert_true(bear.attachments.is_empty())
	assert_false(bear.has_keyword(Mtg.Keyword.HASTE))
	assert_true(licid.tapped, "still tapped from its activation")
	assert_false(licid.summoning_sick, "never left: no new sickness")
	assert_eq(licid.cur_activated_abilities.size(), 1, "the licid ability is back")
	assert_eq(licid.data, licid.printed_data)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_true(_rows(0, "licid_end").is_empty())


func test_a_licid_ended_after_its_controllers_untap_step_can_attack() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(0, licid))
	assert_eq(CombatState.attack_illegality(g, licid, 1), "",
		"controlled continuously since the turn began (CR 302.6)")


func test_mana_abilities_pay_the_end_cost() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	var mountain := put_battlefield(0, "Mountain")
	assert_eq(g.special_action_refusal(0, _rows(0, "licid_end")[0]), "")
	assert_ok(g.take_special_action(0, _rows(0, "licid_end")[0]))
	assert_true(mountain.tapped, "the payer's mana source was tapped for it")
	assert_true(licid.is_creature())


func test_an_unaffordable_end_is_refused_and_nothing_changes() -> void:
	var licid := put_synthetic(0, _licid("{R}{R}"))
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	var mountain := put_battlefield(0, "Mountain")
	var row: Dictionary = _rows(0, "licid_end")[0]
	assert_string_contains(g.special_action_refusal(0, row), "not enough mana")
	assert_refused(g.take_special_action(0, row), "not enough mana")
	assert_false(mountain.tapped, "a refused action taps nothing")
	assert_true(g.is_licid_aura(licid))
	assert_eq(licid.attached_to, bear.id)
	assert_eq(g.priority_player, 0)


func test_the_end_needs_priority_and_its_controller() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	var row: Dictionary = _rows(0, "licid_end")[0]
	add_mana(0, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.take_special_action(1, row), "")
	assert_refused(g.end_licid_effect(1, licid), "")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_string_contains(g.special_action_refusal(0, row), "priority")
	assert_refused(g.take_special_action(0, row), "priority")
	assert_true(g.is_licid_aura(licid))


func test_a_stale_row_is_refused() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	var row: Dictionary = _rows(0, "licid_end")[0]
	g.destroy(bear)
	g.check_state_based_actions()
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.take_special_action(0, row), "no longer available")
	assert_refused(g.take_special_action(0, {"kind": "nonsense", "id": 1}), "no longer available")


func test_the_opponent_may_end_nothing_by_responding_before_the_effect_ends() -> void:
	# In response to the ACTIVATION the opponent can act; to the END they
	# cannot — it never touches the stack. A Bolt the opponent holds is
	# still in hand when the licid is a creature again.
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	add_mana(0, Mtg.ManaColor.R)
	var passes_before := g.priority_player
	assert_ok(g.end_licid_effect(0, licid))
	assert_eq(g.priority_player, passes_before)
	assert_true(g.stack.is_empty())


func test_the_end_under_both_rules_presets() -> void:
	# Fifth Edition's damage-prevention window admits prevention only
	# (`Duel.hlp`): the special action is refused there, exactly as the
	# Circling Vultures discard is; the modern profile has no window.
	for preset in ["fifth", "modern"]:
		before_each()
		g.rules.set_preset(preset)
		g.rules.damage_prevention_window = preset == "fifth"
		g.set_agent(1, Duelist.new())
		give_hand(1, "Healing Salve")   # something to do in the window
		var licid := put_synthetic(1, _licid())
		var host := put_battlefield(1, "Grizzly Bears")
		g.priority_player = 1
		add_mana(1, Mtg.ManaColor.R)
		assert_ok(g.activate_ability(1, licid, 0, [TargetRef.card(host)]))
		resolve_stack()
		g.priority_player = 0
		var bolt := give_hand(0, "Lightning Bolt")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
		resolve_stack()
		add_mana(1, Mtg.ManaColor.R)
		if preset == "fifth":
			assert_true(g.awaiting_damage_prevention, "the window is open")
			if g.priority_player != 1:
				assert_ok(g.end_damage_prevention(g.priority_player))
			assert_eq(g.priority_player, 1)
			var row: Dictionary = _rows(1, "licid_end")[0]
			assert_string_contains(g.special_action_refusal(1, row), "damage prevention")
			assert_refused(g.take_special_action(1, row), "damage prevention")
			assert_true(g.is_licid_aura(licid))
		else:
			assert_false(g.awaiting_damage_prevention)
			g.priority_player = 1
			assert_ok(g.take_special_action(1, _rows(1, "licid_end")[0]))
			assert_true(licid.is_creature())


class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


# --------------------------------------------- ignoring Volrath's Curse --

func test_the_curse_binds_until_its_victim_ignores_it_for_the_turn() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var bear: CardInstance = pair[1]
	var land := put_battlefield(0, "Forest")
	assert_eq(CombatState.attack_illegality(g, bear, 1), "can't attack")
	var rows := _rows(0, "ignore_effect")
	assert_eq(rows.size(), 1, "offered to the enchanted creature's controller")
	assert_true(_rows(1, "ignore_effect").is_empty(), "not to the Curse's")
	var row: Dictionary = rows[0]
	assert_eq(row["card"], curse)
	assert_eq(String(row["sacrifice"]), "permanent")
	assert_eq(String(row["label"]), "Sacrifice a permanent: ignore Synthetic Curse this turn")
	g.set_agent(0, PickFirst.new(land))
	assert_ok(g.take_special_action(0, row))
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD, "the sacrifice was the payer's choice")
	assert_true(g.effect_ignored_by(curse, 0))
	assert_false(g.effect_ignored_by(curse, 1))
	assert_true(g.stack.is_empty())
	assert_eq(g.priority_player, 0)
	assert_eq(CombatState.attack_illegality(g, bear, 1), "", "free for the turn")
	assert_true(_rows(0, "ignore_effect").is_empty(), "nothing left to ignore this turn")
	advance_to_next_turn()   # theirs
	assert_false(g.effect_ignored_by(curse, 0), "until end of turn only")
	advance_to_next_turn()   # ours again
	assert_eq(CombatState.attack_illegality(g, bear, 1), "can't attack")
	assert_eq(_rows(0, "ignore_effect").size(), 1)


func test_the_curse_bans_the_creatures_abilities_until_ignored() -> void:
	var curse := give_synthetic(1, _curse())
	var prodigal := put_battlefield(0, "Prodigal Sorcerer")
	g.attach_aura_from_anywhere(curse, prodigal, 1)
	g.priority_player = 0
	var land := put_battlefield(0, "Forest")
	assert_refused(g.activate_ability(0, prodigal, 0, [TargetRef.player(1)]), "Synthetic Curse")
	g.set_agent(0, PickFirst.new(land))
	assert_ok(g.ignore_static_effect(0, curse))
	assert_ok(g.activate_ability(0, prodigal, 0, [TargetRef.player(1)]))


func test_the_sacrifice_is_held_for_a_human_seat_and_replayed() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var bear: CardInstance = pair[1]
	var land := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Island")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.take_special_action(0, _rows(0, "ignore_effect")[0]))
	assert_not_null(g.awaiting_choice, "the payer is asked which permanent")
	assert_true(g.awaiting_choice.is_cost)
	assert_true(g.awaiting_choice.candidates.has(land))
	assert_true(g.awaiting_choice.candidates.has(bear), "any permanent of theirs")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "nothing moves while asked")
	assert_false(g.effect_ignored_by(curse, 0))
	assert_ok(g.answer_choice(other.id))
	assert_null(g.awaiting_choice)
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.effect_ignored_by(curse, 0))
	assert_eq(g.priority_player, 0)


func test_the_held_sacrifice_may_be_withdrawn() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var land := put_battlefield(0, "Forest")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.take_special_action(0, _rows(0, "ignore_effect")[0]))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.cancel_choice())
	assert_null(g.awaiting_choice)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.effect_ignored_by(curse, 0))


func test_ignoring_needs_priority_the_right_player_and_not_the_1997_window() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var land := put_battlefield(0, "Forest")
	g.set_agent(0, PickFirst.new(land))
	assert_refused(g.ignore_static_effect(1, curse), "")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_refused(g.ignore_static_effect(0, curse), "priority")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	# The window (fifth): refused there, like every special action.
	before_each()
	g.rules.set_preset("fifth")
	g.rules.damage_prevention_window = true
	g.set_agent(0, Duelist.new())
	give_hand(0, "Healing Salve")
	pair = _cursed()
	curse = pair[0]
	var bolt2 := give_hand(1, "Lightning Bolt")
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt2, [TargetRef.player(0)]))
	resolve_stack()
	assert_true(g.awaiting_damage_prevention)
	if g.priority_player != 0:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.priority_player, 0)
	assert_refused(g.ignore_static_effect(0, curse), "damage prevention")
	assert_false(g.effect_ignored_by(curse, 0))


func test_a_new_controller_of_the_cursed_creature_is_bound_again() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var bear: CardInstance = pair[1]
	var land := put_battlefield(0, "Forest")
	g.set_agent(0, PickFirst.new(land))
	assert_ok(g.ignore_static_effect(0, curse))
	assert_false(bear.cur_cant_attack)
	g.change_control(bear, 1)
	g.recalculate()
	assert_true(bear.cur_cant_attack, "ignored for player 0, not for its new controller")
	assert_eq(_rows(1, "ignore_effect").size(), 1)
	assert_true(_rows(0, "ignore_effect").is_empty())


func test_special_actions_round_trip_field_exact() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach_licid(licid, bear)
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.take_special_action(0, _rows(0, "licid_end")[0])), "ending a licid effect")
	var pair := _cursed()
	var land := put_battlefield(0, "Forest")
	g.set_agent(0, PickFirst.new(land))
	_round_trips(func() -> void:
		assert_ok(g.take_special_action(0, _rows(0, "ignore_effect")[0])), "ignoring the Curse")
	assert_false(g.effect_ignored_by(pair[0], 0))
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


## Answers every card question with [member pick] when it is offered.
class PickFirst extends DecisionAgent:
	var pick: CardInstance
	func _init(p: CardInstance) -> void:
		pick = p
	func choose_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String, _optional := false, _adverse := false,
			_ordered := false) -> CardInstance:
		return pick if candidates.has(pick) else candidates[0]


# ------------------------------------------------------------ the journal --

func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if not _same(obj.get(name), row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_ARRAY:
		var aa := a as Array
		var bb := b as Array
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var ad := a as Dictionary
		var bd := b as Dictionary
		if ad.size() != bd.size():
			return false
		for k in ad:
			if not bd.has(k) or not _same(ad[k], bd[k]):
				return false
		return true
	return a == b


func _round_trips(move: Callable, what: String) -> void:
	var before := _capture()
	var mark := g.make_mark()
	move.call()
	var mark_size := g.undo_log.size()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "%s left state behind" % what)
	assert_gt(mark_size, mark, "%s recorded nothing — is the move happening?" % what)
	g.end_search()
