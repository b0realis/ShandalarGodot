extends GameTest
## THE CARDS THE AI NEVER CAST (sweep of 2026-09-04).
##
## Three cards had never been cast in any logged game — Simulacrum, Energy
## Tap, Glyph of Destruction. Rather than answer for the three names, the
## whole pool was swept: every one of the 851 non-land cards was put in
## hand on a maximally favourable board and offered to the real
## `_try_cast_best`. SEVENTY-TWO were never cast, and no board improved
## thirty-nine of them. They fell into six structural classes; this file
## pins the three that were closed, and states the shape of the three that
## were not (docs/ROADMAP.md, "The AI dead-card sweep").
##
## Closed here:
##
## 1. A `*/*` CREATURE IS WORTH NOTHING IN HAND. [method
##    Evaluator.card_value] reads the PRINTED power and toughness, and a
##    creature sized by a static ability prints 0/0 — worth exactly 0.0,
##    or NEGATIVE for a `0/*` Wall (Defender is priced at -1.0). The
##    ranking loop keeps `value > best_value` from a floor of 0.0, so not
##    one of the pool's twelve could ever be the best card in hand.
## 2. AN UNCLASSIFIED EFFECT IS AIMED AT THE WRONG SIDE OF THE TABLE. A
##    card-local effect the reader has no model for is ASSUMED
##    removal-shaped, so the target picker shops the opponent's
##    battlefield — and a card whose own spec says "creature you control"
##    then finds nothing there and is never cast at all.
## 3. A COUNTERSPELL BUILT FROM A CARD-LOCAL EFFECT IS NOT A COUNTERSPELL.
##    `_try_counter` recognised only the shared `CounterEffect`, so Power
##    Sink, Mana Drain, Spell Blast and Force Spike — 33, 29, 7 and 1 deck
##    files of the shipped pool — were dead cards in hand all game.


func _reactive_ai(seat: int) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Everything seat 0 needs to cast anything: five of each land, untapped.
func _mana(pid: int) -> void:
	for land in ["Forest", "Island", "Mountain", "Plains", "Swamp"]:
		for _i in 4:
			put_battlefield(pid, land)


# ---------------------------------------------------- the `*/*` creatures --

func test_casts_a_creature_whose_size_is_a_static_ability() -> void:
	# Keldon Warlord is `*/*` — printed 0/0, worth 0.0, and therefore
	# never the best card in hand however long the game ran.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var warlord := give_hand(0, "Keldon Warlord")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Keldon Warlord")
	resolve_stack()
	assert_eq(warlord.zone, Mtg.Zone.BATTLEFIELD)


func test_casts_a_zero_star_wall() -> void:
	# Wall of Shadows prints 0/1 and its size is a static ability, so
	# `card_value` reads 0 + 1 + Defender's -1.0 = EXACTLY 0.0 — and the
	# ranking loop's bar starts at 0.0.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var wall := give_hand(0, "Wall of Shadows")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Wall of Shadows")
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)


func test_an_ordinary_creature_still_outranks_it() -> void:
	# The stand-in is the mana value, not a licence to jump the queue: a
	# Craw Wurm is still the better six drop.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	give_hand(0, "Wall of Shadows")
	var wurm := give_hand(0, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Craw Wurm")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------- the side of the table --

func test_simulacrum_is_aimed_at_our_own_creature() -> void:
	# "Damage that would be dealt to you this turn is dealt to target
	# creature you control instead." A card-local effect, so the reader
	# calls it removal-shaped and the picker looked only at THEIR board,
	# where the spec's own source filter makes nothing legal.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var mine := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var sim := give_hand(0, "Simulacrum")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Simulacrum")
	var item: StackItem = g.stack.back()
	assert_eq(item.targets[0].instance_id, mine.id, "at our own creature")


func test_the_other_side_is_only_looked_at_when_the_spec_allows_it() -> void:
	# The fallback is not "aim anywhere": with nothing of OURS on the
	# board, Simulacrum's own source filter still makes their Hill Giant
	# illegal, and the card correctly stays in hand.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var giant := put_battlefield(1, "Hill Giant")
	var sim := give_hand(0, "Simulacrum")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(sim.zone, Mtg.Zone.HAND, "no legal target on either side")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------ the counterspells --

func test_counters_with_mana_drain() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Mana Drain")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "Mana Drain")
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD, "the dragon never landed")
	# Run out the delayed payout ("at the beginning of your next main
	# phase"). It is also what keeps this test from leaking the game:
	# the scheduled Callable captures `game`, so a duel that ENDS with an
	# unpaid Mana Drain pending holds a reference cycle — see
	# docs/ROADMAP.md, the block-audit section's note on mana_drain.gd.
	advance_to_next_turn()
	assert_true("\n".join(g.log_lines).contains("Mana Drain pays out"),
		"the delayed mana arrived")


func test_power_sink_is_paid_for_with_a_real_x() -> void:
	# {X}{U}, and X = 0 counters nothing at all: the response path used to
	# hard-code X to zero, which is one reason this card had to be sized
	# rather than merely recognised.
	var ai := _reactive_ai(1)
	give_hand(1, "Power Sink")
	for _i in 5:
		put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "Power Sink")
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD, "the dragon never landed")


func test_a_copy_spell_is_not_fired_as_an_answer() -> void:
	# Fork and Reverberation also target a spell, and countering is
	# exactly what they do not do. The reading is the card's own oracle
	# line, which separates "Counter target ..." from "Copy target ...".
	var ai := _reactive_ai(1)
	var fork := give_hand(1, "Fork")
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Mountain")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "a copy spell is not an answer")
	assert_eq(fork.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.BATTLEFIELD)


func test_a_counterspell_is_never_cast_in_the_main_phase() -> void:
	# The other half of the classification: a card-local counterspell is
	# REACTIVE, so it waits for something to answer instead of being
	# ranked against the creatures in hand.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var sink := give_hand(0, "Power Sink")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(sink.zone, Mtg.Zone.HAND, "held for a spell to answer")
