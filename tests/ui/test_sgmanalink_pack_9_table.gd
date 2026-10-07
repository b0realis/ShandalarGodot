extends GameTest
## PACK 9 — THE TEMPEST BLOCK AT AN SGMANALINK TABLE (protocol 28), each
## pinned through the referee (`SgPracticeMatch`), the wire validator
## (`SgViewProtocol`), the client's projection and its duel screen, on
## SYNTHETIC cards (the engine notes' shapes):
##
##  * the version and the rules revision a mismatched build is named by;
##  * three combat flags cross — a block requirement each combat or this
##    turn, "blocks shadow" — and the defender's screen lights a blocker
##    under orders; Magnetic Web's companions cross as rows and light;
##  * a licid's end and Volrath's Curse's ignore are SPECIAL ACTIONS the
##    referee lists (usable only) with the card each belongs to, the
##    client's card menu sends them as a message, and the ignore's
##    sacrifice is the seat's own held cost question (answer or cancel);
##  * a buyback row and a row Dream Halls grants are payment rows the Cast
##    action carries, priced and opened by the referee, cast through it;
##  * Reap's count crosses per candidate opponent and the client narrows
##    the slot to the one picked; a trigger is a "spell or ability"
##    target, named and tokenised, and the client's chain click names it.

var referee: SgPracticeMatch


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null


# ---------------------------------------------------------------- fixture --

var _revision := 1


func _room(seat := 0) -> Dictionary:
	_revision += 1
	return {"id": "r1", "name": "Pack nine", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": _revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(seat), true, false)
	return screen


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


func _row(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


func _cast_option(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for face in view.hand:
		if face.id != handle: continue
		for option in face.actions:
			if option.kind == "spell": return option
	return {}


func _window(active: int, step: int) -> void:
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false


static func _item(menu: PopupMenu, prefix: String) -> int:
	for i in menu.get_item_count():
		if menu.get_item_text(i).begins_with(prefix):
			return menu.get_item_id(i)
	return -1


# ------------------------------------------------------- synthetic cards --

static func _bear(card_name := "Test Bear") -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _watchdog() -> CardData:
	return CardData.new("Test Watchdog", "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 2).static_ability(CombatState.blocks_each_combat()) \
		.oracle("This creature blocks each combat if able.")


static func _dryad() -> CardData:
	return CardData.new("Test Dryad", "{1}{G}", Mtg.CardType.CREATURE).pt(1, 2) \
		.static_ability(CombatState.blocks_shadow())


static func _web() -> CardData:
	return CardData.new("Test Web", "{2}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_web_attack, "If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able."))


static func _web_attack(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and int(inst.counters.get("magnet", 0)) > 0:
			CombatState.add_attack_requirement(inst, source, _magnet_attacks,
				"a creature with a magnet counter on it attacks")


static func _magnet_attacks(_game: MtgGame, declared: Array) -> bool:
	for inst in declared:
		if int((inst as CardInstance).counters.get("magnet", 0)) > 0:
			return true
	return false


static func _licid() -> CardData:
	return CardData.new("Test Licid", "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{R}", "{R}")


static func _curse() -> CardData:
	return CardData.new("Test Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_curse_host, "Enchanted creature can't attack or block.")) \
		.ignorable_by_sacrifice("permanent")


static func _curse_host(game: MtgGame, s: CardInstance) -> void:
	var h := game.find_instance(s.attached_to)
	if not game.is_present(h) or game.effect_ignored_by(s, h.controller_id):
		return
	h.cur_cant_attack = true


static func _capsize() -> CardData:
	return CardData.new("Test Capsize", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)).with_buyback({"mana": "{3}"})


const OC := preload("res://engine/additional_object_costs.gd")


static func _halls() -> CardData:
	return CardData.new("Test Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_halls_rows)


static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance, _src: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it", "object_costs": [group]}]


static func _insight() -> CardData:
	return CardData.new("Test Insight", "{2}{U}", Mtg.CardType.SORCERY).spell(DrawEffect.new(1))


class OpponentSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass


static func _black_permanents(game: MtgGame, _source: CardInstance, earlier: Array) -> Vector2i:
	if earlier.is_empty() or not (earlier[0] as TargetRef).is_player:
		return Vector2i(0, 0)
	var n := 0
	for perm in game.players[(earlier[0] as TargetRef).player_id].battlefield:
		if (perm.cur_colors & Mtg.ManaColor.B) != 0:
			n += 1
	return Vector2i(0, n)


static func _reap() -> CardData:
	var cards := ReturnFromGraveyardEffect.new().any_card()
	cards.targets_counted_by(_black_permanents)
	return CardData.new("Test Reap", "{1}{G}", Mtg.CardType.INSTANT) \
		.spell(OpponentSlot.new()).spell(cards)


class AimAtStackEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell_or_ability("target spell or ability")

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass


static func _wyvern() -> CardData:
	return CardData.new("Test Wyvern", "{3}{U}{U}", Mtg.CardType.CREATURE).pt(4, 4) \
		.activated(ActivatedAbility.new("", false, [AimAtStackEffect.new()],
			"Do nothing to target spell or ability."))


static func _herald() -> CardData:
	return CardData.new("Test Herald", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _nothing,
			"When this creature enters, nothing happens.", _herald_entered))


static func _nothing(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass


static func _herald_entered(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


# ===================================================== the version stamp --

func test_protocol_28_and_the_tempest_rules_revision() -> void:
	# Pack 9's additions travel since protocol 28 (the exact version and
	# rules revision are pinned by the latest bump's own test: 29 and the
	# whole-game campaign's, tests/ui/test_campaign_fix_net_table.gd).
	assert_true(SgProtocol.VERSION >= 28)
	assert_ne(SgCompatibility.RULES_REVISION, "sgmanalink-mirage-bugpass-2026-10-04")
	assert_true(SgCompatibility.valid_stamp(SgCompatibility.stamp()), "the stamp's rules text fits the wire")
	assert_true(SgProtocol.subprotocols().has("sgmanalink-local-v27"),
		"an earlier protocol is still named, so a 27 build is told, not hung up on")


# ======================================================= combat on the wire --

func test_the_combat_flags_cross_and_validate() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dog := put_synthetic(0, _watchdog())
	var dryad := put_synthetic(0, _dryad())
	var bear := put_synthetic(0, _bear())
	g.require_block_this_turn(bear)
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "protocol 28's view validates")
	assert_true(_row(view, dog).flags.cur_must_block)
	assert_true(_row(view, dryad).flags.cur_blocks_shadow)
	assert_true(_row(view, bear).flags.must_block_this_turn_any)
	assert_false(_row(view, dog).flags.cur_blocks_shadow, "control")
	var screen := _screen()
	await _pump()
	assert_true(_local(screen, dog).cur_must_block, "the client's card wears it")
	assert_true(_local(screen, dryad).cur_blocks_shadow)


## Seat 1 attacks with [param attackers]; play stops at seat 0's blocks.
func _attack_into_blocks(attackers: Array) -> void:
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	g._probing = false
	var ids: Array = []
	for card: CardInstance in attackers: ids.append(card.id)
	assert_eq(g.declare_attackers(1, ids), "")
	for _i in 10:
		if g.awaiting_blockers: break
		g.pass_priority(g.priority_player)
	assert_true(g.awaiting_blockers, "control: seat 0 declares blockers")


func test_the_defenders_screen_lights_a_blocker_under_orders() -> void:
	var dog := put_synthetic(0, _watchdog())
	var bear := put_synthetic(0, _bear())
	var raider := put_synthetic(1, _bear("Test Raider"))
	_attack_into_blocks([raider])
	var screen := _screen()
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
	assert_eq(screen._highlight_for(_local(screen, dog)), MiniCard.Highlight.MANDATORY)
	assert_eq(screen._highlight_for(_local(screen, bear)), MiniCard.Highlight.NONE, "control")
	assert_refused(referee.act(0, {"op": "block", "pairs": []}), "blocks each combat if able")


func test_magnetic_web_companions_cross_as_rows() -> void:
	put_synthetic(0, _web())
	var a := put_synthetic(0, _bear("Test Magnet A"))
	var b := put_synthetic(0, _bear("Test Magnet B"))
	var c := put_synthetic(0, _bear("Test Plain"))
	a.counters["magnet"] = 1
	b.counters["magnet"] = 1
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	g.recalculate()
	assert_true(g.awaiting_attackers, "control: seat 0 declares attackers")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	var rows := {}
	for row in view.presentation.attack_companions: rows[row[0]] = row[1]
	assert_eq(rows.get(referee._handle(0, a), []), [referee._handle(0, b)], "A drags B")
	assert_eq(rows.get(referee._handle(0, b), []), [referee._handle(0, a)], "and B drags A")
	assert_false(rows.has(referee._handle(0, c)), "a plain creature drags nobody")
	assert_eq(referee.view(1).presentation.attack_companions, [], "the defender is sent none")
	var screen := _screen()
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	screen._selected_attackers.append(_local(screen, a).id)
	assert_eq(screen._highlight_for(_local(screen, b)), MiniCard.Highlight.MANDATORY)
	assert_eq(screen._highlight_for(_local(screen, c)), MiniCard.Highlight.OPTIONAL)


func test_no_predicate_requirement_sends_no_rows() -> void:
	put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(referee.view(0).presentation.attack_companions, [])


# ===================================================== special actions --

func _attached_licid() -> CardInstance:
	advance_to_step(Mtg.Step.MAIN1)
	var licid := put_synthetic(0, _licid())
	var bear := put_synthetic(0, _bear())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.is_licid_aura(licid))
	g.priority_player = 0
	return licid


func _special_index(view: Dictionary, prefix: String) -> int:
	for i in view.specials.size():
		if String(view.specials[i]).begins_with(prefix): return i
	return -1


func test_a_licid_end_is_listed_only_when_it_can_be_taken() -> void:
	var licid := _attached_licid()
	assert_eq(_special_index(referee.view(0), "Pay {R}: end Test Licid's effect"), -1,
		"no red mana: not on offer (usable only)")
	put_battlefield(0, "Mountain")
	var view := referee.view(0)
	var at := _special_index(view, "Pay {R}: end Test Licid's effect")
	assert_ne(at, -1, "a Mountain to pay with: listed")
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.presentation.special_rows[at], ["licid_end", referee._handle(0, licid)],
		"its row names the licid")
	assert_ok(referee.act(0, {"op": "special", "index": at}))
	assert_false(g.is_licid_aura(licid), "ended at the referee")
	assert_eq(g.priority_player, 0, "the seat keeps priority")


func test_the_clients_licid_menu_sends_the_special_action() -> void:
	var licid := _attached_licid()
	put_battlefield(0, "Mountain")
	var screen := _screen()
	var sent: Array = []
	screen.action_requested.connect(func(action: Dictionary) -> void: sent.append(action.duplicate(true)))
	await _pump()
	var local := _local(screen, licid)
	assert_not_null(local)
	screen._open_card_menu(local, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := _item(menu, "Pay {R}: end Test Licid's effect")
	assert_ne(id, -1, "the licid's own menu offers the end at a network table")
	assert_false(menu.is_item_disabled(menu.get_item_index(id)))
	menu.hide()
	screen._on_card_menu_chosen(id)
	assert_eq(sent.size(), 1, "one message, nothing acted on the projection")
	if sent.is_empty(): return
	assert_eq(String(sent[0].op), "special")
	assert_ok(referee.act(0, sent[0]))
	assert_false(g.is_licid_aura(licid))


func _cursed() -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var curse := give_synthetic(1, _curse())
	var bear := put_synthetic(0, _bear())
	g.priority_player = 1
	g.attach_aura_from_anywhere(curse, bear, 1)
	g.priority_player = 0
	return [curse, bear]


func test_a_curse_ignore_is_a_held_choice_at_the_table() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var forest := put_battlefield(0, "Forest")
	var view := referee.view(0)
	var at := _special_index(view, "Sacrifice a permanent: ignore Test Curse this turn")
	assert_ne(at, -1)
	assert_eq(view.presentation.special_rows[at], ["ignore_effect", referee._handle(0, curse)])
	assert_eq(_special_index(referee.view(1), "Sacrifice a permanent"), -1, "not the caster's")
	assert_ok(referee.act(0, {"op": "special", "index": at}))
	var asked := referee.view(0)
	assert_eq(asked.mode, "choice", "the sacrifice is the seat's own question")
	assert_true(asked.choice.cancel, "a cost: it may be withdrawn")
	assert_true(SgViewProtocol.game(asked))
	var pick := -1
	for i in asked.choice.options.size():
		if String(asked.choice.options[i]).begins_with("Forest"): pick = i
	assert_ne(pick, -1, "the Forest is a body to give")
	assert_ok(referee.act(0, {"op": "choice", "picks": [pick]}))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.effect_ignored_by(curse, 0))


func test_a_curse_ignore_withdrawn_at_the_table_costs_nothing() -> void:
	var pair := _cursed()
	var forest := put_battlefield(0, "Forest")
	var at := _special_index(referee.view(0), "Sacrifice a permanent")
	assert_ok(referee.act(0, {"op": "special", "index": at}))
	assert_eq(referee.view(0).mode, "choice")
	assert_ok(referee.act(0, {"op": "cancel"}))
	assert_eq(referee.view(0).mode, "priority")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.effect_ignored_by(pair[0], 0))


func test_the_clients_cursed_creature_offers_the_ignore() -> void:
	var pair := _cursed()
	put_battlefield(0, "Forest")
	var screen := _screen()
	await _pump()
	screen._open_card_menu(_local(screen, pair[1]), Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	assert_ne(_item(menu, "Sacrifice a permanent: ignore Test Curse this turn"), -1,
		"on the creature it curses")
	menu.hide()


# ========================================================= payment rows --

func test_buyback_rows_cross_as_the_cast_actions_modes() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var capsize := give_synthetic(0, _capsize())
	var option := _cast_option(referee.view(0), capsize)
	assert_eq(option.modes, ["Pay {1}{U}{U}", "Buyback: Pay {1}{U}{U} plus {3} (returns to your hand)"])
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	var spells: Array = _row(view, capsize).abilities.filter(
		func(r: Dictionary) -> bool: return r.kind == "spell")
	assert_eq(spells.map(func(r: Dictionary) -> String: return "%d %s" % [int(r.index), r.cost]),
		["0 {1}{U}{U}", "0 {1}{U}{U}", "1 {1}{U}{U}{3}"], "the printed cost, then each open row's")
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, capsize), "kind": "spell",
		"index": 0, "x": 0, "mode": 1}))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	assert_true(g.buyback_paid(capsize), "cast with buyback")
	resolve_stack()
	assert_eq(capsize.zone, Mtg.Zone.HAND, "and back in hand")


func test_a_dream_halls_row_crosses_and_casts_through_a_discard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _halls())
	var insight := give_synthetic(0, _insight())
	var view := referee.view(0)
	var option := _cast_option(view, insight)
	assert_eq(option.modes.size(), 2, "a plain sorcery has the granted row too")
	assert_string_contains(String(option.modes[1]), "(Test Halls)")
	assert_false(_row(view, insight).castable, "no mana and nothing to discard")
	var other := give_synthetic(0, _insight())
	view = referee.view(0)
	assert_true(_row(view, insight).castable, "another blue card: the granted row pays")
	var lab: Script = load("res://DeckLab/referee.gd")
	assert_eq(lab.options_for(view, 0).prepare.casts.filter(
		func(e: Dictionary) -> bool: return e.card == referee._handle(0, insight))[0].usable_modes, [1],
		"only the granted row is open")
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, insight), "kind": "spell",
		"index": 0, "x": 0, "mode": 1}))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	if g.awaiting_choice != null:
		var asked := referee.view(0)
		var pick := -1
		for i in asked.choice.options.size():
			if String(asked.choice.options[i]).begins_with("Test Insight"): pick = i
		assert_ok(referee.act(0, {"op": "choice", "picks": [pick]}))
	assert_eq(insight.zone, Mtg.Zone.STACK, "cast with no mana")
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD, "the other blue card paid")


func test_the_clients_row_menu_reads_the_referees_rows() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _halls())
	var insight := give_synthetic(0, _insight())
	give_synthetic(0, _insight())
	var screen := _screen()
	await _pump()
	var local := _local(screen, insight)
	assert_eq(screen.game.payment_rows(0, local).size(), 2, "the projection reads the face's rows")
	screen._start_cast(local)
	assert_not_null(screen._mode_overlay, "two rows: the question")
	var lines: Array = []
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel": lines.append(button)
	assert_eq(lines.size(), 2)
	assert_true(lines[0].disabled, "the printed row cannot be paid: not open")
	assert_false(lines[1].disabled, "the granted row is")
	screen._on_mode_canceled()


# ============================================================== targets --

func test_reaps_count_crosses_per_opponent_and_the_client_narrows_it() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var reap := give_synthetic(0, _reap())
	put_battlefield(1, "Black Knight")
	put_battlefield(1, "Black Knight")
	var dead: Array = []
	for card_name in ["Grizzly Bears", "Hill Giant", "Llanowar Elves"]:
		var card := give_hand(0, card_name)
		g.players[0].hand.erase(card)
		card.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(card)
		dead.append(card)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, reap), "kind": "spell",
		"index": 0, "x": 0, "mode": 0}))
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "the counted slot validates")
	var slots: Array = view.announcement.slots
	assert_eq(slots.size(), 2)
	assert_eq(slots[0].targets.size(), 1, "target opponent: seat 1 alone")
	assert_eq(slots[1].counts, [[slots[0].targets[0].id, 0, 2]], "two black permanents: up to two")
	assert_eq(int(slots[1].max), 2)
	var screen := _screen()
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._try_take_target(screen._pending_slots[0].spec.candidates[0])
	assert_eq(screen._pending_slot, 1)
	assert_eq(int(screen._pending_slots[1]["max"]), 2, "narrowed to the opponent picked")
	assert_ok(referee.act(0, {"op": "submit", "targets": [[slots[0].targets[0].id, 1],
		[slots[1].targets[0].id, 1], [slots[1].targets[1].id, 1]]}))
	assert_eq(reap.zone, Mtg.Zone.STACK, "cast with two cards")


func test_a_trigger_is_a_named_spell_or_ability_target() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wyvern := put_synthetic(0, _wyvern())
	put_synthetic(0, _herald())
	var trigger: StackItem = g.stack.back()
	assert_eq(trigger.kind, Mtg.StackKind.TRIGGER, "control: the Herald's trigger waits")
	g.priority_player = 0
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, wyvern), "kind": "ability",
		"index": 0, "x": 0, "mode": 0}))
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	var slot: Dictionary = view.announcement.slots[0]
	assert_eq(int(slot.kind), TargetSpec.Kind.SPELL_OR_ABILITY)
	assert_eq(slot.targets.size(), 1)
	assert_eq(String(slot.targets[0].label), "Triggered ability: Test Herald")
	var chain_id: String = view.presentation.chain.back().id
	var ref: Dictionary = view.presentation.targets[0].ref
	assert_eq(ref.kind, "ability")
	assert_eq(ref.id, chain_id, "the token's ref is the chain entry's handle")
	var screen := _screen()
	var sent: Array = []
	screen.action_requested.connect(func(action: Dictionary) -> void: sent.append(action.duplicate(true)))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	var local_trigger: StackItem = screen.game.stack.back()
	assert_true(screen._chain_names_ability(local_trigger), "the client's chain entry names the trigger")
	screen._on_chain_ability_clicked(local_trigger)
	assert_eq(sent.size(), 1, "submitted")
	if sent.is_empty(): return
	assert_eq(String(sent[0].op), "submit")
	assert_ok(referee.act(0, sent[0]))
	assert_true(g.stack.back().targets[0].is_ability)
	assert_eq(g.stack.back().targets[0].ability_id, trigger.id)


# ============================================== the validator holds the line --

func test_forged_pack_9_rows_fail_the_protocol_check() -> void:
	var licid := _attached_licid()
	put_battlefield(0, "Mountain")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "control: the honest view")
	var at := _special_index(view, "Pay {R}")
	assert_ne(at, -1)
	var forged := view.duplicate(true)
	forged.presentation.special_rows[at] = ["steal_game", referee._handle(0, licid)]
	assert_false(SgViewProtocol.game(forged), "an unknown kind")
	forged = view.duplicate(true)
	forged.presentation.special_rows[at] = ["licid_end", "c999"]
	assert_false(SgViewProtocol.game(forged), "a card this view never carried")
	forged = view.duplicate(true)
	forged.presentation.special_rows.append(["channel", ""])
	assert_false(SgViewProtocol.game(forged), "a row with no special beside it")
	forged = view.duplicate(true)
	forged.presentation.attack_companions = [[referee._handle(0, licid), ["c999"]]]
	assert_false(SgViewProtocol.game(forged), "a companion this view never carried")


func test_a_forged_count_fails_the_protocol_check() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var reap := give_synthetic(0, _reap())
	put_battlefield(1, "Black Knight")
	var dead := give_hand(0, "Grizzly Bears")
	g.players[0].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, reap), "kind": "spell",
		"index": 0, "x": 0, "mode": 0}))
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "control")
	var forged := view.duplicate(true)
	forged.announcement.slots[1].counts = [["t99", 0, 1]]
	assert_false(SgViewProtocol.game(forged), "a token no earlier slot offered")
	forged = view.duplicate(true)
	forged.announcement.slots[1].counts[0][1] = 2
	assert_false(SgViewProtocol.game(forged), "a minimum past its maximum")
	forged = view.duplicate(true)
	forged.announcement.slots[0].counts = [[view.announcement.slots[0].targets[0].id, 0, 1]]
	assert_false(SgViewProtocol.game(forged), "a slot cannot count off its own candidates")
