extends GameTest
## Gap review 2026-11-10, r1b-4 (fair play, CONTRIBUTING.md rule 8):
## tempest_tactics.gd `licid_twin_key` keyed a host by its printed name —
## for a FACE-DOWN host of theirs (Illusionary Mask) the hidden card under
## the mask. Two face-down 2/2s look the same to our seat (CR 708.2), but
## whether they were "twins" (one dressed, the other skipped), and so the
## hosts read and the node budget every reading ran at, moved with what
## was hidden.

const TT := preload("res://engine/ai/tempest_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = true
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _masked(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	inst.face_down = true
	return inst


func _read(hidden: Array) -> Dictionary:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var masks: Array = []
	for n in hidden:
		masks.append(_masked(1, n))
	put_battlefield(1, "Welkin Hawk")
	g.recalculate()
	advance_to_step(Mtg.Step.MAIN1)
	for m in masks:
		assert_eq((m as CardInstance).cur_power, 2)
		assert_eq((m as CardInstance).cur_toughness, 2)
	var a: ActivatedAbility = licid.cur_activated_abilities[0]
	var found: Dictionary = TT.licid_hosts(g, ai, licid, a)
	var plan: Dictionary = TT.licid_plan(g, ai)
	var did := ai.act(g)
	return {"theirs": found["theirs"].size(), "dressed": int(found["dressed"]),
		"nodes": int(plan["nodes"]), "did": did}


func test_two_masks_read_the_same_whatever_is_under_them() -> void:
	var answers: Array = []
	for variant in 3:
		before_each()
		answers.append(_read([["Grizzly Bears", "Grizzly Bears"], ["Grizzly Bears", "Hill Giant"],
			["Shivan Dragon", "Llanowar Elves"]][variant]))
		after_each()
	gut.p("hidden: same %s / other %s / third %s" % answers)
	for i in [1, 2]:
		assert_eq(answers[0]["theirs"], answers[i]["theirs"], "hosts read moved with the hidden card")
		assert_eq(answers[0]["dressed"], answers[i]["dressed"], "dressings moved with the hidden card")
		assert_eq(answers[0]["nodes"], answers[i]["nodes"], "the search budget moved with the hidden card")
		assert_eq(answers[0]["did"], answers[i]["did"], "the decision moved with the hidden card")


## The key itself: two face-down hosts are twins whatever they hide (a
## face-down permanent is a nameless 2/2 with no text, CR 708.2); face up,
## different cards are not.
func test_the_twin_key_hides_a_face_down_card() -> void:
	var bears := _masked(1, "Grizzly Bears")
	var giant := _masked(1, "Hill Giant")
	g.recalculate()
	assert_eq(TT.licid_twin_key(bears), TT.licid_twin_key(giant))
	assert_false(TT.licid_twin_key(bears).contains("Grizzly"))
	var open_bears := put_battlefield(1, "Grizzly Bears")
	var open_giant := put_battlefield(1, "Hill Giant")
	assert_ne(TT.licid_twin_key(open_bears), TT.licid_twin_key(open_giant))
