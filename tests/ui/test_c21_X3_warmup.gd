extends GutTest
## THE DUEL'S WARM-UP ASKS FOR WHAT THE DUEL WILL WEAR ([DuelWarmup]; the
## bug campaign of 0.50.66).
##  - h4-2: the coin movie's two sheets (39 MB of textures) only when the
##    player's toss is the movie — under "Our coin animation" or "Instant"
##    they were kept for the session and never drawn. The toss's sound
##    plays whatever the style.
##  - The owner's ruling (2026-10-29): Magic Battle warms all five colours
##    — each colour's grounds, frames and panels, its exile plate and hand
##    window — only when a random deck is picked ([constant
##    DuelWarmup.ANY_COLOR]); a creature not met yet keeps the five small
##    panels alone.
##  - h1-3: a warm-up let go (a duel opened, the game closing) never waits
##    for its worker while that task is still queued behind other warm-ups
##    — on a 2-6-core machine the engine runs low-priority tasks one at a
##    time ([method SkinWarmer.release]). The queue is filled here with
##    blockers the test holds, so the worker is certainly waiting behind
##    them; each gives up on its own after [constant HOLD_MS], so a wait the
##    fix removed shows as that long a call instead of a hang.

const HOLD_MS := 1500
## A call that does not wait behind the blockers returns well inside this.
const QUICK_MS := 300


## What a blocker holds on: the test opens it.
class Gate extends RefCounted:
	var open := false
	var running := 0
	var lock := Mutex.new()

	func hold() -> void:
		lock.lock()
		running += 1
		lock.unlock()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < HOLD_MS:
			lock.lock()
			var done := open
			lock.unlock()
			if done:
				return
			OS.delay_msec(1)

var _saved_coin: Variant = null
var _had_coin := false
var _warmups: Array = []
var _gate: Gate = null
var _blockers: Array[int] = []


func before_each() -> void:
	_had_coin = Settings.has_value(DuelOptions.COIN_FLIP_KEY)
	_saved_coin = Settings.get_value(DuelOptions.COIN_FLIP_KEY, null)
	DuelWarmup.forced = 1
	_warmups = []
	_gate = Gate.new()
	_blockers = []


func after_each() -> void:
	_open_gate()
	DuelWarmup.forced = -1
	# Every warm-up a test started goes: one in the tree is finished where
	# it stands, one not in it yet frees itself as it joins ([method
	# DuelWarmup._ready]), asking for nothing.
	for warmup in _warmups:
		if not is_instance_valid(warmup):
			continue
		if (warmup as DuelWarmup).is_inside_tree():
			(warmup as DuelWarmup)._finish()
		else:
			(warmup as DuelWarmup)._done = true
	await get_tree().process_frame
	await get_tree().process_frame
	if _had_coin:
		Settings.set_value(DuelOptions.COIN_FLIP_KEY, _saved_coin)
	else:
		Settings.clear_value(DuelOptions.COIN_FLIP_KEY)
	SetupScreen.forget_choices()


func _host() -> Node:
	var host: Node = autofree(Node.new())
	add_child(host)
	return host


func _kept(warmup: DuelWarmup) -> DuelWarmup:
	if warmup != null:
		_warmups.append(warmup)
	return warmup


# -------------------------------------------------------- h4-2: the coin --

func test_the_coin_movie_is_warmed_only_for_the_movie() -> void:
	DuelOptions.set_coin_flip_style(DuelOptions.COIN_VIDEO)
	var movie := _kept(DuelWarmup.warm(_host(), ["green"] as Array[String]))
	assert_has(movie._pictures, "coin_toss_heads", "the movie: its sheets")
	assert_has(movie._pictures, "coin_toss_tails")
	assert_false(GameSkin.is_kept("coin_toss_heads"),
		"asked for, not read here: the warmer reads them off this thread")
	for style in [DuelOptions.COIN_RECREATION, DuelOptions.COIN_INSTANT]:
		DuelOptions.set_coin_flip_style(style)
		var other := _kept(DuelWarmup.warm(_host(), ["green"] as Array[String]))
		assert_does_not_have(other._pictures, "coin_toss_heads",
			"%s: 39 MB the toss never draws" % style)
		assert_does_not_have(other._pictures, "coin_toss_tails", style)
		assert_has(other._sounds, "sfx_toss", "%s: the toss's sound all the same" % style)


# ---------------------------------------------- the ruling: random decks --

func test_a_random_seat_warms_all_five_colours_in_full() -> void:
	var keys := DuelWarmup.pictures_for([DuelWarmup.ANY_COLOR, "green"] as Array[String])
	for color in AdventurePlayer.COLORS:
		for pattern in DuelWarmup.SEAT_PICTURES:
			assert_has(keys, pattern % color, "%s: %s" % [color, pattern % color])
		var ground := DuelOptions.ground_for(0, 0, color, {})
		assert_has(keys, DuelOptions.ground_key(String(ground["color"]), String(ground["type"])),
			"%s: the ground seat 0 would lay" % color)
	var opponent := DuelOptions.ground_for(1, 0, "green", {})
	assert_has(keys, DuelOptions.ground_key(String(opponent["color"]), String(opponent["type"])),
		"the known seat's own ground")
	var unknown := DuelWarmup.pictures_for(["green", ""] as Array[String])
	assert_does_not_have(unknown, "card_frame_red", "a creature not met: never the five frames")
	assert_has(unknown, "hand_panel_red", "its five small panels, as before")


func test_a_random_seat_makes_all_five_exile_plates_and_hand_windows() -> void:
	var warmup := DuelWarmup.new()
	warmup._colors = [DuelWarmup.ANY_COLOR, "green"] as Array[String]
	warmup._small_ones()
	assert_eq((warmup._small as Array).size(), 2 * AdventurePlayer.COLORS.size(),
		"a plate and a window a colour, the known seat's among them once")
	warmup.free()


func test_magic_battle_warms_all_five_only_for_a_random_pick() -> void:
	SetupScreen.forget_choices()
	var screen: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	_warmups.append_array(_queued())
	# A deck picked for each seat: those colours alone.
	for pid in 2:
		var picker: OptionButton = screen._deck_options[pid]
		picker.select(_first_deck_row(picker))
	screen._warmed = {}
	var picked := _kept(screen._warm_duel())
	assert_not_null(picked, "control: the warm-up runs (forced)")
	for color in picked._colors:
		assert_ne(color, DuelWarmup.ANY_COLOR, "a deck picked: its own colour")
	var known: Array[String] = picked._colors.duplicate()
	for color in AdventurePlayer.COLORS:
		if color not in known:
			assert_does_not_have(picked._pictures, "card_frame_" + color,
				"no frame of a colour neither deck is")
	assert_null(screen._warm_duel(), "nothing new picked: nothing started")
	# `<random deck>` picked for seat 0: all five, once.
	screen._deck_options[0].select(0)
	screen._deck_options[0].item_selected.emit(0)
	await get_tree().process_frame
	var random: Array = _queued().filter(func(w: DuelWarmup) -> bool: return w not in _warmups)
	assert_eq(random.size(), 1, "the pick started one warm-up")
	_warmups.append_array(random)
	if random.size() == 1:
		var warmup: DuelWarmup = random[0]
		assert_eq(warmup._colors[0], DuelWarmup.ANY_COLOR)
		for color in AdventurePlayer.COLORS:
			assert_has(warmup._pictures, "card_frame_" + color, "%s: its frame" % color)
	assert_null(screen._warm_duel(), "all five warmed: a later pick adds nothing")


## The warm-ups under the root (each joins it at the end of its frame).
func _queued() -> Array:
	var out: Array = []
	for child in get_tree().root.get_children():
		if child is DuelWarmup:
			out.append(child)
	return out


func _first_deck_row(picker: OptionButton) -> int:
	for i in picker.item_count:
		if picker.is_item_separator(i):
			continue
		var meta := str(picker.get_item_metadata(i))
		if meta != "" and not meta.begins_with(SetupScreen.GROUP_RANDOM):
			return i
	return -1


# ------------------------------------- h1-3: never wait behind a warm-up --

## Every low-priority thread taken by a blocker, and more queued behind.
func _fill_the_queue() -> void:
	for i in maxi(OS.get_processor_count(), 2):
		_blockers.append(WorkerThreadPool.add_task(_gate.hold, false, "c21 X3 blocker"))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 500:
		_gate.lock.lock()
		var running := _gate.running
		_gate.lock.unlock()
		if running > 0:
			break
		OS.delay_msec(1)


func _open_gate() -> void:
	if _gate == null:
		return
	_gate.lock.lock()
	_gate.open = true
	_gate.lock.unlock()
	for task in _blockers:
		WorkerThreadPool.wait_for_task_completion(task)
	_blockers = []


func test_a_warm_up_let_go_waits_for_no_warm_up_ahead_of_it() -> void:
	_fill_the_queue()
	var warmup := DuelWarmup.new()
	warmup._stones = DuelWarmup.StoneWork.new()
	for i in 4:
		warmup._stones.jobs.append({})      # nothing to make: a stone's place
	warmup._launch()
	assert_ne(warmup._task, -1, "control: its worker is queued")
	var before := SkinWarmer.unclaimed()
	var start := Time.get_ticks_msec()
	warmup._exit_tree()                     # the game closing, a duel opened
	var took := Time.get_ticks_msec() - start
	assert_lt(took, QUICK_MS, "let go at once, not after the blockers (%d ms)" % took)
	assert_true(warmup._stones.stop, "told to stop")
	assert_false(warmup._stones.started, "its task had not started")
	assert_eq(SkinWarmer.unclaimed(), before + 1, "held until its task has run")
	assert_eq(warmup._task, -1, "and no longer its to wait for")
	var stones := warmup._stones
	warmup.free()
	_open_gate()
	for i in 200:
		if SkinWarmer.unclaimed() == before:
			break
		await get_tree().process_frame
	assert_eq(SkinWarmer.unclaimed(), before, "reclaimed once it ran")
	assert_eq(stones.made(), 0, "and it made nothing: it saw stop first")


func test_a_duel_that_wants_the_stones_now_still_waits_for_them() -> void:
	var warmup := DuelWarmup.new()
	warmup._stones = DuelWarmup.StoneWork.new()
	for i in 3:
		warmup._stones.jobs.append({})
	warmup._specs = []
	warmup._columns = []
	warmup._small = []
	warmup._launch()
	warmup.finish_now()
	assert_true(warmup._stones.started, "claimed on purpose: it ran")
	assert_eq(warmup._stones.made(), 3, "to its last stone")
	assert_true(warmup.finished())
	warmup.free()
