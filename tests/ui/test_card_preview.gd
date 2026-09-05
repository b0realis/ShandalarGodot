extends GutTest
## THE ENLARGED CARD'S LETTERING — `game/duel/card_preview.gd`.
##
## The owner's 2026-09-04 playtest: *"Large card generator: card text,
## type, illustrator, power/defense are hardly readable in black — make
## text bigger, white with black border, and readable as original."*
##
## Two findings sit behind the fix and both are pinned here.
##
##   1. **THE GROUND, not the ink, was the discovery.** Four of the five
##      strings the owner named ride the card's own BODY, and the 1997
##      frame art (`Cardart/Cardbk_*.pic`, 1997-01-22 — Tier 1) paints that
##      body at luma 19-114 on five of its six colours. Dark ink there was
##      never a 1997 choice; it was ours, calibrated on `Cardbk_White`
##      alone. White with a hard outline is the honest rendering, and
##      Manalink's replacement renderer letters the same three strings
##      `255,255,255` over a `47,47,47` shadow (Tier 3 corroboration,
##      `shandalar-src/src/drawcardlib/config.c:817`).
##   2. **THE RULES TEXT IS THE OTHER CASE** — it sits on the frame's own
##      light plate, which is exactly the ground 1997 used, so it keeps
##      1997's dark ink (`RulestextColor` 47,47,47) and only grows.
##
## The sizes are ports of ratios, not taste, and the ratios are pinned too.


var _preview: CardPreview


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_preview = CardPreview.new()
	_preview.docked = true
	add_child_autofree(_preview)
	_preview.size = CardPreview.SIZE


## `show_card` rebuilds the cost row on every call and `queue_free`s the
## old one, which is not collected until a frame runs — the pool sweeps
## below call it 897 times, so give the frame here rather than leaving GUT
## to count the wreckage as orphans.
func after_each() -> void:
	await get_tree().process_frame


func _show(card_name: String) -> void:
	_preview.show_card(
		CardInstance.new(CardRegistry.get_card(card_name), 7, 0))


## The pool's longest oracle text — the case the text box has to survive.
func _longest_card() -> String:
	var worst := ""
	var worst_len := -1
	for card_name in CardRegistry.all_names():
		var length: int = CardRegistry.get_card(card_name).oracle_text.length()
		if length > worst_len:
			worst_len = length
			worst = card_name
	return worst


# ------------------------------------------------------------------ the ink --

## The four strings the owner named, plus the card name that shares their
## ground: white letters over a hard black outline, on every frame.
func test_every_string_on_the_card_body_is_white_with_a_black_outline() -> void:
	# One card per frame family, so no colour is taken on trust.
	for card_name in ["Serra Angel", "The Abyss", "Shivan Dragon",
			"Nova Pentacle", "Forest", "Master of the Hunt"]:
		_show(card_name)
		for label in [_preview._type_label, _preview._artist_label,
				_preview._pt_label, _preview._name_label]:
			assert_eq(label.get_theme_color("font_color"), CardPreview.BODY_INK,
				"%s: %s is white" % [card_name, label.name])
			assert_eq(label.get_theme_color("font_outline_color"),
				CardPreview.OUTLINE_INK, "%s: outline is black" % card_name)
			assert_gt(label.get_theme_constant("outline_size"), 0,
				"%s: the outline has weight" % card_name)


## And the ink does NOT branch on whether a skin is imported. It used to:
## dark on the imported frame, light on the flat fallback — and that branch
## is precisely what put luma-25 letters on a luma-19 card body.
func test_the_body_ink_is_the_same_with_and_without_the_imported_frame() -> void:
	_show("The Abyss")
	var skinned: Color = _preview._type_label.get_theme_color("font_color")
	assert_eq(skinned, CardPreview.BODY_INK)
	# The flat fallback paints its own dark frame and its own parchment
	# text box; the letters are the same colour on both.
	assert_eq(CardPreview.BODY_INK, Color(1, 1, 1))


## The rules text is the one string 1997 set dark, because it is the one
## string that stands on a light plate.
func test_the_rules_text_keeps_1997s_dark_ink() -> void:
	_show("Shivan Dragon")
	assert_eq(_preview._oracle.get_theme_color("font_color"),
		CardPreview.RULES_INK, "RulestextColor 47,47,47")
	assert_lt(CardPreview.RULES_INK.v, 0.25, "and it really is dark")
	assert_eq(_preview._oracle.get_theme_constant("outline_size"), 0,
		"no outline: the original draws its rules text with a bare "
			+ "SetTextColor and no shadow key exists for it")


# ---------------------------------------------------------------- the sizes --

## Each size is a share of the CARD'S HEIGHT ported off the original's own
## font table, resolved against the face actually in use. The line box has
## to land within a pixel under its target — a pixel over would overflow
## the strip the element sits on.
func test_the_sizes_are_the_1997_ratios_of_the_cards_height() -> void:
	var rows := [
		[_preview._title_font, _preview._name_size, CardPreview.NAME_RATIO, "name"],
		[_preview._title_font, _preview._type_size, CardPreview.TYPE_RATIO, "type"],
		[_preview._body_font, _preview._pt_size, CardPreview.PT_RATIO, "P/T"],
	]
	for row in rows:
		var font: Font = row[0]
		var target: float = float(row[2]) * CardPreview.SIZE.y
		var got: float = font.get_height(int(row[1]))
		assert_between(got, target - 2.0, target + 0.5,
			"%s: line box %.0f px against a %.2f px target" % [row[3], got, target])


## The rules text is sized by the LINE COUNT, which is the invariant the
## original's layout states: `Rulestext` 336 units over a 56-unit cell is
## exactly six lines.
func test_the_rules_box_holds_the_originals_six_lines() -> void:
	var font: Font = _preview._body_font
	var size: int = _preview._rules_size
	var box: float = (0.902 - (CardPreview.TEXT_TOP + 0.019)) * CardPreview.SIZE.y
	var six: float = CardPreview.RULES_LINES * font.get_height(size) \
		+ (CardPreview.RULES_LINES - 1) * CardPreview.RULES_LINE_SPACING
	assert_lte(six, box, "six lines stand inside the box")
	var seven: float = (CardPreview.RULES_LINES + 1) * font.get_height(size) \
		+ CardPreview.RULES_LINES * CardPreview.RULES_LINE_SPACING
	assert_gt(seven, box, "and a seventh would not — the size is the largest "
		+ "that fits six, not merely one that fits")


## Every one of them is a real jump from what the owner could not read.
func test_every_element_is_bigger_than_the_sizes_that_were_reported() -> void:
	assert_gt(_preview._rules_size, 12, "rules text was 12 and shrank to 10")
	assert_gt(_preview._type_size, 11, "the type line was 11")
	assert_gt(_preview._pt_size, 15, "the P/T pair was 15")
	assert_gt(_preview._illus_size, 9, "the illustrator credit was 9")


## The credit stays the smallest thing on the card — it is a credit, not
## something the player acts on.
func test_the_illustrator_credit_is_the_smallest_string_on_the_card() -> void:
	assert_lt(_preview._illus_size, _preview._rules_size)
	assert_lt(_preview._illus_size, _preview._pt_size)
	_show("Serra Angel")
	assert_string_starts_with(_preview._artist_label.text, CardPreview.ILLUS_PREFIX)


# ------------------------------------------------------- fitting the pool --

## THE LONGEST CARD IN THE POOL. Unexpanded it is clipped, as the original
## clips; with `Expand` on, the help file's promise — *"to display the
## entire card text"* — is kept.
func test_expand_shows_the_whole_text_of_the_pools_longest_card() -> void:
	var worst := _longest_card()
	_preview.set_text_expanded(true)
	_show(worst)
	await get_tree().process_frame
	assert_eq(_preview._oracle.get_visible_line_count(),
		_preview._oracle.get_line_count(),
		"%s (%d characters) is shown whole when Expand is on"
			% [worst, CardRegistry.get_card(worst).oracle_text.length()])


## And EVERY card's text box is one the text fits in — measured on the
## real Label, not on arithmetic about it.
func test_expand_fits_every_card_in_the_pool() -> void:
	_preview.set_text_expanded(true)
	var clipped := PackedStringArray()
	for card_name in CardRegistry.all_names():
		_show(card_name)
		await get_tree().process_frame
		if _preview._oracle.get_visible_line_count() \
				< _preview._oracle.get_line_count():
			clipped.append(card_name)
	assert_eq(clipped.size(), 0,
		"no card loses a line with Expand on; these do: %s" % str(clipped))


## Ordinary cards need no ladder at all: the great majority of the pool
## reads at the full ported size in the unexpanded box.
func test_most_of_the_pool_reads_at_the_full_size_unexpanded() -> void:
	var full := 0
	var total := 0
	for card_name in CardRegistry.all_names():
		_show(card_name)
		total += 1
		if _preview._oracle.get_theme_font_size("font_size") \
				== _preview._rules_size:
			full += 1
	assert_gt(float(full) / float(total), 0.7,
		"%d of %d cards need no step down" % [full, total])


## A name or a type line too long for its strip steps DOWN rather than
## being cut — the shape of the original's own nine-font ladders, which
## condense the face until the string fits.
func test_no_name_or_type_line_overflows_its_strip() -> void:
	for card_name in CardRegistry.all_names():
		_show(card_name)
		var name_w: float = _preview._title_font.get_string_size(
			_preview._name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_preview._name_label.get_theme_font_size("font_size")).x
		assert_lte(name_w, (0.68 - 0.055) * CardPreview.SIZE.x,
			"'%s' fits its title strip" % card_name)
		var type_w: float = _preview._title_font.get_string_size(
			_preview._type_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_preview._type_label.get_theme_font_size("font_size")).x
		assert_lte(type_w, (0.845 - 0.075) * CardPreview.SIZE.x,
			"'%s' fits its type strip" % _preview._type_label.text)


# --------------------------------------------------------------- Expand --

## *"This causes the text area to grow, WHEN NECESSARY"* (`Duel.hlp`,
## Showcase). The toggle used to move the box for every card; a Forest now
## keeps the printed box and only a card that overflows grows one.
func test_expand_grows_the_box_only_when_the_card_needs_it() -> void:
	_preview.set_text_expanded(true)
	_show("Forest")
	assert_almost_eq(_preview._oracle.anchor_top,
		float(CardPreview.TEXT_TOP + 0.019), 0.001,
		"a one-line card keeps the printed text box")
	_show(_longest_card())
	assert_almost_eq(_preview._oracle.anchor_top,
		float(CardPreview.TEXT_TOP_EXPANDED + 0.019), 0.001,
		"and the longest card takes the whole allowance")
	_preview.set_text_expanded(false)
	assert_almost_eq(_preview._oracle.anchor_top,
		float(CardPreview.TEXT_TOP + 0.019), 0.001,
		"toggling off puts every card back")


## When the box HAS grown, it takes the frame's own rules plate with it —
## `fullcard_expand_text_box` blits that same band rather than leaving the
## text on bare art, which is the only reason dark rules ink is still safe
## at the expanded size.
func test_a_grown_box_carries_the_frames_own_plate() -> void:
	if GameSkin.texture("card_frame_green") == null:
		return   # no imported skin on this machine; the flat frame paints its own
	_preview.set_text_expanded(true)
	_show("Forest")
	assert_false(_preview._text_plate.visible,
		"a box that has not grown needs no plate — the frame paints one")
	_show(_longest_card())
	assert_true(_preview._text_plate.visible,
		"a grown box carries the plate over the art it now covers")
	assert_not_null(_preview._text_plate.texture)
	assert_eq(_preview._text_plate.anchor_top, _preview._text_bg.anchor_top,
		"plate and box are one rectangle")


## The card BACK covers everything, and forgets the card — a live Expand
## toggle must not resurrect it.
func test_the_card_back_drops_the_plate_and_the_shown_card() -> void:
	_show("Serra Angel")
	_preview.show_back()
	assert_true(_preview._back.visible)
	assert_false(_preview._text_plate.visible)
	_preview.set_text_expanded(true)
	assert_true(_preview._back.visible, "toggling Expand does not un-flip it")


# ------------------------------------------------- the symbols in the text --
#
# The owner's 2026-09-04 playtest: *"The text has special symbols {R}, {B}
# etc. for mana and {T} for tap. Can we replace these in the text with
# actual mana and tapping symbols?"* — and the 1997 game already did. Its
# own shipped card database, `../shandalar-xp/MagicTG/Master.csv` (Tier 1,
# 1997-08-14), stores the rules text with the symbols escaped INSIDE the
# sentence: `0230,Sol Ring,Artifact,Mark Tedin,|T: to add |2 to pool`. See
# `tests/ui/test_mana_text.gd` for the whole evidence chain and for the
# widget's own contract; what is pinned HERE is that the enlarged card
# kept every measured guarantee it had while gaining them.


## The rules box is the widget that can draw them, and on a card with a
## `{T}` and coloured pips it does.
func test_the_rules_box_sets_the_1997_symbols_inline() -> void:
	if GameSkin.texture("mana_symbols") == null:
		return   # no imported sheet on this machine — the braces stay, as designed
	_show("Scarwood Hag")
	assert_is(_preview._oracle, ManaText,
		"the rules text is a ManaText, not a Label")
	var built := ManaText.build(_preview._oracle.text, _preview._body_font,
		_preview._oracle.get_theme_font_size("font_size"),
		(0.882 - 0.118) * CardPreview.SIZE.x, CardPreview.RULES_LINE_SPACING)
	var icons: Dictionary = built["icons"]
	assert_eq(icons.size(), 3, "{G}{G}{G}{G} is ONE mark and the two {T}s "
		+ "are the others — three inline objects, two of them single")
	var drawn := 0
	for run in icons.values():
		drawn += run.size()
	assert_eq(drawn, 6, "all six symbols of Scarwood Hag's text are set")


## And they SCALE WITH THE TYPE. A card at the bottom of the step-down
## ladder gets smaller symbols, not the 18 px ones on a 10 px line.
func test_the_symbols_step_down_with_the_rules_text() -> void:
	_show("Forest")
	var big: int = _preview._oracle.get_theme_font_size("font_size")
	_show("Tawnos's Coffin")
	var small: int = _preview._oracle.get_theme_font_size("font_size")
	assert_lt(small, big, "Tawnos's Coffin is far down the ladder")
	assert_lt(float(ManaText.symbol_metrics(_preview._body_font, small)[0]),
		float(ManaText.symbol_metrics(_preview._body_font, big)[0]),
		"and its symbols came down with it")


## **THE POOL SWEEP, AND IT MUST NOT HAVE COST A CARD A LINE.** The
## unexpanded box read 685 of 897 cards at the full ported size when the
## rules text was a plain `Label` printing braces; with the symbols set it
## reads 688, because a symbol is narrower than the three characters it
## replaces. These are floors, not equalities — getting better is allowed,
## getting worse is the regression this pins.
func test_the_symbols_did_not_cost_the_pool_a_single_step() -> void:
	var full := 0
	for card_name in CardRegistry.all_names():
		_show(card_name)
		if _preview._oracle.get_theme_font_size("font_size") \
				== _preview._rules_size:
			full += 1
	assert_gte(full, 685,
		"%d of %d cards read at the full size unexpanded; the braces "
			% [full, CardRegistry.all_names().size()]
			+ "managed 685 and inline symbols must not do worse")


## The same floor with `Expand` on — 810 with braces, 812 with symbols —
## and still not one card losing a line (which
## `test_expand_fits_every_card_in_the_pool` above measures on the real
## widget, frame by frame).
func test_expand_reads_at_least_as_many_cards_at_full_size_as_the_braces_did()\
		-> void:
	_preview.set_text_expanded(true)
	var full := 0
	for card_name in CardRegistry.all_names():
		_show(card_name)
		if _preview._oracle.get_theme_font_size("font_size") \
				== _preview._rules_size:
			full += 1
	assert_gte(full, 810, "%d cards at full size with Expand on" % full)


## **AND IT STILL READS WITH NO 1997 FILES AT ALL.** Take the sheet away
## and the card is exactly what it was: the braces, as text, at the same
## size, in a box that still fits them.
func test_with_no_imported_sheet_the_card_falls_back_to_the_braces() -> void:
	var saved: Variant = GameSkin._texture_cache.get("mana_symbols")
	GameSkin._texture_cache["mana_symbols"] = null
	ManaIcons._atlas_cache.clear()
	_show("Scarwood Hag")
	await get_tree().process_frame
	var built := ManaText.build(_preview._oracle.text, _preview._body_font,
		_preview._oracle.get_theme_font_size("font_size"),
		(0.882 - 0.118) * CardPreview.SIZE.x, CardPreview.RULES_LINE_SPACING)
	var lines: int = _preview._oracle.get_line_count()
	var visible: int = _preview._oracle.get_visible_line_count()
	if saved == null:
		GameSkin._texture_cache.erase("mana_symbols")
	else:
		GameSkin._texture_cache["mana_symbols"] = saved
	ManaIcons._atlas_cache.clear()
	assert_eq((built["icons"] as Dictionary).size(), 0, "nothing is drawn")
	assert_eq(visible, lines, "and the braces still fit the box")
