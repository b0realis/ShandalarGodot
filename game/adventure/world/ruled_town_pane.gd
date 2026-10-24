class_name RuledTownPane
extends PanelContainer
## A RULED TOWN'S DUEL AND ITS END ([RuledTowns], part B, 2026-10-23) — what
## follows "Duel the creature." on the town's pane ([VisitPane]): the duel
## held over the world ([WorldDuels]) while this pane waits hidden, then
## 1997's full-screen pictures in one of the world's movable rounded panes,
## on the 640 × 480 page of the meetings ([EncounterStage]):
##  - THE TOWN FREED: `Celeb.pic` (`town_freed`), "%s is freed! The people
##    rejoice.", the win music (`music_win_duel`) looping under it.
##  - A LOSS: `Losedul2.pic` (`lose_card`) with each staked card and "Lost
##    this card", a card at a time, the lose music (`music_lose_duel`).
##  - A DRAW: nothing changes, nothing is shown [ours: 1997 slip — a draw
##    lost the stake]; the duel's own window has said it.
##  - THE GAME OVER (the deck in use held no card to stake as the town was
##    entered): `Uth-Arz.pic` (`game_over`) and `@QUESTFAILED` 0, 1, 4, 5,
##    as the meetings show it ([EncounterPane]); on, [constant GAME_OVER].
## The world's bed comes back as the pane closes.
##
## [signal finished] once — [constant WON] (1), LOST (0), DRAWN (−1) or
## GAME_OVER (3) — and the pane frees itself. "Return to main menu" in the
## duel leaves the adventure unsaved and finishes nothing ([WorldDuels]).
## Escape at a picture goes on; during the duel it is the duel's. A right
## click on a card reads it; a drag on the glass moves the pane.

## The town's duel is over: [param result] (see the class doc).
signal finished(result: int)
## A card right-clicked, to be read full screen ([method WorldScreen.read_card]).
signal card_read(card_name: String)

const WON := 1
const LOST := 0
const DRAWN := -1
const GAME_OVER := 3
## The page's size against 1997's, at most and at least, and the room kept
## free above and below the pane (as [EncounterPane]'s).
const MOST := 1.25
const LEAST := 0.55
const ROOM_MARGIN := 32.0
## [Ours] The choice's words where 1997 waited for a key.
const GO_ON := "Continue"
## Where a lost card lies on `Losedul2.pic` (the meetings' place for it,
## [EncounterPane]).
const LOST_AT := Vector2(46, 120)
const LOST_WIDTH := 150.0

## The adventure.
var player: AdventurePlayer
## The world screen (it holds the duel).
var screen: Node
## The town's entry ([method RuledTowns.enter]).
var entry := {}
## The duel's meeting record ([method RuledTowns.meeting]), `{}` before it.
var meeting := {}
## What the duel left ([method RuledTowns.settle]), `{}` before it.
var outcome := {}
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
## Where the pane stands: `""`, `duel`, `freed`, `lost`, `game_over`, `done`.
var step := ""
var result := LOST
var stage: EncounterStage
var _title: Label
var _subtitle: Label
var _words: Label
var _choices: HFlowContainer
var _music: AudioStreamPlayer
var _music_key := ""
var _duel: WorldDuels
var _lost_shown := 0
var _done := false
var _drag := {}
var _most := 1.0
var _factor := 1.0
## The page's size on the step the player last answered: a later step's
## page may be smaller (more words under it), never larger — the page does
## not swell and shrink from click to click [ours].
var _ceiling := INF
var _relayout_queued := false


func _ready() -> void:
	name = "RuledTownPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var slot := int(entry.get("slot", -1))
	_title = PaneStyle.title(WorldNames.site_name(player.world, slot) if player != null else "")
	_title.name = "TownName"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var wizard := int(entry.get("wizard", 0))
	_subtitle = PaneStyle.label("Ruled by the " + WorldNames.WIZARDS[wizard - 1] if wizard >= 1 else "",
		15, PaneStyle.DIM)
	_subtitle.name = "TownKind"
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
	_words.name = "TownWords"
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_words)
	_choices = HFlowContainer.new()
	_choices.name = "TownChoices"
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("h_separation", int(8 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_choices)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = GameAudio.MUSIC_BUS
	_music.finished.connect(func() -> void:
		if _music_key != "" and is_inside_tree():
			_music.play())
	add_child(_music)
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	# The page as wide as the screen allows; how tall is what the words and
	# the choices leave of it, measured as they come ([method _fit]) — not a
	# guess of 260 · k, which with big buttons (k 1.6, a finger's) held the
	# page at 0.8 on an 800-high screen, its stakes unreadably small under
	# huge buttons, the room left empty above and below (the playtest of
	# part B, P4-1; the words and choices take about 200 there).
	_most = clampf((room.x - 120.0) / EncounterStage.PAGE.x, LEAST, MOST)
	_set_factor(_most)
	minimum_size_changed.connect(_fit)
	# Hidden until there is something to show: the duel comes first. Begun
	# after the frame, so whoever opened the pane has connected [signal
	# finished] before anything can end.
	visible = false
	_begin.call_deferred()


## THE DUEL BEGINS — or the game is over with nothing to stake.
func _begin() -> void:
	if _done or not is_inside_tree():
		return
	if bool(entry.get("no_ante", false)):
		_game_over()
		return
	_start_duel()


## THE DUEL OVER THE WORLD ([WorldDuels]), the minion drawn as it is chosen
## ([method RuledTowns.meeting]); the pane waits hidden.
func _start_duel() -> void:
	step = "duel"
	result = LOST
	meeting = RuledTowns.meeting(player, entry)
	var config := RuledTowns.duel_config(player, meeting)
	var host_on: Node = screen if screen != null else get_parent()
	_duel = WorldDuels.host(host_on, config, CreatureBook.name_of(int(meeting["row"])))
	_duel.ended.connect(_after_duel, CONNECT_ONE_SHOT)
	_duel.abandoned.connect(_abandoned, CONNECT_ONE_SHOT)


## The duel host while the duel is up (a test concedes or wins through it).
func duel_host() -> WorldDuels:
	return _duel if is_instance_valid(_duel) else null


## THE DUEL OVER ([param report]): settled, then its picture — or, a draw
## or a loss with nothing staked, the end at once.
func _after_duel(report: DuelReport) -> void:
	outcome = RuledTowns.settle(player, meeting, report, _duel != null and _duel.conceded)
	result = int(outcome["result"])
	match result:
		WON:
			_freed()
		LOST:
			if (outcome["lost"] as Array).is_empty():
				_end.call_deferred()
			else:
				_play_music("music_lose_duel")
				_next_lost()
		_:
			_end.call_deferred()


## The player left for the main menu mid-duel: nothing settled, nothing
## saved; the world screen goes ([WorldDuels]).
func _abandoned() -> void:
	_done = true
	step = "done"


## THE TOWN FREED (`Celeb.pic`, `@VISIT` 8).
func _freed() -> void:
	step = "freed"
	visible = true
	_play_music("music_win_duel")
	_subtitle.text = "Freed"
	stage.clear()
	stage.ground("town_freed")
	say(outcome["words"])
	offer([["go", GO_ON, true]])


## THE NEXT CARD LOST (`Losedul2.pic`, `@VISIT` 9), or the end after the last.
func _next_lost() -> void:
	var lost: Array = outcome.get("lost", [])
	if _lost_shown >= lost.size():
		_end()
		return
	step = "lost"
	visible = true
	stage.clear()
	stage.ground("lose_card")
	stage.card(String(lost[_lost_shown]), LOST_AT, LOST_WIDTH, "LostCard", RuledTowns.LOST_CARD)
	say([RuledTowns.LOST_CARD])
	_lost_shown += 1
	offer([["go", GO_ON, true]])


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


## WHAT A CHOICE DOES at the step the pane stands at.
func choose(_action: String) -> void:
	if _done:
		return
	# The step the player saw stood laid out: its page is the most the
	# next one may take ([member _ceiling]).
	_ceiling = _factor
	match step:
		"lost":
			_next_lost()
		"freed", "game_over":
			_end()


## THE PANE OVER: the music stopped and the world's bed again,
## [signal finished] — once — and the pane gone.
func _end() -> void:
	if _done:
		return
	_done = true
	step = "done"
	_stop_music()
	WorldDuels.world_music(self)
	finished.emit(result)
	queue_free()


## Whether the pane is over.
func done() -> bool:
	return _done


# ------------------------------------------------------- words, choices --

func say(lines: Array) -> void:
	_words.text = "\n".join(PackedStringArray(lines))
	_words.visible = not lines.is_empty()


func offer(actions: Array) -> void:
	PaneStyle.drop_children(_choices)
	for action in actions:
		var choice := PaneStyle.button(String(action[1]), "Choice_" + String(action[0]), k)
		choice.disabled = not bool(action[2])
		choice.pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_button"))
		choice.pressed.connect(choose.bind(String(action[0])))
		# A DOUBLE CLICK'S SECOND PRESS IS NO CHOICE (the playtest of part B,
		# P2-2; the meeting's q2-2 guard): the next lost card's Continue stands
		# where the last one's was, so a double click skipped a card's picture.
		choice.gui_input.connect(func(input: InputEvent) -> void:
			var press := input as InputEventMouseButton
			if press != null and press.double_click:
				choice.accept_event())
		_choices.add_child(choice)
	_queue_relayout()


func words() -> String:
	return _words.text if _words.visible else ""


func choice_ids() -> Array[String]:
	var out: Array[String] = []
	for child in _choices.get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.name).trim_prefix("Choice_"))
	return out


# -------------------------------------------------------------- the music --

## [param key] looped, the world's bed stopped under it; nothing with the
## music switched off.
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


# ------------------------------------------------------------ the stage --

func _set_factor(value: float) -> void:
	_factor = value
	stage.set_factor(value)
	var width := EncounterStage.PAGE.x * value
	for part: Control in [_words, _choices]:
		part.custom_minimum_size.x = width


## The pane kept on the screen (as [method EncounterPane._fit]), the page as
## large as the room left: the screen's height less what the words and the
## choices under it take (measured), up to what the width allows ([member
## _most]).
func _fit() -> void:
	if not is_inside_tree() or stage == null:
		return
	var room := get_viewport_rect().size.y - ROOM_MARGIN
	var rest := get_combined_minimum_size().y - stage.custom_minimum_size.y
	var grow := clampf((room - rest) / EncounterStage.PAGE.y, LEAST, minf(_most, _ceiling))
	if absf(grow - _factor) * EncounterStage.PAGE.y >= 1.0:
		_set_factor(grow)
	_queue_relayout()


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()


## The pane as small as its parts, about its own middle, kept on the screen.
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


# ------------------------------------------------------- keys and mouse --

func _unhandled_input(input: InputEvent) -> void:
	if not visible or _done or not input.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	escape()


## ESCAPE: on, at a picture; nothing during the duel.
func escape() -> void:
	if step in ["lost", "freed", "game_over"]:
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
