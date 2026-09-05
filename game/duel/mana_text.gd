class_name ManaText
extends Control
## Wrapped rules text with the ORIGINAL 1997 mana symbols drawn INLINE
## wherever the oracle text writes `{R}`, `{T}`, `{2}`, `{X}`… — a drop-in
## for the [Label] the enlarged card's rules box used to be.
##
## # THE 1997 GAME DID THIS, AND THE PROOF IS ITS OWN CARD DATABASE
##
## **Tier 1.** `../shandalar-xp/MagicTG/Master.csv` — the shipped card-text
## database, dated **1997-08-14** in the owner's own install — is
## `ID,Card Name,Type Description,Artist Name,Rule Text,Quote`, and its Rule
## Text column carries the symbols INSIDE the sentence, escaped with a
## PIPE:
##
##     0230,Sol Ring,Artifact,Mark Tedin,|T: to add |2 to pool - Interrupt,
##     0015,Birds of Paradise,...,"Flying, |T: Add one mana of any color..."
##     0057,Dark Ritual,...,Add |B|B|B to your mana pool.
##
## (`7c 54` = `|T`, `7c 32` = `|2` on the wire.) **338 of the 1 251 rows
## carry a tag**, and the commonest by a wide margin is `|T` — 204 of them —
## which is decisive on its own: **tap is never part of a mana cost**, so
## those 204 symbols can only ever have been drawn in the rules-text body.
## The vocabulary is `|X`, `|0`..`|9`, `|W|U|B|R|G`, `|T` — the nineteen-cell
## sheet [ManaIcons] decodes, and nothing else. There is no `{R}` brace
## convention anywhere in the 1997 data; braces are OURS, from the Scryfall
## snapshot in `cards/data/`, and this widget is what puts them back.
##
## Three more Tier-1 witnesses agree:
##
## * **The executable imports the function by name.** `Magic.exe` and
##   `Shandalar.exe` import `DrawManaText` and `CalcDrawManaText` from
##   `DrawCardLib.dll`, and reference `%s\ManaSymbols.pic` and the
##   `MagicSymbols` face `\Magis___.TTF`. The 1997 DLL had no "draw plain
##   rules text" entry point at all — resolving symbols was THE text call.
## * **`Magis___.ttf`** (1996-07-30, *"MagicSymbols … © 1994 by Wizards of
##   the Coast … Originally based on Plantin"*) maps exactly `W U B R G`,
##   `T`, `X` and `0`-`9`, in two sizes.
## * **`Duel.hlp`** (1997-11-11) does it in its own prose, in the
##   **Activation Cost** topic: *"For example, Strip Mine has the effect*
##   *"⟦T⟧, Sacrifice Strip Mine: Destroy target land.""* and *"Each time*
##   *you pay ⟦B⟧, you cause 1 damage."* — single characters switched into
##   the MagicSymbols font (which the help file's own font table declares)
##   in the middle of a sentence of card text. The help file shows the
##   player the convention because the game used it.
##
## So `game/help/help_pages.gd`'s claim — that these symbols are met *"on
## the enlarged card in the Showcase"* — is **verified**, and inline
## symbols here are fidelity, not decoration.
##
## # THE GEOMETRY IS THE 1997 DLL'S
##
## **Tier 3**, but a drop-in for that DLL: `draw_mana_text`
## (`shandalar-src/src/drawcardlib/drawmanatext.c:279-303`) sizes every
## symbol off the text metric it is standing in —
##
##     sym_hgt     = metrics.tmHeight * 75 / 100;
##     sym_wid     = w * 75 / 100;            // w == tmHeight on the big card
##     sym_ext_wid = w * 85 / 100;
##
## — a square three quarters of the LINE BOX, in an advance cell of 85% of
## it, so the symbol scales with the type and never with the screen. It is
## centred in that cell both ways
## (`((font_line_hgt - sym_hgt) >> 1) + posy`, `:445-449`), and **a run of
## adjacent symbols is ATOMIC**: `while ((tag = convert_initial_mana_tag(...)))`
## collects the whole run, and if `sym_wid * buf_len` will not fit before
## the right edge the WHOLE run moves to the next line (`:412-434`). This
## widget reproduces all four numbers and that rule.
##
## # WHY A WIDGET AND NOT A `RichTextLabel`
##
## The enlarged card picks its rules type size SYNCHRONOUSLY, inside
## `show_card`, by measuring the wrapped text against the box it has to
## stand in ([method CardPreview._fit_rules_size]). A [RichTextLabel] can
## carry inline images, but it only knows how tall it is AFTER a layout
## pass — `get_content_height()` is a frame away — so a ladder built on it
## would be choosing this hover's type size from the last hover's
## measurement. (1997 had the same problem and solved it the same way: it
## exported a measure-only twin, `CalcDrawManaText`, which is the same
## renderer with `drawflag = 0`.)
##
## [TextParagraph] is the object both a [Label] and a [RichTextLabel] are
## built on, and it is available directly: `add_string` for a run of text,
## `add_object` for an inline box the shaper wraps around, and
## `get_size()`/`get_line_count()` the instant the last run goes in. So the
## measurement and the render are THE SAME OBJECT here, which is strictly
## stronger than what the [Label] gave: the old
## [method CardPreview._wrapped_height] re-derived a line count from
## `get_multiline_string_size` and could in principle disagree with the
## Label that then drew it. The paragraph's own height is exactly the
## arithmetic the card already trusted, now measured rather than assumed —
## `get_size().y == lines * line_height + (lines - 1) * line_spacing`.
##
## **UNSKINNED IT IS THE BRACES, and so is any code the sheet cannot
## draw.** [ManaIcons.symbol] returns null when no skin is imported, and
## the fallback is PER TOKEN, not per card: the run goes back in as the
## literal text. The one code this pool uses that the nineteen cells cannot
## draw is `{C}` (90 occurrences — Scryfall's modern colorless pip, which
## the 1997 texts wrote out in words); it reads as `{C}` and the `{T}`
## beside it still draws. The game is complete with no 1997 files at all,
## which is a standing rule of this project.

## The word-wrap flags that reproduce a [Label]'s `AUTOWRAP_WORD_SMART`:
## break at word boundaries, fall back to breaking inside a word only when
## the word alone cannot fit (`BREAK_ADAPTIVE`), honour the `\n` the oracle
## text really contains (`BREAK_MANDATORY`), and do not let the space that
## ended a line push the next one in.
const WRAP_FLAGS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
	| TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_EDGE_SPACES

## The symbol's side, as a share of the line box it stands in —
## `sym_hgt = metrics.tmHeight * 75 / 100` (`drawmanatext.c:296`).
const SYMBOL_RATIO := 0.75
## Its advance cell, the same share of the same line box —
## `sym_ext_wid = w * 85 / 100` (`:298`). The difference is the padding
## that keeps `{B}{B}{B}` from touching, split evenly either side.
const SYMBOL_ADVANCE_RATIO := 0.85

## `{...}` and what is inside it. Compiled once — a `RegEx` is a
## RefCounted, not card data, so a static cache is safe here (see
## `CONTRIBUTING.md`, the `static var` rule).
static var _token_re: RegEx = null

## Per (face, size): `[symbol side, advance cell]`, both already stepped
## down if the shaper would answer them by making the line taller. Keyed by
## the font's instance id and the size, never by a font object.
static var _metrics_cache: Dictionary = {}


static func _re() -> RegEx:
	if _token_re == null:
		_token_re = RegEx.new()
		_token_re.compile("\\{([^{}]*)\\}")
	return _token_re


## [param text] split into runs: each entry is `["t", <literal>]` or
## `["s", <symbol name>]`. Pure, so the tests can read the split without a
## widget.
static func runs(text: String) -> Array:
	var out: Array = []
	var at := 0
	for m in _re().search_all(text):
		if m.get_start() > at:
			out.append(["t", text.substr(at, m.get_start() - at)])
		out.append(["s", m.get_string(1)])
		at = m.get_end()
	if at < text.length():
		out.append(["t", text.substr(at)])
	return out


## `[side, advance]` in pixels for a symbol set at [param font_size] — the
## 1997 ratios above, then CHECKED: an inline object taller than the line
## box makes the shaper give the line more room, which would cost the
## six-line rules box a line the moment a card mentioned `{T}`. At 75% of
## the line box nothing grows on any face this project ships, and the loop
## is the guarantee that a skin with a different face cannot change that.
static func symbol_metrics(font: Font, font_size: int) -> Array:
	var key := "%d:%d" % [font.get_instance_id(), font_size]
	if _metrics_cache.has(key):
		return _metrics_cache[key]
	var line_h: float = font.get_height(font_size)
	var side: float = maxf(1.0, roundf(line_h * SYMBOL_RATIO))
	while side > 1.0:
		var probe := TextParagraph.new()
		probe.set_break_flags(WRAP_FLAGS)
		probe.set_width(-1)
		probe.add_string("M", font, font_size)
		probe.add_object(0, Vector2(side, side), INLINE_ALIGNMENT_CENTER, 1, 0.0)
		if probe.get_line_size(0).y <= line_h:
			break
		side -= 1.0
	var advance: float = maxf(side,
		roundf(side * SYMBOL_ADVANCE_RATIO / SYMBOL_RATIO))
	var result := [side, advance]
	_metrics_cache[key] = result
	return result


## The paragraph [param text] makes at [param font_size], wrapped to
## [param width] — the ONE builder both the measurement and the draw go
## through. Returns `{"para": TextParagraph, "icons": {key: Array}}`, each
## value the run of textures to set inside that object's rect.
##
## **A RUN OF ADJACENT SYMBOLS IS ONE OBJECT**, which is how the original
## keeps `{B}{B}{B}` from being broken across a line (`:412-434`) — and it
## also puts the question of how a shaper treats two abutting object
## replacement characters beyond reach, which is worth having.
static func build(text: String, font: Font, font_size: int, width: float,
		line_spacing: int) -> Dictionary:
	var para := TextParagraph.new()
	para.set_break_flags(WRAP_FLAGS)
	para.set_width(width)
	para.set_line_spacing(line_spacing)
	para.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var metrics := symbol_metrics(font, font_size)
	var side: float = metrics[0]
	var advance: float = metrics[1]
	var icons: Dictionary = {}
	var pending: Array = []      # abutting symbols, still collecting
	var literal := ""            # abutting text, likewise
	var key := 0

	for run in runs(text):
		var tex: Texture2D = null
		if run[0] == "s":
			tex = ManaIcons.symbol(run[1])
		if tex != null:
			if literal != "":
				para.add_string(literal, font, font_size)
				literal = ""
			pending.append(tex)
			continue
		if not pending.is_empty():
			para.add_object(key, Vector2(advance * pending.size(), side),
				INLINE_ALIGNMENT_CENTER, 1, 0.0)
			icons[key] = pending
			key += 1
			pending = []
		# NO SKIN, or a code the nineteen-cell sheet cannot draw: the
		# braces go back in as text, exactly as they read today. Text
		# ACCUMULATES rather than going in run by run, so with no skin at
		# all the paragraph is one span and shapes character for character
		# as the plain string the box used to hold.
		literal += String(run[1]) if run[0] == "t" \
			else "{" + String(run[1]) + "}"
	if literal != "":
		para.add_string(literal, font, font_size)
	if not pending.is_empty():
		para.add_object(key, Vector2(advance * pending.size(), side),
			INLINE_ALIGNMENT_CENTER, 1, 0.0)
		icons[key] = pending
	# A paragraph with nothing in it has no line at all, which would make
	# an empty box report zero lines where a Label reports one.
	if para.get_line_count() == 0:
		para.add_string(" ", font, font_size)
	return {"para": para, "icons": icons}


## How tall [param text] stands once wrapped to [param width] at
## [param font_size] — symbols included. This is [CardPreview]'s fitting
## arithmetic, and it is now a MEASUREMENT of the very paragraph that will
## be drawn rather than a reconstruction of it. The 1997 renderer had the
## same pair and drew them from one function: `CalcDrawManaText` is
## `DrawManaText` with the pen switched off.
static func measure(text: String, font: Font, font_size: int, width: float,
		line_spacing: int) -> float:
	var built := build(text, font, font_size, width, line_spacing)
	var para: TextParagraph = built["para"]
	return para.get_size().y


var text: String = "":
	set(value):
		if text == value:
			return
		text = value
		_rebuild()

var _para: TextParagraph = null
var _icons: Dictionary = {}
## Rebuilt LAZILY. `show_card` sets the text, then the size, then moves the
## box — three notifications for one card — and shaping the paragraph three
## times over a 897-card sweep is work nobody reads. Nothing outside
## [method _ensure] touches [member _para].
var _dirty := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	# EVERY theme item this widget reads is an OVERRIDE from the start, so
	# no lookup can ever miss and log an error into a suite that fails on
	# one. Callers then set the ones they care about exactly as they would
	# on a Label — same names, same types.
	add_theme_font_override("font", ThemeDB.fallback_font)
	add_theme_font_size_override("font_size", ThemeDB.fallback_font_size)
	add_theme_color_override("font_color", Color(1, 1, 1))
	add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_theme_constant_override("line_spacing", 0)
	add_theme_constant_override("outline_size", 0)


func _notification(what: int) -> void:
	# The width decides the wrap and the theme decides the face and size,
	# so both rebuild. `add_theme_*_override` notifies synchronously, which
	# is what lets a caller set the size and measure in the same call.
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_rebuild()


func _rebuild() -> void:
	_dirty = true
	queue_redraw()


func _ensure() -> void:
	if not _dirty and _para != null:
		return
	var built := build(text, get_theme_font("font"),
		get_theme_font_size("font_size"), maxf(size.x, 1.0),
		get_theme_constant("line_spacing"))
	_para = built["para"]
	_icons = built["icons"]
	_dirty = false


## How many lines the text wraps to — the [Label] method of the same name.
func get_line_count() -> int:
	_ensure()
	return _para.get_line_count()


## How many of them stand WHOLE inside the box, which is the number that
## gets drawn. The original clips its rules text (`ETO_CLIPPED`) and so do
## we; a half-height line is worse than no line, so the cut is between
## lines exactly as a [Label]'s is.
func get_visible_line_count() -> int:
	_ensure()
	var spacing: int = get_theme_constant("line_spacing")
	var y := 0.0
	var shown := 0
	for i in _para.get_line_count():
		var h: float = _para.get_line_size(i).y
		if y + h > size.y + 0.5:
			break
		shown += 1
		y += h + spacing
	return shown


func _draw() -> void:
	_ensure()
	var spacing: int = get_theme_constant("line_spacing")
	var color: Color = get_theme_color("font_color")
	var outline: int = get_theme_constant("outline_size")
	var outline_color: Color = get_theme_color("font_outline_color")
	var metrics := symbol_metrics(get_theme_font("font"),
		get_theme_font_size("font_size"))
	var side: float = metrics[0]
	var advance: float = metrics[1]
	var pad := (advance - side) / 2.0
	var ci := get_canvas_item()
	var y := 0.0
	for i in get_visible_line_count():
		if outline > 0:
			_para.draw_line_outline(ci, Vector2(0, y), i, outline, outline_color)
		_para.draw_line(ci, Vector2(0, y), i, color)
		# The object rects are PARAGRAPH-relative and already carry the
		# line spacing, so they land on the same `y` this loop walks. Each
		# holds a RUN of symbols, and each symbol sits centred in its own
		# advance cell — `((sym_ext_wid - sym_wid) >> 1) + posx`,
		# `drawmanatext.c:447`.
		for key in _para.get_line_objects(i):
			var run: Array = _icons.get(key, [])
			if run.is_empty():
				continue
			var rect := _para.get_line_object_rect(i, key)
			for n in run.size():
				draw_texture_rect(run[n], Rect2(
					rect.position + Vector2(n * advance + pad, 0.0),
					Vector2(side, side)), false)
		y += _para.get_line_size(i).y + spacing
