extends Node
## THE SHELL'S BED — one tune for every room of the shell, held by an
## autoload so it keeps playing while the player walks between them.
##
## THE ROOMS: the title screen, Magic Battle, Options and Help. Until
## 2026-09-07 each screen that wanted the shell's tune built a
## [MusicPlayer] of its own and started the bed from the top when it
## opened, so a walk from the title screen into Options and back was the
## same tune starting over twice; Help and Options had no bed at all and
## the music simply stopped at their door. Three playtest notes in a row
## were about exactly this — *"Play a suitable soothing music at the main
## menu"* (2026-09-04), *"the magic battle GUI menu should have also the
## same music as main menu"* (2026-09-05), *"Help and options in main
## menu should have same music as main menu"* (2026-09-07) — and the
## answer to the third is the one that makes the other two hold
## everywhere: the shell is ONE place with one soundtrack, and its rooms
## share a player that outlives any of them.
##
## HOW A ROOM USES IT. A shell room calls [method play] from its `_ready`
## and nothing on the way out: [method MusicPlayer.play_one] keys on the
## track id, so a bed that is already up is left exactly where it is, and
## a room that follows another room is a room in which the music never
## stopped. The screens that own a bed of THEIR OWN — the Deck Builder,
## the Gauntlet, the duel — call [method stop] when they start theirs, so
## every door that leads out of the shell is a door the tune stops at, and
## the tune comes back from the top when the player returns to the shell.
## Magic Battle's `Go!` stops it as well, the moment every gate has
## passed, so the coin toss is heard against silence.
##
## WHY AN AUTOLOAD. Nothing under the current scene survives
## `change_scene_to_file`; this is the second thing in the project that
## has to (the first is `Lifecycle`, the process hooks), and an autoload
## is the honest way to say so in `project.godot` rather than parenting a
## stray node under the root from a screen. It carries no `class_name` —
## an autoload IS its name.
##
## THE GLOBAL `music_enabled` SWITCH IS THE WHOLE RULE, exactly as it was
## on each screen: the Deck Builder's screen-scoped `deck_builder_music`
## is that screen's and does not reach the shell. The buses are dressed
## before the first note ([method GameAudio.apply_settings]), so a player
## who turned the music down last session does not get one loud second
## of it first. Silent for a player who has not imported the original's
## `Sound/` folder — [MusicPlayer] treats a missing id as silence — and
## silent headless: the suite and the Deck Lab never start a voice.
##
## THE BED ITSELF, and how it was chosen without anybody hearing it:
##
## **WHAT THE 1997 SHELL PLAYED: NOTHING.** This was asked as a provenance
## question first, and the answer is that the original's shell screen has
## no music bed at all. The shell is `Magic.exe`'s own window class
## (`wndproc_MagicShellClass`, `Magic-trace.c:4124`, entry `4CC770`); it
## loads its art from `\ShellArt` (`%s\WINBK_ShellScreen16.bmp`, the five
## `%s\WINBK_ShellSphereAnimation16-%d.bmp` frames) and its pages from
## `@SHELLSCREEN_DUEL` / `_TOOLS` / `_METAGAME` / `_HELP` / `_RECORDS`.
## Its ENTIRE audio vocabulary is the 68-entry one-shot table at
## `shandalar-src/src/functions/windows.c:1181-1266`, and the only shell
## entries in it are seven cues — `WAV_SHELL_SHANDALAR`, `_TOOLTIME`,
## `_HELPME`, `_HALLOFRECORDS`, `_DUELMENOW` (ids 60-64) and
## `_WINDUEL`/`_LOSEDUEL` (44-45), `defs.h:2232-2252`. Those five map
## one-to-one onto the five shell pages and measure 2.8-6.1 s each
## (`Duelsounds/Shell_*.wav`, 22 050 Hz stereo): they are page stingers,
## not a bed. Every LOOPING bed literal in the original —
## `x:sound\dueltune.wav`, `x:sound\locmus0..19.wav`,
## `x:sound\tmplmus1.wav`, `x:sound\[bgruw]castle.wav` — lives in
## `Shandalar.exe`, the ADVENTURE, and none of them in the shell's exe,
## which carries no `music` string and no `sound\` path at all. A full
## audio inventory of the owner's install confirms it: there is no title
## or menu file to source. So the title screen's music is `[QoL]`, and
## the choice below is OURS.
##
## **HOW THE BED WAS CHOSEN, WITHOUT ANYBODY HEARING IT.** Nobody on this
## side of the work can listen to audio, so the pick is made on what the
## bytes can be measured for. All 27 beds were read for duration, peak,
## RMS, crest, the spread between the 10th and 90th percentile of a 20 ms
## loudness envelope, the rate of frames whose energy jumps 6 dB
## (transients per second), zero-crossing rate and a high-frequency
## energy ratio. `music_location_15` (LocMus15) came out as the calmest
## bed the Deck Builder does not already own:
##
##   * **0.06 transients/s** over 36 s — joint lowest of the twenty
##     location beds, i.e. essentially no percussion or stabs.
##   * **816 zero-crossings/s and -19.2 dB of high-frequency energy** —
##     the second-darkest bed in the library; a sustained thing, not a
##     bright or busy one.
##   * **8.3 dB of loudness spread**, no frame below -50 dBFS: it never
##     swells and it never drops out.
##   * **36.0 s**, the second-longest bed there is, so the loop wraps
##     less often than anything else would.
##
## The two the prompt guessed at do NOT measure calmest, which is why
## this list is not headed by either. `music_temple` (Tmplmus1) is the
## SHORTEST bed at 24.9 s, spends only 43% of its length within 3 dB of
## its own median and has an 18.2 dB crest — a struck, bell-like shape.
## `music_castle_blue` is 30.6% SILENCE, an ambience file with holes in
## it, which would loop as a tune that keeps stopping.
##
## **THIS IS A JUDGEMENT MADE WITHOUT HEARING THE MUSIC.** If the owner
## disagrees, the fix is ONE LINE: put another id first in this list.
## The runners-up are here in measured order behind it —
## `music_location_8` (equally transient-free and steadier still, but
## brighter and shorter) and `music_location_2` (a little quieter),
## with `music_temple` last as the calmest of the non-location beds.
##
## **NOT THE DECK BUILDER'S BED, deliberately.** That screen loops
## [method MusicLibrary.single_for] over `deck_builder_beds()` =
## LocMus1..19, so it takes `music_location_1` — measurably the steadiest
## bed of all, and already spoken for. Sharing it would mean the same
## track restarting from zero every time the player crossed between the
## two screens, which reads as a stutter rather than as continuity.
const MENU_BEDS: Array[String] = [
	"music_location_15",
	"music_location_8",
	"music_location_2",
	"music_temple",
]

## The shell's one voice on the Music bus. Made on the first [method play]
## rather than in `_ready`, so a headless run that never opens the shell
## never has one.
var _player: MusicPlayer


## Start the shell's bed, or leave it playing if it already is — the one
## call every shell room makes from its `_ready`. Re-callable from
## anywhere the music settings change (the Options screen's Music switch
## and its track picker): a switch turned off stops the tune and drops
## the PCM, a switch turned back on starts it, a new choice of track
## replaces the old one, and the same choice already playing is left
## alone.
func play() -> void:
	GameAudio.apply_settings()
	if _player == null:
		_player = MusicPlayer.new()
		add_child(_player)
	if not Settings.music_enabled():
		_player.stop_music()
		return
	_player.play_one(MusicLibrary.single_for(MENU_BEDS))


## Stop the bed and let go of the audio behind it — what every screen
## with a bed of its own does before starting that bed, and what `Go!`
## does on the way to the table.
func stop() -> void:
	if _player != null:
		_player.stop_music()


## The track id the shell is playing, empty when it is not.
func bed() -> String:
	return _player.key if _player != null else ""


## The player itself, for the tests to read (`tracks`, `stream`, `silent`).
func player() -> MusicPlayer:
	return _player
