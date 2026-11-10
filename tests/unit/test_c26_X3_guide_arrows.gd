extends GutTest
## THE GUIDE ARROWS (the owner's ruling of 2026-11-03: *"In tasks a user
## can choose multiple arrows, the portal arrow is of different color and
## overlaid on other arrows but the user can disable special portal arrow in
## tasks if he/she wishes"*; 0.60.13 bug campaign, c26, fixer X3): several
## tasks tracked at once, an arrow each; Automatic guidance the default;
## Arzakon's portal in its own ink, drawn over the others whenever it is a
## target, its automatic arrow switched off in Tasks; the choice saved so
## that 0.60.12 and older read several tasks as Automatic guidance.

const SIEGE := {"tile": Vector2i(12, 30), "kind": "siege", "name": "Kraag Temple"}
const QUEST := {"tile": Vector2i(40, 9), "kind": "quest", "name": "Velmar Village"}
const PORTAL := {"tile": Vector2i(31, 31), "kind": "portal", "name": "Arzakon's Portal"}
const MONUMENT := {"tile": Vector2i(31, 31), "kind": "monument", "name": "Arzakon's Petrified Portal"}
var _portal_before: bool


func before_each() -> void:
	_portal_before = WorldGuides.portal_wanted()
	WorldGuides.want_portal(true)


func after_each() -> void:
	WorldGuides.want_portal(_portal_before)


func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "4242"
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _reloaded(player: AdventurePlayer) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))


func _targets(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for each in list:
		out.append((each as Dictionary).duplicate())
	return out


func _names(guided: Array[Dictionary]) -> Array:
	return guided.map(func(target: Dictionary) -> String: return target.get("id", target["name"]))


func _castle(player: AdventurePlayer, color: int) -> Vector2i:
	var castle: Dictionary = player.world.encounters[color]
	return Vector2i(int(castle["x"]), int(castle["y"]))


# ---------------------------------------------------- several at once --

func test_several_tasks_guide_at_once_an_arrow_each() -> void:
	var player := _hero()
	var ordinary := _targets([SIEGE])
	assert_eq(_names(AdventureTasks.guide(player, ordinary)), ["Kraag Temple"], "Automatic guidance: the first target")
	assert_true(AdventureTasks.toggle(player, "mainland/wizard:0"))
	assert_true(AdventureTasks.toggle(player, "mainland/wizard:3"))
	var guided := AdventureTasks.guide(player, ordinary)
	assert_eq(guided.size(), 2, "an arrow for each chosen task, none automatic")
	assert_eq(guided.map(func(target: Dictionary) -> Vector2i: return target["tile"]).has(_castle(player, 0)), true)
	assert_eq(guided.map(func(target: Dictionary) -> Vector2i: return target["tile"]).has(_castle(player, 3)), true)
	assert_eq(AdventureTasks.tracked(player).size(), 2)
	assert_eq(player.tracked_task, "", "several: the old string reads as Automatic guidance")
	assert_true(AdventureTasks.toggle(player, "mainland/wizard:0"), "a second click takes the arrow away")
	assert_eq(_names(AdventureTasks.guide(player, ordinary)), ["mainland/wizard:3"])
	assert_eq(player.tracked_task, "mainland/wizard:3", "one: the old string names it")
	assert_true(AdventureTasks.select(player, ""), "Automatic guidance clears the choice")
	assert_true(AdventureTasks.tracked(player).is_empty())
	assert_eq(_names(AdventureTasks.guide(player, ordinary)), ["Kraag Temple"])


func test_a_finished_or_unknown_task_cannot_be_chosen() -> void:
	var player := _hero()
	assert_false(AdventureTasks.toggle(player, "mainland/wizard:9"))
	player.defeated_wizards.append("black")
	assert_false(AdventureTasks.toggle(player, "mainland/wizard:0"), "a beaten wizard's task is finished")
	assert_true(AdventureTasks.toggle(player, "mainland/wizard:1"))
	player.defeated_wizards.append("blue")
	assert_true(AdventureTasks.tracked(player).is_empty(), "a chosen task that finishes is chosen no more")
	assert_eq(player.tracked_task, "")


# ------------------------------------------------------------ the save --

func test_several_chosen_tasks_are_saved_and_older_builds_read_automatic() -> void:
	var player := _hero()
	AdventureTasks.toggle(player, "mainland/wizard:0")
	AdventureTasks.toggle(player, "mainland/wizard:2")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(saved["tasks"]["selected"], "", "0.60.12 reads the old string: Automatic guidance")
	var restored := AdventurePlayer.from_dict(saved)
	assert_not_null(restored)
	if restored == null: return
	var chosen := AdventureTasks.tracked(restored)
	chosen.sort()
	assert_eq(chosen, ["mainland/wizard:0", "mainland/wizard:2"] as Array[String])
	# As 0.60.12 would: its own read keeps every history field it knows and
	# looks only at "selected" — the extra field reads as nothing.
	for id in saved["tasks"]["history"]:
		var entry: Dictionary = saved["tasks"]["history"][id]
		for field in ["title", "text", "region", "kind", "status"]: assert_true(entry[field] is String, id + " " + field)


func test_one_chosen_task_saves_as_the_old_string_and_an_old_save_reads_it() -> void:
	var player := _hero()
	AdventureTasks.toggle(player, "mainland/wizard:4")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(saved["tasks"]["selected"], "mainland/wizard:4", "0.60.12 follows it too")
	for id in saved["tasks"]["history"]: saved["tasks"]["history"][id].erase(AdventureTasks.GUIDED)
	var old := AdventurePlayer.from_dict(saved)
	assert_not_null(old)
	if old == null: return
	assert_eq(AdventureTasks.tracked(old), ["mainland/wizard:4"] as Array[String], "a save of 0.60.12: its one task")
	assert_eq(_names(AdventureTasks.guide(old, _targets([SIEGE]))), ["mainland/wizard:4"])


func test_a_misshapen_choice_in_a_save_is_dropped() -> void:
	var player := _hero()
	AdventureTasks.toggle(player, "mainland/wizard:0")
	AdventureTasks.toggle(player, "mainland/wizard:1")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	saved["tasks"]["history"]["mainland/wizard:0"][AdventureTasks.GUIDED] = "yes"
	saved["tasks"]["history"]["mainland/wizard:1"][AdventureTasks.GUIDED] = [true]
	var restored := AdventurePlayer.from_dict(saved)
	assert_not_null(restored)
	if restored == null: return
	assert_true(AdventureTasks.tracked(restored).is_empty(), "nothing chosen: Automatic guidance")
	assert_false(restored.task_history["mainland/wizard:0"].has(AdventureTasks.GUIDED))


func test_a_choice_written_in_the_old_string_alone_replaces_the_flags() -> void:
	var player := _hero()
	AdventureTasks.toggle(player, "mainland/wizard:0")
	player.tracked_task = "mainland/wizard:1" # the debug teleport, an older build's save
	assert_eq(AdventureTasks.tracked(player), ["mainland/wizard:1"] as Array[String])
	player.tracked_task = ""
	assert_true(AdventureTasks.tracked(player).is_empty())


# ------------------------------------------------------- the portal arrow --

func test_the_portal_arrow_comes_last_over_every_guidance() -> void:
	var player := _hero()
	var ordinary := _targets([SIEGE, QUEST, PORTAL])
	var automatic := AdventureTasks.guide(player, ordinary)
	assert_eq(_names(automatic), ["Kraag Temple", "Arzakon's Portal"], "Automatic guidance and the portal")
	assert_true(automatic[1].get("overlay", false))
	assert_eq(_names(AdventureTasks.guide(player, _targets([PORTAL, SIEGE]))), ["Kraag Temple", "Arzakon's Portal"],
		"the portal is never the automatic arrow itself: it has its own")
	AdventureTasks.toggle(player, "mainland/wizard:2")
	assert_eq(_names(AdventureTasks.guide(player, ordinary)), ["mainland/wizard:2", "Arzakon's Portal"], "a chosen task and the portal")
	assert_eq(_names(AdventureTasks.guide(player, _targets([SIEGE, MONUMENT]))), ["mainland/wizard:2", "Arzakon's Petrified Portal"], "petrified too")
	assert_eq(_names(AdventureTasks.guide(player, _targets([SIEGE]))), ["mainland/wizard:2"], "no portal, no portal arrow")


func test_a_chosen_portal_task_is_not_drawn_twice() -> void:
	var player := _hero()
	player.portal = {"x": 31, "y": 31, "state": FinalBattle.PORTAL_OPEN}
	assert_true(AdventureTasks.toggle(player, "mainland/finale"))
	var portal_at := FinalBattle.portal_tile_of(player)
	var mark := PORTAL.duplicate()
	mark["tile"] = portal_at
	var guided := AdventureTasks.guide(player, _targets([SIEGE, mark]))
	assert_eq(guided.size(), 1, "one arrow to the portal: %s" % [_names(guided)])
	assert_eq(guided[0]["id"], "mainland/finale")
	assert_false(guided[0].get("overlay", false), "the chosen task, kept with the switch off")


func test_the_portal_has_its_own_ink_drawn_over_and_its_own_switch() -> void:
	assert_ne(WorldGuides.ink_for("portal"), WorldGuides.GOLD)
	assert_ne(WorldGuides.ink_for("portal"), WorldGuides.SIEGE)
	assert_eq(WorldGuides.ink_for("portal"), WorldGuides.PORTAL)
	assert_eq(WorldGuides.ink_for("monument"), WorldGuides.PORTAL)
	var guides := WorldGuides.new()
	var overlay := PORTAL.duplicate()
	overlay["overlay"] = true
	guides.targets = _targets([overlay, SIEGE, QUEST])
	assert_eq(guides.drawn().map(func(target: Dictionary) -> String: return target["kind"]), ["siege", "quest", "portal"], "the portal drawn last, over the others")
	WorldGuides.want_portal(false)
	assert_eq(guides.drawn().map(func(target: Dictionary) -> String: return target["kind"]), ["siege", "quest"], "switched off in Tasks")
	var chosen := PORTAL.duplicate()
	chosen["id"] = "mainland/finale"
	guides.targets = _targets([chosen, SIEGE])
	assert_eq(guides.drawn().size(), 2, "a chosen portal task still shows")
	guides.free()


func test_an_arrows_name_never_covers_the_arrow() -> void:
	# Seen in the candidates' screenshots: at a side of the screen the name,
	# held on the screen, was written over its own arrow.
	for degrees in range(0, 360, 5):
		var way := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		var at := Vector2(640, 400)
		var side := way.orthogonal()
		var arrow := Rect2(at + way * 14.0, Vector2.ZERO)
		for point in [at - way * 10.0 + side * 11.0, at - way * 10.0 - side * 11.0, at - way * 4.0]: arrow = arrow.expand(point)
		var label := WorldGuides.arrow_label_at(at, way)
		for width in [60.0, 140.0]:
			# Held on the screen: the name may slide along its line, so any
			# stretch of it across the arrow's columns counts.
			var text := Rect2(label.x - width, label.y - 14.0, width * 2.0, 17.0)
			assert_false(text.intersects(arrow), "%d°: the name at %s over the arrow %s" % [degrees, label, arrow])
