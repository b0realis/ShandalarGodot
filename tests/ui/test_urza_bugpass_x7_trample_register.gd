extends GameTest
## WHICH LIFE REGISTER TAKES THE TRAMPLE POINT — the 0.60.19 bug pass, h8-2.
##
## A trampler's excess goes to the player it attacks (CR 702.19b), and the
## duel screen takes that point as a click on that player's life register
## (`@MENU_LIFE` "Target %s"). The screen read "the register that is not
## mine" — right while the ATTACKING player divides, wrong when the
## DEFENDING player does: under Defensive Formation ("Rather than the
## attacking player, you assign the combat damage of each creature
## attacking you") or a banding block (CR 702.22j) the defender's click on
## their own register did nothing, and a click on the attacker's register
## added the point that hurt the defender. Now the register that takes it
## is the defending player's whoever divides — at the local table and on a
## networked guest's screen — and the referee names that point "You" in
## the defender's own view.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []
var local_screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	referee = null
	local_screen = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _until(ready: Callable, game: MtgGame = null) -> void:
	if game == null: game = g
	var guard := 0
	while not bool(ready.call()) and not game.game_over and guard < 800:
		assert_ok(game.pass_priority(game.priority_player))
		guard += 1


func _pump() -> void:
	for i in 10: await get_tree().process_frame


# ------------------------------------------------- the local table --

func _card(game: MtgGame, pid: int, card_name: String) -> CardInstance:
	for inst in game.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return inst
	fail_test("no %s for seat %d" % [card_name, pid])
	return null


## The computer's War Mammoth (seat 1) attacks the player (seat 0), who
## blocks with Llanowar Elves under Defensive Formation; the player then
## divides the Mammoth's 3. The computer never moves on its own here (a
## long pace): the test passes for both seats.
func _defending_player_divides() -> MtgGame:
	var position := DuelPosition.new()
	position.add(1, DuelPosition.TABLE, "War Mammoth")
	position.add(0, DuelPosition.TABLE, "Llanowar Elves")
	position.add(0, DuelPosition.TABLE, "Defensive Formation")
	position.active_player = 1
	position.step = Mtg.Step.COMBAT_BEGIN
	var config := DuelConfig.hotseat_default().for_test(position, 93400)
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 600.0
	local_screen = load("res://game/duel/duel_screen.tscn").instantiate()
	local_screen.config = config
	add_child_autofree(local_screen)
	await get_tree().process_frame
	var game: MtgGame = local_screen.game
	var mammoth := _card(game, 1, "War Mammoth")
	var elves := _card(game, 0, "Llanowar Elves")
	_until(func() -> bool: return game.awaiting_attackers, game)
	assert_ok(game.declare_attackers(1, [mammoth.id]))
	_until(func() -> bool: return game.awaiting_blockers, game)
	assert_ok(game.declare_blockers(0, {elves.id: mammoth.id}))
	_until(func() -> bool: return game.awaiting_damage_assignment, game)
	local_screen._refresh()
	return game


func test_the_defending_player_clicks_their_own_register_for_the_spill() -> void:
	var game: MtgGame = await _defending_player_divides()
	var elves := _card(game, 0, "Llanowar Elves")
	assert_eq(int(game.damage_assignment_request().assigner), 0, "control: Defensive Formation hands the division over")
	assert_eq(local_screen.mode, DuelScreen.Mode.DAMAGE, "control: the player divides on the screen")
	local_screen._assign_one_point(elves.id)
	assert_eq(local_screen._damage_picks, {elves.id: 1}, "control: lethal to the Elves first")
	local_screen._on_life_clicked(1)
	assert_false(local_screen._damage_picks.has(MtgGame.DAMAGE_TO_PLAYER),
		"the attacker's register takes no point: the spill is not the attacker's")
	local_screen._on_life_clicked(0)
	assert_eq(int(local_screen._damage_picks.get(MtgGame.DAMAGE_TO_PLAYER, 0)), 1,
		"the defender's own register takes the point the Mammoth tramples over")
	local_screen._on_life_clicked(0)
	assert_false(game.awaiting_damage_assignment, "all 3 placed: the division went in")
	if game.awaiting_damage_assignment: return
	_until(func() -> bool: return game.current_step() == Mtg.Step.COMBAT_END \
		or game.current_step() == Mtg.Step.MAIN2, game)
	assert_eq(game.players[0].life, 18, "the 2 trampled over hit the defender, as clicked")
	assert_eq(game.players[1].life, 20, "the attacker is never hurt by its own Mammoth")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------ a networked guest --

func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Pack ten", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


## The host's War Mammoth (seat 0) attacks the guest (seat 1), who blocks
## with Llanowar Elves — under the guest's Defensive Formation when
## [param formation].
func _mammoth_blocked(formation: bool) -> Array:
	if formation: put_battlefield(1, "Defensive Formation")
	var mammoth := put_battlefield(0, "War Mammoth")
	var elves := put_battlefield(1, "Llanowar Elves")
	_until(func() -> bool: return g.awaiting_attackers)
	assert_ok(referee.act(0, {"op": "attack", "cards": [referee._handle(0, mammoth)]}))
	_until(func() -> bool: return g.awaiting_blockers)
	assert_ok(referee.act(1, {"op": "block", "pairs": [[referee._handle(1, elves),
		referee._handle(1, mammoth)]]}))
	_until(func() -> bool: return g.awaiting_damage_assignment)
	return [mammoth, elves]


func test_a_defending_guest_clicks_their_own_register_for_the_spill() -> void:
	var cards := _mammoth_blocked(true)
	assert_eq(int(g.damage_assignment_request().assigner), 1, "control: the guest divides")
	var screen := _screen(1)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE, "control: on the guest's screen")
	screen._assign_one_point(_local(screen, cards[1]).id)
	screen._on_life_clicked(1)   # the host's register, seen from the guest's seat
	assert_false(screen._damage_picks.has(MtgGame.DAMAGE_TO_PLAYER),
		"the attacking host's register takes no point")
	screen._on_life_clicked(0)   # the guest's own register
	assert_eq(int(screen._damage_picks.get(MtgGame.DAMAGE_TO_PLAYER, 0)), 1,
		"the guest's own register takes the spill")
	screen._on_life_clicked(0)
	await _pump()
	await _pump()
	assert_eq(refusals, [])
	assert_eq(commands.size(), 1, "one division sent")
	if g.awaiting_damage_assignment: return
	if commands.size() == 1:
		var points := {}
		for pair in commands[0].points: points[String(pair[0])] = int(pair[1])
		assert_eq(int(points.get("player", 0)), 2, "two to the player")
	_until(func() -> bool: return g.current_step() == Mtg.Step.COMBAT_END or g.current_step() == Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 18, "the defending guest took the 2 they clicked onto their own register")
	assert_eq(g.players[0].life, 20)


func test_the_attacking_guest_still_clicks_the_defenders_register() -> void:
	# The control the fix must keep: the guest attacks, the host defends
	# without a Formation, and the guest divides its own trampler.
	var mammoth := put_battlefield(1, "War Mammoth")
	var elves := put_battlefield(0, "Llanowar Elves")
	advance_to_next_turn()
	_until(func() -> bool: return g.awaiting_attackers)
	assert_ok(referee.act(1, {"op": "attack", "cards": [referee._handle(1, mammoth)]}))
	_until(func() -> bool: return g.awaiting_blockers)
	assert_ok(referee.act(0, {"op": "block", "pairs": [[referee._handle(0, elves),
		referee._handle(0, mammoth)]]}))
	_until(func() -> bool: return g.awaiting_damage_assignment)
	assert_eq(int(g.damage_assignment_request().assigner), 1, "control: the attacking guest divides")
	var screen := _screen(1)
	await _pump()
	screen._assign_one_point(_local(screen, elves).id)
	screen._on_life_clicked(0)   # the guest's own register
	assert_false(screen._damage_picks.has(MtgGame.DAMAGE_TO_PLAYER), "never the attacker's own life")
	screen._on_life_clicked(1)   # the defending host's register
	assert_eq(int(screen._damage_picks.get(MtgGame.DAMAGE_TO_PLAYER, 0)), 1)


# ------------------------------------------------ the referee's label --

func _player_point(view: Dictionary) -> Dictionary:
	for target in view.damage_request.get("targets", []):
		if String(target.id) == "player": return target
	return {}


func test_the_defenders_own_view_names_the_player_point_you() -> void:
	_mammoth_blocked(true)
	var view := referee.view(1)
	assert_true(SgViewProtocol.game(view))
	assert_eq(String(_player_point(view).get("name", "")), "You",
		"the defender divides: the trample point is their own life")


func test_the_attackers_view_still_names_the_player_point_opponent() -> void:
	_mammoth_blocked(false)
	assert_eq(int(g.damage_assignment_request().assigner), 0, "control: the attacker divides")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_eq(String(_player_point(view).get("name", "")), "Opponent")
