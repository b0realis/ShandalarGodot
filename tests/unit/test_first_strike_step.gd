extends GameTest
## §1.6 of docs/duel-todo.md — FIRST-STRIKE DAMAGE IS ITS OWN STEP, with a
## priority window after it (CR 510.4/510.5).
##
## The 1997 game named both halves: `@CUECARD_PHASEBAR` (Program/
## UIStrings.txt:706) carries `Resolve 1st strike damage` and `Resolve
## normal damage` as two separate Combat Bar icons, and
## `@PROMPT_STOPANYWAY` can read `Paused: First strike damage resolution`.
## We used to run both waves back to back inside one COMBAT_DAMAGE step,
## so nothing could ever happen between them.


func test_first_strike_creates_its_own_step() -> void:
	var knight := put_battlefield(0, "White Knight")   # 2/2 first strike
	var giant := put_battlefield(1, "Hill Giant")      # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: knight.id}))
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	# The asymmetry that proves the split: the first striker has already
	# connected, the ordinary creature has not, and someone holds priority.
	assert_eq(giant.damage, 2, "the first striker has already dealt its damage")
	assert_eq(knight.damage, 0, "the ordinary blocker has NOT dealt its damage yet")
	assert_eq(g.priority_player, g.active_player, "priority opens in the new step")


func test_the_window_between_the_waves_can_save_the_first_striker() -> void:
	# The §1.6 line, made concrete: kill the survivor of the first-strike
	# wave before it strikes back. Impossible while both waves ran together.
	var knight := put_battlefield(0, "White Knight")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: knight.id}))
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "2 first-strike + 3 bolt buries it")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "nothing was left to strike back")
	assert_eq(knight.damage, 0)


func test_no_first_striker_skips_the_step_entirely() -> void:
	# CR 510.5: the first combat damage step only exists when someone has
	# first strike. Without it the game must not stop twice for damage.
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id}))
	# One pass round from declare-blockers must land on normal damage.
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.current_step(), Mtg.Step.COMBAT_DAMAGE,
		"no first striker: the first-strike step is skipped")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_an_unblocked_first_striker_still_gets_the_step() -> void:
	var knight := put_battlefield(0, "White Knight")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	assert_eq(g.players[1].life, 18, "the first striker hit the player already")


func test_membership_is_frozen_when_the_first_step_begins() -> void:
	# CR 510.5: the second step is for creatures that had neither first nor
	# double strike "as the first combat damage step began" — a creature
	# that LOSES first strike between the waves must not strike twice.
	var knight := put_battlefield(0, "White Knight")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: knight.id}))
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	g.remove_keyword_permanently(knight, Mtg.Keyword.FIRST_STRIKE)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.damage, 2, "the knight must not deal its damage a second time")
