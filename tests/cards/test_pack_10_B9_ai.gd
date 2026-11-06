extends GameTest
## Pack 10 (the Urza block), batch B9: the AI metadata the B9 cards declare
## reaches the fair AI. Morphling's shroud and Palinchron's return carry the
## `self_bounce` role (engine/ai/alliances_tactics.gd, Giant Crab's and
## Selenia's): an opposing spell aimed at them is answered from the public
## stack. The null arm (gate off) leaves the pilot as it was, and the answer
## does not move when the opponent's hidden hand changes (docs/fair-play.md).
## The heuristic "untap up to N lands" picks only its own lands whatever the
## opponent holds.

const U := preload("res://cards/sets/usg/_untap.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai

## P1 casts [param spell] at [param target] and passes: P0 (the AI) holds
## priority over it.
func _aimed_at(target: CardInstance, spell: String, color: int) -> CardInstance:
	assert_ok(g.pass_priority(0))
	var card := give_hand(1, spell)
	add_mana(1, color)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func test_the_ai_shrouds_its_morphling_against_a_bolt() -> void:
	var ai := _ai()
	var morph := put_battlefield(0, "Morphling")
	put_battlefield(0, "Island")
	var bolt := _aimed_at(morph, "Lightning Bolt", Mtg.ManaColor.R)
	assert_eq(ai.act(g), "activated Morphling")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(morph.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(morph.damage, 0)

func test_the_null_arm_lets_the_bolt_through() -> void:
	var ai := _ai(false)
	var morph := put_battlefield(0, "Morphling")
	put_battlefield(0, "Island")
	_aimed_at(morph, "Lightning Bolt", Mtg.ManaColor.R)
	assert_ne(ai.act(g), "activated Morphling")

func test_the_ai_sends_palinchron_home_from_a_terror() -> void:
	var ai := _ai()
	var palinchron := put_battlefield(0, "Palinchron")
	for i in 4: put_battlefield(0, "Island")
	var terror := _aimed_at(palinchron, "Terror", Mtg.ManaColor.B)
	assert_eq(ai.act(g), "activated Palinchron")
	resolve_stack()
	assert_eq(palinchron.zone, Mtg.Zone.HAND)
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)

## The opponent's hidden hand is not read: two different hands, the same
## answer.
func test_the_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var morph := put_battlefield(0, "Morphling")
		put_battlefield(0, "Island")
		give_hand(1, filler)
		_aimed_at(morph, "Lightning Bolt", Mtg.ManaColor.R)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])

## The computer untapping "up to N lands" picks its own, the same whatever
## the opponent holds or which of their lands are tapped behind a hidden
## reason.
func test_the_ai_untaps_its_own_lands_whatever_the_opponent_holds() -> void:
	var picks: Array = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		_ai()
		var mine: Array[CardInstance] = []
		for i in 3:
			var island := put_battlefield(0, "Island")
			island.tapped = true
			mine.append(island)
		var theirs := put_battlefield(1, "Forest")
		theirs.tapped = true
		give_hand(1, filler)
		assert_eq(U.UntapUpToEffect.untap_lands(g, 0, 2, null), 2)
		assert_true(theirs.tapped, "never the opponent's land")
		var untapped: Array[int] = []
		for i in mine.size():
			if not mine[i].tapped: untapped.append(i)
		picks.append(untapped)
	assert_eq(picks[0], picks[1])
