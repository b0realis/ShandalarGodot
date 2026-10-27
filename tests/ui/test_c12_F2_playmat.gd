extends GutTest
## A SEAT'S OWN TERRITORY ON THE DUEL TABLE (the bug campaign c12: the
## playmat, duel side).
##
## [member DuelConfig.territories] carries, per seat, the ground its half
## wears — `{color, type}` — and the adventure's duels put the hero's
## playmat, chosen on the Embark screen, on seat 0. The duel screen wears
## the entry where it names one; where it is `{}` (every plain duel), or
## leaves a half of it out, the Duel Options answer as before.

const SAVED := ["PlayerTerritoryColor", "PlayerTerritoryType"]
## [constant TerritoryGround.GROUND_META]: the ground's key on its node.
const GROUND_META := &"territory_ground"

var screen: DuelScreen
var _saved: Dictionary = {}


func before_each() -> void:
	_saved.clear()
	for key in SAVED:
		if Settings.has_value(key):
			_saved[key] = Settings.get_value(key, null)
	# The Duel Options' own answer, known: the deck's colour, Pattern.
	Settings.set_value("PlayerTerritoryColor", DuelOptions.DECK_COLOR)
	Settings.set_value("PlayerTerritoryType", "Pattern")


func after_each() -> void:
	for key in SAVED:
		if _saved.has(key):
			Settings.set_value(key, _saved[key])
		else:
			Settings.clear_value(key)
	await get_tree().process_frame


func _duel(territories: Array) -> DuelScreen:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.panel_colors = ["white", "black"]
	config.territories = territories
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## The ground key the half of [param pid] is wearing on the table.
func _worn(pid: int) -> String:
	var holder: Control = screen._half_rows[pid].get_parent()
	for child in holder.get_children():
		if child.has_meta(GROUND_META):
			return String(child.get_meta(GROUND_META))
	return ""


func test_seat_zeros_playmat_dresses_its_half() -> void:
	await _duel([{"color": "red", "type": "Mana symbols"}, {}])
	assert_eq(_worn(0), "duel_mana_red", "the playmat, not the deck's white pattern")
	assert_eq(_worn(1), "duel_pattern_black",
		"the other half: the Duel Options' answer, the opponent's deck colour")


func test_an_empty_entry_is_the_duel_options_answer() -> void:
	await _duel([{}, {}])
	assert_eq(_worn(0), "duel_pattern_white", "the deck's colour, the chosen type")
	assert_eq(_worn(1), "duel_pattern_black")


func test_half_an_entry_takes_the_rest_from_the_duel_options() -> void:
	Settings.set_value("PlayerTerritoryType", "Line drawing")
	await _duel([{"color": "", "type": "Mana symbols"}, {"color": "green"}])
	assert_eq(_worn(0), "duel_mana_white", "its type, the Duel Options' colour")
	assert_eq(_worn(1), "duel_picture_green", "its colour, the Duel Options' type")


func test_a_wrong_entry_falls_back_and_never_breaks_the_table() -> void:
	await _duel([{"color": "purple", "type": "Plaid"}, "nonsense"])
	assert_eq(_worn(0), "duel_pattern_white")
	assert_eq(_worn(1), "duel_pattern_black")


## Closing Duel Options repaints every half; a dressed one keeps its mat.
func test_the_duel_options_redress_keeps_the_playmat() -> void:
	await _duel([{"color": "blue", "type": "Line drawing"}, {}])
	Settings.set_value("PlayerTerritoryColor", "Green")
	Settings.set_value("PlayerTerritoryType", "Mana symbols")
	screen._on_duel_options_closed()
	assert_eq(_worn(0), "duel_picture_blue", "the playmat stays")
	assert_eq(_worn(1), "duel_mana_black", "the other half follows the new type")

