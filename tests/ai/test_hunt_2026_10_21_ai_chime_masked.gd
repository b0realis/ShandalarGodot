extends GameTest
## THE CHIME AND THE MASK (bug hunt 2026-10-21, ai; CONTRIBUTING.md rule 8).
##
## Apocalypse Chime — "{2}, {T}, Sacrifice: destroy all nontoken permanents
## originally printed in the Homelands expansion" — is weighed by the
## Homelands arm `set_sweep` ([method HomelandsTactics.option]): their
## Homelands permanents gained, ours lost. It read each permanent's printed
## NAME, a face-down one's included — and a face-down permanent has no
## name (CR 708.2) and hides its card. A masked Ihsan's Shade made the
## Chime worth 4.0 to sacrifice; a masked Craw Wurm made it worth nothing.
## A masked permanent is no Homelands permanent now; turned face up, the
## Shade is (the public-change control).

const HOMELANDS := preload("res://engine/ai/homelands_tactics.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-4")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Their creature (face down unless [param face_up]); our Chime and two
## Swamps to pay for it.
func _chime(creature: String, face_up := false) -> Variant:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var body := put_battlefield(0, creature)
	if not face_up:
		g.turn_face_down(body)
	for n in 2: put_battlefield(1, "Swamp")
	var chime := put_battlefield(1, "Apocalypse Chime")
	var ai := AiPlayer.new(1, AiProfile.wizard())
	return HOMELANDS.option(g, ai, chime, 0, "MAIN")


func test_what_the_mask_hides_moves_nothing() -> void:
	var shade: Variant = _chime("Ihsan's Shade")
	var wurm: Variant = _chime("Craw Wurm")
	assert_eq(str(shade), str(wurm), "the same reading behind either mask")
	assert_eq(str(shade), "{  }", "nothing of theirs is a Homelands permanent")


func test_a_face_up_shade_is_worth_the_chime() -> void:
	var shade: Variant = _chime("Ihsan's Shade", true)
	assert_true(shade is Dictionary and float((shade as Dictionary).get("value", 0.0)) > 0.0,
		"their Shade, face up, is what the Chime is for")
