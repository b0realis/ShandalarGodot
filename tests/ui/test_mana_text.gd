extends GutTest
## THE SYMBOLS IN THE RULES TEXT — `game/duel/mana_text.gd`.
##
## The owner's 2026-09-04 playtest: *"The text has special symbols `{R}`,
## `{B}` etc. for mana and `{T}` for tap. Can we replace these in the text
## with actual mana and tapping symbols when rendering large beautiful
## cards?"*
##
## **The 1997 game already did, and its own card database is the proof.**
## `../shandalar-xp/MagicTG/Master.csv` (Tier 1, dated 1997-08-14) stores
## the rules text with the symbols escaped INSIDE the sentence —
## `0230,Sol Ring,Artifact,Mark Tedin,|T: to add |2 to pool - Interrupt` —
## and 204 of its 338 tagged rows carry `|T`, which settles it: **tap is
## never part of a mana cost**, so those symbols can only have been drawn
## in the rules-text body. `Magic.exe` imports `DrawManaText` and
## `CalcDrawManaText` from `DrawCardLib.dll` by name; `Duel.hlp` (Tier 1)
## does the same thing in its own prose, switching single characters into
## the `MagicSymbols` face mid-sentence. So this is fidelity, not
## decoration, and the braces are OURS — an artefact of the Scryfall
## snapshot in `cards/data/`.
##
## What is pinned here is the CONTRACT that lets the enlarged card keep
## its measured guarantees: the symbol scales with the type, it never makes
## a line taller, a run of them never breaks across a line, and nothing the
## sheet cannot draw is ever dropped.

var _body: Font

## Saved so a test may take the mana sheet away and put it back. Both
## caches are statics that outlive the test, so the restore is
## unconditional and lives in [method after_each].
var _saved_sheet: Variant = null
var _sheet_hidden := false


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_body = GameSkin.font("font_body")
	if _body == null:
		_body = ThemeDB.fallback_font


func after_each() -> void:
	if _sheet_hidden:
		if _saved_sheet == null:
			GameSkin._texture_cache.erase("mana_symbols")
		else:
			GameSkin._texture_cache["mana_symbols"] = _saved_sheet
		ManaIcons._atlas_cache.clear()
		_sheet_hidden = false


## Take the imported sheet away for one test — the state every player who
## has not run `tools/import_original.py` is in.
func _hide_the_sheet() -> void:
	_saved_sheet = GameSkin._texture_cache.get("mana_symbols")
	GameSkin._texture_cache["mana_symbols"] = null
	ManaIcons._atlas_cache.clear()
	_sheet_hidden = true


func _skinned() -> bool:
	return GameSkin.texture("mana_symbols") != null


# ------------------------------------------------------------- the split --

## The braces come apart into literal runs and symbol names, in order, and
## NOTHING is lost — the whole point, since a dropped token is a rules
## sentence that no longer says what the card does.
func test_the_text_splits_into_literals_and_symbols() -> void:
	var got := ManaText.runs("{G}{G}, {T}: Regenerate.")
	assert_eq(got, [["s", "G"], ["s", "G"], ["t", ", "], ["s", "T"],
		["t", ": Regenerate."]])


## And it is lossless over the WHOLE POOL: re-joining every run rebuilds
## the oracle text character for character.
func test_no_card_in_the_pool_loses_a_character_to_the_split() -> void:
	for card_name in CardRegistry.all_names():
		var text: String = CardRegistry.get_card(card_name).oracle_text
		var back := ""
		for run in ManaText.runs(text):
			back += run[1] if run[0] == "t" else "{" + String(run[1]) + "}"
		assert_eq(back, text, "%s survives the split" % card_name)


## THE CODES THIS POOL ACTUALLY USES, against the nineteen cells the 1997
## sheet has. Everything but `{C}` is on the sheet; `{C}` is Scryfall's
## modern colorless pip, which the 1997 texts wrote out in words and the
## 1997 sheet therefore has no cell for. It must READ, not vanish.
func test_every_code_in_the_pool_is_either_on_the_sheet_or_falls_back() -> void:
	var codes := {}
	for card_name in CardRegistry.all_names():
		for run in ManaText.runs(CardRegistry.get_card(card_name).oracle_text):
			if run[0] == "s":
				codes[run[1]] = true
	assert_gt(codes.size(), 5, "the pool really does use these")
	var off_sheet := PackedStringArray()
	for code in codes:
		if not ManaIcons.CELL.has(code):
			off_sheet.append(code)
	assert_eq(str(off_sheet), str(PackedStringArray(["C"])),
		"only {C} is off the 1997 sheet; a new one would need a decision")


## A code with no cell goes back in as its own braces rather than drawing
## nothing — checked on the real `{C}`, so it cannot rot.
func test_a_code_the_sheet_cannot_draw_stays_readable_text() -> void:
	if not _skinned():
		return
	var built := ManaText.build("{T}: Add {C}{C}.", _body, 18, 400.0, 1)
	var icons: Dictionary = built["icons"]
	assert_eq(icons.size(), 1, "the {T} draws")
	var para: TextParagraph = built["para"]
	assert_eq(para.get_line_count(), 1)
	# The braces are in the paragraph as text: it is wider than the same
	# sentence with the {C}s deleted.
	var without := ManaText.build("{T}: Add .", _body, 18, 400.0, 1)
	assert_gt(para.get_size().x, (without["para"] as TextParagraph).get_size().x,
		"{C}{C} occupies room as text")


# -------------------------------------------------------------- no skin --

## **UNSKINNED IT IS THE BRACES.** With no imported skin there is no mana
## sheet, and the game is complete without one — a standing rule of this
## project. Every token falls back, nothing is drawn, and the text is
## exactly what it reads today.
func test_with_no_imported_sheet_every_symbol_stays_as_braces() -> void:
	_hide_the_sheet()
	assert_null(ManaIcons.symbol("T"), "no sheet, no symbol")
	var built := ManaText.build("{G}{G}, {T}: Regenerate.", _body, 18, 400.0, 1)
	assert_eq((built["icons"] as Dictionary).size(), 0, "nothing is drawn")
	var bare := ManaText.build("{G}{G}, {T}: Regenerate.", _body, 18, 400.0, 1)
	var plain := TextParagraph.new()
	plain.set_break_flags(ManaText.WRAP_FLAGS)
	plain.set_width(400.0)
	plain.set_line_spacing(1)
	plain.add_string("{G}{G}, {T}: Regenerate.", _body, 18)
	assert_almost_eq((bare["para"] as TextParagraph).get_size().x,
		plain.get_size().x, 0.5, "and it measures as the plain string it is")


# ------------------------------------------------- the 1997 measurements --

## `sym_hgt = metrics.tmHeight * 75 / 100` and `sym_ext_wid = w * 85 / 100`
## (`drawcardlib/drawmanatext.c:296-298`), against the line box of the face
## actually in use — so the symbol is a share of the TYPE, never a pixel
## count, and a 10 px line cannot end up with an 18 px symbol on it.
func test_the_symbol_is_the_1997_share_of_the_line_it_stands_in() -> void:
	for size in [18, 16, 14, 12, 11, 10]:
		var line_h: float = _body.get_height(size)
		var m := ManaText.symbol_metrics(_body, size)
		assert_almost_eq(float(m[0]), roundf(line_h * 0.75), 0.01,
			"size %d: the symbol is three quarters of its line box" % size)
		assert_almost_eq(float(m[1]),
			roundf(roundf(line_h * 0.75) * 0.85 / 0.75), 0.01,
			"size %d: the advance cell is 85%% of it" % size)


## And it SHRINKS WITH THE LADDER. A 10 px line with 18 px symbols on it
## would be worse than the braces were.
func test_the_symbol_shrinks_when_the_text_steps_down() -> void:
	var big: float = ManaText.symbol_metrics(_body, 18)[0]
	var small: float = ManaText.symbol_metrics(_body, 10)[0]
	assert_gt(big, small, "18 px type carries a bigger symbol than 10 px type")
	assert_lt(small, _body.get_height(10), "and it still fits its own line")


## **THE SYMBOL NEVER MAKES THE LINE TALLER.** This is the invariant the
## enlarged card's six-line box rests on: an inline object taller than the
## line box makes the shaper give the line more room, and the first card
## that said `{T}` would lose a line.
func test_a_line_with_symbols_on_it_is_no_taller_than_one_without() -> void:
	if not _skinned():
		return
	for size in [18, 16, 14, 12, 11, 10]:
		var with_syms := ManaText.build("{2}{G}{G}, {T}: Regenerate.",
			_body, size, 4000.0, 1)
		var plain := ManaText.build("Regenerate.", _body, size, 4000.0, 1)
		var a: TextParagraph = with_syms["para"]
		var b: TextParagraph = plain["para"]
		assert_eq(a.get_line_count(), 1)
		assert_eq(a.get_line_size(0).y, b.get_line_size(0).y,
			"size %d: the symbols ride inside the line box" % size)


## A RUN OF ADJACENT SYMBOLS IS ATOMIC — the original collects the whole
## run and moves all of it to the next line rather than splitting it
## (`drawmanatext.c:412-434`). `{B}{B}{B}` is one indivisible mark.
func test_a_run_of_symbols_never_breaks_across_a_line() -> void:
	if not _skinned():
		return
	var built := ManaText.build("Add {B}{B}{B} to your mana pool.",
		_body, 18, 4000.0, 1)
	assert_eq((built["icons"] as Dictionary).size(), 1,
		"three abutting symbols are ONE inline object")
	assert_eq((built["icons"] as Dictionary).values()[0].size(), 3,
		"and it carries all three")
	# Squeezed to a width that splits the sentence, the run still travels
	# whole: every line either holds the whole object or none of it.
	for width in range(40, 210, 6):
		var narrow := ManaText.build("Add {B}{B}{B} to your mana pool.",
			_body, 18, float(width), 1)
		var para: TextParagraph = narrow["para"]
		var seen := 0
		for line in para.get_line_count():
			seen += para.get_line_objects(line).size()
		assert_eq(seen, 1, "width %d: the run is on exactly one line" % width)


## The paragraph's height IS the arithmetic the enlarged card fits against
## — `lines * line_box + (lines - 1) * spacing`, measured rather than
## reconstructed. [method CardPreview._wrapped_height] is this number.
func test_the_measured_height_is_the_cards_own_fitting_arithmetic() -> void:
	var text: String = CardRegistry.get_card("Master of the Hunt").oracle_text
	for spacing in [0, 1, 3]:
		var built := ManaText.build(text, _body, 14, 229.2, spacing)
		var para: TextParagraph = built["para"]
		var lines := para.get_line_count()
		assert_gt(lines, 6, "the pool's longest card really does wrap")
		assert_almost_eq(para.get_size().y,
			lines * _body.get_height(14) + (lines - 1) * spacing, 0.01,
			"spacing %d" % spacing)
		assert_almost_eq(ManaText.measure(text, _body, 14, 229.2, spacing),
			para.get_size().y, 0.01, "and `measure` reports it")


# -------------------------------------------------------------- the node --

## The widget draws only WHOLE lines, and stops at its own box — the
## original clips (`ETO_CLIPPED`) and a half-height line is worse than no
## line.
func test_the_widget_shows_whole_lines_and_clips_the_rest() -> void:
	var w := ManaText.new()
	add_child_autofree(w)
	w.add_theme_font_override("font", _body)
	w.add_theme_font_size_override("font_size", 14)
	w.add_theme_constant_override("line_spacing", 1)
	w.size = Vector2(229.2, 3.0 * _body.get_height(14) + 2.0)
	w.text = CardRegistry.get_card("Master of the Hunt").oracle_text
	await get_tree().process_frame
	assert_gt(w.get_line_count(), 3, "there is more text than room")
	assert_eq(w.get_visible_line_count(), 3, "three whole lines fit, so three show")
	# Grown to hold everything, everything shows.
	w.size = Vector2(229.2, 4000.0)
	await get_tree().process_frame
	assert_eq(w.get_visible_line_count(), w.get_line_count())


## An empty box still reports one line, as a `Label` does — the enlarged
## card never has one (it prints "(no rules text)"), but a widget that
## answered zero would make any fitting loop built on it divide by nothing.
func test_an_empty_widget_reports_one_line() -> void:
	var w := ManaText.new()
	add_child_autofree(w)
	w.add_theme_font_override("font", _body)
	w.size = Vector2(200, 200)
	await get_tree().process_frame
	assert_eq(w.get_line_count(), 1)


## The widget letters like a `Label` in both house treatments — the dark
## ink on a plate the enlarged card uses, and the white-over-outline every
## string standing on the card BODY uses. Turning the outline on changes
## the ink and never the layout; the paint itself was checked on screen.
func test_an_outline_changes_the_ink_and_not_the_layout() -> void:
	var plain := ManaText.new()
	var outlined := ManaText.new()
	for w in [plain, outlined]:
		add_child_autofree(w)
		w.add_theme_font_override("font", _body)
		w.add_theme_font_size_override("font_size", 14)
		w.add_theme_constant_override("line_spacing", 1)
		w.size = Vector2(229.2, 200.0)
		w.text = CardRegistry.get_card("Scarwood Hag").oracle_text
	outlined.add_theme_color_override("font_color", Color(1, 1, 1))
	outlined.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	outlined.add_theme_constant_override("outline_size", 3)
	await get_tree().process_frame
	assert_eq(outlined.get_line_count(), plain.get_line_count())
	assert_eq(outlined.get_visible_line_count(), plain.get_visible_line_count())
	assert_eq(outlined.get_theme_constant("outline_size"), 3)
	assert_eq(plain.get_theme_constant("outline_size"), 0,
		"and the default is the rules text's: no outline at all")
