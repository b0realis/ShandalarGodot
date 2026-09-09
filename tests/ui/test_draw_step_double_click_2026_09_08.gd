extends GutTest
## THE DOUBLE-CLICK OUTSIDE THE MAIN PHASE — the owner's playtest of
## 2026-09-08: *"If you are in draw phase and you double click on
## creature - you are warned you cannot cast but lands still tap and mana
## is lost !!! Lands should not automatically tap upon double click in
## draw phase - QoL."*
##
## WHAT WENT WRONG, and why the plainest card in the hand never showed it.
## A card that needs NO choice was refused by the engine the moment it was
## clicked, so nothing had been tapped for it. A card that stops for a
## choice FIRST — every Aura, every targeted sorcery, every X spell that
## then takes aim — parked in TARGETING without the engine ever seeing the
## announcement, and the double-click's auto-tapper then paid the whole
## cost of a cast the step was never going to allow: the lands tapped, the
## refusal arrived only after the player had aimed, and the stranded pool
## burned a life at the step change under the 1997 ruleset.
##
## WHAT IS PINNED. A double-click on a card the engine refuses for a
## reason no choice and no payment can fix — the step (draw, upkeep),
## whose turn it is, a sorcery-speed card on the opponent's turn — shows
## the refusal on the bar and taps NOTHING: every land stays untapped, the
## pool stays empty, no window opens, and there is nothing floating for
## the step change to burn. The legal cases are untouched: an instant in
## the draw step, a targeted instant in the draw step (mana drawn, aim
## still the player's), a creature in the main phase, an Aura in the main
## phase, and the X double-click's *"all of the mana you have available"*
## rule all cast exactly as they did (`tests/ui/test_casting_flow.gd` §5
## and `tests/ui/test_x_dialog.gd` pin the rest of that), and a creature
## the player cannot afford is refused as it always was.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


## Seat 0 with [param card_name] in hand and [param lands] untapped copies
## of [param land] on the table, nothing floating, standing in
## [param step] of the turn whose active player is [param active].
func _stage(card_name: String, step: Mtg.Step, lands := 2,
		active := 0, land := "Forest") -> CardInstance:
	var g: MtgGame = screen.game
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.priority_player = 0
	g.players[0].hand.clear()
	g.players[0].mana_pool.clear()
	g.players[0].battlefield.clear()
	screen.mode = DuelScreen.Mode.NORMAL
	var inst := CardInstance.new(CardRegistry.get_card(card_name), 94001, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	for i in lands:
		var source := CardInstance.new(CardRegistry.get_card(land),
			94010 + i, 0)
		g._instances[source.id] = source
		g._put_on_battlefield(source, 0)
	screen._refresh()
	return inst


## Something for an Aura to enchant.
func _body(pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		94500 + pid, pid)
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, pid)
	screen._refresh()
	return bear


## The gesture as the hand window delivers it: the first press's release
## is the row's own `pressed` (the single click), the second press
## arrives with `double_click` set and goes to the auto-cast.
func _double_click(inst: CardInstance) -> void:
	screen._on_card_clicked(inst)
	screen._auto_cast(inst)


func _tapped(g: MtgGame) -> int:
	var n := 0
	for perm in g.players[0].battlefield:
		if perm.tapped:
			n += 1
	return n


## The refusal, and nothing paid for it.
func _assert_refused_untouched(g: MtgGame, inst: CardInstance, why: String,
		life_before: int) -> void:
	assert_string_contains(screen._prompt_label.text, why,
		"the bar carries the refusal")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the cast was dropped")
	assert_null(screen._pending_card, "and nothing is left pending")
	assert_false(screen._modal_open(), "no window was opened to answer")
	assert_eq(inst.zone, Mtg.Zone.HAND, "the card stays in hand")
	assert_eq(_tapped(g), 0, "NO land tapped for a cast that was refused")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing floating to lose")
	assert_eq(g.players[0].life, life_before, "and no life went with it")


# ------------------------------------- the cards that need no choice at all --

func test_a_creature_double_clicked_in_the_draw_step_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", Mtg.Step.DRAW)
	var life := g.players[0].life
	_double_click(bears)
	_assert_refused_untouched(g, bears, "main phase", life)


func test_a_creature_double_clicked_in_the_upkeep_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", Mtg.Step.UPKEEP)
	var life := g.players[0].life
	_double_click(bears)
	_assert_refused_untouched(g, bears, "main phase", life)


func test_a_sorcery_speed_card_on_the_opponents_turn_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", Mtg.Step.MAIN1, 2, 1)
	var life := g.players[0].life
	_double_click(bears)
	_assert_refused_untouched(g, bears, "main phase", life)


# ------------------------------ the cards that stop for a choice first (§) --
#
# These are the owner's bug. Before the fix of 2026-09-09 every one of
# them tapped: the Aura took one Plains, Stone Rain took all three
# Mountains, and Braingeyser took EVERY Island the seat had, because the
# X question's answer is "all of the mana you have available".

func test_an_aura_double_clicked_in_the_draw_step_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var aura := _stage("Holy Strength", Mtg.Step.DRAW, 3, 0, "Plains")
	_body(0)
	var life := g.players[0].life
	_double_click(aura)
	_assert_refused_untouched(g, aura, "main phase", life)


func test_a_targeted_sorcery_in_the_draw_step_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var rain := _stage("Stone Rain", Mtg.Step.DRAW, 3, 0, "Mountain")
	var life := g.players[0].life
	_double_click(rain)
	_assert_refused_untouched(g, rain, "main phase", life)


func test_an_x_spell_in_the_draw_step_taps_nothing_and_asks_nothing() -> void:
	# The worst of them: the X window's own answer is the whole board, so
	# the refused Braingeyser used to strand five blue mana.
	var g: MtgGame = screen.game
	var geyser := _stage("Braingeyser", Mtg.Step.DRAW, 5, 0, "Island")
	var life := g.players[0].life
	_double_click(geyser)
	_assert_refused_untouched(g, geyser, "main phase", life)
	assert_null(screen._x_dialog, "and the X question was never put")


func test_a_tutor_in_the_draw_step_opens_no_library_picker() -> void:
	# The picker came up before the engine was ever asked, so the player
	# chose a card off their library and THEN read that they could not
	# cast the spell.
	var g: MtgGame = screen.game
	var tutor := _stage("Demonic Tutor", Mtg.Step.DRAW, 3, 0, "Swamp")
	var life := g.players[0].life
	_double_click(tutor)
	_assert_refused_untouched(g, tutor, "main phase", life)
	assert_null(screen._search_dialog, "the library was never opened")


func test_an_aura_double_clicked_in_the_upkeep_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var aura := _stage("Holy Strength", Mtg.Step.UPKEEP, 3, 0, "Plains")
	_body(0)
	var life := g.players[0].life
	_double_click(aura)
	_assert_refused_untouched(g, aura, "main phase", life)


func test_a_targeted_sorcery_on_the_opponents_turn_taps_nothing() -> void:
	var g: MtgGame = screen.game
	var rain := _stage("Stone Rain", Mtg.Step.MAIN1, 3, 1, "Mountain")
	var life := g.players[0].life
	_double_click(rain)
	_assert_refused_untouched(g, rain, "main phase", life)


func test_nothing_is_stranded_for_the_step_change_to_burn() -> void:
	# The whole of the owner's sentence, end to end, under the ruleset
	# that charges for a floating pool (RulesOptions.mana_burn, the 1997
	# answer): the refused Aura used to leave one white mana behind and
	# the draw step's end took a life for it.
	var g: MtgGame = screen.game
	g.rules.mana_burn = true
	var aura := _stage("Holy Strength", Mtg.Step.DRAW, 3, 0, "Plains")
	_body(0)
	var life := g.players[0].life
	_double_click(aura)
	g._advance_step()
	assert_eq(g.players[0].mana_pool.total(), 0, "no pool was ever made")
	assert_eq(g.players[0].life, life, "so the step change burned nothing")


# --------------------------------------- the legal gestures, unchanged (§) --

func test_an_instant_in_the_draw_step_still_auto_casts() -> void:
	var g: MtgGame = screen.game
	var fog := _stage("Fog", Mtg.Step.DRAW, 1)
	_double_click(fog)
	assert_eq(g.stack.size(), 1, "on the chain, in one gesture")
	assert_eq(fog.zone, Mtg.Zone.STACK)
	assert_eq(_tapped(g), 1, "the Forest paid for it")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_a_targeted_instant_in_the_draw_step_still_auto_taps() -> void:
	# "If the spell is a targeted one, you need to choose a target" — the
	# mana is drawn and the aim is the player's, as in the main phase.
	var g: MtgGame = screen.game
	var bolt := _stage("Lightning Bolt", Mtg.Step.DRAW, 0)
	var mountain := CardInstance.new(CardRegistry.get_card("Mountain"), 94100, 0)
	g._instances[mountain.id] = mountain
	g._put_on_battlefield(mountain, 0)
	screen._refresh()
	_double_click(bolt)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the aim is still ours")
	assert_eq(screen._pending_card, bolt)
	assert_true(mountain.tapped, "the Mountain was drawn for it")
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.R), 1)


func test_a_creature_in_the_main_phase_still_auto_casts() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", Mtg.Step.MAIN1)
	_double_click(bears)
	assert_eq(g.stack.size(), 1, "on the chain, in one gesture")
	assert_eq(_tapped(g), 2, "the suitable lands tapped themselves")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_an_aura_in_the_main_phase_still_auto_taps_and_aims() -> void:
	var g: MtgGame = screen.game
	var aura := _stage("Holy Strength", Mtg.Step.MAIN1, 1, 0, "Plains")
	_body(0)
	_double_click(aura)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the aim is still ours")
	assert_eq(screen._pending_card, aura)
	assert_eq(_tapped(g), 1, "and the Plains was drawn for it")


func test_the_x_double_click_still_spends_everything_available() -> void:
	# The playtest rule of 2026-09-03, and the gesture's own answer to the
	# X question: *"If you double-click to auto-cast an X spell, ALL of
	# the mana you have available in your pool and from land sources will
	# be put into that spell"* (`Duel.hlp`, topic **Hands**).
	var g: MtgGame = screen.game
	var geyser := _stage("Braingeyser", Mtg.Step.MAIN1, 5, 0, "Island")
	_double_click(geyser)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the aim is still ours")
	assert_eq(screen._pending_x, 3, "{X}{U}{U} out of five Islands")
	assert_eq(_tapped(g), 5, "every Island went into it")


func test_a_creature_out_of_reach_is_refused_as_before() -> void:
	# One Forest cannot pay {1}{G}: the engine's own sentence, the cast
	# dropped, nothing tapped — what the gesture did before this pass,
	# pinned so the fix does not move it. The timing query deliberately
	# says nothing about the mana, so this refusal still arrives from the
	# engine at the END of the chain.
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", Mtg.Step.MAIN1, 1)
	var life := g.players[0].life
	_double_click(bears)
	_assert_refused_untouched(g, bears, "not enough mana", life)
