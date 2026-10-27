class_name LairPane
extends VisitPane
## A LAIR ENTERED ([WorldLairs], [LairEvent]) — its 1997 picture by its
## colour (the blue one the sunken ship) in the visit pane's glass, and
## what it holds, step by step: the treasure shown over the picture,
## "Found this card"; or "You happen upon a …!" and the event — the clue
## told, the riddle asked and its card shown, the thieves' luck, the
## Gemcutter's five amulets, the Oasis's offer, the Nomad's Bazaar and the
## Diamond Mine opening the card trader ([CardTradePane], over the world,
## the lair waiting under it), and THE FOUR DUELS ([LairDuels], part B): the
## Abandoned Shrine, the Dragon's Lair, the Hall of the Sultan and the
## Spectral Arena — `sfx_lair_duel`, the creature's hoard of rares fanned
## over the picture as 1997 laid it, its words, "Leave quietly." / "Duel the
## creature."; the duel held over the world ([WorldDuels]) while the pane
## waits hidden; a win's cards laid on `win_back_cards` in 1997's places
## over their rarities, "Won These Cards", the win music under them; a loss
## or a draw straight on to the lair's end. A card left to find is shown
## last; leaving (Escape too) gives it. The picture comes in as 1997's did,
## in random 5 × 5 tiles (`ShowLairBackdropTransition`; [TileReveal]), the
## card found with it; a choice answers to its first letter ([VisitPane]).

## The hero would trade: [param way] ([constant CardTrade.BAZAAR] or
## [constant CardTrade.MINE]).
signal trading(way: String)

## [Ours] The Guardian's Ghost's amulet no longer held when it is to be paid
## (spent since it was named — a World Magic cast from the panel): said, and
## no deck is shown.
const GHOST_SHORT := "You hold no %s amulet to give."

## What the lair holds ([method LairEvent.begin]).
var event := {}
## The riddle asked, `{}` for none.
var riddle := {}
var _found_shown := false
var _done := false
## The amulet the Guardian's Ghost asks.
var _ghost_amulet := ""
## The lair's duel ([method LairDuels.begin]), `{}` for none; what it left
## ([method LairDuels.settle]), `{}` before it.
var duel_setup := {}
var duel_spoils := {}
## Where the duel stands: `""`, `offer`, `duel`, `won`, `over`.
var duel_step := ""
var _duel: WorldDuels
var _music: AudioStreamPlayer
var _music_key := ""


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
			if String(event.get("reward", "")) == "":
				WorldSoundscape.play_from(self, "sfx_treasure")
			_settle(lines)
		LairEvent.LOST_CITY:
			lines.append(LairEvent.lost_city(player, event))
			if String(event.get("reward", "")) == "":
				WorldSoundscape.play_from(self, "sfx_treasure")
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
			WorldSoundscape.play_from(self, "sfx_treasure")
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
			offer([["leave", "Never mind.", true], ["ghost", "See a deck.", true]])
		LairEvent.SHRINE, LairEvent.DRAGON, LairEvent.SULTAN, LairEvent.ARENA:
			_offer_duel(lines)
		_:
			_settle(lines)


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


## "Found this card": the card shown, Leave takes it — the treasure, the
## waiting rare, a riddle's or the thieves' card. [Ours] With the bag full
## the card is lost, as 1997's adder lost it without a word (duel.c
## 1859–1867), and said under it ([constant AdventurePlayer.BAG_FULL]), as
## the lair duel's hoard says it (the playtest of part B, H3-2, P3-6).
func _found() -> void:
	_found_shown = true
	var card := String(event.get("reward", ""))
	WorldSoundscape.play_from(self, WorldSoundscape.card_key(card))
	say([LairEvent.FOUND])
	show_card(card)
	offer([["leave", "Leave", true]], AdventurePlayer.BAG_FULL if player.bag_room() < 1 else "")


# ------------------------------------------------------------ the duels --

## A LAIR'S DUEL OFFERED ([LairDuels]): `Aswanjag.wav`, the setup drawn in
## 1997's order (the Hall's gift first), the hoard fanned over the picture,
## the creature's words after [param lines], Leave quietly or Duel.
func _offer_duel(lines: Array) -> void:
	duel_setup = LairDuels.begin(player, event)
	duel_step = "offer"
	WorldSoundscape.play_from(self, LairDuels.SOUND)
	var said: Array = lines.duplicate()
	said.append_array(duel_setup.get("words", []))
	say(said)
	var places: Array = []
	for at in LairDuels.stake_places((duel_setup["rares"] as Array).size()):
		places.append(VisitPane.page_point(at))
	show_cards(duel_setup["rares"], [], places, 104.0)
	offer(LairDuels.choices(duel_setup))


## DUEL THE CREATURE: the duel over the world ([WorldDuels]), the pane
## hidden while it lasts.
func _start_duel() -> void:
	if duel_step != "offer" or int(duel_setup.get("row", 0)) <= 0:
		return
	duel_step = "duel"
	var config := LairDuels.duel_config(player, duel_setup)
	visible = false
	var host_on: Node = get_parent()
	# The lair's own menu question: saved as it was entered, and spent (the
	# playtest of part B, H2-6; the meeting's spoke of meeting the creature).
	_duel = WorldDuels.host(host_on, config, LairDuels.foe(duel_setup), WorldDuels.MENU_LAIR)
	_duel.ended.connect(_after_duel, CONNECT_ONE_SHOT)
	_duel.abandoned.connect(func() -> void:
		duel_step = "over"
		_done = true, CONNECT_ONE_SHOT)


## The duel host while the duel is up (a test concedes or wins through it).
func duel_host() -> WorldDuels:
	return _duel if is_instance_valid(_duel) else null


## THE DUEL OVER ([param report]): settled; a win's cards shown, else on to
## the lair's end — nothing lost, nothing won.
func _after_duel(report: DuelReport) -> void:
	duel_spoils = LairDuels.settle(player, duel_setup, report, _duel != null and _duel.conceded)
	visible = true
	show_cards([])
	if int(duel_spoils["result"]) == LairDuels.WON and not (duel_spoils["cards"] as Array).is_empty():
		_cards_won()
		return
	duel_step = "over"
	WorldDuels.world_music(self)
	leave_lair()


## THE CARDS WON (`Winbak01.pic`): each in 1997's place over its rarity,
## "Won These Cards", the win music.
func _cards_won() -> void:
	duel_step = "won"
	_play_music("music_win_duel")
	show_picture("win_back_cards")
	var cards: Array = duel_spoils["cards"]
	var captions: Array = []
	for rarity in duel_spoils["rarities"]:
		captions.append(DuelSpoils.rarity_word(int(rarity)))
	var places: Array = []
	for at in duel_spoils["places"]:
		places.append(VisitPane.page_point(at))
	show_cards(cards, captions, places)
	say(duel_spoils["words"])
	offer([["won", "Continue", true]],
		LairDuels.BAG_FULL if not (duel_spoils["bag_lost"] as Array).is_empty() else "")


## The cards won seen: the lair's own picture again, the music gone, the
## lair's end.
func _after_cards() -> void:
	duel_step = "over"
	_stop_music()
	WorldDuels.world_music(self)
	show_cards([])
	show_picture("")
	leave_lair()


## [param key] looped (the win music), the world's bed stopped under it;
## nothing with the music switched off.
func _play_music(key: String) -> void:
	if not Settings.music_enabled():
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.name = "Music"
		_music.bus = GameAudio.MUSIC_BUS
		_music.finished.connect(func() -> void:
			if _music_key != "" and is_inside_tree():
				_music.play())
		add_child(_music)
	WorldDuels.world_music_off(self)
	_music_key = key
	_music.stream = stream
	_music.play()


func _stop_music() -> void:
	_music_key = ""
	if _music != null:
		_music.stop()


## The tune playing, "" for none.
func music_key() -> String:
	return _music_key


## A creature's deck has been seen (the Guardian's Ghost): on.
func deck_seen() -> void:
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
		"ghost":
			_pay_the_ghost()
		"lair_duel":
			_start_duel()
		"won":
			_after_cards()
		"leave":
			leave_lair()
		_:
			super.choose(action)


## THE GUARDIAN'S GHOST PAID: the amulet it named, looked for again — it
## may have been spent since it was named — then any creature of the lair's
## colour to choose ([method VisitPane.ask_whose_deck]). Short of it, the
## Ghost says so ([constant GHOST_SHORT]) and the lair is done.
func _pay_the_ghost() -> void:
	var held := int(player.amulets.get(_ghost_amulet, 0))
	if _ghost_amulet == "" or held < 1:
		var lines: Array = (place.get("lines", []) as Array).duplicate()
		lines.append(GHOST_SHORT % _ghost_amulet)
		_settle(lines)
		return
	player.amulets[_ghost_amulet] = held - 1
	ask_whose_deck(clampi(int(event.get("color", 1)), 1, 5))


## LEAVING: a card still to be found is shown first; then it is the
## hero's and the lair is left.
func leave_lair() -> void:
	if _done or duel_step == "duel":
		return
	if duel_step == "won":
		_after_cards()
		return
	if not _found_shown and String(event.get("reward", "")) != "":
		show_cards([])
		_found()
		return
	_done = true
	LairEvent.finish(player, event)
	left.emit("")


## The card the lair gave or will give, "" for none.
func reward() -> String:
	return String(event.get("reward", ""))


func _unhandled_input(input: InputEvent) -> void:
	# Hidden under the duel or the trader, Escape is theirs.
	if visible and input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_lair()
	elif visible and VisitPane.letter_choice(self, _choices, input):
		# A choice by its first letter, as every place's ([VisitPane]).
		get_viewport().set_input_as_handled()
