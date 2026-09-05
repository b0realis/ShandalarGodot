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
	var ids := next_tracks(new_key)
	if ids.is_empty():
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
	key = ""
	tracks = []
	stop()
	# Drop the streams with the playback. A stopped duel screen holding
	# 22 MB of PCM until it is collected is 22 MB nobody can hear.
	stream = null


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
	var loaded: Array[AudioStream] = []
	for id in ids:
		if loaded.size() >= MAX_TRACKS:
			break
		var one := MusicLibrary.stream(id)
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
	# OUR SHUFFLE, NOT THE ENGINE'S: `MusicLibrary.playlist_for` already
	# decided the order and a test can pin it. Turning this on as well
	# would reshuffle behind that decision on the audio thread.
	list.shuffle = false
	list.loop = true
	list.fade_time = FADE
	return list
