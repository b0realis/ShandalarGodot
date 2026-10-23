class_name LairPane
extends VisitPane
## A LAIR ENTERED ([WorldLairs], [LairEvent]) — its 1997 picture by its
## colour (the blue one the sunken ship) in the visit pane's glass, and
## what it holds, step by step: the treasure shown over the picture,
## "Found this card"; or "You happen upon a …!" and the event — the clue
## told, the riddle asked and its card shown, the thieves' luck, the
## Gemcutter's five amulets, the Oasis's offer, the Nomad's Bazaar and the
## Diamond Mine opening the card trader ([CardTradePane], over the world,
## the lair waiting under it). A card left to find is shown last; leaving
## (Escape too) gives it.

## The hero would trade: [param way] ([constant CardTrade.BAZAAR] or
## [constant CardTrade.MINE]).
signal trading(way: String)

## What the lair holds ([method LairEvent.begin]).
var event := {}
## The riddle asked, `{}` for none.
var riddle := {}
var _found_shown := false
var _done := false
## The amulet the Guardian's Ghost asks.
var _ghost_amulet := ""


## The place for the pane from [param event].
static func place_of(event: Dictionary) -> Dictionary:
	var color := clampi(int(event.get("color", 1)), 1, 5)
	return {"kind": "lair", "slot": int(event.get("slot", -1)), "name": String(event.get("name", "Lair")),
		"subtitle": "%s lair" % AdventurePlayer.COLORS[color - 1].capitalize(),
		"picture": "visit_lair_" + AdventurePlayer.COLORS[color - 1], "lines": [], "actions": []}


func _ready() -> void:
	super._ready()
	name = "LairPane"
	_start()


## The event's first words and choices.
func _start() -> void:
	if LairEvent.is_treasure(event):
		_found()
		return
	var lines: Array = [LairEvent.arrival(event)]
	var kind := int(event["event"])
	match kind:
		LairEvent.RUINED_TOWER:
			var told := LairEvent.ruined_tower(player)
			if told < 0:
				_ask_riddle(lines)
				return
			lines.append("Among its stones you learn of %s:" % WorldClues.title(told))
			lines.append_array(WorldClues.lines(player.world, told))
			_settle(lines)
		LairEvent.LOREMASTER, LairEvent.PYRAMIDS:
			_ask_riddle(lines)
		LairEvent.THIEVES:
			lines.append(LairEvent.thieves(player, event))
			_settle(lines)
		LairEvent.LOST_CITY:
			lines.append(LairEvent.lost_city(player, event))
			_settle(lines)
		LairEvent.BAZAAR:
			lines.append("Nomads trade any card for gold.")
			say(lines)
			offer([["bazaar", "Trade with the nomads", true], ["leave", "Leave", true]])
		LairEvent.MINE:
			lines.append("The miners trade any card for amulets.")
			say(lines)
			offer([["mine", "Trade with the miners", player.amulet_count() > 0], ["leave", "Leave", true]])
		LairEvent.GEMCUTTER:
			lines.append("You may buy amulets for %d gold pieces." % LairEvent.AMULET_PRICE)
			say(lines)
			_gem_choices("")
		LairEvent.OASIS:
			var card := LairEvent.oasis_card(player, event)
			if card == "":
				lines.append("You have no card the keeper of the oasis would take.")
				_settle(lines)
			else:
				lines.append("You may trade your %s for five extra life in the next duel." % card)
				say(lines)
				show_card(card)
				offer([["leave", "Never mind.", true], ["oasis", "Trade for life.", true]])
		LairEvent.GHOST:
			var held: Array[String] = []
			for hue in AdventurePlayer.COLORS:
				if int(player.amulets.get(hue, 0)) > 0:
					held.append(hue)
			if held.is_empty():
				_settle(lines)
				return
			var dice := MsvcRandom.new(player.dice)
			_ghost_amulet = held[dice.below(held.size())]
			player.dice = dice.state
			var color := clampi(int(event.get("color", 1)), 1, 5)
			lines.append("For one %s amulet I will reveal the deck of any %s creature." % [
				_ghost_amulet, AdventurePlayer.COLORS[color - 1]])
			say(lines)
			offer([["leave", "Never mind.", true], ["ghost", "See a deck.", false]],
				"The creatures and their decks come with the duels.")
		_:
			lines.append("A creature waits here to duel you.")
			say(lines)
			offer([["leave", "Leave", true]], "The duels come next.")


## The event's part done: [param lines] said, and on.
func _settle(lines: Array) -> void:
	say(lines)
	offer([["leave", "Leave", true]])


func _ask_riddle(lines: Array) -> void:
	var dice := MsvcRandom.new(player.dice)
	riddle = CardRiddle.make(dice, player.difficulty)
	player.dice = dice.state
	if riddle.is_empty():
		_settle(lines)
		return
	lines.append(String(riddle["question"]))
	say(lines)
	var answers: Array = []
	var words: Array = riddle["answers"]
	for i in words.size():
		answers.append(["answer_%d" % i, String(words[i]), true])
	offer(answers)


## Answer [param index] given: the verdict, the card shown.
func answer(index: int) -> void:
	if riddle.is_empty() or bool(riddle.get("answered", false)):
		return
	riddle["answered"] = true
	var right := CardRiddle.correct(riddle, index)
	LairEvent.riddle_answered(player, event, right)
	var lines: Array = (place.get("lines", []) as Array).duplicate()
	lines.append(CardRiddle.verdict(riddle, index))
	show_card(String(riddle["card"]))
	_settle(lines)


func _gem_choices(note_text: String) -> void:
	var actions: Array = []
	for hue in AdventurePlayer.COLORS:
		actions.append(["amulet_" + hue, LairEvent.amulet_words(player, hue),
			player.gold >= LairEvent.AMULET_PRICE])
	actions.append(["leave", "No thanks.", true])
	offer(actions, note_text)


## "Found this card": the card shown, Leave takes it.
func _found() -> void:
	_found_shown = true
	var card := String(event.get("reward", ""))
	say([LairEvent.FOUND])
	show_card(card)
	offer([["leave", "Leave", true]])


## A trade with the nomads or the miners is over: the lair again.
func traded() -> void:
	if int(event.get("event", 0)) == LairEvent.MINE:
		offer([["mine", "Trade with the miners", player.amulet_count() > 0], ["leave", "Leave", true]])


func choose(action: String) -> void:
	if action.begins_with("answer_"):
		answer(int(action.trim_prefix("answer_")))
		return
	if action.begins_with("amulet_"):
		_gem_choices(LairEvent.buy_amulet(player, action.trim_prefix("amulet_")))
		return
	match action:
		"bazaar":
			trading.emit(CardTrade.BAZAAR)
		"mine":
			trading.emit(CardTrade.MINE)
		"oasis":
			var said := LairEvent.oasis_trade(player, event)
			show_card("")
			_settle([LairEvent.arrival(event), said])
		"leave":
			leave_lair()


## LEAVING: a card still to be found is shown first; then it is the
## hero's and the lair is left.
func leave_lair() -> void:
	if _done:
		return
	if not _found_shown and String(event.get("reward", "")) != "":
		_found()
		return
	_done = true
	LairEvent.finish(player, event)
	left.emit("")


## The card the lair gave or will give, "" for none.
func reward() -> String:
	return String(event.get("reward", ""))


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_lair()
