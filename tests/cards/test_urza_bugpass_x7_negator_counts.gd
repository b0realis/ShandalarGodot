extends GameTest
## Phyrexian Negator's "(n of total)" prompt — the 0.60.19 bug pass, h8-3.
##
## "Whenever Phyrexian Negator is dealt damage, sacrifice that many
## permanents." The sacrifices are picked one at a time through the shared
## Urza's Saga helper (cards/sets/usg/_triggers.gd `sacrifice_some`), each
## prompt counting "(n of total)". The total was worked out again after
## every pick from the shrinking pool, so three sacrifices out of three
## permanents read "(1 of 3)", "(2 of 2)", "(3 of 1)". The total is now how
## many will go — the damage, or every permanent when there are fewer —
## fixed before the first pick, as Urza's Saga's own `sacrifice_permanents`
## does it.


## A seat that answers as the default agent does and writes down each
## card question it is asked.
class Recorder extends DecisionAgent:
	var prompts: Array[String] = []

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		prompts.append(prompt)
		return super.answer_card(game, pid, candidates, prompt)


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()


func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## Bolt the Negator (5/5) with [param swamps] Swamps beside it; the
## prompts its controller was asked.
func _bolted_negator(swamps: int) -> Array[String]:
	var seat := Recorder.new()
	g.set_agent(0, seat)
	var negator := put_battlefield(0, "Phyrexian Negator")
	for n in swamps: put_battlefield(0, "Swamp")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(negator)]))
	resolve_stack()
	var out: Array[String] = []
	for p in seat.prompts:
		if p.begins_with("Phyrexian Negator: sacrifice a permanent"): out.append(p)
	return out


func test_three_sacrifices_from_three_permanents_count_to_three() -> void:
	var prompts := _bolted_negator(2)
	assert_eq(prompts, ["Phyrexian Negator: sacrifice a permanent (1 of 3)",
		"Phyrexian Negator: sacrifice a permanent (2 of 3)",
		"Phyrexian Negator: sacrifice a permanent (3 of 3)"],
		"one total for the whole sacrifice, not the pool left after each pick")
	assert_eq(g.players[0].battlefield.size(), 0, "all three went")


func test_fewer_permanents_than_damage_count_to_what_there_is() -> void:
	var prompts := _bolted_negator(1)
	assert_eq(prompts, ["Phyrexian Negator: sacrifice a permanent (1 of 2)",
		"Phyrexian Negator: sacrifice a permanent (2 of 2)"],
		"three to pay with two permanents: two picks, counted out of two")
	assert_eq(g.players[0].battlefield.size(), 0)


func test_more_permanents_than_damage_keep_the_same_count() -> void:
	var prompts := _bolted_negator(4)
	assert_eq(prompts, ["Phyrexian Negator: sacrifice a permanent (1 of 3)",
		"Phyrexian Negator: sacrifice a permanent (2 of 3)",
		"Phyrexian Negator: sacrifice a permanent (3 of 3)"], "control: the count was right here before")
	assert_eq(g.players[0].battlefield.size(), 2)
