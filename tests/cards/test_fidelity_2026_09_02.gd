extends GameTest
## The 2026-09-02 fidelity pass: the three cards the previous pass left
## explicitly HALF DONE — Frankenstein's Monster, Titania's Song and Worms
## of the Earth — each pinned at the behaviour that was missing
## (CONTRIBUTING.md rule 6: marker, row and test, every time).
##
## The two engine mechanisms they paid for are pinned next to the
## mechanism rather than here: `tests/unit/test_entry_ban.gd` for the
## enters-the-battlefield refusal and `tests/unit/test_leave_hook.gd` for
## the immediate leaves-the-battlefield hook and its floating statics.


# --------------------------------------------------- Frankenstein's Monster --

## A seat that always takes the LAST candidate offered and the LAST option
## — the opposite of every hint the Monster computes, so a test that gets
## its answer proves the question was really asked.
class ContrarySeat extends DecisionAgent:
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		return null if candidates.is_empty() else candidates[candidates.size() - 1]

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		return options.size() - 1


func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func _cast_monster(x: int) -> CardInstance:
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	if x > 0:
		add_mana(0, Mtg.ManaColor.C, x)
	assert_ok(g.cast_spell(0, monster, [], x))
	resolve_stack()
	return monster


func test_an_unassembled_monster_never_enters_the_battlefield() -> void:
	# "If you can't, put this creature into its owner's graveyard INSTEAD OF
	# onto the battlefield" — a replacement (CR 614.1c), so the Monster is
	# never a permanent at all. It therefore does not die, and nothing that
	# watches creatures dying is fed. Soul Net is the witness; the engine's
	# own per-turn body count is the second.
	put_battlefield(1, "Soul Net")
	put_battlefield(1, "Forest")
	var monster := _cast_monster(2)   # X=2 with an empty graveyard
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "it never entered, so it never died")
	assert_eq(g.creatures_died_this_turn, 0)


func test_a_monster_that_did_enter_dies_like_anything_else() -> void:
	# The control for the test above: Soul Net is not broken, and the
	# Monster is an ordinary creature once it is on the battlefield.
	put_battlefield(1, "Soul Net")
	put_battlefield(1, "Forest")
	_bury(0, "Grizzly Bears")
	var monster := _cast_monster(1)
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(monster)
	resolve_stack()
	assert_eq(g.players[1].life, 21, "this one really did die")
	assert_eq(g.creatures_died_this_turn, 1)


func test_the_monster_is_never_a_0_1_on_the_battlefield() -> void:
	# It used to arrive as its printed 0/1 and grow from an arrival
	# TRIGGER, so a 0/1 zombie really was on the table for as long as that
	# trigger sat on the stack. As a replacement (CR 614.1c) the whole
	# clause happens inside the spell's own resolution: one resolution, and
	# the stack is empty with a finished Monster on the battlefield.
	for _i in 3:
		_bury(0, "Grizzly Bears")
	put_battlefield(1, "Meekstone")
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, monster, [], 3))
	assert_eq(g.stack.size(), 1, "just the spell")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))   # one resolution
	assert_eq(g.stack.size(), 0, "no arrival trigger was left behind")
	assert_eq(monster.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(monster.cur_power, 3, "already built as it entered")
	# Meekstone reads power, and it read the finished body: a 0/1 would
	# have untapped freely.
	assert_true(monster.cur_skips_untap)


func test_the_controller_chooses_which_corpses_are_exiled() -> void:
	# "Exile X creature cards from your graveyard" — WHICH ones is the
	# controller's, and the engine's cheapest-first order is only the hint.
	_bury(0, "Grizzly Bears")        # mana value 2 — the hint
	var dragon := _bury(0, "Shivan Dragon")
	g.agents[0] = ContrarySeat.new()
	_cast_monster(1)
	assert_eq(dragon.zone, Mtg.Zone.EXILE, "they took the Dragon, against the hint")
	assert_eq(g.players[0].graveyard.size(), 1, "the Bears are still there")


func test_the_controller_chooses_each_counter() -> void:
	# "For each creature card exiled this way, this creature enters with a
	# +2/+0, +1/+1, or +0/+2 counter on it." The engine used to add +1/+1
	# throughout without asking.
	_bury(0, "Grizzly Bears")
	_bury(0, "Grizzly Bears")
	g.agents[0] = ContrarySeat.new()   # takes the LAST option: +0/+2
	var monster := _cast_monster(2)
	assert_eq(monster.cur_power, 0, "0/1 plus two +0/+2 counters")
	assert_eq(monster.cur_toughness, 5)


func test_the_default_seat_still_builds_a_balanced_monster() -> void:
	# The hints are the old hard-wired answers, so a seat that follows them
	# plays exactly as the card used to.
	_bury(0, "Grizzly Bears")
	_bury(0, "Grizzly Bears")
	var monster := _cast_monster(2)
	assert_eq(monster.cur_power, 2)
	assert_eq(monster.cur_toughness, 3)


func test_a_reanimated_monster_is_assembled_from_nothing() -> void:
	# CR 107.3b — X is 0 anywhere but the stack. A Monster cast for X=2 and
	# COUNTERED is a plain creature card in a graveyard; raising it must not
	# charge two more corpses, nor pay two more counters.
	_bury(0, "Grizzly Bears")
	_bury(0, "Grizzly Bears")
	var monster := give_hand(0, "Frankenstein's Monster")
	var counter := give_hand(1, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, monster, [], 2))
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(monster)]))
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].graveyard.size(), 3, "the two Bears are untouched")
	g.reanimate(monster, 0)
	assert_eq(monster.zone, Mtg.Zone.BATTLEFIELD, "it enters — X is 0 now")
	assert_eq(monster.cur_power, 0)
	assert_eq(monster.cur_toughness, 1)
	assert_eq(g.players[0].graveyard.size(), 2, "and it exiled nothing")


# ------------------------------------------------------------ Titania's Song --

func test_titanias_song_keeps_animating_after_it_is_destroyed() -> void:
	# "If this enchantment leaves the battlefield, this effect continues
	# until end of turn."
	var ring := put_battlefield(1, "Sol Ring")      # mana value 1
	var song := put_battlefield(0, "Titania's Song")
	g.recalculate()
	assert_true(ring.is_creature())
	g.destroy(song)
	g.check_state_based_actions()
	assert_eq(song.zone, Mtg.Zone.GRAVEYARD)
	assert_true(ring.is_creature(), "the effect continues without the Song")
	assert_eq(ring.cur_power, 1)
	assert_refused(g.tap_for_mana(1, ring), "no mana ability")


func test_titanias_song_lingers_however_it_leaves() -> void:
	# The hook is on the departure, not on the destruction: bouncing the
	# Song is the same event to this rider.
	var ring := put_battlefield(1, "Sol Ring")
	var song := put_battlefield(0, "Titania's Song")
	g.recalculate()
	g.return_to_hand(song)
	assert_eq(song.zone, Mtg.Zone.HAND)
	assert_true(ring.is_creature())


func test_titanias_songs_rider_ends_with_the_turn() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var song := put_battlefield(0, "Titania's Song")
	g.recalculate()
	g.destroy(song)
	g.check_state_based_actions()
	assert_true(ring.is_creature())
	advance_to_next_turn()
	assert_false(ring.is_creature(), "until END OF TURN, and no longer")
	assert_ok(g.tap_for_mana(1, ring))   # and it has its ability back


func test_titanias_songs_rider_catches_a_later_artifact() -> void:
	# CR 611.3a — a continuous effect from a static ability is not locked
	# in, and the printed rider lifts only the source's presence
	# (CR 611.3b). An artifact that arrives after the Song has gone, in the
	# same turn, is animated too.
	var song := put_battlefield(0, "Titania's Song")
	g.destroy(song)
	g.check_state_based_actions()
	var latecomer := put_battlefield(1, "Sol Ring")
	g.recalculate()
	assert_true(latecomer.is_creature())
	assert_eq(latecomer.cur_power, 1)


func test_titanias_song_still_ends_when_the_turn_it_left_in_does() -> void:
	# A Song that is still on the battlefield keeps animating across turns:
	# the rider is an end-of-turn duration for a departed Song only.
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Titania's Song")
	advance_to_next_turn()
	assert_true(ring.is_creature(), "the Song is still on the table")


# ---------------------------------------------------------------- Oubliette --

func test_the_oubliette_frees_its_prisoner_the_instant_it_leaves() -> void:
	# "phases out UNTIL this enchantment leaves the battlefield" is a
	# DURATION (CR 702.25f), not a trigger, so there is no window between
	# the Oubliette going and the creature coming back and nothing to
	# respond to. It used to be a leave-TRIGGER that had to resolve first —
	# the second card in the pool the immediate leave hook pays for.
	var victim := put_battlefield(1, "Serra Angel")
	var oubliette := put_battlefield(0, "Oubliette")
	resolve_stack()
	assert_true(victim.phased_out)
	g.destroy(oubliette)
	assert_eq(g.stack.size(), 0, "nothing on the stack to wait for")
	assert_false(victim.phased_out, "back at once")
	assert_true(victim.tapped, "tapped, as printed")


# --------------------------------------------------------- Worms of the Earth --

func test_worms_of_the_earth_ban_every_arrival_a_land_could_make() -> void:
	# The second printed line, "Lands can't enter the battlefield", is
	# wider than the first: a land PUT onto the battlefield is not played.
	put_battlefield(0, "Worms of the Earth")
	var forest := give_hand(0, "Forest")
	g.put_from_hand_into_play(forest, 0)
	assert_eq(forest.zone, Mtg.Zone.HAND, "not played, and still refused")
	assert_null(g.find_on_battlefield(0, "Forest"))


func test_worms_of_the_earth_let_lands_in_again_once_they_are_gone() -> void:
	# The ban is radiated by the permanent, so it ends with the permanent.
	var worms := put_battlefield(0, "Worms of the Earth")
	var forest := give_hand(0, "Forest")
	g.put_from_hand_into_play(forest, 0)
	assert_eq(forest.zone, Mtg.Zone.HAND)
	g.destroy(worms)
	g.check_state_based_actions()
	g.put_from_hand_into_play(forest, 0)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


func test_worms_of_the_earth_do_not_ban_anything_but_lands() -> void:
	put_battlefield(0, "Worms of the Earth")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_worms_of_the_earth_ban_an_animated_land_returning() -> void:
	# CONTRIBUTING.md rule 5: the ban reads the arriving object's LIVE type. A
	# Mishra's Factory is a land whether or not it is currently a creature.
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Worms of the Earth")
	g.return_to_hand(factory)
	assert_eq(factory.zone, Mtg.Zone.HAND)
	g.put_from_hand_into_play(factory, 0)
	assert_eq(factory.zone, Mtg.Zone.HAND, "a land is a land")
