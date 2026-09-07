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
## hook was built for.


func _ready() -> void:
	GameDisplay.apply_settings()


func _exit_tree() -> void:
	CardRegistry.unload()
