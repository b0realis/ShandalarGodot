extends GameTest
## THE MANA VALUE UNDER THE MASK (bug hunt 2026-10-21, ai; CONTRIBUTING.md
## rule 8).
##
## A face-down creature (Illusionary Mask) has mana value 0 (CR 708.2), and
## the card under it is hidden. Two of the fair pilot's arms read the
## printed cost of the opponent's creatures anyway:
##  * TARIFF ([method MirageTactics.role_choice], `tariff`): "each player
##    sacrifices the creature with the highest mana value unless he or she
##    pays it". The card's own resolution reads the COPIABLE values
##    (`g.copiable_data`, 0 for a masked creature); the pilot read the
##    printed one, so a masked Force of Nature beside their Grizzly Bears
##    and two Forests made Tariff worth 4.0 (the masked 2/2 "can't pay its
##    six"), and a masked Llanowar Elves made it worth nothing. The spell
##    would really have asked them for the Bears' two.
##  * PLAGUEBEARER ([method AlliancesTactics.option], `exact_mv_removal`):
##    "{X}{X}{B}: destroy target nonblack creature with mana value X". X
##    was sized to the masked card's printed value — X=2 for a masked
##    Grizzly Bears, nothing for a masked Craw Wurm: the one X that kills
##    what nobody showed.
## Both read the copiable mana value now; turned face up, the creature is
## priced by its card again (the public-change controls).

const MIRAGE := preload("res://engine/ai/mirage_tactics.gd")
const ALLIANCES := preload("res://engine/ai/alliances_tactics.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in ["pack-8", "pack-9"])


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Their creature (face down unless [param face_up]), their Grizzly Bears
## and two Forests; Tariff in our hand.
func _tariff(creature: String, face_up := false) -> Variant:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var body := put_battlefield(0, creature)
	if not face_up:
		g.turn_face_down(body)
	put_battlefield(0, "Grizzly Bears")
	for n in 2: put_battlefield(0, "Forest")
	var ai := AiPlayer.new(1, AiProfile.wizard())
	return MIRAGE.role_choice(g, ai, give_hand(1, "Tariff"))


func test_tariff_reads_no_mask() -> void:
	var big: Variant = _tariff("Force of Nature")
	var small: Variant = _tariff("Llanowar Elves")
	assert_eq(str(big), str(small), "what the mask hides moves nothing")
	assert_eq(str(big), "{  }", "the Bears are the victim, and they can pay its two")


## THE PUBLIC-CHANGE CONTROL: a face-up Force of Nature is the victim, and
## two Forests do not pay its six.
func test_a_face_up_force_of_nature_is_the_victim() -> void:
	var choice: Variant = _tariff("Force of Nature", true)
	assert_true(choice is Dictionary and float((choice as Dictionary).get("value", 0.0)) >= 2.0,
		"Tariff is worth casting at a Force of Nature they cannot pay for")


## Their creature (face down unless [param face_up]); our Plaguebearer and
## five Swamps.
func _plague(creature: String, face_up := false) -> Variant:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var body := put_battlefield(0, creature)
	if not face_up:
		g.turn_face_down(body)
	for n in 5: put_battlefield(1, "Swamp")
	var plague := put_battlefield(1, "Plaguebearer")
	var ai := AiPlayer.new(1, AiProfile.wizard())
	return ALLIANCES.option(g, ai, plague, 0, "MAIN")


func test_plaguebearer_sizes_no_x_to_a_mask() -> void:
	var bears: Variant = _plague("Grizzly Bears")
	var wurm: Variant = _plague("Craw Wurm")
	assert_eq(str(bears), str(wurm), "what the mask hides moves nothing")
	if bears is Dictionary and not (bears as Dictionary).is_empty():
		assert_eq(int((bears as Dictionary).get("x", -1)), 0,
			"a face-down creature's mana value is 0")


## THE PUBLIC-CHANGE CONTROL: face-up Bears are killed at X=2.
func test_plaguebearer_still_kills_face_up_bears() -> void:
	var choice: Variant = _plague("Grizzly Bears", true)
	assert_true(choice is Dictionary and not (choice as Dictionary).is_empty(), "the Bears are a target")
	assert_eq(int((choice as Dictionary).get("x", -1)), 2)
