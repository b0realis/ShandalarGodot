extends GutTest
## A glyph a face lacks is found in our own body face, not asked of the
## operating system on every shaping (campaign 2026-11-26, smoothness 1),
## and a face's own text measures as it did.


func _own_height(face: Font, size: int) -> float:
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = face.get_rids()[0]
	return ts.font_get_ascent(rid, size) + ts.font_get_descent(rid, size)


func _shape_ms(face: Font, text: String) -> float:
	var t0 := Time.get_ticks_usec()
	for i in 20:
		var para := TextParagraph.new()
		para.width = 600.0
		para.add_string("%s %d" % [text, i], face, 16)
		para.get_size()
	return float(Time.get_ticks_usec() - t0) / 20000.0


func _check(face: Font, what: String) -> void:
	assert_false(face.fallbacks.is_empty(), "%s has a face behind it" % what)
	for size in [10, 13, 16, 22, 30, 48]:
		assert_almost_eq(face.get_height(size), _own_height(face, size), 0.01,
			"%s at %d px is as tall as the face alone" % [what, size])
	for glyph in ["—", "›", "×", "é", "◀", "▶", "▲", "▼", "●"]:
		var found := false
		for rid: RID in face.get_rids():
			if TextServerManager.get_primary_interface().font_has_char(rid, glyph.unicode_at(0)):
				found = true
		assert_true(found, "%s or the face behind it has U+%04X" % [what, glyph.unicode_at(0)])
	assert_lt(_shape_ms(face, "Creature — Goblin ▼"), 1.0, "%s: no lookup outside the game" % what)


func test_the_engine_face_borrows_our_glyphs() -> void:
	GameSkin.font("font_body")
	_check(ThemeDB.fallback_font, "the engine's face")


func test_the_title_face_borrows_our_glyphs() -> void:
	var title := GameSkin.font("font_title")
	if title == null:
		pass_test("no title face without a skin")
		return
	_check(title, "the title face")
	var bold := UiChrome.menu_button("A — B", Vector2(200, 40), 22, 0.5)
	add_child_autofree(bold)
	var plain := UiChrome.menu_button("A - B", Vector2(0, 0), 22)
	add_child_autofree(plain)
	var dashed := UiChrome.menu_button("A \u2014 B", Vector2(0, 0), 22)
	add_child_autofree(dashed)
	assert_lt(_shape_ms(bold.get_theme_font("font"), "A — B"), 1.0, "the emboldened face borrows too")
	assert_eq(dashed.get_minimum_size().y, plain.get_minimum_size().y, "a button with a dash is as tall as one without")


func test_a_label_is_no_taller_for_the_borrowed_face() -> void:
	GameSkin.font("font_body")
	var face := ThemeDB.fallback_font
	var kept: Array = face.fallbacks.duplicate()
	var label := Label.new()
	label.text = "Plain text"
	add_child_autofree(label)
	var with_lent := label.get_minimum_size()
	face.fallbacks = []
	label.text = "Plain text."
	label.text = "Plain text"
	var alone := label.get_minimum_size()
	face.fallbacks = kept
	assert_eq(with_lent, alone, "the same box with and without the face behind")
