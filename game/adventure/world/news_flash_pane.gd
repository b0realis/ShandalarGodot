class_name NewsFlashPane
extends VisitPane
## THE NEWS FLASH (part B, 2026-10-23) — what 1997 showed in its map window
## as a wizard began a siege or took a town ([Sieges]): `Newsback.pic`
## zoomed in (`visit_news`), `Newsflash.wav` (`sfx_newsflash`), the words of
## `@NEWSFLASH` under "--- NEWS FLASH ---" — "Black Wizard sends a Witch to
## attack Kraag Temple!"; "The Evil Red Wizardess taps Kraag Temple!", "She
## needs 2 more mana taps to cast the Spell of Dominion!", "Your mana tap
## here is lost." — and a wait for a key (`WaitForInputEventUnlessBlocked`).
## Here the visit pane's glass over the world, which waits under it: one
## choice, Continue (Enter and Escape too), and [signal VisitPane.left]
## with "" once read. The town concerned is named under the title.
##
## [QoL, the lead's default: the news stops the hero's walk — the panes
## hold the world (1997 let a walk held by the arrow keys go on after the
## key was read).]

const CONTINUE := "Continue"

## The news ([method Sieges.on_step]: `{kind, lines, town, wizard,
## creature}`).
var news := {}


## The pane's place for [param shown] news of [param hero]'s world.
static func place_of(hero: AdventurePlayer, shown: Dictionary) -> Dictionary:
	var town := int(shown.get("town", -1))
	var named := WorldNames.site_name(hero.world, town) if Quests.is_site(hero.world, town) else ""
	return {"kind": "news", "slot": town, "name": Sieges.NEWS_FLASH, "subtitle": named,
		"picture": "visit_news", "lines": (shown.get("lines", []) as Array).duplicate(),
		"actions": [["continue", CONTINUE, true]]}


func _ready() -> void:
	if place.is_empty():
		place = place_of(player, news)
	super._ready()
	name = "NewsFlashPane"
	WorldSoundscape.play_from(self, "sfx_newsflash")


## Continue: the news read.
func choose(action: String) -> void:
	if action == "continue":
		left.emit("")
		return
	super.choose(action)


## Enter, like Escape, reads on.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		left.emit("")
