extends GameTest
## Pack 9 engine package E3 — LICIDS (Tempest block), pinned on SYNTHETIC
## cards built here (the twelve real licids are a card batch's):
##
##   "{cost}, {T}: This creature loses this ability and becomes an Aura
##   enchantment with enchant creature. Attach it to target creature. You
##   may pay {end} to end this effect."
##
## [method CardData.as_licid] builds that ability; its effect calls
## [method MtgGame.become_licid_aura] on resolution — an instance-level
## identity swap (the Necromancy recipe, [method MtgGame.become_aura]):
## Aura enchantment only (CR 205.1a — the Licid creature type goes with
## the creature type, 205.3d), the licid ability gone (CR 613.1f), every
## other ability kept, no zone change (no new summoning sickness, CR
## 302.6). "Pay {end} to end this effect" is a SPECIAL ACTION (CR 116.2c,
## [method MtgGame.end_licid_effect]); its rows live in
## test_pack_9_engine_E3_special_actions.gd. Here: the activation, the
## fizzle, the Aura state, the host leaving, protection, Humility,
## Dominating Licid's control, control changes, copies, two activations,
## turn expiry, both rules presets and the journal.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

## A red 2/2 licid whose Aura half grants haste ("Enraging Licid"'s shape).
static func _licid(card_name := "Synthetic Licid", act := "{R}", end := "{R}",
		steals := false) -> CardData:
	return CardData.new(card_name, "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid(act, end, steals) \
		.static_ability(StaticAbility.new(_host_haste,
			"Enchanted creature has haste.").changing_abilities()) \
		.oracle("%s, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay %s to end this effect.\nEnchanted creature has haste." % [act, end])


## A blue 1/1 that steals what it enchants ("Dominating Licid"'s shape).
static func _dominating() -> CardData:
	return CardData.new("Synthetic Dominating Licid", "{1}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1).with_subtypes(["licid"]).as_licid("{U}", "{U}", true) \
		.oracle("{U}, {T}: ... You may pay {U} to end this effect.\nYou control enchanted creature.")


static func _host_haste(game: MtgGame, s: CardInstance) -> void:
	if s.attached_to == -1:
		return
	var h := game.find_instance(s.attached_to)
	if game.is_present(h) and not h.cur_keywords.has(Mtg.Keyword.HASTE):
		h.cur_keywords.append(Mtg.Keyword.HASTE)


static func _sturdy() -> CardData:
	return CardData.new("Synthetic Sturdy", "{2}", Mtg.CardType.CREATURE).pt(2, 2) \
		.static_ability(StaticAbility.new(_indestructible, "Indestructible."))


static func _indestructible(_game: MtgGame, s: CardInstance) -> void:
	s.cur_indestructible = true


## "All creatures lose all abilities and have base power and toughness
## 1/1" (Humility's shape): a creature licid has no licid ability to use.
static func _humility() -> CardData:
	return CardData.new("Synthetic Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_humble,
			"All creatures lose all abilities and have base power and toughness 1/1.") \
			.silencing_abilities().setting_base_pt())


static func _humble(game: MtgGame, _s: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_creature():
			continue
		inst.cur_activated_abilities.clear()
		inst.cur_mana_abilities.clear()
		inst.cur_triggered_abilities.clear()
		inst.cur_keywords.clear()
		inst.cur_abilities_silenced = true
		inst.cur_power = 1
		inst.cur_toughness = 1


## Activate [param licid]'s ability (index 0) onto [param host] for
## [param pid], with the {R} or {U} it costs floating.
func _activate(licid: CardInstance, host: CardInstance, pid := 0,
		color := Mtg.ManaColor.R) -> String:
	g.priority_player = pid
	add_mana(pid, color)
	return g.activate_ability(pid, licid, 0, [TargetRef.card(host)])


func _attach(licid: CardInstance, host: CardInstance, pid := 0,
		color := Mtg.ManaColor.R) -> void:
	assert_ok(_activate(licid, host, pid, color))
	resolve_stack()


# ----------------------------------------------------- the activated ability --

func test_the_builder_declares_one_activation_and_its_end_cost() -> void:
	var data := _licid()
	assert_eq(data.activated_abilities.size(), 1)
	var ability: ActivatedAbility = data.activated_abilities[0]
	assert_eq(ability, data.licid_ability)
	assert_true(ability.tap_cost)
	assert_eq(ability.cost.text, "{R}")
	assert_eq(str(data.licid_end_cost), "{R}")
	assert_false(data.licid_steals)
	assert_null(data.licid_base, "the printed card is no Aura")
	assert_false(data.is_aura())
	assert_eq(ability.effects.size(), 1)
	assert_eq(ability.effects[0].target_spec.kind, TargetSpec.Kind.CREATURE)
	assert_eq(ability.effects[0].ai_role, &"licid")
	assert_string_contains(ability.text, "You may pay {R} to end this effect.")


func test_the_activation_makes_it_an_aura_attached_to_the_target() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	var preview := g.licid_aura_data(licid)
	assert_true(preview.is_aura(), "the preview is the Aura it would become")
	assert_true(preview.activated_abilities.is_empty())
	assert_eq(licid.data, licid.printed_data, "and previewing changes nothing")
	assert_null(g.licid_aura_data(bear), "a bear is no licid")
	assert_ok(_activate(licid, bear))
	assert_true(licid.tapped, "{T} is paid on activation")
	assert_true(licid.is_creature(), "nothing happens until it resolves")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(licid.is_aura())
	assert_false(licid.is_creature(), "no longer a creature (CR 613.1d)")
	assert_true(licid.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(licid.has_subtype("aura"))
	assert_false(licid.has_subtype("licid"), "a creature type leaves with the creature type")
	assert_eq(licid.attached_to, bear.id)
	assert_true(bear.attachments.has(licid.id))
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE), "its other abilities work")
	assert_true(licid.cur_activated_abilities.is_empty(), "it lost the licid ability")
	assert_true(licid.tapped, "an Aura that was tapped stays tapped")
	assert_eq(licid.controller_id, 0)
	assert_eq(licid.cur_colors, Mtg.ManaColor.R, "its colour is its own")
	assert_eq(licid.printed_data.card_name, "Synthetic Licid")
	assert_true(g.is_licid_aura(licid))
	assert_true(licid.data.is_aura())
	assert_eq(licid.data.licid_base, licid.printed_data)


func test_an_illegal_target_on_resolution_counters_it_and_the_licid_stays_a_tapped_creature() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(_activate(licid, bear))
	bear.added_protection = Mtg.ManaColor.R   # protection from red, in response
	g.recalculate()
	resolve_stack()
	assert_true(licid.is_creature())
	assert_false(g.is_licid_aura(licid))
	assert_true(licid.tapped)
	assert_eq(licid.attached_to, -1)
	assert_true(bear.attachments.is_empty())
	assert_eq(licid.cur_activated_abilities.size(), 1, "it keeps the ability")
	assert_eq(licid.data, licid.printed_data)


func test_a_protected_creature_is_no_target_at_all() -> void:
	var licid := put_synthetic(0, _licid())
	var knight := put_battlefield(1, "White Knight")   # protection from black
	var bear := put_battlefield(1, "Grizzly Bears")
	bear.added_protection = Mtg.ManaColor.R
	g.recalculate()
	assert_refused(_activate(licid, bear))
	assert_false(licid.tapped, "a refused activation pays nothing")
	_attach(licid, knight)   # protection from BLACK says nothing to a red licid
	assert_eq(licid.attached_to, knight.id)


func test_the_licid_leaving_before_resolution_does_nothing() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_activate(licid, bear))
	g.return_to_hand(licid)
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.HAND)
	assert_eq(licid.data, licid.printed_data)
	assert_true(bear.attachments.is_empty())
	assert_false(bear.has_keyword(Mtg.Keyword.HASTE))


func test_a_licid_that_left_and_came_back_is_a_new_object_and_is_not_moved() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_activate(licid, bear))
	g.return_to_hand(licid)
	g._remove_from_zone(licid)
	g._put_on_battlefield(licid, 0)
	resolve_stack()
	assert_true(licid.is_creature(), "CR 400.7: the ability's object is gone")
	assert_eq(licid.attached_to, -1)


# --------------------------------------------------------- the Aura state --

func test_as_an_aura_it_is_no_creature_for_anything() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	assert_false(TargetSpec.creature().is_legal(g, TargetRef.card(licid), bear),
		"Terror's kind of spell can't find it")
	var aura_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Aura",
		func(c: CardInstance) -> bool: return c.is_aura())
	assert_true(aura_spec.is_legal(g, TargetRef.card(licid), bear), "Aura hate sees an Aura")
	assert_ne(CombatState.attack_illegality(g, licid, 1), "", "it can't attack")


func test_wrath_of_god_misses_it_and_disenchant_hits_it() -> void:
	var licid := put_synthetic(0, _licid())
	var sturdy := put_synthetic(0, _sturdy())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attach(licid, sturdy)
	var wrath := give_hand(0, "Wrath of God")
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, wrath))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(sturdy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(licid.zone, Mtg.Zone.BATTLEFIELD, "an Aura is no creature to destroy")
	assert_eq(licid.attached_to, sturdy.id)
	var disenchant := give_hand(0, "Disenchant")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, disenchant, [TargetRef.card(licid)]))
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(licid.data, licid.printed_data, "a creature card in the graveyard")
	assert_true(licid.data.is_creature())
	assert_false(sturdy.has_keyword(Mtg.Keyword.HASTE))
	assert_true(sturdy.attachments.is_empty())


func test_the_host_leaving_puts_the_licid_into_its_owners_graveyard() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attach(licid, bear)
	g.destroy(bear)
	g.check_state_based_actions()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD, "CR 704.5m")
	assert_true(g.players[0].graveyard.has(licid))
	assert_eq(licid.data, licid.printed_data)
	assert_true(licid.memory.is_empty())


func test_the_host_bounced_also_takes_the_licid_off() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	g.return_to_hand(bear)
	g.check_state_based_actions()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)


func test_the_host_gaining_protection_from_its_colour_sheds_it() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	bear.added_protection = Mtg.ManaColor.R
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD, "CR 702.16d, 704.5m")
	assert_true(bear.attachments.is_empty())


func test_a_licid_aimed_at_itself_is_an_unattached_aura_and_goes_to_the_graveyard() -> void:
	# The target is legal on activation and on resolution (it is still a
	# creature then); once the effect has made it an Aura it can attach to
	# nothing that is itself (CR 303.4d), and the state-based action takes
	# the unattached Aura (CR 704.5m).
	var licid := put_synthetic(0, _licid())
	_attach(licid, licid)
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(licid.data, licid.printed_data)


func test_the_aura_state_lasts_across_turns_and_untaps_like_any_permanent() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(g.is_licid_aura(licid), "no duration: it stays an Aura")
	assert_eq(licid.attached_to, bear.id)
	assert_false(licid.tapped, "it untapped in its controller's untap step")


func test_humility_keeps_a_creature_licid_from_activating() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _humility())
	g.recalculate()
	assert_refused(_activate(licid, bear), "no such ability")
	assert_false(licid.tapped)


func test_humility_does_not_touch_a_licid_that_is_an_aura() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	put_synthetic(1, _humility())
	g.recalculate()
	assert_false(licid.cur_abilities_silenced, "an Aura is not a creature")
	assert_eq(licid.cur_power, 2, "and has no base 1/1 imposed")
	# Ended, it is a creature under Humility at once.
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(0, licid))
	assert_true(licid.is_creature())
	assert_true(licid.cur_abilities_silenced)
	assert_true(licid.cur_activated_abilities.is_empty())


# ----------------------------------------------------- control and copies --

func test_a_dominating_licid_steals_its_host_and_gives_it_back_when_ended() -> void:
	var licid := put_synthetic(0, _dominating())
	var giant := put_battlefield(1, "Hill Giant")
	_attach(licid, giant, 0, Mtg.ManaColor.U)
	assert_true(licid.data.aura_steals)
	assert_eq(giant.controller_id, 0, "you control enchanted creature")
	assert_true(g.players[0].battlefield.has(giant))
	assert_true(giant.summoning_sick, "a new controller: sick (CR 302.6)")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.end_licid_effect(0, licid))
	assert_eq(giant.controller_id, 1, "the steal ends with the effect")
	assert_true(licid.is_creature())
	assert_eq(licid.controller_id, 0)


func test_a_dominating_licid_changing_hands_takes_the_stolen_creature_along() -> void:
	var licid := put_synthetic(0, _dominating())
	var giant := put_battlefield(1, "Hill Giant")
	_attach(licid, giant, 0, Mtg.ManaColor.U)
	g.change_control(licid, 1)
	g.recalculate()
	assert_eq(licid.controller_id, 1)
	assert_eq(giant.controller_id, 1, "the Aura's controller controls its host")


func test_the_licids_controller_may_end_the_effect_after_a_control_change() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_attach(licid, bear)
	g.change_control(licid, 1)
	g.recalculate()
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.end_licid_effect(0, licid), "not yours")
	assert_true(g.is_licid_aura(licid))
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(1, licid))
	assert_true(licid.is_creature())
	assert_eq(licid.controller_id, 1)


func test_control_magic_falls_off_a_stolen_licid_that_becomes_an_aura() -> void:
	# The thief activates the licid it took; the licid stops being a
	# creature, Control Magic can no longer enchant it (CR 704.5m) and the
	# licid returns to its owner — who now controls the Aura (and may end
	# its effect).
	var licid := put_synthetic(0, _licid())
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var magic := give_hand(1, "Control Magic")
	add_mana(1, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(1, magic, [TargetRef.card(licid)]))
	resolve_stack()
	assert_eq(licid.controller_id, 1)
	advance_to_next_turn()
	advance_to_next_turn()   # the thief's next turn: the licid is no longer sick
	assert_eq(g.active_player, 1)
	var orc := put_battlefield(1, "Grizzly Bears")
	_attach(licid, orc, 1)
	assert_eq(magic.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(licid.controller_id, 0, "back to its owner")
	assert_eq(licid.attached_to, orc.id)
	assert_true(orc.has_keyword(Mtg.Keyword.HASTE))


func test_a_copy_of_a_licid_reverts_to_the_copy_not_to_its_own_card() -> void:
	# A Clone-like permanent that is a copy of a licid: the Aura half is
	# derived from what it IS (the copy), and ending the effect returns it
	# to that copy (CR 707.2), not to its printed card.
	var clone := put_battlefield(0, "Grizzly Bears")
	var copied := _licid("Synthetic Copied Licid")
	g.become_copy(clone, copied)
	var host := put_battlefield(0, "Hill Giant")
	_attach(clone, host)
	assert_true(g.is_licid_aura(clone))
	assert_eq(clone.data.licid_base, copied)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(0, clone))
	assert_eq(clone.data, copied)
	assert_true(clone.is_creature())
	assert_eq(clone.cur_activated_abilities.size(), 1)


func test_two_activations_make_two_effects_and_each_must_be_ended() -> void:
	# Untapped in response, the licid is activated twice. The later one
	# resolves first (onto the bear), the earlier one moves it onto the
	# giant; two "become an Aura" effects now apply, and it is a creature
	# again only once both are ended (CR 116.2c, 613.1d).
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	assert_ok(_activate(licid, giant))
	g.untap_permanent(licid)
	assert_ok(_activate(licid, bear))
	resolve_stack()
	assert_true(g.is_licid_aura(licid))
	assert_eq(licid.attached_to, giant.id)
	assert_true(bear.attachments.is_empty())
	assert_true(giant.attachments.has(licid.id))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(0, licid))
	assert_true(g.is_licid_aura(licid), "one effect is left")
	assert_eq(licid.attached_to, giant.id)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.end_licid_effect(0, licid))
	assert_true(licid.is_creature())
	assert_eq(licid.attached_to, -1)


# ------------------------------------------------------- rules presets --

func test_the_licid_works_the_same_under_both_presets() -> void:
	for preset in ["fifth", "modern"]:
		before_each()
		g.rules.set_preset(preset)
		var licid := put_synthetic(0, _licid())
		var bear := put_battlefield(0, "Grizzly Bears", true)
		assert_ne(CombatState.attack_illegality(g, bear, 1), "", "%s: a sick bear stays home" % preset)
		_attach(licid, bear)
		assert_true(bear.has_keyword(Mtg.Keyword.HASTE), preset)
		assert_eq(CombatState.attack_illegality(g, bear, 1), "", "%s: haste lets it attack" % preset)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.end_licid_effect(0, licid))
		assert_true(licid.is_creature(), preset)
		assert_false(licid.summoning_sick, "%s: no zone change, no sickness" % preset)


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


func _resolve_all() -> void:
	while not g.stack.is_empty():
		g._resolve_top()
	g.check_state_based_actions()


func test_the_pre_flight_probe_of_a_human_seat_leaves_no_trace() -> void:
	# A seat that wants to be asked makes every resolution run once over a
	# GameSnapshot first (docs/duel-todo.md §1.3). The swap must be rewound
	# with it: one effect, not two, once the real resolution has run.
	g.agents[0] = HumanAgent.new()
	g.agents[1] = HumanAgent.new()
	g.interactive_choices = true
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_activate(licid, bear))
	resolve_stack()
	assert_null(g.awaiting_choice)
	assert_true(g.is_licid_aura(licid))
	assert_eq(int(licid.memory.get("licid_effects", 0)), 1)
	assert_eq(bear.attachments.size(), 1)


func test_becoming_an_aura_and_ending_it_round_trip_field_exact() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	_round_trips(func() -> void:
		assert_ok(_activate(licid, bear))
		_resolve_all(), "the activation")
	assert_true(licid.is_creature())
	_round_trips(func() -> void:
		g.become_licid_aura(licid, bear)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.end_licid_effect(0, licid)), "become and end")
	var dom := put_synthetic(0, _dominating())
	var giant := put_battlefield(1, "Hill Giant")
	_round_trips(func() -> void:
		g.become_licid_aura(dom, giant)
		g.destroy(giant)
		g.check_state_based_actions(), "a steal, then the host dies")
	assert_eq(giant.controller_id, 1)
	assert_true(dom.is_creature())
