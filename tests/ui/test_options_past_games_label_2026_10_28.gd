extends GutTest
## THE GAME RECORDS' OWN HEADING on the Options screen
## (`game/options_screen.gd`). The stale-docs list of 2026-10-28 found
## "View past-played games" under the "Booster Draft:" label, so the
## game-record viewer read as part of the draft. It now stands under its
## own "Game records:" label, ahead of the draft's; the draft's button stays
## under "Booster Draft:".

var screen: Control


func before_each() -> void:
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


## The section heading (a label ending in ":") nearest above the control
## named [param node_name] in the panel's list, "" for none.
func _heading_above(node_name: String) -> String:
	var target := screen.find_child(node_name, true, false) as Control
	assert_not_null(target, node_name)
	if target == null:
		return ""
	var heading := ""
	for child in target.get_parent().get_children():
		if child == target:
			return heading
		if child is Label and (child as Label).text.ends_with(":"):
			heading = (child as Label).text
	return ""


func test_past_games_has_its_own_heading() -> void:
	assert_eq(_heading_above("ViewPastGames"), "Game records:",
		"the game-record viewer is not part of the Booster Draft")


func test_the_draft_keeps_its_heading() -> void:
	assert_eq(_heading_above("LaunchDraftSetup"), "Booster Draft:")
