class_name DuelWarmup
extends Node
## THE DUEL MADE READY BEFORE IT OPENS (the smoothness pass, 0.50.66; the
## owner, 2026-10-29: *"I really want our adventure to play silky butter
## smooth"*). A duel's screen is built in the frame its button is clicked
## ([method DuelScreen._build_ui]), and the first duel of a session read
## its pictures off the disk there and walked its stones pixel by pixel
## ([method OriginalDialog.stone_job]): 135 ms of one frame on the desk, 420
## with the 2x skin. The later duels find all of it kept.
##
## [method warm] does that work while the player reads what comes before
## the duel — the meeting, the setup — and off the thread that draws:
##  1. the duel's pictures and sounds decoded on a worker and kept a few a
##     frame ([SkinWarmer]): the table's own, and each seat colour's
##     ([constant SEAT_PICTURES], the ground [DuelOptions] would lay);
##  2. once their pictures are kept, the stones ([constant STONES]) and
##     the Combat Bar's keyed columns made on a worker ([method
##     OriginalDialog.make_stone], [method CombatBar.make_keyed]) and kept
##     on the main thread ([method OriginalDialog.keep_stone], [method
##     CombatBar.keep_keyed]) — the same pixels the duel would make;
##  3. each seat colour's exile plate and hand window, one a frame.
## A duel that opens before the warm-up is through makes what is missing
## as before; nothing waits for it. Memory: nothing the first duel would
## not have kept for the session anyway, kept sooner — the table's
## pictures ([constant PICTURES]: 5.2 MB of textures with the 1997 skin,
## 20.7 MB with the 2x skin), its stones and the Combat Bar's two columns
## (2.7 / 10.6 MB), each seat colour's 1.8 / 7.1 MB, and the coin's sheets
## (39 MB, only with [param coin] of [method warm], a duel at hand).
##
## NOT HEADLESS (the tests, the tools), NOT ON THE WEB, nor where the
## engine has no threads ([method SkinWarmer.runs_here], [member forced]):
## there the duel makes everything as it opens, as before.

## The table's own pictures, whatever its colours: 5.2 MB of textures
## with the 1997 skin, 20.7 MB with the 2x skin.
const PICTURES: Array[String] = ["message_panel", "attack_panel", "attack_min", "attack_bones",
	"phase_bar", "combat_bar", "mana_pool_panel", "mana_stripes", "panel_dark_stone",
	"button_normal", "button_pressed", "button_disabled", "versus_splash",
	"versus_background", "card_frame_artifact", "card_back", "summon_sick", "panel_end_duel"]
## The coin's two sheets — 2240x2160 each, 39 MB of textures with either
## skin — warmed only when a duel is at hand ([param coin] of [method
## warm]: a meeting, a setup), never on arrival in the world.
const COIN_PICTURES: Array[String] = ["coin_toss_heads", "coin_toss_tails"]
## The small ones of [constant SEAT_PICTURES], warmed in all five colours
## for a seat whose colour is not known yet.
const SMALL_SEAT_PICTURES: Array[String] = ["life_panel_%s", "grave_panel_%s", "hand_panel_%s"]
## Each seat colour's pictures (`%s` the colour key), and the ground
## [DuelOptions] would lay: 1.8 MB of textures with the 1997 skin, 7.1 MB
## with the 2x skin, a colour.
const SEAT_PICTURES: Array[String] = ["life_panel_%s", "grave_panel_%s", "hand_panel_%s",
	"card_frame_%s", "card_frame_land_%s"]
## The sounds of a duel's opening (and the coin's, with its sheets).
const SOUNDS: Array[String] = ["sfx_shuffle", "sfx_draw", "sfx_button"]
const COIN_SOUNDS: Array[String] = ["sfx_toss"]
## The stones a duel wears: [kind, picture, raised, gain] — the four faces
## of the bar's button ([method OriginalDialog.dress_bar_button]), the
## Combat window's ruled field, two seamless grounds. The Situation Bar's own (ruled or ridged,
## the player's frame) is added by [method _stone_specs].
const STONES: Array = [
	[OriginalDialog.STONE_BUTTON, "message_panel", true, 1.55],
	[OriginalDialog.STONE_BUTTON, "message_panel", false, 1.55],
	[OriginalDialog.STONE_BUTTON, "message_panel", true, 1.18],
	[OriginalDialog.STONE_BUTTON, "message_panel", true, 1.78],
	[OriginalDialog.STONE_RULED, "attack_panel", true, 1.55],
	# The menus' and the questions' dark stone, the End of Duel window's
	# rings ([method OriginalDialog.ground], THE SEAMLESS GROUNDS).
	[OriginalDialog.STONE_GROUND, "panel_dark_stone", true, 1.55],
	[OriginalDialog.STONE_GROUND, "panel_end_duel", true, 1.55],
]
## How long a frame may spend keeping stones (making their textures).
const KEEP_BUDGET_US := 2000
## Tests: 1 warms headless too, 0 never, -1 by the rule ([method runs_here]).
static var forced := -1


## The stones (and the Combat Bar's keyed columns) made by a worker. The
## worker writes only into the jobs and [member done], under [member lock].
class StoneWork extends RefCounted:
	var jobs: Array[Dictionary] = []
	var done := 0
	var stop := false
	var lock := Mutex.new()

	func run() -> void:
		for i in jobs.size():
			lock.lock()
			var stopped := stop
			lock.unlock()
			if stopped:
				return
			DuelWarmup.make(jobs[i])
			lock.lock()
			done = i + 1
			lock.unlock()

	func made() -> int:
		lock.lock()
		var count := done
		lock.unlock()
		return count


var _stones: StoneWork = null
var _task := -1
var _kept := 0
var _done := false
## The pictures to ask for, whether they were, and the stones still to be
## made jobs of.
var _pictures: Array[String] = []
var _sounds: Array[String] = []
var _colors: Array[String] = []
## The Combat Bar's columns still to read back ([method _read_one_column]),
## and whether the worker was started.
var _columns: Array = []
var _launched := false
## The small ones still to make ([method _small_ones]); null before.
var _small = null
var _asked := false
var _specs: Array = []
## The skin's warmer decoding this duel's pictures and sounds (under the
## parent: it outlives this node when the stones are made first).
var _skin: SkinWarmer = null


## True where the warm-up runs: [method SkinWarmer.runs_here]'s rule
## ([member forced] for tests).
static func runs_here() -> bool:
	if forced >= 0:
		return forced == 1
	return SkinWarmer.runs_here()


## Starts warming a duel whose seats may wear [param colors] (colour keys,
## `"green"`; either may be `""`) — [param hero_mat] the hero's playmat
## ([member DuelConfig.territories], `{color, type}`) — for [param parent]
## (a meeting's pane, the setup screen, the world). The warm-up itself
## lives under the tree's root, joined at the end of the frame: it outlives
## the screen that asked for it — the setup screen is gone the moment Go!
## is pressed, and waiting there for a stone in the making would be the
## very freeze this is for; it frees itself when done. [param sounds] the
## holder's own besides [constant
## SOUNDS]; [param coin] false leaves the coin's sheets to be read when it
## is tossed (a warm-up long before any duel). Nothing more happens in this frame: the files are asked
## for in the next ([method _process]). Null when it does not run here.
static func warm(parent: Node, colors: Array[String] = [], hero_mat := {},
		sounds: Array[String] = [], coin := true) -> DuelWarmup:
	if not runs_here() or parent == null or not parent.is_inside_tree():
		return null
	var warmup := DuelWarmup.new()
	warmup.name = "DuelWarmup"
	warmup._pictures = pictures_for(colors, hero_mat)
	warmup._colors = colors.duplicate()
	warmup._sounds = SOUNDS.duplicate()
	if coin:
		warmup._pictures.append_array(COIN_PICTURES)
		warmup._sounds.append_array(COIN_SOUNDS)
	for key in sounds:
		if key not in warmup._sounds:
			warmup._sounds.append(key)
	parent.get_tree().root.add_child.call_deferred(warmup)
	return warmup


## The pictures a duel with seats wearing [param colors] opens with.
static func pictures_for(colors: Array[String], hero_mat := {}) -> Array[String]:
	var out: Array[String] = []
	# The two stones' pictures first, so the stones can start early.
	out.append_array(PICTURES)
	for pid in colors.size():
		var color := String(colors[pid])
		if color == "":
			# A seat whose colour is not known yet (a random deck, the
			# creature not met): the five colours' small panels, 0.5 MB of
			# textures (1.9 MB 2x) — never the five grounds and frames.
			for any in AdventurePlayer.COLORS:
				for pattern in SMALL_SEAT_PICTURES:
					var small_key := pattern % any
					if small_key not in out:
						out.append(small_key)
			continue
		var ground := DuelOptions.ground_for(pid, 0, color, hero_mat if pid == 0 else {})
		var key := DuelOptions.ground_key(String(ground["color"]), String(ground["type"]))
		if key not in out:
			out.append(key)
		for pattern in SEAT_PICTURES:
			var seat_key := pattern % color
			if seat_key not in out:
				out.append(seat_key)
	return out


## The stones to make, as [method OriginalDialog.stone_job] specs: [constant
## STONES] and the Situation Bar's, in the frame the player chose.
static func _stone_specs() -> Array:
	var out := STONES.duplicate()
	var frame := DuelOptions.bar_frame()
	if frame == DuelOptions.BAR_FRAME_SHANDALARGODOT:
		out.append([OriginalDialog.STONE_RULED, "message_panel", true, 1.55])
	else:
		out.append([OriginalDialog.STONE_RIDGED, "message_panel", true, 1.55, frame])
	return out


func _ready() -> void:
	if _done:
		queue_free()        # finished before it joined the tree (a test)
		return
	set_process(true)


## ONE STEP A FRAME on this thread, each a few milliseconds at most:
##  1. the files asked for ([SkinWarmer], beside this node under the root:
##     it outlives this node when the stones are done first);
##  2. the stones wait for their pictures — kept by the skin's warmer, or,
##     once it is done, read as a duel would read them;
##  3. each picture's pixels read back, one picture a frame, into the
##     stones' jobs, and the Combat Bar's two columns ([method
##     CombatBar.keyed_job]); then the worker makes them all;
##  4. what it made kept as it is made, [constant KEEP_BUDGET_US] a frame
##     (at least one);
##  5. the small ones ([method _small_ones]), one a frame.
func _process(_delta: float) -> void:
	if _done:
		return
	if not _asked:
		_asked = true
		_skin = SkinWarmer.warm(get_parent(), _pictures, _sounds)
		return
	if _stones == null:
		var warming := is_instance_valid(_skin) and not _skin.finished()
		for spec in _stone_specs():
			if warming and not GameSkin.is_kept(String(spec[1])):
				return
		_stones = StoneWork.new()
		_specs = _stone_specs()
		_columns = [false, true]
		return
	if not _specs.is_empty():
		_read_one_picture()
		return
	if not _columns.is_empty():
		_read_one_column()
		return
	if not _launched:
		_launch()
		return
	if _small != null:
		if not _small.is_empty():
			(_small.pop_front() as Callable).call()
		if _small.is_empty():
			_finish()
		return
	var started := Time.get_ticks_usec()
	var made := _stones.made()
	while _kept < made:
		keep(_stones.jobs[_kept])
		_kept += 1
		if Time.get_ticks_usec() - started >= KEEP_BUDGET_US:
			break
	if _kept >= _stones.jobs.size():
		_stop_worker()
		_small_ones()


## The first waiting picture's pixels read back once, and every stone of
## it made a job.
func _read_one_picture() -> void:
	var key := String(_specs[0][1])
	var art := GameSkin.texture(key)
	var pixels: Image = art.get_image() if art != null else null
	var rest: Array = []
	for spec in _specs:
		if String(spec[1]) != key:
			rest.append(spec)
			continue
		if pixels == null:
			continue
		var job := OriginalDialog.stone_job(String(spec[0]), key, bool(spec[2]), float(spec[3]),
			String(spec[4]) if spec.size() > 4 else "", pixels)
		if not job.is_empty():
			_stones.jobs.append(job)
	_specs = rest


## One of the Combat Bar's two columns (the gold when the opponent attacks,
## the blue when the player does) read back into a job, for the same worker
## after the stones.
func _read_one_column() -> void:
	var job := CombatBar.keyed_job(CombatBar.column_region(bool(_columns.pop_front())),
		CombatBar.Fill.BLACK)
	if not job.is_empty():
		job["work"] = "keyed"
		_stones.jobs.append(job)


func _launch() -> void:
	_launched = true
	if _stones.jobs.is_empty():
		_small_ones()
		return
	_task = WorkerThreadPool.add_task(_stones.run, false, "Duel warm-up")


## One job made, by its work. Any thread.
static func make(job: Dictionary) -> void:
	if String(job.get("work", "")) == "keyed":
		CombatBar.make_keyed(job)
	else:
		OriginalDialog.make_stone(job)


## One job kept, by its work. Main thread.
static func keep(job: Dictionary) -> void:
	if String(job.get("work", "")) == "keyed":
		CombatBar.keep_keyed(job)
	else:
		OriginalDialog.keep_stone(job)


## THE SMALL ONES, one a frame on this thread (a few milliseconds each the
## first time, nothing after): each seat colour's exile plate and hand
## window — then done.
func _small_ones() -> void:
	_small = []
	for color in _colors:
		if color == "":
			continue
		_small.append(func() -> void: ExilePlate.plate(color))
		_small.append(func() -> void: StackHand.window_texture(color))
	if _small.is_empty():
		_finish()


## Whether every stone is kept (or nothing was left to make).
func finished() -> bool:
	return _done


## Waits for the worker and keeps every stone now — a test, or a duel that
## wants them this frame.
func finish_now() -> void:
	if _stones == null:
		_stones = StoneWork.new()
		_specs = _stone_specs()
		_columns = [false, true]
	while not _specs.is_empty():
		_read_one_picture()
	while not _columns.is_empty():
		_read_one_column()
	if not _launched:
		_launch()
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		while _kept < _stones.made():
			keep(_stones.jobs[_kept])
			_kept += 1
	if _small == null:
		_small_ones()
	while _small != null and not _small.is_empty():
		(_small.pop_front() as Callable).call()
	_finish()


func _finish() -> void:
	_done = true
	set_process(false)
	_stop_worker()
	if is_inside_tree():
		queue_free()


func _stop_worker() -> void:
	if _task == -1:
		return
	if _stones != null:
		_stones.lock.lock()
		_stones.stop = true
		_stones.lock.unlock()
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


func _exit_tree() -> void:
	_stop_worker()
