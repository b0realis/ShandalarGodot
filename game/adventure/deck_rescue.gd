class_name DeckRescue
extends RefCounted

## THE DECK IN USE KEPT PLAYABLE [ours] (0.70.11 campaign, bugs3 #1).
##
## 1997 ended the adventure when the deck in use held no card to stake
## (`ExitIfNoUsableDeckCards`, visitLocation.c 2252; [constant
## CreatureMeeting.NO_ANTE]) — right for a hero who owns no spell at all,
## and a trap with three deck slots: a look at an empty slot and Done left
## it the deck in use, the next creature ended the adventure, and the
## autosave made as it came replayed the end.
##
## So before the end is drawn ([method CreatureMeeting.meet], a dungeon
## room's duel, a ruled town's, the Final Battle), as a save is read
## ([method AdventurePlayer.from_dict]) and as a deck builder closes, the
## deck in use is looked at ([method rescue]):
##   • it holds a card to stake — nothing happens;
##   • another deck does — that deck (the lowest) is the deck in use;
##   • no deck does, but the hero's cards hold one — those cards go into
##     the deck in use, up to [constant COPIES] of a card, every basic land;
##   • the hero owns no card to stake — nothing: 1997's end stands.
## What was done is kept in [member AdventurePlayer.deck_note] for the
## world to say; the save's format is untouched (the marks it already has).

## The copies of a card put into a deck filled from the bag: 1997's rule.
const COPIES := 3
const SWITCHED := "Deck %d holds no spell to stake in a duel: you duel with Deck %d."
const FILLED := "No deck held a spell to stake in a duel: your cards were put into Deck %d."


## Whether [param entry] (one of [member AdventurePlayer.cards]) is a card
## a duel may stake: no basic land, and known to the game now.
static func stakeable(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	var card := String((entry as Dictionary).get("card", ""))
	return not card in CreatureDeck.BASICS and CardRegistry.has_card(card)


## Whether deck [param slot] (0–2) holds a card to stake.
static func playable(player: AdventurePlayer, slot: int) -> bool:
	for entry in player.cards:
		if stakeable(entry) and ((entry as Dictionary).get("decks", []) as Array).has(slot):
			return true
	return false


## The lowest deck with a card to stake; −1 for none.
static func playable_slot(player: AdventurePlayer) -> int:
	for slot in 3:
		if playable(player, slot):
			return slot
	return -1


## Whether the hero owns a card to stake at all, in a deck or out of one.
static func owns_a_stake(player: AdventurePlayer) -> bool:
	for entry in player.cards:
		if stakeable(entry):
			return true
	return false


## Whether [method rescue] would change something: the deck in use holds
## no card to stake and the hero's cards could give it one.
static func needed(player: AdventurePlayer) -> bool:
	return player != null and not playable(player, player.current_deck) and owns_a_stake(player)


## THE RESCUE (the class doc): the line that says what was done — also kept
## in [member AdventurePlayer.deck_note] — or "" when nothing was.
static func rescue(player: AdventurePlayer) -> String:
	if not needed(player):
		return ""
	var was := player.current_deck
	var other := playable_slot(player)
	var said := ""
	if other >= 0:
		player.current_deck = other
		said = SWITCHED % [was + 1, other + 1]
	else:
		var put := {}
		for entry in player.cards:
			if not entry is Dictionary:
				continue
			var card := String((entry as Dictionary).get("card", ""))
			if not CardRegistry.has_card(card):
				continue
			var decks: Array = (entry as Dictionary).get("decks", []) as Array
			if decks.has(was):
				put[card] = int(put.get(card, 0)) + 1
				continue
			if not card in CreatureDeck.BASICS and int(put.get(card, 0)) >= COPIES:
				continue
			put[card] = int(put.get(card, 0)) + 1
			var marked := decks.duplicate()
			marked.append(was)
			(entry as Dictionary)["decks"] = marked
		said = FILLED % (was + 1)
	player.deck_note = said
	return said
