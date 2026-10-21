extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: a face-down permanent
## that is phased out keeps its secret.
##
## WAS: `DuelScreen._on_card_clicked` answers a click on a phased-out
## permanent before anything else ("X is phased out. Phases in at ..."), and
## that branch had no face-down guard: a click on an Illusionary Mask
## creature phased out by Oubliette, Reality Ripple or its own phasing put
## the real card in the Showcase and its name on the Situation Bar — to
## either seat — where the hover, the card menu, the piles and the
## graveyard view all keep it face down (`docs/card-states.md` §5.1). NOW
## the Showcase shows the back and the bar says "A face-down creature".

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _summon(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func test_a_click_on_a_phased_out_face_down_card_names_nothing(seat = use_parameters([0, 1])) -> void:
	var lion := _summon(int(seat), "Savannah Lions")
	screen.game.turn_face_down(lion)
	assert_true(screen.game.phase_out(lion), "control: phased out")
	screen._refresh()
	screen._card_preview.show_back()
	screen._on_card_clicked(lion)
	assert_true(screen._card_preview._back.visible, "the Showcase keeps the card back")
	var said := screen._prompt_label.text
	assert_false(said.contains("Savannah Lions"), "the bar does not name it: " + said)
	assert_string_contains(said, "A face-down creature is phased out.")


func test_an_open_phased_out_card_still_reads() -> void:
	var lion := _summon(1, "Savannah Lions")
	assert_true(screen.game.phase_out(lion))
	screen._refresh()
	screen._card_preview.show_back()
	screen._on_card_clicked(lion)
	assert_false(screen._card_preview._back.visible, "a public card fills the Showcase")
	assert_string_contains(screen._prompt_label.text, "Savannah Lions is phased out.")
