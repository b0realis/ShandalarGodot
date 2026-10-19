extends GameTest
## THE RUNAWAY GUARD (2026-10-19, [member AiPlayer._guard_seen],
## [constant AiPlayer.GUARD_CAST_CAP], [constant AiPlayer.GUARD_ABILITY_CAP]).
##
## Found by the Deck Lab on 0.50.38 (and so in the published 0.50.34): with
## Aluren on the table and a Shrieking Drake in hand the pilot cast the
## Drake for nothing, its arrival returned the only creature it had —
## itself — and it cast it again, for ever. 90 of 200 games stalled; on the
## duel screen, an AI turn that never ends. Aluren lets ANY player cast
## free, so the opponent's Aluren does it too, and Man-o'-War has the shape.
##
## Pinned here, on every profile and with the loop runner on and off:
##  * a position the seat has acted from is never acted from again in the
##    step — the Drake that returns itself is cast once;
##  * a cycle that moves something each time (the same Drake under a
##    Pandemonium is a damage a round) stops at the cast count, and a free
##    ability at the activation count;
##  * every turn ends, and a whole game plays out.

const PACKS := ["pack-6", "pack-8", "pack-9"]
const PRESETS := ["modern", "fifth"]


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in PACKS)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)


func _pilot(pid: int, rung: String, combos: bool) -> AiPlayer:
	var p := AiProfile.apprentice() if rung == "apprentice" else AiProfile.wizard()
	p.plays_combos = combos
	p.develops_late = false
	var ai := AiPlayer.new(pid, p)
	g.set_agent(pid, ai)
	return ai


func _casts(pid: int, card_name: String) -> int:
	var n := 0
	for data in g.spells_cast_this_turn[pid]:
		if (data as CardData).card_name == card_name:
			n += 1
	return n


## Both seats act until seat 0's first main phase is over; fails on a
## runaway.
func _play_main_phase(cap := 3000) -> void:
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and g.current_step() == Mtg.Step.MAIN1 \
			and rounds < cap:
		var a := (g.agents[0] as AiPlayer).act(g)
		var b := (g.agents[1] as AiPlayer).act(g)
		if a == "" and b == "":
			break
		rounds += 1
	assert_lt(rounds, cap, "the main phase ran away")


## ...and on until the turn is over.
func _finish_turn(cap := 3000) -> void:
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and rounds < cap:
		var a := (g.agents[0] as AiPlayer).act(g)
		var b := (g.agents[1] as AiPlayer).act(g)
		if a == "" and b == "":
			break
		rounds += 1
	assert_lt(rounds, cap, "the turn ran away")


## The four boards the guard was asked for: a free creature that returns
## itself, under our Aluren and under theirs.
func _board(which: String) -> String:
	match which:
		"our_drake":
			put_battlefield(0, "Aluren")
			give_hand(0, "Shrieking Drake")
			return "Shrieking Drake"
		"their_drake":
			put_battlefield(1, "Aluren")
			give_hand(0, "Shrieking Drake")
			return "Shrieking Drake"
		"our_jelly":
			put_battlefield(0, "Aluren")
			give_hand(0, "Man-o'-War")
			return "Man-o'-War"
		"their_jelly":
			put_battlefield(1, "Aluren")
			give_hand(0, "Man-o'-War")
			return "Man-o'-War"
	return ""


const BOARDS := ["our_drake", "their_drake", "our_jelly", "their_jelly"]


func test_a_creature_that_returns_itself_is_cast_once_a_step() -> void:
	for preset in PRESETS:
		for rung in ["apprentice", "wizard"]:
			for combos in [false, true]:
				for which in BOARDS:
					_fresh(preset)
					_pilot(0, rung, combos)
					_pilot(1, "wizard", false)
					var card_name := _board(which)
					var label := "%s %s combos=%s %s" % [preset, rung, combos, which]
					_play_main_phase()
					assert_lte(_casts(0, card_name), 1, "%s: the position came back, and it moved on" % label)
					_finish_turn()


func test_every_game_with_the_free_creatures_plays_out() -> void:
	for rung in ["apprentice", "wizard"]:
		for combos in [false, true]:
			for which in BOARDS:
				before_each()
				var a0 := _pilot(0, rung, combos)
				var a1 := _pilot(1, rung, combos)
				_board(which)
				# Short libraries: the game ends at the draw it cannot make.
				for pid in 2:
					var lib: Array[CardInstance] = g.players[pid].library
					g.players[pid].library = lib.slice(lib.size() - 6)
				assert_true(AiPlayer.play_out(g, a0, a1, 20000),
					"%s combos=%s %s: the game ended" % [rung, combos, which])


## The same Drake under a Pandemonium deals a damage each time — the
## position never comes back — and stops at the cast count.
func test_a_cycle_that_moves_stops_at_the_cast_count() -> void:
	for preset in PRESETS:
		for rung in ["apprentice", "wizard"]:
			_fresh(preset)
			_pilot(0, rung, false)
			_pilot(1, "wizard", false)
			put_battlefield(0, "Aluren")
			put_battlefield(0, "Pandemonium")
			give_hand(0, "Shrieking Drake")
			g.players[1].life = 30
			_play_main_phase()
			var cast := _casts(0, "Shrieking Drake")
			assert_gt(cast, 1, "%s %s: the position guard is not what stopped it" % [preset, rung])
			assert_lte(cast, AiPlayer.GUARD_CAST_CAP, "%s %s" % [preset, rung])
			_finish_turn()


## The activation count, at the gate every activation reading asks
## ([method AiPlayer._ability_available]): thirty breaths of firebreathing
## in a turn, and the thirty-first is not offered. (A free ability is the
## shape it backstops; the pilot's readings do not price a synthetic one,
## so the gate itself is pinned — the cast count above is pinned end to
## end.)
func test_an_ability_stops_at_the_activation_count() -> void:
	var ai := _pilot(0, "wizard", false)
	var dragon := put_battlefield(0, "Shivan Dragon")
	put_battlefield(0, "Mountain")
	dragon.ability_uses[0] = AiPlayer.GUARD_ABILITY_CAP - 1
	assert_true(ai._ability_available(g, dragon, 0), "the thirtieth breath")
	dragon.ability_uses[0] = AiPlayer.GUARD_ABILITY_CAP
	assert_false(ai._ability_available(g, dragon, 0), "not a thirty-first this turn")


## The loop runner's own rounds are not the cast count's: a Pandemonium
## loop run for lethal runs past eight, and the plain path stops after it.
func test_the_runner_runs_past_the_count_and_the_plain_path_stops_after_it() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilot(0, "wizard", true)
		_pilot(1, "wizard", false)
		put_battlefield(0, "Aluren")
		put_battlefield(0, "Pandemonium")
		give_hand(0, "Shrieking Drake")
		g.players[1].life = 12
		_finish_turn()
		assert_eq(g.winner, 0, "%s: twelve rounds, past the count of eight" % preset)


## A legitimate line never meets its own position again: three casts from
## three positions, each one taken.
func test_a_line_that_moves_is_never_stopped() -> void:
	var ai := _pilot(0, "wizard", false)
	_pilot(1, "wizard", false)
	for i in 3:
		put_battlefield(0, "Forest")
	for i in 3:
		give_hand(0, "Llanowar Elves")
	_play_main_phase()
	assert_eq(_casts(0, "Llanowar Elves"), 3, "three Elves, three positions")
	assert_false(ai._guard_seen.has("said"), "the guard never spoke")
