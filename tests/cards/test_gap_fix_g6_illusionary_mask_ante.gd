extends GameTest
## THE GAP REVIEW OF 2026-11-10 (r6-3), the owner's ruling of that day:
## Illusionary Mask refuses ante cards in a duel not played for ante.
##
## WAS: the ruling of 2026-10-21 refuses the nine ante cards' spells and
## abilities with Ante off ([method MtgGame.not_for_ante_refusal]), but the
## Mask's own pick of "a creature card in your hand" skipped no one, so a
## Tempest Efreet (or Timmerian Fiends) the player may not cast reached the
## battlefield face down through a card whose text says it CASTS that
## creature. NOW the Mask offers only the creatures the ruling lets act;
## when that leaves nothing, its log line gives the ruling's reason to its
## controller alone — the other seat reads only that nothing was hidden,
## and the question (whose prompt can reach the table) names no refused
## card. In a duel played for ante the Mask is unchanged. Other
## put-into-play effects keep today's behaviour (the ruling's own words).

const REASON := "Ante must be on for Tempest Efreet"


## Remembers what the Mask offered and the question it asked.
class Records extends DecisionAgent:
	var offered: Array[String] = []
	var prompt := ""

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			asked: String) -> CardInstance:
		offered.clear()
		for card in candidates:
			offered.append(card.data.card_name)
		prompt = asked
		return super(game, pid, candidates, asked)


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _activate(mask: CardInstance, x: int) -> void:
	add_mana(0, Mtg.ManaColor.C, x)
	assert_ok(g.activate_ability(0, mask, 0, [], x))
	resolve_stack()


func test_an_ante_creature_is_not_masked_with_ante_off() -> void:
	assert_false(g.ante_enabled, "a bare duel is not played for ante")
	var mask := put_battlefield(0, "Illusionary Mask")
	var efreet := give_hand(0, "Tempest Efreet")
	assert_ne(g.not_for_ante_refusal(efreet), "", "control: the Efreet can't be cast")
	_activate(mask, 4)
	assert_eq(efreet.zone, Mtg.Zone.HAND, "the Efreet stays in hand")
	assert_false(efreet.face_down)


func test_nothing_left_to_hide_says_why_to_its_controller_only() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	give_hand(0, "Tempest Efreet")
	_activate(mask, 4)
	var found := -1
	for i in g.log_lines.size():
		if g.log_lines[i].begins_with("Illusionary Mask finds nothing to hide"):
			found = i
	assert_gt(found, -1, "the Mask's line")
	if found < 0:
		return
	assert_string_contains(g.log_lines[found], REASON, "its controller reads the reason")
	var meta: Dictionary = g.log_meta[found]
	assert_eq(int(meta.get("private_to", -1)), 0, "a line private to the Mask's controller")
	assert_false(String(meta.get("public", "")).contains("Efreet"),
		"the other seat is not told what the hand holds: %s" % meta.get("public", ""))


func test_the_other_creatures_are_still_offered() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var efreet := give_hand(0, "Tempest Efreet")
	var bears := give_hand(0, "Grizzly Bears")
	var agent := Records.new()
	g.agents[0] = agent
	_activate(mask, 4)
	assert_eq(agent.offered, ["Grizzly Bears"] as Array[String], "the Efreet is not offered")
	assert_false(agent.prompt.contains("Efreet"), "the question names no hand card: %s" % agent.prompt)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bears.face_down, "the Bears masked")
	assert_eq(efreet.zone, Mtg.Zone.HAND)


func test_a_duel_played_for_ante_masks_the_efreet_as_before() -> void:
	g.ante_enabled = true
	var mask := put_battlefield(0, "Illusionary Mask")
	var efreet := give_hand(0, "Tempest Efreet")
	give_hand(0, "Grizzly Bears")
	var agent := Records.new()
	g.agents[0] = agent
	_activate(mask, 4)
	assert_eq(agent.offered, ["Tempest Efreet", "Grizzly Bears"] as Array[String],
		"both offered, the dearer first")
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(efreet.face_down, "masked as before")
