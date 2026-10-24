class_name WorldEncounters
extends RefCounted
## MEETING A CREATURE ON THE WORLD — the door between the creatures on the map
## ([WorldCreatures], whose contact test finds the meeting) and the meeting
## itself (its pane, its duel and what comes after).
##
## THE CONTRACT (part B, 2026-10-23):
##  - [method WorldScreen.meet_creature] stops the walk, saves the adventure
##    with the creature still on the map (1997 saved before every meeting, so
##    quitting mid-duel meets it again — the owner's ruling), and calls
##    [method open] with the roaming slot met.
##  - [method open] puts the meeting's pane over the world and returns it
##    (a Control child of [param screen]; while it lives the world waits,
##    [method WorldScreen.modal]). It emits `finished(result: int)` once when
##    the meeting is over — 1 the duel won, 0 lost, −1 drawn, 2 no duel
##    (paid, a riddle answered or missed, a tribute taken) — and frees itself.
##  - [method WorldScreen.meet_creature] then spends the slot
##    ([method WorldCreatures.met]) and saves again, as 1997 did.
## null from [method open] means no meeting could be held; the world spends
## the slot as met without a duel.
##
## WHAT [method open] BUILDS (part B, W5): the meeting drawn
## ([method CreatureMeeting.begin]: the antes on the adventure's dice), its
## pane ([EncounterPane]) centred over the world, a card right-clicked on it
## read full screen ([method WorldScreen.read_card]). The pane holds the
## duel itself over the world ([WorldDuels], which asks [method
## WorldScreen.hold_for_duel]) and settles it ([DuelSpoils]).
##
## TWO MORE ENDS than the contract's four:
##  - [constant GAME_OVER] (3) — the deck in use holds no card to stake: the
##    pane said 1997's "You have no power for even an Ante!" (`@QUESTFAILED`
##    0, 1, 4, 5 — `ExitIfNoUsableDeckCards`, visitLocation.c 2252, which
##    then ended the program). THE HOOK FOR THE ADVENTURE'S END (part B,
##    W7): the world screen's `finished` handler shows the end screen
##    (`game_over`, `Uth-Arz.pic`) for this result instead of saving and
##    going on; until it does, the meeting is spent as no duel.
##  - "Return to main menu" in the duel: no `finished` at all — the world
##    screen goes to the title without saving ([WorldDuels]; the owner's
##    ruling 4).
## A hero teleported by the spoils is looked at where they stand; a World
## Magic's town found by a tribute shows the map once the meeting is spent.

## The meeting's ends ([constant WorldCreatures.WON] … NO_DUEL), and the
## game's end with nothing to stake.
const WON := 1
const LOST := 0
const DRAWN := -1
const NO_DUEL := 2
const GAME_OVER := EncounterPane.GAME_OVER


## The meeting with the creature in roaming slot [param slot], over
## [param screen]; null when none can be held.
static func open(screen: Node, slot: int) -> Control:
	var player: AdventurePlayer = screen.get("player") if screen != null else null
	if player == null:
		return null
	var meeting := CreatureMeeting.begin(player, slot)
	if meeting.is_empty():
		return null
	var pane := EncounterPane.new()
	pane.player = player
	pane.screen = screen
	pane.meeting = meeting
	var hud: Variant = screen.get("hud")
	if hud is WorldHud and (hud as WorldHud).big:
		pane.k = WorldHud.BIG
	screen.add_child(pane)
	PaneStyle.centre(pane)
	if screen.has_method("read_card"):
		pane.card_read.connect(func(card_name: String) -> void: screen.call("read_card", card_name))
	return pane
