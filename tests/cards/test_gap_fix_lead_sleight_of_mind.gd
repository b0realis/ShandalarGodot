extends GameTest
## SLEIGHT OF MIND READS THE TEXT (gap review 2026-11-10, r2-7's targeting
## half). A text change reaches only what the card's TEXT prints (CR 612.3):
## a protection another effect granted is no colour word in its text, so a
## creature whose only protection is granted is no legal target, and the
## colour words offered are the printed ones only.


## A seat that records the OPTION questions it is asked, answering the hint.
class Seat extends DecisionAgent:
	var asked: Array = []

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append([prompt, options.duplicate()])
		return hint


func test_a_granted_protection_alone_is_no_color_word() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	g.grant_protection_permanently(bears, Mtg.ManaColor.R)
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, sleight, [TargetRef.card(bears)]),
		"Illegal target")


func test_only_the_printed_word_is_offered_beside_a_grant() -> void:
	var knight := put_battlefield(1, "Black Knight")   # protection from white
	g.grant_protection_permanently(knight, Mtg.ManaColor.R)
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	var seat := Seat.new()
	g.set_agent(0, seat)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
	resolve_stack()
	assert_false(seat.asked.is_empty(), "the caster was asked for the color word")
	assert_eq(seat.asked[0][1], ["White"], "the granted red is not in the text")
	assert_eq(knight.cur_protection & Mtg.ManaColor.R, Mtg.ManaColor.R,
		"the granted red stays")
	assert_eq(knight.cur_protection & Mtg.ManaColor.W, 0, "the printed white moved")


func test_a_printed_word_is_still_a_target() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
