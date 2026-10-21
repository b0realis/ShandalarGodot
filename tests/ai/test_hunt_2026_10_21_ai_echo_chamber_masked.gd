extends GameTest
## ECHO CHAMBER AND THE MASK (bug hunt 2026-10-21, ai; CONTRIBUTING.md rule 8).
##
## Echo Chamber — "an opponent chooses target creature they control; create
## a token that's a copy of it, with haste, exiled at the next end step" —
## is priced by the Alliances arm `hasty_token` ([method
## AlliancesTactics.option]) at the body they would pick, and at nothing
## when that body's copy would not stay: a Phyrexian Dreadnought's "sacrifice
## it unless ... total power 12" ([method MirageTactics.dies_on_arrival],
## which reads the PRINTED card). A face-down creature's copy is a plain 2/2
## (CR 707.2, 708.2) — and the printed card under THEIR mask is hidden:
## behind a masked Dreadnought the Chamber was worth nothing, behind a
## masked Grizzly Bears a 2/2's worth. A masked body is read as the 2/2 it
## is now; face up, the Dreadnought is a copy that does not stay again (the
## control).

const A := preload("res://engine/ai/alliances_tactics.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in ["pack-8", "pack-9"])


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Their only creature (face down unless [param face_up]); our Echo Chamber
## and four Mountains, our first main phase. What the Chamber is worth.
func _chamber(creature: String, face_up := false) -> Variant:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var body := put_battlefield(1, creature)
	if not face_up:
		g.turn_face_down(body)
	for n in 4: put_battlefield(0, "Mountain")
	var chamber := put_battlefield(0, "Echo Chamber")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	return A.option(g, ai, chamber, 0, "MAIN")


func test_what_the_mask_hides_moves_nothing() -> void:
	var dread: Variant = _chamber("Phyrexian Dreadnought")
	var bears: Variant = _chamber("Grizzly Bears")
	assert_eq(str(dread), str(bears), "the same 2/2 copy behind either mask")


func test_a_face_up_dreadnought_is_a_copy_that_does_not_stay() -> void:
	assert_eq(_chamber("Phyrexian Dreadnought", true), {}, "sacrificed as it arrives")
