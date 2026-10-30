class_name MusicPlayer
extends AudioStreamPlayer
## THE TUNE ON THE MUSIC BUS — a playlist of whole tracks, not one sample
## on repeat.
##
## **WHAT THIS REPLACED, and why.** Until 2026-09-03 this class did one
## thing: load the manifest key it was handed, patch `loop_mode` and
## `loop_end` onto the [AudioStreamWAV], and play it forever. The 1997
## game does exactly that — `MAGIC.EXE` (entry `004ebfef`) opens a duel on
## `Dueltune.wav` and sets the loop marker — and it was faithful, and it
## was wrong to ship as the only option, because **`Dueltune.wav` is TEN
## seconds long** — 889 184 bytes of 22 050 Hz 16-bit STEREO, 10.08 s, not
## the twenty a mono reading of the byte count gives. In 1997 a duel was
## short and the machine was loud and nobody noticed. The owner's
## playtest, 2026-09-03: *"Music in the duel is wrong — now it is
## repeating a short sample — unacceptable."*
##
## So the default is now a PLAYLIST of the twenty-seven beds the original
## actually has ([MusicLibrary]), and the 1997 single-bed loop is one of
## the choices rather than the only behaviour.
##
## **THE SEAM BETWEEN TRACKS.** [AudioStreamPlaylist] is Godot's own
## sequencer and it is used here for one property above all: `fade_time`.
## Two consecutive samples butted together click, because the first ends
## on a non-zero sample and the second starts on another one — that
## discontinuity IS the click the old loop made every ten seconds. A
## crossfade removes it by construction, and it costs nothing to ask for.
## It also means the sequencing happens on the audio thread instead of in
## a `finished` handler a frame later, so there is no gap either.
##
## **WHY A SINGLE CHOSEN TRACK IS IN THE LIST TWICE.** A one-entry
## playlist has no seam to fade ACROSS when it wraps, so it would click
## exactly like the old loop did. The same stream listed twice gives the
## sequencer a real transition to fade, and costs no memory at all — it is
## the same [Resource] both times.
##
## **MEMORY, WHICH IS WHY THE LIST IS CAPPED.** Every stream in an
## [AudioStreamPlaylist] is resident. One imported `LocMus` is ~2.8 MB of
## 22 kHz PCM and there are twenty-seven of them, so a playlist of
## everything would hold 76 MB for something one voice plays one at a
## time. [constant MAX_TRACKS] windows it: eight tracks is about four
## minutes of music and about 22 MB, and the window MOVES — see
## [member _cursor].
##
## **IT SURVIVES A DUEL ENDING.** The shuffled order and the position in
## it are `static`, so they belong to the SESSION rather than to this
## node. A duel screen builds a [MusicPlayer], plays eight tracks' worth,
## and is freed when the duel ends; the next duel picks up at track nine
## instead of starting the same shuffle again. Over an evening the player
## hears the whole library instead of the same eight tunes.
##
## The old behaviour, for the record: `Dueltune.wav` on repeat is one
## ten-second bar SIXTY times in a ten-minute duel, with a click on every
## wrap because the sample's last frame is nowhere near its first.
##
## **NOTHING HAPPENS WITHOUT A DISPLAY.** A headless run never loads a
## sample and never starts a voice — the test suite and the Deck Lab must
## not pay for music they cannot hear.

## How many tunes may be resident at once. See the class doc.
##
## [AudioStreamPlaylist] itself stops at 64; this is far below that and
## the limit that binds is memory, not the engine's.
const MAX_TRACKS := 8

## Seconds of crossfade between one track and the next. Long enough to
## hide a hard edit, short enough that two beds are never really playing
## against each other.
const FADE := 1.5

## The context key currently playing (`music_duel`, `music_location_7`),
## empty when stopped. The duel screen and the deck builder speak in these
## and nothing else; what they get for one is [MusicLibrary]'s business.
var key := ""

## The track ids this player is holding, in order. Read by tests.
var tracks: Array[String] = []

## Set true for a run with no audio device (see the class doc).
var silent := false

## THE SESSION'S OWN SHUFFLE, and the reason a duel ending does not reset
## the music. Static because it outlives every screen that plays it.
static var _order: Array[String] = []
static var _order_key := ""
static var _cursor := 0


func _ready() -> void:
	GameAudio.ensure_buses()
	bus = GameAudio.MUSIC_BUS
	silent = DisplayServer.get_name() == "headless"
	set_process(_window != null)


## Start the music a screen asks for, by CONTEXT key (`music_duel`,
## `music_location_3`). Calling it again with that context already playing
## does nothing, so a screen may call it from anywhere without restarting
## the music. A context the player has no tunes for is silence, not an
## error.
func play_key(new_key: String) -> void:
	if new_key == "" or silent:
		return
	if playing and key == new_key:
		return
	if _window != null and _window_key == new_key:
		return   # already on its way (THE WINDOW OFF THE THREAD THAT DRAWS)
	var ids := next_tracks(new_key)
	if ids.is_empty():
		return
	_drop_window()
	if _open_window(new_key, ids):
		return
	var built := build_stream(ids)
	if built == null:
		return
	key = new_key
	tracks = ids
	stream = built
	play()


## Play exactly these track ids, in this order — the seam the tests act
## through, and what a preview button would use. Empty is silence.
func play_tracks(ids: Array[String]) -> void:
	if silent or ids.is_empty():
		return
	_drop_window()
	var built := build_stream(ids)
	if built == null:
		return
	key = ""
	tracks = ids
	stream = built
	play()


## PLAY EXACTLY ONE BED, ON REPEAT — the Deck Builder's mode since the
## owner's playtest of 2026-09-04 (*"Deck builder: only the first song you
## now use should loop over."*).
##
## It is [method play_tracks] with the ONE thing that method cannot give a
## screen: a KEY, so calling it again with the same bed already playing
## does nothing. That is what lets a screen re-apply its own music switch
## on every settings change without the tune restarting from the top each
## time — the same contract [method play_key] keeps for a playlist.
##
## The seam it wraps still holds: a one-entry list is listed TWICE by
## [method build_stream], so the wrap is a crossfade and not the click the
## 1997 loop marker made every ten seconds.
func play_one(id: String) -> void:
	if id == "" or silent:
		return
	if playing and key == id:
		return
	var ids: Array[String] = [id]
	_drop_window()
	var built := build_stream(ids)
	if built == null:
		return
	key = id
	tracks = ids
	stream = built
	play()


## Stop, and forget which tune was loaded so the next [method play_key]
## always starts something. The session's place in the shuffle is NOT
## forgotten — that is the point of [member _cursor].
func stop_music() -> void:
	_drop_window()
	key = ""
	tracks = []
	stop()
	# Drop the streams with the playback. A stopped duel screen holding
	# 22 MB of PCM until it is collected is 22 MB nobody can hear.
	stream = null


# --- the smoothness pass (0.50.66, M1): the window off the thread that draws ---
## THE WINDOW OFF THE THREAD THAT DRAWS (the smoothness pass, 0.50.66; the
## owner, 2026-10-29: *"I really want our adventure to play silky butter
## smooth"*). [method build_stream] reads every tune of the window before
## the first note — eight with the shuffle on, about 2.7 MB of 1997 PCM
## each — and a duel asks for its window as it opens ([DuelAudio]): 128-152
## ms of every duel's opening on the desk, about 230 with the 2x skin, on
## the thread that draws. So [method play_key] hands the tunes that are not
## kept to a worker ([method MusicLibrary.tune_job], [method
## MusicLibrary.decode_tune] there, [method MusicLibrary.keep_tune] back on
## this thread), and plays THE SAME LIST — the same tunes in the same
## order, held by the playlist as [method build_stream] holds them:
##  - it starts once its first tune is there; each later tune's place is an
##    empty [AudioStreamWAV] the tune is laid into as it arrives ([method
##    _fill]). The sequencer reads a place only when it reaches it;
##  - A TUNE IS NEVER SKIPPED: a sequencer reaching an empty place skips it,
##    so should the worker still be busy when the playing tune is [constant
##    DEADLINE] seconds (and its crossfade) from its end, the rest is waited
##    for there and then ([method settle_window]);
##  - a window holding a tune that is no WAV (a player's own .ogg or .mp3,
##    which cannot be laid into a place) starts once all of it is decoded;
##  - one that would not read is an empty place, skipped — [method
##    build_stream] leaves it out;
##  - headless, on the web, without threads ([method decodes_off_thread]):
##    the whole list at once, as before. And while nothing is new — every
##    tune kept already — at once too: there is nothing to wait for.
## Memory: as before. A tune laid into its place is the one kept
## ([member MusicLibrary._kept]), the decoded copy let go.

## Seconds before the playing tune's crossfade by which the rest of the
## window must be in its places.
const DEADLINE := 2.0

## Tests: 1 decodes off the main thread headless too, 0 never, -1 by the
## rule ([method decodes_off_thread]).
static var threaded := -1


## A window's tunes, decoded by a worker. The worker writes only into the
## jobs it decodes and [member done], under [member lock]; the main thread
## reads a job only once [member done] has passed it.
class TuneWindow extends RefCounted:
	## One per id of the window: [method MusicLibrary.tune_job]'s, `{}` for
	## a tune settled without the worker (kept, or none).
	var jobs: Array[Dictionary] = []
	var done := 0
	var stop := false
	## Set by the worker as it begins (h1-3, [method SkinWarmer.release]).
	var started := false
	var lock := Mutex.new()

	func run() -> void:
		lock.lock()
		started = true
		lock.unlock()
		for i in jobs.size():
			lock.lock()
			var stopped := stop
			lock.unlock()
			if stopped:
				return
			MusicLibrary.decode_tune(jobs[i])
			lock.lock()
			done = i + 1
			lock.unlock()

	func decoded() -> int:
		lock.lock()
		var count := done
		lock.unlock()
		return count


var _window: TuneWindow = null
var _task := -1
var _window_key := ""
var _window_ids: Array[String] = []
## Per id: the tune (null for none, or not yet), and whether it is settled.
var _tunes: Array = []
var _settled: Array[bool] = []
## How many jobs have been kept on this thread.
var _taken := 0
## The playlist once it plays, and the places still waiting for a tune.
var _list: AudioStreamPlaylist = null
var _places: Dictionary = {}
## The tune that opened the list (its length sets the deadline).
var _opening: AudioStream = null


## True where a worker thread may decode a window: an engine with threads,
## a screen, not the web ([member threaded] for tests).
static func decodes_off_thread() -> bool:
	if threaded >= 0:
		return threaded == 1
	return OS.has_feature("threads") and not OS.has_feature("web") \
		and DisplayServer.get_name() != "headless"


## How far into an opening tune of [param length] seconds the rest of the
## window must be in its places: before its crossfade, with [constant
## DEADLINE] to spare; at once for a short one.
static func due(length: float) -> float:
	return maxf(0.0, length - FADE - DEADLINE)


## Whether a window is still being decoded or laid into its places.
func window_pending() -> bool:
	return _window != null


## [param ids] for context [param new_key] handed to a worker; false when
## it is not for one (see the class doc above), and [method play_key]
## builds the list at once.
func _open_window(new_key: String, ids: Array[String]) -> bool:
	if not decodes_off_thread() or ids.size() > MAX_TRACKS:
		return false
	var jobs: Array[Dictionary] = []
	var any := false
	for id in ids:
		var job := MusicLibrary.tune_job(id)
		jobs.append(job)
		any = any or not job.is_empty()
	if not any:
		return false       # every tune kept, or none there: nothing to wait for
	_drop_window()
	_window = TuneWindow.new()
	_window.jobs = jobs
	_window_key = new_key
	_window_ids = ids
	_tunes = []
	_settled = []
	for i in ids.size():
		if jobs[i].is_empty():
			# Kept (handed out at once) or not there (null), as build_stream
			# would have it.
			_tunes.append(MusicLibrary.stream(ids[i]))
			_settled.append(true)
		else:
			_tunes.append(null)
			_settled.append(false)
	_taken = 0
	_list = null
	_places = {}
	_opening = null
	_task = SkinWarmer.track(_window, WorkerThreadPool.add_task(_window.run, false, "Music window"))
	set_process(true)
	_advance()
	return true


func _process(_delta: float) -> void:
	if _window == null:
		set_process(false)
		return
	_advance()


## Keep what the worker decoded, lay it into its place, start the list once
## it can, and keep the deadline ([constant DEADLINE]).
func _advance() -> void:
	_take(_window.decoded())
	if _list == null:
		_try_start()
	elif not _places.is_empty() and _opening != null:
		if get_playback_position() >= due(_opening.get_length()):
			settle_window()
			return
	if _window != null and _taken >= _window.jobs.size():
		# Every tune in its place — or none would play, build_stream's null:
		# what played before goes on.
		_close_window()


## Keep the jobs the worker has been through, up to [param upto].
func _take(upto: int) -> void:
	while _taken < upto:
		var i := _taken
		_taken += 1
		var job: Dictionary = _window.jobs[i]
		if job.is_empty():
			continue
		var tune: AudioStream = null
		if _places.has(i):
			var place: AudioStreamWAV = _places[i]
			var decoded: Variant = job.get("stream")
			if decoded is AudioStreamWAV:
				_fill(place, decoded)
				# THE PLACE IS THE ONE KEPT: the decoded copy goes.
				job["stream"] = place
			tune = MusicLibrary.keep_tune(job)
			_places.erase(i)
		else:
			tune = MusicLibrary.keep_tune(job)
		_tunes[i] = tune
		_settled[i] = true


## Start the list when its first tune is there and every place still
## waiting can be filled in place (a WAV).
func _try_start() -> void:
	var first := -1
	for i in _tunes.size():
		if not _settled[i]:
			return              # an earlier tune may yet be the first
		if _tunes[i] != null:
			first = i
			break
	if first < 0:
		return
	var waiting := 0
	for i in _tunes.size():
		if _settled[i]:
			continue
		waiting += 1
		if String(_window.jobs[i].get("path", "")).get_extension().to_lower() != "wav":
			return              # a place that cannot be filled: wait for it
	if waiting == 0:
		_start(build_list(_tunes))
		return
	var list := AudioStreamPlaylist.new()
	list.set_stream_count(_tunes.size())
	for i in _tunes.size():
		if _settled[i]:
			# A tune that would not read is an empty place: skipped, as
			# build_stream leaves it out.
			list.set_list_stream(i, _tunes[i] if _tunes[i] != null else AudioStreamWAV.new())
		else:
			var place := AudioStreamWAV.new()
			_places[i] = place
			list.set_list_stream(i, place)
	_dress(list)
	_opening = _tunes[first]
	_start(list)


func _start(list: AudioStreamPlaylist) -> void:
	if list == null:
		return
	_list = list
	key = _window_key
	tracks = _window_ids
	stream = list
	play()


## Every tune of the window in its place NOW — the worker waited for. The
## deadline's step, and a test's.
func settle_window() -> void:
	if _window == null:
		return
	if _task != -1:
		SkinWarmer.claim(_task)
		_task = -1
	_take(_window.decoded())
	if _list == null:
		_try_start()
	_close_window()


## The window closed: its worker let go — waited for only when it has
## started, never behind a warm-up still queued ahead of it (the bug
## campaign of 0.50.66, h1-3: [method SkinWarmer.release]).
func _close_window() -> void:
	if _task != -1:
		SkinWarmer.release(_window, _task)
		_task = -1
	_window = null
	_places = {}
	_opening = null
	set_process(false)


## The window let go: the worker asked to stop and, when it has started,
## waited for (it ends after the tune in hand; [method _close_window]),
## nothing started.
func _drop_window() -> void:
	if _window == null:
		return
	_close_window()
	_window_key = ""


func _exit_tree() -> void:
	_drop_window()


## [param decoded]'s sound laid into [param place], an empty
## [AudioStreamWAV] already in the playing list.
static func _fill(place: AudioStreamWAV, decoded: AudioStreamWAV) -> void:
	place.format = decoded.format
	place.mix_rate = decoded.mix_rate
	place.stereo = decoded.stereo
	place.loop_mode = decoded.loop_mode
	place.loop_begin = decoded.loop_begin
	place.loop_end = decoded.loop_end
	place.data = decoded.data
# --- end the smoothness pass (M1): the window ---


# ------------------------------------------------------- the sequencing --

## The next window of the session's shuffle for [param context_key], and
## the cursor moved past it.
##
## In the two single-track modes the window is that one track and the
## cursor does not move: there is nothing to advance through.
static func next_tracks(context_key: String) -> Array[String]:
	var wanted := MusicLibrary.playlist_for(context_key)
	if wanted.size() <= 1:
		return wanted
	# A NEW SHUFFLE ONLY WHEN THE LIBRARY OR THE CHOICE CHANGED. Rerolling
	# per duel would make the cursor meaningless and the first track
	# always a fresh surprise, which is the behaviour this replaced.
	var signature := "%s|%d" % [MusicLibrary.choice(), wanted.size()]
	if _order_key != signature or _order.is_empty():
		_order = wanted
		_order_key = signature
		_cursor = 0
	var out: Array[String] = []
	var take: int = mini(MAX_TRACKS, _order.size())
	for i in take:
		out.append(_order[(_cursor + i) % _order.size()])
	_cursor = (_cursor + take) % _order.size()
	# THE CONTEXT'S OWN BED STILL OPENS, when the library has it: a duel
	# should still begin on `Dueltune`, whatever comes after it.
	if out.has(context_key) and out[0] != context_key:
		out.erase(context_key)
		out.push_front(context_key)
	return out


## Forget the session's shuffle. Tests call it; nothing else needs to.
static func reset_order() -> void:
	_order = []
	_order_key = ""
	_cursor = 0


## Where the session is in its shuffle. Tests read it.
static func cursor() -> int:
	return _cursor


## Build the stream that plays [param ids] end to end and then round
## again. Null when not one of them loads.
##
## ONE TRACK BECOMES TWO ENTRIES — see the class doc. It is the same
## [Resource] twice, so it costs nothing and it gives the sequencer a seam
## to crossfade instead of a hard wrap.
static func build_stream(ids: Array[String]) -> AudioStream:
	var loaded: Array = []
	for id in ids:
		if loaded.size() >= MAX_TRACKS:
			break
		var one := MusicLibrary.stream(id)
		if one != null:
			loaded.append(one)
	return build_list(loaded)


## The playlist of [param tunes] in their order, the ones that are null
## left out ([method build_stream]'s, and the window's once every tune is
## there — the same list either way). Null when none is left.
static func build_list(tunes: Array) -> AudioStreamPlaylist:
	var loaded: Array[AudioStream] = []
	for one in tunes:
		if loaded.size() >= MAX_TRACKS:
			break
		if one != null:
			loaded.append(one)
	if loaded.is_empty():
		return null
	if loaded.size() == 1:
		loaded.append(loaded[0])
	var list := AudioStreamPlaylist.new()
	list.set_stream_count(loaded.size())
	for i in loaded.size():
		list.set_list_stream(i, loaded[i])
	_dress(list)
	return list


static func _dress(list: AudioStreamPlaylist) -> void:
	# OUR SHUFFLE, NOT THE ENGINE'S: `MusicLibrary.playlist_for` already
	# decided the order and a test can pin it. Turning this on as well
	# would reshuffle behind that decision on the audio thread.
	list.shuffle = false
	list.loop = true
	list.fade_time = FADE
