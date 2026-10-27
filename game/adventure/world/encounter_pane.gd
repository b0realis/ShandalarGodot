class_name EncounterPane
extends PanelContainer
## A CREATURE MET — the 1997 meeting screen and everything after it, in one
## of the world's movable rounded panes ([PaneStyle]): the 1997 page on its
## stage ([EncounterStage]) and the words and choices under it, as a lair's
## pane has them ([LairPane]).
##
## THE MEETING (E = world_lair_monster_encounter.c; [CreatureMeeting] holds
## the rules): the ground of the creature's colour (`preduel_<colour>`), its
## face and name, "Your Ante" and "Opponent Ante" with the cards staked
## (right click reads one), the purse's panels and the quest scroll; the
## creature's words by its relation and the hero's wins, and the choices —
## Duel, Pay, Answer a riddle (the lair's riddle: the question in the words,
## the answers as choices, the card shown), Change ante card, Accept
## tribute (its offer, its payment, Duel Anyway; a spell picked from the
## creature's deck, a World Magic's town found — the map shown after —, the
## castle's secrets). `music_duel` plays, as 1997's `dueltune.wav` did.
## Then THE SPECIAL MEETING's lines (`sfx_dsummon`, a summoned creature's
## face), and THE DUEL over the world ([WorldDuels]): the pane waits hidden.
## THE SPOILS ([DuelSpoils]) after it: the cards won fanned on
## `win_back_cards` with their rarities and "Won these cards." — or the
## dungeon's plaque and "Take the cards. / Take the dungeon clue." —, the
## bag's note, the amulet on `win_back_reward`, the reward screen with its
## title, the card picks [ours: a full bag's losses named, its pick not
## offered]; a loss "Lost this card" on `lose_card`, a card at
## a time; a draw "Better Luck Next Time!". `music_win_duel` and
## `music_lose_duel` loop under them, as 1997's `winduel.wav` and
## `loseduel.wav` did. The world's bed comes back as the pane closes.
##
## THE KEYS AND THE MOUSE as the other panes: a click on a choice — or its
## first letter, Enter or Space to take the one lit [1997] ([method
## VisitPane.letter_choice]); a right click on a card reads it; a drag on
## the pane's glass moves it. ESCAPE:
## nothing at the meeting's choices (1997 asked again — there is no
## flight); at a riddle, nothing — it waits for an answer [ours: 1997 slip
## — Escape was a wrong answer and lost the stake]; at a tribute or its
## lists, the meeting ends with nothing taken (1997's); at
## "Take the cards / Take the dungeon clue", the cards [ours: 1997 slip —
## any answer but the first took the clue]; at a line said, on; at "any card
## of your choice", the list again (it must be picked, as 1997 asked again).
##
## [signal finished] once, with [constant WorldCreatures.WON] (1), LOST (0),
## DRAWN (−1), NO_DUEL (2) — paid, a riddle, a tribute — or
## [constant GAME_OVER] (3): no card to stake, "You have no power for even an
## Ante!" (`@QUESTFAILED`), the adventure's end screen being the end's own
## (part B, W7: [WorldEncounters]). Then the pane frees itself.

## The meeting is over: [param result] (see the class doc).
signal finished(result: int)
## A card right-clicked, to be read full screen ([method WorldScreen.read_card]).
signal card_read(card_name: String)

const WON := 1
const LOST := 0
const DRAWN := -1
const NO_DUEL := 2
## No card to stake: the game is over (the adventure's end screen's).
const GAME_OVER := 3
## The stage's size against 1997's page, at most and at least; the room
## kept free above and below the pane.
const MOST := 1.25
const LEAST := 0.55
const ROOM_MARGIN := 32.0
## [Ours] The choices' own words where 1997 waited for a key.
const GO_ON := "Continue"
const LEAVE := "Leave"
const FIGHT := "To the duel!"
const MUST_PICK := "Pick a card: the reward is yours to choose."
const BAG_FULL := AdventurePlayer.BAG_FULL
## [Ours] A FULL BAG'S LOSSES SAID (the fix pass of part B, c5, P4-6; 1997
## lost them without a word, `AddCardToDeckSorted`, duel.c 1859–1867): the
## cards won it could not hold, named under them; the reward's pick, not
## offered.
const BAG_LOST := "Lost: %s."
const PICK_LOST := "The card of your choice is lost."

## The adventure.
var player: AdventurePlayer
## The world screen (it holds the duel, [WorldDuels], and the lists).
var screen: Node
## The meeting ([method CreatureMeeting.begin]).
var meeting := {}
## What the duel left ([method DuelSpoils.settle]), `{}` before it.
var spoils := {}
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
## Where the pane stands: `meeting`, `riddle`, `verdict`, `stake_lost`,
## `tribute`, `magics`, `told`, `special`, `duel`, `cards`, `bag`,
## `amulet`, `reward`, `pick`, `bag_full`, `lost`, `draw`, `won`,
## `game_over`, `done`.
var step := ""
## The meeting's result so far.
var result := NO_DUEL
var stage: EncounterStage
var _title: Label
var _subtitle: Label
var _words: Label
var _choices: HFlowContainer
var _note: Label
var _music: AudioStreamPlayer
var _music_key := ""
var _duel: WorldDuels
var _list: CardListPane
var _most := 1.0
var _factor := 1.0
## The page's size on the step the player last answered: a later step's
## page may be smaller (more words under it), never larger — the page does
## not swell and shrink from click to click [ours].
var _ceiling := INF
var _done := false
var _map_after := false
var _riddle_right := false
var _lost_shown := 0
var _seen := {}
var _drag := {}
var _relayout_queued := false


func _ready() -> void:
	name = "EncounterPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = PaneStyle.title("")
	_title.name = "EncounterTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = PaneStyle.label("", 15, PaneStyle.DIM)
	_subtitle.name = "EncounterKind"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	var frame := PanelContainer.new()
	frame.name = "Picture"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(PaneStyle.GOLD, 0.7)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(4)
	rim.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", rim)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage = EncounterStage.new()
	stage.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	frame.add_child(stage)
	column.add_child(frame)
	_words = PaneStyle.label("", 17, PaneStyle.INK)
	_words.name = "EncounterWords"
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_words)
	_choices = HFlowContainer.new()
	_choices.name = "EncounterChoices"
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("h_separation", int(8 * k))
	_choices.add_theme_constant_override("v_separation", int(6 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_choices)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
	_note.name = "EncounterNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = GameAudio.MUSIC_BUS
	_music.finished.connect(func() -> void:
		if _music_key != "" and is_inside_tree():
			_music.play())
	add_child(_music)
	# The page as wide as the screen allows; how tall the words and choices
	# under it let it be is measured once they are there ([method _fit]) —
	# not a guess of 300 · k, which with the big buttons (k 1.6) drew the page
	# at two thirds, its stakes and cards unreadable under huge buttons (the
	# fix pass of part B, c5, P4-1).
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	_most = clampf((room.x - 120.0) / EncounterStage.PAGE.x, LEAST, MOST)
	_set_factor(_most)
	minimum_size_changed.connect(_fit)
	_begin()


## THE MEETING BEGINS: its screen, or the game's end with nothing to stake.
func _begin() -> void:
	if meeting.is_empty():
		_end()
		return
	var row := int(meeting["row"])
	_title.text = CreatureBook.name_of(row)
	_subtitle.text = "A creature of the %s" % WorldNames.WIZARDS[clampi(int(meeting["color"]), 1, 5) - 1]
	if bool(meeting.get("no_ante", false)):
		_game_over()
		return
	_play_music("music_duel")
	_show_meeting()


# ----------------------------------------------------------- the stage --

func _set_factor(value: float) -> void:
	_factor = value
	stage.set_factor(value)
	var width := EncounterStage.PAGE.x * value
	for part: Control in [_words, _choices, _note]:
		part.custom_minimum_size.x = width


## THE PANE KEPT ON THE SCREEN (as [method VisitPane._fit]), THE PAGE AS
## LARGE AS THE ROOM LEFT: the screen's height less what the words and
## choices under the page really take (measured), up to what the width
## allows ([member _most]) — the page gives way to more words, and does not
## grow back with fewer ([member _ceiling]).
func _fit() -> void:
	if not is_inside_tree() or stage == null:
		return
	var room := get_viewport_rect().size.y - ROOM_MARGIN
	var rest := get_combined_minimum_size().y - stage.custom_minimum_size.y
	var grow := clampf((room - rest) / EncounterStage.PAGE.y, LEAST, minf(_most, _ceiling))
	if absf(grow - _factor) * EncounterStage.PAGE.y >= 1.0:
		_set_factor(grow)
	_queue_relayout()


## THE PANE AS SMALL AS ITS PARTS, ABOUT ITS OWN MIDDLE, after a change of
## words or choices (a pane outside a container only ever grows: a line
## wrapped before its width was known left it a screen and a half tall),
## and kept on the screen — once a frame at most.
func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()


func _relayout() -> void:
	_relayout_queued = false
	if not is_inside_tree():
		return
	var middle := position + size / 2.0
	size = get_combined_minimum_size()
	position = middle - size / 2.0
	var room := get_viewport_rect().size
	# A pane that fits keeps its foot on the screen as it grows about its
	# middle (the c5 fix pass: 586 high in a 600-high window, grown from
	# where it was centred, it stood 5 below the edge).
	if size.y <= room.y:
		position.y = minf(position.y, room.y - size.y)
	position.x = clampf(position.x, 40.0 - size.x, room.x - 40.0)
	position.y = clampf(position.y, 0.0, maxf(room.y - 40.0, 0.0))


## The meeting's page: the ground of the creature's colour, its face, the
## plaques and the stakes, the purse and the quest scroll.
func _meeting_stage() -> void:
	stage.clear()
	var color := clampi(int(meeting["color"]), 1, 5)
	stage.hue = color
	stage.ground("preduel_" + AdventurePlayer.COLORS[color - 1])
	stage.creature_face(int(meeting["row"]))
	stage.ante_plaques()
	stage.stakes(meeting.get("hero_ante", []), meeting.get("creature_ante", []))
	stage.purse(player)
	stage.scroll(WorldStatus.lines(player))


# --------------------------------------------------------- the meeting --

func _show_meeting() -> void:
	step = "meeting"
	_meeting_stage()
	say(CreatureMeeting.words(player, meeting))
	offer(CreatureMeeting.options(player, meeting))


## WHAT A CHOICE DOES, at the step the pane stands at.
func choose(action: String) -> void:
	if _done:
		return
	# The step the player saw stood laid out: its page is the most the
	# next one may take ([member _ceiling]).
	_ceiling = _factor
	match step:
		"meeting":
			_choose_at_meeting(action)
		"riddle":
			if action.begins_with("answer_"):
				answer(int(action.trim_prefix("answer_")))
		"verdict":
			if _riddle_right:
				_end()
			else:
				_stake_lost(meeting.get("lost", []))
		"tribute":
			_choose_tribute(action)
		"magics":
			if action.begins_with("magic_"):
				var lines := CreatureMeeting.reveal_magic(player, int(action.trim_prefix("magic_")))
				_map_after = true
				_told(lines, "See the map")
			else:
				_end()
		"special":
			_start_duel()
		"cards":
			if action == "cards" or action == "clue":
				DuelSpoils.choose(player, meeting, spoils, action == "cards")
				if action == "clue":
					_clue_told()
					return
			_next_result()
		"stake_lost", "told", "game_over":
			_end()
		"duel", "pick", "done":
			pass
		_:
			# A result's line read ("bag", "amulet", "reward", "lost", "draw",
			# "won", "clue"): the next one.
			_next_result()


func _choose_at_meeting(action: String) -> void:
	match action:
		"duel":
			_to_duel()
		"pay":
			if CreatureMeeting.pay(player, meeting):
				result = NO_DUEL
				_end()
			else:
				offer(CreatureMeeting.options(player, meeting), "You hold too little gold now.")
		"riddle":
			var asked := CreatureMeeting.riddle(player, meeting)
			if asked.is_empty():
				offer(CreatureMeeting.options(player, meeting), "No riddle comes to the creature's mind.")
				return
			step = "riddle"
			var lines: Array[String] = CreatureMeeting.words(player, meeting)
			lines.append(String(asked["question"]))
			say(lines)
			var answers: Array = []
			var words_given: Array = asked["answers"]
			for i in words_given.size():
				answers.append(["answer_%d" % i, String(words_given[i]), true])
			offer(answers)
		"change":
			var card := CreatureMeeting.change_ante(player, meeting)
			_meeting_stage()
			offer(CreatureMeeting.options(player, meeting),
				"Your ante is now %s." % card if card != "" else "")
		"tribute":
			var paid := CreatureMeeting.tribute(player, meeting)
			step = "tribute"
			say(paid["lines"])
			offer(paid["choices"])


## THE RIDDLE ANSWERED with answer [param index] (−1 none): the
## verdict with the riddle's card (the lair's: "Correct!", "WRONG",
## "WRONG.  Correct is:"); a wrong answer then loses the stake.
func answer(index: int) -> void:
	var asked: Dictionary = meeting.get("riddle", {})
	if step != "riddle" or asked.is_empty():
		return
	_riddle_right = CardRiddle.correct(asked, index)
	var lost := CreatureMeeting.riddle_answered(player, meeting, _riddle_right)
	meeting["lost"] = lost
	result = NO_DUEL
	step = "verdict"
	stage.clear()
	stage.creature_face(int(meeting["row"]))
	stage.card(String(asked.get("card", "")), Vector2(450, 120), 150.0, "RiddleCard")
	say([CardRiddle.verdict(asked, index) if index >= 0 else CardRiddle.WRONG])
	offer([["go", GO_ON if not _riddle_right else LEAVE, true]])


## THE STAKE LOST to a riddle missed (E:2049–2074): `losedul2.pic`, the card
## and "Lost this card", `loseduel.wav`.
func _stake_lost(lost: Array) -> void:
	step = "stake_lost"
	_play_music("music_lose_duel")
	stage.clear()
	stage.ground("lose_card")
	if not lost.is_empty():
		stage.card(String(lost[0]), Vector2(46, 120), 150.0, "LostCard", CreatureMeeting.LOST_CARD)
	say([CreatureMeeting.LOST_CARD] if not lost.is_empty() else [] as Array[String])
	offer([["leave", LEAVE, true]])


# ----------------------------------------------------------- the tribute --

func _choose_tribute(action: String) -> void:
	var paid: Dictionary = meeting.get("tribute", {})
	match action:
		"payment":
			var said := CreatureMeeting.take_payment(player, meeting)
			_told([said] as Array[String], LEAVE)
		"duel":
			_to_duel()
		"offer":
			match int(paid.get("offer", -1)):
				0:
					_pick_spell()
				1:
					var magics := CreatureMeeting.magic_choices(player)
					if magics.is_empty():
						_told(CreatureMeeting.lines_of(CreatureMeeting.ALL_MAGICS), LEAVE)
						return
					step = "magics"
					say([CreatureMeeting.WHICH_MAGIC] as Array[String])
					var actions: Array = []
					for index in magics:
						actions.append(["magic_%d" % index, AdventurePlayer.WORLD_MAGICS[index], true])
					offer(actions)
				_:
					_told(CreatureMeeting.secrets(player, meeting), LEAVE)
		_:
			_end()


## "A spell from my deck?": the creature's deck listed, a card picked (none:
## nothing taken).
func _pick_spell() -> void:
	var row := int(meeting["row"])
	_open_list(CreatureMeeting.PICK_SPELL, "From the deck of %s." % CreatureBook.called(row),
		_offered(CreatureMeeting.spell_choices(meeting)), func(card_name: String) -> void:
			var kept := CreatureMeeting.take_spell(player, card_name)
			_told([("%s is yours." % card_name) if kept else BAG_FULL] as Array[String], LEAVE),
		func() -> void: _end())


## [param counted] (`name -> count`, a list to pick from) without the cards
## the Classic MTG rules let no one offer the hero any more ([method
## CardShop.classic_rule]; under the 1997 rules the whole list). A basic
## land is always allowed, so a list of every card is never empty.
func _offered(counted: Dictionary) -> Dictionary:
	var rule := CardShop.classic_rule(player)
	if rule.is_empty():
		return counted
	var out := {}
	for card_name in counted:
		if CardShop.classic_allows(rule, String(card_name)):
			out[card_name] = counted[card_name]
	return out


## Lines said, and one way on ([param go] its words): the meeting then ends.
func _told(lines: Array[String], go: String) -> void:
	step = "told"
	result = NO_DUEL
	say(lines)
	offer([["leave", go, true]])


# -------------------------------------------------------------- the duel --

## DUEL (or Duel Anyway): the duel prepared — the special meeting's sound
## and lines, a summoned creature's face — then the duel.
func _to_duel() -> void:
	var events := CreatureMeeting.prepare_duel(player, meeting)
	if bool(meeting.get("special", false)):
		WorldSoundscape.play_from(self, "sfx_dsummon")
	if events.is_empty():
		_start_duel()
		return
	step = "special"
	if int(meeting.get("summoned", 0)) > 0:
		_title.text = CreatureBook.name_of(int(meeting["row"]))
		# The summoned creature's face comes in over the one met, tile by
		# tile (`DrawCreaturePortrait` mode 1, E:2183; [method
		# EncounterStage.reveal_face]): the screen read before it is drawn.
		var was := TileReveal.picture_of(self) if TileReveal.wanted() else null
		_meeting_stage()
		stage.reveal_face(was)
	say(events)
	offer([["fight", FIGHT, true]])


## THE DUEL OVER THE WORLD ([WorldDuels]): the creatures crowding the hero
## gone ([method WorldCreatures.clear_crowd], 1997's E:2232–2244), the
## pane hidden while it lasts.
func _start_duel() -> void:
	step = "duel"
	result = LOST
	var slot := int(meeting.get("slot", -1))
	if slot >= 0:
		WorldCreatures.clear_crowd(player, slot)
	var config := CreatureMeeting.duel_config(player, meeting)
	_stop_music()
	visible = false
	var host_on: Node = screen if screen != null else get_parent()
	_duel = WorldDuels.host(host_on, config, CreatureBook.name_of(int(meeting["row"])))
	_duel.ended.connect(_after_duel, CONNECT_ONE_SHOT)
	_duel.abandoned.connect(_abandoned, CONNECT_ONE_SHOT)


## The duel host, while the duel is up (a test concedes through it).
func duel_host() -> WorldDuels:
	return _duel if is_instance_valid(_duel) else null


## THE DUEL OVER ([param report]): the spoils settled, the pane again.
func _after_duel(report: DuelReport) -> void:
	meeting["conceded"] = _duel != null and _duel.conceded
	spoils = DuelSpoils.settle(player, meeting, report)
	result = int(spoils["result"])
	visible = true
	match result:
		WON:
			_play_music("music_win_duel")
		LOST:
			_play_music("music_lose_duel")
	_next_result()


## The player left for the main menu mid-duel: nothing settled, nothing
## saved; the world screen goes ([WorldDuels]).
func _abandoned() -> void:
	_done = true
	_stop_music()


# ------------------------------------------------------------ the spoils --

## THE NEXT RESULT SCREEN, in 1997's order; the end after the last.
func _next_result() -> void:
	match result:
		WON:
			if not _seen.has("cards"):
				_seen["cards"] = true
				if not (spoils["cards"] as Array).is_empty():
					_cards_won()
				else:
					_won_words()
				return
			if int(spoils.get("bag", 0)) > 0 and not _seen.has("bag"):
				_seen["bag"] = true
				step = "bag"
				say(CreatureMeeting.lines_of(DuelSpoils.BAG_NOTE % int(spoils["bag"])))
				# The cards taken over the clue, lost to the full bag: said here,
				# the cards' step being past (P4-6).
				offer([["go", GO_ON, true]], _bag_lost_note())
				return
			if String(spoils.get("amulet", "")) != "" and not _seen.has("amulet"):
				_seen["amulet"] = true
				_amulet_won()
				return
			# A reward that gave nothing to say — lives carried with none
			# changed, the won card refused under the Classic MTG rules — has
			# no screen: 1997 showed its title alone over an empty page, the
			# treasure's sound with it [ours: 1997 slip; the bug campaign
			# c12, h2-3].
			if int(spoils.get("bits", 0)) != 0 and not _seen.has("reward") \
					and not (spoils.get("rewards", []) as Array).is_empty():
				_seen["reward"] = true
				_reward()
				return
			if bool(spoils.get("pick_any", false)) or bool(spoils.get("pick_duplicate", false)):
				if player.bag_room() < 1:
					_pick_lost()
				elif bool(spoils.get("pick_any", false)):
					_pick_any()
				else:
					_pick_duplicate()
				return
			_end()
		LOST:
			# Each card staked, "Lost this card" (E:2654–2667); with none staked
			# (nothing could be), the journal's line once [ours].
			var lost: Array = spoils.get("lost", [])
			var shown := maxi(lost.size(), 1)
			if _lost_shown >= shown:
				_end()
				return
			step = "lost"
			stage.clear()
			stage.ground("lose_card")
			if _lost_shown < lost.size():
				stage.card(String(lost[_lost_shown]), Vector2(46, 120), 150.0, "LostCard", DuelSpoils.LOST_CARD)
				say([DuelSpoils.LOST_CARD] as Array[String])
			else:
				stage.creature_face(int(meeting["row"]), EncounterStage.FACE_AT, EncounterStage.BANNER_AT, true)
				say([String(spoils.get("journal", "")) + "."] as Array[String])
			_lost_shown += 1
			offer([["go", GO_ON, true]])
		_:
			if not _seen.has("draw"):
				_seen["draw"] = true
				step = "draw"
				stage.clear()
				stage.ground("lose_card")
				stage.creature_face(int(meeting["row"]), Rect2(70, 60, 180, 180), Rect2(70, 240, 180, 35), true)
				say(spoils.get("words", [] as Array[String]))
				offer([["go", GO_ON, true]])
				return
			_end()


## THE CARDS WON (`winbak01.pic`): fanned with their rarities; "Won these
## cards." — or the dungeon's plaque and the question.
func _cards_won() -> void:
	step = "cards"
	stage.clear()
	stage.ground("win_back_cards")
	stage.fan(spoils["cards"], spoils["rarities"], spoils["heights"])
	if bool(spoils.get("asks", false)):
		stage.end_plaque(spoils["plaque"])
		say(spoils["words"])
		offer([["cards", DuelSpoils.TAKE_CARDS, true], ["clue", DuelSpoils.TAKE_CLUE, true]])
	else:
		say(spoils["words"])
		offer([["go", GO_ON, true]], _bag_lost_note())


## [Ours] The cards won the full bag could not hold, named — once: on the
## cards' step, or on the bag's note after the clue's question (P4-6). ""
## for none. The reward's card is said on the reward's own screen.
func _bag_lost_note() -> String:
	if _seen.has("bag_lost") or String(spoils.get("took", "")) != "cards":
		return ""
	var lost: Array = (spoils.get("bag_lost", []) as Array).duplicate()
	if bool(spoils.get("reward_lost", false)) and not lost.is_empty():
		lost.pop_back()
	if lost.is_empty():
		return ""
	_seen["bag_lost"] = true
	return "%s\n%s" % [BAG_FULL, BAG_LOST % ", ".join(PackedStringArray(lost))]


## The clue taken instead of the cards: what is now known of the place. The
## plaque keeps the word it was asked with — the clues known before this one
## (E:2336–2356, counted before `RevealRandomCastleDungeonClue`; counted again
## after the reveal it said "(second clue)" over the first, the fix pass of
## part B, c5, P4-4).
func _clue_told() -> void:
	step = "clue"
	stage.clear()
	stage.ground("win_back_cards")
	if not (spoils["plaque"] as Dictionary).is_empty():
		stage.end_plaque(spoils["plaque"])
	say(spoils.get("clue", [] as Array[String]))
	offer([["go", GO_ON, true]])


## A win with no cards (a henchman's): the journal's line [ours].
func _won_words() -> void:
	step = "won"
	stage.clear()
	stage.ground("win_back_reward")
	stage.creature_face(int(meeting["row"]), EncounterStage.FACE_AT, EncounterStage.BANNER_AT, true)
	say(spoils.get("words", [] as Array[String]))
	offer([["go", GO_ON, true]])


## THE AMULET (`winbak02.pic`, E:2421–2449): "Won this Amulet." with its
## stone.
func _amulet_won() -> void:
	step = "amulet"
	stage.clear()
	stage.ground("win_back_reward")
	stage.amulet(String(spoils["amulet"]))
	say([DuelSpoils.WON_AMULET] as Array[String])
	offer([["go", GO_ON, true]])


## THE REWARD (`winbak02.pic`, `treasure.wav`, E:2455–2632): the tinted
## face, the title, the gifts, the reward card shown.
func _reward() -> void:
	step = "reward"
	WorldSoundscape.play_from(self, "sfx_treasure")
	stage.clear()
	stage.ground("win_back_reward")
	stage.creature_face(int(meeting["row"]), Rect2(60, 30, 180, 180), Rect2(60, 210, 180, 35), true)
	if String(spoils.get("reward_card", "")) != "":
		stage.card(String(spoils["reward_card"]), Vector2(440, 60), 150.0, "RewardCard")
	var lines: Array[String] = CreatureMeeting.lines_of(String(spoils.get("title", "")))
	lines.append_array(spoils.get("rewards", [] as Array[String]))
	say(lines)
	offer([["go", GO_ON, true]])


## "You get any card of your choice!": every card listed; it must be picked
## (Never mind and Escape list them again, as 1997 asked again).
func _pick_any() -> void:
	step = "pick"
	var every := {}
	for row in CardTrade.catalogue():
		every[String(row["name"])] = 1
	_open_list(DuelSpoils.PICK_CARD, MUST_PICK, _offered(every), func(card_name: String) -> void:
			DuelSpoils.pick_any(player, spoils, card_name)
			_next_result(),
		func() -> void: _pick_any())


## [Ours] The reward's pick with the bag full (P4-6): no list whose pick
## would vanish — the full bag said, the pick spent, the meeting on.
func _pick_lost() -> void:
	step = "bag_full"
	spoils["pick_any"] = false
	spoils["pick_duplicate"] = false
	say([BAG_FULL, PICK_LOST] as Array[String])
	offer([["go", GO_ON, true]])


## "You get a duplicate card of your choice!": the hero's own cards; Never
## mind keeps none.
func _pick_duplicate() -> void:
	step = "pick"
	var owned: Array = []
	for entry in player.cards:
		owned.append(String((entry as Dictionary).get("card", "")))
	_open_list(DuelSpoils.PICK_CARD, "A copy of one of your own cards.", _offered(CardListPane.counted(owned)),
		func(card_name: String) -> void:
			DuelSpoils.pick_duplicate(player, spoils, card_name)
			_next_result(),
		func() -> void:
			spoils["pick_duplicate"] = false
			_next_result())


# --------------------------------------------------------------- the end --

## THE GAME IS OVER with nothing to stake (`ExitIfNoUsableDeckCards`): the
## pane ends with [constant GAME_OVER] and the world screen shows the end.
func _game_over() -> void:
	step = "game_over"
	result = GAME_OVER
	# The end screen shows the 1997 words, full screen ([AdventureEndScreen],
	# the world screen's [method WorldScreen.show_end]): this pane hands over
	# at once rather than say them twice. Deferred — this can run as the pane
	# enters the tree, before the world screen has heard of [signal finished].
	_end.call_deferred()


## THE MEETING OVER: the music stopped and the world's bed again,
## [signal finished] — once — and the pane gone; a World Magic's town
## found shows the map after (1997's `ShowWorldMapScreen`), a hero
## teleported is looked at where they now stand.
func _end() -> void:
	if _done:
		return
	_done = true
	step = "done"
	_stop_music()
	_close_list()
	WorldDuels.world_music(self)
	if bool(spoils.get("teleported", false)) and screen != null and screen.get("view") != null:
		var view: Variant = screen.get("view")
		if view is WorldView:
			(view as WorldView).camera = Vector2(player.position)
	finished.emit(result)
	if _map_after and screen != null and screen.has_method("toggle_map"):
		screen.call_deferred("toggle_map")
	queue_free()


## Whether the meeting is over.
func done() -> bool:
	return _done


# ------------------------------------------------------- words, choices --

## The words now: [param lines], a line each.
func say(lines: Array) -> void:
	_words.text = "\n".join(PackedStringArray(lines))
	_words.visible = not lines.is_empty()


## The choices now: [param actions], each `[id, words, ready]`; [param
## note_text] under them.
func offer(actions: Array, note_text := "") -> void:
	PaneStyle.drop_children(_choices)
	for action in actions:
		var choice := PaneStyle.button(String(action[1]), "Choice_" + String(action[0]), k)
		choice.disabled = not bool(action[2])
		choice.pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_button"))
		choice.pressed.connect(choose.bind(String(action[0])))
		# A DOUBLE CLICK'S SECOND PRESS IS NO CHOICE (the bug pass of part B,
		# q2-2): the choices are made again where the old ones stood, so a
		# double click on "Answer a riddle." answered the riddle unseen — and
		# a wrong answer lost the stake.
		choice.gui_input.connect(func(input: InputEvent) -> void:
			var press := input as InputEventMouseButton
			if press != null and press.double_click:
				choice.accept_event())
		_choices.add_child(choice)
	_note.text = note_text
	_note.visible = note_text != ""


## The words shown, the choices offered (their ids), the note.
func words() -> String:
	return _words.text if _words.visible else ""


func choice_ids() -> Array[String]:
	var out: Array[String] = []
	for child in _choices.get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.name).trim_prefix("Choice_"))
	return out


func note() -> String:
	return _note.text


# -------------------------------------------------------------- the lists --

## A list of cards over the world, this pane hidden under it
## ([CardListPane] in pick mode): [param on_pick] with the card picked,
## [param on_done] on Never mind or Escape.
func _open_list(title: String, subtitle: String, cards: Dictionary, on_pick: Callable,
		on_done: Callable) -> void:
	_close_list()
	var list := CardListPane.new()
	list.title = title
	list.subtitle = subtitle
	list.cards = cards
	list.picking = true
	list.k = k
	_list = list
	visible = false
	var parent := get_parent()
	parent.add_child(list)
	PaneStyle.centre(list)
	list.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	list.picked.connect(func(card_name: String) -> void:
		_close_list()
		on_pick.call(card_name), CONNECT_DEFERRED)
	list.done.connect(func() -> void:
		_close_list()
		on_done.call(), CONNECT_DEFERRED)


func _close_list() -> void:
	if is_instance_valid(_list):
		_list.queue_free()
	_list = null
	if not _done and step != "duel":
		visible = true


## The list open over the world, or null.
func card_list() -> CardListPane:
	return _list if is_instance_valid(_list) and not _list.is_queued_for_deletion() else null


# -------------------------------------------------------------- the music --

## [param key] looped (`music_duel`, `music_win_duel`, `music_lose_duel`), the
## world's bed stopped under it; nothing with the music switched off.
func _play_music(key: String) -> void:
	if not Settings.music_enabled():
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
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


# ------------------------------------------------------- keys and mouse --

func _unhandled_input(input: InputEvent) -> void:
	if not visible or _done:
		return
	if VisitPane.letter_choice(self, _choices, input):
		get_viewport().set_input_as_handled()
		return
	if not input.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	escape()


## A press of the mouse puts out the choice a letter lit.
func _input(input: InputEvent) -> void:
	VisitPane.drop_letter(_choices, input)


## ESCAPE, by the step (see the class doc).
func escape() -> void:
	match step:
		"meeting", "duel", "pick", "done", "riddle":
			# [Ours: 1997 slip — Escape at the riddle was a wrong answer and
			# lost the staked card (world_lair_monster_encounter.c:2049-2074);
			# the riddle waits for an answer, as the cards/clue choice no
			# longer loses the cards to Escape.]
			pass
		"tribute", "magics":
			result = NO_DUEL
			_end()
		"cards":
			# [Ours: 1997 slip — Escape took the clue and forfeited the cards.]
			choose("cards" if bool(spoils.get("asks", false)) else "go")
		"special":
			_start_duel()
		_:
			choose("go")


## A drag on the pane's glass moves it (the owner's movable panes), kept on
## the screen.
func _gui_input(input: InputEvent) -> void:
	var press := input as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			_drag = {"grip": press.global_position - global_position}
		else:
			_drag = {}
		accept_event()
		return
	var motion := input as InputEventMouseMotion
	if motion != null and not _drag.is_empty():
		var room := get_viewport_rect().size
		var to: Vector2 = motion.global_position - Vector2(_drag["grip"])
		to.x = clampf(to.x, 40.0 - size.x, room.x - 40.0)
		to.y = clampf(to.y, 0.0, room.y - 40.0)
		global_position = to
		accept_event()
