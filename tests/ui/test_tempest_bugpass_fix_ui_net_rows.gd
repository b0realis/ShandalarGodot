extends GutTest
## TEMPEST BUG PASS (Pack 9) — the local duel screen's payment rows and its
## X window, priced as the ENGINE prices the chosen row or ability:
##
##  * the X window of a BUYBACK row counts the buyback (Fanning the Flames
##    with four Mountains: {R}{3} leaves X = 0), and so does the
##    double-click's own answer;
##  * the X window of a creature's {X} ability counts Heartstone's floored
##    reduction (two lands pay X = 3; Skeleton Scavengers regenerates);
##  * under Aluren at instant speed the PRINTED row of a small creature is
##    greyed (only the Aluren row gives flash — Aluren ruling 2004-10-04),
##    as the network client greys it.

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
	CardPacks.set_enabled("pack-9", false)


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
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _mode_lines() -> Array:
	var out: Array = []
	if screen._mode_overlay == null:
		return out
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel":
			out.append(button)
	return out


## Fanning the Flames' shape: {X}{R}, X damage to any target, buyback {3}.
static func _fanning() -> CardData:
	return CardData.new("Test Fanning", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().any_target()) \
		.with_buyback({"mana": "{3}"})


static func _aluren_rows(_g: MtgGame, _pid: int, spell: CardInstance, _src: CardInstance) -> Array:
	if not spell.data.is_creature() or spell.data.cost.mana_value() > 3:
		return []
	return [{"label": "Cast it without paying its mana cost", "flash": true}]


static func _aluren() -> CardData:
	return CardData.new("Test Aluren", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_aluren_rows)


static func _creature_ability(_g: MtgGame, _pid: int, source: CardInstance,
		_ability: ActivatedAbility, _modifier: CardInstance) -> bool:
	return source.is_creature()


## Heartstone's shape: "Activated abilities of creatures cost {1} less to
## activate. This effect can't reduce the mana in that cost to less than one mana."
static func _heartstone() -> CardData:
	return CardData.new("Test Heartstone", "{3}", Mtg.CardType.ARTIFACT) \
		.with_ability_cost_reduction(1, _creature_ability, 1)


## A creature with an {X} ability (Skeleton Scavengers' cost shape).
static func _x_creature() -> CardData:
	return CardData.new("Test X Beast", "{2}", Mtg.CardType.CREATURE).pt(2, 2) \
		.activated(ActivatedAbility.new("{X}", false, [DrawEffect.new(1)], "{X}: Draw a card."))


# ---------------------------------------------------------------------------
# h2-3. The buyback row ({X}{R} plus {3}) with four Mountains can only pay
# X = 0; the window was budgeted on the printed {X}{R} and pre-filled X = 3,
# and OK then dropped the cast.
func test_the_x_window_of_a_buyback_row_counts_the_buyback() -> void:
	var fanning := _make(0, _fanning(), Mtg.Zone.HAND)
	for i in 4:
		_make(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	var g := _window(0, Mtg.Step.MAIN1)
	assert_eq(g.payment_row_refusal(0, fanning, 1), "", "the buyback row is payable at X = 0")
	screen._click_hand_card(fanning)
	assert_eq(_mode_lines().size(), 2)
	screen._on_mode_chosen(1)
	assert_not_null(screen._x_dialog, "the X window opens for the buyback row")
	if screen._x_spin != null:
		assert_eq(int(screen._x_spin.max_value), 0,
			"four Mountains pay {R}{3} and nothing more: X can only be 0 with buyback")
		assert_eq(int(screen._x_spin.value), 0, "the pre-filled X is payable")
		assert_eq(screen._auto_x_budget(), 0, "and the double-click asks the same bill")
	screen._on_cancel()


# The printed row of the same card keeps the whole budget: {R} and X = 3.
func test_the_x_window_of_the_printed_row_is_unchanged() -> void:
	var fanning := _make(0, _fanning(), Mtg.Zone.HAND)
	for i in 4:
		_make(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(fanning)
	screen._on_mode_chosen(0)
	assert_not_null(screen._x_dialog)
	if screen._x_spin != null:
		assert_eq(int(screen._x_spin.max_value), 3, "four Mountains: {R} and X = 3")
		assert_eq(screen._auto_x_budget(), 3)
	screen._on_cancel()


# ---------------------------------------------------------------------------
# h2-2. Heartstone's floored reduction: X = 3 costs two mana (E7), and the
# window budgeted with the flat ability surcharge only, offering X = 2.
func test_the_x_window_of_an_ability_counts_heartstone() -> void:
	_make(0, _heartstone(), Mtg.Zone.BATTLEFIELD)
	var beast := _make(0, _x_creature(), Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	var g := _window(0, Mtg.Step.MAIN1)
	var due := g.ability_payment(0, beast, 0, 3)
	assert_eq((due.cost as ManaCost).mana_value() + int(due.extra), 2, "the engine: X = 3 costs two")
	screen._open_ability_menu(beast)
	screen._on_ability_chosen(beast.cur_mana_abilities.size())
	assert_not_null(screen._x_dialog, "the X window opens")
	if screen._x_spin != null:
		assert_eq(int(screen._x_spin.max_value), 3,
			"two Forests pay X = 3 under Heartstone; the window offers it")
		assert_eq(screen._auto_x_budget(), 3, "and so does the double-click")
	screen._on_cancel()


# Without Heartstone the same two Forests pay X = 2, as they always did.
func test_the_x_window_of_an_ability_without_a_reduction_is_unchanged() -> void:
	var beast := _make(0, _x_creature(), Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_window(0, Mtg.Step.MAIN1)
	screen._open_ability_menu(beast)
	screen._on_ability_chosen(beast.cur_mana_abilities.size())
	assert_not_null(screen._x_dialog)
	if screen._x_spin != null:
		assert_eq(int(screen._x_spin.max_value), 2)
	screen._on_cancel()


# The real Stronghold pair: Skeleton Scavengers with three +1/+1 counters
# ("Pay {1} for each +1/+1 counter": X must be 3) under Heartstone costs two
# mana; with two lands the window stopped at X = 2, so the human could not
# regenerate it at all.
func test_skeleton_scavengers_regenerates_under_heartstone_from_the_window() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	_make(0, "Heartstone", Mtg.Zone.BATTLEFIELD)
	var scavengers := _make(0, "Skeleton Scavengers", Mtg.Zone.BATTLEFIELD)
	scavengers.counters["+1/+1"] = 3
	screen.game.recalculate()
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	var g := _window(0, Mtg.Step.MAIN1)
	var due := g.ability_payment(0, scavengers, 0, 3)
	assert_eq((due.cost as ManaCost).mana_value() + int(due.extra), 2, "the engine: X = 3 costs two")
	assert_eq(g.ability_announce_refusal(0, scavengers, 0), "")
	screen._open_ability_menu(scavengers)
	screen._on_ability_chosen(scavengers.cur_mana_abilities.size())
	assert_not_null(screen._x_dialog, "the X window opens")
	if screen._x_spin != null:
		assert_gte(int(screen._x_spin.max_value), 3, "X = 3 (the counters) is selectable")
	screen._on_cancel()


# ---------------------------------------------------------------------------
# h2-4. At instant speed under Aluren a small creature's printed row cannot
# be cast — "You can't choose to cast a creature as though it had flash via
# Aluren and still pay the mana cost" — and the local row menu left it open.
func test_the_printed_row_is_greyed_at_instant_speed_under_aluren() -> void:
	_make(1, _aluren(), Mtg.Zone.BATTLEFIELD)
	var bears := _make(0, "Grizzly Bears", Mtg.Zone.HAND)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	var g := _window(1, Mtg.Step.END)
	assert_ne(g.spell_announce_refusal(0, bears, 0, 0), "", "the engine refuses the printed row now")
	assert_eq(g.spell_announce_refusal(0, bears, 0, 1), "", "and takes the Aluren row")
	screen._click_hand_card(bears)
	var lines := _mode_lines()
	assert_eq(lines.size(), 2)
	if lines.size() == 2:
		assert_true(lines[0].disabled, "the printed row can't be cast at instant speed")
		assert_eq(lines[0].tooltip_text, g.spell_announce_refusal(0, bears, 0, 0),
			"greyed with the engine's reason")
		assert_false(lines[1].disabled)
	screen._on_mode_canceled()


# In its own main phase both rows stay open.
func test_both_rows_are_open_at_sorcery_speed_under_aluren() -> void:
	_make(1, _aluren(), Mtg.Zone.BATTLEFIELD)
	var bears := _make(0, "Grizzly Bears", Mtg.Zone.HAND)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_window(0, Mtg.Step.MAIN1)
	screen._click_hand_card(bears)
	var lines := _mode_lines()
	assert_eq(lines.size(), 2)
	if lines.size() == 2:
		assert_false(lines[0].disabled)
		assert_false(lines[1].disabled)
	screen._on_mode_canceled()
