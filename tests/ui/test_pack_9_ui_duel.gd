extends GutTest
## PACK 9 — THE TEMPEST BLOCK AT A LOCAL TABLE: what a human seat on the
## duel screen can now do and see of what the engine gained, each pinned
## on a SYNTHETIC card (the engine notes' shapes) so a card batch cannot
## move it:
##
##  * COMBAT REQUIREMENTS (CR 509.1c, 508.1d) — a blocker under orders
##    (Watchdog, Provoke) is orange while it owes a block it could make;
##    a creature a pencilled attack drags in (Magnetic Web) is orange.
##  * SPECIAL ACTIONS (CR 116.2c-d) — a licid's "pay {R} to end this
##    effect" on the territory menu and the licid's own menu, greyed
##    without the mana; Volrath's Curse's sacrifice-to-ignore on the
##    cursed creature's menu, its sacrifice an ordinary held cost question
##    (answered or withdrawn); neither holds an empty chain's window.
##  * PAYMENT ROWS (CR 702.27a, 118.9) — a buyback row in plain words; a
##    row a permanent grants (Dream Halls) in the row menu, lighting the
##    card when it alone is payable, greyed with the engine's reason when
##    it is not; an X spell cast through it asks no X (CR 107.3b).
##  * TARGETS (CR 601.2c, 115.7) — Reap's count read once the opponent is
##    picked; a TRIGGER on the chain names the ability while a "target
##    spell or ability" slot is open (Silver Wyvern).

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

func _window(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func _stop_here() -> void:
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)


## A card of [param data] (synthetic) or of the registry name, made for
## [param pid] into [param zone].
func _make(pid: int, what: Variant, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data: CardData = what if what is CardData else CardRegistry.get_card(String(what))
	assert_not_null(data, str(what))
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	match zone:
		Mtg.Zone.HAND:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD:
			inst.zone = Mtg.Zone.GRAVEYARD
			g.players[pid].graveyard.append(inst)
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _resolve(g: MtgGame) -> void:
	var guard := 0
	while not g.stack.is_empty() and guard < 20:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1


static func _item(menu: PopupMenu, prefix: String) -> int:
	for i in menu.get_item_count():
		if menu.get_item_text(i).begins_with(prefix):
			return menu.get_item_id(i)
	return -1


static func _item_live(menu: PopupMenu, id: int) -> bool:
	var at := menu.get_item_index(id)
	return at >= 0 and not menu.is_item_disabled(at)


func _mode_lines() -> Array:
	var out: Array = []
	if screen._mode_overlay == null:
		return out
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel":
			out.append(button)
	return out


# ------------------------------------------------------- synthetic cards --

static func _bear(card_name := "Test Bear", cost := "{1}{G}") -> CardData:
	return CardData.new(card_name, cost, Mtg.CardType.CREATURE).pt(2, 2)


static func _watchdog() -> CardData:
	return CardData.new("Test Watchdog", "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 2).static_ability(CombatState.blocks_each_combat()) \
		.oracle("This creature blocks each combat if able.")


static func _flier() -> CardData:
	return CardData.new("Test Flier", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 1) \
		.with_keywords([Mtg.Keyword.FLYING])


static func _web() -> CardData:
	return CardData.new("Test Web", "{2}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_web_attack,
			"If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able."))


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
		.with_subtypes(["licid"]).as_licid("{R}", "{R}") \
		.oracle("{R}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {R} to end this effect.")


static func _curse() -> CardData:
	return CardData.new("Test Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_curse_host, "Enchanted creature can't attack or block.")) \
		.ignorable_by_sacrifice("permanent") \
		.oracle("Enchant creature\nEnchanted creature can't attack or block. That creature's controller may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.")


static func _curse_host(game: MtgGame, s: CardInstance) -> void:
	var h := game.find_instance(s.attached_to)
	if not game.is_present(h) or game.effect_ignored_by(s, h.controller_id):
		return
	h.cur_cant_attack = true


static func _capsize() -> CardData:
	return CardData.new("Test Capsize", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)).with_buyback({"mana": "{3}"}) \
		.oracle("Buyback {3}\nDraw a card.")


static func _halls() -> CardData:
	return CardData.new("Test Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_halls_rows) \
		.oracle("Rather than pay the mana cost for a spell, its controller may discard a card that shares a color with that spell.")


static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance, _src: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it", "object_costs": [group]}]


const OC := preload("res://engine/additional_object_costs.gd")


static func _insight() -> CardData:
	return CardData.new("Test Insight", "{2}{U}", Mtg.CardType.SORCERY) \
		.spell(DrawEffect.new(1)).oracle("Draw a card.")


static func _blue_x() -> CardData:
	return CardData.new("Test Blue X", "{X}{U}", Mtg.CardType.SORCERY) \
		.spell(DrawEffect.new(1)).oracle("Draw a card.")


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
		.spell(OpponentSlot.new()).spell(cards) \
		.oracle("Return up to X target cards from your graveyard to your hand, where X is the number of black permanents target opponent controls as you cast this spell.")


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
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _herald_gain,
			"When this creature enters, you gain 1 life.", _herald_entered))


static func _herald_gain(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass


static func _herald_entered(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


# ================================================= combat requirements --

## Seat 1 attacks with [param attackers]; the screen stands in seat 0's
## block declaration.
func _attack_into_blocks(attackers: Array) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	g._probing = false
	var ids: Array = []
	for card: CardInstance in attackers:
		ids.append(card.id)
	assert_eq(g.declare_attackers(1, ids), "")
	for _i in 10:
		if g.awaiting_blockers:
			break
		g.pass_priority(g.priority_player)
	assert_true(g.awaiting_blockers, "control: seat 0 declares blockers")
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
	return g


func test_a_watchdog_owing_a_block_is_orange() -> void:
	var dog := _make(0, _watchdog(), Mtg.Zone.BATTLEFIELD)
	var bear := _make(0, _bear(), Mtg.Zone.BATTLEFIELD)
	var raider := _make(1, _bear("Test Raider"), Mtg.Zone.BATTLEFIELD)
	_attack_into_blocks([raider])
	assert_eq(screen._highlight_for(dog), MiniCard.Highlight.MANDATORY,
		"it blocks each combat if able, and the Raider is there to block")
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.NONE, "control: a free bear")
	screen._block_map[dog.id] = [raider.id]
	assert_eq(screen._highlight_for(dog), MiniCard.Highlight.COMMITTED, "pencilled in")
	screen._block_map.clear()
	dog.tapped = true
	assert_eq(screen._highlight_for(dog), MiniCard.Highlight.NONE, "tapped: no block to owe")


func test_a_watchdog_that_cannot_block_the_attacker_is_not_orange() -> void:
	var dog := _make(0, _watchdog(), Mtg.Zone.BATTLEFIELD)
	var flier := _make(1, _flier(), Mtg.Zone.BATTLEFIELD)
	var g := _attack_into_blocks([flier])
	assert_eq(screen._highlight_for(dog), MiniCard.Highlight.NONE,
		"a requirement never breaks a restriction (CR 509.1c): it cannot block a flier")
	assert_eq(g.declare_blockers(0, {}), "", "and the engine takes no blocks")


func test_a_provoked_creature_is_orange_this_turn() -> void:
	var bear := _make(0, _bear(), Mtg.Zone.BATTLEFIELD)
	var raider := _make(1, _bear("Test Raider"), Mtg.Zone.BATTLEFIELD)
	screen.game.require_block_this_turn(bear)
	_attack_into_blocks([raider])
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.MANDATORY)


func test_magnetic_web_lights_the_creatures_an_attack_drags_in() -> void:
	_make(0, _web(), Mtg.Zone.BATTLEFIELD)
	var a := _make(0, _bear("Test Magnet A"), Mtg.Zone.BATTLEFIELD)
	var b := _make(0, _bear("Test Magnet B"), Mtg.Zone.BATTLEFIELD)
	var c := _make(0, _bear("Test Plain"), Mtg.Zone.BATTLEFIELD)
	a.counters["magnet"] = 1
	b.counters["magnet"] = 1
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	g.recalculate()
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	assert_eq(screen._highlight_for(b), MiniCard.Highlight.OPTIONAL, "nothing pencilled: free")
	screen._selected_attackers.append(a.id)
	assert_eq(screen._highlight_for(b), MiniCard.Highlight.MANDATORY,
		"a magnet creature attacks: every able magnet creature must")
	assert_eq(screen._highlight_for(c), MiniCard.Highlight.OPTIONAL, "control: no counter")
	assert_eq(screen._highlight_for(a), MiniCard.Highlight.COMMITTED)
	screen._selected_attackers.clear()
	screen._selected_attackers.append(c.id)
	assert_eq(screen._highlight_for(b), MiniCard.Highlight.OPTIONAL,
		"a plain attacker sets nothing off")


# ======================================================= special actions --

## Seat 0's licid hangs itself on seat 0's bear, through the engine.
func _attached_licid() -> Array:
	var licid := _make(0, _licid(), Mtg.Zone.BATTLEFIELD)
	var bear := _make(0, _bear(), Mtg.Zone.BATTLEFIELD)
	var g := _window(0, Mtg.Step.MAIN1)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]), "")
	_resolve(g)
	assert_true(g.is_licid_aura(licid), "control: the licid is an Aura on the bear")
	g.priority_player = 0
	return [licid, bear]


func test_a_licid_end_is_on_the_territory_menu_greyed_without_mana() -> void:
	var pair := _attached_licid()
	_stop_here()
	screen._open_territory_menu(0, Vector2(100, 400))
	var menu: PopupMenu = screen._territory_menu
	var id := _item(menu, "Pay {R}: end Test Licid's effect")
	assert_ne(id, -1, "the licid's controller is offered its end")
	assert_false(_item_live(menu, id), "no red mana: greyed")
	assert_eq(menu.get_item_tooltip(menu.get_item_index(id)).begins_with("not enough mana"), true,
		"the reason says so")
	menu.hide()
	screen._on_territory_menu_chosen(id)
	assert_true(screen.game.is_licid_aura(pair[0]), "nothing ended")


func test_a_licid_end_is_taken_from_the_licids_own_menu() -> void:
	var pair := _attached_licid()
	var licid: CardInstance = pair[0]
	var mountain := _make(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	_stop_here()
	screen._open_card_menu(licid, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := _item(menu, "Pay {R}: end Test Licid's effect")
	assert_true(_item_live(menu, id), "right-click the licid: end its effect")
	menu.hide()
	screen._on_card_menu_chosen(id)
	var g: MtgGame = screen.game
	assert_false(g.is_licid_aura(licid), "the licid is its creature self again")
	assert_true(licid.is_creature())
	assert_eq(licid.attached_to, -1)
	assert_true(mountain.tapped, "the {R} came from the Mountain")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")
	assert_eq(g.priority_player, 0, "the taker keeps priority (CR 116.3)")
	assert_true(g.stack.is_empty(), "no stack (CR 116.2c)")


func test_a_licid_end_holds_a_window_only_over_a_chain() -> void:
	_attached_licid()
	_make(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	var g: MtgGame = screen.game
	assert_false(screen._could_respond(0), "an empty chain is not held for an end")
	var bolt := _make(1, "Lightning Bolt", Mtg.Zone.HAND)
	g.priority_player = 1
	g.players[1].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.cast_spell(1, bolt, [TargetRef.player(0)]), "")
	assert_eq(g.pass_priority(1), "")
	assert_eq(g.priority_player, 0)
	assert_true(screen._could_respond(0), "a spell waits: the end is a response")


## Seat 1's Curse on seat 0's bear.
func _cursed() -> Array:
	var g: MtgGame = screen.game
	var curse := _make(1, _curse(), Mtg.Zone.HAND)
	var bear := _make(0, _bear(), Mtg.Zone.BATTLEFIELD)
	g.priority_player = 1
	g.attach_aura_from_anywhere(curse, bear, 1)
	_window(0, Mtg.Step.MAIN1)
	_stop_here()
	g.recalculate()
	assert_true(bear.cur_cant_attack, "control: the curse binds")
	return [curse, bear]


## Seat 0 holds priority in its main phase, held there by a Stop.
func _hold_priority() -> void:
	var g: MtgGame = screen.game
	_stop_here()
	g.priority_player = 0
	g._passes = 0


func test_the_curse_is_ignored_from_the_cursed_creatures_menu() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var bear: CardInstance = pair[1]
	var forest := _make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_hold_priority()
	screen._open_card_menu(bear, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := _item(menu, "Sacrifice a permanent: ignore Test Curse this turn")
	assert_true(_item_live(menu, id), "the cursed creature carries the ignore")
	menu.hide()
	screen._on_card_menu_chosen(id)
	var g: MtgGame = screen.game
	var asking: PlayerChoice = g.awaiting_choice
	assert_not_null(asking, "the sacrifice is held as a cost question")
	assert_true(asking.is_cost)
	assert_eq(asking.pid, 0)
	assert_true(asking.candidates.has(forest))
	assert_false(g.effect_ignored_by(curse, 0), "nothing taken yet")
	assert_eq(g.answer_choice(forest.id), "")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the Forest paid")
	assert_true(g.effect_ignored_by(curse, 0))
	g.recalculate()
	assert_false(bear.cur_cant_attack, "ignored until end of turn")
	screen._open_card_menu(bear, Vector2(100, 100))
	assert_eq(_item(menu, "Sacrifice a permanent: ignore"), -1, "taken this turn: no more")
	menu.hide()


func test_the_curses_own_menu_offers_it_too_and_cancel_withdraws_it() -> void:
	var pair := _cursed()
	var curse: CardInstance = pair[0]
	var forest := _make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_hold_priority()
	screen._open_card_menu(curse, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := _item(menu, "Sacrifice a permanent: ignore Test Curse this turn")
	assert_true(_item_live(menu, id))
	menu.hide()
	screen._on_card_menu_chosen(id)
	var g: MtgGame = screen.game
	assert_not_null(g.awaiting_choice)
	assert_eq(g.cancel_choice(), "")
	assert_null(g.awaiting_choice)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "withdrawn: nothing sacrificed")
	assert_false(g.effect_ignored_by(curse, 0))


func test_the_ignore_is_not_the_curse_casters() -> void:
	_cursed()
	var g: MtgGame = screen.game
	g.priority_player = 1
	for row in screen._special_actions(1):
		assert_ne(String(row["kind"]), "ignore_effect", "seat 1 is the AI, and not the payer")
	g.priority_player = 0
	assert_eq(screen._engine_special_actions(0).size(), 1, "the cursed seat holds it")


# ========================================================= payment rows --

func test_a_buyback_row_says_buyback_in_the_row_menu() -> void:
	var capsize := _make(0, _capsize(), Mtg.Zone.HAND)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(capsize)
	var lines := _mode_lines()
	assert_eq(lines.size(), 2, "the printed row and the buyback row")
	assert_eq(lines[0].text, "Pay {1}{U}{U}")
	assert_eq(lines[1].text, "Buyback: Pay {1}{U}{U} plus {3} (returns to your hand)")
	assert_false(lines[1].disabled, "short of mana is the chain's to wait for, not a grey")
	screen._on_mode_canceled()


func test_the_buyback_label_reads_every_shape() -> void:
	assert_eq(DuelScreen.payment_row_label({"label": "Pay {1}{G} with buyback (Sacrifice a land)",
		"payment": {"buyback": true, "buyback_text": "Sacrifice a land"}}),
		"Buyback: Pay {1}{G}, Sacrifice a land (returns to your hand)")
	assert_eq(DuelScreen.payment_row_label({"label": "Pay {R}", "payment": {}}), "Pay {R}",
		"an ordinary row as the engine words it")
	var worded := "Buyback: Pay {1}{U}{U} plus {3} (returns to your hand)"
	assert_eq(DuelScreen.payment_row_label({"label": worded,
		"payment": {"buyback": true, "buyback_text": "{3}"}}), worded, "said once")


func test_dream_halls_row_lights_a_card_only_it_can_pay_for() -> void:
	_make(0, _halls(), Mtg.Zone.BATTLEFIELD)
	var insight := _make(0, _insight(), Mtg.Zone.HAND)
	_window(0, Mtg.Step.MAIN1)
	assert_eq(screen._highlight_for(insight), MiniCard.Highlight.NONE,
		"no mana and no blue card to discard")
	_make(0, _insight(), Mtg.Zone.HAND)
	assert_eq(screen._highlight_for(insight), MiniCard.Highlight.OPTIONAL,
		"another blue card: the granted row pays")


func test_dream_halls_row_is_in_the_menu_and_greyed_without_a_card() -> void:
	_make(0, _halls(), Mtg.Zone.BATTLEFIELD)
	var insight := _make(0, _insight(), Mtg.Zone.HAND)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(insight)
	var lines := _mode_lines()
	assert_eq(lines.size(), 2, "a plain sorcery has two ways to pay")
	assert_eq(lines[0].text, "Pay {2}{U}")
	assert_string_contains(lines[1].text, "Discard a card that shares a color with it")
	assert_string_contains(lines[1].text, "Test Halls", "named after the permanent granting it")
	assert_true(lines[1].disabled, "nothing to discard")
	assert_ne(lines[1].tooltip_text, "", "with the engine's reason")
	screen._on_mode_canceled()


func test_a_spell_cast_through_the_dream_halls_row() -> void:
	_make(0, _halls(), Mtg.Zone.BATTLEFIELD)
	var insight := _make(0, _insight(), Mtg.Zone.HAND)
	var other := _make(0, _insight(), Mtg.Zone.HAND)
	var g := _window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(insight)
	assert_false(_mode_lines()[1].disabled)
	screen._on_mode_chosen(1)
	if g.awaiting_choice != null:
		assert_eq(g.answer_choice(other.id), "")
	assert_eq(insight.zone, Mtg.Zone.STACK, "cast with no mana")
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD, "the discard paid")


func test_an_x_spell_through_a_granted_row_asks_no_x() -> void:
	_make(0, _halls(), Mtg.Zone.BATTLEFIELD)
	var spell := _make(0, _blue_x(), Mtg.Zone.HAND)
	_make(0, _insight(), Mtg.Zone.HAND)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(spell)
	screen._pending_mode = 1
	assert_false(screen._pending_wants_x(), "X is 0 under a row without {X} (CR 107.3b)")
	screen._pending_mode = 0
	assert_true(screen._pending_wants_x(), "control: the printed row asks it")
	screen._on_mode_canceled()


# ============================================================== targets --

func test_reap_counts_its_cards_once_the_opponent_is_picked() -> void:
	var reap := _make(0, _reap(), Mtg.Zone.HAND)
	_make(1, "Black Knight", Mtg.Zone.BATTLEFIELD)
	_make(1, "Black Knight", Mtg.Zone.BATTLEFIELD)
	_make(1, "Swamp", Mtg.Zone.BATTLEFIELD)
	for card_name in ["Grizzly Bears", "Hill Giant", "Llanowar Elves"]:
		_make(0, card_name, Mtg.Zone.GRAVEYARD)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(reap)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the opponent first")
	assert_eq(screen._pending_slot, 0)
	screen._try_take_target(TargetRef.player(1))
	assert_eq(screen._pending_slot, 1, "on to the cards")
	assert_eq(int(screen._pending_slots[1]["max"]), 2, "two black permanents: up to two cards")
	assert_eq(int(screen._pending_slots[1]["min"]), 0)
	screen._on_cancel()


func test_reap_at_an_opponent_without_black_skips_the_cards() -> void:
	var reap := _make(0, _reap(), Mtg.Zone.HAND)
	_make(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var g := _window(0, Mtg.Step.MAIN1)
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 2)
	screen._click_hand_card(reap)
	screen._try_take_target(TargetRef.player(1))
	assert_eq(reap.zone, Mtg.Zone.STACK, "X is 0: no card slot to fill, the spell is cast")


func test_a_trigger_on_the_chain_is_a_spell_or_ability_target() -> void:
	var wyvern := _make(0, _wyvern(), Mtg.Zone.BATTLEFIELD)
	var g := _window(0, Mtg.Step.MAIN1)
	_make(0, _herald(), Mtg.Zone.BATTLEFIELD)
	var trigger: StackItem = null
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER:
			trigger = item
	assert_not_null(trigger, "control: the Herald's trigger waits on the chain")
	g.priority_player = 0
	assert_false(screen._chain_names_ability(trigger), "outside targeting it is its card")
	screen._pending_card = wyvern
	screen._pending_pid = 0
	screen._pending_ability_index = 0
	screen._pending_x = 0
	screen._build_ability_slots(wyvern.cur_activated_abilities[0])
	screen._advance_pending()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_true(screen._chain_names_ability(trigger), "a spell-or-ability slot names the trigger")
	assert_eq(screen._ability_highlight(trigger), MiniCard.Highlight.TARGET_LEGAL)
	screen._on_chain_ability_clicked(trigger)
	var aimed: StackItem = g.stack.back()
	assert_eq(aimed.card, wyvern, "the ability is on the chain")
	assert_eq(aimed.targets.size(), 1)
	assert_true(aimed.targets[0].is_ability, "aimed at the trigger as an ability")
	assert_eq(aimed.targets[0].ability_id, trigger.id)


func test_a_trigger_names_its_card_for_an_ordinary_slot() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_make(0, _herald(), Mtg.Zone.BATTLEFIELD)
	var trigger: StackItem = g.stack.back()
	assert_eq(trigger.kind, Mtg.StackKind.TRIGGER)
	var bolt := _make(0, "Lightning Bolt", Mtg.Zone.HAND)
	g.priority_player = 0
	screen._click_hand_card(bolt)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_false(screen._chain_names_ability(trigger), "\"any target\": the Herald itself")
	screen._on_cancel()
