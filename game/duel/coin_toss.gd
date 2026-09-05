class_name CoinToss
extends Control
## THE DUEL'S OPENING MOMENT — the toss that decides who chooses play or
## draw, on the `Winbk_StartDuel` backdrop, with `Toss.wav`.
##
## Lifted out of `duel_screen.gd` on 2026-09-02 (the fiftieth pass) for the
## same reason the sound layer left it: how the toss is PRESENTED is a
## thing with rules of its own — now three of them — and it deserves to be
## tested without a duel around it. The duel screen keeps the one line that
## matters to it (the toss blocks the AI scheduler until it is over).
##
## ─────────────────────────────────────────────────────────────────────
## WHAT THE 1997 GAME ACTUALLY DID
## ─────────────────────────────────────────────────────────────────────
##
## **The 1997 coin toss was not an animation. It was a movie**, which is
## why no coin art exists anywhere to import. The decompilation shows the
## toss opening its own dialog and embedding an AVI in it through Win32's
## MCIWnd control — `MCIWndCreateA(...)` on `COINTOSS_Heads.AVI` /
## `COINTOSS_Tails.AVI`, with a 10ms poll timer and a 15-second timeout
## (`DUEL.EXE`, the dialog proc at entry `004492ad`).
##
## That finding is corroborated from a Tier-1 artefact, and the
## corroboration is stronger than the original claim. `Program/Magic.exe`'s
## own string table holds, in three consecutive literals:
##
##     DIALOG_COINFLIP
##     %s\COINTOSS_Tails.AVI
##     %s\COINTOSS_Heads.AVI
##
## — the dialog tag and its two movies, adjacent in the literal pool. And
## `magvid.dll`, the original's video DLL, imports `AVIFileOpenA`,
## `AVIStreamRead` and `AVIStreamReadFormat` from `AVIFIL32.dll` and
## carries `LoadAVI` / `PlayAVI` / `StopAVI` / `UnloadAVI` beside the
## hard-coded fourcc literals `iv41` / `IV41` / `iv41j`. **The 1997 video
## codec is Indeo Video 4.1**, and every one of the 69 AVIs that survives
## in `../shandalar-src` is `IV41`, 24-bit, 15fps. See
## `tools/import_original.py`'s VIDEOS block for what that costs us.
##
## **`@DIALOG_COINFLIP` is two strings** (`Uistrings.txt:593-596`, and
## `Program/UIStrings.txt` reads identically):
##
##     Coin flip results: Heads
##     Coin flip results: Tails
##
## one per movie — the caption names the face that came up. [constant
## RESULT_LINES] is those two strings verbatim.
##
## **`Show coin flip animations` did NOT mean "show nothing".** The
## original's entry point takes a third parameter for exactly this:
##
##     int coin_flip(int player, const char *dialog_title,
##                   int show_dialog_if_animation_is_off);
##         // Last parameter should always be 1 except during game startup
##
## (`shandalar-src/src/manalink.h:266`). With the switch off the DIALOG
## still appeared; only the movie was skipped. So the instant mode
## ([constant DuelOptions.COIN_INSTANT]) is not a modern invention in
## structure — it is what 1997 did with the switch off. What is ours is
## making the dialog carry an ICON that says which seat won rather than
## only a line of text.
##
## ─────────────────────────────────────────────────────────────────────
## THE THREE MODES — `[QoL]`, one stored value
## ─────────────────────────────────────────────────────────────────────
##
## [constant DuelOptions.COIN_VIDEO] plays the original's own footage;
## [constant DuelOptions.COIN_RECREATION] is our tween; [constant
## DuelOptions.COIN_INSTANT] is the dialog with no motion in it. The 1997
## switch is the two-position VIEW of that three-position value —
## [method DuelOptions.toggle] on `ShowCoinFlips` answers "not instant" —
## so the Duel Options panel keeps the original's checkbox and the `[QoL]`
## Options screen offers the whole list. One key, two views, no parallel
## copy; the same contract [DuelOptions] states for the territory
## background.
##
## The video degrades to the recreation when the footage is not imported
## ([method effective_style]), which is the common case: the two AVIs
## exist only in a genuine 1997 install.
##
## ─────────────────────────────────────────────────────────────────────
## DETERMINISM
## ─────────────────────────────────────────────────────────────────────
##
## **Nothing in this file is random, and nothing in it decides anything.**
## The winner is rolled once, on `game.rng`, in `DuelScreen._new_game`;
## every function here takes it as an argument and only reports it.
## [method toss_start_face] exists precisely so the recreation LANDS on the
## seat the engine already chose, and [method result_face] maps that seat
## onto a coin face by a fixed rule rather than a roll. A headless run
## returns from [method run] before it builds anything, so the suite and
## the Deck Lab gain no wait they did not have.

# ---------------------------------------------------------------- strings --

## `@DIALOG_STARTCOINFLIP` — one entry, the window's title
## (`s30/assets/text/Uistrings.txt:483-485`; `Program/UIStrings.txt` is
## line-for-line identical here).
const TITLE := "Start of Duel"

## `@DIALOG_COINFLIP` — two entries, one per movie
## (`s30/assets/text/Uistrings.txt:593-596`). Index 0 is Heads.
const RESULT_LINES: Array[String] = [
	"Coin flip results: Heads",
	"Coin flip results: Tails",
]

## WHICH FACE BELONGS TO WHICH SEAT IS **OURS**, and it is a convention
## rather than a finding. The original's own entry point is
## `coin_flip(int player, ...)` — the coin is flipped FOR a seat — and
## `@DIALOG_PLAYORDRAW` answers the viewer in the second person ("You won
## the coin toss."), so the reading below is the natural one: the coin is
## called for the seat you are sitting in, and Heads is that seat winning.
## The decompilation is not checked out on this machine, so the mapping
## could not be read back from `004492ad`; if it ever is and it disagrees,
## this one constant is the whole of the change.
const HEADS := 0
const TAILS := 1

# ------------------------------------------------------------- geometry --

## The dialog, the coin, and the recreation's timing. These moved here
## from `DuelScreen` unchanged — `TOSS_PANEL`, `TOSS_COIN`, `TOSS_TURN`
## and `TOSS_HALF_TURNS` were their names there.
const PANEL := Vector2(452, 296)
const COIN := 104.0
const TURN := 0.17          ## one half-turn of the coin
const HALF_TURNS := 9

## THE PANEL'S THREE BANDS, because three different things go in the
## middle of it and only one of them is the size of a coin.
##
##   0 .. CONTENT_TOP     the title band (`Start of Duel`)
##   CONTENT_TOP .. -FOOT the coin, the film, or the instant badge
##   the last FOOT px     `@DIALOG_COINFLIP`'s caption over
##                        `@DIALOG_PLAYORDRAW`'s verdict
##
## The foot is measured UP FROM THE BOTTOM so the same two labels sit
## correctly on a panel of any height — which matters, because the movie
## sizes the panel to itself. Both were laid out by eye against the
## screenshot: at the first attempt the caption ran under the coin and
## read `Coin ... Tails`.
const CONTENT_TOP := 56.0
const FOOT := 128.0
## The instant badge is a chevron, a coin and a name in a column, so it
## needs more room than a bare coin does.
const BADGE_HEIGHT := 190.0

## How long the finished coin holds before the panel fades. The
## recreation has already spent `TURN * HALF_TURNS` seconds turning, so it
## needs less; the instant mode has spent none and needs enough for a
## player to actually read the badge — the owner's own requirement for
## this mode, and the reason it is not simply zero.
const VERDICT_HOLD := 1.5
const INSTANT_HOLD := 1.9
const FADE := 0.25

## The struck disc, and the ink the panel letters with.
const COIN_FACE := Color8(206, 178, 104)
const COIN_RIM := Color8(96, 74, 32)
## A mirror match would strike two identical faces and the turn would not
## read; the reverse is struck in silver instead.
const COIN_REVERSE_TINT := Color(0.80, 0.85, 0.92)

## One face of the coin bears a seat's deck-colour MANA SYMBOL, taken from
## the original `Manasymbols.pic` sheet — the only original asset in the
## set that already IS a disc. It reads at a glance: the colour the coin
## lands on is the colour that leads.
const FACE_SYMBOL := {
	"white": "W", "blue": "U", "black": "B", "red": "R", "green": "G",
}

# ------------------------------------------------------------ the video --

## Skin keys for the two transcoded movies, by face. The importer writes
## `<key>.png` (a sprite sheet of every frame) beside `<key>.json` (its
## grid, frame count and frame rate) — see `tools/import_original.py`.
## Godot 4 has no AVI decoder at all, so the AVI is never opened at
## runtime; the conversion happens once, at import. (The 1997 coin is
## CRAM — Microsoft Video 1 — not the Indeo the rest of the game's movies
## use; corrected 2026-09-03 against the owner's own CD.)
const VIDEO_KEYS := {HEADS: "coin_toss_heads", TAILS: "coin_toss_tails"}

## Said out loud when the player picks the video and there is none. The
## honest sentence: the footage ships with the 1997 game and nowhere else.
const VIDEO_MISSING := "The 1997 coin-toss movies are not imported. " \
	+ "Cointoss_Heads.avi and Cointoss_Tails.avi ship with the original " \
	+ "game and nowhere else; point tools/import_original.py at your own " \
	+ "copy and it transcodes them (they are Microsoft Video 1, which " \
	+ "ffmpeg and GStreamer both read). Until they are imported the toss " \
	+ "uses our own animation."

## THE ORIGINAL'S OWN TIMEOUT, and ours for the same reason. `DUEL.EXE`'s
## toss dialog polls the MCIWnd every 10ms and gives up after **fifteen
## seconds** (the dialog proc at entry `004492ad`), so a movie that never
## finished could not hold the duel. Ours cannot either: a sidecar
## claiming an absurd frame count is capped here rather than trusted.
const VIDEO_TIMEOUT := 15.0

## The largest a frame is allowed to be drawn. The original's movies play
## inside a dialog; a 1997 AVI is small (the surviving ones run 144x300 to
## 576x340) and blowing one up past its own pixels only shows the codec's
## blocking. Fitted, never stretched.
const VIDEO_MAX := Vector2(360, 270)


# ------------------------------------------------------- style selection --

## The style the toss will ACTUALLY use, given what is on disk. The video
## falls back to the recreation — never to instant: a player who asked to
## see the toss acted out should still see it acted out.
static func effective_style(style: String) -> String:
	if style == DuelOptions.COIN_VIDEO and not video_available():
		return DuelOptions.COIN_RECREATION
	return style


## The player's choice, resolved against what is on disk.
static func current_style() -> String:
	return effective_style(DuelOptions.coin_flip_style())


## Both movies present, decoded and described? One without the other is
## useless — the toss can come up either way.
static func video_available() -> bool:
	return not video_meta(HEADS).is_empty() and not video_meta(TAILS).is_empty()


## The sheet description for one face, or `{}` when it is absent or
## unusable. Empty is the answer for a missing skin, a missing sidecar, a
## sidecar that does not parse, and a sheet with no frames in it — every
## caller wants the same "there is no video" from all four.
static func video_meta(face: int) -> Dictionary:
	var key: String = VIDEO_KEYS.get(face, "")
	if key == "" or GameSkin.texture(key) == null:
		return {}
	var meta := GameSkin.metadata(key)
	if int(meta.get("frames", 0)) <= 0 or int(meta.get("frame_width", 0)) <= 0 \
			or int(meta.get("frame_height", 0)) <= 0:
		return {}
	return meta


## Which frame of the sheet is showing [param elapsed] seconds in. PURE,
## so the playback clock is testable without a screen: past the end it
## holds the last frame rather than wrapping — a coin toss plays once.
static func video_frame_at(meta: Dictionary, elapsed: float) -> int:
	var frames := int(meta.get("frames", 0))
	if frames <= 0:
		return 0
	var fps := float(meta.get("fps", 15.0))
	if fps <= 0.0:
		return frames - 1
	return clampi(int(floor(elapsed * fps)), 0, frames - 1)


## Where frame [param index] sits on the sheet. Row-major, which is the
## order the importer tiles them in.
static func video_frame_rect(meta: Dictionary, index: int) -> Rect2i:
	var cols := maxi(1, int(meta.get("cols", 1)))
	var w := int(meta.get("frame_width", 0))
	var h := int(meta.get("frame_height", 0))
	return Rect2i((index % cols) * w, (index / cols) * h, w, h)


## How big one frame is drawn: fitted inside [constant VIDEO_MAX] at its
## own aspect and NEVER enlarged past its own pixels — a 1997 movie
## upscaled is just bigger codec blocks.
static func video_draw_size(meta: Dictionary) -> Vector2:
	var frame := Vector2(float(int(meta.get("frame_width", 1))),
		float(int(meta.get("frame_height", 1))))
	if frame.x <= 0.0 or frame.y <= 0.0:
		return VIDEO_MAX
	var fit := minf(1.0, minf(VIDEO_MAX.x / frame.x, VIDEO_MAX.y / frame.y))
	return (frame * fit).floor()


## The window each mode needs. The coin and the badge take a fixed panel;
## the movie takes one sized to itself, so a tall 1997 AVI is not cropped
## by a window that was measured for a coin.
static func panel_size_for(style: String, meta: Dictionary) -> Vector2:
	if style == DuelOptions.COIN_VIDEO:
		var film := video_draw_size(meta)
		return Vector2(maxf(PANEL.x, film.x + 48.0),
			CONTENT_TOP + film.y + FOOT)
	if style == DuelOptions.COIN_INSTANT:
		return Vector2(PANEL.x, CONTENT_TOP + BADGE_HEIGHT + FOOT)
	return PANEL


## How long the whole movie runs, in seconds.
static func video_length(meta: Dictionary) -> float:
	var fps := float(meta.get("fps", 15.0))
	if fps <= 0.0:
		return 0.0
	return float(int(meta.get("frames", 0))) / fps


# ---------------------------------------------------------- the two faces --

## Which face the coin starts on so that [constant HALF_TURNS]
## alternations leave [param winner]'s face up. The coin must LAND on the
## seat the engine already chose — the animation reports the result, it
## never decides it.
static func toss_start_face(winner: int) -> int:
	return posmod(winner - HALF_TURNS, 2)


## Heads or Tails for a given outcome — see the note on [constant HEADS].
## Pure, and the same predicate that aims the seat pointer, so the words
## and the picture can never disagree.
static func result_face(winner: int, viewer_seat: int) -> int:
	return HEADS if winner == viewer_seat else TAILS


## `@DIALOG_COINFLIP`'s own caption for an outcome.
static func result_line(winner: int, viewer_seat: int) -> String:
	return RESULT_LINES[result_face(winner, viewer_seat)]


## `@DIALOG_PLAYORDRAW`'s verdict, in the voice the seat deserves — the
## original's own second person for the seat the viewer is playing.
##
## The toss decides who CHOOSES, not who leads (`Duel.hlp`, **Play or Draw
## Rule**); the choice itself is [OpeningHand]'s first question, so the
## coin only reports the win.
static func verdict_line(winner_is_you: bool, winner_name: String) -> String:
	if winner_is_you:
		return OpeningHand.PLAY_OR_DRAW["you_won"]
	return OpeningHand.PLAY_OR_DRAW["won"] % winner_name


# ---------------------------------------------------------------- the run --

## Present the toss and return when the panel is gone. [param winner] is
## the seat the ENGINE chose; nothing here may change it.
##
## Headless returns immediately and builds nothing — the suite and the
## Deck Lab must gain no wait.
func run(config: DuelConfig, winner: int, winner_is_you: bool,
		viewer_seat: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# COVER THE TABLE, and cover it NOW. `set_anchors_preset` alone keeps
	# the rect the node already has — for a freshly-`new()`ed Control that
	# is (0,0), and it stays (0,0) until its parent happens to re-lay-out,
	# which the duel screen, already sized when `_new_game` reaches the
	# toss, never does. The panel below anchors to this node's CENTRE, so a
	# zero-size overlay put the whole toss dialog in the top-left corner
	# half off screen — caught by the screenshot pass of 2026-09-02,
	# invisible to every test. Setting anchors AND offsets resizes the node
	# in the same call, because it is already in the tree; an explicit
	# `size =` on top of that is what Godot's "non-equal opposite anchors"
	# warning is about, and it printed once per duel until it was dropped.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The overlay covers the table but must not swallow its clicks — the
	# panel below is decoration, not a dialog with answers in it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := current_style()
	var face := result_face(winner, viewer_seat)
	var panel := _build_panel(panel_size_for(style, video_meta(face)))
	add_child(panel)

	var caption := _label(result_line(winner, viewer_seat), 20)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 20
	caption.offset_right = -20
	caption.offset_top = -116
	caption.offset_bottom = -84
	# The caption names the face that came up, so it only makes sense once
	# the coin has stopped. Instant has no "once" — its coin is already
	# down when the panel opens.
	caption.visible = style == DuelOptions.COIN_INSTANT
	panel.add_child(caption)

	var verdict := _label("", 20)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	verdict.offset_left = 20
	verdict.offset_right = -20
	verdict.offset_top = -80
	verdict.offset_bottom = -20
	panel.add_child(verdict)

	var hold := VERDICT_HOLD
	if style == DuelOptions.COIN_VIDEO:
		await _play_video(panel, face)
	elif style == DuelOptions.COIN_INSTANT:
		panel.add_child(result_badge(config, winner, viewer_seat))
		hold = INSTANT_HOLD
	else:
		await _spin_coin(panel, config, winner)
	if not is_instance_valid(panel):
		return
	caption.visible = true
	verdict.text = verdict_line(winner_is_you, config.player_names[winner])

	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(panel):
		return
	var fade := panel.create_tween()
	fade.tween_property(panel, "modulate:a", 0.0, FADE)
	await fade.finished
	if is_instance_valid(panel):
		panel.queue_free()


# ------------------------------------------------------ mode 2: the tween --

## OUR RECONSTRUCTION — the coin rises, turns end over end, and falls back
## onto the winner's colour. It is a reconstruction and not a port: there
## is no coin art in the 1997 files because the 1997 coin was a movie (see
## the class doc), so this is built out of an original asset that IS a
## disc, the deck-colour mana symbol.
func _spin_coin(panel: Control, config: DuelConfig, winner: int) -> void:
	var coin := Control.new()
	coin.size = Vector2(COIN, COIN)
	# Centred in the content band, so the caption below it is never
	# overrun however tall the panel is.
	coin.position = Vector2((panel.size.x - COIN) * 0.5,
		CONTENT_TOP + (panel.size.y - CONTENT_TOP - FOOT - COIN) * 0.5)
	coin.pivot_offset = coin.size / 2.0
	var faces: Array[Control] = []
	for seat in 2:
		var face := build_face(String(config.panel_colors[seat]))
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.visible = false
		coin.add_child(face)
		faces.append(face)
	if config.panel_colors[0] == config.panel_colors[1]:
		faces[1].modulate = COIN_REVERSE_TINT
	panel.add_child(coin)

	var shown := toss_start_face(winner)
	faces[shown].visible = true

	# The toss: the coin rises, turning end over end, and falls back.
	var arc := coin.create_tween()
	arc.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(coin, "position:y", coin.position.y - 58.0,
		TURN * HALF_TURNS * 0.5)
	arc.set_ease(Tween.EASE_IN)
	arc.tween_property(coin, "position:y", coin.position.y,
		TURN * HALF_TURNS * 0.5)
	for half_turn in HALF_TURNS:
		# Squash to an edge-on sliver, swap the face, open out again.
		var spin := coin.create_tween()
		spin.set_trans(Tween.TRANS_SINE)
		spin.tween_property(coin, "scale:y", 0.06, TURN * 0.5)
		await spin.finished
		if not is_instance_valid(panel):
			return
		faces[shown].visible = false
		shown = 1 - shown
		faces[shown].visible = true
		var open := coin.create_tween()
		open.set_trans(Tween.TRANS_SINE)
		open.tween_property(coin, "scale:y", 1.0, TURN * 0.5)
		await open.finished
		if not is_instance_valid(panel):
			return

	# It settles face-up, showing the leader's colour.
	var settle := coin.create_tween()
	settle.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	settle.tween_property(coin, "scale", Vector2(1.14, 1.14), 0.24)


# ------------------------------------------------------ mode 1: the movie --

## THE ORIGINAL'S OWN FOOTAGE, "played in the middle of the screen" — the
## place `MCIWndCreateA` put it, inside the toss dialog.
##
## The AVI itself is never opened here: it is Indeo Video 4.1 and neither
## Godot nor GDScript can decode it. `tools/import_original.py` transcodes
## it once, into a sprite sheet, which is the same thing every other sheet
## in this project is ([ManaIcons], [MiniCard], [FilterBar], [SetBadges]).
## Playback is therefore a region walk over one texture, driven by the
## sheet's own recorded frame rate.
func _play_video(panel: Control, face: int) -> void:
	var meta := video_meta(face)
	if meta.is_empty():
		return          # cannot happen through current_style(); cheap guard
	var draw_size := video_draw_size(meta)
	var atlas := AtlasTexture.new()
	atlas.atlas = GameSkin.texture(VIDEO_KEYS[face])
	atlas.region = Rect2(video_frame_rect(meta, 0))
	var film := TextureRect.new()
	film.texture = atlas
	film.size = draw_size
	film.position = Vector2((panel.size.x - draw_size.x) * 0.5, CONTENT_TOP)
	film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	film.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(film)

	# Walk the sheet on the movie's own clock. `process_frame` rather than
	# a Timer per frame: one wait per rendered frame, and the index comes
	# from elapsed TIME, so a slow frame drops a frame instead of slowing
	# the toss down.
	var length := minf(video_length(meta), VIDEO_TIMEOUT)
	var started := Time.get_ticks_msec()
	var last := -1
	while true:
		var elapsed := (Time.get_ticks_msec() - started) / 1000.0
		if elapsed >= length:
			break
		var index := video_frame_at(meta, elapsed)
		if index != last:
			atlas.region = Rect2(video_frame_rect(meta, index))
			last = index
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_instance_valid(panel):
			return
	atlas.region = Rect2(video_frame_rect(meta, int(meta.get("frames", 1)) - 1))


# ----------------------------------------------------- mode 3: the badge --

## THE INSTANT RESULT, and the reason this mode is not just a line of
## text. The owner's requirement was that it *relay the information* —
## which seat won — at a glance, so the badge says it three ways at once:
##
##  - the COIN, already landed, wearing the winning seat's deck colour
##    (the same struck disc the recreation lands on);
##  - a CHEVRON on the winner's side of it, pointing at that seat's half
##    of the table. The board is not mirrored and the viewer always sits
##    at the bottom (see [enum DuelScreen.Row]), so down is yours and up
##    is theirs — the pointer is aimed at the actual territory, not at an
##    arbitrary icon;
##  - the seat's NAME under it, because a mirror match gives both seats
##    the same colour and the chevron is then the only thing left that
##    distinguishes them.
##
## Static so it can be built and read in a test without a duel around it.
static func result_badge(config: DuelConfig, winner: int,
		viewer_seat: int) -> Control:
	var badge := VBoxContainer.new()
	badge.name = "ResultBadge"
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_theme_constant_override("separation", 10)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	badge.offset_top = CONTENT_TOP
	badge.offset_bottom = CONTENT_TOP + BADGE_HEIGHT

	var near := winner == viewer_seat
	if not near:
		badge.add_child(Chevron.pointing(false))

	var coin := build_face(String(config.panel_colors[winner]))
	coin.custom_minimum_size = Vector2(COIN, COIN)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_child(coin)

	if near:
		badge.add_child(Chevron.pointing(true))

	var whose := _label("Your seat" if near else config.player_names[winner], 18)
	whose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(whose)
	return badge


## THE POINTER, DRAWN AND NOT LETTERED.
##
## It was a Label carrying `▲` / `▼` for one screenshot, and the
## screenshot is why it is not one now: [method OriginalDialog.ink_label]
## dresses its text in the 1997 body face (MPlantin), **which has no
## triangle glyphs**, so the badge came out as a coin with a name under it
## and nothing pointing anywhere. The same trap as the graveyard shelf's
## `◀ ▶`, which get away with it only because they are drawn in the
## fallback font.
##
## Painted in the panel's own two voices — the pale outline that lifts ink
## off the sandstone speckle, then the ink itself — so it belongs to the
## dialog rather than sitting on top of it.
class Chevron extends Control:
	## True points DOWN (the near seat, the viewer's own half of the
	## table); false points UP (the far seat).
	var down := true

	## One pointer, sized and centred for a column.
	static func pointing(downward: bool) -> Chevron:
		var arrow := Chevron.new()
		arrow.down = downward
		arrow.custom_minimum_size = Vector2(60, 34)
		arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return arrow

	func _draw() -> void:
		draw_colored_polygon(_triangle(0.0), Color8(226, 219, 190))
		draw_colored_polygon(_triangle(2.5), Color8(46, 32, 12))

	## The triangle, shrunk toward its own centre by [param inset] — which
	## is how the outline is made: the same shape drawn twice.
	func _triangle(inset: float) -> PackedVector2Array:
		var w: float = size.x
		var h: float = size.y
		var mid := Vector2(w * 0.5, h * 0.5)
		var points := PackedVector2Array([Vector2(0, 0), Vector2(w, 0),
			Vector2(w * 0.5, h)] if down
			else [Vector2(w * 0.5, 0), Vector2(w, h), Vector2(0, h)])
		if inset <= 0.0:
			return points
		var shrunk := PackedVector2Array()
		for point in points:
			shrunk.append(point + (mid - point).normalized() * inset)
		return shrunk


# --------------------------------------------------------------- chrome --

## The toss's window. The original's coin flip is a DIALOG, so it wears
## the same chrome as every other popup — [method OriginalDialog.frame] on
## the beveled sandstone `Winbk_Options`.
func _build_panel(panel_size: Vector2) -> Control:
	var panel := Control.new()
	panel.name = "TossPanel"
	panel.size = panel_size
	# KEEP_SIZE writes real offsets around the centre anchor; the bare
	# preset would leave them at 0 and hang the panel off screen-centre.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER,
		Control.PRESET_MODE_KEEP_SIZE)
	var bg := OriginalDialog.frame("panel_stone")
	if bg != null:
		panel.add_child(bg)
	else:
		var flat := Panel.new()
		flat.add_theme_stylebox_override("panel",
			OriginalDialog.panel_style("panel_stone", 0.0))
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(flat)

	var title := _label(TITLE, 20)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 14
	title.offset_bottom = 44
	panel.add_child(title)
	return panel


## Dark ink on the sandstone — [method OriginalDialog.ink_label] is the
## one place that voice is defined (the pale outline lifts it off the
## speckle). Centred, because everything on this panel is.
static func _label(text: String, size: int) -> Label:
	var lab := OriginalDialog.ink_label(text, size)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lab


## One face of the coin: a struck disc bearing a seat's deck-colour mana
## symbol, taken from the original `Manasymbols.pic` sheet. Falls back to
## the colour's initial when the skin is not imported.
static func build_face(color_key: String) -> Control:
	var face := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = COIN_FACE
	disc.border_color = COIN_RIM
	disc.set_border_width_all(4)
	disc.set_corner_radius_all(int(COIN / 2.0))
	disc.shadow_color = Color(0, 0, 0, 0.35)
	disc.shadow_size = 6
	face.add_theme_stylebox_override("panel", disc)

	var sym: String = FACE_SYMBOL.get(color_key, "W")
	var tex := ManaIcons.symbol(sym)
	var inset := COIN * 0.17
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
			Control.PRESET_MODE_MINSIZE, int(inset))
		face.add_child(icon)
	else:
		var text := Label.new()
		text.text = sym
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", int(COIN * 0.5))
		text.add_theme_color_override("font_color", Color8(48, 36, 14))
		text.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.add_child(text)
	return face
