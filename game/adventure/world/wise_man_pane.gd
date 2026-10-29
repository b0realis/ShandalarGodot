class_name WiseManPane
extends VisitPane
## THE WISE MAN'S ROOM — `Wiseman3.pic` in the visit pane's glass, what he
## says page by page ([WiseMan]), or the town's quest offered ([Quests]):
## "Take this message North to my brother, the keeper of Kraag Temple. He
## will reward you with a mana link." — or a creature's (part B): "Defeat
## the Witch which has been menacing our village. Return here and I will
## reward you with 1 black amulet." ([method Quests.offer_words]) —
## "Accept the Quest." / "Never mind." (Never mind keeps the offer, as
## 1997's did.)
## A gift that asks a choice asks it here: whose deck to see (then shown by
## the world screen, [CardListPane]), or the card to copy. A town that turns
## the hero away ([TownStatus.NO_QUESTS]) says so and offers no quest,
## however the pane was opened ([method refused]). As every place's pane
## ([VisitPane]): the room zooms in as 1997's did (`AnimateVisitBackdropZoomIn`
## of `wiseman3.pic`, visitLocation.c 877, 893, 3094; [TileReveal]), and a
## choice answers to its first letter — "G" Go on, "L" Leave, "A" Accept the
## Quest — Enter or Space to take it.

## The copy gift wants a card picked, three amulets of [param color] its price.
signal copying(color: int)

## `talk` for the wise man's words, `quest` for the town's offer.
var mode := "talk"
## What he says ([method WiseMan.speak]).
var talk := {}
var _page := 0


## The place for the pane: the wise man of town [param slot].
static func place_of(hero: AdventurePlayer, slot: int) -> Dictionary:
	return {"kind": "wiseman", "slot": slot, "name": WorldNames.site_name(hero.world, slot),
		"subtitle": "Wise Man", "picture": "visit_wiseman", "lines": [], "actions": []}


func _ready() -> void:
	super._ready()
	name = "WiseManPane"
	if mode == "quest":
		_offer_quest()
	else:
		talk = WiseMan.speak(player, int(place["slot"]))
		_show_page(0)


## Whether this town turns the hero away: a quest it gave was failed. 1997's
## `VisitTownWiseman` looks at that first (status & 4, visitLocation.c
## 876–889), before any talk or offer.
func refused() -> bool:
	return TownStatus.refuses_quests(player.world, int(place["slot"]))


## The town's quest, offered — or, where the town turns the hero away, its
## refusal in the wise man's words ([constant WiseMan.REFUSAL]).
func _offer_quest() -> void:
	if refused():
		say([WiseMan.REFUSAL])
		offer([["leave", "Leave", true]])
		return
	say(Array(Quests.offer_words(player)))
	offer([["accept", "Accept the Quest.", true], ["leave", "Never mind.", true]])


## Page [param index] of the talk: Go on to the next, or what follows.
func _show_page(index: int) -> void:
	var pages: PackedStringArray = talk.get("pages", PackedStringArray())
	_page = index
	say([pages[index]] if index < pages.size() else [])
	if index < pages.size() - 1:
		offer([["next", "Go on", true], ["leave", "Leave", true]])
		return
	match String(talk.get("then", "")):
		"deck":
			ask_whose_deck(int(talk.get("color", 1)))
		"copy":
			offer([["copy", "Pick a spell", true], ["leave", "Never mind.", true]])
		_:
			offer([["leave", "Leave", true]])


## The copy gift's card was picked: [param card_name] copied.
func copied(card_name: String) -> void:
	var color := int(talk.get("color", 1))
	if WiseMan.copy(player, card_name, color):
		say(["Another %s joins your cards." % card_name])
	elif player.bag_room() < 1:
		say([AdventurePlayer.BAG_FULL])
	elif not CardShop.may_offer(player, card_name):
		say([CardShop.classic_refusal(card_name, player.ban_list)])
	offer([["leave", "Leave", true]])


## A creature's deck has been seen.
func deck_seen() -> void:
	offer([["leave", "Leave", true]])


func choose(action: String) -> void:
	match action:
		"next":
			_show_page(_page + 1)
		"accept":
			if refused():
				_offer_quest()
				return
			var said := Quests.accept(player, int(place["slot"]))
			say([said])
			offer([["leave", "Leave", true]])
		"copy":
			copying.emit(int(talk.get("color", 1)))
		_:
			super.choose(action)
