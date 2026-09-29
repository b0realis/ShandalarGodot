extends Node
## THE PROCESS-END HOOK — an autoload whose job is to leave the tree
## last and, on the way out, drop the card database while the card
## scripts are still loaded ([method CardRegistry.unload]) — and, since
## 2026-09-07, to enter it first (see the end of this doc).
##
## WHY A NODE, AND WHY AN AUTOLOAD. The abort this cures (see the doc on
## `CardRegistry.unload`) happens AFTER `quit()`, during static-variable
## teardown, so no `quit()` call site can fix it by itself and there are
## eight of them across the game and the tools. An autoload is the one
## thing every entry point shares: the main scene, GUT's `extends
## SceneTree` runner and every `extends SceneTree` tool all get it, and
## `SceneTree.finalize` sends every node `NOTIFICATION_EXIT_TREE` before
## static state is torn down. So the hook needs no call and cannot be
## forgotten — which is the property the eight call sites lacked.
##
## Autoloads sit before the current scene under the root and leave the
## tree AFTER it (the propagation runs children in reverse order), so by
## the time this runs the duel or the deck builder has already gone.
##
## AND THE PROCESS-START HOOK, for the same reason in reverse: an autoload
## is ready BEFORE the first scene, so a setting that has to be on the
## window before anything is drawn — `[QoL]` `Full screen`, [GameDisplay]
## — goes on here, once, and the title screen opens into it. Nothing in
## the scenes has to remember to do it, which is the property the exit
## hook was built for. The tooltip shaper ([method UiChrome.watch_tooltips],
## 2026-09-18) hangs on the tree here for the same reason: one process,
## one hook, every hover text wrapped to the window. And the Android
## corner ([AndroidCorner], 2026-09-29) is made here for the same reason
## again: before the autoloads that read it.


func _ready() -> void:
	GameDisplay.apply_settings()
	# The player's own keys over the project's defaults ([Controls]),
	# before any screen reads the map.
	Controls.apply()
	UiChrome.watch_tooltips(get_tree())
	# On Android the corner the player pushes into is made here, before
	# SkinPack and CardPacks read it, and what is there goes to the log
	# and to the start report in the corner ([AndroidCorner]); the tracer
	# joins the tree last of all, after the first scene, so it sees an
	# event before any layer eats it.
	if OS.has_feature("android"):
		var corner := GamePaths.android_files_dir()
		AndroidCorner.prepare(corner)
		var tracer := AndroidCorner.new()
		tracer.corner = corner
		tracer.say(AndroidCorner.version_line())
		for line in AndroidCorner.report(corner):
			tracer.say(line)
		get_tree().root.add_child.call_deferred(tracer)


func _exit_tree() -> void:
	CardRegistry.unload()


## THE ANDROID BACK GESTURE IS ESCAPE (2026-09-29, the Meta Quest
## panel). Godot's default answers it by quitting the game
## (`application/config/quit_on_go_back`, off in project.godot): a
## thumb on the back of a duel would end the process. Escape is what
## every screen already answers — the pause menu, a closed view, a
## cancelled cast — so the request becomes one press and release of
## that key, through the same door a keyboard's goes. Public, so a test
## can send the notification itself.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.physical_keycode = KEY_ESCAPE
			key.pressed = pressed
			Input.parse_input_event(key)
