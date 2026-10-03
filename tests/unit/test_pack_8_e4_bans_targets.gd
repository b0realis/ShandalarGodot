extends GameTest
## Pack 8 engine package E4 — ACTIVATION / PLAY / TARGET BANS and
## "BECOMES THE TARGET".
##
## - N_activation_ban: "Activated abilities of artifacts can't be
##   activated" (Null Rod), "... of creatures" (Cursed Totem), "creatures
##   with flying ... their activated abilities with {T} in their costs"
##   (Katabatic Winds), "players can cast spells and activate abilities
##   only during their own turns" (City of Solitude) — static bans radiated
##   by CardData.bans_activations — and Abeyance's floating "can't activate
##   abilities that aren't mana abilities" (MtgGame.add_floating_activation_ban).
##   MANA ABILITIES ARE ACTIVATED ABILITIES (CR 605.1a): the ban reaches
##   tap_for_mana, ManaPlanner.sources (so no auto-pay plan, human or AI,
##   counts a Mox under a Null Rod) and try_pay.
## - N_floating_play_ban: Solfatara's "can't play lands this turn",
##   Abeyance's "can't cast instant or sorcery spells" (until end of turn,
##   MtgGame.add_floating_play_ban, read by play_banned like the statics).
## - N_target_ban_players: MtgPlayer.cur_target_bans, the player twin of
##   CardInstance.cur_target_bans (Peace Talks), and
##   MtgGame.targeting_kind to tell spells and activated abilities from
##   triggered ones.
## - N_became_target: Mtg.EventType.BECAME_TARGET as a spell, ability or
##   trigger is put on the stack (Skulking Ghost, Tar Pit Warrior,
##   Forsaken Wastes) — once per object per stack item, final targets of a
##   copy only, and the new target of a redirection.


# ------------------------------------------------------------- synthetics --

static func _bans_artifacts(_g: MtgGame, _s: CardInstance, _pid: int, inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


static func _bans_creatures(_g: MtgGame, _s: CardInstance, _pid: int, inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return inst.is_creature()


static func _bans_flier_taps(_g: MtgGame, _s: CardInstance, _pid: int, inst: CardInstance,
		ability: Variant, _is_mana: bool) -> bool:
	return inst.is_creature() and inst.has_keyword(Mtg.Keyword.FLYING) \
		and MtgGame.ability_has_tap_cost(ability)


static func _bans_off_turn(g: MtgGame, _s: CardInstance, pid: int, _inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return pid != g.active_player


func _rod() -> CardData:
	return CardData.new("Test Rod", "{2}", Mtg.CardType.ARTIFACT).bans_activations(_bans_artifacts)


func _totem() -> CardData:
	return CardData.new("Test Totem", "{2}", Mtg.CardType.ARTIFACT).bans_activations(_bans_creatures)


func _mox() -> CardData:
	return CardData.new("Test Mox", "{0}", Mtg.CardType.ARTIFACT).mana(ManaAbility.new(Mtg.ManaColor.G))


func _elf() -> CardData:
	return CardData.new("Test Elf", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.mana(ManaAbility.new(Mtg.ManaColor.G))


## "{T}: deal 1 damage to any target" on a creature or an artifact.
func _pinger(types := Mtg.CardType.CREATURE, flying := false) -> CardData:
	var data := CardData.new("Test Pinger", "{1}", types)
	if types & Mtg.CardType.CREATURE:
		data.pt(1, 1)
	if flying:
		data.with_keywords([Mtg.Keyword.FLYING])
	return data.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()], "{T}: 1 damage to any target."))


## "{1}: +1/+0 until end of turn" — no {T}.
func _firebreather(flying := false) -> CardData:
	var data := CardData.new("Test Breather", "{R}", Mtg.CardType.CREATURE).pt(1, 1)
	if flying:
		data.with_keywords([Mtg.Keyword.FLYING])
	return data.activated(ActivatedAbility.new("{1}", false, [PumpEffect.new(1, 0).self_buff()], "{1}: +1/+0."))


func _shock() -> CardData:
	return CardData.new("Test Shock", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target())


func _bear(card_name := "Test Bear") -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


# ---------------------------------------------------------- activation bans --

func test_null_rod_stops_an_artifacts_activated_ability() -> void:
	var pinger := put_synthetic(0, _pinger(Mtg.CardType.ARTIFACT))
	put_synthetic(1, _rod())
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]), "Test Rod")
	assert_ne(g.ability_timing_refusal(0, pinger, pinger.cur_activated_abilities[0]), "",
		"the AI's and the duel screen's reading refuses it too")
	assert_eq(g.players[1].life, 20)


func test_null_rod_stops_a_mox_everywhere_mana_is_planned() -> void:
	var mox := put_synthetic(0, _mox())
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.can_afford_cost(0, ManaCost.parse("{G}")), "the control: the Mox pays")
	var rod := put_synthetic(1, _rod())
	assert_refused(g.tap_for_mana(0, mox), "Test Rod")
	assert_false(mox.tapped)
	for s in ManaPlanner.sources(g, 0):
		assert_ne(s[0], mox, "no plan counts a banned source")
	assert_false(g.can_afford_cost(0, ManaCost.parse("{G}")))
	assert_false(g.try_pay(0, ManaCost.parse("{G}")))
	assert_false(mox.tapped, "nothing was tapped for a refused payment")
	var forest := put_battlefield(0, "Forest")
	assert_true(g.try_pay(0, ManaCost.parse("{G}")), "a land is not an artifact")
	assert_true(forest.tapped)
	# The ban is the Rod's while it is on the battlefield (live, CR 400.7).
	g.destroy(rod)
	assert_ok(g.tap_for_mana(0, mox))


func test_cursed_totem_stops_creatures_mana_and_activated_abilities() -> void:
	var elf := put_synthetic(0, _elf())
	var pinger := put_synthetic(0, _pinger())
	var mox := put_synthetic(0, _mox())
	put_synthetic(1, _totem())
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, elf), "Test Totem")
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]), "Test Totem")
	assert_ok(g.tap_for_mana(0, mox))
	# An artifact that BECOMES a creature is caught (live types).
	var mox2 := put_synthetic(0, _mox())
	g.continuous.add_until_eot_animation(mox2.id, Mtg.CardType.CREATURE, 2, 2)
	g.recalculate()
	assert_refused(g.tap_for_mana(0, mox2), "Test Totem")


func test_katabatic_style_ban_reads_flying_and_the_tap_symbol() -> void:
	put_synthetic(1, CardData.new("Test Winds", "{2}{G}", Mtg.CardType.ENCHANTMENT) \
		.bans_activations(_bans_flier_taps))
	var flier := put_synthetic(0, _pinger(Mtg.CardType.CREATURE, true))
	var walker := put_synthetic(0, _pinger())
	var breather := put_synthetic(0, _firebreather(true))
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, flier, 0, [TargetRef.player(1)]), "Test Winds")
	assert_ok(g.activate_ability(0, walker, 0, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, breather, 0))   # no {T} in its cost


func test_city_of_solitude_style_ban_reaches_mana_abilities_in_the_other_turn() -> void:
	put_synthetic(0, CardData.new("Test City", "{2}{G}", Mtg.CardType.ENCHANTMENT) \
		.bans_activations(_bans_off_turn) \
		.bans_playing(func(game: MtgGame, pid: int, _d: CardData) -> bool: return pid != game.active_player))
	var forest := put_battlefield(1, "Forest")
	var pinger := put_synthetic(1, _pinger())
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.pass_priority(0))
	assert_refused(g.tap_for_mana(1, forest), "Test City")
	assert_refused(g.activate_ability(1, pinger, 0, [TargetRef.player(0)]), "Test City")
	var shock := give_synthetic(1, _shock())
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, shock, [TargetRef.player(0)]), "Test City")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.tap_for_mana(1, forest))   # on its own turn the seat is free


func test_a_floating_activation_ban_spares_mana_abilities_and_ends_at_cleanup() -> void:
	var pinger := put_synthetic(1, _pinger())
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.UPKEEP)
	g.add_floating_activation_ban(1, func(_g: MtgGame, _pid: int, _i: CardInstance,
			_a: Variant, is_mana: bool) -> bool: return not is_mana, "Test Abeyance")
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, pinger, 0, [TargetRef.player(0)]), "Test Abeyance")
	assert_ok(g.tap_for_mana(1, forest))   # mana abilities are spared
	advance_to_next_turn()
	assert_eq(g.floating_activation_bans.size(), 0, "until end of turn")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(1, pinger, 0, [TargetRef.player(0)]))


func test_activation_bans_are_journaled() -> void:
	g.undo_log = UndoLog.new()
	var mark := g.make_mark()
	g.add_floating_activation_ban(0, func(_g: MtgGame, _p: int, _i: CardInstance,
			_a: Variant, _m: bool) -> bool: return true, "x")
	g.add_floating_play_ban(0, func(_g: MtgGame, _p: int, _d: CardData) -> bool: return true, "y")
	g.unmake_to(mark)
	assert_eq(g.floating_activation_bans.size(), 0)
	assert_eq(g.floating_play_bans.size(), 0)


# ------------------------------------------------------- floating play bans --

func test_solfatara_style_land_ban_lasts_this_turn() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	g.add_floating_play_ban(0, func(_g: MtgGame, _pid: int, d: CardData) -> bool: return d.is_land(),
		"Test Solfatara")
	var forest := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.play_land(0, forest), "Test Solfatara")
	assert_ne(g.play_banned(0, forest.data), "", "the AI's reading")
	assert_eq(g.play_banned(1, forest.data), "", "only the target player")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.play_land(0, forest))


func test_abeyance_style_spell_ban_spares_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.add_floating_play_ban(0, func(_g: MtgGame, _pid: int, d: CardData) -> bool:
		return d.is_type(Mtg.CardType.INSTANT) or d.is_type(Mtg.CardType.SORCERY), "Test Abeyance")
	var shock := give_synthetic(0, _shock())
	var bear := give_synthetic(0, _bear())
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, shock, [TargetRef.player(1)]), "Test Abeyance")
	assert_ne(g.cast_timing_refusal(0, shock), "")
	assert_ok(g.cast_spell(0, bear))


# ------------------------------------------------------ player target bans --

static func _not_trigger(game: MtgGame, source: CardInstance, spec: TargetSpec) -> bool:
	return game.targeting_kind(source, spec) != Mtg.StackKind.TRIGGER


static func _peace(game: MtgGame, _source: CardInstance) -> void:
	for p in game.players:
		p.cur_target_bans.append({"filter": _not_trigger})
	for inst in game.all_battlefield():
		inst.cur_target_bans.append({"filter": _not_trigger})


static func _ping_target(game: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	for ref in game.current_targets():
		game.deal_damage(source, ref, 1)


func test_players_can_be_shielded_from_spells_and_activated_abilities_not_triggers() -> void:
	put_synthetic(1, CardData.new("Test Peace", "{1}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_peace, "Players and permanents can't be targeted.")))
	var pinger := put_synthetic(0, _pinger())
	var bear := put_synthetic(1, _bear())
	var trig := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _ping_target,
		"At the beginning of your upkeep, deal 1 damage to target player.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.controller_id) \
		.targeting(TargetSpec.player())
	put_synthetic(0, CardData.new("Test Pinging Totem", "{3}", Mtg.CardType.ARTIFACT).triggered(trig))
	advance_to_next_turn()
	advance_to_next_turn()   # P0's next upkeep fired its trigger at a player
	assert_eq(g.players[0].life + g.players[1].life, 39, "a triggered ability may still target a player")
	var shock := give_synthetic(0, _shock())
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, shock, [TargetRef.player(1)]))
	assert_refused(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]))
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.card(bear)]))
	assert_eq(g.targeting_kind(shock, shock.data.spell_effects[0].target_spec), Mtg.StackKind.SPELL)
	assert_eq(g.targeting_kind(pinger, pinger.cur_activated_abilities[0].effects[0].target_spec),
		Mtg.StackKind.ABILITY)


# --------------------------------------------------- becomes the target --

static func _is_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


static func _sacrifice_me(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if s.zone == Mtg.Zone.BATTLEFIELD:
		g.sacrifice_permanent(s)


func _tar_pit() -> CardData:
	return CardData.new("Test Tar Pit", "{2}{B}", Mtg.CardType.CREATURE).pt(3, 4) \
		.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _sacrifice_me,
			"When this creature becomes the target of a spell or ability, sacrifice it.", _is_me))


var _seen: Array = []


func before_each() -> void:
	super()
	_seen = []


func _record(event: GameEvent) -> void:
	if event.type == Mtg.EventType.BECAME_TARGET:
		_seen.append(event.data.duplicate())


func test_a_spell_makes_its_target_become_the_target_once() -> void:
	var pit := put_synthetic(1, _tar_pit())
	g.event_occurred.connect(_record)
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(pit)]))
	assert_eq(_seen.size(), 1)
	assert_eq(_seen[0].get("instance"), pit)
	assert_eq(int(_seen[0].get("kind")), Mtg.StackKind.SPELL)
	assert_eq(int(_seen[0].get("controller")), 0)
	assert_eq(g.stack.size(), 2, "the sacrifice trigger sits ABOVE the spell")
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].graveyard.has(pit), true)


func test_an_activated_ability_and_a_trigger_make_their_targets_become_the_target() -> void:
	var pit := put_synthetic(1, _tar_pit())
	var pinger := put_synthetic(0, _pinger())
	g.event_occurred.connect(_record)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pinger, 0, [TargetRef.card(pit)]))
	assert_eq(_seen.size(), 1)
	assert_eq(int(_seen[0].get("kind")), Mtg.StackKind.ABILITY)
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.GRAVEYARD)
	var pit2 := put_synthetic(1, _tar_pit())
	var trig := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _ping_target,
		"At the beginning of your upkeep, deal 1 damage to target creature an opponent controls.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.controller_id) \
		.targeting(TargetSpec.creature("target creature an opponent controls").with_game_filter(
			func(_g: MtgGame, i: CardInstance) -> bool: return i.controller_id == 1))
	put_synthetic(0, CardData.new("Test Upkeep Pinger", "{3}", Mtg.CardType.ARTIFACT).triggered(trig))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(pit2.zone, Mtg.Zone.GRAVEYARD, "a triggered ability targets too")
	assert_eq(int(_seen[-1].get("kind")), Mtg.StackKind.TRIGGER)


func test_untargeted_effects_and_players_do_not_trigger_it() -> void:
	var pit := put_synthetic(1, _tar_pit())
	g.event_occurred.connect(_record)
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.player(1)]))
	assert_eq(_seen.size(), 1)
	assert_eq(int(_seen[0].get("player")), 1, "a PLAYER becomes the target too")
	assert_eq(_seen[0].get("instance"), null)
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.BATTLEFIELD)


func test_a_copy_announces_only_its_final_targets() -> void:
	var pit := put_synthetic(1, _tar_pit())
	var bear := put_synthetic(1, _bear())
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	g.event_occurred.connect(_record)
	# A copy aimed at the bear first, then re-aimed at the Tar Pit — the
	# copy is put on the stack with its FINAL targets (CR 707.10c).
	var copy := g.copy_spell_on_stack(shock, 0)
	var item := g.find_stack_item(copy)
	item.targets[0] = TargetRef.card(pit)
	item.target_groups[0][0] = item.targets[0]
	g._resume_priority(0)
	assert_eq(_seen.size(), 1)
	assert_eq(_seen[0].get("instance"), pit, "the bear was never the copy's target")
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.GRAVEYARD)


func test_a_redirected_spell_makes_its_new_target_become_the_target() -> void:
	var pit := put_synthetic(1, _tar_pit())
	var bear := put_synthetic(1, _bear())
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	g.event_occurred.connect(_record)
	assert_true(g.retarget_spell(shock, 0, TargetRef.card(pit)))
	assert_eq(_seen.size(), 1)
	assert_eq(_seen[0].get("instance"), pit)
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.damage, 0)


static func _spell_only(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and bool(e.data.get("is_spell", false))


static func _drain(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	g.adjust_life(int(e.data.controller), -5)


func test_becomes_the_target_of_a_spell_ignores_abilities() -> void:
	var wastes := put_synthetic(1, CardData.new("Test Wastes", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _drain,
			"Whenever this becomes the target of a spell, that spell's controller loses 5 life.", _spell_only)))
	var pinger := put_synthetic(0, CardData.new("Test Disenchanter", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", true, [DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))], "{T}: destroy target permanent.")))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pinger, 0, [TargetRef.card(wastes)]))
	assert_eq(g.stack.size(), 1, "an ability does not trigger it")
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	var wastes2 := put_synthetic(1, CardData.new("Test Wastes", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _drain,
			"Whenever this becomes the target of a spell, that spell's controller loses 5 life.", _spell_only)))
	var shock := give_synthetic(0, CardData.new("Test Naturalize", "{G}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(wastes2)]))
	resolve_stack()
	assert_eq(g.players[0].life, 15, "the spell's controller lost 5")
	assert_eq(wastes2.zone, Mtg.Zone.GRAVEYARD)


func test_a_failed_cast_announces_nothing() -> void:
	var pit := put_synthetic(1, _tar_pit())
	g.event_occurred.connect(_record)
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	assert_refused(g.cast_spell(0, shock, [TargetRef.card(pit)]), "mana")
	assert_eq(_seen.size(), 0)
	assert_eq(pit.zone, Mtg.Zone.BATTLEFIELD)


static func _pit_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var a_pit := g.find_instance(a.instance_id).data.card_name == "Test Tar Pit"
	var b_pit := g.find_instance(b.instance_id).data.card_name == "Test Tar Pit"
	if a_pit != b_pit:
		return a_pit
	return a.instance_id < b.instance_id


static func _entered_self(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


func _etb_pinger() -> CardData:
	return CardData.new("Test Arrival", "{3}", Mtg.CardType.ARTIFACT).triggered(
		TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _ping_target,
			"When this enters, it deals 1 damage to target creature.", _entered_self) \
			.targeting(TargetSpec.creature(), _pit_first, "Select a creature."))


func test_a_human_held_trigger_announces_only_the_target_finally_named() -> void:
	# The provisional pick (the Tar Pit, ranked first) is not a target:
	# only the creature the human actually names becomes the target.
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var pit := put_synthetic(1, _tar_pit())
	var bear := put_synthetic(1, _bear())
	g.event_occurred.connect(_record)
	put_synthetic(0, _etb_pinger())
	assert_true(g.stack.back().target_held)
	g._open_priority()
	assert_not_null(g.awaiting_choice)
	assert_eq(_seen.size(), 0, "nothing became the target while the human was asked")
	assert_ok(g.answer_choice("Test Bear"))
	assert_eq(_seen.size(), 1)
	assert_eq(_seen[0].get("instance"), bear)
	assert_eq(int(_seen[0].get("kind")), Mtg.StackKind.TRIGGER)
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.BATTLEFIELD, "the Tar Pit was never targeted")
	assert_eq(bear.damage, 1)


func test_the_ai_seat_s_trigger_target_becomes_the_target_at_priority() -> void:
	var pit := put_synthetic(1, _tar_pit())
	put_synthetic(1, _bear())
	g.event_occurred.connect(_record)
	put_synthetic(0, _etb_pinger())
	assert_eq(_seen.size(), 0, "announced as a player would receive priority (CR 603.3)")
	g._open_priority()
	assert_eq(_seen.size(), 1)
	assert_eq(_seen[0].get("instance"), pit)
	assert_eq(g.stack.size(), 2, "the sacrifice trigger sits above the ping")
	resolve_stack()
	assert_eq(pit.zone, Mtg.Zone.GRAVEYARD)


func test_a_ban_radiated_by_a_permanent_that_changed_control_still_applies() -> void:
	# "Activated abilities of artifacts can't be activated" binds every
	# player, whoever controls the Rod.
	var mox := put_synthetic(0, _mox())
	var rod := put_synthetic(1, _rod())
	g.change_control(rod, 0)
	assert_eq(rod.controller_id, 0)
	assert_refused(g.tap_for_mana(0, mox), "Test Rod")
	var their_mox := put_synthetic(1, _mox())
	assert_refused(g.tap_for_mana(1, their_mox), "Test Rod")


func test_two_stacked_activations_are_each_refused_under_the_ban() -> void:
	var pinger := put_synthetic(0, _pinger(Mtg.CardType.ARTIFACT))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]))
	# The Rod arrives with the first activation on the stack: the activated
	# ability already on the stack resolves (a ban stops ACTIVATING), a
	# second activation is refused.
	put_synthetic(1, _rod())
	g.untap_permanent(pinger)
	assert_refused(g.activate_ability(0, pinger, 0, [TargetRef.player(1)]), "Test Rod")
	resolve_stack()
	assert_eq(g.players[1].life, 19)
